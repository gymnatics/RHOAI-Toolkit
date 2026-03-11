# MaaS Demo - Model as a Service on OpenShift AI

Interactive demos showcasing MaaS (Model as a Service) capabilities on Red Hat OpenShift AI.

## Quick Start

### CLI Demo (Recommended for Quick Testing)

```bash
# Run the interactive demo
./demo-maas.sh

# Or specify endpoint manually
./demo-maas.sh --endpoint https://inference-gateway.apps.cluster.example.com
```

### Web Demo (Recommended for Presentations)

```bash
# Install dependencies
pip install -r requirements.txt

# Run Streamlit app
streamlit run app.py

# Open http://localhost:8501
```

---

## What This Demo Shows

### Core Features

| Feature | Description |
|---------|-------------|
| **Model Discovery** | List all MaaS-enabled models across namespaces |
| **Token Generation** | Create API tokens with custom expiration |
| **Chat Interface** | Interactive chat with any model |
| **Streaming** | Real-time streaming responses |
| **Model Comparison** | Same prompt to multiple models, side-by-side |
| **Response Metrics** | Latency, token usage, model info |

### MaaS Value Propositions Demonstrated

1. **Centralized API** - One endpoint for all models
2. **Authentication** - Token-based access control
3. **Model Flexibility** - Switch models without code changes
4. **Enterprise Ready** - Rate limiting, quotas, governance

---

## CLI Demo Menu

```
╔════════════════════════════════════════════════════════════════╗
║                    MaaS Interactive Demo                        ║
╚════════════════════════════════════════════════════════════════╝

1) Check MaaS Status
   Show RHOAI version, MaaS endpoint, available models

2) Generate Token
   Create API token with custom duration (1h, 24h, etc.)

3) Chat with Model
   Interactive chat session with streaming support

4) Compare Models
   Send same prompt to multiple models, see side-by-side results

5) View Response Metrics
   Show latency, token usage from last request

0) Exit
```

---

## Web Demo Features

### Sidebar
- **Connection**: Endpoint URL, API token, connection status
- **Model Selection**: Dropdown of available models
- **Settings**: Temperature, max tokens, streaming toggle

### Main Area
- **Chat Tab**: Interactive chat interface
- **Comparison Tab**: Multi-model comparison
- **Metrics Tab**: Response time, token usage charts

---

## Prerequisites

### For CLI Demo
- `oc` CLI installed and logged in
- `jq` for JSON parsing
- `curl` for API calls
- MaaS infrastructure set up (`./scripts/setup-maas.sh`)
- At least one model deployed with MaaS enabled

### For Web Demo
- Python 3.8+
- MaaS endpoint URL
- Valid API token

---

## Setup MaaS (If Not Already Done)

```bash
# 1. Setup MaaS infrastructure
./scripts/setup-maas.sh

# 2. Deploy a model with MaaS enabled
./demo/setup-demo-model.sh

# 3. Generate a token
./demo/generate-maas-token.sh

# 4. Run the demo
./demo/maas-demo/demo-maas.sh
```

---

## Manual Implementation

If you want to set up MaaS manually without the demo scripts:

### Step 1: Setup MaaS Infrastructure

For **RHOAI 3.3+** (integrated MaaS):

```bash
# 1. Install RHCL Operator
oc create namespace kuadrant-system

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kuadrant-system
  namespace: kuadrant-system
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhcl-operator
  namespace: kuadrant-system
spec:
  channel: stable
  installPlanApproval: Automatic
  name: rhcl-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# 2. Create Kuadrant instance
cat <<EOF | oc apply -f -
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
EOF

# 3. Enable MaaS in DataScienceCluster
oc patch datasciencecluster default-dsc --type=merge -p '{
  "spec": {
    "components": {
      "kserve": {
        "modelsAsService": {
          "managementState": "Managed"
        }
      }
    }
  }
}'

# 4. Create GatewayClass and Gateway
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')

cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: openshift-ai-inference
  namespace: openshift-ingress
spec:
  gatewayClassName: openshift-ai-inference
  listeners:
    - allowedRoutes:
        namespaces:
          from: All
      hostname: inference-gateway.${CLUSTER_DOMAIN}
      name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - group: ''
            kind: Secret
            name: default-gateway-tls
        mode: Terminate
EOF
```

### Step 2: Deploy a Model with MaaS

For **RHOAI 3.3+** (LLMInferenceService):

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: my-model
  namespace: demo
  annotations:
    security.opendatahub.io/enable-auth: "true"
spec:
  replicas: 1
  model:
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:latest
    name: RedHatAI/Qwen3-8B-FP8-dynamic
  router:
    route: {}
    gateway: {}
  template:
    containers:
    - name: main
      resources:
        limits:
          nvidia.com/gpu: "1"
```

For **RHOAI 3.2** (InferenceService with annotation):

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: my-model
  namespace: demo
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    maas.opendatahub.io/enabled: "true"
    security.opendatahub.io/enable-auth: "true"
spec:
  predictor:
    model:
      modelFormat:
        name: pytorch
      runtime: vllm-runtime
      storage:
        key: aws-connection-models
        path: models/my-model
```

### Step 3: Generate Token and Test

```bash
# Generate token
TOKEN=$(oc create token default -n demo --duration=1h)

# Get endpoint
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
MAAS_ENDPOINT="inference-gateway.${CLUSTER_DOMAIN}"  # RHOAI 3.3+
# MAAS_ENDPOINT="maas.${CLUSTER_DOMAIN}"             # RHOAI 3.2

# Test
curl -X POST "https://$MAAS_ENDPOINT/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "my-model",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## API Examples

### List Models
```bash
curl -s "https://$MAAS_ENDPOINT/v1/models" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Chat Completion
```bash
curl -X POST "https://$MAAS_ENDPOINT/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "my-model",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

### Streaming
```bash
curl -X POST "https://$MAAS_ENDPOINT/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "my-model",
    "messages": [{"role": "user", "content": "Tell me a story"}],
    "stream": true
  }'
```

---

## Files

| File | Description |
|------|-------------|
| `README.md` | This documentation |
| `demo-maas.sh` | CLI interactive demo |
| `app.py` | Streamlit web demo |
| `requirements.txt` | Python dependencies |

---

## Troubleshooting

### "MaaS endpoint not found"
- Ensure MaaS is set up: `./scripts/setup-maas.sh`
- Check RHOAI version: RHOAI 3.3+ uses integrated MaaS

### "Unauthorized" errors
- Token may be expired, generate a new one
- Check token has correct audience

### "Model not found"
- Ensure model has MaaS enabled
- Check model is in Running state: `oc get isvc -A`

### No models listed
- Deploy a model with MaaS: `./demo/setup-demo-model.sh`
- For RHOAI 3.3+: Use `LLMInferenceService` with `maasEnabled: true`
