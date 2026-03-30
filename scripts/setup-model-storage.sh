#!/bin/bash
################################################################################
# Setup Model Storage (MinIO + RHOAI Data Connection)
#
# Deploys MinIO S3-compatible storage and creates RHOAI data connection for
# storing and serving models downloaded from HuggingFace.
#
# Usage:
#   ./setup-model-storage.sh [OPTIONS]
#
# Options:
#   -n, --namespace NAME    Namespace for MinIO (default: model-storage)
#   -b, --bucket NAME       Bucket name (default: models)
#   --storage-size SIZE     PVC size (default: 200Gi)
#   --minio-user USER       MinIO username (default: minio)
#   --minio-password PASS   MinIO password (default: minio123)
#   --skip-data-connection  Skip creating RHOAI data connection
#   --data-connection-ns NS Namespace for data connection (default: same as MinIO)
#   -h, --help              Show this help
#
# Examples:
#   ./setup-model-storage.sh                           # Default setup
#   ./setup-model-storage.sh -n demo -b my-models      # Custom namespace/bucket
#   ./setup-model-storage.sh --storage-size 500Gi     # Larger storage
#
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source utilities
if [ -f "$BASE_DIR/lib/utils/colors.sh" ]; then
    source "$BASE_DIR/lib/utils/colors.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    BOLD='\033[1m'
fi

print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Defaults
NAMESPACE="model-storage"
BUCKET_NAME="models"
STORAGE_SIZE="200Gi"
MINIO_USER="minio"
MINIO_PASSWORD="minio123"
SKIP_DATA_CONNECTION=false
DATA_CONNECTION_NS=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -b|--bucket)
            BUCKET_NAME="$2"
            shift 2
            ;;
        --storage-size)
            STORAGE_SIZE="$2"
            shift 2
            ;;
        --minio-user)
            MINIO_USER="$2"
            shift 2
            ;;
        --minio-password)
            MINIO_PASSWORD="$2"
            shift 2
            ;;
        --skip-data-connection)
            SKIP_DATA_CONNECTION=true
            shift
            ;;
        --data-connection-ns)
            DATA_CONNECTION_NS="$2"
            shift 2
            ;;
        -h|--help)
            head -40 "$0" | tail -35
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Default data connection namespace to MinIO namespace
DATA_CONNECTION_NS="${DATA_CONNECTION_NS:-$NAMESPACE}"

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║           Model Storage Setup (MinIO + RHOAI)                  ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_info "Namespace:      $NAMESPACE"
print_info "Bucket:         $BUCKET_NAME"
print_info "Storage Size:   $STORAGE_SIZE"
print_info "Data Connection: ${DATA_CONNECTION_NS}"
echo ""

# Check oc login
if ! oc whoami &>/dev/null; then
    print_error "Not logged into OpenShift. Run 'oc login' first."
    exit 1
fi

# Get cluster domain
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "")
if [ -z "$CLUSTER_DOMAIN" ]; then
    print_error "Could not determine cluster domain"
    exit 1
fi

################################################################################
# Step 1: Create namespace
################################################################################
print_step "Creating namespace: $NAMESPACE"

if oc get namespace "$NAMESPACE" &>/dev/null; then
    print_info "Namespace already exists"
else
    oc create namespace "$NAMESPACE"
    print_success "Namespace created"
fi

# Label for RHOAI dashboard visibility
oc label namespace "$NAMESPACE" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true

################################################################################
# Step 2: Deploy MinIO
################################################################################
print_step "Deploying MinIO..."

# Check if MinIO already exists
if oc get deployment minio -n "$NAMESPACE" &>/dev/null; then
    print_info "MinIO deployment already exists"
else
    # Create MinIO secret
    cat <<EOF | oc apply -n "$NAMESPACE" -f -
apiVersion: v1
kind: Secret
metadata:
  name: minio
  labels:
    app.kubernetes.io/name: minio
    app.kubernetes.io/component: storage
stringData:
  MINIO_ROOT_USER: "${MINIO_USER}"
  MINIO_ROOT_PASSWORD: "${MINIO_PASSWORD}"
EOF

    # Create PVC
    cat <<EOF | oc apply -n "$NAMESPACE" -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: models-pvc
  labels:
    app.kubernetes.io/name: minio
    app.kubernetes.io/component: storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${STORAGE_SIZE}
EOF

    # Create Deployment
    cat <<EOF | oc apply -n "$NAMESPACE" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  labels:
    app.kubernetes.io/name: minio
    app.kubernetes.io/component: storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: minio
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/name: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        imagePullPolicy: IfNotPresent
        command:
        - /usr/bin/docker-entrypoint.sh
        - server
        - /data
        - "--console-address"
        - ":9001"
        envFrom:
        - secretRef:
            name: minio
        ports:
        - name: api
          containerPort: 9000
          protocol: TCP
        - name: console
          containerPort: 9001
          protocol: TCP
        resources:
          requests:
            cpu: 100m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 2Gi
        volumeMounts:
        - name: data
          mountPath: /data
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: api
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /minio/health/ready
            port: api
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: models-pvc
EOF

    # Create Service
    cat <<EOF | oc apply -n "$NAMESPACE" -f -
apiVersion: v1
kind: Service
metadata:
  name: minio
  labels:
    app.kubernetes.io/name: minio
spec:
  type: ClusterIP
  ports:
  - name: api
    port: 9000
    targetPort: api
  - name: console
    port: 9001
    targetPort: console
  selector:
    app.kubernetes.io/name: minio
EOF

    # Create Routes
    cat <<EOF | oc apply -n "$NAMESPACE" -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: minio
  labels:
    app.kubernetes.io/name: minio
spec:
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  port:
    targetPort: api
  to:
    kind: Service
    name: minio
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: minio-console
  labels:
    app.kubernetes.io/name: minio
spec:
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  port:
    targetPort: console
  to:
    kind: Service
    name: minio
EOF

    print_success "MinIO deployed"
fi

################################################################################
# Step 3: Wait for MinIO to be ready
################################################################################
print_step "Waiting for MinIO to be ready..."

TIMEOUT=120
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    READY=$(oc get deployment minio -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$READY" = "1" ]; then
        print_success "MinIO is ready"
        break
    fi
    echo "  Waiting for MinIO pod... (${ELAPSED}s)"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    print_error "Timeout waiting for MinIO"
    exit 1
fi

################################################################################
# Step 4: Create bucket
################################################################################
print_step "Creating bucket: $BUCKET_NAME"

# Get MinIO internal URL
MINIO_INTERNAL_URL="http://minio.${NAMESPACE}.svc:9000"

# Create a job to create the bucket
cat <<EOF | oc apply -n "$NAMESPACE" -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: create-bucket
  labels:
    app.kubernetes.io/name: minio-setup
spec:
  ttlSecondsAfterFinished: 60
  template:
    spec:
      containers:
      - name: mc
        image: quay.io/minio/mc:latest
        command: ["/bin/sh", "-c"]
        args:
          - |
            set -e
            
            # Wait for MinIO
            echo "Waiting for MinIO..."
            until curl -sf http://minio:9000/minio/health/live; do
              sleep 2
            done
            
            # Configure mc
            mc alias set myminio http://minio:9000 "${MINIO_USER}" "${MINIO_PASSWORD}"
            
            # Create bucket if not exists
            if mc ls myminio/${BUCKET_NAME} 2>/dev/null; then
              echo "Bucket '${BUCKET_NAME}' already exists"
            else
              mc mb myminio/${BUCKET_NAME}
              echo "Bucket '${BUCKET_NAME}' created"
            fi
            
            echo "Done!"
      restartPolicy: Never
  backoffLimit: 3
EOF

# Wait for job completion
print_info "Waiting for bucket creation..."
oc wait --for=condition=complete job/create-bucket -n "$NAMESPACE" --timeout=60s 2>/dev/null || true
oc delete job/create-bucket -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
print_success "Bucket ready"

################################################################################
# Step 5: Create RHOAI Data Connection
################################################################################
if [ "$SKIP_DATA_CONNECTION" = false ]; then
    print_step "Creating RHOAI data connection in namespace: $DATA_CONNECTION_NS"
    
    # Ensure target namespace exists
    if ! oc get namespace "$DATA_CONNECTION_NS" &>/dev/null; then
        oc create namespace "$DATA_CONNECTION_NS"
        oc label namespace "$DATA_CONNECTION_NS" opendatahub.io/dashboard=true --overwrite
    fi
    
    # Get MinIO route for external access (used by workbenches)
    MINIO_ROUTE="https://$(oc get route minio -n "$NAMESPACE" -o jsonpath='{.spec.host}')"
    
    # Create data connection secret (RHOAI format)
    # This secret format is recognized by RHOAI dashboard and workbenches
    cat <<EOF | oc apply -n "$DATA_CONNECTION_NS" -f -
apiVersion: v1
kind: Secret
metadata:
  name: aws-connection-minio
  labels:
    opendatahub.io/dashboard: "true"
    opendatahub.io/managed: "true"
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: "MinIO Model Storage"
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "${MINIO_USER}"
  AWS_SECRET_ACCESS_KEY: "${MINIO_PASSWORD}"
  AWS_S3_ENDPOINT: "http://minio.${NAMESPACE}.svc:9000"
  AWS_S3_BUCKET: "${BUCKET_NAME}"
  AWS_DEFAULT_REGION: "us-east-1"
EOF

    # Also create the aws-connection-my-storage secret for compatibility with existing scripts
    cat <<EOF | oc apply -n "$DATA_CONNECTION_NS" -f -
apiVersion: v1
kind: Secret
metadata:
  name: aws-connection-my-storage
  labels:
    opendatahub.io/dashboard: "true"
    opendatahub.io/managed: "true"
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: "Model Storage (MinIO)"
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "${MINIO_USER}"
  AWS_SECRET_ACCESS_KEY: "${MINIO_PASSWORD}"
  AWS_S3_ENDPOINT: "http://minio.${NAMESPACE}.svc:9000"
  AWS_S3_BUCKET: "${BUCKET_NAME}"
  AWS_DEFAULT_REGION: "us-east-1"
EOF

    print_success "Data connection created"
fi

################################################################################
# Summary
################################################################################
echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                    Setup Complete!                             ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}MinIO Details:${NC}"
echo "  Namespace:     $NAMESPACE"
echo "  Internal URL:  http://minio.${NAMESPACE}.svc:9000"
echo "  Console:       https://minio-console-${NAMESPACE}.${CLUSTER_DOMAIN}"
echo "  API Route:     https://minio-${NAMESPACE}.${CLUSTER_DOMAIN}"
echo "  Username:      $MINIO_USER"
echo "  Password:      $MINIO_PASSWORD"
echo "  Bucket:        $BUCKET_NAME"
echo ""
echo -e "${CYAN}RHOAI Data Connection:${NC}"
echo "  Namespace:     $DATA_CONNECTION_NS"
echo "  Secret Name:   aws-connection-minio"
echo "  Also:          aws-connection-my-storage (for script compatibility)"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Download model from HuggingFace:"
echo "     NAMESPACE=$DATA_CONNECTION_NS ./scripts/download-model.sh s3 Qwen/Qwen3-8B"
echo ""
echo "  2. Deploy model using storageUri:"
echo "     storageUri: s3://${BUCKET_NAME}/<model-name>/"
echo ""
echo "  3. Or use the RHOAI dashboard to create a model server"
echo "     with the 'MinIO Model Storage' data connection"
echo ""
