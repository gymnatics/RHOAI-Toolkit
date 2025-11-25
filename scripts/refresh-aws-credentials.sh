#!/bin/bash

################################################################################
# Quick AWS Credentials Refresh Script
# For demo platforms with temporary credentials
################################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           AWS Credentials Refresh Tool                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${YELLOW}This will update your AWS credentials in ~/.aws/credentials${NC}"
echo ""
echo "Get your fresh credentials from your demo platform, then:"
echo ""

# Prompt for credentials
read -p "AWS Access Key ID: " ACCESS_KEY
read -s -p "AWS Secret Access Key: " SECRET_KEY
echo ""
read -s -p "AWS Session Token: " SESSION_TOKEN
echo ""

# Validate inputs
if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
    echo -e "${RED}Error: Access Key ID and Secret Access Key are required${NC}"
    exit 1
fi

# Backup existing credentials
if [ -f ~/.aws/credentials ]; then
    cp ~/.aws/credentials ~/.aws/credentials.backup
    echo -e "${GREEN}✓${NC} Backed up existing credentials to ~/.aws/credentials.backup"
fi

# Write new credentials
mkdir -p ~/.aws
cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = $ACCESS_KEY
aws_secret_access_key = $SECRET_KEY
EOF

# Add session token if provided
if [ -n "$SESSION_TOKEN" ]; then
    echo "aws_session_token = $SESSION_TOKEN" >> ~/.aws/credentials
fi

# Set permissions
chmod 600 ~/.aws/credentials

echo -e "${GREEN}✓${NC} Credentials updated"
echo ""

# Test credentials
echo "Testing credentials..."
if aws sts get-caller-identity &>/dev/null; then
    echo -e "${GREEN}✓ Credentials are valid!${NC}"
    echo ""
    aws sts get-caller-identity
    echo ""
    echo -e "${BLUE}You can now run your installation scripts${NC}"
else
    echo -e "${RED}✗ Credentials test failed${NC}"
    echo ""
    echo "Please verify:"
    echo "  1. You copied the complete Access Key ID"
    echo "  2. You copied the complete Secret Access Key"
    echo "  3. You copied the complete Session Token (if required)"
    echo ""
    echo "Your old credentials were backed up to ~/.aws/credentials.backup"
fi

