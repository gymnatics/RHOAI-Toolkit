#!/bin/bash

################################################################################
# Configuration Manager
# Saves and loads installation configuration to avoid re-entering details
################################################################################

CONFIG_FILE="${CONFIG_FILE:-$HOME/.openshift-install-config.env}"

################################################################################
# Save Configuration
################################################################################
save_configuration() {
    local config_file="${1:-$CONFIG_FILE}"
    
    cat > "$config_file" << EOF
# OpenShift Installation Configuration
# Generated: $(date)
# This file stores your installation preferences

# Cluster Configuration
CLUSTER_NAME="${CLUSTER_NAME}"
BASE_DOMAIN="${BASE_DOMAIN}"
AWS_REGION="${AWS_REGION}"

# Instance Types
MASTER_INSTANCE_TYPE="${MASTER_INSTANCE_TYPE}"
MASTER_REPLICAS="${MASTER_REPLICAS}"
WORKER_INSTANCE_TYPE="${WORKER_INSTANCE_TYPE}"
WORKER_REPLICAS="${WORKER_REPLICAS}"

# Network Configuration
USE_EXISTING_VPC="${USE_EXISTING_VPC}"
VPC_ID="${VPC_ID}"
VPC_CIDR="${VPC_CIDR}"
SUBNET_IDS_STR="${SUBNET_IDS[@]}"

# SSH Key
SSH_KEY_PATH="${SSH_KEY_PATH}"

# Pull Secret Path (not the actual secret)
PULL_SECRET_PATH="${PULL_SECRET_PATH}"

EOF
    
    chmod 600 "$config_file"
    echo "Configuration saved to: $config_file"
}

################################################################################
# Load Configuration
################################################################################
load_configuration() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if [ ! -f "$config_file" ]; then
        return 1
    fi
    
    # Source the configuration
    source "$config_file"
    
    # Convert subnet IDs string back to array
    if [ -n "$SUBNET_IDS_STR" ]; then
        IFS=' ' read -r -a SUBNET_IDS <<< "$SUBNET_IDS_STR"
    fi
    
    return 0
}

################################################################################
# Check if Configuration Exists
################################################################################
has_saved_configuration() {
    local config_file="${1:-$CONFIG_FILE}"
    [ -f "$config_file" ]
}

################################################################################
# Display Saved Configuration
################################################################################
display_saved_configuration() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if [ ! -f "$config_file" ]; then
        return 1
    fi
    
    source "$config_file"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Saved Configuration Found"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Cluster:"
    echo "  Name:           $CLUSTER_NAME"
    echo "  Domain:         $BASE_DOMAIN"
    echo "  Region:         $AWS_REGION"
    echo ""
    echo "Instance Types:"
    echo "  Master:         $MASTER_INSTANCE_TYPE (x$MASTER_REPLICAS)"
    echo "  Worker:         $WORKER_INSTANCE_TYPE (x$WORKER_REPLICAS)"
    echo ""
    echo "Network:"
    if [ "$USE_EXISTING_VPC" = "true" ]; then
        echo "  VPC:            $VPC_ID (existing)"
        echo "  CIDR:           $VPC_CIDR"
        echo "  Subnets:        ${#SUBNET_IDS[@]} configured"
    else
        echo "  VPC:            Will create new"
        echo "  CIDR:           $VPC_CIDR"
    fi
    echo ""
    echo "Saved: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$config_file" 2>/dev/null || stat -c '%y' "$config_file" 2>/dev/null | cut -d'.' -f1)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

################################################################################
# Prompt to Use Saved Configuration
################################################################################
prompt_use_saved_configuration() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if ! has_saved_configuration "$config_file"; then
        return 1
    fi
    
    display_saved_configuration "$config_file"
    
    echo "Would you like to use this saved configuration?"
    echo ""
    echo "  1) Yes - Use saved configuration (quick)"
    echo "  2) No - Enter new configuration"
    echo "  3) Edit - Modify specific values"
    echo ""
    read -p "Select option [1]: " use_saved
    use_saved="${use_saved:-1}"
    
    case $use_saved in
        1)
            load_configuration "$config_file"
            return 0
            ;;
        2)
            return 1
            ;;
        3)
            load_configuration "$config_file"
            interactive_edit_configuration
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

################################################################################
# Interactive Configuration Editor
################################################################################
interactive_edit_configuration() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Edit Configuration"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Press Enter to keep current value, or type new value"
    echo ""
    
    # Cluster Name
    read -p "Cluster name [$CLUSTER_NAME]: " new_value
    [ -n "$new_value" ] && CLUSTER_NAME="$new_value"
    
    # Domain
    read -p "Base domain [$BASE_DOMAIN]: " new_value
    [ -n "$new_value" ] && BASE_DOMAIN="$new_value"
    
    # Region
    read -p "AWS region [$AWS_REGION]: " new_value
    [ -n "$new_value" ] && AWS_REGION="$new_value"
    
    # Master instance type
    read -p "Master instance type [$MASTER_INSTANCE_TYPE]: " new_value
    [ -n "$new_value" ] && MASTER_INSTANCE_TYPE="$new_value"
    
    # Master replicas
    read -p "Master replicas [$MASTER_REPLICAS]: " new_value
    [ -n "$new_value" ] && MASTER_REPLICAS="$new_value"
    
    # Worker instance type
    read -p "Worker instance type [$WORKER_INSTANCE_TYPE]: " new_value
    [ -n "$new_value" ] && WORKER_INSTANCE_TYPE="$new_value"
    
    # Worker replicas
    read -p "Worker replicas [$WORKER_REPLICAS]: " new_value
    [ -n "$new_value" ] && WORKER_REPLICAS="$new_value"
    
    # VPC CIDR (if creating new)
    if [ "$USE_EXISTING_VPC" != "true" ]; then
        read -p "VPC CIDR [$VPC_CIDR]: " new_value
        [ -n "$new_value" ] && VPC_CIDR="$new_value"
    fi
    
    echo ""
    echo "Configuration updated!"
    echo ""
}

################################################################################
# Clear Saved Configuration
################################################################################
clear_saved_configuration() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if [ -f "$config_file" ]; then
        rm -f "$config_file"
        echo "Saved configuration cleared"
    fi
}

################################################################################
# Export Configuration for Use in Scripts
################################################################################
export_configuration() {
    export CLUSTER_NAME
    export BASE_DOMAIN
    export AWS_REGION
    export MASTER_INSTANCE_TYPE
    export MASTER_REPLICAS
    export WORKER_INSTANCE_TYPE
    export WORKER_REPLICAS
    export USE_EXISTING_VPC
    export VPC_ID
    export VPC_CIDR
    export SSH_KEY_PATH
    export PULL_SECRET_PATH
}

