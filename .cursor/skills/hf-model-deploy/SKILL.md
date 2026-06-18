---
name: hf-model-deploy
description: |
  Deploy HuggingFace models on OpenShift AI with stable, resumable downloads.
  
  Use when:
  - "Deploy a HuggingFace model on OpenShift"
  - "Download model without failures"
  - "Pre-cache model weights to S3/MinIO"
  - "Find modelcar image in quay.io"
  - "Set up vLLM with local model weights"
  - "Upload model to S3 and deploy"
  
  Prevents download hangs by using OCI ModelCar (preferred) or S3 pre-caching with hf_transfer.
  NOT for bare-metal Docker deployments (use Ansible role pattern instead).
---

# /hf-model-deploy Skill

Stable, failure-resistant model deployment for OpenShift AI. Solves the common problem of
HuggingFace downloads hanging or failing mid-stream during KServe storage-initializer execution.

## Strategy Priority (always follow this order)

### 1. OCI ModelCar (Best — zero download at pod startup)

Models pre-packaged as OCI container images. Container runtime handles pull with
built-in retry, resume, and layer caching.

**Discovery — find available models:**

```bash
# Search quay.io public catalog
curl -s "https://quay.io/api/v1/repository/redhat-ai-services/modelcar-catalog/tag/?filter_tag_name=like:qwen" | python3 -c "
import sys,json
tags = json.load(sys.stdin).get('tags',[])
for t in tags:
    if not t['name'].endswith('z') and '--' not in t['name']:
        print(f\"  {t['name']:40s} ({t['size']/1e9:.1f} GB)\")
"

# Check Red Hat validated images (requires pull secret)
# See: https://docs.redhat.com/en/documentation/red_hat_ai/3/html/validated_models/redhat-ai-validated-modelcar-images
```

**Deploy with OCI URI:**

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: <model-name>
  namespace: <namespace>
  labels:
    opendatahub.io/dashboard: "true"
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    openshift.io/display-name: "<Display Name>"
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
      storageUri: oci://quay.io/redhat-ai-services/modelcar-catalog:<tag>
      args:
        - --max-model-len=16384
        - --gpu-memory-utilization=0.90
        - --enable-auto-tool-choice
        - --tool-call-parser=hermes
      resources:
        requests:
          nvidia.com/gpu: "1"
          cpu: "4"
          memory: 24Gi
        limits:
          nvidia.com/gpu: "1"
          cpu: "8"
          memory: 48Gi
```

**Available OCI sources:**

| Registry | Auth Required | Example |
|----------|--------------|---------|
| `quay.io/redhat-ai-services/modelcar-catalog` | No | `:qwen3-8b`, `:qwen3-14b`, `:qwen2.5-7b-instruct` |
| `registry.redhat.io/rhelai1/modelcar-*` | Yes (pull secret) | `modelcar-qwen3-8b-fp8-dynamic:1.5` |

---

### 2. S3/MinIO Pre-Cache (Enterprise-grade — shared, durable, RHOAI-native)

Download model weights ONCE to S3-compatible storage (MinIO in-cluster or AWS S3),
then all InferenceServices pull from S3. This is the RHOAI "Data Connection" pattern.

**Why S3 is better than PVC:**
- Shared: multiple pods/replicas can pull from the same bucket
- Durable: S3 has built-in redundancy (vs single-node PVC)
- Native: KServe storage-initializer uses boto3 (auto-retry, chunk download)
- RHOAI Dashboard compatible: Data Connection UI works with S3
- **llm-d compatible**: Works with LLMInferenceService multi-pod architecture (PVC RWO does NOT)

**Performance (in-cluster MinIO):**
- S3 → predictor download: **~2 seconds** for 29GB (in-cluster network, same node)
- vs `hf://`: 15-40 minutes for same model
- vs PVC: incompatible with LLMInferenceService (RWO breaks router-scheduler)

**Quick setup (RHOAI Toolkit):**
```bash
./scripts/setup-model-storage.sh -n <namespace> --data-connection-ns <namespace> --storage-size 100Gi
```

**Step 1: Deploy MinIO (if not already available)**

```bash
# Check if MinIO or S3-compatible storage exists
oc get pods -A | grep -i minio

# If not, deploy MinIO in-cluster (one-time setup)
cat <<'EOF' | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: minio
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: minio
spec:
  replicas: 1
  selector:
    matchLabels: { app: minio }
  template:
    metadata:
      labels: { app: minio }
    spec:
      containers:
        - name: minio
          image: quay.io/minio/minio:latest
          args: ["server", "/data", "--console-address", ":9001"]
          env:
            - { name: MINIO_ROOT_USER, value: "minioadmin" }
            - { name: MINIO_ROOT_PASSWORD, value: "minioadmin" }
          ports:
            - { containerPort: 9000 }
            - { containerPort: 9001 }
          volumeMounts:
            - { name: data, mountPath: /data }
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: minio-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-data
  namespace: minio
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 200Gi
  storageClassName: gp3-csi
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio
spec:
  selector: { app: minio }
  ports:
    - { name: api, port: 9000, targetPort: 9000 }
    - { name: console, port: 9001, targetPort: 9001 }
EOF
```

**Step 2: Download HF model → Upload to S3 (one-time Job)**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hf-to-s3-<model-short-name>
  namespace: minio
spec:
  backoffLimit: 3
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: transfer
          image: registry.redhat.io/ubi9/python-311:latest
          command: ["/bin/bash", "-c"]
          args:
            - |
              pip install -q huggingface_hub boto3 &&
              python3 -c "
              import boto3, os, pathlib
              from huggingface_hub import snapshot_download

              model_id = os.environ['MODEL_ID']
              print(f'Downloading {model_id} from HuggingFace...')
              snapshot_download(model_id, local_dir='/tmp/model', local_dir_use_symlinks=False)
              print('Download complete. Uploading to S3...')

              s3 = boto3.client('s3',
                  endpoint_url=os.environ['S3_ENDPOINT'],
                  aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
                  aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'])

              bucket = os.environ.get('S3_BUCKET', 'models')
              base = pathlib.Path('/tmp/model')
              uploaded = 0
              for f in sorted(base.rglob('*')):
                  if f.is_file() and '.cache' not in str(f):
                      key = f'{model_id}/{f.relative_to(base)}'
                      print(f'Uploading {key} ({f.stat().st_size/1e6:.1f} MB)')
                      s3.upload_file(str(f), bucket, key)
                      uploaded += 1
              print(f'Done! Uploaded {uploaded} files to s3://{bucket}/{model_id}/')
              "
          env:
            - { name: MODEL_ID, value: "<org/model-name>" }
            - { name: HF_TOKEN, valueFrom: { secretKeyRef: { name: hf-token, key: hf-token, optional: true } } }
            - { name: HF_HUB_DISABLE_XET, value: "1" }
            - { name: S3_ENDPOINT, value: "http://minio.<namespace>.svc:9000" }
            - { name: AWS_ACCESS_KEY_ID, value: "minio" }
            - { name: AWS_SECRET_ACCESS_KEY, value: "minio123" }
            - { name: S3_BUCKET, value: "models" }
          resources:
            requests: { cpu: "4", memory: "8Gi" }
            limits: { cpu: "8", memory: "16Gi" }
```

**Step 3: Create Data Connection (S3 credentials for KServe)**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: s3-model-connection
  namespace: <model-namespace>
  labels:
    opendatahub.io/dashboard: "true"
    opendatahub.io/managed: "true"
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: "Model Storage (MinIO)"
    serving.kserve.io/s3-endpoint: minio.<namespace>.svc:9000
    serving.kserve.io/s3-usehttps: "0"
    serving.kserve.io/s3-verifyssl: "0"
    serving.kserve.io/s3-region: us-east-1
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "minio"
  AWS_SECRET_ACCESS_KEY: "minio123"
  AWS_S3_ENDPOINT: "http://minio.<namespace>.svc:9000"
  AWS_S3_BUCKET: "models"
  AWS_DEFAULT_REGION: "us-east-1"
```

**IMPORTANT**: The `serving.kserve.io/s3-*` annotations are REQUIRED for the KServe storage-initializer to connect to MinIO. Without `s3-usehttps: "0"` and `s3-verifyssl: "0"`, the initializer attempts HTTPS verification against MinIO's HTTP endpoint and fails with `403 Forbidden`.

**Step 4: Deploy InferenceService with S3**

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: <model-name>
  namespace: <namespace>
  labels:
    opendatahub.io/dashboard: "true"
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    serving.kserve.io/storageSecretName: s3-model-connection
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
      storageUri: s3://models/<org>/<model-name>
      args:
        - --max-model-len=16384
        - --gpu-memory-utilization=0.90
        - --enable-auto-tool-choice
        - --tool-call-parser=hermes
      resources:
        requests:
          nvidia.com/gpu: "1"
        limits:
          nvidia.com/gpu: "1"
```

**Step 5: Deploy LLMInferenceService with S3 (for MaaS/llm-d)**

Use this instead of Step 4 when MaaS gateway integration is required:

```yaml
apiVersion: serving.kserve.io/v1alpha2
kind: LLMInferenceService
metadata:
  name: <model-name>
  namespace: <namespace>
  labels:
    opendatahub.io/dashboard: "true"
    opendatahub.io/genai-asset: "true"
    kueue.x-k8s.io/queue-name: default
  annotations:
    openshift.io/display-name: "<Display Name>"
    security.opendatahub.io/enable-auth: "false"
    serving.kserve.io/storageSecretName: s3-model-connection
spec:
  model:
    name: <model-name>
    uri: s3://models/<org>/<model-name>
  replicas: 1
  router:
    gateway: {}
    route: {}
    scheduler: {}
  template:
    containers:
      - name: main
        env:
          - name: VLLM_ADDITIONAL_ARGS
            value: "--max-model-len=4096 --gpu-memory-utilization=0.90 --enforce-eager --enable-auto-tool-choice --tool-call-parser=hermes"
        resources:
          requests:
            nvidia.com/gpu: "1"
            cpu: "4"
            memory: "32Gi"
          limits:
            nvidia.com/gpu: "1"
            cpu: "8"
            memory: "48Gi"
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
```

**Note**: `--enforce-eager` is recommended for FP8 models on L40S (48GB) to avoid CUDAGraph OOM during profiling when model weights exceed 60% of VRAM.

---

### 3. PVC Pre-Cache (When no S3 available — single pod only)

Pre-download model weights to a PersistentVolumeClaim, then mount in InferenceService.
Uses `huggingface_hub.snapshot_download` for parallel downloads with automatic resume.

**Limitations vs S3:**
- RWO (ReadWriteOnce): only one pod can mount at a time
- No replica scaling
- Tied to a single availability zone
- **⚠️ NOT compatible with LLMInferenceService (llm-d)** — see warning below

**⚠️ CRITICAL: PVC + LLMInferenceService Incompatibility**

`LLMInferenceService` creates TWO deployments: predictor + router-scheduler. The router's
tokenizer sidecar also mounts the model PVC. With EBS RWO, both pods MUST be on the same
node, but the operator does not co-schedule them and resets any manual patches.

**Use PVC only with plain `InferenceService` (single-pod). For `LLMInferenceService` (llm-d/MaaS),
use S3/MinIO or `hf://` instead.**

**⚠️ CRITICAL: Availability Zone Pre-Check (MANDATORY before PVC creation)**

EBS-backed PVCs with `WaitForFirstConsumer` binding bind to the zone of the FIRST pod that
mounts them. If the download Job runs on a non-GPU node in a different AZ, the PVC becomes
permanently locked to that zone and the GPU pod will NEVER schedule.

```bash
# Step 0: Identify GPU node zone BEFORE creating PVC
GPU_ZONE=$(oc get nodes -l nvidia.com/gpu.present=true \
  -o jsonpath='{.items[0].metadata.labels.topology\.kubernetes\.io/zone}')
echo "GPU node zone: $GPU_ZONE"
# Use this zone as nodeSelector in the download Job!
```

**Step 1: Create PVC**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: model-cache-<model-short-name>
  namespace: <namespace>
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: <model-size-GB * 2.5>Gi
  storageClassName: gp3-csi
```

**Step 2: Download Job (with zone-pinning to GPU node)**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: download-<model-short-name>
  namespace: <namespace>
spec:
  backoffLimit: 3
  activeDeadlineSeconds: 3600
  template:
    spec:
      restartPolicy: OnFailure
      # PIN TO GPU NODE ZONE — ensures PVC binds to correct AZ
      nodeSelector:
        topology.kubernetes.io/zone: <GPU_ZONE>
      containers:
        - name: downloader
          image: registry.redhat.io/ubi9/python-311:latest
          command: ["/bin/bash", "-c"]
          args:
            - |
              pip install -q huggingface_hub &&
              python3 -c "
              from huggingface_hub import snapshot_download
              snapshot_download(
                  '$MODEL_ID',
                  local_dir='/mnt/models',
                  local_dir_use_symlinks=False
              )
              print('Download complete!')
              "
          env:
            - { name: MODEL_ID, value: "<org/model-name>" }
            - { name: HF_TOKEN, valueFrom: { secretKeyRef: { name: hf-token, key: hf-token, optional: true } } }
            - { name: HF_HUB_DISABLE_XET, value: "1" }
          resources:
            requests: { cpu: "2", memory: "4Gi" }
            limits: { cpu: "8", memory: "16Gi" }
          volumeMounts:
            - { name: model-vol, mountPath: /mnt/models }
      volumes:
        - name: model-vol
          persistentVolumeClaim:
            claimName: model-cache-<model-short-name>
```

**Step 3: Deploy InferenceService with PVC (NOT LLMInferenceService)**

```yaml
storageUri: pvc://model-cache-<model-short-name>
```

---

### 4. Direct HF Download (AVOID — fragile for large models)

Only use for models < 10GB. For larger models, ALWAYS use strategy 1, 2, or 3.

```yaml
storageUri: hf://<org>/<model-name>
```

**Known issues with `hf://` for large models (>10GB):**
- XET protocol hangs (connection drops silently after 18GB+)
- No resume capability in storage-initializer
- Single-threaded download → timeout on slow networks
- Pod stuck in `Init:0/1` for hours with no error message

---

## Model Size vs GPU VRAM Guide

| GPU | VRAM | Max Model (FP16) | Max Model (FP8) | Max Model (INT4) |
|-----|------|-----------------|-----------------|-----------------|
| L4 | 24GB | ~7B | ~14B | ~30B |
| L40S | 48GB | ~14B | ~30B | ~70B |
| A100 | 80GB | ~30B | ~65B | ~120B |
| H100 | 80GB | ~30B | ~65B | ~120B |

**Rule of thumb:** `model_weight_GB + KV_cache_GB < VRAM * gpu_memory_utilization`

---

## Tool Calling Configuration

| Model Family | Parser | Example | Notes |
|-------------|--------|---------|-------|
| Qwen2.5/3/3.6 | `hermes` | `--tool-call-parser=hermes` | |
| Llama 3.x | `llama3_json` | `--tool-call-parser=llama3_json` | |
| Llama 4.x | `llama4_json` | `--tool-call-parser=llama4_json` | |
| Mistral | `mistral` | `--tool-call-parser=mistral` | |
| Gemma 4 | `functiongemma` | `--tool-call-parser=functiongemma` | RHOAI vLLM only; use `hermes` on community vLLM if `functiongemma` unavailable |
| Granite | `granite` | `--tool-call-parser=granite` | |

Always pair with: `--enable-auto-tool-choice`

**Important**: Parser availability varies by vLLM version. If a parser is not recognized, the container will crash with `KeyError: 'invalid tool call parser: ...'`. Check available parsers in the error message and pick the closest match.

---

## XET Protocol Notes (llm-d Storage Initializer)

The llm-d storage-initializer uses HuggingFace's XET protocol for parallel downloads:

- **Download speed**: Fast (24GB in ~5-8 minutes)
- **Finalization**: After download completes, the `.incomplete` file must be renamed/moved. This can take **10-20+ minutes** for large files on EBS/network storage
- **Permission warnings**: `Could not set the permissions ... Continuing without setting permissions` — this is **normal** and does not indicate failure
- **Monitoring progress**: Use `oc exec <pod> -c storage-initializer -- du -sh /mnt/models/` to check actual disk usage
- **Stuck detection**: If file size hasn't changed for 20+ minutes AND no new logs appear, consider deleting and retrying

---

## FP8 Quantized Models: GPU Compatibility

| GPU | Arch | FP8 Support | Notes |
|-----|------|------------|-------|
| H100/H200 | Hopper | Full | Native FP8 compute |
| A100 | Ampere | Full | FP8 via software emulation in vLLM |
| L40S | Ada | Problematic | `cutlass_scaled_mm` kernel may fail with community `vllm/vllm-openai` images |
| L4 | Ada | Problematic | Same CUTLASS kernel issue |

**Workaround for Ada GPUs (L40S/L4)**:
- Use BF16 model weights instead of FP8
- Or use RHOAI's `registry.redhat.io/rhaii/vllm-cuda-rhel9` image (built with Ada-compatible kernels)
- Or add `--enforce-eager` flag (disables CUDA graphs, may reduce performance)

**Note on CUDAGraph OOM**: FP8 27B models on L40S (48GB) may OOM during CUDAGraph profiling
even after model loads successfully. Add `--enforce-eager` to disable CUDAGraph when GPU memory
is tight (model_weight > 60% of VRAM).

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Init:0/1` for >30min | HF download hung or XET finalization slow | Check `du -sh` for progress; if truly stuck, switch to OCI or S3 |
| `CUDA out of memory` | Model too large for GPU | Reduce `--max-model-len` or use smaller/quantized model |
| `ErrImagePull` | Auth required for registry.redhat.io | Add pull secret to ServiceAccount |
| `ImagePullBackOff` | OCI image tag wrong | Verify tag: `curl quay.io/api/v1/repository/.../tag/` |
| `untolerated taint` | Missing GPU toleration | Add `tolerations` for `nvidia.com/gpu` |
| Pod on non-GPU node | Resources not in `model.resources` | Move GPU requests inside `spec.predictor.model.resources` |
| S3 access denied | Wrong Data Connection secret | Check `serving.kserve.io/storageSecretName` annotation |
| `S3 error [403]: Forbidden` | Secret missing KServe S3 annotations | Add `serving.kserve.io/s3-usehttps: "0"` and `s3-verifyssl: "0"` to secret annotations |
| `NoSuchBucket` | MinIO bucket not created | `oc exec <minio-pod> -- mc alias set local http://localhost:9000 <user> <pass> && mc mb local/models` |
| S3 download slow | MinIO on remote cluster | Deploy MinIO in same cluster/region as model namespace |
| `cutlass_scaled_mm` RuntimeError | FP8 kernel incompatible with GPU | Use BF16 model or RHOAI native image or `--enforce-eager` |
| `getpwuid(): uid not found` | Community vLLM image on OpenShift | Add `USER=vllm`, `HOME=/tmp` env vars (see debug-inference skill) |
| `model type X not recognized` | vLLM image too old for model arch | Use newer image tag (check Docker Hub for model-specific tags) |
| PVC pod `Pending` + `didn't match PersistentVolume's node affinity` | PVC bound to wrong AZ (download ran on non-GPU node) | Delete PVC, recreate, re-run download Job with `nodeSelector: topology.kubernetes.io/zone: <GPU_ZONE>` |
| `torch.OutOfMemoryError` during CUDAGraph profiling | Model + CUDAGraph exceeds VRAM | Add `--enforce-eager` to disable CUDAGraph |
| Router-scheduler `ContainerCreating` + Multi-Attach error | PVC (RWO) + LLMInferenceService multi-pod | **Cannot use PVC with llm-d** — switch to S3 or `hf://` |

---

## Workflow

1. **Determine model availability** → Search OCI catalogs first
2. **Choose strategy** → OCI > S3/MinIO > `hf://` > PVC (see decision matrix below)
3. **Validate GPU fit** → Check VRAM vs model size table
4. **Check GPU node AZ** → `oc get nodes -l nvidia.com/gpu.present=true -o jsonpath='{..zone}'` (REQUIRED for PVC/S3 on EBS)
5. **Pre-cache if needed** → Run download Job with `nodeSelector` pinned to GPU zone
6. **Deploy** → Apply InferenceService/LLMInferenceService manifest
7. **Monitor** → `oc get isvc -w` or `oc get llmisvc -w` until READY=True
8. **Test** → `curl <endpoint>/v1/models`

### Storage Strategy Decision Matrix

| CR Type | OCI | S3/MinIO | `hf://` | PVC |
|---------|-----|----------|---------|-----|
| `InferenceService` | ✅ Best | ✅ Good | ⚠️ Fragile >10GB | ✅ OK |
| `LLMInferenceService` (llm-d) | ✅ Best | ✅ Good | ⚠️ Slow but works | ❌ RWO breaks router |
