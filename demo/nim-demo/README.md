# NVIDIA NIM Demo

Deploy NVIDIA NIM (Inference Microservices) on Red Hat OpenShift AI, showcasing NVIDIA AI Enterprise capabilities with optimized model serving.

## Overview

This demo deploys a **Nemotron Nano 8B** model using NVIDIA NIM on RHOAI 3.4+, demonstrating:

- NVIDIA NIM optimized inference runtime
- NGC container registry integration
- GenAI Studio / Playground integration
- NIM-specific GPU metrics (tokens/sec, TTFT)
- OpenAI-compatible API endpoint

## Prerequisites

| Requirement | Details |
|-------------|---------|
| RHOAI 3.4+ | NIM enabled (`kserve.nim.managementState: Managed`) |
| GPU node | L40S (48 GB) recommended, T4 (16 GB) minimum |
| NGC API Key | From [ngc.nvidia.com/setup/api-keys](https://org.ngc.nvidia.com/setup/api-keys) |
| NVIDIA Developer Program | Free membership at [developer.nvidia.com](https://developer.nvidia.com/developer-program) |

## Quick Start

```bash
# Interactive (prompts for NGC key)
./deploy.sh

# Non-interactive
./deploy.sh --ngc-key nvapi-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Deploy smaller model (good for T4 GPUs)
./deploy.sh --model nemotron-nano-4b --ngc-key nvapi-xxx

# Clean up
./deploy.sh --delete
```

## Getting Your NGC API Key

1. Go to [ngc.nvidia.com](https://org.ngc.nvidia.com/setup/api-keys)
2. Sign in with your NVIDIA Developer Program account
3. Click **Generate API Key**
4. Select **Personal Key** type
5. Copy the key (starts with `nvapi-...`)

## Model Options

| Preset | Model | VRAM (BF16) | Best For |
|--------|-------|-------------|----------|
| `nemotron-nano-8b` (default) | Llama 3.1 Nemotron Nano 8B | 16 GB | L40S, A100, reasoning + tool calling |
| `nemotron-nano-4b` | Llama 3.1 Nemotron Nano 4B | 8 GB | T4, L4, lightweight inference |

## What Gets Deployed

```
nim-demo namespace
├── Secret: nvidia-nim-image-pull (nvcr.io registry auth)
├── Secret: nvidia-nim-secrets (NGC_API_KEY)
├── PVC: nim-cache-pvc (50 Gi model cache)
├── ServingRuntime: nemotron-nano-8b (NIM container)
├── InferenceService: nemotron-nano-8b (KServe model endpoint)
└── ServiceMonitor: nim-metrics (Prometheus scraping)
```

## Testing the Deployment

### Via curl

```bash
# Get auth token
TOKEN=$(oc create token default -n nim-demo --duration=1h)

# Chat completion
curl -sk https://<inference-url>/v1/chat/completions \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nemotron-nano-8b",
    "messages": [{"role": "user", "content": "Explain Kubernetes in one sentence."}]
  }'
```

### Via GenAI Studio

1. Open RHOAI Dashboard: `https://rh-ai.apps.<cluster-domain>`
2. Go to **Projects** > **nim-demo**
3. Click the model under **Models** tab
4. Use the **Playground** to chat

### Tool Calling (Nemotron 8B supports function calling)

```bash
curl -sk https://<inference-url>/v1/chat/completions \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nemotron-nano-8b",
    "messages": [{"role": "user", "content": "What is the weather in Sydney?"}],
    "tools": [{
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get current weather",
        "parameters": {"type": "object", "properties": {"city": {"type": "string"}}}
      }
    }]
  }'
```

## Monitoring

NIM exposes Prometheus metrics at `/metrics`:

- `nim:inference:request_success` — successful requests
- `nim:inference:request_duration_seconds` — request latency
- `nim:inference:tokens_per_second` — throughput
- `nim:inference:time_to_first_token_seconds` — TTFT
- `nim:inference:gpu_cache_usage_perc` — KV cache utilization

If User Workload Monitoring is enabled, these are automatically scraped via the ServiceMonitor.

## Troubleshooting

### Model not loading (stuck in Loading state)

```bash
# Check pod logs
oc logs deployment/nemotron-nano-8b-predictor -n nim-demo -c kserve-container

# Common issues:
# - NGC key invalid → re-create secrets
# - Insufficient GPU memory → try nemotron-nano-4b
# - Image pull failed → verify nvcr.io access
```

### Playground returns 404

The `NIM_SERVED_MODEL_NAME` env var must match the InferenceService name. This is already configured in the manifests but if you deployed via the RHOAI UI, patch it:

```bash
oc patch servingruntime nemotron-nano-8b -n nim-demo --type=json \
  -p '[{"op":"add","path":"/spec/containers/0/env/-","value":{"name":"NIM_SERVED_MODEL_NAME","value":"nemotron-nano-8b"}}]'
```

### Istio sidecar issues

If traffic is blocked by Istio proxy:

```bash
oc patch inferenceservice nemotron-nano-8b -n nim-demo --type=merge \
  -p '{"metadata":{"annotations":{"traffic.sidecar.istio.io/excludeOutboundPorts":"8000"}}}'
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  OpenShift AI Platform                                  │
│                                                         │
│  ┌──────────────┐   ┌──────────────┐   ┌───────────┐  │
│  │ GenAI Studio │   │   KServe     │   │ Monitoring │  │
│  │  Playground  │──▶│ InferenceSvc │◀──│  (Observe) │  │
│  └──────────────┘   └──────┬───────┘   └───────────┘  │
│                             │                           │
│  ┌──────────────────────────▼───────────────────────┐  │
│  │  NVIDIA NIM ServingRuntime                       │  │
│  │  ┌─────────────────────────────────────────────┐ │  │
│  │  │  nvcr.io/nim/nvidia/nemotron-nano-8b        │ │  │
│  │  │  - TensorRT-LLM optimized                   │ │  │
│  │  │  - OpenAI-compatible API                    │ │  │
│  │  │  - /metrics endpoint                        │ │  │
│  │  └─────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
│                             │                           │
│  ┌──────────────────────────▼───────────────────────┐  │
│  │  NVIDIA L40S GPU (48 GB)                         │  │
│  │  Ada Lovelace • FP8 Tensor Cores • 864 GB/s BW  │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```
