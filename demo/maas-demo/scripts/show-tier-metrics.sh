#!/bin/bash
################################################################################
# Show Tier Metrics for MaaS Demo
################################################################################
# Displays rate limiting metrics from Limitador and Gateway to prove
# tier-based rate limiting is working.
#
# Usage:
#   ./show-tier-metrics.sh              # Show all metrics
#   ./show-tier-metrics.sh --watch      # Continuous monitoring
#   ./show-tier-metrics.sh --test       # Run test requests and show metrics
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common functions if available
if [ -f "$PARENT_DIR/lib/common.sh" ]; then
    source "$PARENT_DIR/lib/common.sh"
else
    # Fallback colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    print_header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }
    print_step() { echo -e "${CYAN}→ $1${NC}"; }
    print_success() { echo -e "${GREEN}✓ $1${NC}"; }
    print_error() { echo -e "${RED}✗ $1${NC}"; }
    print_warning() { echo -e "${YELLOW}! $1${NC}"; }
fi

WATCH_MODE=false
TEST_MODE=false
NAMESPACE="${NAMESPACE:-maas-demo}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --watch|-w)
            WATCH_MODE=true
            shift
            ;;
        --test|-t)
            TEST_MODE=true
            shift
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --watch, -w      Continuous monitoring mode"
            echo "  --test, -t       Run test requests and show metrics"
            echo "  -n, --namespace  Namespace (default: maas-demo)"
            echo "  -h, --help       Show this help"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

################################################################################
# Helper Functions
################################################################################

get_limitador_metrics() {
    local pod_ip
    pod_ip=$(oc get pod -n kuadrant-system -l app=limitador -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
    
    if [ -z "$pod_ip" ]; then
        echo "Limitador not found"
        return 1
    fi
    
    oc run metrics-query-$RANDOM --rm -i --restart=Never --image=curlimages/curl -n kuadrant-system -- \
        curl -s "http://${pod_ip}:8080/metrics" 2>/dev/null
}

get_gateway_metrics() {
    local gateway_pod gateway_ip
    gateway_pod=$(oc get pods -n openshift-ingress -l gateway.networking.k8s.io/gateway-name=maas-default-gateway -o name 2>/dev/null | head -1)
    
    if [ -z "$gateway_pod" ]; then
        echo "Gateway not found"
        return 1
    fi
    
    gateway_ip=$(oc get ${gateway_pod} -n openshift-ingress -o jsonpath='{.status.podIP}')
    
    oc run gateway-metrics-$RANDOM --rm -i --restart=Never --image=curlimages/curl -n openshift-ingress -- \
        curl -s "http://${gateway_ip}:15090/stats/prometheus" 2>/dev/null
}

################################################################################
# Main Display
################################################################################

show_metrics() {
    print_header "MaaS Tier Rate Limiting Metrics"
    
    echo -e "${CYAN}Namespace:${NC} $NAMESPACE"
    echo -e "${CYAN}Time:${NC} $(date)"
    echo ""
    
    # Limitador Metrics
    print_step "Fetching Limitador metrics..."
    echo ""
    
    local limitador_metrics
    limitador_metrics=$(get_limitador_metrics 2>/dev/null)
    
    if [ -n "$limitador_metrics" ]; then
        echo -e "${GREEN}Limitador Rate Limiting Stats:${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Parse metrics
        local authorized_calls limited_calls authorized_hits
        authorized_calls=$(echo "$limitador_metrics" | grep "^authorized_calls" | grep -oP '\} \K[0-9]+' | head -1)
        limited_calls=$(echo "$limitador_metrics" | grep "^limited_calls" | grep -oP '\} \K[0-9]+' | head -1)
        authorized_hits=$(echo "$limitador_metrics" | grep "^authorized_hits" | grep -oP '\} \K[0-9]+' | head -1)
        
        printf "  %-25s %s\n" "Authorized Requests:" "${authorized_calls:-0}"
        printf "  %-25s %s\n" "Rate Limited (429):" "${limited_calls:-0}"
        printf "  %-25s %s\n" "Total Hits:" "${authorized_hits:-0}"
        
        if [ "${limited_calls:-0}" -gt 0 ]; then
            echo ""
            echo -e "  ${YELLOW}⚠️  Rate limiting is active! ${limited_calls} requests were blocked.${NC}"
        fi
        echo ""
    else
        print_warning "Could not fetch Limitador metrics"
    fi
    
    # Gateway Response Codes
    print_step "Fetching Gateway metrics..."
    echo ""
    
    local gateway_metrics
    gateway_metrics=$(get_gateway_metrics 2>/dev/null)
    
    if [ -n "$gateway_metrics" ]; then
        echo -e "${GREEN}Gateway Response Codes (to model):${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Extract response codes for the model
        echo "$gateway_metrics" | grep "istio_requests_total" | grep "qwen3-4b" | \
            grep -oP 'response_code="\K[0-9]+' | sort | uniq -c | \
            while read count code; do
                case $code in
                    200) printf "  %-25s %s ${GREEN}(Success)${NC}\n" "HTTP $code:" "$count" ;;
                    401) printf "  %-25s %s ${RED}(Unauthorized)${NC}\n" "HTTP $code:" "$count" ;;
                    429) printf "  %-25s %s ${YELLOW}(Rate Limited)${NC}\n" "HTTP $code:" "$count" ;;
                    *) printf "  %-25s %s\n" "HTTP $code:" "$count" ;;
                esac
            done
        echo ""
    else
        print_warning "Could not fetch Gateway metrics"
    fi
    
    # Tier Information
    echo -e "${GREEN}Configured Tier Limits:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  %-15s %-20s %s\n" "Tier" "Limit" "Groups"
    printf "  %-15s %-20s %s\n" "----" "-----" "------"
    printf "  %-15s %-20s %s\n" "🆓 Free" "10,000 tokens/hr" "system:authenticated"
    printf "  %-15s %-20s %s\n" "⭐ Premium" "50,000 tokens/hr" "tier-premium-users"
    printf "  %-15s %-20s %s\n" "👑 Enterprise" "100,000 tokens/hr" "tier-enterprise-users"
    echo ""
}

################################################################################
# Test Mode
################################################################################

run_tier_test() {
    print_header "Tier Rate Limiting Test"
    
    local cluster_domain maas_endpoint
    cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
    maas_endpoint="inference-gateway.${cluster_domain}"
    
    echo "Testing each tier with API requests..."
    echo ""
    
    for tier in free premium enterprise; do
        local sa_name="tier-${tier}-sa"
        local token
        
        echo -e "${CYAN}Testing ${tier^^} tier...${NC}"
        
        # Generate token
        token=$(oc create token "$sa_name" -n "$NAMESPACE" --duration=5m --audience=https://kubernetes.default.svc 2>/dev/null)
        
        if [ -z "$token" ]; then
            print_warning "Could not generate token for $sa_name"
            continue
        fi
        
        # Find model
        local model_name
        model_name=$(oc get llminferenceservice -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        
        if [ -z "$model_name" ]; then
            print_warning "No model found in $NAMESPACE"
            continue
        fi
        
        # Make request
        local response_code
        response_code=$(curl -sk -o /dev/null -w "%{http_code}" \
            "https://${maas_endpoint}/${NAMESPACE}/${model_name}/v1/chat/completions" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d '{"model": "'"$model_name"'", "messages": [{"role": "user", "content": "Hi"}], "max_tokens": 10}')
        
        case $response_code in
            200) print_success "$tier: HTTP $response_code - Request successful" ;;
            429) print_warning "$tier: HTTP $response_code - Rate limited!" ;;
            401) print_error "$tier: HTTP $response_code - Unauthorized" ;;
            *) echo "  $tier: HTTP $response_code" ;;
        esac
    done
    
    echo ""
    print_step "Fetching updated metrics..."
    echo ""
    show_metrics
}

################################################################################
# Watch Mode
################################################################################

watch_metrics() {
    print_header "Watching Tier Metrics (Ctrl+C to stop)"
    
    while true; do
        clear
        show_metrics
        echo -e "${CYAN}Refreshing in 5 seconds... (Ctrl+C to stop)${NC}"
        sleep 5
    done
}

################################################################################
# Main
################################################################################

if [ "$TEST_MODE" = true ]; then
    run_tier_test
elif [ "$WATCH_MODE" = true ]; then
    watch_metrics
else
    show_metrics
fi
