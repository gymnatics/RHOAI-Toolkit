# Interactive Model Deployment Guide

## Overview

The **Interactive Model Deployment** feature provides a user-friendly way to deploy models using the llm-d serving runtime in RHOAI 3.0. It guides you through all configuration options with sensible defaults.

---

## Quick Start

### Standalone Script

```bash
./scripts/deploy-llmd-model.sh
```

### During Workflow Installation

When running `./rhoai-toolkit.sh` or `./integrated-workflow-v2.sh`, you'll be prompted to deploy a model after RHOAI installation is complete.

---

## Features

### 1. **Pre-defined Model Catalog**

Choose from a curated list of models:

| Model | Size | Features | Resource Requirements |
|-------|------|----------|----------------------|
| **Qwen3-4B (FP8)** | 4B params | Tool calling | 1 GPU, 4 CPU, 16Gi |
| **Qwen3-8B (FP8)** | 8B params | Tool calling | 1 GPU, 8 CPU, 32Gi |
| **Llama 3.2-3B Instruct** | 3B params | Instruct-tuned | 1 GPU, 4 CPU, 16Gi |
| **Granite 3.0-8B Instruct** | 8B params | Instruct-tuned | 1 GPU, 8 CPU, 32Gi |
| **Custom** | - | User-defined | User-defined |

### 2. **Custom Model Support**

Enter any OCI-compliant model URI:
- From Red Hat registry: `oci://registry.redhat.io/rhelai1/modelcar-*:latest`
- From Quay.io: `oci://quay.io/redhat-ai-services/modelcar-catalog:*`
- From custom registries: `oci://your-registry.com/model:tag`

### 3. **Interactive Namespace Selection**

- **List existing namespaces** (filters out system namespaces)
- **Select by number or name**
- **Create new namespace** if needed

### 4. **Resource Configuration**

Configure resources with defaults based on model size:
- **GPU limit**: Number of GPUs (default: 1)
- **CPU limit**: CPU cores (default: 4-8)
- **Memory limit**: RAM allocation (default: 16-32Gi)

### 5. **Tool Calling Configuration**

For supported models (Qwen3), enable tool calling with:
- `--enable-auto-tool-choice`
- `--tool-call-parser=hermes`

### 6. **Authentication Setup**

Choose to require authentication:
- **Enabled** (default): Requires Kubernetes service account token
- **Disabled**: Model is publicly accessible (not recommended for production)

---

## Usage Examples

### Example 1: Deploy Qwen3-4B with Tool Calling

```bash
$ ./scripts/deploy-llmd-model.sh

═══════════════════════════════════════════════════════════
║ Interactive Model Deployment with llm-d
═══════════════════════════════════════════════════════════

✓ Logged in to OpenShift: https://api.openshift-cluster.example.opentlc.com:6443
✓ RHOAI is installed
✓ All llm-d prerequisites are configured

═══════════════════════════════════════════════════════════
║ Model Selection
═══════════════════════════════════════════════════════════

Available models:

  1) Qwen3-4B (FP8) - 4B params, tool calling support
     oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest

  2) Qwen3-8B (FP8) - 8B params, tool calling support
     oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:latest

  3) Llama 3.2-3B Instruct
     oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct

  4) Granite 3.0-8B Instruct
     oci://quay.io/redhat-ai-services/modelcar-catalog:granite-3.0-8b-instruct

  5) Custom model URI (enter your own)

Select a model (1-5): 1

✓ Selected model: qwen3-4b
ℹ URI: oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest

═══════════════════════════════════════════════════════════
║ Namespace Selection
═══════════════════════════════════════════════════════════

Available namespaces:

 1) 0-demo
 2) user-test

  0) Create new namespace

Select namespace (enter number or name): 1

✓ Target namespace: 0-demo

═══════════════════════════════════════════════════════════
║ Resource Configuration
═══════════════════════════════════════════════════════════

Configure resources for the model:

  GPU limit: 1
  CPU limit: 4
  Memory limit: 16Gi

Use default resources? (Y/n): Y

✓ Resources configured:
  GPU: 1
  CPU: 4
  Memory: 16Gi

═══════════════════════════════════════════════════════════
║ Tool Calling Configuration
═══════════════════════════════════════════════════════════

This model supports tool calling (function calling).

Enable tool calling? (Y/n): Y

✓ Tool calling enabled

═══════════════════════════════════════════════════════════
║ Authentication Configuration
═══════════════════════════════════════════════════════════

Require authentication for this model?
(Recommended: Yes for production)

Require authentication? (Y/n): Y

✓ Authentication enabled

═══════════════════════════════════════════════════════════
║ Deployment Summary
═══════════════════════════════════════════════════════════

Model: qwen3-4b
URI: oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest
Namespace: 0-demo
Resources: 1 GPU, 4 CPU, 16Gi Memory
Tool Calling: Enabled (hermes parser)
Authentication: Required

Proceed with deployment? (Y/n): Y

═══════════════════════════════════════════════════════════
║ Deploying Model
═══════════════════════════════════════════════════════════

▶ Creating LLMInferenceService 'qwen3-4b' in namespace '0-demo'...
llminferenceservice.serving.kserve.io/qwen3-4b created

✓ Model deployment created!

ℹ Deployment initiated. The model will take 5-10 minutes to be ready.

ℹ Monitor deployment status:
  oc get llmisvc qwen3-4b -n 0-demo -w

ℹ View pods:
  oc get pods -n 0-demo -l serving.kserve.io/inferenceservice=qwen3-4b

ℹ Generate API token:
  oc create token default -n 0-demo --duration=24h

ℹ Or use the demo script:
  ./demo/generate-maas-token.sh

ℹ Test the model (after it's ready):
  ./demo/test-maas-api.sh

═══════════════════════════════════════════════════════════
║ Deployment Complete!
═══════════════════════════════════════════════════════════

✓ Your model deployment has been initiated.

ℹ Next steps:
  1. Wait 5-10 minutes for the model to be ready
  2. Check status: oc get llmisvc -n 0-demo
  3. Generate token: ./demo/generate-maas-token.sh
  4. Test model: ./demo/test-maas-api.sh
```

### Example 2: Deploy Custom Model

```bash
Select a model (1-5): 5

ℹ Enter custom model URI (e.g., oci://registry.example.com/model:tag):
Model URI: oci://quay.io/my-org/custom-llm:v1.0

ℹ Enter model name (alphanumeric, lowercase, hyphens only):
Model name: my-custom-llm

✓ Selected model: my-custom-llm
ℹ URI: oci://quay.io/my-org/custom-llm:v1.0

[... rest of prompts ...]
```

### Example 3: Create New Namespace

```bash
Select namespace (enter number or name): 0

ℹ Enter new namespace name (alphanumeric, lowercase, hyphens only):
Namespace: ai-models

▶ Creating namespace 'ai-models'...
✓ Namespace created
✓ Target namespace: ai-models
```

---

## Integration with Workflows

### Automatic During Installation

When running the integrated workflow scripts for RHOAI 3.0, you'll be automatically prompted after RHOAI installation:

```bash
./rhoai-toolkit.sh
# or
./integrated-workflow-v2.sh
```

After RHOAI setup completes:

```
═══════════════════════════════════════════════════════════
║ Interactive Model Deployment with llm-d
═══════════════════════════════════════════════════════════

Would you like to deploy a model now?

Deploy a model? (y/N): y
```

**Skip deployment**:
```
Deploy a model? (y/N): n

ℹ Skipping model deployment. You can deploy later using:
  ./scripts/deploy-llmd-model.sh
```

---

## Configuration Details

### Generated YAML

The script generates an `LLMInferenceService` with the following structure:

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: <model-name>
  namespace: <target-namespace>
  labels:
    kueue.x-k8s.io/queue-name: default
    opendatahub.io/dashboard: "true"
    opendatahub.io/genai-asset: "true"
  annotations:
    security.opendatahub.io/enable-auth: "true"  # or "false"
spec:
  replicas: 1
  model:
    uri: <model-uri>
    name: <model-name>
  router:
    route: {}
    gateway: {}
    scheduler: {}
  template:
    containers:
    - name: main
      env:  # Only if tool calling is enabled
        - name: VLLM_ADDITIONAL_ARGS
          value: "--enable-auto-tool-choice --tool-call-parser=hermes"
      resources:
        limits:
          cpu: '<cpu-limit>'
          memory: <memory-limit>
          nvidia.com/gpu: "<gpu-limit>"
        requests:
          cpu: '<cpu-limit/2>'  # Auto-calculated
          memory: <memory-limit/2>  # Auto-calculated
          nvidia.com/gpu: "<gpu-limit>"
```

### Resource Requests

The script automatically calculates resource requests as **50% of limits** for CPU and memory, which is a best practice for Kubernetes resource management.

---

## Monitoring Deployment

### Check Status

```bash
# Watch deployment status
oc get llmisvc <model-name> -n <namespace> -w

# Check pods
oc get pods -n <namespace> -l serving.kserve.io/inferenceservice=<model-name>

# View logs
oc logs -n <namespace> -l serving.kserve.io/inferenceservice=<model-name> -c kserve-container -f
```

### Expected Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| Image Pull | 2-3 min | `ContainerCreating` |
| Model Loading | 2-5 min | `Running`, logs show loading |
| Ready | - | Logs show "Application startup complete." |

---

## Testing the Deployment

### Generate API Token

```bash
# Method 1: Quick token
oc create token default -n <namespace> --duration=24h

# Method 2: Demo script
./demo/generate-maas-token.sh
```

### Test Inference

```bash
# Get model endpoint
MODEL_URL=$(oc get llmisvc <model-name> -n <namespace> -o jsonpath='{.status.addresses[0].url}')

# Get token
TOKEN=$(oc create token default -n <namespace> --duration=1h)

# Test
curl "$MODEL_URL/v1/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
        "model": "<model-name>",
        "prompt": "What is the capital of France?",
        "max_tokens": 50
    }'
```

### Test Tool Calling (if enabled)

```bash
curl "$MODEL_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
        "model": "<model-name>",
        "messages": [
            {"role": "user", "content": "What is the weather in Paris?"}
        ],
        "tools": [
            {
                "type": "function",
                "function": {
                    "name": "get_weather",
                    "description": "Get current weather",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "location": {"type": "string"}
                        },
                        "required": ["location"]
                    }
                }
            }
        ]
    }'
```

---

## Troubleshooting

### Model Stuck in Pending

**Check GPU availability**:
```bash
oc get nodes -l nvidia.com/gpu.present=true
```

**Check resource quotas**:
```bash
oc describe resourcequota -n <namespace>
```

### Image Pull Errors

**Check image URI**:
```bash
oc describe llmisvc <model-name> -n <namespace>
```

**Verify registry access** (for custom registries):
```bash
oc create secret docker-registry my-registry-secret \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n <namespace>
```

### Authentication Failures

**Check service account**:
```bash
oc get sa -n <namespace>
```

**Check RBAC**:
```bash
oc get role,rolebinding -n <namespace>
```

**Check token**:
```bash
# Decode token to check claims
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq .
```

---

## Best Practices

### 1. **Use Authentication**
Always enable authentication for production deployments to prevent unauthorized access.

### 2. **Right-Size Resources**
Start with default resources and adjust based on:
- Model size and quantization
- Expected load
- Response time requirements

### 3. **Namespace Organization**
Create dedicated namespaces for different:
- Teams or projects
- Environments (dev, staging, prod)
- Use cases

### 4. **Model Versioning**
Include version tags in custom model URIs:
```
oci://registry.example.com/model:v1.2.3
```

### 5. **Monitor Resource Usage**
```bash
# Check resource usage
oc adm top pods -n <namespace>
oc adm top nodes
```

---

## Related Documentation

- **[LLMD-SETUP-GUIDE.md](LLMD-SETUP-GUIDE.md)**: Complete llm-d setup guide
- **[SERVING-RUNTIME-COMPARISON.md](../reference/SERVING-RUNTIME-COMPARISON.md)**: llm-d vs vLLM comparison
- **[TOOL-CALLING-GUIDE.md](TOOL-CALLING-GUIDE.md)**: Tool calling configuration
- **[MAAS-SERVING-RUNTIMES.md](MAAS-SERVING-RUNTIMES.md)**: MaaS compatibility and security

---

**Last Updated**: November 2025  
**RHOAI Version**: 3.0  
**Serving Runtime**: llm-d

