#!/bin/bash
################################################################################
# Model catalog for MaaS Demo
# Compatible with bash 3.x (macOS default)
################################################################################

# Model definitions: name|display_name|uri|tool_parser
# Using indexed arrays for bash 3.x compatibility
MODEL_KEYS=("qwen3-4b" "llama-3.2-3b" "mistral-7b" "granite-3.2-8b")
MODEL_VALUES=(
    "Qwen3-4B|oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b|hermes"
    "Llama 3.2-3B Instruct|oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct|llama3_json"
    "Mistral-7B Instruct|oci://quay.io/redhat-ai-services/modelcar-catalog:mistral-7b-instruct-v0.3|mistral"
    "Granite 3.2-8B Instruct|oci://quay.io/redhat-ai-services/modelcar-catalog:granite-3.2-8b-instruct|hermes"
)

# Get index of model key
_get_model_index() {
    local key="$1"
    for i in "${!MODEL_KEYS[@]}"; do
        if [ "${MODEL_KEYS[$i]}" = "$key" ]; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# List available models
list_catalog_models() {
    echo "Available models in catalog:"
    echo ""
    for i in "${!MODEL_KEYS[@]}"; do
        local key="${MODEL_KEYS[$i]}"
        local value="${MODEL_VALUES[$i]}"
        IFS='|' read -r display_name uri parser <<< "$value"
        echo "  $key - $display_name"
    done
    echo ""
}

# Get model info
get_model_info() {
    local model_key="$1"
    local idx
    idx=$(_get_model_index "$model_key")
    
    if [ -z "$idx" ]; then
        return 1
    fi
    
    echo "${MODEL_VALUES[$idx]}"
}

# Parse model info into variables
parse_model_info() {
    local model_key="$1"
    local info
    info=$(get_model_info "$model_key")
    
    if [ -z "$info" ]; then
        return 1
    fi
    
    IFS='|' read -r MODEL_DISPLAY_NAME MODEL_URI TOOL_PARSER <<< "$info"
    export MODEL_DISPLAY_NAME MODEL_URI TOOL_PARSER
}

# Select model interactively
select_catalog_model() {
    echo "Select a model to deploy:"
    select opt in "${MODEL_KEYS[@]}"; do
        if [ -n "$opt" ]; then
            echo "$opt"
            return 0
        fi
    done
}
