#!/bin/bash

#############################################################################
# OpenShift Master Installation Script
# Purpose: All-in-one script for OpenShift installation on AWS
# Combines: Prerequisites check, version download, and automated installation
#############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
INSTALL_DIR=""
CLUSTER_NAME=""
BASE_DOMAIN=""
AWS_REGION=""
AZS=()
MASTER_INSTANCE_TYPE=""
MASTER_REPLICAS=""
WORKER_INSTANCE_TYPE=""
WORKER_REPLICAS=""
VPC_CIDR=""
MACHINE_CIDR=""
VPC_ID=""
SUBNET_IDS=()
PULL_SECRET=""
SSH_KEY=""
INSTALL_TYPE=""

#############################################################################
# Utility Functions
#############################################################################

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${CYAN}=========================================="
    echo -e "  $1"
    echo -e "==========================================${NC}"
    echo ""
}

prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    read -p "$(echo -e ${BLUE}${prompt}${NC} [${GREEN}${default}${NC}]: )" input
    eval $var_name="${input:-$default}"
}

press_any_key() {
    echo ""
    read -p "Press any key to continue..." -n 1 -r
    echo ""
}

#############################################################################
# AWS Configuration Function
#############################################################################

configure_aws_credentials() {
    print_header "AWS Credentials Configuration"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        echo ""
        echo "Install AWS CLI:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  brew install awscli"
        else
            echo "  Visit: https://aws.amazon.com/cli/"
        fi
        press_any_key
        return 1
    fi
    
    # Check if credentials already exist
    if aws sts get-caller-identity &> /dev/null; then
        print_success "AWS credentials are already configured"
        CALLER_IDENTITY=$(aws sts get-caller-identity)
        ACCOUNT_ID=$(echo $CALLER_IDENTITY | jq -r '.Account' 2>/dev/null || echo "N/A")
        USER_ARN=$(echo $CALLER_IDENTITY | jq -r '.Arn' 2>/dev/null || echo "N/A")
        echo ""
        echo "Current configuration:"
        echo "  Account ID: $ACCOUNT_ID"
        echo "  User/Role:  $USER_ARN"
        echo ""
        
        read -p "$(echo -e ${BLUE}Do you want to reconfigure AWS credentials?${NC} [y/N]: )" reconfigure
        if [[ "$reconfigure" != "y" && "$reconfigure" != "Y" ]]; then
            print_info "Keeping existing AWS configuration"
            press_any_key
            return 0
        fi
    fi
    
    echo ""
    print_info "You need AWS credentials to install OpenShift on AWS"
    echo ""
    echo "You can find your credentials in the AWS Console:"
    echo "  1. Go to: https://console.aws.amazon.com/"
    echo "  2. Click your username → Security credentials"
    echo "  3. Create access key if you don't have one"
    echo ""
    
    read -p "$(echo -e ${BLUE}Do you want to configure AWS credentials now?${NC} [Y/n]: )" configure_now
    if [[ "$configure_now" == "n" || "$configure_now" == "N" ]]; then
        print_info "Skipping AWS configuration"
        press_any_key
        return 1
    fi
    
    echo ""
    print_info "Enter your AWS credentials:"
    echo ""
    
    # Prompt for Access Key ID
    read -p "$(echo -e ${BLUE}AWS Access Key ID${NC}: )" aws_access_key
    if [ -z "$aws_access_key" ]; then
        print_error "Access Key ID cannot be empty"
        press_any_key
        return 1
    fi
    
    # Prompt for Secret Access Key (hidden input)
    read -s -p "$(echo -e ${BLUE}AWS Secret Access Key${NC}: )" aws_secret_key
    echo ""
    if [ -z "$aws_secret_key" ]; then
        print_error "Secret Access Key cannot be empty"
        press_any_key
        return 1
    fi
    
    # Prompt for Default Region
    read -p "$(echo -e ${BLUE}Default region${NC} [us-east-2]: )" aws_region
    aws_region="${aws_region:-us-east-2}"
    
    # Prompt for Output Format
    read -p "$(echo -e ${BLUE}Default output format${NC} [json]: )" aws_output
    aws_output="${aws_output:-json}"
    
    # Configure AWS CLI
    print_info "Configuring AWS CLI..."
    
    # Create AWS config directory if it doesn't exist
    mkdir -p "$HOME/.aws"
    
    # Write credentials file
    cat > "$HOME/.aws/credentials" <<EOF
[default]
aws_access_key_id = ${aws_access_key}
aws_secret_access_key = ${aws_secret_key}
EOF
    
    # Write config file
    cat > "$HOME/.aws/config" <<EOF
[default]
region = ${aws_region}
output = ${aws_output}
EOF
    
    # Set secure permissions
    chmod 600 "$HOME/.aws/credentials"
    chmod 600 "$HOME/.aws/config"
    
    # Verify configuration
    print_info "Verifying AWS credentials..."
    if aws sts get-caller-identity &> /dev/null; then
        print_success "AWS credentials configured successfully!"
        echo ""
        CALLER_IDENTITY=$(aws sts get-caller-identity)
        ACCOUNT_ID=$(echo $CALLER_IDENTITY | jq -r '.Account' 2>/dev/null || echo "N/A")
        USER_ARN=$(echo $CALLER_IDENTITY | jq -r '.Arn' 2>/dev/null || echo "N/A")
        echo "Account ID: $ACCOUNT_ID"
        echo "User/Role:  $USER_ARN"
        echo "Region:     $aws_region"
    else
        print_error "Failed to verify AWS credentials"
        echo ""
        echo "Please check your credentials and try again"
        press_any_key
        return 1
    fi
    
    press_any_key
}

#############################################################################
# Prerequisites Check Functions
#############################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local all_good=true
    
    # Check for AWS CLI
    print_info "Checking for AWS CLI..."
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        echo "Install: brew install awscli"
        all_good=false
    else
        print_success "AWS CLI installed: $(aws --version 2>&1 | head -1)"
    fi
    
    # Check for jq
    print_info "Checking for jq..."
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Attempting to install..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &> /dev/null; then
                brew install jq 2>/dev/null || print_error "Failed to install jq"
            else
                print_error "Homebrew not found. Please install jq manually"
                all_good=false
            fi
        else
            print_error "Please install jq manually"
            all_good=false
        fi
    else
        print_success "jq installed"
    fi
    
    # Check AWS credentials
    print_info "Checking AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        echo ""
        echo "Configure AWS credentials:"
        echo "  aws configure"
        echo ""
        all_good=false
    else
        CALLER_IDENTITY=$(aws sts get-caller-identity)
        ACCOUNT_ID=$(echo $CALLER_IDENTITY | jq -r '.Account')
        USER_ARN=$(echo $CALLER_IDENTITY | jq -r '.Arn')
        print_success "AWS credentials configured"
        echo "  Account ID: $ACCOUNT_ID"
        echo "  User/Role:  $USER_ARN"
    fi
    
    # Check for openshift-install binary
    print_info "Checking for openshift-install binary..."
    if [ ! -f "./openshift-install" ]; then
        print_warning "openshift-install binary not found"
        echo "You can download it from the main menu"
    else
        print_success "openshift-install binary found"
        ./openshift-install version 2>/dev/null || print_warning "Could not verify version"
    fi
    
    # Check for pull secret
    print_info "Checking for pull secret..."
    if [ -f "$HOME/.openshift/pull-secret.json" ]; then
        print_success "Pull secret found at $HOME/.openshift/pull-secret.json"
    else
        print_warning "Pull secret not found"
        echo "Download from: https://console.redhat.com/openshift/install/pull-secret"
    fi
    
    # Check for SSH key
    print_info "Checking for SSH key..."
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        print_success "SSH key found at $HOME/.ssh/id_rsa.pub"
    else
        print_warning "SSH key not found (will be generated during installation)"
    fi
    
    echo ""
    if [ "$all_good" = true ]; then
        print_success "All prerequisites met!"
    else
        print_warning "Some prerequisites are missing. Please address them before installation."
    fi
    
    press_any_key
}

check_aws_quotas() {
    print_header "Checking AWS Service Quotas"
    
    read -p "$(echo -e ${BLUE}Enter AWS region to check${NC} [us-east-2]: )" region
    region="${region:-us-east-2}"
    
    print_info "Checking quotas in $region..."
    
    # Check VPCs
    print_info "Checking VPCs..."
    vpc_count=$(aws ec2 describe-vpcs --region $region --query 'Vpcs | length(@)' --output text 2>/dev/null || echo "0")
    echo "  Current VPCs: $vpc_count"
    
    # Check H100 availability
    print_info "Checking H100 (p5.48xlarge) availability..."
    available_azs=$(aws ec2 describe-instance-type-offerings \
        --location-type availability-zone \
        --region $region \
        --filters Name=instance-type,Values=p5.48xlarge \
        --query 'InstanceTypeOfferings[].Location' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$available_azs" ]; then
        print_success "H100 instances available in: $available_azs"
    else
        print_warning "H100 instances may not be available or require quota increase"
    fi
    
    # Check other GPU instances
    print_info "Checking other GPU instances in $region..."
    for instance_type in "p4d.24xlarge" "p3.2xlarge" "g6e.xlarge" "g6e.2xlarge" "g6e.4xlarge" "g5.xlarge"; do
        available=$(aws ec2 describe-instance-type-offerings \
            --location-type availability-zone \
            --region $region \
            --filters Name=instance-type,Values=$instance_type \
            --query 'InstanceTypeOfferings[].Location' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$available" ]; then
            echo "  ✓ $instance_type available in: $available"
        fi
    done
    
    press_any_key
}

#############################################################################
# Download OpenShift Installer
#############################################################################

download_installer() {
    print_header "Download OpenShift Installer"
    
    # Detect architecture
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    if [[ "$OS" == "darwin" ]]; then
        if [[ "$ARCH" == "arm64" ]]; then
            PLATFORM="mac-arm64"
        else
            PLATFORM="mac"
        fi
    elif [[ "$OS" == "linux" ]]; then
        if [[ "$ARCH" == "x86_64" ]]; then
            PLATFORM="linux"
        elif [[ "$ARCH" == "aarch64" ]]; then
            PLATFORM="linux-arm64"
        else
            print_error "Unsupported architecture: $ARCH"
            return 1
        fi
    else
        print_error "Unsupported OS: $OS"
        return 1
    fi
    
    print_info "Detected platform: $PLATFORM"
    
    echo ""
    echo "Available OpenShift versions:"
    echo "  1) 4.19 (latest 4.19.x)"
    echo "  2) 4.20 (latest 4.20.x)"
    echo "  3) 4.18 (latest 4.18.x)"
    echo "  4) Custom version"
    echo ""
    
    read -p "$(echo -e ${BLUE}Select version${NC} [1]: )" version_choice
    version_choice="${version_choice:-1}"
    
    case $version_choice in
        1)
            VERSION="4.19"
            ;;
        2)
            VERSION="4.20"
            ;;
        3)
            VERSION="4.18"
            ;;
        4)
            read -p "$(echo -e ${BLUE}Enter version (e.g., 4.19.5)${NC}: )" VERSION
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    # Construct download URL
    BASE_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp"
    
    if [[ "$VERSION" =~ ^4\.[0-9]+$ ]]; then
        CHANNEL_URL="$BASE_URL/stable-${VERSION}"
        print_info "Fetching latest version in $VERSION channel..."
        FULL_VERSION=$(curl -s --insecure "${CHANNEL_URL}/release.txt" 2>/dev/null | grep "^Name:" | awk '{print $2}')
        
        if [ -z "$FULL_VERSION" ]; then
            print_error "Could not fetch version information from $CHANNEL_URL"
            print_error "Please check your network connection or try specifying a full version number"
            return 1
        fi
    else
        FULL_VERSION="$VERSION"
    fi
    
    print_info "Downloading OpenShift installer version: $FULL_VERSION"
    
    DOWNLOAD_URL="${BASE_URL}/${FULL_VERSION}/openshift-install-${PLATFORM}.tar.gz"
    
    # Download
    print_info "Downloading from: $DOWNLOAD_URL"
    if curl -L --insecure -o "openshift-install-${FULL_VERSION}.tar.gz" "$DOWNLOAD_URL"; then
        print_success "Download completed"
    else
        print_error "Download failed"
        return 1
    fi
    
    # Extract
    print_info "Extracting installer..."
    tar -xzf "openshift-install-${FULL_VERSION}.tar.gz"
    
    # Remove quarantine attribute on macOS
    if [[ "$OS" == "darwin" ]]; then
        print_info "Removing macOS quarantine attribute..."
        xattr -rc . 2>/dev/null || true
    fi
    
    # Make executable
    chmod +x openshift-install
    
    # Verify
    print_info "Verifying installation..."
    ./openshift-install version
    
    print_success "OpenShift installer $FULL_VERSION installed successfully!"
    
    press_any_key
}

#############################################################################
# Installation Configuration Functions
#############################################################################

get_pull_secret() {
    print_info "OpenShift Pull Secret Required"
    echo ""
    echo "You need a pull secret from Red Hat to download OpenShift images."
    echo "Get your pull secret from: https://console.redhat.com/openshift/install/pull-secret"
    echo ""
    
    # Check for existing pull secret
    if [ -f "$HOME/.openshift/pull-secret.json" ]; then
        print_info "Found existing pull secret at $HOME/.openshift/pull-secret.json"
        read -p "$(echo -e ${BLUE}Use existing pull secret?${NC} [Y/n]: )" use_existing
        if [[ "$use_existing" != "n" && "$use_existing" != "N" ]]; then
            PULL_SECRET=$(cat "$HOME/.openshift/pull-secret.json")
            print_success "Using existing pull secret"
            return
        fi
    fi
    
    # Prompt for input method
    echo ""
    echo "How would you like to provide the pull secret?"
    echo "  1) Paste pull secret directly (recommended)"
    echo "  2) Provide path to pull secret file"
    echo ""
    read -p "$(echo -e ${BLUE}Select option${NC} [1]: )" secret_method
    secret_method="${secret_method:-1}"
    
    case $secret_method in
        1)
            echo ""
            print_info "Paste your pull secret below and press Enter:"
            print_info "(The secret should be a JSON string starting with '{\"auths\"...')"
            print_warning "Note: After pasting, press Enter to continue"
            echo ""
            echo -n "> "
            
            # Read the pull secret with IFS to handle special characters
            IFS= read -r PULL_SECRET
            
            # Trim whitespace
            PULL_SECRET=$(echo "$PULL_SECRET" | xargs)
            
            # Debug: Show first 50 characters
            echo ""
            print_info "Received $(echo -n "$PULL_SECRET" | wc -c) characters"
            print_info "First 50 chars: ${PULL_SECRET:0:50}..."
            
            # Validate that it's not empty
            if [ -z "$PULL_SECRET" ]; then
                print_error "Pull secret cannot be empty"
                echo ""
                echo "Troubleshooting:"
                echo "  1. Make sure you copied the entire pull secret"
                echo "  2. Try using Option 2 (file path) instead"
                echo ""
                press_any_key
                return 1
            fi
            
            # Basic validation - check if it looks like JSON
            if [[ ! "$PULL_SECRET" =~ ^\{.*\}$ ]]; then
                print_warning "Pull secret doesn't appear to be valid JSON"
                echo "Expected format: {\"auths\":{...}}"
                echo ""
                read -p "$(echo -e ${BLUE}Continue anyway?${NC} [y/N]: )" continue_anyway
                if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
                    print_error "Pull secret validation failed"
                    echo ""
                    echo "Tip: Try using Option 2 to provide a file path instead"
                    press_any_key
                    return 1
                fi
            fi
            
            print_success "Pull secret received and validated"
            ;;
        2)
            echo ""
            read -p "$(echo -e ${BLUE}Enter path to pull secret file${NC}: )" pull_secret_path
            
            # Expand tilde to home directory
            pull_secret_path="${pull_secret_path/#\~/$HOME}"
            
            if [ ! -f "$pull_secret_path" ]; then
                print_error "Pull secret file not found: $pull_secret_path"
                exit 1
            fi
            
            PULL_SECRET=$(cat "$pull_secret_path")
            
            if [ -z "$PULL_SECRET" ]; then
                print_error "Pull secret file is empty"
                exit 1
            fi
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
    
    # Save for future use
    mkdir -p "$HOME/.openshift"
    echo "$PULL_SECRET" > "$HOME/.openshift/pull-secret.json"
    chmod 600 "$HOME/.openshift/pull-secret.json"
    print_success "Pull secret saved to $HOME/.openshift/pull-secret.json"
}

get_ssh_key() {
    print_info "SSH Public Key Configuration"
    echo ""
    echo "SSH key is required to access OpenShift cluster nodes"
    echo ""
    
    # Check for existing SSH keys
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        print_success "Found existing SSH key at $HOME/.ssh/id_rsa.pub"
        echo ""
        echo "Key preview:"
        head -c 80 "$HOME/.ssh/id_rsa.pub"
        echo "..."
        echo ""
        
        read -p "$(echo -e ${BLUE}Use this SSH key?${NC} [Y/n]: )" use_existing
        if [[ "$use_existing" != "n" && "$use_existing" != "N" ]]; then
            SSH_KEY=$(cat "$HOME/.ssh/id_rsa.pub")
            print_success "Using existing SSH key"
            return
        fi
    else
        print_warning "No SSH key found at $HOME/.ssh/id_rsa.pub"
    fi
    
    # Offer options
    echo ""
    echo "SSH Key Options:"
    echo "  1) Generate new SSH key (recommended)"
    echo "  2) Provide path to existing SSH public key"
    echo ""
    read -p "$(echo -e ${BLUE}Select option${NC} [1]: )" ssh_option
    ssh_option="${ssh_option:-1}"
    
    case $ssh_option in
        1)
            echo ""
            print_info "Generating new SSH key..."
            
            # Ask for custom name or use default
            read -p "$(echo -e ${BLUE}SSH key name${NC} [id_rsa]: )" key_name
            key_name="${key_name:-id_rsa}"
            
            key_path="$HOME/.ssh/${key_name}"
            
            # Check if key already exists
            if [ -f "${key_path}" ]; then
                print_warning "Key ${key_path} already exists"
                read -p "$(echo -e ${BLUE}Overwrite?${NC} [y/N]: )" overwrite
                if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
                    print_info "Using existing key"
                    SSH_KEY=$(cat "${key_path}.pub")
                    return
                fi
            fi
            
            # Optional: Add comment/email
            echo -e -n "${BLUE}Email/comment for key (optional)${NC}: "
            read -r key_comment
            
            # Generate key
            mkdir -p "$HOME/.ssh"
            chmod 700 "$HOME/.ssh"
            
            if [ -n "$key_comment" ]; then
                ssh-keygen -t rsa -b 4096 -f "${key_path}" -N "" -C "$key_comment"
            else
                ssh-keygen -t rsa -b 4096 -f "${key_path}" -N ""
            fi
            
            if [ $? -eq 0 ]; then
                print_success "SSH key generated successfully!"
                echo ""
                echo "Private key: ${key_path}"
                echo "Public key:  ${key_path}.pub"
                echo ""
                SSH_KEY=$(cat "${key_path}.pub")
                
                # Show the public key
                print_info "Your public key:"
                cat "${key_path}.pub"
                echo ""
            else
                print_error "Failed to generate SSH key"
                exit 1
            fi
            ;;
        2)
            echo ""
            read -p "$(echo -e ${BLUE}Enter path to SSH public key${NC}: )" ssh_key_path
            
            # Expand tilde
            ssh_key_path="${ssh_key_path/#\~/$HOME}"
            
            if [ ! -f "$ssh_key_path" ]; then
                print_error "SSH key file not found: $ssh_key_path"
                echo ""
                echo "Make sure the file exists and the path is correct"
                exit 1
            fi
            
            # Validate it's a public key
            if [[ ! "$ssh_key_path" =~ \.pub$ ]]; then
                print_warning "File doesn't end with .pub - make sure this is a PUBLIC key"
                read -p "$(echo -e ${BLUE}Continue anyway?${NC} [y/N]: )" continue_anyway
                if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
                    exit 1
                fi
            fi
            
            SSH_KEY=$(cat "$ssh_key_path")
            print_success "SSH key loaded from $ssh_key_path"
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
    
    print_success "SSH key configured"
}

configure_cluster() {
    print_header "OpenShift Cluster Configuration"
    
    prompt_with_default "Enter cluster name" "openshift-cluster" CLUSTER_NAME
    prompt_with_default "Enter base domain" "example.com" BASE_DOMAIN
    
    echo ""
    print_info "AWS Region and Availability Zone Configuration"
    prompt_with_default "Enter AWS region" "us-east-2" AWS_REGION
    
    print_info "Fetching available availability zones for $AWS_REGION..."
    available_azs=$(aws ec2 describe-availability-zones --region $AWS_REGION --query 'AvailabilityZones[?State==`available`].ZoneName' --output text)
    
    echo ""
    echo "Available Availability Zones:"
    echo "$available_azs"
    echo ""
    
    prompt_with_default "Enter availability zones (comma-separated)" "us-east-2a,us-east-2b,us-east-2c" AZS_INPUT
    IFS=',' read -ra AZS <<< "$AZS_INPUT"
    
    echo ""
    print_info "Master Node Configuration"
    prompt_with_default "Master node instance type" "m6i.xlarge" MASTER_INSTANCE_TYPE
    prompt_with_default "Number of master replicas" "3" MASTER_REPLICAS
    
    echo ""
    print_info "Worker Node Configuration"
    echo "Common instance types:"
    echo "  - m6i.2xlarge (standard)"
    echo "  - p5.48xlarge (H100 GPU - 8x H100 80GB)"
    echo "  - p4d.24xlarge (A100 GPU - 8x A100 40GB)"
    echo "  - g6e.xlarge (L40S GPU - 1x L40S 48GB)"
    echo "  - g6e.4xlarge (L40S GPU - 1x L40S 48GB)"
    echo "  - g5.xlarge (A10G GPU - 1x A10G 24GB)"
    prompt_with_default "Worker node instance type" "m6i.2xlarge" WORKER_INSTANCE_TYPE
    prompt_with_default "Number of worker replicas" "3" WORKER_REPLICAS
    
    echo ""
    print_info "Network Configuration"
    prompt_with_default "VPC CIDR block" "10.0.0.0/16" VPC_CIDR
    prompt_with_default "Machine network CIDR" "10.0.0.0/16" MACHINE_CIDR
}

use_existing_vpc() {
    print_header "Use Existing VPC and Subnets"
    
    echo -e "${YELLOW}This option allows you to use existing AWS infrastructure.${NC}"
    echo ""
    
    # Get VPC ID
    print_info "Enter your existing VPC ID (e.g., vpc-0123456789abcdef0)"
    read -p "$(echo -e ${BLUE}VPC ID${NC}: )" VPC_ID
    
    if [ -z "$VPC_ID" ]; then
        print_error "VPC ID is required"
        return 1
    fi
    
    # Verify VPC exists
    print_step "Verifying VPC..."
    if ! aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$AWS_REGION" &>/dev/null; then
        print_error "VPC $VPC_ID not found in region $AWS_REGION"
        return 1
    fi
    
    VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$AWS_REGION" --query 'Vpcs[0].CidrBlock' --output text)
    print_success "Found VPC: $VPC_ID (CIDR: $VPC_CIDR)"
    
    # Set machine CIDR to match VPC CIDR
    MACHINE_CIDR="$VPC_CIDR"
    
    echo ""
    print_info "Enter subnet IDs (comma-separated)"
    print_info "You need both public and private subnets across your availability zones"
    echo ""
    
    # List available subnets in the VPC
    print_step "Available subnets in VPC $VPC_ID:"
    aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --region "$AWS_REGION" \
        --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
        --output table
    
    echo ""
    read -p "$(echo -e ${BLUE}Subnet IDs${NC} (comma-separated): )" subnets_input
    
    if [ -z "$subnets_input" ]; then
        print_error "Subnet IDs are required"
        return 1
    fi
    
    # Parse subnet IDs
    IFS=',' read -r -a SUBNET_IDS <<< "$subnets_input"
    
    # Trim whitespace from each subnet ID
    for i in "${!SUBNET_IDS[@]}"; do
        SUBNET_IDS[$i]=$(echo "${SUBNET_IDS[$i]}" | xargs)
    done
    
    # Verify subnets exist
    print_step "Verifying subnets..."
    for subnet_id in "${SUBNET_IDS[@]}"; do
        if ! aws ec2 describe-subnets --subnet-ids "$subnet_id" --region "$AWS_REGION" &>/dev/null; then
            print_error "Subnet $subnet_id not found"
            return 1
        fi
        
        subnet_az=$(aws ec2 describe-subnets --subnet-ids "$subnet_id" --region "$AWS_REGION" --query 'Subnets[0].AvailabilityZone' --output text)
        subnet_cidr=$(aws ec2 describe-subnets --subnet-ids "$subnet_id" --region "$AWS_REGION" --query 'Subnets[0].CidrBlock' --output text)
        print_success "Verified subnet: $subnet_id ($subnet_az, $subnet_cidr)"
    done
    
    echo ""
    print_success "VPC and subnet configuration complete"
    echo ""
    echo "Summary:"
    echo "  - VPC: $VPC_ID"
    echo "  - VPC CIDR: $VPC_CIDR"
    echo "  - Subnets: ${#SUBNET_IDS[@]}"
    for subnet_id in "${SUBNET_IDS[@]}"; do
        echo "    • $subnet_id"
    done
    echo ""
    
    print_warning "Important: Ensure your subnets have:"
    echo "  1. Proper route tables (public subnets → Internet Gateway, private → NAT Gateway)"
    echo "  2. Appropriate tags for OpenShift (kubernetes.io/role/elb for public, kubernetes.io/role/internal-elb for private)"
    echo "  3. Sufficient IP address space for the cluster"
    echo ""
    
    read -p "Press Enter to continue..."
}

create_vpc_and_subnets() {
    print_info "Creating VPC and subnets for OpenShift cluster..."
    
    # Create VPC
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block $VPC_CIDR \
        --region $AWS_REGION \
        --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${CLUSTER_NAME}-vpc}]" \
        --query 'Vpc.VpcId' \
        --output text)
    
    print_success "Created VPC: $VPC_ID"
    
    # Enable DNS hostnames and DNS support
    aws ec2 modify-vpc-attribute \
        --vpc-id $VPC_ID \
        --enable-dns-hostnames \
        --region $AWS_REGION
    
    aws ec2 modify-vpc-attribute \
        --vpc-id $VPC_ID \
        --enable-dns-support \
        --region $AWS_REGION
    
    # Create Internet Gateway
    IGW_ID=$(aws ec2 create-internet-gateway \
        --region $AWS_REGION \
        --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${CLUSTER_NAME}-igw}]" \
        --query 'InternetGateway.InternetGatewayId' \
        --output text)
    
    aws ec2 attach-internet-gateway \
        --vpc-id $VPC_ID \
        --internet-gateway-id $IGW_ID \
        --region $AWS_REGION
    
    print_success "Created and attached Internet Gateway: $IGW_ID"
    
    # Calculate subnet CIDRs
    IFS='.' read -r -a vpc_octets <<< "${VPC_CIDR%/*}"
    subnet_prefix="${VPC_CIDR#*/}"
    subnet_size=$((subnet_prefix + 4))  # /20 subnets from /16 VPC
    
    PUBLIC_SUBNET_IDS=()
    PRIVATE_SUBNET_IDS=()
    SUBNET_IDS=()
    NAT_GATEWAY_IDS=()
    subnet_counter=0
    
    # Create public subnets (for load balancers and NAT gateways)
    print_info "Creating public subnets..."
    for az in "${AZS[@]}"; do
        third_octet=$((subnet_counter * 32))
        subnet_cidr="${vpc_octets[0]}.${vpc_octets[1]}.${third_octet}.0/${subnet_size}"
        
        subnet_id=$(aws ec2 create-subnet \
            --vpc-id $VPC_ID \
            --cidr-block $subnet_cidr \
            --availability-zone $az \
            --region $AWS_REGION \
            --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${CLUSTER_NAME}-public-${az}},{Key=kubernetes.io/role/elb,Value=1}]" \
            --query 'Subnet.SubnetId' \
            --output text)
        
        PUBLIC_SUBNET_IDS+=("$subnet_id")
        SUBNET_IDS+=("$subnet_id")
        print_success "Created public subnet $subnet_cidr in $az: $subnet_id"
        
        # Enable auto-assign public IP
        aws ec2 modify-subnet-attribute \
            --subnet-id $subnet_id \
            --map-public-ip-on-launch \
            --region $AWS_REGION
        
        ((subnet_counter++))
    done
    
    # Create private subnets (for OpenShift nodes)
    print_info "Creating private subnets..."
    for az in "${AZS[@]}"; do
        third_octet=$((subnet_counter * 32))
        subnet_cidr="${vpc_octets[0]}.${vpc_octets[1]}.${third_octet}.0/${subnet_size}"
        
        subnet_id=$(aws ec2 create-subnet \
            --vpc-id $VPC_ID \
            --cidr-block $subnet_cidr \
            --availability-zone $az \
            --region $AWS_REGION \
            --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${CLUSTER_NAME}-private-${az}},{Key=kubernetes.io/role/internal-elb,Value=1}]" \
            --query 'Subnet.SubnetId' \
            --output text)
        
        PRIVATE_SUBNET_IDS+=("$subnet_id")
        SUBNET_IDS+=("$subnet_id")
        print_success "Created private subnet $subnet_cidr in $az: $subnet_id"
        
        ((subnet_counter++))
    done
    
    # Create public route table
    print_info "Creating public route table..."
    PUBLIC_RTB_ID=$(aws ec2 create-route-table \
        --vpc-id $VPC_ID \
        --region $AWS_REGION \
        --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${CLUSTER_NAME}-public-rtb}]" \
        --query 'RouteTable.RouteTableId' \
        --output text)
    
    # Add route to internet gateway
    aws ec2 create-route \
        --route-table-id $PUBLIC_RTB_ID \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id $IGW_ID \
        --region $AWS_REGION > /dev/null
    
    # Associate public subnets with public route table
    for subnet_id in "${PUBLIC_SUBNET_IDS[@]}"; do
        aws ec2 associate-route-table \
            --subnet-id $subnet_id \
            --route-table-id $PUBLIC_RTB_ID \
            --region $AWS_REGION > /dev/null
    done
    
    print_success "Created public route table"
    
    # Create NAT Gateways and private route tables
    print_info "Creating NAT Gateways (this may take a few minutes)..."
    for i in "${!AZS[@]}"; do
        az="${AZS[$i]}"
        public_subnet="${PUBLIC_SUBNET_IDS[$i]}"
        private_subnet="${PRIVATE_SUBNET_IDS[$i]}"
        
        # Allocate Elastic IP for NAT Gateway
        eip_alloc_id=$(aws ec2 allocate-address \
            --domain vpc \
            --region $AWS_REGION \
            --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${CLUSTER_NAME}-nat-${az}}]" \
            --query 'AllocationId' \
            --output text)
        
        # Create NAT Gateway
        nat_gw_id=$(aws ec2 create-nat-gateway \
            --subnet-id $public_subnet \
            --allocation-id $eip_alloc_id \
            --region $AWS_REGION \
            --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${CLUSTER_NAME}-nat-${az}}]" \
            --query 'NatGateway.NatGatewayId' \
            --output text)
        
        NAT_GATEWAY_IDS+=("$nat_gw_id")
        print_success "Created NAT Gateway in $az: $nat_gw_id"
    done
    
    # Wait for NAT Gateways to become available
    print_info "Waiting for NAT Gateways to become available..."
    for nat_gw_id in "${NAT_GATEWAY_IDS[@]}"; do
        aws ec2 wait nat-gateway-available \
            --nat-gateway-ids $nat_gw_id \
            --region $AWS_REGION
    done
    print_success "All NAT Gateways are available"
    
    # Create private route tables (one per AZ)
    for i in "${!AZS[@]}"; do
        az="${AZS[$i]}"
        private_subnet="${PRIVATE_SUBNET_IDS[$i]}"
        nat_gw_id="${NAT_GATEWAY_IDS[$i]}"
        
        # Create private route table
        private_rtb_id=$(aws ec2 create-route-table \
            --vpc-id $VPC_ID \
            --region $AWS_REGION \
            --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${CLUSTER_NAME}-private-${az}}]" \
            --query 'RouteTable.RouteTableId' \
            --output text)
        
        # Add route to NAT Gateway
        aws ec2 create-route \
            --route-table-id $private_rtb_id \
            --destination-cidr-block 0.0.0.0/0 \
            --nat-gateway-id $nat_gw_id \
            --region $AWS_REGION > /dev/null
        
        # Associate private subnet with private route table
        aws ec2 associate-route-table \
            --subnet-id $private_subnet \
            --route-table-id $private_rtb_id \
            --region $AWS_REGION > /dev/null
        
        print_success "Created private route table for $az"
    done
    
    print_success "VPC and subnet configuration complete"
    echo ""
    echo "Summary:"
    echo "  - VPC: $VPC_ID"
    echo "  - Public subnets: ${#PUBLIC_SUBNET_IDS[@]}"
    echo "  - Private subnets: ${#PRIVATE_SUBNET_IDS[@]}"
    echo "  - NAT Gateways: ${#NAT_GATEWAY_IDS[@]}"
}

generate_install_config() {
    print_info "Generating install-config.yaml..."
    
    INSTALL_DIR="${CLUSTER_NAME}-install"
    mkdir -p "$INSTALL_DIR"
    
    cat > "$INSTALL_DIR/install-config.yaml" <<EOF
apiVersion: v1
baseDomain: ${BASE_DOMAIN}
metadata:
  name: ${CLUSTER_NAME}
platform:
  aws:
    region: ${AWS_REGION}
    subnets:
$(for subnet in "${SUBNET_IDS[@]}"; do echo "      - $subnet"; done)
compute:
- name: worker
  platform:
    aws:
      type: ${WORKER_INSTANCE_TYPE}
      zones:
$(for az in "${AZS[@]}"; do echo "        - $az"; done)
  replicas: ${WORKER_REPLICAS}
controlPlane:
  name: master
  platform:
    aws:
      type: ${MASTER_INSTANCE_TYPE}
      zones:
$(for az in "${AZS[@]}"; do echo "        - $az"; done)
  replicas: ${MASTER_REPLICAS}
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: ${MACHINE_CIDR}
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
pullSecret: '${PULL_SECRET}'
sshKey: '${SSH_KEY}'
EOF
    
    # Backup install-config.yaml
    cp "$INSTALL_DIR/install-config.yaml" "$INSTALL_DIR/install-config.yaml.backup"
    
    print_success "install-config.yaml generated and saved to $INSTALL_DIR/"
}

display_summary() {
    print_header "Installation Configuration Summary"
    
    echo "Cluster Name:        $CLUSTER_NAME"
    echo "Base Domain:         $BASE_DOMAIN"
    echo "AWS Region:          $AWS_REGION"
    echo "Availability Zones:  ${AZS[*]}"
    echo ""
    echo "Master Nodes:"
    echo "  - Instance Type:   $MASTER_INSTANCE_TYPE"
    echo "  - Replicas:        $MASTER_REPLICAS"
    echo ""
    echo "Worker Nodes:"
    echo "  - Instance Type:   $WORKER_INSTANCE_TYPE"
    echo "  - Replicas:        $WORKER_REPLICAS"
    echo ""
    echo "Network:"
    echo "  - VPC CIDR:        $VPC_CIDR"
    echo "  - Machine CIDR:    $MACHINE_CIDR"
    if [ -n "$VPC_ID" ]; then
        echo "  - VPC ID:          $VPC_ID"
        echo "  - Subnet IDs:      ${SUBNET_IDS[*]}"
    fi
    echo ""
}

run_installation() {
    print_header "Starting OpenShift Installation"
    
    print_warning "This process will take 30-45 minutes. Do not interrupt!"
    echo ""
    
    read -p "$(echo -e ${BLUE}Proceed with installation?${NC} [Y/n]: )" proceed
    if [[ "$proceed" == "n" || "$proceed" == "N" ]]; then
        print_warning "Installation cancelled by user"
        return 1
    fi
    
    # Create cluster
    print_info "Creating OpenShift cluster..."
    ./openshift-install create cluster --dir="$INSTALL_DIR" --log-level=info
    
    if [ $? -eq 0 ]; then
        print_success "OpenShift cluster installation completed successfully!"
        echo ""
        
        # Extract cluster information
        CONSOLE_URL=$(grep "Access the OpenShift web-console here:" "$INSTALL_DIR/.openshift_install.log" | tail -1 | awk '{print $NF}')
        KUBEADMIN_PASSWORD=$(cat "$INSTALL_DIR/auth/kubeadmin-password" 2>/dev/null || echo "Not found")
        KUBECONFIG_PATH="$PWD/$INSTALL_DIR/auth/kubeconfig"
        
        # Save cluster details to a file
        CLUSTER_INFO_FILE="$PWD/cluster-info.txt"
        cat > "$CLUSTER_INFO_FILE" << EOF
╔════════════════════════════════════════════════════════════════════════════╗
║                    OpenShift Cluster Information                           ║
╚════════════════════════════════════════════════════════════════════════════╝

Installation completed: $(date)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🌐 WEB CONSOLE ACCESS:
──────────────────────

URL:      $CONSOLE_URL
Username: kubeadmin
Password: $KUBEADMIN_PASSWORD

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 COMMAND LINE ACCESS:
───────────────────────

1. Set the KUBECONFIG environment variable:
   export KUBECONFIG=$KUBECONFIG_PATH

2. Verify cluster access:
   oc get nodes
   oc get co

3. View cluster version:
   oc version

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 FILES LOCATION:
──────────────────

Kubeconfig:        $INSTALL_DIR/auth/kubeconfig
Admin Password:    $INSTALL_DIR/auth/kubeadmin-password
Installation Log:  $INSTALL_DIR/.openshift_install.log
Cluster Metadata:  $INSTALL_DIR/metadata.json

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 QUICK START COMMANDS:
────────────────────────

# Set up environment
export KUBECONFIG=$KUBECONFIG_PATH

# Check cluster status
oc get nodes
oc get clusterversion
oc get co

# Access web console
open $CONSOLE_URL

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 NOTES:
─────────

- This file contains sensitive information. Keep it secure!
- The kubeadmin user is for initial access only
- Create additional users and remove kubeadmin for production use
- Backup the auth/ directory for disaster recovery

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
        
        # Display cluster information
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${GREEN}🎉 CLUSTER DETAILS SAVED TO: $CLUSTER_INFO_FILE${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        cat "$CLUSTER_INFO_FILE"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${YELLOW}💾 Cluster information has been saved to: $CLUSTER_INFO_FILE${NC}"
        echo -e "${YELLOW}📋 You can view it anytime with: cat $CLUSTER_INFO_FILE${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    else
        print_error "Installation failed. Check logs in $INSTALL_DIR/.openshift_install.log"
        return 1
    fi
}

#############################################################################
# Full Installation Flow
#############################################################################

installation_only() {
    print_header "OpenShift Installation (Using Existing Installer)"
    
    # Check if installer exists
    if [ ! -f "./openshift-install" ]; then
        print_error "openshift-install binary not found in current directory"
        echo ""
        echo "Options:"
        echo "  1. Download installer from main menu (option 3)"
        echo "  2. Place your openshift-install binary in this directory"
        echo ""
        press_any_key
        return 1
    fi
    
    # Show current version
    print_info "Using OpenShift installer:"
    ./openshift-install version 2>/dev/null || print_warning "Could not verify version"
    echo ""
    
    read -p "$(echo -e ${BLUE}Continue with this installer version?${NC} [Y/n]: )" continue_install
    if [[ "$continue_install" == "n" || "$continue_install" == "N" ]]; then
        print_info "Installation cancelled"
        press_any_key
        return 1
    fi
    
    get_pull_secret
    get_ssh_key
    configure_cluster
    
    # Ask if user wants to use existing VPC or create new one
    echo ""
    print_header "Network Infrastructure"
    echo ""
    echo -e "${YELLOW}Do you want to use existing VPC and subnets, or create new ones?${NC}"
    echo ""
    echo "  1) Create new VPC and subnets (recommended for new installations)"
    echo "  2) Use existing VPC and subnets"
    echo ""
    read -p "$(echo -e ${BLUE}Select option${NC} [1]: )" vpc_choice
    vpc_choice="${vpc_choice:-1}"
    
    case $vpc_choice in
        1)
            create_vpc_and_subnets
            ;;
        2)
            use_existing_vpc
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    generate_install_config
    display_summary
    
    run_installation
    
    press_any_key
}

full_installation() {
    print_header "Full OpenShift Installation (Download + Install)"
    
    # Check if installer exists
    if [ -f "./openshift-install" ]; then
        print_warning "An OpenShift installer already exists in this directory"
        ./openshift-install version 2>/dev/null | head -1
        echo ""
        read -p "$(echo -e ${BLUE}Do you want to download a different version?${NC} [y/N]: )" download_new
        
        if [[ "$download_new" != "y" && "$download_new" != "Y" ]]; then
            print_info "Using existing installer"
        else
            download_installer
        fi
    else
        download_installer
    fi
    
    # Proceed with installation
    echo ""
    read -p "$(echo -e ${BLUE}Proceed with installation configuration?${NC} [Y/n]: )" proceed
    if [[ "$proceed" == "n" || "$proceed" == "N" ]]; then
        print_info "Installation cancelled"
        press_any_key
        return 1
    fi
    
    get_pull_secret
    get_ssh_key
    configure_cluster
    
    # Ask if user wants to use existing VPC or create new one
    echo ""
    print_header "Network Infrastructure"
    echo ""
    echo -e "${YELLOW}Do you want to use existing VPC and subnets, or create new ones?${NC}"
    echo ""
    echo "  1) Create new VPC and subnets (recommended for new installations)"
    echo "  2) Use existing VPC and subnets"
    echo ""
    read -p "$(echo -e ${BLUE}Select option${NC} [1]: )" vpc_choice
    vpc_choice="${vpc_choice:-1}"
    
    case $vpc_choice in
        1)
            create_vpc_and_subnets
            ;;
        2)
            use_existing_vpc
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    generate_install_config
    display_summary
    
    run_installation
    
    press_any_key
}

#############################################################################
# Main Menu
#############################################################################

show_menu() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════════════════╗
║                OpenShift Installation Master Script                        ║
║                     All-in-One Installation Tool                           ║
╚════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Show current installer version if exists
    if [ -f "./openshift-install" ]; then
        echo -e "${GREEN}✓ OpenShift Installer Found:${NC}"
        ./openshift-install version 2>/dev/null | head -1 || echo "  Version check failed"
        echo ""
    else
        echo -e "${YELLOW}⚠ No OpenShift installer found in current directory${NC}"
        echo ""
    fi
    
    # Show AWS configuration status
    if aws sts get-caller-identity &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ AWS Credentials Configured${NC}"
        echo ""
    else
        echo -e "${YELLOW}⚠ AWS Credentials Not Configured${NC}"
        echo ""
    fi
    
    echo "1) Configure AWS Credentials"
    echo "2) Check Prerequisites & System Status"
    echo "3) Check AWS Service Quotas & GPU Availability"
    echo "4) Download/Update OpenShift Installer"
    echo "5) Run Full Installation (Download + Install)"
    echo "6) Run Installation Only (Skip Download)"
    echo "7) View Documentation"
    echo "8) Exit"
    echo ""
}

view_documentation() {
    clear
    print_header "Available Documentation"
    
    echo "Documentation files in this directory:"
    echo ""
    ls -lh *.md 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    echo "Key documents:"
    echo "  - GETTING-STARTED.md    : Step-by-step installation guide"
    echo "  - QUICK-START.md        : Quick reference"
    echo "  - INSTALLATION-GUIDE.md : Comprehensive guide with troubleshooting"
    echo "  - VERSION-GUIDE.md      : Version management information"
    echo ""
    
    press_any_key
}

#############################################################################
# Main Program
#############################################################################

main() {
    while true; do
        show_menu
        read -p "$(echo -e ${BLUE}Select an option${NC} [1-8]: )" choice
        
        case $choice in
            1)
                configure_aws_credentials
                ;;
            2)
                check_prerequisites
                ;;
            3)
                check_aws_quotas
                ;;
            4)
                download_installer
                ;;
            5)
                full_installation
                ;;
            6)
                installation_only
                ;;
            7)
                view_documentation
                ;;
            8)
                echo ""
                print_info "Exiting. Good luck with your OpenShift installation!"
                echo ""
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-8."
                sleep 2
                ;;
        esac
    done
}

# Run main program
main

