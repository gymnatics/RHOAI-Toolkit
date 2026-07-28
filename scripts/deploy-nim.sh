#!/bin/bash
################################################################################
# NVIDIA NIM Platform Setup & Model Deployment
################################################################################
# Full NIM enablement script: enables NIM in RHOAI dashboard, creates NGC
# credentials, deploys a NIM model, and sets up monitoring.
#
# This is the comprehensive version — for quick demo deploy only, use:
#   demo/nim-demo/deploy.sh
#
# Usage:
#   ./scripts/deploy-nim.sh                         # Interactive setup
#   ./scripts/deploy-nim.sh --ngc-key nvapi-xxx     # Automated
#   ./scripts/deploy-nim.sh --skip-platform         # Skip RHOAI config, deploy only
#   ./scripts/deploy-nim.sh --delete                # Remove everything
#
# Prerequisites:
#   - RHOAI 3.4+ installed
#   - GPU node (g6e/L40S recommended)
#   - NGC API key from https://org.ngc.nvidia.com/setup/api-keys
#
# Provides:
#   enable_nim_platform()
#   setup_ngc_credentials()
#   deploy_nim_model()
#   verify_nim_deployment()
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"

################################################################################
# Configuration
################################################################################

NAMESPACE="nim-demo"
NGC_API_KEY=""
MODEL_PRESET="nemotron-nano-8b"
GPU_COUNT="1"
DELETE_MODE=false
SKIP_PLATFORM=false
DEPLOY_DASHBOARD=false
WAIT_TIMEOUT=900

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --ngc-key) NGC_API_KEY="$2"; shift 2 ;;
        --model) MODEL_PRESET="$2"; shift 2 ;;
        --gpu-count) GPU_COUNT="$2"; shift 2 ;;
        --skip-platform) SKIP_PLATFORM=true; shift ;;
        --deploy-grafana) DEPLOY_DASHBOARD=true; shift ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            cat <<EOF
Usage: $0 [OPTIONS]

Full NVIDIA NIM platform setup and model deployment on RHOAI

Options:
  -n, --namespace NS      Target namespace (default: nim-demo)
  --ngc-key KEY           NGC API key (will prompt if not provided)
  --model PRESET          Model: nemotron-nano-8b (default), nemotron-nano-4b
  --gpu-count N           GPUs per replica (default: 1)
  --skip-platform         Skip NIM platform enablement, deploy model only
  --deploy-grafana        Deploy NIM Grafana dashboard
  --delete                Remove NIM deployment and platform config
  -h, --help              Show this help

Steps performed:
  1. Enable NIM serving platform in RHOAI (DSC + dashboard)
  2. Create NGC credentials (image pull + API key secrets)
  3. Deploy NIM model (ServingRuntime + InferenceService)
  4. Verify deployment and print access info
  5. (Optional) Deploy NIM Grafana dashboard

NGC API Key:
  Generate at https://org.ngc.nvidia.com/setup/api-keys
  Sign in → Profile → Setup → Generate API Key (Personal)
EOF
            exit 0
            ;;
        *) shift ;;
    esac
done

################################################################################
# Delete Mode
################################################################################

if [ "$DELETE_MODE" = true ]; then
    print_header "Removing NVIDIA NIM Deployment"

    print_step "Removing NIM model resources from $NAMESPACE..."
    oc delete inferenceservice --all -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete servingruntime --all -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete servicemonitor nim-metrics -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete pvc nim-cache-pvc -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete secret nvidia-nim-image-pull nvidia-nim-secrets -n "$NAMESPACE" --ignore-not-found 2>/dev/null

    print_success "NIM resources removed"
    print_info "NIM platform remains enabled in RHOAI (disable manually in DSC if needed)"
    exit 0
fi

################################################################################
# Pre-flight
################################################################################

print_banner() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║        NVIDIA NIM Platform Setup                              ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_banner

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

CLUSTER_DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
print_info "Cluster: ${CLUSTER_DOMAIN}"
print_info "Model: ${MODEL_PRESET}"
print_info "Namespace: ${NAMESPACE}"
echo ""

################################################################################
# Step 1: Enable NIM Platform
################################################################################

enable_nim_platform() {
    print_header "Step 1: Enable NIM Serving Platform"

    # Check if NIM is already enabled
    NIM_STATE=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kserve.nim.managementState}' 2>/dev/null || echo "")

    if [ "$NIM_STATE" = "Managed" ]; then
        print_success "NIM already enabled in DataScienceCluster"
    else
        print_step "Enabling NIM in DataScienceCluster..."
        oc patch datasciencecluster default-dsc --type=merge -p '
{
  "spec": {
    "components": {
      "kserve": {
        "nim": {
          "managementState": "Managed"
        }
      }
    }
  }
}'
        print_success "NIM enabled in DataScienceCluster"
    fi

    # Ensure dashboard has NIM not disabled
    print_step "Verifying dashboard NIM configuration..."
    NIM_DISABLED=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o jsonpath='{.spec.dashboardConfig.disableNIMModelServing}' 2>/dev/null || echo "")

    if [ "$NIM_DISABLED" = "true" ]; then
        print_step "Enabling NIM in dashboard..."
        oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge -p '
{
  "spec": {
    "dashboardConfig": {
      "disableNIMModelServing": false
    }
  }
}'
        print_success "NIM enabled in dashboard"
    else
        print_success "NIM already visible in dashboard"
    fi
}

################################################################################
# Step 2: NGC Credentials
################################################################################

setup_ngc_credentials() {
    print_header "Step 2: NGC Credentials"

    if [ -z "$NGC_API_KEY" ]; then
        echo ""
        echo -e "  ${CYAN}NVIDIA NGC API Key Setup${NC}"
        echo ""
        echo "  To use NIM, you need an NGC API key:"
        echo ""
        echo "  1. Go to https://org.ngc.nvidia.com/setup/api-keys"
        echo "  2. Sign in with your NVIDIA Developer Program account"
        echo "  3. Click 'Generate API Key' → Personal Key"
        echo "  4. Copy the key (starts with nvapi-...)"
        echo ""
        read -rsp "  Enter NGC API Key: " NGC_API_KEY
        echo ""

        if [ -z "$NGC_API_KEY" ]; then
            print_error "NGC API key is required"
            exit 1
        fi
    fi

    ensure_namespace "$NAMESPACE"
    oc label namespace "$NAMESPACE" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true

    # Create image pull secret for nvcr.io
    print_step "Creating NGC image pull secret..."
    oc create secret docker-registry nvidia-nim-image-pull \
        --docker-server=nvcr.io \
        --docker-username='$oauthtoken' \
        --docker-password="${NGC_API_KEY}" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | oc apply -f -
    print_success "Image pull secret created"

    # Create API key secret
    print_step "Creating NGC API key secret..."
    oc create secret generic nvidia-nim-secrets \
        --from-literal=NGC_API_KEY="${NGC_API_KEY}" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | oc apply -f -
    print_success "API key secret created"
}

################################################################################
# Step 3: Deploy Model
################################################################################

deploy_nim_model() {
    print_header "Step 3: Deploy NIM Model"

    # Model configuration
    local MODEL_NAME="$MODEL_PRESET"
    local NIM_IMAGE NIM_TAG DISPLAY_NAME

    case "$MODEL_PRESET" in
        nemotron-nano-8b)
            NIM_IMAGE="llama-3.1-nemotron-nano-8b-v1"
            DISPLAY_NAME="Llama 3.1 Nemotron Nano 8B"
            ;;
        nemotron-nano-4b)
            NIM_IMAGE="llama3.1-nemotron-nano-4b-v1.1"
            DISPLAY_NAME="Llama 3.1 Nemotron Nano 4B"
            ;;
        *)
            print_error "Unknown model preset: $MODEL_PRESET"
            echo "Available: nemotron-nano-8b, nemotron-nano-4b"
            exit 1
            ;;
    esac
    NIM_TAG="latest"

    print_info "Deploying: ${DISPLAY_NAME}"
    print_info "Image: nvcr.io/nim/nvidia/${NIM_IMAGE}:${NIM_TAG}"

    # PVC
    print_step "Creating model cache PVC..."
    export NAMESPACE
    envsubst < "$ROOT_DIR/demo/nim-demo/manifests/nim-pvc.yaml" | oc apply -f -
    print_success "PVC created (50Gi)"

    # Hardware profile resource version (lives in redhat-ods-applications)
    local HARDWARE_PROFILE_NAME="gpu-profile"
    local HARDWARE_PROFILE_NAMESPACE="redhat-ods-applications"
    local HARDWARE_PROFILE_RV
    HARDWARE_PROFILE_RV=$(oc get hardwareprofile "$HARDWARE_PROFILE_NAME" -n "$HARDWARE_PROFILE_NAMESPACE" -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null || echo "1")

    # ServingRuntime
    print_step "Creating NIM ServingRuntime..."
    export MODEL_NAME NIM_IMAGE NIM_TAG DISPLAY_NAME NAMESPACE
    envsubst < "$ROOT_DIR/demo/nim-demo/manifests/nim-servingruntime.yaml" | oc apply -f -
    print_success "ServingRuntime created"

    # InferenceService
    print_step "Creating InferenceService..."
    export GPU_COUNT HARDWARE_PROFILE_NAME HARDWARE_PROFILE_NAMESPACE HARDWARE_PROFILE_RV
    envsubst < "$ROOT_DIR/demo/nim-demo/manifests/nim-inferenceservice.yaml" | oc apply -f -
    print_success "InferenceService created"

    # ServiceMonitor
    if oc api-resources | grep -q servicemonitors; then
        print_step "Creating ServiceMonitor..."
        envsubst < "$ROOT_DIR/demo/nim-demo/manifests/nim-servicemonitor.yaml" | oc apply -f -
        print_success "ServiceMonitor created"
    fi

    unset MODEL_NAME NIM_IMAGE NIM_TAG DISPLAY_NAME NAMESPACE GPU_COUNT
    unset HARDWARE_PROFILE_NAME HARDWARE_PROFILE_NAMESPACE HARDWARE_PROFILE_RV
}

################################################################################
# Step 4: Verify Deployment
################################################################################

verify_nim_deployment() {
    print_header "Step 4: Verify Deployment"

    local MODEL_NAME="$MODEL_PRESET"

    print_step "Waiting for NIM model to load..."
    echo "  (First pull from nvcr.io can take 5-15 minutes)"
    echo ""
    echo "  Monitor logs:"
    echo "    oc logs -f deployment/${MODEL_NAME}-predictor -n $NAMESPACE -c kserve-container"
    echo ""

    local ELAPSED=0
    local READY=false

    while [ $ELAPSED -lt $WAIT_TIMEOUT ]; do
        local STATUS
        STATUS=$(oc get inferenceservice "$MODEL_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [ "$STATUS" = "True" ]; then
            READY=true
            break
        fi
        sleep 30
        ELAPSED=$((ELAPSED + 30))
        echo "  Waiting... (${ELAPSED}s elapsed, status: $STATUS)"
    done

    echo ""
    if [ "$READY" = true ]; then
        print_success "NIM model is serving!"
    else
        print_warning "Model not ready after ${WAIT_TIMEOUT}s"
        print_info "It may still be loading. Check logs above."
    fi

    # Print access info
    local INFERENCE_URL
    INFERENCE_URL=$(oc get inferenceservice "$MODEL_NAME" -n "$NAMESPACE" -o jsonpath='{.status.url}' 2>/dev/null || echo "")
    local DASHBOARD_URL="https://rh-ai.${CLUSTER_DOMAIN}"

    echo ""
    print_header "Access Information"
    echo ""
    echo -e "  ${CYAN}RHOAI Dashboard:${NC}  ${DASHBOARD_URL}"
    echo -e "  ${CYAN}Inference URL:${NC}    ${INFERENCE_URL}"
    echo -e "  ${CYAN}Namespace:${NC}        ${NAMESPACE}"
    echo ""
    echo -e "  ${CYAN}Quick test:${NC}"
    echo "    TOKEN=\$(oc create token default -n $NAMESPACE --duration=1h)"
    echo "    curl -sk ${INFERENCE_URL}/v1/chat/completions \\"
    echo "      -H \"Authorization: Bearer \$TOKEN\" \\"
    echo "      -H \"Content-Type: application/json\" \\"
    echo "      -d '{\"model\": \"${MODEL_NAME}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
    echo ""

    if [ "$READY" = true ]; then
        print_step "Running quick verification..."
        local TOKEN
        TOKEN=$(oc create token default -n "$NAMESPACE" --duration=10m 2>/dev/null || echo "")
        if [ -n "$TOKEN" ] && [ -n "$INFERENCE_URL" ]; then
            local RESPONSE
            RESPONSE=$(curl -sk "${INFERENCE_URL}/v1/chat/completions" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"model\": \"${MODEL_NAME}\", \"messages\": [{\"role\": \"user\", \"content\": \"Say hello in one word.\"}], \"max_tokens\": 10}" \
                2>/dev/null || echo "")
            if echo "$RESPONSE" | grep -q "choices"; then
                print_success "Chat completion working!"
                echo "  Response: $(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'])" 2>/dev/null || echo "$RESPONSE")"
            else
                print_warning "Could not verify — check endpoint manually"
            fi
        fi
    fi
}

################################################################################
# Step 5: NIM Grafana Dashboard (Optional)
################################################################################

deploy_nim_dashboard() {
    if [ "$DEPLOY_DASHBOARD" != true ]; then
        return
    fi

    print_header "Step 5: NIM Grafana Dashboard"

    local DASHBOARD_FILE="$ROOT_DIR/lib/manifests/grafana/nim-dashboard.json"
    if [ ! -f "$DASHBOARD_FILE" ]; then
        print_warning "NIM dashboard JSON not found at $DASHBOARD_FILE"
        return
    fi

    # Check if Grafana is deployed
    if ! oc get deployment grafana -n grafana &>/dev/null; then
        print_warning "Grafana not deployed. Deploy with: ./scripts/deploy-dashboards.sh --deploy-grafana"
        return
    fi

    print_step "Creating NIM dashboard ConfigMap..."
    oc create configmap nim-dashboard \
        --from-file=nim-dashboard.json="$DASHBOARD_FILE" \
        -n grafana \
        --dry-run=client -o yaml | oc apply -f -

    oc label configmap nim-dashboard grafana_dashboard=1 -n grafana --overwrite 2>/dev/null || true
    print_success "NIM Grafana dashboard deployed"
}

################################################################################
# Main
################################################################################

if [ "$SKIP_PLATFORM" != true ]; then
    enable_nim_platform
fi

setup_ngc_credentials
deploy_nim_model
verify_nim_deployment
deploy_nim_dashboard

echo ""
print_success "NVIDIA NIM setup complete!"
print_info "View in GenAI Studio: https://rh-ai.${CLUSTER_DOMAIN}"
