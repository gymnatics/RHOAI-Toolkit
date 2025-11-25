#!/bin/bash

################################################################################
# Check MaaS Security Configuration
################################################################################
# This script checks for models with MaaS enabled but no authentication.
# This is a security risk because the direct route bypasses MaaS policies.
#
# Usage: ./scripts/check-maas-security.sh
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

################################################################################
# Main Check
################################################################################

print_header "MaaS Security Configuration Check"

# Check if logged in
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift"
    echo "Please login first: oc login <cluster-url>"
    exit 1
fi

print_success "Connected to: $(oc whoami --show-server)"
echo ""

# Get cluster domain
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)

if [ -z "$CLUSTER_DOMAIN" ]; then
    print_error "Failed to get cluster domain"
    exit 1
fi

print_info "Cluster domain: $CLUSTER_DOMAIN"
echo ""

# Check for MaaS installation
if ! oc get namespace maas-api &>/dev/null; then
    print_warning "MaaS not installed (maas-api namespace not found)"
    echo "Run: ./scripts/setup-maas.sh"
    exit 0
fi

print_success "MaaS installed"
echo ""

# Check for insecure models
print_header "Checking for Security Issues"

insecure_models=0
secure_models=0
total_maas_models=0

# Get all namespaces (excluding system namespaces)
namespaces=$(oc get ns -o name | grep -v "openshift\|kube\|default\|maas-api\|kuadrant" | sed 's/namespace\///')

echo "Scanning namespaces for models with MaaS enabled..."
echo ""

for ns in $namespaces; do
    # Check for LLMInferenceServices
    models=$(oc get llmisvc -n "$ns" -o json 2>/dev/null | jq -r '.items[].metadata.name' 2>/dev/null || echo "")
    
    if [ -n "$models" ]; then
        for model in $models; do
            # Check if model has MaaS enabled (has HTTPRoute to maas gateway)
            has_maas=$(oc get httproute -n "$ns" -o json 2>/dev/null | \
                       jq -r --arg model "$model" '.items[] | select(.metadata.labels."serving.kserve.io/inferenceservice" == $model and (.spec.parentRefs[]?.name == "maas-default-gateway")) | .metadata.name' 2>/dev/null || echo "")
            
            if [ -n "$has_maas" ]; then
                total_maas_models=$((total_maas_models + 1))
                
                # Check if authentication is enabled
                auth_enabled=$(oc get llmisvc "$model" -n "$ns" -o jsonpath='{.metadata.annotations.security\.opendatahub\.io/enable-auth}' 2>/dev/null || echo "")
                
                if [ "$auth_enabled" == "false" ] || [ -z "$auth_enabled" ]; then
                    print_error "INSECURE: $ns/$model"
                    echo "   MaaS enabled: ✓"
                    echo "   Authentication: ✗ DISABLED"
                    echo "   Direct route (UNPROTECTED): https://maas.${CLUSTER_DOMAIN}/${ns}/${model}/v1/..."
                    echo "   MaaS route (protected): https://maas.${CLUSTER_DOMAIN}/maas-api/v1/models/${ns}/${model}"
                    echo ""
                    echo "   ${YELLOW}Fix:${NC}"
                    echo "   oc annotate llmisvc/$model -n $ns security.opendatahub.io/enable-auth=true --overwrite"
                    echo ""
                    insecure_models=$((insecure_models + 1))
                else
                    print_success "SECURE: $ns/$model"
                    echo "   MaaS enabled: ✓"
                    echo "   Authentication: ✓ ENABLED"
                    echo ""
                    secure_models=$((secure_models + 1))
                fi
            fi
        done
    fi
done

# Summary
print_header "Security Check Summary"

echo "Total models with MaaS: $total_maas_models"
echo "Secure models: ${GREEN}$secure_models${NC}"
echo "Insecure models: ${RED}$insecure_models${NC}"
echo ""

if [ $insecure_models -eq 0 ] && [ $total_maas_models -gt 0 ]; then
    print_success "All MaaS-enabled models have authentication enabled!"
    echo ""
    print_info "Your MaaS deployment is secure."
elif [ $insecure_models -gt 0 ]; then
    print_error "Found $insecure_models insecure model(s)!"
    echo ""
    print_warning "SECURITY RISK:"
    echo "Models with MaaS enabled but no authentication have TWO routes:"
    echo "  1. MaaS Gateway route (protected by MaaS AuthPolicy)"
    echo "  2. Direct route (UNPROTECTED - anyone can access!)"
    echo ""
    print_warning "The direct route bypasses all MaaS policies including:"
    echo "  - Authentication"
    echo "  - Rate limiting"
    echo "  - Billing/usage tracking"
    echo ""
    print_info "To fix, enable authentication on each insecure model using the commands above."
elif [ $total_maas_models -eq 0 ]; then
    print_info "No models with MaaS enabled found."
    echo ""
    echo "To deploy a model with MaaS:"
    echo "  1. Go to RHOAI Dashboard → Deploy Model"
    echo "  2. Select 'llm-d' as serving runtime"
    echo "  3. ✅ Check 'Enable Model as a Service'"
    echo "  4. ✅ Check 'Require authentication' (CRITICAL!)"
fi

echo ""
print_header "Additional Security Recommendations"

echo "1. Always enable BOTH checkboxes when deploying with MaaS:"
echo "   ✅ Enable Model as a Service"
echo "   ✅ Require authentication"
echo ""
echo "2. Use short token expiration times:"
echo "   - 10 minutes for testing"
echo "   - 1 hour for development"
echo "   - 24 hours maximum for production"
echo ""
echo "3. Monitor token usage:"
echo "   - Tokens cannot be revoked (known limitation)"
echo "   - Short expiration is your only protection"
echo ""
echo "4. Regularly audit model deployments:"
echo "   Run this script periodically: ./scripts/check-maas-security.sh"
echo ""

# Exit with error code if insecure models found
if [ $insecure_models -gt 0 ]; then
    exit 1
else
    exit 0
fi

