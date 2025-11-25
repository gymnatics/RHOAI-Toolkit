# Tool Calling Configuration for Models in RHOAI 3.0

## Overview

To enable tool calling (function calling) for models in RHOAI 3.0, you need to add specific runtime arguments via the `VLLM_ADDITIONAL_ARGS` environment variable.

## Quick Answer for Qwen3-4B

For **Qwen3-4B** (or any Qwen model), use the **`hermes`** tool call parser:

```yaml
env:
  - name: VLLM_ADDITIONAL_ARGS
    value: "--enable-auto-tool-choice --tool-call-parser=hermes"
```

## Tool Call Parsers by Model

Different models require different tool call parsers:

| Model Family | Tool Call Parser | Example |
|--------------|------------------|---------|
| **Qwen** (Qwen3, Qwen2.5) | `hermes` | `--tool-call-parser=hermes` |
| **Llama 3.2** | `llama3_json` | `--tool-call-parser=llama3_json` |
| **Mistral** | `mistral` | `--tool-call-parser=mistral` |
| **Hermes** | `hermes` | `--tool-call-parser=hermes` |

## Configuration Methods

### Method 1: Through UI (llm-d)

When deploying via the RHOAI Dashboard with `llm-d`:

1. Deploy model → Advanced settings
2. Add environment variable:
   - **Name**: `VLLM_ADDITIONAL_ARGS`
   - **Value**: `--enable-auto-tool-choice --tool-call-parser=hermes`

### Method 2: Through YAML (LLMInferenceService)

For `llm-d` deployments via YAML:

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-4b-tools
  namespace: your-namespace
spec:
  replicas: 1
  model:
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest
    name: RedHatAI/Qwen3-4B-FP8-dynamic
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
```

### Method 3: Through YAML (InferenceService with vLLM)

For direct `vLLM` deployments:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: qwen3-4b-tools
  namespace: your-namespace
spec:
  predictor:
    model:
      args:
        - '--dtype=half'
        - '--max-model-len=8000'
        - '--gpu-memory-utilization=0.95'
        - '--enable-auto-tool-choice'
        - '--tool-call-parser=hermes'
      modelFormat:
        name: vLLM
      name: ''
      resources:
        limits:
          cpu: '4'
          memory: 16Gi
          nvidia.com/gpu: "1"
        requests:
          cpu: '2'
          memory: 8Gi
      runtime: vllm-runtime
      storage:
        key: aws-connection-models
        path: qwen3-4b/
```

## Complete Example: Qwen3-8B with Tool Calling

From the CAI guide, here's a complete working example:

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-sample
  namespace: llama-serving
  labels:
    kueue.x-k8s.io/queue-name: default
    opendatahub.io/dashboard: "true"
    opendatahub.io/genai-asset: "true"
  annotations:
    security.opendatahub.io/enable-auth: "false"
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
          cpu: '1'
          memory: 8Gi
          nvidia.com/gpu: "1"
        requests:
          cpu: '1'
          memory: 8Gi
          nvidia.com/gpu: "1"
```

## Tool Calling Arguments Explained

### `--enable-auto-tool-choice`

- **Purpose**: Automatically enables tool/function calling capability
- **Required**: Yes, for tool calling to work
- **Effect**: Allows the model to decide when to call tools vs. respond directly

### `--tool-call-parser=<parser>`

- **Purpose**: Specifies which parser to use for extracting tool calls from model output
- **Required**: Yes, must match your model's format
- **Options**:
  - `hermes` - For Qwen, Hermes models
  - `llama3_json` - For Llama 3.x models
  - `mistral` - For Mistral models
  - `granite` - For IBM Granite models

### Optional: `--chat-template`

For custom chat templates (advanced):

```yaml
args:
  - '--enable-auto-tool-choice'
  - '--tool-call-parser=llama3_json'
  - '--chat-template=/opt/app-root/template/tool_chat_template_llama3.2_json.jinja'
```

## Testing Tool Calling

Once deployed, test with a tool-calling request:

```bash
# Get your model endpoint
ENDPOINT="https://inference-gateway.apps.<cluster-domain>/<namespace>/<model-name>"

# Test with a tool-calling prompt
curl -X POST "$ENDPOINT/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-4b",
    "messages": [
      {
        "role": "user",
        "content": "What is the weather in San Francisco?"
      }
    ],
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "get_weather",
          "description": "Get the current weather for a location",
          "parameters": {
            "type": "object",
            "properties": {
              "location": {
                "type": "string",
                "description": "The city and state, e.g. San Francisco, CA"
              }
            },
            "required": ["location"]
          }
        }
      }
    ]
  }'
```

## Common Issues

### Issue 1: Tool calling not working

**Symptom**: Model doesn't call tools, just responds with text

**Solution**: 
- ✅ Verify `--enable-auto-tool-choice` is set
- ✅ Verify correct `--tool-call-parser` for your model
- ✅ Check vLLM logs: `oc logs <pod-name> -c kserve-container`

### Issue 2: Wrong parser error

**Symptom**: Error like "Unknown tool call parser: xxx"

**Solution**: Use the correct parser for your model:
- Qwen → `hermes`
- Llama 3 → `llama3_json`
- Mistral → `mistral`

### Issue 3: Environment variable not applied

**Symptom**: Tool calling doesn't work after adding `VLLM_ADDITIONAL_ARGS`

**Solution**:
1. Delete the pod to force recreation:
   ```bash
   oc delete pod -l serving.kserve.io/inferenceservice=<model-name>
   ```
2. Verify env var is set:
   ```bash
   oc get pod <pod-name> -o jsonpath='{.spec.containers[*].env[?(@.name=="VLLM_ADDITIONAL_ARGS")].value}'
   ```

## Model-Specific Recommendations

### Qwen3-4B

```yaml
env:
  - name: VLLM_ADDITIONAL_ARGS
    value: "--enable-auto-tool-choice --tool-call-parser=hermes"
resources:
  limits:
    cpu: '4'
    memory: 16Gi
    nvidia.com/gpu: "1"
```

### Qwen3-8B

```yaml
env:
  - name: VLLM_ADDITIONAL_ARGS
    value: "--enable-auto-tool-choice --tool-call-parser=hermes"
resources:
  limits:
    cpu: '8'
    memory: 32Gi
    nvidia.com/gpu: "1"
```

### Llama 3.2-3B

```yaml
args:
  - '--dtype=half'
  - '--max-model-len=20000'
  - '--gpu-memory-utilization=0.95'
  - '--enable-auto-tool-choice'
  - '--tool-call-parser=llama3_json'
  - '--chat-template=/opt/app-root/template/tool_chat_template_llama3.2_json.jinja'
```

## Additional vLLM Arguments

You can combine tool calling with other vLLM arguments:

```yaml
env:
  - name: VLLM_ADDITIONAL_ARGS
    value: "--enable-auto-tool-choice --tool-call-parser=hermes --max-model-len=8000 --gpu-memory-utilization=0.9"
```

Common additional arguments:
- `--max-model-len=<int>` - Maximum sequence length
- `--gpu-memory-utilization=<float>` - GPU memory usage (0.0-1.0)
- `--dtype=half` - Use FP16 precision
- `--max-num-seqs=<int>` - Maximum number of sequences to process in parallel

## References

- CAI's guide to RHOAI 3.0 (Section 3 - llm-d examples)
- vLLM Documentation: https://docs.vllm.ai/
- OpenAI Function Calling: https://platform.openai.com/docs/guides/function-calling

---

**Last Updated**: November 2025  
**RHOAI Version**: 3.0  
**Source**: CAI's guide to RHOAI 3.0.pdf

