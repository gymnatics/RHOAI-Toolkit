#!/bin/bash
################################################################################
# Common utility functions
################################################################################

# Get the directory where the script is located
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

# Apply a manifest file
apply_manifest() {
    local manifest_file="$1"
    local description="${2:-manifest}"
    
    if [ ! -f "$manifest_file" ]; then
        print_error "Manifest file not found: $manifest_file"
        return 1
    fi
    
    print_step "Applying $description..."
    if oc apply -f "$manifest_file"; then
        print_success "$description applied"
        return 0
    else
        print_error "Failed to apply $description"
        return 1
    fi
}

# Wait for a resource to exist
wait_for_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="${3:-}"
    local timeout="${4:-300}"
    local description="${5:-$resource_type $resource_name}"
    
    local ns_flag=""
    if [ -n "$namespace" ]; then
        ns_flag="-n $namespace"
    fi
    
    print_step "Waiting for $description..."
    
    local elapsed=0
    until oc get $resource_type $resource_name $ns_flag &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_error "Timeout waiting for $description"
            return 1
        fi
        echo "Waiting for $description... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "$description is ready"
    return 0
}

# Check if operator is installed
check_operator_installed() {
    local operator_name="$1"
    local namespace="$2"
    
    if oc get subscription "$operator_name" -n "$namespace" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Wait for operator to be ready
wait_for_operator_ready() {
    local operator_name="$1"
    local namespace="$2"
    local timeout="${3:-300}"
    
    print_step "Waiting for $operator_name operator to be ready..."
    
    local elapsed=0
    until oc get csv -n "$namespace" 2>/dev/null | grep "$operator_name" | grep -q "Succeeded"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for $operator_name operator"
            return 1
        fi
        echo "Waiting for $operator_name CSV... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "$operator_name operator is ready"
    return 0
}

# Check if namespace exists, create if not
ensure_namespace() {
    local namespace="$1"
    
    if oc get namespace "$namespace" &>/dev/null; then
        print_success "Namespace $namespace already exists"
    else
        print_step "Creating namespace $namespace..."
        oc create namespace "$namespace"
        print_success "Namespace $namespace created"
    fi
}

