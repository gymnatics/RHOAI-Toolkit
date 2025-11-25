# Serving Runtime Comparison: llm-d vs vLLM

## Overview

RHOAI 3.0 offers two main serving runtimes for deploying models. The runtime you choose determines **how you configure vLLM arguments**.

## Quick Comparison

| Feature | llm-d | vLLM |
|---------|-------|------|
| **API Type** | `LLMInferenceService` | `InferenceService` |
| **vLLM Args** | `VLLM_ADDITIONAL_ARGS` env var | `args` array |
| **MaaS Support** | ✅ Yes | ❌ No |
| **Multi-replica** | ✅ Yes (via LWS) | ⚠️ Limited |
| **UI Deployment** | ✅ Yes | ✅ Yes |
| **Kueue Integration** | ✅ Yes | ⚠️ Limited |
| **Best For** | Production, MaaS, multi-replica | GenAI Playground, simple deployments |

## Detailed Comparison

### llm-d (LLMInferenceService)

**API Version**: `serving.kserve.io/v1alpha1`

**How to Configure vLLM Arguments**:
```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-4b
spec:
  template:
    containers:
    - name: main
      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: "--enable-auto-tool-choice --tool-call-parser=hermes"
```

**Key Characteristics**:
- Uses **environment variable** `VLLM_ADDITIONAL_ARGS`
- Supports **Leader Worker Set** (LWS) for multi-replica
- **Required** for MaaS (Model as a Service)
- Integrates with Kueue for resource management
- More complex but more powerful

**From CAI Guide** (Section 3 - llm-d):
> "Simply deploy models using llm-d as the 'serving runtime', and check the 'Require authentication' checkbox."

**Example from CAI Guide**:
```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-sample
  namespace: llama-serving
spec:
  replicas: 1
  model:
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:latest
    name: RedHatAI/Qwen3-8B-FP8-dynamic
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
          nvidia.com/gpu: "1"
```

---

### vLLM (InferenceService)

**API Version**: `serving.kserve.io/v1beta1`

**How to Configure vLLM Arguments**:
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llama-32-3b-instruct
spec:
  predictor:
    model:
      args:
        - '--dtype=half'
        - '--max-model-len=20000'
        - '--enable-auto-tool-choice'
        - '--tool-call-parser=llama3_json'
      modelFormat:
        name: vLLM
```

**Key Characteristics**:
- Uses **args array** directly
- Simpler configuration
- Used for **GenAI Playground**
- Does **NOT** support MaaS through UI
- Single replica (typically)
- RawDeployment mode

**From CAI Guide** (Section 2 - Model Deployment):
> "Deploying a model from the Catalog with vLLM"

**Example from CAI Guide**:
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llama-32-3b-instruct
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
spec:
  predictor:
    model:
      args:
        - '--dtype=half'
        - '--max-model-len=20000'
        - '--gpu-memory-utilization=0.95'
        - '--enable-auto-tool-choice'
        - '--tool-call-parser=llama3_json'
        - '--chat-template=/opt/app-root/template/tool_chat_template_llama3.2_json.jinja'
      modelFormat:
        name: vLLM
      runtime: llama-32-3b-instruct
      storageUri: 'oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct'
```

---

## Why Your Error Happened

### You Used: llm-d

When you selected **llm-d** as your serving runtime, you created a `LLMInferenceService`.

For `LLMInferenceService`, vLLM arguments **must** be configured via:
```yaml
env:
  - name: VLLM_ADDITIONAL_ARGS
    value: "--enable-auto-tool-choice --tool-call-parser=hermes"
```

### The Problem

The **RHOAI UI** doesn't properly handle `VLLM_ADDITIONAL_ARGS` when you add it as an environment variable:

1. **With `--`**: Bash interprets as bash options → Error: `/bin/bash: --: invalid option`
2. **Without `--`**: Bash tries to execute as commands → Error: `command not found`

### The Solution

**Deploy via YAML** (not UI), exactly as the CAI guide shows:

```bash
./scripts/deploy-qwen3-4b-with-tools.sh <namespace>
```

This uses the same approach as the CAI guide: YAML deployment with `VLLM_ADDITIONAL_ARGS`.

---

## When to Use Each Runtime

### Use llm-d When:
- ✅ You need MaaS (Model as a Service)
- ✅ You need multi-replica deployments
- ✅ You need Kueue resource management
- ✅ You need authentication/authorization
- ✅ Production deployments

### Use vLLM When:
- ✅ Deploying for GenAI Playground
- ✅ Simple, single-replica deployments
- ✅ You don't need MaaS
- ✅ Development/testing
- ✅ You want simpler configuration

---

## Configuration Comparison

### Tool Calling with llm-d

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: my-model
spec:
  template:
    containers:
    - name: main
      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: "--enable-auto-tool-choice --tool-call-parser=hermes"
```

**Deployment**: Must use YAML (UI doesn't work)

### Tool Calling with vLLM

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: my-model
spec:
  predictor:
    model:
      args:
        - '--enable-auto-tool-choice'
        - '--tool-call-parser=hermes'
      modelFormat:
        name: vLLM
```

**Deployment**: Can use YAML or potentially UI (args are more reliable)

---

## Key Takeaways

1. **llm-d** uses `VLLM_ADDITIONAL_ARGS` environment variable
2. **vLLM** uses `args` array
3. **UI doesn't work** for llm-d with `VLLM_ADDITIONAL_ARGS`
4. **Always use YAML** for models with tool calling
5. **llm-d is required** for MaaS
6. **vLLM is used** for GenAI Playground

---

## Your Specific Case

You chose: **llm-d** (correct for MaaS and production)

You tried: **Adding `VLLM_ADDITIONAL_ARGS` via UI** (doesn't work)

You should: **Deploy via YAML** using the script:
```bash
./scripts/deploy-qwen3-4b-with-tools.sh <namespace>
```

This will create a `LLMInferenceService` with `VLLM_ADDITIONAL_ARGS` properly configured, exactly as the CAI guide shows.

---

## References

- CAI's guide to RHOAI 3.0:
  - Section 2: vLLM deployment with args
  - Section 3: llm-d deployment with VLLM_ADDITIONAL_ARGS
- [MAAS-SERVING-RUNTIMES.md](../guides/MAAS-SERVING-RUNTIMES.md) - MaaS compatibility
- [KSERVE-DEPLOYMENT-MODES.md](KSERVE-DEPLOYMENT-MODES.md) - RawDeployment vs Serverless

---

**Last Updated**: November 2025  
**RHOAI Version**: 3.0  
**Source**: CAI's guide to RHOAI 3.0, Sections 2 & 3

