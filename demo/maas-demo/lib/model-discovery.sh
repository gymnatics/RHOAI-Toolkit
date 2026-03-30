#!/bin/bash
################################################################################
# Model discovery functions for MaaS Demo
################################################################################

# Get all LLMInferenceServices
get_all_models() {
    oc get llminferenceservice -A \
        -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}/{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
        2>/dev/null
}

# Get ready models only
get_ready_models() {
    local models
    models=$(get_all_models)
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            IFS='/' read -r ns name ready <<< "$line"
            if [ "$ready" = "True" ]; then
                echo "$ns/$name"
            fi
        fi
    done <<< "$models"
}

# List models with status
list_models() {
    local models
    models=$(get_all_models)
    
    if [ -z "$models" ]; then
        echo "No LLMInferenceServices found"
        return 1
    fi
    
    echo "Available models:"
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            IFS='/' read -r ns name ready <<< "$line"
            if [ "$ready" = "True" ]; then
                echo "  ✓ $ns/$name (Ready)"
            else
                echo "  ⏳ $ns/$name (Not Ready)"
            fi
        fi
    done <<< "$models"
}

# Select a model interactively
select_model() {
    local ready_models=()
    local line
    
    # Read models into array (compatible with bash 3.2+)
    while IFS= read -r line; do
        [ -n "$line" ] && ready_models+=("$line")
    done < <(get_ready_models)
    
    if [ ${#ready_models[@]} -eq 0 ]; then
        print_error "No ready models found"
        return 1
    fi
    
    if [ ${#ready_models[@]} -eq 1 ]; then
        echo "${ready_models[0]}"
        return 0
    fi
    
    echo "Select a model:" >&2
    select opt in "${ready_models[@]}"; do
        if [ -n "$opt" ]; then
            echo "$opt"
            return 0
        fi
    done
}

# Parse model string (namespace/name) into variables
parse_model() {
    local model_str="$1"
    IFS='/' read -r MODEL_NAMESPACE MODEL_NAME <<< "$model_str"
    export MODEL_NAMESPACE MODEL_NAME
}
