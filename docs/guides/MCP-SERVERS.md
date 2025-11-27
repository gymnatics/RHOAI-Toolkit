# MCP Servers in RHOAI 3.0 GenAI Playground

## Overview

**MCP (Model Context Protocol)** is a standardized protocol that enables LLMs to interact with external tools, data sources, and services. In RHOAI 3.0, MCP servers extend the GenAI Playground with:
- **Tool Calling**: Allow models to use external functions
- **Data Access**: Connect to databases, APIs, and file systems
- **Service Integration**: Integrate with GitHub, Jira, Slack, etc.
- **Custom Tools**: Build your own MCP servers

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GenAI Playground (UI)                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│               LlamaStack Backend Pod                         │
│  (lsd-genai-playground)                                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              MCP Server ConfigMap                            │
│  (gen-ai-aa-mcp-servers)                                     │
└────────────────────┬────────────────────────────────────────┘
                     │
          ┌──────────┴──────────┬──────────────────┐
          ▼                     ▼                  ▼
    ┌───────────┐         ┌───────────┐     ┌────────────┐
    │  GitHub   │         │ Filesystem│     │   Custom   │
    │MCP Server │         │MCP Server │     │MCP Server  │
    └───────────┘         └───────────┘     └────────────┘
```

## Prerequisites

- RHOAI 3.0 with GenAI Studio enabled
- At least one model added to Playground
- Models must support tool calling (e.g., Llama 3.2, Mistral)

## Enabling MCP Servers

### Step 1: Create MCP Servers ConfigMap

MCP servers are configured via a ConfigMap in the `redhat-ods-applications` namespace:

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: redhat-ods-applications
data:
  GitHub-MCP-Server: |
    {
      "url": "https://api.githubcopilot.com/mcp",
      "description": "The GitHub MCP server enables exploration and interaction with repositories, code, and developer resources on GitHub. It provides programmatic access to repositories, issues, pull requests, and related project data, allowing automation and integration within development workflows."
    }
  Filesystem-MCP-Server: |
    {
      "url": "http://filesystem-mcp-server.mcp-servers.svc.cluster.local:8080",
      "description": "Access and manipulate files in a secure filesystem. Read, write, and manage files and directories."
    }
  Brave-Search-MCP-Server: |
    {
      "url": "http://brave-search-mcp-server.mcp-servers.svc.cluster.local:8080",
      "description": "Search the web using Brave Search API. Get real-time information from the internet."
    }
```

**Apply the ConfigMap**:

```bash
oc apply -f mcp-servers-configmap.yaml
```

### Step 2: Restart LlamaStack Pod

For the changes to take effect:

```bash
# Find the playground pod
oc get pods -n ai-bu-shared | grep lsd-genai-playground

# Delete it (will auto-recreate with new config)
oc delete pod -l app=lsd-genai-playground -n ai-bu-shared

# Wait for new pod to start
oc wait --for=condition=Ready pod -l app=lsd-genai-playground -n ai-bu-shared --timeout=120s
```

### Step 3: Verify MCP Servers in Playground

1. Go to **GenAI Studio → Playground**
2. Look for the **🔌 Tools** or **MCP** section
3. Your configured MCP servers should appear
4. Click **🔒** (lock icon) to authenticate (even if no auth required)

## Pre-built MCP Servers

### 1. GitHub MCP Server

**URL**: `https://api.githubcopilot.com/mcp`

**Capabilities**:
- Search repositories
- View file contents
- Create and manage issues
- Review pull requests
- Access commit history

**Example Usage**:
```
Prompt: "Search for Python projects related to machine learning on GitHub"
Prompt: "Show me the README from the opendatahub-io/odh-dashboard repository"
```

### 2. Filesystem MCP Server

**URL**: `http://filesystem-mcp-server.<namespace>.svc.cluster.local:8080`

**Capabilities**:
- Read files and directories
- Write and create files
- List directory contents
- Delete files (with permissions)

**Example Usage**:
```
Prompt: "List all files in /data/models"
Prompt: "Read the content of /data/config.yaml"
```

### 3. Brave Search MCP Server

**URL**: Brave Search API endpoint

**Capabilities**:
- Web search
- Real-time information retrieval
- News and articles

**Example Usage**:
```
Prompt: "Search for the latest news about OpenShift AI"
Prompt: "What are the top 5 Python machine learning libraries?"
```

## Deploying Custom MCP Servers

### Example: Simple Echo MCP Server

#### 1. Create the MCP Server Application

**Python Example** (`mcp-server.py`):

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"})

@app.route('/tools', methods=['GET'])
def tools():
    """List available tools"""
    return jsonify({
        "tools": [
            {
                "name": "echo",
                "description": "Echo back the input text",
                "parameters": {
                    "text": {"type": "string", "description": "Text to echo"}
                }
            }
        ]
    })

@app.route('/execute', methods=['POST'])
def execute():
    """Execute a tool"""
    data = request.json
    tool_name = data.get('tool')
    params = data.get('parameters', {})
    
    if tool_name == 'echo':
        return jsonify({
            "result": f"Echo: {params.get('text', '')}"
        })
    
    return jsonify({"error": "Unknown tool"}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

#### 2. Create Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY mcp-server.py .

EXPOSE 8080
CMD ["python", "mcp-server.py"]
```

**requirements.txt**:
```
Flask==3.0.0
```

#### 3. Build and Push Image

```bash
# Build image
podman build -t quay.io/your-org/echo-mcp-server:v1 .

# Push to registry
podman push quay.io/your-org/echo-mcp-server:v1
```

#### 4. Deploy to OpenShift

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mcp-servers
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-mcp-server
  namespace: mcp-servers
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo-mcp-server
  template:
    metadata:
      labels:
        app: echo-mcp-server
    spec:
      containers:
      - name: mcp-server
        image: quay.io/your-org/echo-mcp-server:v1
        ports:
        - containerPort: 8080
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: echo-mcp-server
  namespace: mcp-servers
spec:
  selector:
    app: echo-mcp-server
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
```

**Deploy**:
```bash
oc apply -f echo-mcp-server.yaml
```

#### 5. Add to MCP ConfigMap

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: redhat-ods-applications
data:
  Echo-MCP-Server: |
    {
      "url": "http://echo-mcp-server.mcp-servers.svc.cluster.local:8080",
      "description": "A simple echo server for testing MCP integration"
    }
```

## MCP Server Examples from opendatahub-io/agents

The OpenDataHub team provides several pre-built MCP servers:

```bash
# Clone the agents repository
git clone https://github.com/opendatahub-io/agents.git
cd agents/examples
```

**Available Examples**:
1. **Filesystem MCP** - File system access
2. **PostgreSQL MCP** - Database queries
3. **Brave Search MCP** - Web search
4. **Sequential Thinking MCP** - Multi-step reasoning
5. **Memory MCP** - Persistent conversation memory

**Deploy Example**:
```bash
# Deploy Filesystem MCP server
oc apply -f agents/examples/filesystem-mcp/deployment.yaml

# Deploy Brave Search MCP server
oc apply -f agents/examples/brave-search-mcp/deployment.yaml
```

## Authenticating MCP Servers

Some MCP servers require authentication:

### Option 1: Environment Variables

Add credentials to the MCP server deployment:

```yaml
spec:
  template:
    spec:
      containers:
      - name: mcp-server
        env:
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: mcp-server-secret
              key: api-key
```

### Option 2: OAuth/Token in ConfigMap

Include auth tokens in the MCP ConfigMap:

```yaml
data:
  Authenticated-MCP-Server: |
    {
      "url": "https://api.example.com/mcp",
      "description": "An authenticated MCP server",
      "auth": {
        "type": "bearer",
        "token": "your-api-token-here"
      }
    }
```

**⚠️ Security Note**: Store sensitive tokens in Secrets, not ConfigMaps!

## Using MCP Servers in Playground

### Step 1: Connect to MCP Server

1. In the Playground, look for the **🔌 Tools** section
2. Find your MCP server in the list
3. Click the **🔒** lock icon next to it
4. If authentication is required, enter credentials
5. Wait for "Connected" status

### Step 2: Use MCP Tools in Prompts

Once connected, you can ask the model to use the tools:

**Example Prompts**:

```
"Use the GitHub MCP server to search for repositories related to Kubernetes operators"

"Can you read the file /data/config.yaml using the Filesystem MCP server?"

"Search the web for the latest OpenShift AI release notes using Brave Search"

"List all tables in the database using the PostgreSQL MCP server"
```

The model will:
1. Recognize the need to use a tool
2. Call the appropriate MCP server
3. Receive the results
4. Formulate a response based on the data

## Troubleshooting

### MCP Server Not Appearing in Playground

**Check ConfigMap**:
```bash
oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o yaml
```

**Verify format**:
- JSON must be valid
- URL must be accessible
- Description is required

**Restart playground**:
```bash
oc delete pod -l app=lsd-genai-playground -n ai-bu-shared
```

### "Connection Failed" Error

**Test connectivity from playground pod**:
```bash
# Get playground pod name
POD=$(oc get pods -n ai-bu-shared -l app=lsd-genai-playground -o name)

# Test connection
oc exec -n ai-bu-shared $POD -- curl -v http://echo-mcp-server.mcp-servers.svc.cluster.local:8080/health
```

**Common issues**:
- MCP server pod not running
- Service misconfigured
- Network policy blocking traffic
- Incorrect URL in ConfigMap

### Model Not Using MCP Tools

**Requirements**:
- Model must support tool calling
- Tool calling must be enabled in model deployment
- Model must be "connected" to MCP server (click 🔒)

**Check model args**:
```bash
oc get inferenceservice <model-name> -n <namespace> -o yaml | grep -A 5 args
```

Should include:
```yaml
args:
  - '--enable-auto-tool-choice'
  - '--tool-call-parser=llama3_json'  # or appropriate parser
```

### MCP Server Returns Errors

**Check MCP server logs**:
```bash
oc logs -n mcp-servers deployment/echo-mcp-server
```

**Validate MCP response format**:
MCP servers must return JSON in this format:
```json
{
  "result": "Tool execution result",
  "error": null
}
```

## Best Practices

1. **Security**
   - Store API keys in Secrets, not ConfigMaps
   - Use RBAC to limit MCP server access
   - Validate all user inputs in custom MCP servers
   - Use HTTPS/TLS for external MCP servers

2. **Performance**
   - Cache frequently accessed data
   - Set appropriate timeouts
   - Use async/await for I/O operations
   - Monitor MCP server resource usage

3. **Reliability**
   - Implement health checks
   - Handle errors gracefully
   - Add retry logic for transient failures
   - Log all tool calls for debugging

4. **Documentation**
   - Provide clear tool descriptions
   - Document required parameters
   - Include usage examples
   - Maintain API versioning

5. **Testing**
   - Test MCP servers independently
   - Validate JSON responses
   - Test with various prompts
   - Monitor playground interactions

## CLI Quick Reference

```bash
# Create/update MCP ConfigMap
oc apply -f mcp-servers-configmap.yaml

# View MCP ConfigMap
oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o yaml

# Restart playground to load new MCP servers
oc delete pod -l app=lsd-genai-playground -n ai-bu-shared

# Deploy custom MCP server
oc apply -f my-mcp-server.yaml

# Check MCP server logs
oc logs -n mcp-servers deployment/my-mcp-server

# Test MCP server health
oc exec -n ai-bu-shared deployment/lsd-genai-playground -- \
  curl http://my-mcp-server.mcp-servers.svc.cluster.local:8080/health

# List all MCP servers
oc get svc -n mcp-servers
```

## Related Documentation

- [OpenDataHub Agents GitHub](https://github.com/opendatahub-io/agents)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [Tool Calling Guide](TOOL-CALLING-GUIDE.md)
- [GenAI Playground Integration](GENAI-PLAYGROUND-INTEGRATION.md)

## Status

✅ **Available in RHOAI 3.0**  
📚 Based on CAI Guide Section 2 (Steps 5-6) - MCP Servers Configuration  
🔗 Reference: https://github.com/opendatahub-io/agents/tree/main/examples

