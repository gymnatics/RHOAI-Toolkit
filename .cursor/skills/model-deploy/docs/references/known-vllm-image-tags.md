---
title: vLLM Image Tags Reference
category: references
tags: [vllm, docker, image, container, openshift, compatibility]
semantic_keywords: [vLLM container image, Docker Hub tags, model architecture support, OpenShift compatibility]
use_cases: [model-deploy, debug-inference, hf-model-deploy]
last_updated: 2026-06-10
---

# vLLM Image Tags Reference

Guide for selecting the correct vLLM container image when deploying models on OpenShift AI.

## Image Sources

| Registry | Image | Managed By | OpenShift Native |
|----------|-------|-----------|-----------------|
| `registry.redhat.io/rhaii/vllm-cuda-rhel9` | RHOAI default (used by llm-d) | Red Hat | Yes |
| `vllm/vllm-openai` | Community vLLM | vLLM project | Needs env vars |

## Tag Discovery

```bash
# List recent tags from Docker Hub
curl -s "https://hub.docker.com/v2/repositories/vllm/vllm-openai/tags?page_size=50&ordering=last_updated" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for tag in data.get('results', []):
    print(f\"  {tag['name']:50s} updated: {tag.get('last_updated','')[:10]}\")
"
```

## Key Tags and Model Support

| Tag | Model Support | Notes |
|-----|--------------|-------|
| `registry.redhat.io/rhaii/vllm-cuda-rhel9` | Qwen3, Llama 3/4, Granite, Mistral, Gemma 3 | RHOAI platform default; OpenShift-native UID handling |
| `vllm/vllm-openai:latest` | Same as latest stable release | May lag behind nightly for newest architectures |
| `vllm/vllm-openai:nightly` | Cutting-edge model support | Rebuilt daily from main branch |
| `vllm/vllm-openai:gemma4` | Gemma 4 tower variants (E2B, E4B, 31B) | Does NOT support 12B unified |
| `vllm/vllm-openai:gemma4-unified` | Gemma 4 12B encoder-free (`gemma4_unified`) | Purpose-built for the unified variant |

## OpenShift Compatibility

Community `vllm/vllm-openai` images are NOT built for OpenShift's arbitrary UID security model. Required env vars:

```yaml
env:
  - name: USER
    value: "vllm"
  - name: HOME
    value: "/tmp"
  - name: TORCHINDUCTOR_CACHE_DIR
    value: "/tmp/torch_cache"
  - name: TRITON_CACHE_DIR
    value: "/tmp/.triton"
  - name: NUMBA_CACHE_DIR
    value: "/tmp/.numba"
```

Without these, the container crashes with `KeyError: 'getpwuid(): uid not found: <random-uid>'`.

## Model Architecture → Image Mapping

When RHOAI's default image doesn't support a model architecture:

| Model Architecture | Config `model_type` | Minimum Image |
|-------------------|-------------------|---------------|
| Qwen 2/2.5/3 | `qwen2`, `qwen3` | RHOAI default |
| Llama 3.x/4.x | `llama` | RHOAI default |
| Gemma 2/3 | `gemma2`, `gemma3` | RHOAI default |
| Granite 3.x | `granite` | RHOAI default |
| Mistral/Mixtral | `mistral` | RHOAI default |
| Gemma 4 tower (E2B, E4B, 31B) | `gemma4` | `vllm/vllm-openai:gemma4` |
| Gemma 4 unified (12B) | `gemma4_unified` | `vllm/vllm-openai:gemma4-unified` |

## How to Override in LLMInferenceService

```yaml
apiVersion: serving.kserve.io/v1alpha2
kind: LLMInferenceService
metadata:
  name: my-model
spec:
  template:
    containers:
      - name: main
        image: vllm/vllm-openai:gemma4-unified  # Override here
        env:
          - name: USER
            value: "vllm"
          - name: HOME
            value: "/tmp"
          # ... other required env vars
```

## Checking Model Architecture

To determine what architecture a model uses (before choosing an image):

```bash
# Check config.json on HuggingFace
curl -sL "https://huggingface.co/<org>/<model>/raw/main/config.json" | python3 -c "
import sys, json
c = json.load(sys.stdin)
print(f\"model_type: {c.get('model_type')}\"  )
print(f'architectures: {c.get(\"architectures\")}')
"
```
