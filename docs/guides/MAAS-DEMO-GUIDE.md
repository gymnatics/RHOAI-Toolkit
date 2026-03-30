# MaaS Demo Guide for RHOAI 3.3+

A comprehensive guide for setting up and running the Model as a Service (MaaS) demo on Red Hat OpenShift AI 3.3+.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
  - [Infrastructure Requirements](#infrastructure-requirements)
  - [Running the Setup Script](#running-the-setup-script)
  - [Manual Setup Steps](#manual-setup-steps)
- [Authentication](#authentication)
- [API Reference](#api-reference)
- [Running the Demos](#running-the-demos)
- [Troubleshooting](#troubleshooting)
- [Version Differences](#version-differences)

---

## Overview

MaaS (Model as a Service) provides a centralized API gateway for accessing LLM models deployed on OpenShift AI. Key benefits include:

| Feature | Description |
|---------|-------------|
| **Centralized Access** | Single endpoint for all models across namespaces |
| **Authentication** | Token-based access control via Kubernetes ServiceAccounts |
| **Authorization** | RBAC-based access to specific models |
| **Rate Limiting** | Tier-based quotas via TokenRateLimitPolicy |
| **Path-Based Routing** | `/<namespace>/<model>/v1/...` URL structure |

### RHOAI 3.3 MaaS Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         External Client                              │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  inference-gateway.apps.<cluster-domain>                            │
│  (AWS ELB / LoadBalancer)                                           │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  openshift-ai-inference Gateway (Istio/Envoy)                       │
│  Namespace: openshift-ingress                                       │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  AuthPolicy: openshift-ai-inference-authn                    │   │
│  │  - Token Review (audience: https://kubernetes.default.svc)   │   │
│  │  - SubjectAccessReview (can user GET llminferenceservices?)  │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  HTTPRoute: /<namespace>/<model>/v1/...                             │
│  Routes to InferencePool in target namespace                        │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  LLMInferenceService (llm-d)                                        │
│  Namespace: maas-demo                                               │
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │  Router/Scheduler │  │  EPP Service     │  │  Model Pod       │  │
│  │  (request routing)│  │  (endpoint picker)│  │  (vLLM engine)   │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Cluster Requirements

| Requirement | Details |
|-------------|---------|
| OpenShift | 4.16+ |
| RHOAI | 3.2+ (3.3 recommended for integrated MaaS) |
| GPU Nodes | At least 1 node with NVIDIA GPU |
| Operators | NFD, NVIDIA GPU Operator, LWS, Kueue |

### Operator Checklist

```bash
# Verify required operators are installed
oc get csv -A | grep -E "nfd|gpu|kueue|lws|rhods"
```

Expected output:
```
nvidia-gpu-operator         gpu-operator-certified.v24.x.x
nfd                         nfd.v4.x.x
openshift-lws-operator      leader-worker-set.v1.0.0
openshift-operators         kueue-operator.v1.x.x
redhat-ods-operator         rhods-operator.3.3.0
```

---

## Quick Start

```bash
# 1. Navigate to demo directory
cd /path/to/Openshift-installation/demo

# 2. Run the setup script (handles all infrastructure)
./setup-demo-model.sh

# 3. Wait for model to be ready (5-10 minutes)
oc get llminferenceservice -n maas-demo -w

# 4. Generate a token
TOKEN=$(oc create token default -n maas-demo --duration=1h \
  --audience=https://kubernetes.default.svc)

# 5. Test the API
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
curl -sk "https://inference-gateway.${CLUSTER_DOMAIN}/maas-demo/qwen3-4b/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen3-4b", "messages": [{"role": "user", "content": "Hello!"}]}'
```

---

## Detailed Setup

### Infrastructure Requirements

The `setup-demo-model.sh` script automatically handles these, but here's what's needed:

#### 1. LeaderWorkerSet (LWS) Operator Instance

llm-d requires LWS for multi-node workloads. The operator may be installed but not configured.

```bash
# Check if LWS CRD exists
oc get crd leaderworkersets.leaderworkerset.x-k8s.io

# If not, create the operator instance
cat <<EOF | oc apply -f -
apiVersion: operator.openshift.io/v1
kind: LeaderWorkerSetOperator
metadata:
  name: cluster
spec:
  managementState: Managed
EOF

# Wait for CRD
oc wait --for=condition=Established crd/leaderworkersets.leaderworkerset.x-k8s.io --timeout=60s
```

#### 2. Gateway TLS Certificate

The inference gateway needs a TLS certificate.

```bash
# Check if certificate exists
oc get secret default-gateway-tls -n openshift-ingress

# If not, create self-signed certificate
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
GATEWAY_HOSTNAME="inference-gateway.${CLUSTER_DOMAIN}"

# Create OpenSSL config
cat > /tmp/openssl.cnf << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext
x509_extensions = v3_ext

[dn]
CN = inference-gateway

[req_ext]
subjectAltName = @alt_names

[v3_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${GATEWAY_HOSTNAME}
DNS.2 = *.${CLUSTER_DOMAIN}
EOF

# Generate certificate
openssl req -x509 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -days 365 -nodes -config /tmp/openssl.cnf

# Create secret
oc create secret tls default-gateway-tls -n openshift-ingress \
  --cert=/tmp/tls.crt --key=/tmp/tls.key

# Restart gateway pod to pick up certificate
oc delete pod -n openshift-ingress -l app=openshift-ai-inference
```

#### 3. GPU Node Tolerations

GPU nodes typically have taints. Models need tolerations to schedule.

```yaml
# In LLMInferenceService spec.template
tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
```

### Running the Setup Script

```bash
./setup-demo-model.sh
```

The script will:
1. ✅ Check prerequisites (RHOAI, LLMInferenceService CRD)
2. ✅ Create LWS operator instance if needed
3. ✅ Create TLS certificate if needed
4. ✅ Check MaaS gateway status
5. ✅ Check for GPU nodes
6. ✅ Create project/namespace
7. ✅ Deploy LLMInferenceService with:
   - OCI model image (no S3 required)
   - GPU toleration
   - Tool calling enabled
   - Authentication annotation

### Manual Setup Steps

If you prefer manual setup:

#### Step 1: Create Namespace

```bash
oc new-project maas-demo
oc label namespace maas-demo opendatahub.io/dashboard=true
```

#### Step 2: Deploy LLMInferenceService

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-4b
  namespace: maas-demo
  labels:
    kueue.x-k8s.io/queue-name: default
    opendatahub.io/dashboard: "true"
    opendatahub.io/genai-asset: "true"
  annotations:
    security.opendatahub.io/enable-auth: "true"
    openshift.io/display-name: "Qwen3-4B"
spec:
  replicas: 1
  model:
    uri: oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b
    name: qwen3-4b
  router:
    route: {}
    gateway: {}
    scheduler: {}
  template:
    containers:
    - name: main
      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: "--enable-auto-tool-choice --tool-call-parser=hermes"
      resources:
        limits:
          cpu: '4'
          memory: 16Gi
          nvidia.com/gpu: "1"
        requests:
          cpu: '2'
          memory: 8Gi
          nvidia.com/gpu: "1"
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
```

```bash
oc apply -f llminferenceservice.yaml
```

#### Step 3: Wait for Ready

```bash
# Watch status
oc get llminferenceservice qwen3-4b -n maas-demo -w

# Check pods
oc get pods -n maas-demo

# View logs if needed
oc logs -n maas-demo -l app.kubernetes.io/name=qwen3-4b -c main --tail=50
```

---

## Authentication

### How Authentication Works in RHOAI 3.3+

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Client Request │────▶│  AuthPolicy     │────▶│  Model Service  │
│  + Bearer Token │     │  (Authorino)    │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌─────────────────┐
                        │ 1. TokenReview  │
                        │    (validate    │
                        │     token)      │
                        └─────────────────┘
                               │
                               ▼
                        ┌─────────────────┐
                        │ 2. SubjectAccess│
                        │    Review (can  │
                        │    user GET     │
                        │    llmisvc?)    │
                        └─────────────────┘
```

### Token Audience

**Critical**: RHOAI 3.3+ requires a specific token audience.

| Gateway | Audience |
|---------|----------|
| `openshift-ai-inference` (RHOAI 3.3+) | `https://kubernetes.default.svc` |
| `maas-default-gateway` (Legacy) | `maas-default-gateway-sa` |

### Generating Tokens

```bash
# RHOAI 3.3+ (correct audience)
TOKEN=$(oc create token default -n maas-demo --duration=1h \
  --audience=https://kubernetes.default.svc)

# Verify token
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq .aud
# Should show: ["https://kubernetes.default.svc"]
```

### RBAC Requirements

The ServiceAccount must have permission to `get` the LLMInferenceService:

```bash
# Check permissions
oc auth can-i get llminferenceservices \
  --as=system:serviceaccount:maas-demo:default -n maas-demo

# If "no", grant access
oc create rolebinding maas-model-access \
  --clusterrole=admin \
  --serviceaccount=maas-demo:default \
  -n maas-demo
```

### Disabling Authentication (Testing Only)

```bash
oc patch llminferenceservice qwen3-4b -n maas-demo --type=merge \
  -p '{"metadata":{"annotations":{"security.opendatahub.io/enable-auth":"false"}}}'
```

---

## API Reference

### Endpoint Structure

```
https://inference-gateway.<cluster-domain>/<namespace>/<model>/v1/<endpoint>
```

Example:
```
https://inference-gateway.apps.cluster.example.com/maas-demo/qwen3-4b/v1/chat/completions
```

### Available Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/models` | GET | List model info |
| `/v1/chat/completions` | POST | Chat completion |
| `/v1/completions` | POST | Text completion |
| `/health` | GET | Health check |
| `/metrics` | GET | Prometheus metrics |

### Chat Completion Request

```bash
curl -sk "https://inference-gateway.${CLUSTER_DOMAIN}/maas-demo/qwen3-4b/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-4b",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What is OpenShift AI?"}
    ],
    "temperature": 0.7,
    "max_tokens": 500,
    "stream": false
  }'
```

### Streaming Response

```bash
curl -sk "https://inference-gateway.${CLUSTER_DOMAIN}/maas-demo/qwen3-4b/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-4b",
    "messages": [{"role": "user", "content": "Tell me a story"}],
    "stream": true
  }'
```

### Tool Calling

```bash
curl -sk "https://inference-gateway.${CLUSTER_DOMAIN}/maas-demo/qwen3-4b/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-4b",
    "messages": [{"role": "user", "content": "What is the weather in Tokyo?"}],
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "get_weather",
          "description": "Get weather for a location",
          "parameters": {
            "type": "object",
            "properties": {
              "location": {"type": "string", "description": "City name"}
            },
            "required": ["location"]
          }
        }
      }
    ],
    "tool_choice": "auto"
  }'
```

---

## Running the Demos

### CLI Demo

```bash
cd demo/maas-demo
./demo-maas.sh
```

Features:
- Check MaaS status
- Generate tokens
- Interactive chat
- Model comparison
- Response metrics

### Web Demo (Streamlit)

```bash
cd demo/maas-demo

# Option 1: Auto-configured launcher (recommended)
./run-demo.sh

# Option 2: Manual setup
pip install -r requirements.txt
streamlit run app.py
```

#### Auto-Configuration Features

The `run-demo.sh` launcher automatically:
- Detects cluster endpoint from `oc` CLI
- Finds deployed LLMInferenceServices
- Generates API token with correct audience
- Sets environment variables for Streamlit

```bash
# Launcher options
./run-demo.sh                      # Auto-detect everything
./run-demo.sh --namespace myns     # Specify namespace
./run-demo.sh --model mymodel      # Specify model
./run-demo.sh --no-token           # Skip token generation
```

#### Manual Configuration

Open http://localhost:8501 and either:

1. **Auto-detect**: Click **🔍 Auto-Detect** then **🔑 Gen Token**
2. **Manual**: Enter settings:
   - **Endpoint**: `inference-gateway.apps.<cluster-domain>`
   - **Namespace**: `maas-demo`
   - **Model Name**: `qwen3-4b`
   - **Token**: Click **Gen Token** or paste manually
   - **API Mode**: `path-based` (for RHOAI 3.3+)

---

## Troubleshooting

### Model Pod Stuck in Pending

**Symptom**: Pod shows `Pending` status

```bash
oc describe pod -n maas-demo -l app.kubernetes.io/name=qwen3-4b
```

**Common causes**:

| Cause | Solution |
|-------|----------|
| GPU taint not tolerated | Add `nvidia.com/gpu` toleration |
| No GPU nodes available | Check `oc get nodes -l nvidia.com/gpu.present=true` |
| Insufficient resources | Check node capacity |

### LeaderWorkerSet Error

**Symptom**: `ReconcileMultiNodeWorkloadError` in LLMInferenceService status

```bash
oc get llminferenceservice qwen3-4b -n maas-demo -o yaml | grep -A5 conditions
```

**Solution**: Create LWS operator instance

```bash
cat <<EOF | oc apply -f -
apiVersion: operator.openshift.io/v1
kind: LeaderWorkerSetOperator
metadata:
  name: cluster
spec:
  managementState: Managed
EOF
```

### Authentication Failures (401)

**Symptom**: `401 Unauthorized` or `x-ext-auth-reason: not authenticated`

**Check token audience**:
```bash
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq .aud
```

**Solution**: Use correct audience
```bash
TOKEN=$(oc create token default -n maas-demo --duration=1h \
  --audience=https://kubernetes.default.svc)
```

### Authorization Failures (403)

**Symptom**: `403 Forbidden`

**Check RBAC**:
```bash
oc auth can-i get llminferenceservices \
  --as=system:serviceaccount:maas-demo:default -n maas-demo
```

**Solution**: Grant access
```bash
oc create rolebinding maas-model-access \
  --clusterrole=admin \
  --serviceaccount=maas-demo:default \
  -n maas-demo
```

### Gateway TLS Errors

**Symptom**: `filter_chain_not_found` in gateway logs

```bash
oc logs -n openshift-ingress -l app=openshift-ai-inference --tail=20
```

**Solution**: Create TLS certificate (see [Infrastructure Requirements](#infrastructure-requirements))

### External Access Timeout

**Symptom**: Curl to external endpoint times out

**Cause**: DNS resolves to wrong LoadBalancer

**Workaround**: Test internally
```bash
# From within cluster
oc run test --rm -i --restart=Never --image=curlimages/curl -- \
  curl -sk "https://openshift-ai-inference-openshift-ai-inference.openshift-ingress.svc.cluster.local:443/maas-demo/qwen3-4b/v1/models" \
  -H "Host: inference-gateway.apps.<cluster-domain>"
```

---

## Version Differences

### RHOAI 3.3+ vs 3.2

| Feature | RHOAI 3.3+ | RHOAI 3.2 |
|---------|------------|-----------|
| Model CRD | `LLMInferenceService` | `InferenceService` with annotation |
| Gateway | `openshift-ai-inference` | `maas-default-gateway` |
| API Routing | Path-based: `/<ns>/<model>/v1/...` | Legacy: `/v1/...` |
| Token Audience | `https://kubernetes.default.svc` | `maas-default-gateway-sa` |
| MaaS Setup | Integrated (DSC component) | Kustomize-based |

### Model Deployment Comparison

**RHOAI 3.3+ (LLMInferenceService)**:
```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: my-model
  annotations:
    security.opendatahub.io/enable-auth: "true"
spec:
  model:
    uri: oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b
```

**RHOAI 3.2 (InferenceService)**:
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: my-model
  annotations:
    maas.opendatahub.io/enabled: "true"
    security.opendatahub.io/enable-auth: "true"
spec:
  predictor:
    model:
      runtime: vllm-runtime
```

---

## Available Models

The setup script offers these OCI-based models (no S3 required):

| Model | Size | Tool Calling | Image |
|-------|------|--------------|-------|
| Qwen3-4B | 4B | ✅ (hermes) | `quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b` |
| Llama 3.2-3B | 3B | ✅ (llama3_json) | `quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct` |
| Granite 3.0-8B | 8B | ✅ (hermes) | `quay.io/redhat-ai-services/modelcar-catalog:granite-3.0-8b-instruct` |

---

## Quick Reference

```bash
# Check model status
oc get llminferenceservice -n maas-demo

# Check pods
oc get pods -n maas-demo

# View model logs
oc logs -n maas-demo -l app.kubernetes.io/name=qwen3-4b -c main -f

# Generate token (RHOAI 3.3+)
TOKEN=$(oc create token default -n maas-demo --duration=1h \
  --audience=https://kubernetes.default.svc)

# Test API
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
curl -sk "https://inference-gateway.${CLUSTER_DOMAIN}/maas-demo/qwen3-4b/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen3-4b", "messages": [{"role": "user", "content": "Hello!"}]}'

# Disable auth (testing)
oc patch llminferenceservice qwen3-4b -n maas-demo --type=merge \
  -p '{"metadata":{"annotations":{"security.opendatahub.io/enable-auth":"false"}}}'

# Re-enable auth
oc patch llminferenceservice qwen3-4b -n maas-demo --type=merge \
  -p '{"metadata":{"annotations":{"security.opendatahub.io/enable-auth":"true"}}}'
```

---

## Tier-Based Rate Limiting

RHOAI 3.3 includes built-in tier support for controlling API access and rate limits.

### How Tiers Work

Tiers are based on **OpenShift groups**. Users are assigned to tiers by adding them to the corresponding group.

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  API Request    │────▶│  AuthPolicy     │────▶│  TokenRateLimit │
│  + Bearer Token │     │  (validates     │     │  Policy         │
│                 │     │   token)        │     │  (checks tier)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │                        │
                               ▼                        ▼
                        ┌─────────────────┐     ┌─────────────────┐
                        │ Extract user    │     │ Apply rate      │
                        │ groups from     │     │ limit based     │
                        │ token           │     │ on group        │
                        └─────────────────┘     └─────────────────┘
```

### Built-in Tier Configuration

Tiers are defined in the `tier-to-group-mapping` ConfigMap:

```bash
oc get configmap tier-to-group-mapping -n redhat-ods-applications -o yaml
```

Default tiers:

| Tier | Level | Groups | Default Rate Limit |
|------|-------|--------|-------------------|
| 🆓 Free | 0 | `tier-free-users`, `system:authenticated` | 1,000 tokens/hr |
| ⭐ Premium | 1 | `tier-premium-users`, `premium-group` | 10,000 tokens/hr |
| 👑 Enterprise | 2 | `tier-enterprise-users`, `enterprise-group`, `admin-group` | 100,000 tokens/hr |

**Note**: All authenticated users default to the Free tier via `system:authenticated`.

### Assigning Users to Tiers

```bash
# Create tier groups (if they don't exist)
oc adm groups new tier-premium-users
oc adm groups new tier-enterprise-users

# Add user to Premium tier
oc adm groups add-users tier-premium-users myuser

# Add user to Enterprise tier
oc adm groups add-users tier-enterprise-users myuser

# Verify user's groups
oc get groups -o jsonpath='{range .items[*]}{.metadata.name}: {.users}{"\n"}{end}' | grep myuser
```

### Configuring Rate Limits

Rate limits are enforced via `TokenRateLimitPolicy` (Kuadrant). The demo script configures this automatically.

#### View Current Policy

```bash
oc get tokenratelimitpolicy -n openshift-ingress -o yaml
```

#### Example TokenRateLimitPolicy

```yaml
apiVersion: kuadrant.io/v1alpha1
kind: TokenRateLimitPolicy
metadata:
  name: maas-tier-limits
  namespace: openshift-ingress
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: openshift-ai-inference
  limits:
    free-tier:
      rates:
        - limit: 1000      # tokens
          window: 1h       # per hour
      when:
        - predicate: 'request.path.matches("/.*/v1/chat/completions")'
        - predicate: 'auth.identity.groups.exists(g, g == "system:authenticated")'
      counters:
        - expression: auth.identity.uid
    premium-tier:
      rates:
        - limit: 10000
          window: 1h
      when:
        - predicate: 'request.path.matches("/.*/v1/chat/completions")'
        - predicate: 'auth.identity.groups.exists(g, g == "tier-premium-users")'
      counters:
        - expression: auth.identity.uid
    enterprise-tier:
      rates:
        - limit: 100000
          window: 1h
      when:
        - predicate: 'request.path.matches("/.*/v1/chat/completions")'
        - predicate: 'auth.identity.groups.exists(g, g == "tier-enterprise-users")'
      counters:
        - expression: auth.identity.uid
```

### How Token Counting Works

The `TokenRateLimitPolicy` uses the `usage.total_tokens` field from the OpenAI-compatible API response:

```json
{
  "choices": [...],
  "usage": {
    "prompt_tokens": 50,
    "completion_tokens": 150,
    "total_tokens": 200  // ← This is counted
  }
}
```

Each request's `total_tokens` is added to the user's counter. When the limit is reached, subsequent requests receive HTTP 429.

### Testing Rate Limits

```bash
# Generate token
TOKEN=$(oc create token default -n maas-demo --duration=1h \
  --audience=https://kubernetes.default.svc)

# Send requests until rate limited
for i in {1..100}; do
  echo "Request $i:"
  curl -sk "https://inference-gateway.${CLUSTER_DOMAIN}/maas-demo/qwen3-4b/v1/chat/completions" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"model": "qwen3-4b", "messages": [{"role": "user", "content": "Count to 100"}], "max_tokens": 500}' \
    -w "\nHTTP Status: %{http_code}\n" -o /dev/null
  
  # Stop if rate limited
  [ $? -eq 0 ] || break
done
```

### Customizing Tier Limits

To change rate limits, edit the `TokenRateLimitPolicy`:

```bash
# Edit the policy
oc edit tokenratelimitpolicy maas-tier-limits -n openshift-ingress

# Or patch specific limit
oc patch tokenratelimitpolicy maas-tier-limits -n openshift-ingress --type=merge -p '
{
  "spec": {
    "limits": {
      "free-tier": {
        "rates": [{"limit": 2000, "window": "1h"}]
      }
    }
  }
}'
```

### Adding Custom Tiers

1. **Add group mapping** to ConfigMap:

```bash
oc edit configmap tier-to-group-mapping -n redhat-ods-applications
```

Add:
```yaml
- name: custom-tier
  displayName: Custom Tier
  level: 3
  groups:
    - custom-tier-users
```

2. **Create the group**:

```bash
oc adm groups new custom-tier-users
```

3. **Add rate limit** to TokenRateLimitPolicy:

```bash
oc patch tokenratelimitpolicy maas-tier-limits -n openshift-ingress --type=merge -p '
{
  "spec": {
    "limits": {
      "custom-tier": {
        "rates": [{"limit": 500000, "window": "1h"}],
        "when": [
          {"predicate": "request.path.matches(\"/.*/v1/chat/completions\")"},
          {"predicate": "auth.identity.groups.exists(g, g == \"custom-tier-users\")"}
        ],
        "counters": [{"expression": "auth.identity.uid"}]
      }
    }
  }
}'
```

---

## Related Documentation

- [RHOAI 3.3 Installation Guide](./RHOAI-33-INSTALLATION.md)
- [MaaS Serving Runtimes](./MAAS-SERVING-RUNTIMES.md)
- [Troubleshooting Guide](../TROUBLESHOOTING.md)
- [Main README](../../README.md)
