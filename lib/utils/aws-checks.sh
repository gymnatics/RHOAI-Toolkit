#!/bin/bash

################################################################################
# AWS Prerequisites Check Functions
# Validates AWS configuration before OpenShift installation
################################################################################

# Source colors if not already loaded
if [ -z "$GREEN" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

################################################################################
# Check AWS CLI Installation
################################################################################
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}✗ AWS CLI not found${NC}"
        echo ""
        echo "Install AWS CLI:"
        echo "  brew install awscli"
        echo "  OR"
        echo "  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        return 1
    fi
    echo -e "${GREEN}✓ AWS CLI installed${NC}"
    return 0
}

################################################################################
# Check AWS Credentials
################################################################################
check_aws_credentials() {
    echo ""
    echo -e "${CYAN}Checking AWS Credentials...${NC}"
    
    if ! aws sts get-caller-identity &>/dev/null; then
        echo -e "${RED}✗ AWS credentials not configured or invalid${NC}"
        echo ""
        echo "Configure AWS credentials:"
        echo "  aws configure"
        echo ""
        echo "Or set environment variables:"
        echo "  export AWS_ACCESS_KEY_ID=your_key"
        echo "  export AWS_SECRET_ACCESS_KEY=your_secret"
        return 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    local user_arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
    
    echo -e "${GREEN}✓ AWS credentials valid${NC}"
    echo "  Account: $account_id"
    echo "  User: $user_arn"
    return 0
}

################################################################################
# Check Route53 Hosted Zones
################################################################################
check_route53_zones() {
    echo ""
    echo -e "${CYAN}Checking Route53 Hosted Zones...${NC}"
    
    local zones=$(aws route53 list-hosted-zones --output json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to list Route53 hosted zones${NC}"
        echo "  Check if you have Route53 permissions"
        return 1
    fi
    
    local zone_count=$(echo "$zones" | grep -c '"Name"' || echo "0")
    
    if [ "$zone_count" -eq 0 ]; then
        echo -e "${RED}✗ No Route53 hosted zones found${NC}"
        echo ""
        echo "You need a public hosted zone for OpenShift installation."
        echo "Create one in AWS Console or contact your AWS administrator."
        return 1
    fi
    
    echo -e "${GREEN}✓ Found $zone_count Route53 hosted zone(s)${NC}"
    echo ""
    echo "Available domains:"
    
    # Display zones in a readable format
    aws route53 list-hosted-zones --output json 2>/dev/null | \
        grep -E '"Name"|"Id"|"PrivateZone"' | \
        awk 'BEGIN {count=0} 
             /"Name"/ {name=$2; gsub(/[",]/, "", name)} 
             /"Id"/ {id=$2; gsub(/.*\//, "", id); gsub(/[",]/, "", id)} 
             /"PrivateZone"/ {
                 private=$2; 
                 gsub(/[,]/, "", private);
                 count++;
                 if (private == "false") {
                     printf "  %d) %s (Public) ✓\n", count, name
                 } else {
                     printf "  %d) %s (Private) - Not suitable for new clusters\n", count, name
                 }
             }'
    
    echo ""
    echo -e "${YELLOW}Note: Use a PUBLIC hosted zone domain for installation${NC}"
    echo -e "${YELLOW}      Do NOT include leading dot (.) in domain name${NC}"
    
    return 0
}

################################################################################
# Check for Conflicting Private Hosted Zones
################################################################################
check_conflicting_zones() {
    echo ""
    echo -e "${CYAN}Checking for Conflicting Private Hosted Zones...${NC}"
    
    local private_zones=$(aws route53 list-hosted-zones --output json 2>/dev/null | \
        grep -B 3 '"PrivateZone": true' | \
        grep '"Name"' | \
        grep 'openshift-cluster' || echo "")
    
    if [ -n "$private_zones" ]; then
        echo -e "${YELLOW}⚠ Found private hosted zones from previous installations:${NC}"
        echo "$private_zones" | sed 's/"Name": "//g' | sed 's/",//g' | sed 's/^[ \t]*/  - /'
        echo ""
        echo -e "${YELLOW}These should be cleaned up before installing:${NC}"
        echo "  ./scripts/cleanup-all.sh"
        echo ""
        return 1
    fi
    
    echo -e "${GREEN}✓ No conflicting private hosted zones${NC}"
    return 0
}

################################################################################
# Check AWS Region Configuration
################################################################################
check_aws_region() {
    echo ""
    echo -e "${CYAN}Checking AWS Region...${NC}"
    
    local region=$(aws configure get region 2>/dev/null)
    
    if [ -z "$region" ]; then
        region=${AWS_DEFAULT_REGION:-us-east-2}
        echo -e "${YELLOW}⚠ No region configured, using default: $region${NC}"
        export AWS_DEFAULT_REGION=$region
    else
        echo -e "${GREEN}✓ Region configured: $region${NC}"
    fi
    
    # Verify region is valid
    if ! aws ec2 describe-regions --region $region &>/dev/null; then
        echo -e "${RED}✗ Invalid or inaccessible region: $region${NC}"
        return 1
    fi
    
    return 0
}

################################################################################
# Check AWS Service Quotas
################################################################################
check_aws_quotas() {
    echo ""
    echo -e "${CYAN}Checking AWS Service Quotas...${NC}"
    
    local region=$(aws configure get region 2>/dev/null || echo "us-east-2")
    local issues=0
    
    # Check VPC quota
    local vpc_quota=$(aws service-quotas get-service-quota \
        --service-code vpc \
        --quota-code L-F678F1CE \
        --region $region \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "5")
    
    local vpc_count=$(aws ec2 describe-vpcs --region $region --query 'length(Vpcs)' --output text 2>/dev/null || echo "0")
    
    # Convert quota to integer (remove decimal)
    vpc_quota=$(echo "$vpc_quota" | cut -d'.' -f1)
    
    if [ "$vpc_count" -ge "$vpc_quota" ]; then
        echo -e "${RED}✗ VPC quota reached: $vpc_count/$vpc_quota${NC}"
        issues=$((issues + 1))
    else
        echo -e "${GREEN}✓ VPC quota: $vpc_count/$vpc_quota available${NC}"
    fi
    
    # Check Elastic IP quota
    local eip_quota=$(aws service-quotas get-service-quota \
        --service-code ec2 \
        --quota-code L-0263D0A3 \
        --region $region \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "5")
    
    local eip_count=$(aws ec2 describe-addresses --region $region --query 'length(Addresses)' --output text 2>/dev/null || echo "0")
    
    # Convert quota to integer (remove decimal)
    eip_quota=$(echo "$eip_quota" | cut -d'.' -f1)
    
    if [ "$eip_count" -ge "$eip_quota" ]; then
        echo -e "${RED}✗ Elastic IP quota reached: $eip_count/$eip_quota${NC}"
        issues=$((issues + 1))
    else
        echo -e "${GREEN}✓ Elastic IP quota: $eip_count/$eip_quota available${NC}"
    fi
    
    if [ $issues -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Request quota increases at:${NC}"
        echo "  https://console.aws.amazon.com/servicequotas/"
        return 1
    fi
    
    return 0
}

################################################################################
# Check SSH Key Configuration
################################################################################
check_ssh_key() {
    echo ""
    echo -e "${CYAN}Checking SSH Key Configuration...${NC}"
    
    # Check if ssh-agent is running
    if ! ssh-add -l &>/dev/null; then
        echo -e "${YELLOW}⚠ SSH agent not running or no keys loaded${NC}"
        echo ""
        echo "Start ssh-agent and add your key:"
        echo "  eval \$(ssh-agent)"
        echo "  ssh-add ~/.ssh/id_rsa"
        echo ""
        echo "Or the installer can generate a new key for you."
        return 1
    fi
    
    local key_count=$(ssh-add -l 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ SSH agent running with $key_count key(s) loaded${NC}"
    
    # Show loaded keys
    echo ""
    echo "Loaded SSH keys:"
    ssh-add -l 2>/dev/null | sed 's/^/  /'
    
    return 0
}

################################################################################
# Check for Existing OpenShift Resources
################################################################################
check_existing_resources() {
    echo ""
    echo -e "${CYAN}Checking for Existing OpenShift Resources...${NC}"
    
    local region=$(aws configure get region 2>/dev/null || echo "us-east-2")
    
    # Check for OpenShift VPCs
    local vpc_count=$(aws ec2 describe-vpcs --region $region \
        --filters "Name=tag:Name,Values=*openshift*" \
        --query 'length(Vpcs)' \
        --output text 2>/dev/null || echo "0")
    
    # Check for OpenShift instances
    local instance_count=$(aws ec2 describe-instances --region $region \
        --filters "Name=tag:Name,Values=*openshift*" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
        --query 'length(Reservations[].Instances[])' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$vpc_count" -gt 0 ] || [ "$instance_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Found existing OpenShift resources:${NC}"
        [ "$vpc_count" -gt 0 ] && echo "  - $vpc_count VPC(s) with 'openshift' in name"
        [ "$instance_count" -gt 0 ] && echo "  - $instance_count EC2 instance(s) with 'openshift' in name"
        echo ""
        echo -e "${YELLOW}These may be from a previous installation.${NC}"
        echo "Clean up before proceeding:"
        echo "  ./scripts/cleanup-all.sh"
        echo ""
        return 1
    fi
    
    echo -e "${GREEN}✓ No existing OpenShift resources found${NC}"
    return 0
}

################################################################################
# Check OpenShift Installer
################################################################################
check_openshift_installer() {
    echo ""
    echo -e "${CYAN}Checking OpenShift Installer...${NC}"
    
    if [ ! -f "./openshift-install" ]; then
        echo -e "${RED}✗ openshift-install binary not found${NC}"
        echo ""
        echo "Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
        return 1
    fi
    
    if [ ! -x "./openshift-install" ]; then
        echo -e "${YELLOW}⚠ openshift-install not executable, fixing...${NC}"
        chmod +x ./openshift-install
    fi
    
    local version=$(./openshift-install version 2>/dev/null | head -1 || echo "unknown")
    echo -e "${GREEN}✓ OpenShift installer found${NC}"
    echo "  Version: $version"
    
    return 0
}

################################################################################
# Main AWS Prerequisites Check
################################################################################
check_aws_prerequisites() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         AWS Prerequisites Check for OpenShift Install         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local checks_passed=0
    local checks_failed=0
    local checks_warning=0
    
    # Run all checks
    check_aws_cli && checks_passed=$((checks_passed + 1)) || checks_failed=$((checks_failed + 1))
    check_aws_credentials && checks_passed=$((checks_passed + 1)) || checks_failed=$((checks_failed + 1))
    check_aws_region && checks_passed=$((checks_passed + 1)) || checks_failed=$((checks_failed + 1))
    check_route53_zones && checks_passed=$((checks_passed + 1)) || checks_failed=$((checks_failed + 1))
    check_conflicting_zones && checks_passed=$((checks_passed + 1)) || checks_warning=$((checks_warning + 1))
    check_aws_quotas && checks_passed=$((checks_passed + 1)) || checks_warning=$((checks_warning + 1))
    check_ssh_key && checks_passed=$((checks_passed + 1)) || checks_warning=$((checks_warning + 1))
    check_existing_resources && checks_passed=$((checks_passed + 1)) || checks_warning=$((checks_warning + 1))
    check_openshift_installer && checks_passed=$((checks_passed + 1)) || checks_failed=$((checks_failed + 1))
    
    # Summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Prerequisites Check Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}✓ Passed: $checks_passed${NC}"
    [ $checks_warning -gt 0 ] && echo -e "${YELLOW}⚠ Warnings: $checks_warning${NC}"
    [ $checks_failed -gt 0 ] && echo -e "${RED}✗ Failed: $checks_failed${NC}"
    echo ""
    
    if [ $checks_failed -gt 0 ]; then
        echo -e "${RED}❌ Critical checks failed. Please fix the issues above before proceeding.${NC}"
        echo ""
        return 1
    elif [ $checks_warning -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Some warnings detected. You may proceed, but review the warnings above.${NC}"
        echo ""
        read -p "Continue anyway? [y/N]: " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            return 1
        fi
        return 0
    else
        echo -e "${GREEN}✅ All prerequisites checks passed! Ready to install.${NC}"
        echo ""
        return 0
    fi
}

