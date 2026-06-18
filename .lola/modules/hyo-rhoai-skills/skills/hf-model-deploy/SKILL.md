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
              pip install -q huggingface_hub hf_transfer boto3 &&
              
              # Step A: Download from HuggingFace (fast, resumable)
              huggingface-cli download $MODEL_ID \
                --local-dir /tmp/model \
                --local-dir-use-symlinks False &&
              
              # Step B: Upload to S3/MinIO
              python3 -c "
              import boto3, os, pathlib
              s3 = boto3.client('s3',
                  endpoint_url=os.environ['S3_ENDPOINT'],
                  aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
                  aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'])
              
              bucket = os.environ.get('S3_BUCKET', 'models')
              try: s3.create_bucket(Bucket=bucket)
              except: pass
              
              base = pathlib.Path('/tmp/model')
              for f in base.rglob('*'):
                  if f.is_file():
                      key = f'${MODEL_ID}/{f.relative_to(base)}'
                      print(f'Uploading {key} ({f.stat().st_size/1e6:.1f}MB)')
                      s3.upload_file(str(f), bucket, key)
              print('Upload complete!')
              "
          env:
            - { name: MODEL_ID, value: "<org/model-name>" }
            - { name: HF_TOKEN, valueFrom: { secretKeyRef: { name: hf-token, key: token, optional: true } } }
            - { name: HF_HUB_ENABLE_HF_TRANSFER, value: "1" }
            - { name: HF_HUB_DISABLE_XET, value: "1" }
            - { name: S3_ENDPOINT, value: "http://minio.minio.svc:9000" }
            - { name: AWS_ACCESS_KEY_ID, value: "minioadmin" }
            - { name: AWS_SECRET_ACCESS_KEY, value: "minioadmin" }
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
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "minioadmin"
  AWS_SECRET_ACCESS_KEY: "minioadmin"
  AWS_S3_ENDPOINT: "http://minio.minio.svc:9000"
  AWS_S3_BUCKET: "models"
  AWS_DEFAULT_REGION: "us-east-1"
```

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

---

### 3. PVC Pre-Cache (When no S3 available — single pod only)

Pre-download model weights to a PersistentVolumeClaim, then mount in InferenceService.
Uses `hf_transfer` for high-speed parallel downloads with automatic resume.

**Limitations vs S3:**
- RWO (ReadWriteOnce): only one pod can mount at a time
- No replica scaling
- Tied to a single availability zone

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

**Step 2: Download Job (resilient, resumable)**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: download-<model-short-name>
  namespace: <namespace>
spec:
  backoffLimit: 3
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: downloader
          image: registry.redhat.io/ubi9/python-311:latest
          command: ["/bin/bash", "-c"]
          args:
            - |
              pip install -q huggingface_hub hf_transfer &&
              huggingface-cli download $MODEL_ID \
                --local-dir /mnt/models \
                --local-dir-use-symlinks False
          env:
            - { name: MODEL_ID, value: "<org/model-name>" }
            - { name: HF_TOKEN, valueFrom: { secretKeyRef: { name: hf-token, key: token, optional: true } } }
            - { name: HF_HUB_ENABLE_HF_TRANSFER, value: "1" }
            - { name: HF_HUB_DISABLE_XET, value: "1" }
          resources:
            requests: { cpu: "2", memory: "4Gi" }
            limits: { cpu: "8", memory: "8Gi" }
          volumeMounts:
            - { name: model-vol, mountPath: /mnt/models }
      volumes:
        - name: model-vol
          persistentVolumeClaim:
            claimName: model-cache-<model-short-name>
```

**Step 3: Deploy InferenceService with PVC**

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

| Model Family | Parser | Example |
|-------------|--------|---------|
| Qwen2.5/3 | `hermes` | `--tool-call-parser=hermes` |
| Llama 3.x | `llama3_json` | `--tool-call-parser=llama3_json` |
| Mistral | `mistral` | `--tool-call-parser=mistral` |
| Gemma 4 | `gemma4` | `--tool-call-parser=gemma4` |

Always pair with: `--enable-auto-tool-choice`

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Init:0/1` for >30min | HF download hung | Switch to OCI or S3 strategy |
| `CUDA out of memory` | Model too large for GPU | Reduce `--max-model-len` or use smaller/quantized model |
| `ErrImagePull` | Auth required for registry.redhat.io | Add pull secret to ServiceAccount |
| `ImagePullBackOff` | OCI image tag wrong | Verify tag: `curl quay.io/api/v1/repository/.../tag/` |
| `untolerated taint` | Missing GPU toleration | Add `tolerations` for `nvidia.com/gpu` |
| Pod on non-GPU node | Resources not in `model.resources` | Move GPU requests inside `spec.predictor.model.resources` |
| S3 access denied | Wrong Data Connection secret | Check `serving.kserve.io/storageSecretName` annotation |
| S3 download slow | MinIO on remote cluster | Deploy MinIO in same cluster/region as model namespace |

---

## Workflow

1. **Determine model availability** → Search OCI catalogs first
2. **Choose strategy** → OCI > S3/MinIO > PVC > (never hf:// for >10GB)
3. **Validate GPU fit** → Check VRAM vs model size table
4. **Pre-cache if needed** → Run HF→S3 transfer Job (one-time)
5. **Deploy** → Apply InferenceService manifest
6. **Monitor** → `oc get isvc -w` until READY=True
7. **Test** → `curl <endpoint>/v1/models`
