# Demo Applications

This folder contains demo scripts and applications for RHOAI.

> **RHOAI 3.3 Compatibility**: All demos are compatible with RHOAI 3.3. The LlamaStack demo benefits from Llama Stack 0.4.2 improvements. MaaS demos work with both the integrated 3.3 MaaS and legacy setup.

> **MaaS demos & RHOAI version**: `maas-demo/` targets RHOAI 3.3's tier-based MaaS
> only -- its entry scripts detect RHOAI 3.4+/3.5 and exit with guidance rather than
> run against the wrong system (subscription CRDs replaced tiers in 3.4; body-based
> routing replaced per-model URLs in 3.5). `setup-demo-model.sh`,
> `generate-maas-token.sh`, and `test-maas-api.sh` (this directory, not
> `maas-demo/`) are version-aware and work across 3.3/3.4/3.5. For RHOAI 3.4+/3.5
> rate limiting and governance demos, use [`maas-ratelimit-demo/`](maas-ratelimit-demo/)
> and `../scripts/deploy-maas-model.sh` / `../scripts/verify-maas.sh` instead.

> **RHOAI 3.5+ note**: The Llama Stack Operator has been renamed to **OGX** (DSC field
> `llamastackoperator` -> `ogx`; CRD `LlamaStackDistribution` -> `OGXServer`). The
> LlamaStack-related demos and functions in this repo (`lib/functions/llamastack.sh`,
> `demo/autorag-demo/`) detect your RHOAI version automatically and deploy an
> `OGXServer` instead of a `LlamaStackDistribution` on 3.5+. See
> [docs/guides/rhoai-3.5/RHOAI-35-WHATS-NEW.md](../docs/guides/rhoai-3.5/RHOAI-35-WHATS-NEW.md).

## 📁 Contents

| Directory/File | Description |
|----------------|-------------|
| `banking-demo/` | **Banking Feature Store Demo** - Feast feature store with banking data |
| `mlflow-tracing-demo/` | **MLflow Tracing Demo** - Banking multi-agent system with MLflow 3.x distributed tracing |
| `guardrails-demo/` | **Guardrails Demo** - TrustyAI AI safety with PII detection |
| `lemonade-trustyai-demo/` | **Lemonade Stand Assistant (TrustyAI Edition)** - upstream FMS Orchestr8 guardrails demo (HAP + prompt-injection + language detectors) |
| `guidellm-demo/` | **GuideLLM Demo** - LLM benchmarking (TTFT, ITL, throughput) |
| `llamastack-demo/` | **LlamaStack/OGX + MCP Demo UI** - Streamlit chatbot frontend (version-aware: OGX on RHOAI 3.5+) |
| `maas-demo/` | **MaaS Demo** - Interactive CLI and web demo for Model as a Service |
| `open-webui-demo/` | **Open WebUI Demo** - Chat interface for multiple models |
| `agentic-platform-demo/` | **Managed Agentic AI Platform** - Enterprise AI agent platform with Loan Processing Agent, KAgenti, MCP Gateway, OPA policies, Keycloak OIDC, Grafana dashboards, Dify, Tekton pipelines, Istio mesh |
| `lib/` | Shared utilities (version detection) |
| `setup-demo-model.sh` | Deploy a sample model with MaaS |
| `test-maas-api.sh` | Test MaaS API endpoints |
| `generate-maas-token.sh` | Generate MaaS API token |

---

## 🤖 LlamaStack/OGX Demo UI

A Streamlit-based chatbot that demonstrates LlamaStack (RHOAI 3.4 and earlier) or OGX
(RHOAI 3.5+, replaces LlamaStack) orchestrating LLM + MCP tools.

### Quick Deploy

```bash
# From the main directory
./rhoai-toolkit.sh
# Select: 3) RHOAI Management
# Select: 7) Deploy LlamaStack Demo UI
```

### Features
- Real-time MCP tool call visualization
- Service health checks (LlamaStack/OGX, MCP)
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

## 🍋 Lemonade Stand Assistant (TrustyAI Edition)

Vendors and deploys the upstream [rh-ai-quickstart/lemonade-stand-assistant](https://github.com/rh-ai-quickstart/lemonade-stand-assistant)
Helm chart as-is: Llama 3.2 3B + TrustyAI Guardrails Orchestrator (FMS Orchestr8) wired to
HAP, prompt-injection, and language detectors, plus a chat app and Shiny metrics dashboard.

Different from `lemonade-stand-demo/` (which proxies through **NeMo Guardrails** instead).

```bash
./demo/lemonade-trustyai-demo/deploy.sh
```

See `lemonade-trustyai-demo/README.md` for full documentation.

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

> The examples below are legacy (RHOAI 3.2 and earlier, `maas-api` namespace).
> For current versions, see the version-specific examples further down.

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

## API Usage by RHOAI Version

### RHOAI 3.3 (Tech Preview, tier-based)

```bash
# Token: OpenShift SA token, audience must be https://kubernetes.default.svc
TOKEN=$(oc create token default -n <namespace> --audience=https://kubernetes.default.svc --duration=1h)

curl -sk -X POST "https://inference-gateway.apps.<cluster>/<namespace>/<model>/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"model": "<model>", "messages": [{"role": "user", "content": "Hello!"}]}'
```

### RHOAI 3.4 (GA, subscription-based)

```bash
HOST="https://maas.apps.<cluster>"

# API key (sk-oai-*), NOT /maas-api/v1/tokens -- that legacy endpoint no longer exists
API_KEY=$(curl -sk -X POST "${HOST}/maas-api/v1/api-keys" \
  -H "Authorization: Bearer $(oc whoami -t)" -H "Content-Type: application/json" \
  -d '{"name":"demo","subscription":"<sub-name>","expiresIn":"1h"}' | jq -r '.key')

# Per-model URL routing (same pattern as 3.3, but with the sk-oai-* key)
curl -sk -X POST "${HOST}/<namespace>/<model>/v1/chat/completions" \
  -H "Authorization: Bearer ${API_KEY}" -H "Content-Type: application/json" \
  -d '{"model": "<model>", "messages": [{"role": "user", "content": "Hello!"}]}'
```

### RHOAI 3.5+ (body-based routing)

```bash
HOST="https://maas.apps.<cluster>"

API_KEY=$(curl -sk -X POST "${HOST}/maas-api/v1/api-keys" \
  -H "Authorization: Bearer $(oc whoami -t)" -H "Content-Type: application/json" \
  -d '{"name":"demo","subscription":"<sub-name>","expiresIn":"1h"}' | jq -r '.key')

# GET /v1/models to find the exact model id (publishers/<ns>/models/<name> --
# <name> is spec.model.name, which may differ from the k8s resource name)
curl -sk "${HOST}/v1/models" -H "Authorization: Bearer ${API_KEY}"

# Single shared endpoint -- model id goes in the BODY, not the URL path
curl -sk -X POST "${HOST}/v1/chat/completions" \
  -H "Authorization: Bearer ${API_KEY}" -H "Content-Type: application/json" \
  -d '{"model": "publishers/<ns>/models/<name>", "messages": [{"role": "user", "content": "Hello!"}]}'
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

