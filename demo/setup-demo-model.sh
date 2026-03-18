#!/bin/bash
################################################################################
# Setup Demo Model for MaaS
################################################################################
# This script deploys a model using llm-d (LLMInferenceService) for MaaS demo.
# 
# llm-d is the ONLY serving runtime that works with MaaS through the UI.
# vLLM does NOT support MaaS via the dashboard.
#
# Requirements:
#   - RHOAI 3.2+ (LLMInferenceService CRD must exist)
#   - GPU nodes available
#   - MaaS infrastructure set up (run ../scripts/setup-maas.sh if not)
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Source RHOAI detection utility
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/rhoai-detect.sh" ]; then
    source "$SCRIPT_DIR/lib/rhoai-detect.sh"
fi

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

print_header "MaaS Demo Model Setup (llm-d)"

echo -e "${CYAN}This script deploys a model using llm-d (LLMInferenceService).${NC}"
echo -e "${CYAN}llm-d is the ONLY runtime that works with MaaS through the UI.${NC}"
echo ""

################################################################################
# Prerequisites Check
################################################################################

print_step "Checking prerequisites..."

# Check if logged in
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift"
    echo "Please login first: oc login <cluster-url>"
    exit 1
fi
print_success "Connected to OpenShift cluster"

# Check if RHOAI is installed
if ! oc get datasciencecluster default-dsc &>/dev/null; then
    print_error "RHOAI not installed"
    echo "Please install RHOAI first"
    exit 1
fi
print_success "RHOAI is installed"

# Check for LLMInferenceService CRD (required for llm-d)
if ! oc get crd llminferenceservices.serving.kserve.io &>/dev/null; then
    print_error "LLMInferenceService CRD not found"
    echo ""
    echo "llm-d requires RHOAI 3.2 or higher."
    echo "Your cluster does not have the LLMInferenceService CRD."
    echo ""
    echo "Options:"
    echo "  1. Upgrade to RHOAI 3.2+"
    echo "  2. Use vLLM directly (but it won't work with MaaS UI)"
    exit 1
fi
print_success "LLMInferenceService CRD available (llm-d supported)"

# Detect RHOAI version
detect_rhoai_version
echo ""

################################################################################
# Setup LeaderWorkerSet (LWS) Operator
################################################################################

print_step "Checking LeaderWorkerSet (LWS) operator..."

# LWS is required for llm-d multi-node workloads
if oc get crd leaderworkersets.leaderworkerset.x-k8s.io &>/dev/null; then
    print_success "LeaderWorkerSet CRD already available"
else
    # Check if LWS operator is installed
    if oc get crd leaderworkersetoperators.operator.openshift.io &>/dev/null; then
        print_info "LWS operator installed, creating instance..."
        
        # Create LeaderWorkerSetOperator instance if it doesn't exist
        if ! oc get leaderworkersetoperator cluster &>/dev/null 2>&1; then
            cat <<EOF | oc apply -f -
apiVersion: operator.openshift.io/v1
kind: LeaderWorkerSetOperator
metadata:
  name: cluster
spec:
  managementState: Managed
EOF
            print_info "Waiting for LeaderWorkerSet CRD to be created..."
            for i in {1..30}; do
                if oc get crd leaderworkersets.leaderworkerset.x-k8s.io &>/dev/null; then
                    print_success "LeaderWorkerSet CRD is ready"
                    break
                fi
                sleep 2
            done
        else
            print_success "LeaderWorkerSetOperator instance exists"
        fi
    else
        print_warning "LWS operator not installed"
        echo "llm-d requires LeaderWorkerSet for multi-node workloads."
        echo "Install the 'Red Hat build of Leader Worker Set' operator from OperatorHub."
        echo ""
        read -p "Continue anyway? (y/n): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
fi
echo ""

################################################################################
# Setup Gateway TLS Certificate
################################################################################

print_step "Checking MaaS gateway TLS certificate..."

# Get cluster domain for certificate
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)

if is_rhoai_33_or_higher; then
    # RHOAI 3.3+: Check openshift-ai-inference gateway
    GATEWAY_NS="openshift-ingress"
    TLS_SECRET="default-gateway-tls"
    GATEWAY_HOSTNAME="inference-gateway.${CLUSTER_DOMAIN}"
    
    if oc get secret "$TLS_SECRET" -n "$GATEWAY_NS" &>/dev/null; then
        print_success "Gateway TLS certificate exists"
    else
        # Check if gateway exists and needs TLS
        if oc get gateway openshift-ai-inference -n "$GATEWAY_NS" &>/dev/null; then
            print_info "Creating TLS certificate for inference gateway..."
            
            # Create openssl config for SAN
            TMPDIR=$(mktemp -d)
            cat > "$TMPDIR/openssl.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext
x509_extensions = v3_ext

[dn]
CN = inference-gateway

[req_ext]
subjectAltName = @alt_names

[v3_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $GATEWAY_HOSTNAME
DNS.2 = *.${CLUSTER_DOMAIN}
EOF
            
            # Generate certificate
            openssl req -x509 -newkey rsa:2048 \
                -keyout "$TMPDIR/tls.key" \
                -out "$TMPDIR/tls.crt" \
                -days 365 -nodes \
                -config "$TMPDIR/openssl.cnf" 2>/dev/null
            
            # Create secret
            oc create secret tls "$TLS_SECRET" -n "$GATEWAY_NS" \
                --cert="$TMPDIR/tls.crt" \
                --key="$TMPDIR/tls.key" 2>/dev/null
            
            # Cleanup
            rm -rf "$TMPDIR"
            
            if oc get secret "$TLS_SECRET" -n "$GATEWAY_NS" &>/dev/null; then
                print_success "TLS certificate created"
                
                # Restart gateway pod to pick up new certificate
                print_info "Restarting gateway pod to apply TLS..."
                GATEWAY_POD=$(oc get pods -n "$GATEWAY_NS" -l app=openshift-ai-inference -o name 2>/dev/null | head -1)
                if [ -n "$GATEWAY_POD" ]; then
                    oc delete "$GATEWAY_POD" -n "$GATEWAY_NS" 2>/dev/null || true
                    sleep 5
                fi
            else
                print_warning "Failed to create TLS certificate"
            fi
        fi
    fi
fi
echo ""

################################################################################
# Check MaaS Status
################################################################################

print_step "Checking MaaS infrastructure..."

MAAS_READY=false
if is_rhoai_33_or_higher; then
    # RHOAI 3.3+: Check for gateway
    if oc get gateway openshift-ai-inference -n openshift-ingress &>/dev/null; then
        # Check if gateway is programmed
        PROGRAMMED=$(oc get gateway openshift-ai-inference -n openshift-ingress -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
        if [ "$PROGRAMMED" = "True" ]; then
            print_success "MaaS gateway is ready (RHOAI 3.3+)"
            MAAS_READY=true
        else
            print_warning "MaaS gateway exists but not programmed"
        fi
    else
        print_warning "MaaS gateway not found"
        echo "Enable MaaS with: modelsAsService.managementState: Managed in DataScienceCluster"
    fi
else
    # RHOAI 3.2: Check for legacy MaaS namespace
    if oc get namespace maas-api &>/dev/null; then
        print_success "MaaS infrastructure found (legacy namespace)"
        MAAS_READY=true
    else
        print_warning "Legacy MaaS namespace not found"
        echo "Run: ../scripts/setup-maas.sh"
    fi
fi

if [ "$MAAS_READY" = false ]; then
    echo ""
    read -p "Continue without MaaS? (y/n): " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi
echo ""

################################################################################
# Check GPU Nodes
################################################################################

print_step "Checking for GPU nodes..."

GPU_NODES=$(oc get nodes -l nvidia.com/gpu.present=true --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$GPU_NODES" -eq 0 ]; then
    print_warning "No GPU nodes detected"
    echo "Model deployment requires GPU nodes."
    echo ""
    read -p "Continue anyway? (y/n): " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    print_success "Found $GPU_NODES GPU node(s)"
fi
echo ""

################################################################################
# Project Setup
################################################################################

print_header "Project Setup"

# Default project name
DEFAULT_PROJECT="maas-demo"
read -p "Enter project/namespace name [$DEFAULT_PROJECT]: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_PROJECT}

if oc get project "$PROJECT_NAME" &>/dev/null; then
    print_warning "Project $PROJECT_NAME already exists"
    oc project "$PROJECT_NAME"
else
    print_step "Creating project: $PROJECT_NAME"
    oc new-project "$PROJECT_NAME"
    print_success "Project created"
fi

# Label namespace for RHOAI dashboard visibility
oc label namespace "$PROJECT_NAME" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
echo ""

################################################################################
# Model Selection
################################################################################

print_header "Model Selection"

echo -e "${CYAN}Available models (OCI images - no S3 required):${NC}"
echo ""
echo "  1) Qwen3-4B (4B params) ${GREEN}[Recommended - Fast, Tool Calling]${NC}"
echo "     oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b"
echo ""
echo "  2) Llama 3.2-3B Instruct (3B params)"
echo "     oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct"
echo ""
echo "  3) Granite 3.0-8B Instruct (8B params)"
echo "     oci://quay.io/redhat-ai-services/modelcar-catalog:granite-3.0-8b-instruct"
echo ""
echo "  4) Custom model URI"
echo ""

read -p "Select model (1-4) [1]: " MODEL_CHOICE
MODEL_CHOICE=${MODEL_CHOICE:-1}

case "$MODEL_CHOICE" in
    1)
        MODEL_URI="oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b"
        MODEL_NAME="qwen3-4b"
        MODEL_DISPLAY_NAME="Qwen3-4B"
        TOOL_PARSER="hermes"
        ;;
    2)
        MODEL_URI="oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct"
        MODEL_NAME="llama-3-2-3b"
        MODEL_DISPLAY_NAME="Llama 3.2-3B Instruct"
        TOOL_PARSER="llama3_json"
        ;;
    3)
        MODEL_URI="oci://quay.io/redhat-ai-services/modelcar-catalog:granite-3.0-8b-instruct"
        MODEL_NAME="granite-8b"
        MODEL_DISPLAY_NAME="Granite 3.0-8B Instruct"
        TOOL_PARSER="hermes"
        ;;
    4)
        read -p "Enter model URI: " MODEL_URI
        read -p "Enter model name (no spaces): " MODEL_NAME
        read -p "Enter display name: " MODEL_DISPLAY_NAME
        TOOL_PARSER="hermes"
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
print_success "Selected: $MODEL_DISPLAY_NAME"
echo ""

################################################################################
# Authentication Option
################################################################################

print_header "Authentication Configuration"

echo "MaaS authentication options:"
echo ""
echo "  1) Enable authentication ${GREEN}[Recommended for production]${NC}"
echo "     - Requires token for API access"
echo "     - Protects model from unauthorized access"
echo ""
echo "  2) Disable authentication ${YELLOW}[For testing only]${NC}"
echo "     - Model is publicly accessible"
echo "     - Easier for quick demos"
echo ""

read -p "Enable authentication? (Y/n): " AUTH_CHOICE
AUTH_CHOICE=${AUTH_CHOICE:-Y}

if [[ "$AUTH_CHOICE" =~ ^[Yy]$ ]]; then
    AUTH_ENABLED="true"
    print_info "Authentication will be enabled"
else
    AUTH_ENABLED="false"
    print_warning "Authentication disabled - model will be publicly accessible"
fi
echo ""

################################################################################
# Deploy LLMInferenceService
################################################################################

print_header "Deploying Model with llm-d"

print_step "Creating LLMInferenceService '$MODEL_NAME' in namespace '$PROJECT_NAME'..."
echo ""

cat <<EOF | oc apply -f -
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: $MODEL_NAME
  namespace: $PROJECT_NAME
  labels:
    kueue.x-k8s.io/queue-name: default
    opendatahub.io/dashboard: "true"
    opendatahub.io/genai-asset: "true"
  annotations:
    security.opendatahub.io/enable-auth: "$AUTH_ENABLED"
    openshift.io/display-name: "$MODEL_DISPLAY_NAME"
spec:
  replicas: 1
  model:
    uri: $MODEL_URI
    name: $MODEL_NAME
  router:
    route: {}
    gateway: {}
    scheduler: {}
  template:
    containers:
    - name: main
      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: "--enable-auto-tool-choice --tool-call-parser=$TOOL_PARSER"
      resources:
        limits:
          cpu: '4'
          memory: 16Gi
          nvidia.com/gpu: "1"
        requests:
          cpu: '2'
          memory: 8Gi
          nvidia.com/gpu: "1"
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
EOF

if [ $? -eq 0 ]; then
    print_success "LLMInferenceService created!"
else
    print_error "Failed to create LLMInferenceService"
    exit 1
fi

echo ""

################################################################################
# Wait for Deployment
################################################################################

print_step "Checking deployment status..."
sleep 3

echo ""
echo "Current status:"
oc get llminferenceservice "$MODEL_NAME" -n "$PROJECT_NAME" 2>/dev/null || echo "Waiting for resource to be created..."
echo ""

################################################################################
# Summary and Next Steps
################################################################################

print_header "Deployment Complete!"

echo -e "${GREEN}✓ Model '$MODEL_NAME' deployment initiated${NC}"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Configuration Summary:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Model:          ${GREEN}$MODEL_DISPLAY_NAME${NC}"
echo -e "  Name:           ${GREEN}$MODEL_NAME${NC}"
echo -e "  Namespace:      ${GREEN}$PROJECT_NAME${NC}"
echo -e "  Runtime:        ${GREEN}llm-d (LLMInferenceService)${NC}"
echo -e "  Authentication: $([ "$AUTH_ENABLED" = "true" ] && echo "${GREEN}Enabled${NC}" || echo "${YELLOW}Disabled${NC}")"
echo -e "  Tool Calling:   ${GREEN}Enabled ($TOOL_PARSER parser)${NC}"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Next Steps:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. Wait for model to be ready (5-10 minutes):"
echo -e "   ${YELLOW}oc get llminferenceservice $MODEL_NAME -n $PROJECT_NAME -w${NC}"
echo ""
echo "2. Check pod status:"
echo -e "   ${YELLOW}oc get pods -n $PROJECT_NAME${NC}"
echo ""

# Get the endpoint based on version
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
if is_rhoai_33_or_higher; then
    ENDPOINT="inference-gateway.${CLUSTER_DOMAIN}"
    API_PATH="/$PROJECT_NAME/$MODEL_NAME/v1/chat/completions"
else
    ENDPOINT=$(oc get route maas-api -n maas-api -o jsonpath='{.spec.host}' 2>/dev/null || echo "maas-api.apps.<cluster>")
    API_PATH="/v1/chat/completions"
fi

if [ "$AUTH_ENABLED" = "true" ]; then
    echo "3. Generate API token:"
    echo -e "   ${YELLOW}TOKEN=\$(oc create token default -n $PROJECT_NAME --duration=1h --audience=https://kubernetes.default.svc)${NC}"
    echo ""
    echo "4. Test the model:"
    echo -e "   ${YELLOW}curl -sk -X POST \"https://$ENDPOINT$API_PATH\" \\${NC}"
    echo -e "   ${YELLOW}  -H \"Authorization: Bearer \$TOKEN\" \\${NC}"
    echo -e "   ${YELLOW}  -H \"Content-Type: application/json\" \\${NC}"
    echo -e "   ${YELLOW}  -d '{\"model\": \"$MODEL_NAME\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'${NC}"
    echo ""
    echo ""
    print_info "Note: Token audience must be 'https://kubernetes.default.svc' for RHOAI 3.3+"
else
    echo "3. Test the model (no auth required):"
    echo -e "   ${YELLOW}curl -sk -X POST \"https://$ENDPOINT$API_PATH\" \\${NC}"
    echo -e "   ${YELLOW}  -H \"Content-Type: application/json\" \\${NC}"
    echo -e "   ${YELLOW}  -d '{\"model\": \"$MODEL_NAME\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'${NC}"
fi

echo ""
echo "5. Run the MaaS demo:"
echo -e "   ${YELLOW}./maas-demo/demo-maas.sh${NC}"
echo ""
