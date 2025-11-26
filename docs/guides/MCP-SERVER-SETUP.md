# MCP Server Setup for RHOAI GenAI Playground

## Overview

MCP (Model Context Protocol) servers enable AI agents in the RHOAI GenAI Playground to interact with external services like GitHub, weather APIs, and OpenShift clusters.

## Quick Setup

```bash
cd /Users/dayeo/Openshift-installation
chmod +x scripts/setup-mcp-servers.sh
./scripts/setup-mcp-servers.sh
```

## What Are MCP Servers?

MCP servers provide AI agents with the ability to:
- **GitHub MCP**: Explore repositories, issues, pull requests, and code
- **Weather MCP**: Get real-time weather information
- **OpenShift MCP**: Interact with cluster resources
- **Custom MCP**: Add your own integrations

## Available MCP Servers

### 1. GitHub MCP Server
- **URL**: `https://api.githubcopilot.com/mcp`
- **Purpose**: Repository exploration, code analysis, issue tracking
- **Use Cases**: Code review, project discovery, automation

### 2. Weather MCP Server
- **URL**: `https://weather-mcp-ai-bu-shared.apps.test-rc3.rhoai.rh-aiservices-bu.com/sse`
- **Purpose**: Weather data and forecasts
- **Use Cases**: Weather-aware applications, location-based services

### 3. OpenShift MCP Server
- **URL**: `https://ocp-mcp-ai-bu-shared.apps.test-rc3.rhoai.rh-aiservices-bu.com/sse`
- **Purpose**: Cluster resource management
- **Use Cases**: Deployment automation, resource monitoring

## Setup Options

### Interactive Setup (Recommended)

```bash
./scripts/setup-mcp-servers.sh
```

The script will ask you:
1. Which MCP servers to enable
2. Custom URLs (if needed)
3. Custom server configurations

### Manual Setup

Create the ConfigMap manually:

```bash
cat <<EOF | oc apply -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: redhat-ods-applications
data:
  GitHub-MCP-Server: |
    {
      "url": "https://api.githubcopilot.com/mcp",
      "description": "GitHub repository and code interaction"
    }
  Weather-MCP-Server: |
    {
      "url": "https://weather-mcp-ai-bu-shared.apps.test-rc3.rhoai.rh-aiservices-bu.com/sse",
      "description": "Weather information and forecasts"
    }
EOF
```

## Using MCP Servers

### 1. Access GenAI Playground

```bash
# Get the dashboard URL
oc get route rhods-dashboard -n redhat-ods-applications

# Open in browser
https://<dashboard-url>
```

### 2. Navigate to AI Agents

- Go to the GenAI Playground or AI Agents section
- You'll see the configured MCP servers listed

### 3. Login to MCP Servers

- Click the 🔒 (lock) symbol next to each MCP server
- **Important**: You must "login" even if authentication isn't required
- This establishes the connection

### 4. Use in Agent Workflows

Once logged in, AI agents can use these servers in their workflows:

```
Example: "Check the weather in New York and create a GitHub issue about it"
```

The agent will:
1. Use Weather MCP to get weather data
2. Use GitHub MCP to create the issue

## Adding Custom MCP Servers

### Option 1: Using the Script

```bash
./scripts/setup-mcp-servers.sh
# Select option 4 for custom server
```

### Option 2: Deploy Your Own MCP Server

1. **Deploy MCP server application**:
   ```bash
   # See examples: https://github.com/opendatahub-io/agents/tree/main/examples
   ```

2. **Add to ConfigMap**:
   ```bash
   oc edit configmap gen-ai-aa-mcp-servers -n redhat-ods-applications
   ```

3. **Add your server**:
   ```yaml
   data:
     My-Custom-Server: |
       {
         "url": "https://my-mcp-server.example.com/sse",
         "description": "My custom MCP server description"
       }
   ```

## Verification

### Check ConfigMap

```bash
oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o yaml
```

### View in Dashboard

1. Open RHOAI Dashboard
2. Go to GenAI Playground or AI Agents
3. You should see your configured MCP servers

### Test Connection

1. Click 🔒 to login to each server
2. Create a simple agent workflow that uses the server
3. Verify the agent can access the MCP server

## Troubleshooting

### MCP Server Not Showing

```bash
# Check if ConfigMap exists
oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications

# Check ConfigMap data
oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o jsonpath='{.data}'
```

### Connection Issues

- Ensure the MCP server URL is accessible
- Check if you've "logged in" using the 🔒 symbol
- Verify network connectivity from the cluster

### Update MCP Servers

```bash
# Edit existing ConfigMap
oc edit configmap gen-ai-aa-mcp-servers -n redhat-ods-applications

# Or re-run the setup script
./scripts/setup-mcp-servers.sh
```

## MCP Server Examples

### Example 1: GitHub Repository Search

**Agent Prompt**: "Find all Python repositories in the opendatahub-io organization"

**MCP Server Used**: GitHub MCP

**Result**: Agent uses GitHub MCP to search and list repositories

### Example 2: Weather-Based Decisions

**Agent Prompt**: "If it's raining in Boston, create a reminder to bring an umbrella"

**MCP Server Used**: Weather MCP

**Result**: Agent checks weather and creates reminder

### Example 3: OpenShift Resource Check

**Agent Prompt**: "List all pods in the nvidia-gpu-operator namespace"

**MCP Server Used**: OpenShift MCP

**Result**: Agent queries cluster and lists pods

## Advanced Configuration

### Authentication for MCP Servers

If your MCP server requires authentication:

1. **Add credentials to ConfigMap**:
   ```yaml
   My-Authenticated-Server: |
     {
       "url": "https://my-server.com/mcp",
       "description": "My server",
       "auth": {
         "type": "bearer",
         "token": "your-token-here"
       }
     }
   ```

2. **Or use Secrets**:
   ```bash
   oc create secret generic mcp-auth \
     --from-literal=token=your-token \
     -n redhat-ods-applications
   ```

### Multiple Environments

Create different ConfigMaps for different environments:

```bash
# Development
oc apply -f mcp-servers-dev.yaml

# Production
oc apply -f mcp-servers-prod.yaml
```

## Resources

- **MCP Server Examples**: https://github.com/opendatahub-io/agents/tree/main/examples
- **CAI Guide**: See "CAI's guide to RHOAI 3.0.txt" Section on MCP Servers
- **RHOAI Documentation**: OpenShift AI official docs

## Summary

✅ **MCP servers enable AI agents** to interact with external services  
✅ **Easy setup** with the provided script  
✅ **Multiple servers** can be configured  
✅ **Custom servers** can be added  
✅ **Login required** even without authentication  

**Setup MCP servers to unlock the full potential of AI agents in RHOAI!** 🚀

