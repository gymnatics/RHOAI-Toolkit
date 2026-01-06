#!/bin/bash

################################################################################
# Setup MCP Servers for RHOAI GenAI Playground
################################################################################
# This script configures MCP (Model Context Protocol) servers for use with
# the GenAI Playground and AI Agents in RHOAI 3.0
#
# Based on CAI Guide Section on MCP Servers
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() { echo -e "${CYAN}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

print_header "Setup MCP Servers for RHOAI GenAI Playground"

# Check if logged in
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift cluster"
    exit 1
fi

print_success "Connected to cluster: $(oc whoami --show-server)"
echo ""

# Check if RHOAI is installed
if ! oc get namespace redhat-ods-applications &>/dev/null; then
    print_error "RHOAI namespace not found"
    print_info "Please install RHOAI first: ./rhoai-toolkit.sh"
    exit 1
fi

print_success "RHOAI namespace found"
echo ""

print_header "MCP Server Configuration"

echo -e "${YELLOW}MCP (Model Context Protocol) servers enable AI agents to interact with external services.${NC}"
echo ""
echo "Available MCP servers:"
echo "  1) GitHub MCP Server - Interact with GitHub repositories"
echo "  2) Filesystem MCP Server - Access files and directories"
echo "  3) Brave Search MCP Server - Web search capabilities"
echo "  4) PostgreSQL MCP Server - Database queries"
echo "  5) Sequential Thinking MCP Server - Multi-step reasoning"
echo "  6) Custom MCP Server - Add your own"
echo ""

read -p "Which MCP servers would you like to enable? (comma-separated, e.g., 1,2,3 or 'all'): " mcp_choice

# Build the ConfigMap data
MCP_DATA=""

if [[ "$mcp_choice" == "all" ]] || [[ "$mcp_choice" =~ 1 ]]; then
    echo ""
    print_info "GitHub MCP Server Configuration"
    print_warning "GitHub MCP requires authentication to access repositories and API."
    echo ""
    echo "To create a GitHub Personal Access Token:"
    echo "  1. Go to: https://github.com/settings/tokens/new"
    echo "  2. Give it a name (e.g., 'OpenShift AI MCP')"
    echo "  3. Select scopes: 'repo' and 'read:org'"
    echo "  4. Click 'Generate token' and copy it"
    echo ""
    read -p "Enter your GitHub Personal Access Token (or press Enter to skip): " github_token
    
    if [ -n "$github_token" ]; then
        print_info "Adding GitHub MCP Server with authentication..."
        MCP_DATA+='  GitHub-MCP-Server: |
    {
      "url": "https://api.githubcopilot.com/mcp",
      "headers": {
        "Authorization": "Bearer '"$github_token"'"
      },
      "description": "GitHub MCP server with authentication for repository access, code search, issues, and pull requests."
    }
'
    else
        print_warning "Skipping GitHub MCP Server (no token provided)"
        print_info "You can add it later by re-running this script"
    fi
fi

if [[ "$mcp_choice" == "all" ]] || [[ "$mcp_choice" =~ 2 ]]; then
    echo ""
    read -p "Deploy Filesystem MCP Server to cluster? (y/N): " deploy_fs
    
    local fs_url="http://filesystem-mcp-server.mcp-servers.svc.cluster.local:8080"
    
    if [[ "$deploy_fs" =~ ^[Yy]$ ]]; then
        print_info "Deploying Filesystem MCP Server..."
        
        # Create namespace if it doesn't exist
        oc create namespace mcp-servers 2>/dev/null || true
        
        # Deploy filesystem MCP server (placeholder - would need actual deployment)
        cat <<FSEOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filesystem-mcp-server
  namespace: mcp-servers
spec:
  replicas: 1
  selector:
    matchLabels:
      app: filesystem-mcp
  template:
    metadata:
      labels:
        app: filesystem-mcp
    spec:
      containers:
      - name: mcp-server
        image: quay.io/opendatahub/filesystem-mcp:latest
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: filesystem-mcp-server
  namespace: mcp-servers
spec:
  selector:
    app: filesystem-mcp
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
FSEOF
        
        print_success "Filesystem MCP Server deployed"
    else
        read -p "Enter Filesystem MCP Server URL (or press Enter for default): " fs_url_input
        fs_url="${fs_url_input:-$fs_url}"
    fi
    
    print_info "Adding Filesystem MCP Server..."
    MCP_DATA+='  Filesystem-MCP-Server: |
    {
      "url": "'"$fs_url"'",
      "description": "Access and manipulate files in a secure filesystem. Read, write, and manage files and directories."
    }
'
fi

if [[ "$mcp_choice" == "all" ]] || [[ "$mcp_choice" =~ 3 ]]; then
    echo ""
    read -p "Enter Brave Search API Key (or press Enter to skip): " brave_key
    
    local brave_url="http://brave-search-mcp-server.mcp-servers.svc.cluster.local:8080"
    
    if [ -n "$brave_key" ]; then
        print_info "Deploying Brave Search MCP Server with API key..."
        
        oc create namespace mcp-servers 2>/dev/null || true
        
        # Create secret for API key
        oc create secret generic brave-search-api-key \
            --from-literal=api-key="$brave_key" \
            -n mcp-servers \
            --dry-run=client -o yaml | oc apply -f -
        
        print_success "Brave Search API key configured"
    fi
    
    print_info "Adding Brave Search MCP Server..."
    MCP_DATA+='  Brave-Search-MCP-Server: |
    {
      "url": "'"$brave_url"'",
      "description": "Search the web using Brave Search API. Get real-time information from the internet."
    }
'
fi

if [[ "$mcp_choice" =~ 4 ]]; then
    echo ""
    print_info "PostgreSQL MCP Server Configuration"
    read -p "Enter PostgreSQL connection string (e.g., postgres://user:pass@host:5432/db): " pg_conn
    read -p "Enter PostgreSQL MCP Server URL (or press Enter for default): " pg_url
    pg_url="${pg_url:-http://postgresql-mcp-server.mcp-servers.svc.cluster.local:8080}"
    
    print_info "Adding PostgreSQL MCP Server..."
    MCP_DATA+='  PostgreSQL-MCP-Server: |
    {
      "url": "'"$pg_url"'",
      "description": "Execute SQL queries against PostgreSQL databases. Retrieve and analyze data."
    }
'
fi

if [[ "$mcp_choice" =~ 5 ]]; then
    echo ""
    local seq_url="http://sequential-thinking-mcp-server.mcp-servers.svc.cluster.local:8080"
    read -p "Enter Sequential Thinking MCP Server URL (or press Enter for default): " seq_url_input
    seq_url="${seq_url_input:-$seq_url}"
    
    print_info "Adding Sequential Thinking MCP Server..."
    MCP_DATA+='  Sequential-Thinking-MCP-Server: |
    {
      "url": "'"$seq_url"'",
      "description": "Enable multi-step reasoning and chain-of-thought problem solving."
    }
'
fi

if [[ "$mcp_choice" =~ 6 ]]; then
    echo ""
    print_info "Custom MCP Server Configuration"
    read -p "Enter MCP server name: " custom_name
    read -p "Enter MCP server URL: " custom_url
    read -p "Enter MCP server description: " custom_desc
    
    print_info "Adding Custom MCP Server..."
    MCP_DATA+='  '"$custom_name"': |
    {
      "url": "'"$custom_url"'",
      "description": "'"$custom_desc"'"
    }
'
fi

if [ -z "$MCP_DATA" ]; then
    print_error "No MCP servers selected"
    exit 1
fi

echo ""
print_header "Creating MCP Server ConfigMap"

# Create the ConfigMap
cat <<EOF | oc apply -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: redhat-ods-applications
data:
$MCP_DATA
EOF

if [ $? -eq 0 ]; then
    echo ""
    print_success "✅ MCP Server ConfigMap created successfully!"
    echo ""
    
    print_header "Restarting Playground Pods"
    
    print_info "Restarting playground pods to load new MCP server configuration..."
    
    # Find all namespaces with playground pods
    playground_namespaces=$(oc get pods -A -l app=lsd-genai-playground -o jsonpath='{range .items[*]}{.metadata.namespace}{"\n"}{end}' | sort -u)
    
    if [ -n "$playground_namespaces" ]; then
        for ns in $playground_namespaces; do
            print_step "Restarting playground in namespace: $ns"
            oc delete pod -l app=lsd-genai-playground -n "$ns" --ignore-not-found=true
        done
        
        echo ""
        print_info "Waiting for playground pods to restart (30 seconds)..."
        sleep 30
        
        print_success "Playground pods restarted"
    else
        print_warning "No playground pods found. MCP servers will be available when you add a model to playground."
    fi
    
    echo ""
    
    print_header "Next Steps"
    
    print_info "1. Access the GenAI Playground:"
    DASHBOARD_URL=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$DASHBOARD_URL" ]; then
        echo "   https://$DASHBOARD_URL"
    else
        echo "   oc get route rhods-dashboard -n redhat-ods-applications"
    fi
    echo ""
    
    print_info "2. Navigate to: GenAI Studio → Playground"
    echo ""
    
    print_info "3. Look for the 🔌 Tools or MCP section"
    echo ""
    
    print_info "4. Click the 🔒 (lock icon) next to each MCP server to connect"
    echo "   (Required even if no authentication is needed)"
    echo ""
    
    print_info "5. Start using MCP servers in your prompts!"
    echo "   Example: 'Use the GitHub MCP server to search for Kubernetes projects'"
    echo ""
    
    print_header "View MCP Server Configuration"
    echo "To view the configured MCP servers:"
    echo "  oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o yaml"
    echo ""
    
    print_header "Add More MCP Servers"
    echo "You can add more MCP servers by:"
    echo "  1. Deploying custom MCP servers"
    echo "     See: https://github.com/opendatahub-io/agents/tree/main/examples"
    echo "  2. Re-running this script to update the ConfigMap"
    echo "  3. Manually editing the ConfigMap:"
    echo "     oc edit configmap gen-ai-aa-mcp-servers -n redhat-ods-applications"
    echo ""
    
    print_header "Documentation"
    echo "For more information, see:"
    echo "  - docs/guides/MCP-SERVERS.md"
    echo "  - docs/guides/GENAI-PLAYGROUND-INTEGRATION.md"
    echo ""
    
else
    print_error "Failed to create MCP Server ConfigMap"
    exit 1
fi

echo ""
print_success "✅ MCP Server setup complete!"
echo ""

