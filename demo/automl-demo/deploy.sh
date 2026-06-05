#!/bin/bash
################################################################################
# Deploy AutoML Demo
################################################################################
# Sets up infrastructure for AutoML (Technology Preview):
#   - MinIO for pipeline artifacts and sample data
#   - Pipeline Server (DSPA) for Kubeflow Pipelines
#   - AutoGluon ServingRuntime for deploying trained models
#   - S3 data connection for CSV training data
#
# AutoML itself is a dashboard-native feature -- after infrastructure is ready,
# use the RHOAI dashboard: Develop and train > AutoML
#
# Usage:
#   ./deploy.sh                    # Deploy to automl-demo namespace
#   ./deploy.sh -n my-namespace    # Custom namespace
#   ./deploy.sh --delete           # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"

NAMESPACE="${1:-automl-demo}"
DELETE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--delete]"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "AutoML Demo (Technology Preview)"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing AutoML infrastructure from $NAMESPACE..."
    oc delete servingruntime kserve-autogluonserver -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete datasciencepipelineapplication pipelines-definition -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    export NAMESPACE
    envsubst < "$SCRIPT_DIR/manifests/minio.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
    print_success "AutoML infrastructure removed from $NAMESPACE"
    exit 0
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

# Verify AI Pipelines CRD
if ! oc get crd datasciencepipelinesapplications.datasciencepipelinesapplications.opendatahub.io &>/dev/null 2>&1; then
    print_error "DSPA CRD not found. Ensure 'aipipelines: Managed' in your DataScienceCluster."
    exit 1
fi

ensure_namespace "$NAMESPACE"
oc label namespace "$NAMESPACE" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true

# Enable AutoML in dashboard
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
    --type=merge -p '{"spec":{"dashboardConfig":{"automl":true}}}' 2>/dev/null || true

# --- Step 1: MinIO for pipeline artifacts + sample data ---
print_step "Deploying MinIO for pipeline artifacts and sample data..."
if oc get deployment minio -n "$NAMESPACE" &>/dev/null; then
    print_info "MinIO already deployed in $NAMESPACE"
else
    export NAMESPACE
    envsubst < "$SCRIPT_DIR/manifests/minio.yaml" | oc apply -f -
    oc rollout status deployment/minio -n "$NAMESPACE" --timeout=120s 2>/dev/null || true
fi

# --- Step 2: Create pipeline-artifacts bucket and upload sample data ---
print_step "Creating S3 buckets and uploading sample data..."
MINIO_POD=$(oc get pod -l app=minio -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$MINIO_POD" ]; then
    oc exec "$MINIO_POD" -n "$NAMESPACE" -- sh -c '
        mc alias set local http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} 2>/dev/null
        mc mb --ignore-existing local/pipeline-artifacts 2>/dev/null
        mc mb --ignore-existing local/automl-data 2>/dev/null
    ' 2>/dev/null || print_warning "Could not create buckets -- MinIO may still be starting"

    if [ -f "$SCRIPT_DIR/sample-data/loan-approval.csv" ]; then
        oc exec -i "$MINIO_POD" -n "$NAMESPACE" -- sh -c 'cat > /tmp/loan-approval.csv' \
            < "$SCRIPT_DIR/sample-data/loan-approval.csv" 2>/dev/null
        oc exec "$MINIO_POD" -n "$NAMESPACE" -- sh -c '
            mc cp /tmp/loan-approval.csv local/automl-data/loan-approval.csv 2>/dev/null
        ' 2>/dev/null || print_warning "Could not upload sample data"
        print_success "Sample CSV uploaded to s3://automl-data/loan-approval.csv"
    fi
else
    print_warning "MinIO pod not found yet -- upload sample data after MinIO is ready"
fi

# --- Step 3: Create S3 data connection ---
print_step "Creating S3 data connection for AutoML..."
oc apply -n "$NAMESPACE" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: aws-connection-automl-data
  namespace: $NAMESPACE
  labels:
    opendatahub.io/dashboard: "true"
    opendatahub.io/managed: "true"
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: "AutoML Training Data"
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: minio
  AWS_SECRET_ACCESS_KEY: minio123
  AWS_DEFAULT_REGION: us-east-1
  AWS_S3_BUCKET: automl-data
  AWS_S3_ENDPOINT: http://minio.${NAMESPACE}.svc.cluster.local:9000
EOF

# --- Step 4: Pipeline Server (DSPA) ---
print_step "Deploying Pipeline Server (DSPA)..."
if oc get datasciencepipelinesapplication pipelines-definition -n "$NAMESPACE" &>/dev/null 2>&1; then
    print_info "Pipeline server already exists in $NAMESPACE"
else
    export NAMESPACE
    envsubst < "$SCRIPT_DIR/manifests/pipeline-server.yaml" | oc apply -f -
    print_info "Pipeline server deploying (takes 1-2 minutes)..."
fi

# --- Step 5: AutoGluon ServingRuntime ---
print_step "Deploying AutoGluon ServingRuntime..."
oc apply -n "$NAMESPACE" -f "$SCRIPT_DIR/manifests/autogluon-servingruntime.yaml"

echo ""
print_success "AutoML Demo infrastructure deployed"
print_info "Namespace: $NAMESPACE"
echo ""
echo "  AutoML is a dashboard UI feature. To use it:"
echo ""
echo "  1. Open RHOAI Dashboard"
echo "  2. Go to: Develop and train > AutoML"
echo "  3. Create an optimization run:"
echo "     - S3 Connection: 'AutoML Training Data'"
echo "     - Select: loan-approval.csv"
echo "     - Task type: Binary Classification"
echo "     - Label column: loan_status"
echo "  4. Wait for training to complete (~5-10 minutes)"
echo "  5. View leaderboard and compare models"
echo "  6. Register the best model to Model Registry"
echo "  7. Deploy using AutoGluon ServingRuntime for KServe"
echo ""
echo "  Sample data: s3://automl-data/loan-approval.csv"
echo "  Task types: Binary Classification, Multiclass, Regression, Time Series"
echo ""
echo "  Requirements:"
echo "  - At least 4 CPUs and 16 GiB memory available for scheduling"
echo "  - CSV file: UTF-8, comma-delimited, with header row"
echo ""
