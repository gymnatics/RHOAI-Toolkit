# LlamaStack + MCP + Guardrails Demo UI

A **reusable** Streamlit-based demo interface for testing LlamaStack with MCP tools and AI safety guardrails. This UI is fully configurable via environment variables, making it adaptable to different LlamaStack distributions, MCP servers, and use cases.

---

## Features

- ✅ **Fully Configurable** - All settings via environment variables
- ✅ **Works with Any MCP Server** - Not tied to specific tools
- ✅ **Custom System Prompts** - Define LLM behavior per deployment
- ✅ **Service Health Checks** - Real-time status for LlamaStack, MCP, and Guardrails
- ✅ **Tool Discovery** - Automatically shows available tools from LlamaStack
- ✅ **Chat Interface** - Full conversation with tool call visualization
- ✅ **AI Safety Guardrails** - TrustyAI integration for input/output safety checks
- ✅ **Warn or Block Mode** - Choose whether to warn about or block unsafe content

---

## Configuration Reference

All configuration is done via environment variables in the ConfigMap:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `LLAMASTACK_URL` | ✅ | `http://localhost:8321` | LlamaStack service endpoint |
| `MODEL_ID` | ✅ | `llama3` | Model ID registered in LlamaStack |
| `MCP_SERVER_URL` | ✅ | `http://localhost:8000` | MCP server URL (for health checks) |
| `GUARDRAILS_URL` | ❌ | (empty) | TrustyAI GuardrailsOrchestrator URL |
| `ENABLE_GUARDRAILS` | ❌ | `false` | Enable AI safety guardrails |
| `GUARDRAILS_MODE` | ❌ | `warn` | `warn` (show warning) or `block` (prevent) |
| `APP_TITLE` | ❌ | `LlamaStack + MCP Demo` | Page title |
| `APP_SUBTITLE` | ❌ | `Demonstrating AI Agent...` | Subtitle below title |
| `MCP_SERVER_NAME` | ❌ | `MCP Server` | Name shown in architecture diagram |
| `MCP_SERVER_DESCRIPTION` | ❌ | `Model Context Protocol...` | Description in architecture section |
| `CHAT_PLACEHOLDER` | ❌ | `Ask a question...` | Placeholder text in chat input |
| `SYSTEM_PROMPT` | ❌ | (generic assistant) | Custom system prompt for the LLM |

---

## Quick Start

### Prerequisites

You need these already deployed in your OpenShift namespace:
- LlamaStack distribution (any version)
- An MCP Server (any implementation)
- **MCP toolgroup registered in LlamaStack config** (see [Register MCP Server in LlamaStack](#register-mcp-server-in-llamastack) below)

### Step 1: Login to OpenShift

```bash
oc login --token=<your-token> --server=<your-cluster-api> --insecure-skip-tls-verify=true
oc project demo-test  # or your namespace
```

### Step 2: Update Configuration

Before deploying, edit `deployment.yaml` to match your environment:

```yaml
# In deployment.yaml, find the ConfigMap section and update these values:
apiVersion: v1
kind: ConfigMap
metadata:
  name: llamastack-demo-config
  namespace: your-namespace               # <-- Change to your namespace
data:
  # Required settings
  LLAMASTACK_URL: "http://your-llamastack-service.your-namespace.svc.cluster.local:8321"
  MODEL_ID: "your-model-id"               # <-- e.g., qwen3-8b, llama3, mistral
  MCP_SERVER_URL: "http://your-mcp-server.your-namespace.svc.cluster.local:8000"
  
  # Optional: Customize the UI for your use case
  APP_TITLE: "My Custom Demo"
  MCP_SERVER_NAME: "My Data Server"
  MCP_SERVER_DESCRIPTION: "Provides access to my custom data"
  CHAT_PLACEHOLDER: "Ask about my data..."
  
  # Optional: Custom system prompt
  SYSTEM_PROMPT: |
    You are an assistant with access to external data tools.
    Use the available tools to answer user questions.
    Be helpful and explain the data clearly.
```

> **Tip:** To find your LlamaStack service name, run: `oc get svc | grep -i llama`

Also update the namespace in the Deployment, Service, and Route sections.

### Step 2.5: Register MCP Server in LlamaStack

**Important:** For LlamaStack to use the MCP tools, you must register the MCP server in LlamaStack's config.

1. **Find which ConfigMap your LlamaStack is using:**
   ```bash
   oc get deployment <your-llamastack-deployment> -o yaml | grep -A5 "volumes:"
   ```
   Look for the ConfigMap name under `user-config` volume (e.g., `llama-stack-config`).

2. **Get the current config:**
   ```bash
   oc get configmap llama-stack-config -n demo-test -o jsonpath='{.data.run\.yaml}' > /tmp/llama-config.yaml
   ```

3. **Edit the config to add MCP toolgroup:**
   
   Find the `tool_groups:` section and add the MCP server:
   ```yaml
   tool_groups:
   - toolgroup_id: builtin::rag
     provider_id: rag-runtime
   - toolgroup_id: mcp::metar-weather              # <-- Add this block
     provider_id: model-context-protocol
     mcp_endpoint:
       uri: http://metar-mcp-server.demo-test.svc.cluster.local:8000/mcp
   ```

4. **Apply the updated config:**
   ```bash
   oc create configmap llama-stack-config \
     --from-file=run.yaml=/tmp/llama-config.yaml \
     -n demo-test \
     --dry-run=client -o yaml | oc apply -f -
   ```

5. **Restart LlamaStack to load the new config:**
   ```bash
   oc delete pod -l app=llama-stack -n demo-test
   # Or:
   oc rollout restart deployment/<your-llamastack-deployment> -n demo-test
   ```

6. **Verify tools are registered:**
   ```bash
   curl -s http://<llamastack-service>:8321/v1/tools | grep metar
   ```

> **Note:** There may be multiple ConfigMaps with similar names (e.g., `llama-stack-config` vs `lsd-genai-playground-config`). Make sure you update the one that's actually mounted by the deployment.

### Step 3: Build and Deploy

```bash
cd mcp-demo/llamastack-demo-ui

# Create build resources
oc apply -f buildconfig.yaml

# Build the container (wait for it to complete)
oc start-build llamastack-mcp-demo --from-dir=. --follow

# Deploy the application
oc apply -f deployment.yaml

# Wait for pod to be ready
oc rollout status deployment/llamastack-mcp-demo
```

### Step 4: Access the Application

Get the route URL:

```bash
oc get route llamastack-mcp-demo -o jsonpath='https://{.spec.host}{"\n"}'
```

Open this URL in your browser.

---

## Using the Demo UI

### First Time Setup

1. Open the route URL in your browser
2. In the sidebar, click **"🔄 Check"** to verify services are online
3. Click **"🔄 Refresh Tools"** to load available MCP tools

### Asking Questions

Type questions in the chat input at the bottom:

- "What's the weather in Delhi?"
- "Show me weather at VIDP"
- "List all available stations"
- "What airports have fog?"

The UI will show:
- Tool calls being made (green boxes)
- Tool results (blue boxes)
- Final AI response

---

## Updating Configuration After Deployment

If you need to change the LlamaStack URL, Model ID, or MCP Server URL after deployment:

### Option 1: Edit ConfigMap directly

```bash
# Open the ConfigMap in your default editor
oc edit configmap llamastack-demo-config

# Change the values, save, and exit
# Then restart the deployment to pick up changes:
oc rollout restart deployment/llamastack-mcp-demo
```

### Option 2: Patch specific values

```bash
# Example: Change the model ID
oc patch configmap llamastack-demo-config -p '{"data":{"MODEL_ID":"gpt-4o"}}'

# Restart to apply
oc rollout restart deployment/llamastack-mcp-demo
```

### Option 3: Use the UI sidebar

You can also temporarily change URLs in the sidebar under "🌐 Endpoints" (these changes are session-only and don't persist).

---

## Example Configurations

### Example 1: METAR Weather Data (Aviation)

```yaml
data:
  LLAMASTACK_URL: "http://lsd-genai-playground-service.demo-test.svc.cluster.local:8321"
  MODEL_ID: "qwen3-8b"
  MCP_SERVER_URL: "http://metar-mcp-server.demo-test.svc.cluster.local:8000"
  APP_TITLE: "Aviation Weather Assistant"
  MCP_SERVER_NAME: "METAR Weather"
  MCP_SERVER_DESCRIPTION: "METAR aviation weather data from MongoDB"
  CHAT_PLACEHOLDER: "Ask about airport weather (e.g., 'What's the weather in Delhi?')"
  SYSTEM_PROMPT: |
    You are an aviation weather assistant with access to METAR data.
    Use the search_metar_data tool to fetch real weather data.
    Common ICAO codes: VIDP (Delhi), VABB (Mumbai), VOBL (Bangalore).
    Explain weather data in a user-friendly way.
```

### Example 2: Customer Database

```yaml
data:
  LLAMASTACK_URL: "http://llamastack-prod.sales.svc.cluster.local:8321"
  MODEL_ID: "llama3-70b"
  MCP_SERVER_URL: "http://customer-api.sales.svc.cluster.local:8080"
  APP_TITLE: "Sales Assistant"
  MCP_SERVER_NAME: "Customer Database"
  MCP_SERVER_DESCRIPTION: "Access customer records and sales data"
  CHAT_PLACEHOLDER: "Ask about customers or sales..."
  SYSTEM_PROMPT: |
    You are a sales assistant with access to customer data.
    Use the available tools to look up customer information.
    Always protect sensitive data and follow data privacy guidelines.
```

### Example 3: Document Search (RAG)

```yaml
data:
  LLAMASTACK_URL: "http://llamastack.docs.svc.cluster.local:8321"
  MODEL_ID: "mistral-7b"
  MCP_SERVER_URL: "http://doc-search.docs.svc.cluster.local:8000"
  APP_TITLE: "Documentation Search"
  MCP_SERVER_NAME: "Doc Search"
  MCP_SERVER_DESCRIPTION: "Search internal documentation and knowledge base"
  CHAT_PLACEHOLDER: "Search documentation..."
  SYSTEM_PROMPT: |
    You are a documentation assistant.
    Use the knowledge_search tool to find relevant documents.
    Always cite the source documents in your responses.
```

---

## Troubleshooting

### Pod not starting

```bash
# Check pod status
oc get pods -l app=llamastack-mcp-demo

# Check events
oc get events --sort-by='.lastTimestamp' | tail -20

# Check logs
oc logs deployment/llamastack-mcp-demo
```

### Services showing "OFFLINE" in UI

1. Click "🔄 Check" to refresh status
2. If still offline, verify the services exist:
   ```bash
   oc get svc | grep -E "lsd-genai|metar-mcp"
   ```
3. Check if pods are running:
   ```bash
   oc get pods | grep -E "lsd-genai|metar-mcp"
   ```

### No tools found (or only RAG tools showing)

This usually means the MCP server is not registered in LlamaStack's config.

1. **Check if MCP toolgroup is in the config:**
   ```bash
   oc get configmap llama-stack-config -n demo-test -o jsonpath='{.data.run\.yaml}' | grep -A5 "mcp::"
   ```
   If nothing is returned, you need to register the MCP server. See [Register MCP Server in LlamaStack](#register-mcp-server-in-llamastack).

2. **Verify you updated the correct ConfigMap:**
   ```bash
   # Check which ConfigMap is mounted
   oc get deployment lsd-genai-playground -o yaml | grep -A10 "volumes:"
   ```
   The `user-config` volume shows which ConfigMap to update.

3. **Ensure MCP server is running:**
   ```bash
   oc get pods | grep metar-mcp
   oc logs deployment/metar-mcp-server --tail=50
   ```

4. **Restart LlamaStack after config changes:**
   ```bash
   oc delete pod -l app=llama-stack
   ```

### Tool calls fail

1. Check if vLLM has tool-call-parser enabled:
   ```bash
   oc get deployment <your-model>-predictor -o yaml | grep -A5 "args:"
   ```
   Should include `--enable-auto-tool-choice` and `--tool-call-parser=hermes`

2. Check LlamaStack logs during the request:
   ```bash
   oc logs -f deployment/lsd-genai-playground
   ```

---

## Files in This Directory

| File | Purpose |
|------|---------|
| `app.py` | Streamlit application code |
| `requirements.txt` | Python dependencies |
| `Dockerfile` | Container build instructions |
| `deployment.yaml` | ConfigMap + Deployment + Service + Route |
| `buildconfig.yaml` | OpenShift BuildConfig + ImageStream |
| `README.md` | This file |

---

## Rebuilding After Code Changes

If you modify `app.py`:

```bash
# Start a new build
oc start-build llamastack-mcp-demo --from-dir=. --follow

# The deployment will auto-update when the new image is pushed
# Or force a restart:
oc rollout restart deployment/llamastack-mcp-demo
```
