---
title: Deployment Annotations & Labels Reference
category: references
tags: [annotations, labels, inferenceservice, llminferenceservice, llm-d, vllm, maas, dashboard]
semantic_keywords: [RHOAI annotations, InferenceService labels, LLMInferenceService deployment, MaaS integration, dashboard display]
use_cases: [model-deploy, serving-runtime-config, debug-inference]
last_updated: 2026-06-03
---

# Deployment Annotations & Labels Reference

This document covers required and recommended annotations/labels for model deployments on OpenShift AI, including both the standard `InferenceService` and the newer `LLMInferenceService` (llm-d) CRDs.

## Quick Decision: InferenceService vs LLMInferenceService

| Feature | InferenceService | LLMInferenceService (llm-d) |
|---------|-----------------|---------------------------|
| MaaS Gateway integration | No (direct Route only) | Yes (automatic registration) |
| Custom vLLM args | Via `spec.predictor.model.args` or container override | Via `VLLM_ADDITIONAL_ARGS` env var |
| GPU resources | Explicit in `spec.predictor.model.resources` | Via `spec.template.containers[].resources` |
| Tolerations | `spec.predictor.tolerations` | `spec.template.tolerations` |
| Serving Runtime | User-managed `ServingRuntime` CR | Platform-managed via `LLMInferenceServiceConfig` |
| Storage Initializer | Controlled by `storageUri` field | Always enabled (uses `spec.model.uri`) |
| OpenShift version | 4.14+ | 4.19+ |
| RHOAI version | 2.x+ | 3.4+ |

> **Rule of thumb**: Use `LLMInferenceService` when you need MaaS gateway integration (API key management, rate limiting, centralized access). Use standard `InferenceService` for direct model access without MaaS.

---

## ServingRuntime Annotations & Labels

Required for the RHOAI Dashboard to properly recognize and display the runtime:

### Required Labels

```yaml
metadata:
  labels:
    opendatahub.io/dashboard: "true"   # Makes runtime visible in RHOAI Dashboard
```

### Required Annotations

```yaml
metadata:
  annotations:
    openshift.io/display-name: "vLLM ServingRuntime (FP8)"      # Display name in Dashboard
    opendatahub.io/apiProtocol: REST                             # API protocol type (REST or gRPC)
    opendatahub.io/template-name: vllm-runtime                   # Template identifier for Dashboard matching
    opendatahub.io/template-display-name: "vLLM ServingRuntime for KServe"  # Template display name
```

### Common Issue: "Unknown Serving Runtime" in Dashboard

If the RHOAI Dashboard shows "Unknown Serving Runtime":
1. Ensure `opendatahub.io/apiProtocol` annotation is present on the ServingRuntime
2. Ensure `opendatahub.io/template-name` annotation is present
3. Ensure `opendatahub.io/dashboard: "true"` label is present
4. Verify `spec.supportedModelFormats[].name` matches the InferenceService `modelFormat.name` (case-sensitive)

---

## InferenceService (Standard vLLM Deployment)

### Required Labels

```yaml
metadata:
  labels:
    opendatahub.io/dashboard: "true"   # Makes model visible in RHOAI Dashboard
```

### Required Annotations

```yaml
metadata:
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment   # or "Serverless" for Knative
    openshift.io/display-name: "Model Display Name"    # Human-readable name in Dashboard
```

### Full Example (vLLM with HuggingFace model)

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: qwen3-14b
  namespace: rhoai-models
  labels:
    opendatahub.io/dashboard: "true"
    app.kubernetes.io/part-of: my-app
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    openshift.io/display-name: "Qwen3-14B-FP8-dynamic"
spec:
  predictor:
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
    model:
      modelFormat:
        name: vLLM
      runtime: vllm-runtime
      storageUri: hf://RedHatAI/Qwen3-14B-FP8-dynamic
      args:
        - --max-model-len=32768
        - --reasoning-parser=qwen3
        - --enable-auto-tool-choice
        - --tool-call-parser=qwen3_coder
      resources:
        requests:
          cpu: "2"
          memory: 16Gi
          nvidia.com/gpu: "1"
        limits:
          cpu: "8"
          memory: 32Gi
          nvidia.com/gpu: "1"
```

### Storage Initializer Known Issue

On certain GPU nodes, the RHOAI storage-initializer may deadlock during HuggingFace model download finalization (permission denied during file rename). Workaround: bypass storage-initializer by specifying a container directly and letting vLLM download the model at startup:

```yaml
spec:
  predictor:
    containers:
      - name: kserve-container
        image: registry.redhat.io/rhaii/vllm-cuda-rhel9:3.4.0
        command: ["python3", "-m", "vllm.entrypoints.openai.api_server"]
        args:
          - --port=8080
          - --model=RedHatAI/Qwen3-14B-FP8-dynamic
          - --served-model-name=qwen3-14b
          - --download-dir=/dev/shm/models
        env:
          - name: HF_TOKEN
            valueFrom:
              secretKeyRef:
                name: hf-token
                key: token
          - name: HF_HUB_OFFLINE
            value: "0"
          - name: HF_HOME
            value: /dev/shm/models
        volumeMounts:
          - name: dshm
            mountPath: /dev/shm
    volumes:
      - name: dshm
        emptyDir:
          medium: Memory
          sizeLimit: 32Gi
```

> **Note**: This bypasses the storage-initializer entirely. The RHOAI vLLM image defaults to `HF_HUB_OFFLINE=1`, so `HF_HUB_OFFLINE=0` must be explicitly set.

---

## LLMInferenceService (llm-d — MaaS-compatible)

### Required Labels

```yaml
metadata:
  labels:
    opendatahub.io/dashboard: "true"   # Dashboard visibility
```

### Required Annotations

```yaml
metadata:
  annotations:
    openshift.io/display-name: "Model Display Name"   # Human-readable name
```

### Spec Fields

| Field | Required | Description |
|-------|:--------:|-------------|
| `spec.model.uri` | Yes | Model source URI (e.g., `hf://RedHatAI/Qwen3-14B-FP8-dynamic`) |
| `spec.model.name` | Yes | Served model name (used in API requests) |
| `spec.replicas` | No | Static replica count (mutually exclusive with `spec.scaling`) |
| `spec.scaling` | No | Autoscaling config (requires `wva` sub-field) |
| `spec.template` | No | Pod template overrides (containers, tolerations, volumes) |
| `spec.template.containers[].resources` | Recommended | GPU and memory resources |
| `spec.template.tolerations` | Recommended | GPU node tolerations |
| `spec.baseRefs` | No | References to LLMInferenceServiceConfig templates |

### Passing Custom vLLM Arguments

The llm-d template reads the `VLLM_ADDITIONAL_ARGS` environment variable:

```yaml
spec:
  template:
    containers:
      - name: main
        env:
          - name: VLLM_ADDITIONAL_ARGS
            value: "--max-model-len=32768 --reasoning-parser=qwen3 --enable-auto-tool-choice --tool-call-parser=qwen3_coder"
```

### Valid Tool-Call Parsers (RHOAI vLLM 3.4.0 / v0.18.x)

```
deepseek_v3, ernie45, granite, granite-20b-fc, granite4, hermes,
internlm, jamba, kimi_k2, llama3_json, llama4_json, llama4_pythonic,
minimax, mistral, olmo3, openai, phi4_mini_json, pythonic,
qwen3_coder, qwen3_xml, seed_oss, step3, xlam
```

> **Note**: `qwen3` is NOT a valid tool-call-parser. Use `qwen3_coder` for Qwen3 models.

### MaaS Gateway Registration (Required for MaaS Policies)

For the model to appear in MaaS Authorization Policies, the `LLMInferenceService` must reference the `maas-default-gateway` AND a `MaaSModelRef` must be created:

**Step 1**: Add `maas-default-gateway` to `spec.router.gateway.refs`:

```yaml
spec:
  router:
    gateway:
      refs:
        - name: maas-default-gateway
          namespace: openshift-ingress
```

**Step 2**: Create a `MaaSModelRef` in the same namespace:

```yaml
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSModelRef
metadata:
  name: qwen3-14b
  namespace: rhoai-models
spec:
  modelRef:
    kind: LLMInferenceService
    name: qwen3-14b
```

Without both of these, the MaaS Dashboard will show "No models available" even though the model is deployed and Ready via `LLMInferenceService`.

### Common Issue: "No models available" in MaaS Authorization Policies

**Error**: MaaS Dashboard shows "No models available" despite LLMInferenceService being Ready.

**Root Causes** (check in order):
1. **Missing `MaaSModelRef`**: Create one referencing the LLMInferenceService
2. **Wrong gateway reference**: HTTPRoute references `openshift-ai-inference` but MaaS expects `maas-default-gateway`. Add `spec.router.gateway.refs` pointing to `maas-default-gateway`
3. **MaaSModelRef status Failed**: Check `oc get maasmodelref -n <ns> -o yaml` for error messages

### Full Example (LLMInferenceService with GPU + MaaS)

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-14b
  namespace: rhoai-models
  labels:
    opendatahub.io/dashboard: "true"
    opendatahub.io/genai-asset: "true"
    kueue.x-k8s.io/queue-name: default
    app.kubernetes.io/part-of: code-assistant-lab
  annotations:
    security.opendatahub.io/enable-auth: "false"
spec:
  model:
    name: qwen3-14b
    uri: oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-14b
  replicas: 1
  router:
    gateway:
      refs:
        - name: maas-default-gateway
          namespace: openshift-ingress
    route: {}
    scheduler: {}
  template:
    containers:
      - name: main
        env:
          - name: VLLM_ADDITIONAL_ARGS
            value: "--max-model-len=32768 --gpu-memory-utilization=0.92 --reasoning-parser=qwen3 --enable-auto-tool-choice --tool-call-parser=qwen3_coder"
        resources:
          limits:
            nvidia.com/gpu: "1"
            cpu: "8"
            memory: 32Gi
          requests:
            nvidia.com/gpu: "1"
            cpu: "2"
            memory: 16Gi
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
---
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSModelRef
metadata:
  name: qwen3-14b
  namespace: rhoai-models
spec:
  modelRef:
    kind: LLMInferenceService
    name: qwen3-14b
```

### LLMInferenceServiceConfig Selection

The llm-d controller automatically selects configs from `redhat-ods-applications` namespace:

| Config | Purpose |
|--------|---------|
| `v3-4-0-kserve-config-llm-template` | Base vLLM serving template |
| `v3-4-0-kserve-config-llm-template-nvidia-cuda` | NVIDIA GPU image overlay |
| `v3-4-0-kserve-config-llm-router-route` | Router/gateway config |
| `v3-4-0-kserve-config-llm-scheduler` | Scheduler config |

The `baseRefs` field can reference specific accelerator configs:

```yaml
spec:
  baseRefs:
    - name: v3-4-0-kserve-config-llm-template-nvidia-cuda
```

### Storage Initializer Deadlock (Known Issue)

The llm-d storage-initializer uses `hf_transfer` for fast downloads but may deadlock on certain nodes due to permission errors during file finalization. Symptoms:
- Pod stuck in `Init:0/1` state for 30+ minutes
- Storage-initializer logs show "Permission denied: '/mnt/tmp_...'" then no further output
- File sizes in `.cache/huggingface/download/` reach full size but remain `.incomplete`

Root cause: The HuggingFace library cannot atomically rename files when OpenShift's random UID conflicts with filesystem permission operations.

Workaround: If LLMInferenceService storage-initializer deadlocks, fall back to standard InferenceService with direct vLLM download (see InferenceService section above).

---

## Namespace Annotations

For a namespace to appear as a Data Science Project in RHOAI Dashboard:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: rhoai-models
  labels:
    opendatahub.io/dashboard: "true"
  annotations:
    openshift.io/display-name: "RHOAI Models"
```

---

## MaaS Integration Checklist

For a model to be fully visible in MaaS (Authorization Policies, API keys, rate limiting):

1. Deploy via `LLMInferenceService` (not standard `InferenceService`)
2. Add `spec.router.gateway.refs` pointing to `maas-default-gateway`
3. Create a `MaaSModelRef` CR in the same namespace
4. Verify `MaaSModelRef` status is `Ready` (not `Failed`)

---

## Annotation Quick Reference

| Resource | Annotation/Label | Purpose | Required |
|----------|-----------------|---------|:--------:|
| **ServingRuntime** | `opendatahub.io/dashboard: "true"` (label) | Dashboard visibility | Yes |
| **ServingRuntime** | `openshift.io/display-name` | Display name | Yes |
| **ServingRuntime** | `opendatahub.io/apiProtocol: REST` | API protocol | Yes |
| **ServingRuntime** | `opendatahub.io/template-name` | Template matching | Yes |
| **ServingRuntime** | `opendatahub.io/template-display-name` | Template display name | Recommended |
| **InferenceService** | `opendatahub.io/dashboard: "true"` (label) | Dashboard visibility | Yes |
| **InferenceService** | `serving.kserve.io/deploymentMode` | RawDeployment or Serverless | Yes |
| **InferenceService** | `openshift.io/display-name` | Display name | Recommended |
| **LLMInferenceService** | `opendatahub.io/dashboard: "true"` (label) | Dashboard visibility | Yes |
| **LLMInferenceService** | `opendatahub.io/genai-asset: "true"` (label) | GenAI asset marker | Recommended |
| **LLMInferenceService** | `spec.router.gateway.refs` | MaaS gateway registration | Yes (for MaaS) |
| **MaaSModelRef** | `spec.modelRef.kind: LLMInferenceService` | Links model to MaaS | Yes (for MaaS) |
| **Namespace** | `opendatahub.io/dashboard: "true"` (label) | DSP recognition | Yes |
| **Namespace** | `openshift.io/display-name` | Display name | Recommended |
