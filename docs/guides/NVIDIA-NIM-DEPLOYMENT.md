# NVIDIA NIM Deployment Guide

Deploy NVIDIA NIM (Inference Microservices) on Red Hat OpenShift AI for optimized model serving with NVIDIA AI Enterprise.

## Overview

NVIDIA NIM provides optimized inference microservices that integrate natively with RHOAI 3.4+. This guide covers:

1. NGC account setup and API key generation
2. NIM platform enablement in RHOAI
3. Model deployment (Nemotron Nano 8B)
4. GenAI Studio / Playground integration
5. Monitoring and troubleshooting

## Prerequisites

| Requirement | Details |
|-------------|---------|
| OpenShift 4.14+ | With RHOAI 3.4+ installed |
| GPU Node | L40S (48 GB) recommended, T4 (16 GB) minimum |
| GPU Operator | NVIDIA GPU Operator + Node Feature Discovery |
| NVIDIA Account | Developer Program membership (free) |
| NGC API Key | Personal key from NGC portal |

## Step 1: NGC API Key Setup

### Join NVIDIA Developer Program

1. Go to [developer.nvidia.com/developer-program](https://developer.nvidia.com/developer-program)
2. Create account or sign in
3. Accept terms (free tier is sufficient for NIM)

### Generate NGC API Key

1. Go to [org.ngc.nvidia.com/setup/api-keys](https://org.ngc.nvidia.com/setup/api-keys)
2. Sign in with your NVIDIA account
3. Click **Generate API Key**
4. Select **Personal Key** type
5. Give it a name (e.g., "RHOAI NIM Demo")
6. Copy the key — it starts with `nvapi-...`
7. Store it securely (you won't see it again)

### Verify Key Access

```bash
# Test NGC API key
curl -s -H "Authorization: Bearer nvapi-YOUR_KEY_HERE" \
  https://api.ngc.nvidia.com/v2/org/nvidia/repos | jq '.repositories | length'
```

If the response shows a number (e.g., `50+`), your key is valid.

## Step 2: Automated Deployment

### Quick Demo Deploy

The fastest path — deploys NIM model directly:

```bash
cd demo/nim-demo/
./deploy.sh --ngc-key nvapi-YOUR_KEY_HERE
```

### Full Platform Setup

Enables NIM in RHOAI, creates credentials, deploys model, sets up monitoring:

```bash
./scripts/deploy-nim.sh --ngc-key nvapi-YOUR_KEY_HERE
```

### Options

| Flag | Description |
|------|-------------|
| `--ngc-key KEY` | NGC API key (prompts if omitted) |
| `--model nemotron-nano-4b` | Deploy smaller 4B model (T4-friendly) |
| `--namespace NS` | Custom namespace (default: `nim-demo`) |
| `--gpu-count N` | GPUs per replica (default: 1) |
| `--deploy-grafana` | Also deploy NIM Grafana dashboard |
| `--skip-platform` | Skip RHOAI config, deploy model only |

## Step 3: Manual Deployment (Alternative)

If you prefer step-by-step manual deployment:

### 3a. Enable NIM in RHOAI Dashboard

1. Log in to RHOAI Dashboard as admin
2. Go to **Applications** > **Explore**
3. Find the **NVIDIA NIM** tile
4. Click **Enable**
5. Enter your NGC API key when prompted
6. Click **Submit**

### 3b. Create a Data Science Project

1. Go to **Data Science Projects** > **Create project**
2. Name it `nim-demo`
3. Under **Model Serving**, select **NVIDIA NIM** platform

### 3c. Deploy Model via Dashboard

1. Click **Deploy Model**
2. Select a model from the NIM catalog (e.g., Nemotron Nano 8B)
3. Configure:
   - Replicas: 1
   - Size: Small (or match your GPU)
   - Hardware profile: GPU profile with `nvidia.com/gpu` resource
4. Click **Deploy**

### 3d. Wait for Model Ready

Model download and optimization takes 5-15 minutes on first deploy. Monitor:

```bash
# Watch InferenceService status
oc get inferenceservice -n nim-demo -w

# Check pod logs
oc logs -f deployment/nemotron-nano-8b-predictor -n nim-demo -c kserve-container
```

## Step 4: Access the Model

### GenAI Studio / Playground

1. Go to RHOAI Dashboard > **Projects** > **nim-demo**
2. Under **Models**, click the deployed model
3. Use the **Playground** tab for interactive chat

### API Access (OpenAI-compatible)

```bash
# Get token
TOKEN=$(oc create token default -n nim-demo --duration=1h)

# Get inference URL
URL=$(oc get inferenceservice nemotron-nano-8b -n nim-demo -o jsonpath='{.status.url}')

# Chat completion
curl -sk "${URL}/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nemotron-nano-8b",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What are the benefits of NVIDIA NIM?"}
    ],
    "temperature": 0.7,
    "max_tokens": 500
  }'
```

### Tool Calling

Nemotron Nano 8B supports function calling:

```bash
curl -sk "${URL}/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nemotron-nano-8b",
    "messages": [{"role": "user", "content": "What is the weather in Tokyo?"}],
    "tools": [{
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get current weather for a city",
        "parameters": {
          "type": "object",
          "properties": {
            "city": {"type": "string", "description": "City name"}
          },
          "required": ["city"]
        }
      }
    }]
  }'
```

## Step 5: Monitoring

### OpenShift Observe Tab

NIM metrics are automatically available in the OpenShift Observe tab if User Workload Monitoring is enabled:

1. Go to **Observe** > **Metrics**
2. Query NIM metrics:
   - `vllm:num_generation_tokens_total` — total generated tokens
   - `vllm:time_to_first_token_seconds_bucket` — TTFT histogram
   - `vllm:gpu_cache_usage_perc` — KV cache utilization
   - `vllm:num_requests_running` — active requests

### Grafana Dashboard

If Grafana is deployed:

```bash
./scripts/deploy-nim.sh --deploy-grafana
```

Dashboard includes: tokens/sec, TTFT percentiles, GPU utilization, KV cache, request queue.

### NVIDIA DCGM Metrics

GPU-level metrics (already available via GPU Operator):
- `DCGM_FI_DEV_GPU_UTIL` — GPU compute utilization
- `DCGM_FI_DEV_MEM_COPY_UTIL` — memory bandwidth
- `DCGM_FI_DEV_FB_USED` — framebuffer (VRAM) used

## Model Options

| Model | NIM Image | VRAM (BF16) | Features |
|-------|-----------|-------------|----------|
| Nemotron Nano 8B | `nvidia/llama-3.1-nemotron-nano-8b-v1` | 16 GB | Reasoning, tool calling, RAG, 128K context |
| Nemotron Nano 4B | `nvidia/llama3.1-nemotron-nano-4b-v1.1` | 8 GB | Lightweight, T4-compatible, code + chat |
| Nemotron Super 49B | `nvidia/llama-3.3-nemotron-super-49b-v1.5` | 48+ GB (FP8) | Multi-GPU, advanced reasoning |

## Troubleshooting

### NGC API Key Issues

```bash
# Verify key works
curl -s -H "Authorization: Bearer $NGC_API_KEY" https://api.ngc.nvidia.com/v2/org/nvidia/repos | head

# Re-create secrets
oc delete secret nvidia-nim-image-pull nvidia-nim-secrets -n nim-demo
oc create secret docker-registry nvidia-nim-image-pull \
  --docker-server=nvcr.io --docker-username='$oauthtoken' \
  --docker-password="$NGC_API_KEY" -n nim-demo
oc create secret generic nvidia-nim-secrets \
  --from-literal=NGC_API_KEY="$NGC_API_KEY" -n nim-demo
```

### Image Pull Errors

```bash
# Check events
oc get events -n nim-demo --sort-by='.lastTimestamp' | grep -i pull

# Verify secret
oc get secret nvidia-nim-image-pull -n nim-demo -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq .
```

### Model Loading Slowly

First pull downloads 10-20 GB from NGC. Subsequent deployments use the PVC cache:

```bash
# Check download progress
oc logs deployment/nemotron-nano-8b-predictor -n nim-demo -c kserve-container | tail -20

# Verify PVC is bound
oc get pvc nim-cache-pvc -n nim-demo
```

### Playground 404 Error

The `NIM_SERVED_MODEL_NAME` must match the InferenceService name:

```bash
oc patch servingruntime nemotron-nano-8b -n nim-demo --type=json \
  -p '[{"op":"add","path":"/spec/containers/0/env/-","value":{"name":"NIM_SERVED_MODEL_NAME","value":"nemotron-nano-8b"}}]'

# Restart predictor
oc rollout restart deployment/nemotron-nano-8b-predictor -n nim-demo
```

### Insufficient GPU Memory

If the model fails to load on T4 (16 GB):

```bash
# Switch to smaller model
./demo/nim-demo/deploy.sh --delete
./demo/nim-demo/deploy.sh --model nemotron-nano-4b --ngc-key $NGC_API_KEY
```

### Istio Sidecar Interference

If NIM can't reach NGC for model download:

```bash
oc patch inferenceservice nemotron-nano-8b -n nim-demo --type=merge \
  -p '{"metadata":{"annotations":{"traffic.sidecar.istio.io/excludeOutboundPorts":"443"}}}'
```

## Cleanup

```bash
# Remove demo only
./demo/nim-demo/deploy.sh --delete

# Remove everything (including platform config)
./scripts/deploy-nim.sh --delete

# Full namespace cleanup
oc delete project nim-demo
```

## References

- [NVIDIA NIM on RHOAI Documentation](https://docs.nvidia.com/ai-enterprise/deployment/red-hat-ai-factory/latest/deploy-nvidia-nim-redhat.html)
- [NGC API Key Setup](https://org.ngc.nvidia.com/setup/api-keys)
- [NIM LLM Support Matrix](https://docs.nvidia.com/nim/large-language-models/latest/reference/support-matrix.html)
- [Red Hat Developer — NIM on OpenShift AI](https://developers.redhat.com/articles/2025/03/26/generative-ai-nvidia-nim-openshift-ai)
