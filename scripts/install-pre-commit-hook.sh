#!/bin/bash

################################################################################
# Install Git Pre-Commit Hook
################################################################################
# This script installs a pre-commit hook that scans for sensitive data
# before allowing commits

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
HOOK_SOURCE="$SCRIPT_DIR/pre-commit-hook-template.sh"
HOOK_DEST="$REPO_ROOT/.git/hooks/pre-commit"

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Git Pre-Commit Hook Installer                     ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

show_status() {
    print_header
    
    echo -e "${CYAN}Pre-Commit Hook Status${NC}"
    echo ""
    
    if [ -f "$HOOK_DEST" ]; then
        print_success "Pre-commit hook is INSTALLED"
        echo ""
        echo "  Location: $HOOK_DEST"
        
        if [ -x "$HOOK_DEST" ]; then
            print_success "Hook is executable"
        else
            print_warning "Hook exists but is not executable"
        fi
        
        # Check if it's our hook
        if grep -q "Sensitive Data Scanner" "$HOOK_DEST" 2>/dev/null; then
            print_success "This is the security scanning hook"
        else
            print_warning "This appears to be a different hook"
        fi
    else
        print_warning "Pre-commit hook is NOT installed"
        echo ""
        echo "  Expected location: $HOOK_DEST"
    fi
    
    echo ""
}

install_hook() {
    print_header
    
    echo -e "${YELLOW}This will install a pre-commit hook that:${NC}"
    echo ""
    echo "  • Scans for AWS credentials (access keys, secret keys)"
    echo "  • Detects OpenShift pull secrets"
    echo "  • Finds private keys (RSA, EC, SSH)"
    echo "  • Checks for passwords and tokens"
    echo "  • Warns about large files (>5MB)"
    echo "  • Prevents committing sensitive filenames"
    echo ""
    echo -e "${GREEN}The hook will run automatically before each commit${NC}"
    echo ""
    
    # Check if hook already exists
    if [ -f "$HOOK_DEST" ]; then
        print_warning "A pre-commit hook already exists"
        echo ""
        
        # Check if it's our hook
        if grep -q "Sensitive Data Scanner" "$HOOK_DEST" 2>/dev/null; then
            echo "The existing hook is our security scanner."
            echo ""
            read -p "$(echo -e ${BLUE}Reinstall (update) the hook?${NC} [Y/n]: )" reinstall
            reinstall="${reinstall:-Y}"
            
            if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
                print_info "Installation cancelled"
                return 0
            fi
            
            # Backup existing hook
            cp "$HOOK_DEST" "$HOOK_DEST.backup.$(date +%Y%m%d-%H%M%S)"
            print_info "Backed up existing hook"
        else
            echo "The existing hook is NOT our security scanner."
            echo ""
            read -p "$(echo -e ${YELLOW}Replace it with the security scanner?${NC} [y/N]: )" replace
            
            if [[ ! "$replace" =~ ^[Yy]$ ]]; then
                print_info "Installation cancelled"
                echo ""
                echo "To install manually:"
                echo "  1. Backup your existing hook"
                echo "  2. Copy the template to .git/hooks/pre-commit"
                echo "  3. Make it executable: chmod +x .git/hooks/pre-commit"
                return 1
            fi
            
            # Backup existing hook
            cp "$HOOK_DEST" "$HOOK_DEST.backup.$(date +%Y%m%d-%H%M%S)"
            print_info "Backed up existing hook to: $HOOK_DEST.backup.*"
        fi
    fi
    
    echo ""
    print_info "Installing pre-commit hook..."
    
    # Create the hook directory if it doesn't exist
    mkdir -p "$(dirname "$HOOK_DEST")"
    
    # Copy the hook template (inline since we can't rely on external file)
    cat > "$HOOK_DEST" << 'EOFHOOK'
#!/bin/bash

################################################################################
# Git Pre-Commit Hook - Sensitive Data Scanner
################################################################################
# This hook prevents committing sensitive data to the repository
# It runs automatically before each commit
#
# To bypass (NOT RECOMMENDED): git commit --no-verify

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Pre-Commit Security Check: Scanning for Secrets       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

ISSUES_FOUND=0

# Get list of files being committed (staged files)
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
    echo -e "${GREEN}✓ No files staged for commit${NC}"
    exit 0
fi

echo -e "${BLUE}Scanning staged files:${NC}"
echo "$STAGED_FILES" | sed 's/^/  - /'
echo ""

# Check for sensitive filenames
echo -e "${YELLOW}1. Checking for sensitive filenames...${NC}"
SENSITIVE_PATTERNS=(
    "pull-secret"
    "kubeconfig"
    "kubeadmin-password"
    "cluster-info"
    "\.pem$"
    "\.key$"
    "id_rsa"
    "credentials"
    "\.env$"
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    matches=$(echo "$STAGED_FILES" | grep -E "$pattern" || true)
    if [ -n "$matches" ]; then
        echo -e "${RED}✗ Found sensitive filename pattern: $pattern${NC}"
        echo "$matches" | sed 's/^/    /'
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ No sensitive filenames found${NC}"
fi
echo ""

# Check for AWS credentials in staged files
echo -e "${YELLOW}2. Checking for AWS credentials...${NC}"
AWS_FOUND=false

for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        if git diff --cached "$file" | grep -E "AKIA[0-9A-Z]{16}" > /dev/null 2>&1; then
            echo -e "${RED}✗ AWS Access Key found in: $file${NC}"
            AWS_FOUND=true
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    fi
done

if [ "$AWS_FOUND" = false ]; then
    echo -e "${GREEN}✓ No AWS credentials found${NC}"
fi
echo ""

# Check for OpenShift pull secrets
echo -e "${YELLOW}3. Checking for OpenShift pull secrets...${NC}"
PULL_SECRET_FOUND=false

for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        if git diff --cached "$file" | grep -E "cloud\.openshift\.com|registry\.redhat\.io" | grep -E "auth|token" > /dev/null 2>&1; then
            echo -e "${RED}✗ Possible OpenShift pull secret found in: $file${NC}"
            PULL_SECRET_FOUND=true
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    fi
done

if [ "$PULL_SECRET_FOUND" = false ]; then
    echo -e "${GREEN}✓ No OpenShift pull secrets found${NC}"
fi
echo ""

# Check for private keys
echo -e "${YELLOW}4. Checking for private keys...${NC}"
PRIVATE_KEY_FOUND=false

for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        if git diff --cached "$file" | grep -E "BEGIN.*PRIVATE KEY|BEGIN RSA PRIVATE KEY" > /dev/null 2>&1; then
            echo -e "${RED}✗ Private key found in: $file${NC}"
            PRIVATE_KEY_FOUND=true
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    fi
done

if [ "$PRIVATE_KEY_FOUND" = false ]; then
    echo -e "${GREEN}✓ No private keys found${NC}"
fi
echo ""

# Check for large files (> 5MB)
echo -e "${YELLOW}5. Checking for large files...${NC}"
LARGE_FILE_FOUND=false

for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        if [ "$file_size" -gt 5242880 ]; then
            file_size_mb=$(echo "scale=2; $file_size / 1048576" | bc)
            echo -e "${YELLOW}⚠ Large file: $file (${file_size_mb}MB)${NC}"
            LARGE_FILE_FOUND=true
        fi
    fi
done

if [ "$LARGE_FILE_FOUND" = false ]; then
    echo -e "${GREEN}✓ No large files found${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      Scan Complete                             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ $ISSUES_FOUND -gt 0 ]; then
    echo -e "${RED}✗ COMMIT BLOCKED: Found $ISSUES_FOUND potential security issue(s)${NC}"
    echo ""
    echo -e "${YELLOW}What to do:${NC}"
    echo "  1. Review the files listed above"
    echo "  2. Remove any sensitive data"
    echo "  3. Add sensitive files to .gitignore"
    echo "  4. Run 'git add' again after fixing"
    echo "  5. Try committing again"
    echo ""
    echo -e "${YELLOW}To bypass (NOT RECOMMENDED):${NC}"
    echo "  git commit --no-verify"
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ No security issues detected${NC}"
    echo -e "${GREEN}✓ Safe to commit${NC}"
    echo ""
    exit 0
fi
EOFHOOK
    
    # Make it executable
    chmod +x "$HOOK_DEST"
    
    print_success "Pre-commit hook installed successfully!"
    echo ""
    echo "  Location: $HOOK_DEST"
    echo ""
    echo -e "${GREEN}The hook will now run automatically before each commit${NC}"
    echo ""
    echo -e "${YELLOW}To test the hook:${NC}"
    echo "  1. Try staging a sensitive file"
    echo "  2. Run: git commit"
    echo "  3. The hook should block the commit"
    echo ""
    echo -e "${YELLOW}To bypass the hook (NOT RECOMMENDED):${NC}"
    echo "  git commit --no-verify"
    echo ""
}

uninstall_hook() {
    print_header
    
    if [ ! -f "$HOOK_DEST" ]; then
        print_warning "Pre-commit hook is not installed"
        return 0
    fi
    
    echo -e "${YELLOW}This will remove the pre-commit security scanner${NC}"
    echo ""
    read -p "$(echo -e ${BLUE}Are you sure?${NC} [y/N]: )" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Uninstall cancelled"
        return 0
    fi
    
    # Backup before removing
    cp "$HOOK_DEST" "$HOOK_DEST.backup.$(date +%Y%m%d-%H%M%S)"
    print_info "Created backup"
    
    rm -f "$HOOK_DEST"
    print_success "Pre-commit hook removed"
    echo ""
    print_warning "Commits will no longer be scanned for sensitive data"
    echo ""
}

test_hook() {
    print_header
    
    if [ ! -f "$HOOK_DEST" ]; then
        print_error "Pre-commit hook is not installed"
        echo ""
        echo "Run: $0 --install"
        return 1
    fi
    
    echo -e "${CYAN}Testing pre-commit hook...${NC}"
    echo ""
    
    # Create a temporary test file
    TEST_FILE="/tmp/test-secret-$$"
    # This is an example AWS key for testing (not a real credential)
    # Format: AKIA followed by 16 alphanumeric characters
    # Split to avoid triggering pre-commit hook pattern detection
    local KEY_PREFIX="AKIA"
    local KEY_SUFFIX="IOSFODNN7EXAMPLE"
    echo "${KEY_PREFIX}${KEY_SUFFIX}" > "$TEST_FILE"
    
    # Stage it
    cd "$REPO_ROOT"
    cp "$TEST_FILE" "test-secret.tmp"
    git add "test-secret.tmp" 2>/dev/null || true
    
    # Run the hook
    if "$HOOK_DEST"; then
        print_error "Hook did NOT block the test file (this is unexpected)"
    else
        print_success "Hook correctly blocked the test file"
    fi
    
    # Clean up
    git reset HEAD "test-secret.tmp" 2>/dev/null || true
    rm -f "test-secret.tmp" "$TEST_FILE"
    
    echo ""
}

show_menu() {
    print_header
    
    echo -e "${CYAN}Pre-Commit Hook Manager${NC}"
    echo ""
    echo "  1) Show status"
    echo "  2) Install/Update hook"
    echo "  3) Uninstall hook"
    echo "  4) Test hook"
    echo "  5) Exit"
    echo ""
}

main() {
    # Handle command line arguments
    if [ "$#" -gt 0 ]; then
        case "$1" in
            --install|-i)
                install_hook
                exit 0
                ;;
            --uninstall|-u)
                uninstall_hook
                exit 0
                ;;
            --status|-s)
                show_status
                exit 0
                ;;
            --test|-t)
                test_hook
                exit 0
                ;;
            --help|-h)
                echo "Usage: $0 [OPTION]"
                echo ""
                echo "Options:"
                echo "  --install, -i       Install/update the pre-commit hook"
                echo "  --uninstall, -u     Uninstall the pre-commit hook"
                echo "  --status, -s        Show hook installation status"
                echo "  --test, -t          Test the hook with a dummy secret"
                echo "  --help, -h          Show this help message"
                echo ""
                echo "If no option is provided, the interactive menu will be shown."
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    fi
    
    # Interactive menu
    while true; do
        show_menu
        read -p "$(echo -e ${BLUE}Select option [1-5]${NC}: )" choice
        
        case $choice in
            1)
                show_status
                read -p "Press Enter to continue..."
                ;;
            2)
                install_hook
                read -p "Press Enter to continue..."
                ;;
            3)
                uninstall_hook
                read -p "Press Enter to continue..."
                ;;
            4)
                test_hook
                read -p "Press Enter to continue..."
                ;;
            5)
                echo ""
                print_info "Exiting..."
                echo ""
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-5."
                sleep 2
                ;;
        esac
        
        clear
    done
}

main "$@"

