# Fix: VLLM_ADDITIONAL_ARGS Bash Error

## Error

```
/bin/bash: --: invalid option
Usage: /bin/bash [GNU long option] [option] ...
```

## Root Cause

The `VLLM_ADDITIONAL_ARGS` environment variable is being interpreted by bash instead of being passed to the vLLM Python command. This happens when:

1. Arguments start with `--` and bash tries to interpret them
2. Arguments are not properly quoted
3. The container entrypoint is `/bin/bash` instead of direct Python execution

## Solution

### Option 1: Remove Leading Dashes (Recommended for UI)

When deploying via the **RHOAI Dashboard UI**:

**Instead of**:
```
--enable-auto-tool-choice --tool-call-parser=hermes
```

**Use** (without leading dashes):
```
enable-auto-tool-choice tool-call-parser=hermes
```

Or try with single dash:
```
-enable-auto-tool-choice -tool-call-parser=hermes
```

### Option 2: Use YAML Deployment (Most Reliable)

Deploy using `LLMInferenceService` YAML with proper escaping:

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-4b
  namespace: your-namespace
  labels:
    kueue.x-k8s.io/queue-name: default
    opendatahub.io/dashboard: "true"
spec:
  replicas: 1
  model:
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest
    name: qwen3-4b
  router:
    route: {}
    gateway: {}
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

**Key point**: In YAML, the `value` field is properly quoted as a string.

### Option 3: Fix Existing Deployment

If you already deployed and got the error:

```bash
# Get the LLMInferenceService name
oc get llmisvc -n <your-namespace>

# Patch it with correct format
oc patch llmisvc qwen3-4b -n <your-namespace> --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/containers/0/env/-",
    "value": {
      "name": "VLLM_ADDITIONAL_ARGS",
      "value": "--enable-auto-tool-choice --tool-call-parser=hermes"
    }
  }
]'
```

Or delete and redeploy:
```bash
oc delete llmisvc qwen3-4b -n <your-namespace>
# Then redeploy using YAML above
```

## Verification

After fixing, check the pod logs:

```bash
# Get the pod name
oc get pods -n <your-namespace> | grep qwen3-4b

# Check logs
oc logs <pod-name> -n <your-namespace> -c kserve-container

# You should see vLLM starting with the correct arguments:
# INFO: Started server process [1]
# INFO: Waiting for application startup.
# INFO: Application startup complete.
```

## Why This Happens

### Container Entrypoint Issue

Some container images use `/bin/bash` as the entrypoint with a command like:

```bash
/bin/bash -c "python -m vllm.entrypoints.openai.api_server $VLLM_ADDITIONAL_ARGS"
```

When `VLLM_ADDITIONAL_ARGS` starts with `--`, bash interprets it as bash options instead of passing it to Python.

### Proper Format

The vLLM container should directly execute Python:

```bash
python -m vllm.entrypoints.openai.api_server --enable-auto-tool-choice --tool-call-parser=hermes
```

## Alternative: Use args Instead of env

For `InferenceService` (not `LLMInferenceService`), you can use `args` directly:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: qwen3-4b
spec:
  predictor:
    model:
      args:
        - '--dtype=half'
        - '--max-model-len=8000'
        - '--enable-auto-tool-choice'
        - '--tool-call-parser=hermes'
      modelFormat:
        name: vLLM
      runtime: vllm-runtime
```

This bypasses the environment variable issue entirely.

## Testing Tool Calling

After deployment succeeds, test tool calling:

```bash
# Get the endpoint
ENDPOINT=$(oc get route -n <namespace> -l serving.kserve.io/inferenceservice=qwen3-4b -o jsonpath='{.items[0].spec.host}')

# Test with a tool-calling prompt
curl -X POST "https://$ENDPOINT/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-4b",
    "messages": [
      {"role": "user", "content": "What is the weather in San Francisco?"}
    ],
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "get_weather",
          "description": "Get the current weather",
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

## Summary

**Quick Fix**:
1. Delete the failed deployment
2. Redeploy using YAML with proper quoting
3. Or use the UI without leading `--` dashes

**Root Cause**: Bash interpreting `--` as bash options instead of vLLM arguments

**Best Practice**: Always deploy models with tool calling via YAML for reliability

---

**Last Updated**: November 2025  
**Issue**: vLLM argument parsing error  
**Affects**: Models deployed with `VLLM_ADDITIONAL_ARGS` via UI

