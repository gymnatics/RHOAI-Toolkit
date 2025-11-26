#!/bin/bash

################################################################################
# Scan Repository for Exposed Secrets
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Repository Security Scan                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

ISSUES_FOUND=0

# 1. Check for AWS Access Keys
echo -e "${YELLOW}1. Scanning for AWS Access Keys...${NC}"
if git grep -E "AKIA[0-9A-Z]{16}" 2>/dev/null; then
    echo -e "${RED}✗ Found AWS Access Keys in repository!${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ No AWS Access Keys found${NC}"
fi
echo ""

# 2. Check for AWS Secret Keys
echo -e "${YELLOW}2. Scanning for AWS Secret Keys...${NC}"
if git grep -E "aws_secret_access_key\s*=\s*[A-Za-z0-9/+=]{40}" 2>/dev/null; then
    echo -e "${RED}✗ Found AWS Secret Keys in repository!${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ No AWS Secret Keys found${NC}"
fi
echo ""

# 3. Check for passwords
echo -e "${YELLOW}3. Scanning for passwords...${NC}"
if git grep -iE "(password|passwd)\s*[:=]\s*['\"][^'\"]{8,}" 2>/dev/null | grep -v "example\|placeholder\|your-password\|<password>"; then
    echo -e "${RED}✗ Found potential passwords in repository!${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ No hardcoded passwords found${NC}"
fi
echo ""

# 4. Check for private keys
echo -e "${YELLOW}4. Scanning for private keys...${NC}"
if git grep -E "BEGIN.*PRIVATE KEY" 2>/dev/null; then
    echo -e "${RED}✗ Found private keys in repository!${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ No private keys found${NC}"
fi
echo ""

# 5. Check .gitignore
echo -e "${YELLOW}5. Checking .gitignore configuration...${NC}"
if [ -f .gitignore ]; then
    REQUIRED_PATTERNS=("pull-secret" "credentials" "*password*" "*.pem" "*.key")
    MISSING=()
    
    for pattern in "${REQUIRED_PATTERNS[@]}"; do
        if ! grep -q "$pattern" .gitignore; then
            MISSING+=("$pattern")
        fi
    done
    
    if [ ${#MISSING[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ .gitignore is properly configured${NC}"
    else
        echo -e "${YELLOW}⚠ Missing patterns in .gitignore:${NC}"
        for pattern in "${MISSING[@]}"; do
            echo "    - $pattern"
        done
    fi
else
    echo -e "${RED}✗ No .gitignore file found!${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# 6. Check for tracked sensitive files
echo -e "${YELLOW}6. Checking for tracked sensitive files...${NC}"
SENSITIVE_FILES=$(git ls-files | grep -E "(secret|password|credential|\.pem|\.key|pull-secret)" | grep -v "scripts/")
if [ -n "$SENSITIVE_FILES" ]; then
    echo -e "${RED}✗ Found tracked sensitive files:${NC}"
    echo "$SENSITIVE_FILES" | sed 's/^/    /'
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ No sensitive files are tracked${NC}"
fi
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════════╗"
if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "║  ${GREEN}✓ Security Scan Complete - No Issues Found${NC}              ║"
else
    echo -e "║  ${RED}✗ Security Scan Complete - $ISSUES_FOUND Issue(s) Found${NC}          ║"
fi
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [ $ISSUES_FOUND -gt 0 ]; then
    echo -e "${YELLOW}Action Required:${NC}"
    echo "1. Remove sensitive data from tracked files"
    echo "2. Add patterns to .gitignore"
    echo "3. Consider using git-filter-repo to remove from history"
    echo "4. Rotate any exposed credentials immediately"
    echo ""
    exit 1
fi

exit 0

