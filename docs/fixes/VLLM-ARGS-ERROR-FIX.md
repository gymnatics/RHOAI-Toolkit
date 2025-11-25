# Fix: VLLM_ADDITIONAL_ARGS Bash Error

## Error

```
/bin/bash: --: invalid option
Usage: /bin/bash [GNU long option] [option] ...
```

## What the CAI Guide Says

The CAI guide shows **TWO different approaches**:

### 1. For InferenceService (vLLM) - Uses `args`

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

### 2. For LLMInferenceService (llm-d) - Uses `VLLM_ADDITIONAL_ARGS`

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-sample
spec:
  template:
    containers:
    - name: main
      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: "--enable-auto-tool-choice --tool-call-parser=hermes"
```

**Key difference**: 
- `InferenceService` uses `args` (works reliably)
- `LLMInferenceService` uses `VLLM_ADDITIONAL_ARGS` env var

## Root Cause of Your Error

The `VLLM_ADDITIONAL_ARGS` environment variable is being interpreted by bash instead of being passed to the vLLM Python command. This happens when:

1. Arguments start with `--` and bash tries to interpret them
2. The container entrypoint uses shell expansion
3. Bash processes the env var before passing to Python

**The CAI guide uses YAML deployment**, not the UI, which is why it works for them.

## Solution

### ❌ What DOESN'T Work

**Removing the dashes doesn't work** - you'll get:
```
enable-auto-tool-choice: command not found
```

This is because the container is trying to execute it as a shell command.

### ✅ Option 1: Use YAML Deployment (ONLY Reliable Solution)

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

### ✅ Option 2: Don't Use VLLM_ADDITIONAL_ARGS via UI

**The UI doesn't properly handle `VLLM_ADDITIONAL_ARGS` with arguments.**

Instead, deploy **without** tool calling first, then patch the deployment directly:

```bash
# Deploy via UI normally (without VLLM_ADDITIONAL_ARGS)
# Then patch the deployment after it's created:

# Get the deployment name
DEPLOYMENT=$(oc get deployment -n <your-namespace> -l serving.kserve.io/inferenceservice=qwen3-4b -o name)

# Patch the deployment directly
oc patch $DEPLOYMENT -n <your-namespace> --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args",
    "value": [
      "--enable-auto-tool-choice",
      "--tool-call-parser=hermes"
    ]
  }
]'
```

### ✅ Option 3: Delete and Redeploy via YAML (Recommended)

```bash
# Delete the failed deployment
oc delete llmisvc qwen3-4b -n <your-namespace>

# Then redeploy using YAML (see Option 1 above)
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

### The Real Problem

The `VLLM_ADDITIONAL_ARGS` environment variable is designed to be **expanded by the shell**, but:

1. **With `--` prefix**: Bash interprets `--enable-auto-tool-choice` as bash options
   - Error: `/bin/bash: --: invalid option`

2. **Without `--` prefix**: Bash tries to execute `enable-auto-tool-choice` as a command
   - Error: `enable-auto-tool-choice: command not found`

### Container Entrypoint Issue

The container likely has an entrypoint like:

```bash
/bin/bash -c "python -m vllm.entrypoints.openai.api_server $VLLM_ADDITIONAL_ARGS"
```

When bash expands `$VLLM_ADDITIONAL_ARGS`, it processes the arguments **before** passing them to Python.

### Why YAML Works

In YAML, you're not using `VLLM_ADDITIONAL_ARGS`. Instead, you're directly setting the container `args`:

```yaml
args:
  - '--enable-auto-tool-choice'
  - '--tool-call-parser=hermes'
```

This bypasses shell expansion entirely and passes arguments directly to the container command.

### Why UI Doesn't Work

The RHOAI UI likely:
1. Takes your `VLLM_ADDITIONAL_ARGS` value
2. Sets it as an environment variable
3. The container's entrypoint script tries to expand it
4. Bash interprets it incorrectly

**Conclusion**: `VLLM_ADDITIONAL_ARGS` via UI is fundamentally broken for arguments with `--`.

### What the CAI Guide Does Differently

The CAI guide **always uses YAML deployment**, never the UI. Their example works because:

1. They deploy via `oc apply -f` (not UI)
2. The YAML properly quotes the env var value
3. They're using `LLMInferenceService` (llm-d), not `InferenceService` (vLLM)

**From CAI guide** (Section 3 - llm-d):
```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-sample
spec:
  template:
    containers:
    - name: main
      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: "--enable-auto-tool-choice --tool-call-parser=hermes"
```

This works when deployed via YAML, but **fails when you try to add it via the UI**.

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

