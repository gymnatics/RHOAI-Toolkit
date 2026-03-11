# Guardrails Demo - AI Safety with TrustyAI

This demo showcases AI safety features using TrustyAI Guardrails Orchestrator on OpenShift AI.

## Quick Start

### Option 1: Deploy via Toolkit (Recommended)

```bash
./rhoai-toolkit.sh
# Navigate to: RHOAI Management → Demos → Deploy Guardrails Demo
```

### Option 2: Deploy via Script

```bash
# Deploy Guardrails (will prompt for model selection)
./scripts/deploy-guardrails.sh

# Or specify namespace
./scripts/deploy-guardrails.sh my-namespace
```

### Option 3: Manual Deployment

```bash
# 1. Deploy a model first (if you don't have one)
./scripts/serve-model.sh s3 qwen3-8b Qwen/Qwen3-8B-Instruct

# 2. Deploy Guardrails manifests
export MODEL_SERVICE_NAME=qwen3-8b-predictor
export ENABLE_AUTH=false
export NAMESPACE=demo

envsubst < lib/manifests/guardrails/orchestrator-config.yaml | oc apply -n $NAMESPACE -f -
oc apply -n $NAMESPACE -f lib/manifests/guardrails/gateway-config.yaml
envsubst < lib/manifests/guardrails/orchestrator-cr.yaml | oc apply -n $NAMESPACE -f -
```

---

## What This Demo Shows

### Built-in Detectors (No GPU Required)

| Detector | What It Detects |
|----------|-----------------|
| `email` | Email addresses |
| `us-social-security-number` | US SSN (XXX-XX-XXXX) |
| `credit-card` | Credit card numbers |
| `us-phone-number` | US phone numbers |
| `ipv4` | IPv4 addresses |
| `ipv6` | IPv6 addresses |
| `uk-post-code` | UK postal codes |

### Gateway Pipelines

| Pipeline | Endpoint | Description |
|----------|----------|-------------|
| **pii** | `/pii/v1/chat/completions` | Filters PII on input and output |
| **safe** | `/safe/v1/chat/completions` | All safety checks (extensible) |
| **passthrough** | `/passthrough/v1/chat/completions` | No filtering, direct to model |

---

## Testing

### Test Detection API (Standalone)

```bash
./test-guardrails.sh [namespace]
```

Tests PII detection without requiring the model:
- Email detection
- SSN detection
- Credit card detection
- Phone number detection
- Safe content (no PII)

### Test Gateway Pipelines (With Model)

```bash
./test-gateway.sh [namespace]
```

Tests chat completions through different pipelines:
- Passthrough (no filtering)
- PII filtering
- Safe mode

### Manual Testing

```bash
# Get the gateway URL
GATEWAY=$(oc get route guardrails-orchestrator-gateway -n demo -o jsonpath='{.spec.host}')

# Test PII pipeline
curl -X POST "https://$GATEWAY/pii/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-8b",
    "messages": [{"role": "user", "content": "My email is test@example.com"}]
  }'

# Test passthrough (no filtering)
curl -X POST "https://$GATEWAY/passthrough/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-8b",
    "messages": [{"role": "user", "content": "Hello, how are you?"}]
  }'
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     User Request                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Guardrails Gateway                               │
│         Routes: /pii, /safe, /passthrough                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               Guardrails Orchestrator                            │
│                                                                  │
│  ┌──────────────┐                                               │
│  │ Built-in     │  (Sidecar container)                          │
│  │ Detector     │  - Email, SSN, Credit Card                    │
│  │ (127.0.0.1)  │  - Phone, IP addresses                        │
│  └──────────────┘                                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LLM Service                                   │
│              (Your InferenceService)                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Requirement | How to Check | How to Fix |
|-------------|--------------|------------|
| RHOAI installed | `oc get datasciencecluster` | Install RHOAI Operator |
| TrustyAI enabled | Check DSC `trustyai.managementState` | Set to `Managed` |
| KServe RawDeployment | Check DSC `kserve.rawDeploymentServiceConfig` | Set to `Headed` |
| Model deployed | `oc get isvc -n <namespace>` | Run `serve-model.sh` |

### Enable TrustyAI (if not enabled)

```bash
oc patch datasciencecluster default-dsc --type=merge \
  -p '{"spec":{"components":{"trustyai":{"managementState":"Managed"}}}}'
```

### Enable KServe RawDeployment (if not configured)

```bash
oc patch datasciencecluster default-dsc --type=merge \
  -p '{"spec":{"components":{"kserve":{"rawDeploymentServiceConfig":"Headed"}}}}'
```

---

## Enabling Authentication

By default, authentication is disabled for easier demo experience. To enable:

```bash
# Enable auth on existing deployment
oc patch guardrailsorchestrator guardrails-orchestrator -n <namespace> \
  --type=merge \
  -p '{"metadata":{"annotations":{"security.opendatahub.io/enable-auth":"true"}}}'

# Then use Bearer token for requests
TOKEN=$(oc create token default -n <namespace>)
curl -H "Authorization: Bearer $TOKEN" \
  "https://$GATEWAY/pii/v1/chat/completions" ...
```

---

## Extending with Hugging Face Detectors

For more advanced detection (HAP, prompt injection), you can add Hugging Face models:

### Deploy HAP Detector

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: guardrails-detector-runtime
  labels:
    opendatahub.io/dashboard: 'true'
    trustyai/detector: 'true'  # Label for auto-discovery
spec:
  containers:
    - name: kserve-container
      image: quay.io/trustyai/guardrails-detector-huggingface-runtime:v0.2.0
      # ... (see RHOAI docs for full spec)
---
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: hap-detector
  labels:
    trustyai/detector: 'true'
spec:
  predictor:
    model:
      modelFormat:
        name: guardrails-detector-huggingface
      storageUri: "hf://ibm-granite/granite-guardian-hap-38m"
```

### Update Orchestrator Config

Add the HF detector to your orchestrator config:

```yaml
detectors:
  built-in-detector:
    # ... existing config
  hap-detector:
    type: text_contents
    service:
      hostname: hap-detector-predictor
      port: 8080
    chunker_id: whole_doc_chunker
    default_threshold: 0.5
```

---

## Files

| File | Description |
|------|-------------|
| `README.md` | This documentation |
| `app.py` | Mock demo (Streamlit, for learning concepts) |
| `test-guardrails.sh` | Test detection API |
| `test-gateway.sh` | Test gateway pipelines |
| `requirements.txt` | Python dependencies for mock demo |

---

## Troubleshooting

### Guardrails pods not starting

```bash
# Check pod status
oc get pods -n <namespace> -l app.kubernetes.io/name=guardrails-orchestrator

# Check events
oc describe pod -n <namespace> -l app.kubernetes.io/name=guardrails-orchestrator

# Check TrustyAI operator logs
oc logs -n redhat-ods-applications -l app=trustyai-operator
```

### Health check failing

```bash
# Get health route
HEALTH=$(oc get route guardrails-orchestrator-health -n <namespace> -o jsonpath='{.spec.host}')

# Test health
curl -sk "https://$HEALTH/health"
```

### Model not connecting

```bash
# Verify model service exists
oc get svc -n <namespace> | grep predictor

# Check orchestrator config
oc get configmap guardrails-orchestrator-config -n <namespace> -o yaml
```

---

## Learn More

- [RHOAI Guardrails Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.3/html/enabling_ai_safety_with_guardrails)
- [TrustyAI Project](https://github.com/trustyai-explainability)
- [FMS Guardrails Orchestrator](https://github.com/foundation-model-stack/fms-guardrails-orchestrator)
