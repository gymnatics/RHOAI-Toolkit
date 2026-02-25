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

# Get the latest/default channel for an operator from packagemanifest
# Usage: get_operator_channel <package-name> [preferred-channel-pattern]
# Example: get_operator_channel kueue-operator "stable-v1"
get_operator_channel() {
    local package_name="$1"
    local preferred_pattern="${2:-}"
    
    # Get all available channels
    local channels=$(oc get packagemanifest "$package_name" -n openshift-marketplace \
        -o jsonpath='{.status.channels[*].name}' 2>/dev/null)
    
    if [ -z "$channels" ]; then
        echo ""
        return 1
    fi
    
    # If a preferred pattern is specified, try to find a matching channel
    if [ -n "$preferred_pattern" ]; then
        for channel in $channels; do
            if [[ "$channel" == $preferred_pattern* ]]; then
                echo "$channel"
                return 0
            fi
        done
    fi
    
    # Otherwise return the default channel
    local default_channel=$(oc get packagemanifest "$package_name" -n openshift-marketplace \
        -o jsonpath='{.status.defaultChannel}' 2>/dev/null)
    
    if [ -n "$default_channel" ]; then
        echo "$default_channel"
        return 0
    fi
    
    # Fallback: return the last (usually latest) channel
    echo "$channels" | awk '{print $NF}'
}

# Approve any pending InstallPlans for a subscription
# Usage: approve_installplan <subscription-name> <namespace>
approve_installplan() {
    local subscription_name="$1"
    local namespace="$2"
    
    # Get the InstallPlan from the subscription
    local installplan=$(oc get subscription "$subscription_name" -n "$namespace" \
        -o jsonpath='{.status.installPlanRef.name}' 2>/dev/null)
    
    if [ -z "$installplan" ]; then
        return 0
    fi
    
    # Check if it needs approval
    local approved=$(oc get installplan "$installplan" -n "$namespace" \
        -o jsonpath='{.spec.approved}' 2>/dev/null)
    
    if [ "$approved" = "false" ]; then
        print_step "Approving InstallPlan $installplan..."
        oc patch installplan "$installplan" -n "$namespace" \
            --type merge -p '{"spec":{"approved":true}}'
        print_success "InstallPlan approved"
    fi
}

# Wait for operator with InstallPlan approval handling
# Usage: wait_for_operator_with_approval <operator-name> <namespace> [timeout]
wait_for_operator_with_approval() {
    local operator_name="$1"
    local namespace="$2"
    local timeout="${3:-300}"
    
    print_step "Waiting for $operator_name operator to be ready..."
    
    local elapsed=0
    local approval_checked=false
    
    while [ $elapsed -lt $timeout ]; do
        # Check if CSV is succeeded
        if oc get csv -n "$namespace" 2>/dev/null | grep "$operator_name" | grep -q "Succeeded"; then
            print_success "$operator_name operator is ready"
            return 0
        fi
        
        # Check for ResolutionFailed (wrong channel)
        local resolution_failed=$(oc get subscription -n "$namespace" -o json 2>/dev/null | \
            grep -o '"reason":"ConstraintsNotSatisfiable"' | head -1)
        if [ -n "$resolution_failed" ]; then
            print_error "$operator_name subscription failed - check channel configuration"
            return 1
        fi
        
        # Try to approve InstallPlan if not yet checked
        if [ "$approval_checked" = "false" ]; then
            # Find subscription for this operator
            local sub_name=$(oc get subscription -n "$namespace" \
                -o jsonpath='{.items[?(@.spec.name=="'"$operator_name"'")].metadata.name}' 2>/dev/null)
            if [ -n "$sub_name" ]; then
                approve_installplan "$sub_name" "$namespace"
                approval_checked=true
            fi
        fi
        
        echo "Waiting for $operator_name CSV... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_warning "Timeout waiting for $operator_name operator"
    return 1
}

