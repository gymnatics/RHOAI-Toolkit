# Adding Models to GenAI Playground in RHOAI 3.0

## Overview

The GenAI Playground (GenAI Studio) in RHOAI 3.0 provides an interactive interface for testing and experimenting with deployed LLM models. It leverages **LlamaStack** as the backend to provide a unified experience for:
- Testing model responses with custom prompts
- Adjusting model parameters (temperature, top_p, max_tokens)
- Comparing different models side-by-side
- Using MCP (Model Context Protocol) servers for tool calling
- Sharing and collaborating on prompts

## Prerequisites

- RHOAI 3.0 installed with GenAI Studio enabled
- At least one model deployed as an InferenceService
- Model status: **Started** and **Running**
- LlamaStack Operator installed (automatic with RHOAI 3.0)

## Architecture

When you add a model to the playground:

1. **User Action**: Click "Add to Playground" in AI Assets Endpoints
2. **LlamaStackDistribution CR**: Automatically created in the model's namespace
3. **ConfigMap**: `run.yaml` config generated with model endpoints
4. **Pod**: `lsd-genai-playground` pod starts (LlamaStack backend)
5. **Playground UI**: Model becomes available in GenAI Studio

## Step-by-Step: Adding a Model to Playground

### Step 1: Deploy a Model

First, ensure you have a deployed model with the correct annotations:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llama-32-3b-instruct
  namespace: ai-bu-shared
  labels:
    opendatahub.io/dashboard: "true"      # Show in dashboard
    opendatahub.io/genai-asset: "true"    # Mark as GenAI asset
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    security.opendatahub.io/enable-auth: "false"  # Or "true" for authenticated models
    opendatahub.io/model-type: generative         # Important for GenAI Studio
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      storageUri: 'oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct'
```

**Key Requirements**:
- `opendatahub.io/genai-asset: "true"` - Marks model as GenAI asset
- `opendatahub.io/model-type: generative` - Identifies as LLM
- Model must be in **Running** state

### Step 2: Verify Model is Running

```bash
# Check InferenceService status
oc get inferenceservice llama-32-3b-instruct -n ai-bu-shared

# Expected output:
# NAME                    URL                                           READY   AGE
# llama-32-3b-instruct    https://llama-32-3b-instruct-ai-bu-shared...  True    5m
```

The model should show:
- ✅ **READY**: `True`
- ✅ **URL**: Available
- ✅ **AGE**: At least 2-3 minutes (fully initialized)

### Step 3: Add Model to Playground (Via Dashboard)

1. **Navigate to AI Assets**:
   - Go to **GenAI Studio → AI Assets → Endpoints**
   - Or **Models → Deployed Models**

2. **Locate Your Model**:
   - Find your model in the list (e.g., `llama-32-3b-instruct`)
   - Status should be **Started** and **Running**

3. **Add to Playground**:
   - Click the **⋮** (three dots) menu on the model row
   - Select **Add to Playground**
   - Or click the model name, then click **Add to Playground** button

4. **Select Model** (if multiple available):
   - A dialog will appear showing available models
   - Select the model(s) you want to add
   - Click **Add**

5. **Wait for Initialization**:
   - A **LlamaStackDistribution** will be created
   - The `lsd-genai-playground` pod will start
   - This takes **2-3 minutes**

### Step 4: Add Model to Playground (Via CLI)

Alternatively, you can create the LlamaStackDistribution manually:

```yaml
apiVersion: llamastack.io/v1alpha1
kind: LlamaStackDistribution
metadata:
  name: genai-playground
  namespace: ai-bu-shared
spec:
  models:
    - modelId: "llama-32-3b-instruct"
      providerConfig:
        config:
          endpoint: "https://llama-32-3b-instruct-ai-bu-shared.apps.cluster.example.com/v1"
          modelType: "llama3"
        providerId: "remote::vllm"
      model:
        metadata: {}
        modelType: "llama3"
        providerResourceId: "llama-32-3b-instruct"
```

Apply it:

```bash
oc apply -f llama-stack-distribution.yaml -n ai-bu-shared
```

### Step 5: Verify Playground Setup

```bash
# Check LlamaStackDistribution
oc get llamastackdistribution -n ai-bu-shared

# Check playground pod
oc get pods -n ai-bu-shared | grep lsd-genai-playground

# Check playground ConfigMap
oc get configmap -n ai-bu-shared | grep run.yaml

# View the run.yaml configuration
oc get configmap genai-playground-run-config -n ai-bu-shared -o yaml
```

Expected output:
```
NAME               AGE
genai-playground   2m

NAME                                 READY   STATUS    RESTARTS   AGE
lsd-genai-playground-abc123-xyz      1/1     Running   0          2m
```

### Step 6: Access the Playground

1. **Navigate to GenAI Studio**:
   - Go to **GenAI Studio → Playground** in the RHOAI dashboard

2. **Verify Model is Available**:
   - Your model should appear in the **Model** dropdown
   - Select it to start chatting

3. **Configure Parameters** (optional):
   - **System Instructions**: Set the model's behavior
   - **Temperature**: Control randomness (0.0-2.0)
   - **Top P**: Nucleus sampling (0.0-1.0)
   - **Max Tokens**: Response length limit
   - **Frequency Penalty**: Reduce repetition
   - **Presence Penalty**: Encourage new topics

4. **Start Testing**:
   - Type a prompt in the chat box
   - Click **Send** or press Enter
   - View the model's response

## Using Authenticated Models

If your model requires authentication (`security.opendatahub.io/enable-auth: "true"`):

### Step 1: Add API Token to LlamaStackDistribution

Edit the LlamaStackDistribution to add the token:

```bash
oc edit llamastackdistribution genai-playground -n ai-bu-shared
```

Add the token as an environment variable:

```yaml
spec:
  template:
    spec:
      containers:
      - name: llama-stack
        env:
        - name: VLLM_API_TOKEN_1
          value: "your-api-token-here"  # ← Add your token
        - name: VLLM_TLS_VERIFY
          value: "false"
```

### Step 2: Get the Token

If using KServe authentication:

```bash
# Generate a service account token
oc create token default -n ai-bu-shared --duration=24h
```

Use this token as `VLLM_API_TOKEN_1`.

## Advanced Configuration

### Configuring Multiple Models

Add multiple models to the same playground:

```yaml
apiVersion: llamastack.io/v1alpha1
kind: LlamaStackDistribution
metadata:
  name: genai-playground
  namespace: ai-bu-shared
spec:
  models:
    - modelId: "llama-32-3b-instruct"
      providerConfig:
        config:
          endpoint: "https://llama-32-3b-instruct.../v1"
          modelType: "llama3"
        providerId: "remote::vllm"
    - modelId: "mistral-7b-instruct"
      providerConfig:
        config:
          endpoint: "https://mistral-7b-instruct.../v1"
          modelType: "mistral"
        providerId: "remote::vllm"
```

### Customizing run.yaml ConfigMap

The `run.yaml` ConfigMap controls LlamaStack behavior:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: genai-playground-run-config
  namespace: ai-bu-shared
data:
  run.yaml: |
    version: '2'
    image_name: distribution
    providers:
      inference:
        - provider_id: remote::vllm
          provider_type: remote::vllm
          config:
            url: https://llama-32-3b-instruct.../v1
    apis:
      - inference
    models:
      - metadata: {}
        model_id: llama-32-3b-instruct
        model_type: llama3
        provider_id: remote::vllm
        provider_resource_id: llama-32-3b-instruct
```

## Troubleshooting

### Model Not Appearing in Playground

**Check**:
```bash
# 1. Verify model has correct labels/annotations
oc get inferenceservice llama-32-3b-instruct -n ai-bu-shared -o yaml | grep -A 2 labels

# 2. Check model is running
oc get inferenceservice llama-32-3b-instruct -n ai-bu-shared

# 3. Verify LlamaStackDistribution exists
oc get llamastackdistribution -n ai-bu-shared
```

**Fix**:
- Ensure `opendatahub.io/genai-asset: "true"` label is present
- Ensure `opendatahub.io/model-type: generative` annotation is present
- Model must be in Running state for at least 2-3 minutes

### Playground Pod Crashing

**Check logs**:
```bash
oc logs -n ai-bu-shared deployment/lsd-genai-playground
```

**Common issues**:
- **Invalid model endpoint**: Check InferenceService URL
- **Authentication failure**: Verify API token if using auth
- **TLS certificate issues**: Set `VLLM_TLS_VERIFY: "false"`

### "Connection Error" in Playground

**Check connectivity**:
```bash
# Test from playground pod
oc exec -n ai-bu-shared deployment/lsd-genai-playground -- \
  curl -k https://llama-32-3b-instruct.../v1/models
```

**Fix**:
- Verify InferenceService route is accessible
- Check network policies
- Verify Service Mesh configuration

### Model Responses are Slow

**Optimize**:
1. Check model resource limits (CPU, memory, GPU)
2. Adjust vLLM arguments (`--max-model-len`, `--gpu-memory-utilization`)
3. Use smaller max_tokens in playground settings
4. Consider using a smaller model for interactive testing

## Best Practices

1. **Model Selection**
   - Use smaller models (3B-7B) for interactive testing
   - Reserve larger models for production inference

2. **Resource Management**
   - Limit concurrent playground users
   - Set appropriate resource requests/limits
   - Monitor GPU utilization

3. **Authentication**
   - Enable auth for production models
   - Use short-lived tokens (24h)
   - Rotate tokens regularly

4. **Prompt Engineering**
   - Use system instructions to set model behavior
   - Test with various temperatures
   - Document successful prompts

5. **Collaboration**
   - Share playground links with team members
   - Document model quirks and limitations
   - Create prompt libraries

## CLI Quick Reference

```bash
# Check if model is ready for playground
oc get inferenceservice <model-name> -n <namespace>

# View LlamaStackDistribution
oc get llamastackdistribution -n <namespace>

# Check playground pod logs
oc logs -n <namespace> deployment/lsd-genai-playground

# Get playground configuration
oc get configmap -n <namespace> | grep run.yaml

# Restart playground (if issues)
oc delete pod -l app=lsd-genai-playground -n <namespace>

# Remove model from playground
oc delete llamastackdistribution genai-playground -n <namespace>
```

## Related Documentation

- [GenAI Studio Overview](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0/html/working_with_generative_ai_models/index)
- [LlamaStack Documentation](https://llama-stack.readthedocs.io/)
- [Model Deployment Guide](INTERACTIVE-MODEL-DEPLOYMENT.md)
- [MCP Servers Guide](MCP-SERVER-SETUP.md)

## Status

✅ **Available in RHOAI 3.0**  
📚 Based on CAI Guide Section 2 (Step 4) - GenAI Studio Playground Integration

