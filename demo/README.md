# Demo Applications

This folder contains demo scripts and applications for RHOAI.

> **RHOAI 3.3 Compatibility**: All demos are compatible with RHOAI 3.3. The LlamaStack demo benefits from Llama Stack 0.4.2 improvements. MaaS demos work with both the integrated 3.3 MaaS and legacy setup.

## 📁 Contents

| Directory/File | Description |
|----------------|-------------|
| `banking-demo/` | **Banking Feature Store Demo** - Feast feature store with banking data |
| `guardrails-demo/` | **Guardrails Demo** - TrustyAI AI safety with PII detection |
| `guidellm-demo/` | **GuideLLM Demo** - LLM benchmarking (TTFT, ITL, throughput) |
| `llamastack-demo/` | **LlamaStack + MCP Demo UI** - Streamlit chatbot frontend |
| `maas-demo/` | **MaaS Demo** - Interactive CLI and web demo for Model as a Service |
| `open-webui-demo/` | **Open WebUI Demo** - Chat interface for multiple models |
| `lib/` | Shared utilities (version detection) |
| `setup-demo-model.sh` | Deploy a sample model with MaaS |
| `test-maas-api.sh` | Test MaaS API endpoints |
| `generate-maas-token.sh` | Generate MaaS API token |

---

## 🤖 LlamaStack Demo UI

A Streamlit-based chatbot that demonstrates LlamaStack orchestrating LLM + MCP tools.

### Quick Deploy

```bash
# From the main directory
./rhoai-toolkit.sh
# Select: 3) RHOAI Management
# Select: 7) Deploy LlamaStack Demo UI
```

### Features
- Real-time MCP tool call visualization
- Service health checks (LlamaStack, MCP)
- Automatic tool discovery
- Configurable via environment variables

### Manual Deploy

```bash
cd llamastack-demo
oc apply -f buildconfig.yaml
oc start-build llamastack-mcp-demo --from-dir=. --follow
oc apply -f deployment.yaml
```

See `llamastack-demo/README.md` for full documentation.

---

## 🛡️ Guardrails Demo

Deploy TrustyAI Guardrails Orchestrator to protect LLMs with PII detection and safety filters.

### Quick Start

```bash
# From the main directory
./rhoai-toolkit.sh
# Select: RHOAI Management → Demos → Deploy Guardrails Demo
```

Or via script:
```bash
./scripts/deploy-guardrails.sh [namespace]
```

### Features
- **Built-in detectors**: Email, SSN, credit card, phone, IP address detection
- **Gateway pipelines**: `/pii`, `/safe`, `/passthrough` endpoints
- **Model integration**: Connects to your deployed InferenceService
- **Optional auth**: Enable/disable authentication

### Prerequisites
- TrustyAI component enabled in DataScienceCluster
- KServe RawDeployment mode configured
- A deployed model (script will offer to deploy one if none exists)

See `guardrails-demo/README.md` for full documentation.

> **Note**: The `app.py` file is a legacy mock demo for learning concepts locally without OpenShift.

---

## 💰 MaaS Demo

Scripts and examples for using Model as a Service (MaaS) with RHOAI.

## Prerequisites

Before running these demos, ensure:

1. **RHOAI is installed** with GenAI Playground and MaaS UI enabled
2. **MaaS infrastructure is set up**:
   ```bash
   cd ..
   ./scripts/setup-maas.sh
   ```
3. **GPU nodes are available** in your cluster
4. **S3 Data Connection configured** with model storage
   - Create via RHOAI Dashboard: Data Science Projects → Add data connection
   - Or via CLI (see setup script for details)
5. **Models available in S3** bucket (e.g., from Hugging Face)

## What is MaaS?

Model as a Service (MaaS) provides:
- **API endpoints** for deployed models
- **Token-based authentication** for secure access
- **Rate limiting** and usage tracking
- **Multi-tenant support** for different users/teams

## Demo Scripts

### 1. `setup-demo-model.sh`
Deploys a sample model (Llama 3.2-3B) with MaaS enabled.

```bash
./setup-demo-model.sh
```

### 2. `test-maas-api.sh`
Tests the MaaS API endpoint with a sample prompt.

```bash
./test-maas-api.sh
```

### 3. `generate-maas-token.sh`
Generates a MaaS API token for authentication.

```bash
./generate-maas-token.sh
```

## Quick Start

1. **Set up MaaS** (if not already done):
   ```bash
   cd ..
   ./scripts/setup-maas.sh
   ```

2. **Deploy a demo model**:
   ```bash
   ./setup-demo-model.sh
   ```

3. **Generate an API token**:
   ```bash
   ./generate-maas-token.sh
   ```

4. **Test the API**:
   ```bash
   ./test-maas-api.sh
   ```

## Manual Steps (via Dashboard)

### Deploy a Model with MaaS

1. Log in to RHOAI Dashboard
2. Go to **Models** → **Deploy Model**
3. Select a model (e.g., Llama 3.2-3B)
4. Choose **vLLM** runtime
5. Select **gpu-profile**
6. **Enable "Model as a Service"** checkbox
7. Click **Deploy**
8. Wait for status: **Running**

### Generate MaaS Token

1. Go to **Models as a Service**
2. Click **Generate Token**
3. Copy the token
4. Save it securely (you'll need it for API calls)

### Get API Endpoint

1. Go to **AI Assets** → **Endpoints**
2. Find your model
3. Copy the **MaaS API endpoint** URL

## API Usage Examples

### Using curl

```bash
# Set your token and endpoint
export MAAS_TOKEN="your-token-here"
export MAAS_ENDPOINT="https://maas-api-maas-api.apps.your-cluster.com/v1/chat/completions"

# Make a request
curl -X POST "$MAAS_ENDPOINT" \
  -H "Authorization: Bearer $MAAS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-3-2-3b",
    "messages": [
      {"role": "user", "content": "What is OpenShift?"}
    ],
    "max_tokens": 100
  }'
```

### Using Python

```python
import requests

MAAS_TOKEN = "your-token-here"
MAAS_ENDPOINT = "https://maas-api-maas-api.apps.your-cluster.com/v1/chat/completions"

headers = {
    "Authorization": f"Bearer {MAAS_TOKEN}",
    "Content-Type": "application/json"
}

data = {
    "model": "llama-3-2-3b",
    "messages": [
        {"role": "user", "content": "What is OpenShift?"}
    ],
    "max_tokens": 100
}

response = requests.post(MAAS_ENDPOINT, headers=headers, json=data)
print(response.json())
```

## Troubleshooting

### MaaS API not ready
```bash
# Check if MaaS pods are running
oc get pods -n maas-api

# Check MaaS API logs
oc logs -n maas-api -l app=maas-api
```

### Token authentication fails
```bash
# Verify Authorino is running
oc get pods -n kuadrant-system | grep authorino

# Check AuthPolicy
oc get authpolicy -n maas-api
```

### Model not accessible via MaaS
- Ensure model was deployed with "Model as a Service" enabled
- Check model status in dashboard
- Verify model is in "Running" state

## Additional Resources

- **RHOAI Documentation**: https://access.redhat.com/documentation/en-us/red_hat_openshift_ai/
- **MaaS Setup Script**: `../scripts/setup-maas.sh`
- **Troubleshooting Guide**: `../docs/TROUBLESHOOTING.md`

## Notes

- MaaS tokens are scoped to your user account
- Rate limiting is enforced per token
- API follows OpenAI-compatible format
- Supports streaming responses (add `"stream": true`)

