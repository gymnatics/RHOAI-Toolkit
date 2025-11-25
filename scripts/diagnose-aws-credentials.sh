#!/bin/bash

################################################################################
# AWS Credentials Diagnostic Script
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           AWS Credentials Diagnostic Tool                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# 1. Check environment variables
echo -e "${BLUE}1. Checking Environment Variables:${NC}"
if [ -n "$AWS_ACCESS_KEY_ID" ]; then
    echo -e "  ${YELLOW}AWS_ACCESS_KEY_ID${NC} is set: ${AWS_ACCESS_KEY_ID:0:10}..."
else
    echo -e "  ${GREEN}AWS_ACCESS_KEY_ID${NC} is not set (will use config file)"
fi

if [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo -e "  ${YELLOW}AWS_SECRET_ACCESS_KEY${NC} is set: ****"
else
    echo -e "  ${GREEN}AWS_SECRET_ACCESS_KEY${NC} is not set (will use config file)"
fi

if [ -n "$AWS_SESSION_TOKEN" ]; then
    echo -e "  ${YELLOW}AWS_SESSION_TOKEN${NC} is set (temporary credentials)"
else
    echo "  AWS_SESSION_TOKEN is not set"
fi

if [ -n "$AWS_PROFILE" ]; then
    echo -e "  ${YELLOW}AWS_PROFILE${NC} is set to: $AWS_PROFILE"
else
    echo "  AWS_PROFILE is not set (using default)"
fi
echo ""

# 2. Check credentials file
echo -e "${BLUE}2. Checking Credentials File:${NC}"
if [ -f ~/.aws/credentials ]; then
    echo -e "  ${GREEN}✓${NC} Credentials file exists: ~/.aws/credentials"
    
    # Check permissions
    PERMS=$(stat -f "%OLp" ~/.aws/credentials 2>/dev/null || stat -c "%a" ~/.aws/credentials 2>/dev/null)
    if [ "$PERMS" = "600" ]; then
        echo -e "  ${GREEN}✓${NC} Permissions are correct: $PERMS"
    else
        echo -e "  ${YELLOW}⚠${NC} Permissions are: $PERMS (should be 600)"
        echo "    Fix with: chmod 600 ~/.aws/credentials"
    fi
    
    # List profiles
    echo "  Profiles found:"
    grep '^\[' ~/.aws/credentials | sed 's/\[/    - /g' | sed 's/\]//g'
else
    echo -e "  ${RED}✗${NC} Credentials file not found: ~/.aws/credentials"
fi
echo ""

# 3. Check config file
echo -e "${BLUE}3. Checking Config File:${NC}"
if [ -f ~/.aws/config ]; then
    echo -e "  ${GREEN}✓${NC} Config file exists: ~/.aws/config"
    
    # Show default region
    DEFAULT_REGION=$(grep -A 1 '^\[default\]' ~/.aws/config | grep region | awk '{print $3}')
    if [ -n "$DEFAULT_REGION" ]; then
        echo "  Default region: $DEFAULT_REGION"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Config file not found: ~/.aws/config"
fi
echo ""

# 4. Test AWS CLI
echo -e "${BLUE}4. Testing AWS CLI:${NC}"
if command -v aws &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} AWS CLI is installed"
    aws --version
else
    echo -e "  ${RED}✗${NC} AWS CLI is not installed"
    exit 1
fi
echo ""

# 5. Test credentials
echo -e "${BLUE}5. Testing Credentials:${NC}"
echo "  Attempting: aws sts get-caller-identity"
echo ""

IDENTITY_OUTPUT=$(aws sts get-caller-identity 2>&1)
IDENTITY_EXIT_CODE=$?

if [ $IDENTITY_EXIT_CODE -eq 0 ]; then
    echo -e "  ${GREEN}✓ Credentials are VALID!${NC}"
    echo ""
    echo "  Account: $(echo "$IDENTITY_OUTPUT" | jq -r '.Account' 2>/dev/null)"
    echo "  User/Role: $(echo "$IDENTITY_OUTPUT" | jq -r '.Arn' 2>/dev/null)"
    echo "  User ID: $(echo "$IDENTITY_OUTPUT" | jq -r '.UserId' 2>/dev/null)"
else
    echo -e "  ${RED}✗ Credentials are INVALID or EXPIRED${NC}"
    echo ""
    echo "  Error details:"
    echo "$IDENTITY_OUTPUT" | sed 's/^/    /'
    echo ""
    
    # Diagnose specific errors
    if echo "$IDENTITY_OUTPUT" | grep -q "ExpiredToken"; then
        echo -e "  ${YELLOW}Diagnosis: Your credentials have EXPIRED${NC}"
        echo "  This typically happens with:"
        echo "    - AWS Academy credentials (expire after 3-4 hours)"
        echo "    - AWS SSO sessions"
        echo "    - Assumed role credentials"
        echo ""
        echo "  Solution:"
        echo "    1. Go back to AWS Academy/SSO"
        echo "    2. Get fresh credentials"
        echo "    3. Run: aws configure"
        echo "    4. Or update ~/.aws/credentials manually"
    elif echo "$IDENTITY_OUTPUT" | grep -q "InvalidClientTokenId"; then
        echo -e "  ${YELLOW}Diagnosis: Invalid Access Key ID${NC}"
        echo "  This means:"
        echo "    - The Access Key ID is wrong/typo"
        echo "    - The credentials were deleted/rotated"
        echo "    - Wrong AWS account"
        echo ""
        echo "  Solution:"
        echo "    1. Verify your Access Key ID"
        echo "    2. Run: aws configure"
        echo "    3. Enter correct credentials"
    elif echo "$IDENTITY_OUTPUT" | grep -q "SignatureDoesNotMatch"; then
        echo -e "  ${YELLOW}Diagnosis: Invalid Secret Access Key${NC}"
        echo "  This means:"
        echo "    - The Secret Access Key is wrong"
        echo "    - Typo when entering credentials"
        echo ""
        echo "  Solution:"
        echo "    1. Run: aws configure"
        echo "    2. Re-enter your Secret Access Key carefully"
    else
        echo -e "  ${YELLOW}Diagnosis: Unknown error${NC}"
        echo "  Try:"
        echo "    1. Run: aws configure"
        echo "    2. Re-enter all credentials"
    fi
fi
echo ""

# 6. Test VPC access
if [ $IDENTITY_EXIT_CODE -eq 0 ]; then
    echo -e "${BLUE}6. Testing VPC Access (us-east-2):${NC}"
    echo "  Attempting: aws ec2 describe-vpcs --region us-east-2"
    echo ""
    
    VPC_OUTPUT=$(aws ec2 describe-vpcs --region us-east-2 --query 'Vpcs[*].[VpcId,CidrBlock]' --output text 2>&1)
    VPC_EXIT_CODE=$?
    
    if [ $VPC_EXIT_CODE -eq 0 ]; then
        VPC_COUNT=$(echo "$VPC_OUTPUT" | wc -l | tr -d ' ')
        echo -e "  ${GREEN}✓ VPC access works!${NC}"
        echo "  Found $VPC_COUNT VPC(s) in us-east-2"
        if [ "$VPC_COUNT" -gt 0 ]; then
            echo ""
            echo "  VPCs:"
            echo "$VPC_OUTPUT" | sed 's/^/    /'
        fi
    else
        echo -e "  ${RED}✗ Cannot access VPCs${NC}"
        echo ""
        echo "  Error:"
        echo "$VPC_OUTPUT" | sed 's/^/    /'
        echo ""
        echo -e "  ${YELLOW}This might be a permissions issue${NC}"
        echo "  Your credentials need: ec2:DescribeVpcs permission"
    fi
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Diagnostic Complete                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"

