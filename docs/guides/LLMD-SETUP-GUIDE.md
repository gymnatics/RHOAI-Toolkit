# llm-d Setup Guide (per CAI Guide Section 3)

## Overview

**llm-d** (LLM Distributed) is a serving runtime in RHOAI 3.0 that enables:
- Multi-replica model deployments using Leader Worker Set (LWS)
- Authentication and authorization via Kuadrant/Authorino
- Gateway-based routing for distributed inference
- Model as a Service (MaaS) integration

This guide covers the setup requirements from the CAI guide Section 3.

---

## Prerequisites

Before setting up llm-d, ensure you have:

1. ✅ OpenShift cluster running
2. ✅ RHOAI 3.0 installed
3. ✅ Leader Worker Set (LWS) Operator installed
4. ✅ Red Hat Connectivity Link (RHCL) Operator installed (provides Kuadrant)
5. ✅ Kuadrant instance created in `kuadrant-system` namespace
6. ✅ Authorino configured with TLS

---

## Required Components (per CAI Guide)

### 1. GatewayClass

**Purpose**: Defines the gateway controller for inference traffic

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
```

**Command**:
```bash
oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
```

---

### 2. Gateway

**Purpose**: Routes inference requests to llm-d models

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/rev: openshift-gateway
  name: openshift-ai-inference
  namespace: openshift-ingress
spec:
  gatewayClassName: openshift-ai-inference
  listeners:
    - allowedRoutes:
        namespaces:
          from: All  # Or use Selector for specific namespaces
      hostname: inference-gateway.apps.<cluster-domain>
      name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - group: ''
            kind: Secret
            name: default-gateway-tls
        mode: Terminate
```

**Important Notes**:
- Replace `<cluster-domain>` with your actual cluster domain
- `allowedRoutes.namespaces.from: All` allows all namespaces (security risk)
- For production, use `Selector` to specify allowed namespaces

**Command**:
```bash
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')

oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/rev: openshift-gateway
  name: openshift-ai-inference
  namespace: openshift-ingress
spec:
  gatewayClassName: openshift-ai-inference
  listeners:
    - allowedRoutes:
        namespaces:
          from: All
      hostname: inference-gateway.apps.$CLUSTER_DOMAIN
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

---

### 3. LeaderWorkerSetOperator Instance

**Purpose**: Enables multi-replica deployments for llm-d

```yaml
apiVersion: operator.openshift.io/v1
kind: LeaderWorkerSetOperator
metadata:
  name: cluster
  namespace: openshift-lws-operator
spec:
  managementState: Managed
  logLevel: Normal
  operatorLogLevel: Normal
```

**Command**:
```bash
oc apply -f - <<EOF
apiVersion: operator.openshift.io/v1
kind: LeaderWorkerSetOperator
metadata:
  name: cluster
  namespace: openshift-lws-operator
spec:
  managementState: Managed
  logLevel: Normal
  operatorLogLevel: Normal
EOF
```

---

## Automated Setup

### Option 1: Run the Standalone Script

```bash
./scripts/setup-llmd.sh
```

This script will:
1. Create GatewayClass 'openshift-ai-inference'
2. Create Gateway 'openshift-ai-inference' in openshift-ingress
3. Create LeaderWorkerSetOperator instance
4. Verify all prerequisites

### Option 2: Run the Integrated Workflow

The llm-d setup is automatically included when you run:

```bash
./rhoai-toolkit.sh
```

Or:

```bash
./integrated-workflow-v2.sh
```

For RHOAI 3.0, the `setup_llmd_infrastructure` function is called automatically.

---

## Verification

### Check All Prerequisites

Run the verification script:

```bash
/tmp/check-llmd-setup.sh
```

Or manually check each component:

```bash
# 1. Check GatewayClass
oc get gatewayclass openshift-ai-inference

# 2. Check Gateway
oc get gateway openshift-ai-inference -n openshift-ingress

# 3. Check LWS Operator
oc get csv -n openshift-lws-operator | grep leader-worker-set

# 4. Check LWS Instance
oc get leaderworkersetoperator cluster -n openshift-lws-operator

# 5. Check Kuadrant
oc get kuadrant kuadrant -n kuadrant-system

# 6. Check Authorino
oc get authorino authorino -n kuadrant-system
```

---

## Deploying Models with llm-d

### Via UI

1. Open the RHOAI dashboard
2. Navigate to your project
3. Click "Deploy model"
4. Select **llm-d** as the serving runtime
5. Configure your model:
   - Model name
   - Model URI (e.g., `oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest`)
   - Resources (CPU, memory, GPU)
6. **Check "Require authentication"** checkbox for secure access
7. Click "Deploy"

### Via YAML

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-4b
  namespace: your-namespace
spec:
  replicas: 1
  model:
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest
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
```

**Deploy**:
```bash
oc apply -f llm-inference-service.yaml
```

---

## Authentication

### Enable Authentication (Default)

By default, llm-d models deployed via UI with "Require authentication" checked will require a valid Kubernetes service account token.

### Disable Authentication (Optional)

To allow anonymous access:

```bash
oc annotate llmisvc/<model-name> security.opendatahub.io/enable-auth=false -n <namespace>
```

### Generate API Token

Use the demo script:

```bash
./demo/generate-maas-token.sh
```

Or manually:

```bash
# Create service account
oc create sa model-user -n your-namespace

# Create Role and RoleBinding
oc apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: llm-inferenceservice-reader
  namespace: your-namespace
rules:
  - apiGroups: ["serving.kserve.io"]
    resources: ["llminferenceservices"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: llm-inferenceservice-reader-binding
  namespace: your-namespace
subjects:
  - kind: ServiceAccount
    name: model-user
    namespace: your-namespace
roleRef:
  kind: Role
  name: llm-inferenceservice-reader
  apiGroup: rbac.authorization.k8s.io
EOF

# Generate token
oc create token model-user -n your-namespace --duration=24h
```

---

## Testing

### Test with Token

```bash
# Get model endpoint
MODEL_URL=$(oc get llmisvc <model-name> -n <namespace> -o jsonpath='{.status.addresses[0].url}')

# Get token
TOKEN=$(oc create token model-user -n <namespace> --duration=1h)

# Test inference
curl -v "$MODEL_URL/v1/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
        "model": "<model-name>",
        "prompt": "What is the capital of France?"
    }'
```

### Test Without Token (Should Fail)

```bash
curl -v "$MODEL_URL/v1/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "<model-name>",
        "prompt": "What is the capital of France?"
    }'
```

Expected: `HTTP/1.1 401 Unauthorized`

---

## Troubleshooting

### Gateway Not Programmed

**Symptom**: Gateway status shows `Programmed: False`

**Solution**:
```bash
# Check gateway status
oc get gateway openshift-ai-inference -n openshift-ingress -o yaml

# Check Service Mesh
oc get pods -n openshift-ingress
```

### LWS Operator Not Ready

**Symptom**: LeaderWorkerSetOperator instance shows `Available: False`

**Solution**:
```bash
# Check operator status
oc get leaderworkersetoperator cluster -n openshift-lws-operator -o yaml

# Check operator logs
oc logs -n openshift-lws-operator -l app=leader-worker-set-operator
```

### Authentication Failing

**Symptom**: `401 Unauthorized` even with valid token

**Solution**:
```bash
# Check Authorino is running
oc get pods -n kuadrant-system | grep authorino

# Check Authorino TLS configuration
oc get authorino authorino -n kuadrant-system -o yaml | grep -A5 "listener:"

# Check AuthPolicy
oc get authpolicy -n <namespace>
```

---

## Comparison: llm-d vs vLLM

| Feature | llm-d | vLLM |
|---------|-------|------|
| **API Type** | `LLMInferenceService` | `InferenceService` |
| **Multi-replica** | ✅ Yes (via LWS) | ❌ No |
| **Authentication** | ✅ Yes (via Authorino) | ⚠️ Limited |
| **MaaS Support** | ✅ Yes | ❌ No |
| **Gateway Routing** | ✅ Yes | ❌ No |
| **vLLM Args** | `VLLM_ADDITIONAL_ARGS` env var | `args` array |
| **Best For** | Production, MaaS, multi-replica | GenAI Playground, simple deployments |

---

## References

- **CAI Guide Section 3**: llm-d setup and usage
- **[SERVING-RUNTIME-COMPARISON.md](../reference/SERVING-RUNTIME-COMPARISON.md)**: Detailed comparison of llm-d vs vLLM
- **[TOOL-CALLING-GUIDE.md](TOOL-CALLING-GUIDE.md)**: How to enable tool calling with llm-d
- **[MAAS-SERVING-RUNTIMES.md](MAAS-SERVING-RUNTIMES.md)**: MaaS compatibility and security

---

**Last Updated**: November 2025  
**RHOAI Version**: 3.0  
**Source**: CAI's guide to RHOAI 3.0, Section 3

