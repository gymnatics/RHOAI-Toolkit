# ✅ llm-d Setup Complete!

## Summary

Your OpenShift cluster is now fully configured for **llm-d** (LLM Distributed) serving runtime per the CAI guide Section 3.

---

## ✅ What Was Configured

### 1. GatewayClass 'openshift-ai-inference'
- **Status**: ✅ Created
- **Purpose**: Defines the gateway controller for inference traffic
- **Controller**: `openshift.io/gateway-controller/v1`

### 2. Gateway 'openshift-ai-inference'
- **Status**: ✅ Created
- **Namespace**: `openshift-ingress`
- **Hostname**: `inference-gateway.apps.apps.openshift-cluster.example.opentlc.com`
- **Allowed Namespaces**: All (configurable for security)
- **Purpose**: Routes inference requests to llm-d models

### 3. LeaderWorkerSetOperator Instance
- **Status**: ✅ Created
- **Name**: `cluster`
- **Namespace**: `openshift-lws-operator`
- **Management State**: Managed
- **Purpose**: Enables multi-replica model deployments

### 4. Prerequisites (Already Configured)
- ✅ LWS Operator installed
- ✅ Kuadrant instance exists
- ✅ Authorino configured with TLS
- ✅ RHCL Operator installed

---

## 🚀 What You Can Do Now

### 1. Deploy Models Using llm-d

#### Via UI:
1. Open RHOAI dashboard: https://$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}')
2. Navigate to your project (e.g., `0-demo`)
3. Click "Deploy model"
4. Select **llm-d** as the serving runtime
5. Configure your model:
   - Model name: `qwen3-4b`
   - Model URI: `oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest`
   - Resources: 1 GPU, 4 CPU, 16Gi memory
6. **Check "Require authentication"** checkbox
7. Click "Deploy"

#### Via YAML:
```bash
./scripts/deploy-qwen3-4b-with-tools.sh 0-demo
```

This deploys a Qwen3-4B model with tool calling enabled using llm-d.

---

### 2. Enable Multi-Replica Deployments

llm-d supports multi-replica deployments via Leader Worker Set:

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-4b-multi
spec:
  replicas: 3  # <-- Multiple replicas!
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
      resources:
        limits:
          nvidia.com/gpu: "1"
```

---

### 3. Use Tool Calling

llm-d uses `VLLM_ADDITIONAL_ARGS` for tool calling:

```yaml
env:
  - name: VLLM_ADDITIONAL_ARGS
    value: "--enable-auto-tool-choice --tool-call-parser=hermes"
```

**Important**: Deploy via YAML, not UI (UI doesn't handle env vars correctly).

---

### 4. Generate API Tokens

For authenticated access:

```bash
# Generate 24-hour token
./demo/generate-maas-token.sh

# Or manually
oc create token <service-account> -n <namespace> --duration=24h
```

---

### 5. Test Your Model

```bash
# Get model endpoint
MODEL_URL=$(oc get llmisvc qwen3-4b -n 0-demo -o jsonpath='{.status.addresses[0].url}')

# Get token
TOKEN=$(oc create token default -n 0-demo --duration=1h)

# Test inference
curl "$MODEL_URL/v1/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
        "model": "qwen3-4b",
        "prompt": "What is the capital of France?"
    }'
```

---

## 📚 Documentation

### Guides
- **[LLMD-SETUP-GUIDE.md](docs/guides/LLMD-SETUP-GUIDE.md)**: Complete llm-d setup guide
- **[SERVING-RUNTIME-COMPARISON.md](docs/reference/SERVING-RUNTIME-COMPARISON.md)**: llm-d vs vLLM comparison
- **[TOOL-CALLING-GUIDE.md](docs/guides/TOOL-CALLING-GUIDE.md)**: How to enable tool calling
- **[MAAS-SERVING-RUNTIMES.md](docs/guides/MAAS-SERVING-RUNTIMES.md)**: MaaS compatibility

### Scripts
- **`./scripts/setup-llmd.sh`**: Standalone llm-d setup script
- **`./scripts/deploy-qwen3-4b-with-tools.sh`**: Deploy Qwen3-4B with tool calling
- **`./demo/generate-maas-token.sh`**: Generate API tokens
- **`./demo/test-maas-api.sh`**: Test model API

---

## 🔍 Verification

Run the verification script anytime:

```bash
/tmp/check-llmd-setup.sh
```

Or check manually:

```bash
# Check GatewayClass
oc get gatewayclass openshift-ai-inference

# Check Gateway
oc get gateway openshift-ai-inference -n openshift-ingress

# Check LWS Instance
oc get leaderworkersetoperator cluster -n openshift-lws-operator

# Check all prerequisites
oc get kuadrant kuadrant -n kuadrant-system
oc get authorino authorino -n kuadrant-system
```

---

## 🆚 llm-d vs vLLM

| Feature | llm-d | vLLM |
|---------|-------|------|
| **API Type** | `LLMInferenceService` | `InferenceService` |
| **Multi-replica** | ✅ Yes (via LWS) | ❌ No |
| **Authentication** | ✅ Yes (via Authorino) | ⚠️ Limited |
| **MaaS Support** | ✅ Yes | ❌ No |
| **Gateway Routing** | ✅ Yes | ❌ No |
| **vLLM Args** | `VLLM_ADDITIONAL_ARGS` env var | `args` array |
| **Best For** | Production, MaaS, multi-replica | GenAI Playground, simple deployments |

**Your use case**: llm-d is the correct choice because you're using it for tool calling and production deployments.

---

## 🎯 Key Differences from Your Previous Setup

### Before (Missing Components):
- ❌ No GatewayClass 'openshift-ai-inference'
- ❌ No Gateway 'openshift-ai-inference'
- ❌ No LeaderWorkerSetOperator instance

### After (Complete Setup):
- ✅ GatewayClass created
- ✅ Gateway created with inference routing
- ✅ LeaderWorkerSetOperator instance created
- ✅ All prerequisites verified

### What This Enables:
- ✅ Deploy models using llm-d serving runtime
- ✅ Multi-replica deployments
- ✅ Gateway-based routing
- ✅ Authentication via Authorino
- ✅ Tool calling support
- ✅ MaaS integration

---

## 🔐 Security Notes

### Gateway Namespace Access
Currently configured to allow **all namespaces**. For production, consider restricting:

```yaml
allowedRoutes:
  namespaces:
    from: Selector
    selector:
      matchExpressions:
        - key: kubernetes.io/metadata.name
          operator: In
          values:
            - 0-demo
            - user1
            - user2
```

### Authentication
Always enable authentication for production models:
- Check "Require authentication" in UI
- Or add annotation: `security.opendatahub.io/enable-auth=true`

---

## 🛠️ Troubleshooting

### Gateway Not Working
```bash
# Check gateway status
oc get gateway openshift-ai-inference -n openshift-ingress -o yaml

# Check Service Mesh
oc get pods -n openshift-ingress
```

### LWS Not Ready
```bash
# Check operator status
oc get leaderworkersetoperator cluster -n openshift-lws-operator -o yaml

# Check operator logs
oc logs -n openshift-lws-operator -l app=leader-worker-set-operator
```

### Authentication Failing
```bash
# Check Authorino
oc get pods -n kuadrant-system | grep authorino

# Check Authorino TLS
oc get authorino authorino -n kuadrant-system -o yaml | grep -A5 "listener:"
```

---

## 📖 References

- **CAI Guide**: Section 3 (llm-d)
- **Your Scripts**: All updated to include llm-d setup
  - `integrated-workflow-v2.sh`
  - `scripts/integrated-workflow.sh`
  - `lib/functions/rhoai.sh`

---

## ✨ Next Steps

1. **Deploy your first llm-d model**:
   ```bash
   ./scripts/deploy-qwen3-4b-with-tools.sh 0-demo
   ```

2. **Generate an API token**:
   ```bash
   ./demo/generate-maas-token.sh
   ```

3. **Test the model**:
   ```bash
   ./demo/test-maas-api.sh
   ```

4. **Explore multi-replica deployments** (see LLMD-SETUP-GUIDE.md)

5. **Review security settings** (restrict Gateway namespaces if needed)

---

**🎉 Congratulations! Your cluster is now fully configured for llm-d serving runtime!**

For questions or issues, refer to:
- `docs/guides/LLMD-SETUP-GUIDE.md`
- `docs/TROUBLESHOOTING.md`
- CAI's guide to RHOAI 3.0, Section 3

