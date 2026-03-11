#!/bin/bash
################################################################################
# MaaS Interactive Demo
################################################################################
# Interactive demonstration of Model as a Service (MaaS) on OpenShift AI
#
# Features:
#   - Check MaaS status and list models
#   - Generate API tokens
#   - Chat with models (with streaming)
#   - Compare multiple models
#   - View response metrics
#
# Usage:
#   ./demo-maas.sh [--endpoint URL] [--token TOKEN]
#
################################################################################

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Global variables
MAAS_ENDPOINT=""
MAAS_TOKEN=""
RHOAI_VERSION=""
LAST_RESPONSE=""
LAST_LATENCY=""
LAST_TOKENS=""

################################################################################
# Helper Functions
################################################################################

print_header() {
    clear
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          ${BOLD}MaaS Interactive Demo${NC}${CYAN}                               ║${NC}"
    echo -e "${CYAN}║          Model as a Service on OpenShift AI                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    if [ -n "$MAAS_ENDPOINT" ]; then
        echo -e "${GREEN}✓ Connected: ${NC}$MAAS_ENDPOINT"
        echo -e "${GREEN}✓ RHOAI Version: ${NC}$RHOAI_VERSION"
    fi
    echo ""
}

print_menu() {
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Check MaaS Status"
    echo "   Show RHOAI version, endpoint, available models"
    echo ""
    echo -e "${YELLOW}2)${NC} Generate Token"
    echo "   Create API token with custom duration"
    echo ""
    echo -e "${YELLOW}3)${NC} Chat with Model"
    echo "   Interactive chat session"
    echo ""
    echo -e "${YELLOW}4)${NC} Compare Models"
    echo "   Same prompt to multiple models"
    echo ""
    echo -e "${YELLOW}5)${NC} View Last Response Metrics"
    echo "   Latency, token usage from last request"
    echo ""
    echo -e "${YELLOW}0)${NC} Exit"
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

################################################################################
# MaaS Detection and Setup
################################################################################

detect_maas_endpoint() {
    print_step "Detecting MaaS endpoint..."
    
    # Check if oc is available and logged in
    if ! command -v oc &>/dev/null; then
        print_error "oc CLI not found"
        return 1
    fi
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        return 1
    fi
    
    # Detect RHOAI version
    local csv_version=$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift AI")].spec.version}' 2>/dev/null | head -1)
    
    if [ -n "$csv_version" ]; then
        RHOAI_VERSION="$csv_version"
    else
        RHOAI_VERSION="unknown"
    fi
    
    # Get cluster domain
    local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
    
    if [ -z "$cluster_domain" ]; then
        print_error "Could not get cluster domain"
        return 1
    fi
    
    # Determine endpoint based on version
    local major_version=$(echo "$RHOAI_VERSION" | cut -d. -f1,2)
    
    case "$major_version" in
        3.3|3.4|3.5|3.6|3.7|3.8|3.9|4.*)
            # RHOAI 3.3+ uses inference-gateway
            MAAS_ENDPOINT="inference-gateway.${cluster_domain}"
            ;;
        *)
            # Legacy uses maas endpoint
            MAAS_ENDPOINT="maas.${cluster_domain}"
            ;;
    esac
    
    print_success "Detected endpoint: $MAAS_ENDPOINT"
    print_success "RHOAI version: $RHOAI_VERSION"
    return 0
}

check_token() {
    if [ -z "$MAAS_TOKEN" ]; then
        # Try to load from file
        if [ -f "$DEMO_DIR/maas-token.txt" ]; then
            MAAS_TOKEN=$(cat "$DEMO_DIR/maas-token.txt")
            print_success "Loaded token from maas-token.txt"
        else
            print_info "No token found. Generate one with option 2."
            return 1
        fi
    fi
    return 0
}

################################################################################
# Menu Options
################################################################################

# Option 1: Check MaaS Status
check_maas_status() {
    print_header
    echo -e "${BOLD}MaaS Status${NC}"
    echo ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Configuration${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "RHOAI Version:  ${GREEN}$RHOAI_VERSION${NC}"
    echo -e "MaaS Endpoint:  ${GREEN}https://$MAAS_ENDPOINT${NC}"
    echo -e "Token Status:   $([ -n "$MAAS_TOKEN" ] && echo "${GREEN}Loaded${NC}" || echo "${YELLOW}Not set${NC}")"
    echo ""
    
    # List available models
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Available Models${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if command -v oc &>/dev/null && oc whoami &>/dev/null; then
        # Check for LLMInferenceService (RHOAI 3.3+)
        local llm_models=$(oc get llminferenceservice -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} ({.status.conditions[?(@.type=="Ready")].status}){"\n"}{end}' 2>/dev/null || echo "")
        
        if [ -n "$llm_models" ]; then
            echo -e "${CYAN}LLMInferenceService models:${NC}"
            echo "$llm_models" | while read -r line; do
                if [ -n "$line" ]; then
                    echo "  • $line"
                fi
            done
            echo ""
        fi
        
        # Check for InferenceService with MaaS annotation
        local isvc_models=$(oc get inferenceservice -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} ({.status.conditions[?(@.type=="Ready")].status}){"\n"}{end}' 2>/dev/null || echo "")
        
        if [ -n "$isvc_models" ]; then
            echo -e "${CYAN}InferenceService models:${NC}"
            echo "$isvc_models" | while read -r line; do
                if [ -n "$line" ]; then
                    echo "  • $line"
                fi
            done
            echo ""
        fi
        
        if [ -z "$llm_models" ] && [ -z "$isvc_models" ]; then
            echo -e "${YELLOW}No models found${NC}"
            echo ""
            echo "Deploy a model with:"
            echo "  ./demo/setup-demo-model.sh"
        fi
    else
        echo -e "${YELLOW}Cannot list models (oc not available or not logged in)${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Option 2: Generate Token
generate_token() {
    print_header
    echo -e "${BOLD}Generate API Token${NC}"
    echo ""
    
    if ! command -v oc &>/dev/null || ! oc whoami &>/dev/null; then
        print_error "oc CLI required and must be logged in"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "Token duration options:"
    echo "  1) 1 hour"
    echo "  2) 8 hours"
    echo "  3) 24 hours"
    echo "  4) Custom"
    echo ""
    
    read -p "Select duration (1-4): " duration_choice
    
    case $duration_choice in
        1) DURATION="1h" ;;
        2) DURATION="8h" ;;
        3) DURATION="24h" ;;
        4) 
            read -p "Enter duration (e.g., 2h, 30m): " DURATION
            ;;
        *) DURATION="1h" ;;
    esac
    
    echo ""
    print_step "Generating token with duration: $DURATION"
    
    # Get current namespace or use default
    local namespace=$(oc project -q 2>/dev/null || echo "default")
    
    # Generate token
    MAAS_TOKEN=$(oc create token default -n "$namespace" --duration="$DURATION" 2>/dev/null)
    
    if [ -n "$MAAS_TOKEN" ]; then
        print_success "Token generated!"
        echo ""
        echo -e "${CYAN}Token (first 50 chars):${NC}"
        echo "  ${MAAS_TOKEN:0:50}..."
        echo ""
        
        # Save to file
        echo "$MAAS_TOKEN" > "$DEMO_DIR/maas-token.txt"
        print_success "Token saved to demo/maas-token.txt"
        echo ""
        echo -e "${YELLOW}Token expires in: $DURATION${NC}"
    else
        print_error "Failed to generate token"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Option 3: Chat with Model
chat_with_model() {
    print_header
    echo -e "${BOLD}Chat with Model${NC}"
    echo ""
    
    if ! check_token; then
        echo ""
        echo "Generate a token first (option 2)"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Get model name
    echo "Enter model name (or press Enter for 'demo-model'):"
    read -p "> " model_name
    model_name=${model_name:-demo-model}
    
    echo ""
    echo -e "${CYAN}Chatting with: $model_name${NC}"
    echo -e "${CYAN}Type 'quit' to exit, 'stream' to toggle streaming${NC}"
    echo ""
    
    local streaming=false
    
    while true; do
        echo -e "${BLUE}You:${NC}"
        read -p "> " user_input
        
        if [ "$user_input" = "quit" ]; then
            break
        fi
        
        if [ "$user_input" = "stream" ]; then
            streaming=$([ "$streaming" = true ] && echo false || echo true)
            echo -e "${YELLOW}Streaming: $streaming${NC}"
            continue
        fi
        
        if [ -z "$user_input" ]; then
            continue
        fi
        
        echo ""
        
        # Make API request
        local start_time=$(date +%s%3N)
        
        if [ "$streaming" = true ]; then
            echo -e "${GREEN}Assistant:${NC}"
            curl -sN -X POST "https://$MAAS_ENDPOINT/v1/chat/completions" \
                -H "Authorization: Bearer $MAAS_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{
                    \"model\": \"$model_name\",
                    \"messages\": [{\"role\": \"user\", \"content\": \"$user_input\"}],
                    \"max_tokens\": 500,
                    \"stream\": true
                }" 2>/dev/null | while read -r line; do
                    if [[ "$line" == data:* ]]; then
                        local content=$(echo "${line#data: }" | jq -r '.choices[0].delta.content // empty' 2>/dev/null)
                        if [ -n "$content" ]; then
                            echo -n "$content"
                        fi
                    fi
                done
            echo ""
        else
            LAST_RESPONSE=$(curl -s -X POST "https://$MAAS_ENDPOINT/v1/chat/completions" \
                -H "Authorization: Bearer $MAAS_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{
                    \"model\": \"$model_name\",
                    \"messages\": [{\"role\": \"user\", \"content\": \"$user_input\"}],
                    \"max_tokens\": 500
                }" 2>/dev/null)
            
            local end_time=$(date +%s%3N)
            LAST_LATENCY=$((end_time - start_time))
            
            local content=$(echo "$LAST_RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
            LAST_TOKENS=$(echo "$LAST_RESPONSE" | jq -r '.usage.total_tokens // "N/A"' 2>/dev/null)
            
            if [ -n "$content" ]; then
                echo -e "${GREEN}Assistant:${NC}"
                echo "$content"
                echo ""
                echo -e "${CYAN}[${LAST_LATENCY}ms | ${LAST_TOKENS} tokens]${NC}"
            else
                print_error "No response received"
                echo "$LAST_RESPONSE" | jq . 2>/dev/null || echo "$LAST_RESPONSE"
            fi
        fi
        
        echo ""
    done
}

# Option 4: Compare Models
compare_models() {
    print_header
    echo -e "${BOLD}Compare Models${NC}"
    echo ""
    
    if ! check_token; then
        echo ""
        echo "Generate a token first (option 2)"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "Enter first model name:"
    read -p "> " model1
    model1=${model1:-demo-model}
    
    echo "Enter second model name:"
    read -p "> " model2
    
    if [ -z "$model2" ]; then
        print_error "Need two models to compare"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    echo "Enter prompt to send to both models:"
    read -p "> " prompt
    
    if [ -z "$prompt" ]; then
        prompt="Explain what Red Hat OpenShift AI is in 2-3 sentences."
    fi
    
    echo ""
    echo -e "${CYAN}Sending prompt to both models...${NC}"
    echo ""
    
    # Query model 1
    local start1=$(date +%s%3N)
    local response1=$(curl -s -X POST "https://$MAAS_ENDPOINT/v1/chat/completions" \
        -H "Authorization: Bearer $MAAS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model1\",
            \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
            \"max_tokens\": 300
        }" 2>/dev/null)
    local end1=$(date +%s%3N)
    local latency1=$((end1 - start1))
    
    # Query model 2
    local start2=$(date +%s%3N)
    local response2=$(curl -s -X POST "https://$MAAS_ENDPOINT/v1/chat/completions" \
        -H "Authorization: Bearer $MAAS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model2\",
            \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
            \"max_tokens\": 300
        }" 2>/dev/null)
    local end2=$(date +%s%3N)
    local latency2=$((end2 - start2))
    
    # Display results
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Prompt:${NC} $prompt"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${GREEN}Model 1: $model1${NC} [${latency1}ms]"
    echo -e "${CYAN}─────────────────────────────────────────${NC}"
    local content1=$(echo "$response1" | jq -r '.choices[0].message.content // "Error: No response"' 2>/dev/null)
    echo "$content1"
    echo ""
    
    echo -e "${GREEN}Model 2: $model2${NC} [${latency2}ms]"
    echo -e "${CYAN}─────────────────────────────────────────${NC}"
    local content2=$(echo "$response2" | jq -r '.choices[0].message.content // "Error: No response"' 2>/dev/null)
    echo "$content2"
    echo ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Comparison Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    printf "%-20s | %-15s | %-15s\n" "Metric" "$model1" "$model2"
    printf "%-20s | %-15s | %-15s\n" "--------------------" "---------------" "---------------"
    printf "%-20s | %-15s | %-15s\n" "Response Time" "${latency1}ms" "${latency2}ms"
    
    local tokens1=$(echo "$response1" | jq -r '.usage.total_tokens // "N/A"' 2>/dev/null)
    local tokens2=$(echo "$response2" | jq -r '.usage.total_tokens // "N/A"' 2>/dev/null)
    printf "%-20s | %-15s | %-15s\n" "Total Tokens" "$tokens1" "$tokens2"
    echo ""
    
    read -p "Press Enter to continue..."
}

# Option 5: View Metrics
view_metrics() {
    print_header
    echo -e "${BOLD}Last Response Metrics${NC}"
    echo ""
    
    if [ -z "$LAST_RESPONSE" ]; then
        print_info "No previous request. Chat with a model first (option 3)."
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Performance Metrics${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "Response Latency:    ${GREEN}${LAST_LATENCY}ms${NC}"
    echo ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Token Usage${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local usage=$(echo "$LAST_RESPONSE" | jq '.usage' 2>/dev/null)
    if [ -n "$usage" ] && [ "$usage" != "null" ]; then
        echo "$usage" | jq .
    else
        echo "Token usage not available"
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Full Response (JSON)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "Show full JSON response? (y/n): " show_json
    if [[ "$show_json" =~ ^[Yy]$ ]]; then
        echo "$LAST_RESPONSE" | jq .
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# Main
################################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --endpoint)
                MAAS_ENDPOINT="$2"
                shift 2
                ;;
            --token)
                MAAS_TOKEN="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [--endpoint URL] [--token TOKEN]"
                echo ""
                echo "Options:"
                echo "  --endpoint URL    MaaS endpoint URL"
                echo "  --token TOKEN     API token"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    
    # Auto-detect endpoint if not provided
    if [ -z "$MAAS_ENDPOINT" ]; then
        detect_maas_endpoint || {
            echo ""
            echo "Could not auto-detect MaaS endpoint."
            read -p "Enter MaaS endpoint URL: " MAAS_ENDPOINT
            if [ -z "$MAAS_ENDPOINT" ]; then
                print_error "MaaS endpoint required"
                exit 1
            fi
        }
    fi
    
    # Try to load token
    check_token 2>/dev/null || true
    
    # Main menu loop
    while true; do
        print_header
        print_menu
        
        read -p "Select option (0-5): " choice
        
        case $choice in
            1) check_maas_status ;;
            2) generate_token ;;
            3) chat_with_model ;;
            4) compare_models ;;
            5) view_metrics ;;
            0) 
                echo ""
                echo "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

main "$@"
