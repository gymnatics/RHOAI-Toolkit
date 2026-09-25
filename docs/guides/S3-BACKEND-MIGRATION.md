# S3 Backend Migration Guide: MinIO to SeaweedFS / Ceph RGW

## Overview

The RHOAI Toolkit now supports pluggable S3-compatible storage backends:

| Backend | Status | Use Case |
|---------|--------|----------|
| **SeaweedFS** | **Default** | Lightweight, self-contained. Ideal for demos, sandbox clusters, and single-node deployments. |
| **Ceph RGW** (ODF) | Alternative | Enterprise-grade. Uses OpenShift Data Foundation's ObjectBucketClaim. Requires ODF operator. |
| **MinIO** | **Deprecated** | Legacy backend. Still functional but no longer the default. Will be removed in a future release. |

## Why the Change

MinIO's licensing terms changed, making it unsuitable as the default object storage for this toolkit. SeaweedFS provides an equivalent S3-compatible API surface with a permissive Apache 2.0 license.

## Quick Migration

### For `setup-model-storage.sh`

```bash
# Before (MinIO was implicit default):
./scripts/setup-model-storage.sh -n model-storage

# After (SeaweedFS is new default — same command, just works):
./scripts/setup-model-storage.sh -n model-storage

# Explicitly choose backend:
./scripts/setup-model-storage.sh --backend=seaweedfs -n model-storage
./scripts/setup-model-storage.sh --backend=ceph-rgw -n model-storage
./scripts/setup-model-storage.sh --backend=minio -n model-storage  # deprecated
```

### For Demo Scripts

```bash
# All demo deploy.sh scripts auto-detect the backend or default to SeaweedFS.
# To override:
export S3_BACKEND=seaweedfs  # or ceph-rgw, or minio
./demo/autorag-demo/deploy.sh
```

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `S3_BACKEND` | Override backend selection | `seaweedfs` |
| `S3_ACCESS_KEY` | S3 access key | `admin` |
| `S3_SECRET_KEY` | S3 secret key | `admin123` |
| `S3_STORAGE_SIZE` | PVC size for storage | `200Gi` |

## What Changes (and What Doesn't)

### Unchanged (zero-impact for consumers)

- **RHOAI data-connection Secrets** — the `aws-connection-minio` and `aws-connection-my-storage` secret names and their `AWS_*` keys stay identical. Only the `AWS_S3_ENDPOINT` value changes.
- **InferenceService templates** — `storage.key: aws-connection-my-storage` and `storage.path` stay identical.
- **DSPA pipeline server** — `objectStorage.externalStorage` just gets a new host/port.
- **Notebooks and workbenches** — env vars (`S3_ENDPOINT`, `AWS_ACCESS_KEY_ID`, etc.) are injected by the toolkit and updated automatically.

### Changed

| Component | MinIO | SeaweedFS | Ceph RGW |
|-----------|-------|-----------|----------|
| S3 port | 9000 | 8333 | 80 (via ODF route) |
| Health probe | `/minio/health/live` | `/cluster/status` + TCP:8333 | N/A (ODF managed) |
| Bucket creation | `mc mb` | `aws s3 mb` (generic) | Auto by ObjectBucketClaim |
| Auth config | `MINIO_ROOT_USER/PASSWORD` env | `-s3.config` JSON file | ODF auto-generates |
| Console UI | `:9001` | `:9333` (master/admin) | ODF NooBaa console |
| Image | `quay.io/minio/minio` | `docker.io/chrislusf/seaweedfs` | N/A (ODF pods) |

## Existing Cluster Migration

If you have an existing cluster with MinIO already deployed:

1. **Data is preserved** — MinIO's PVC (`models-pvc`) is not deleted when you switch backends. Deploy the new backend alongside; data connections will point to the new service.
2. **Re-download models** — after switching, re-run `download-model.sh` to populate the new backend's storage.
3. **Update data connections** — run `setup-model-storage.sh` with the new backend; it will overwrite the data-connection secrets with the new endpoint.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  storage-backend.sh  (lib/functions/storage-backend.sh)                 │
│                                                                         │
│  detect_or_select_storage_backend() → S3_BACKEND env                    │
│  deploy_storage_backend()           → oc apply manifests                │
│  create_storage_bucket()            → aws-cli Job                       │
│  get_storage_endpoint()             → http://svc.ns.svc:port            │
│  create_data_connection()           → aws-connection-* Secrets           │
│  wait_for_storage()                 → readiness check                   │
└──────────────────────┬──────────────────────────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
   ┌──────────┐  ┌──────────┐  ┌──────────┐
   │ SeaweedFS│  │ Ceph RGW │  │  MinIO   │
   │ :8333    │  │ via ODF  │  │  :9000   │
   │ (default)│  │ (OBC)    │  │ (legacy) │
   └────┬─────┘  └────┬─────┘  └────┬─────┘
        └──────────────┼─────────────┘
                       ▼
        ┌──────────────────────────────┐
        │  aws-connection-minio        │
        │  aws-connection-my-storage   │
        │  (standard AWS_* keys)       │
        └──────────────┬───────────────┘
                       ▼
        ┌──────────────────────────────┐
        │  KServe / DSPA / Notebooks   │
        │  (unchanged — only see the   │
        │   data-connection Secret)    │
        └──────────────────────────────┘
```

## Manifest Layout

```
lib/manifests/storage/
  seaweedfs/              ← New default
    kustomization.yaml
    seaweedfs-deployment.yaml
    seaweedfs-secret.yaml.tmpl
    seaweedfs-pvc.yaml.tmpl
    seaweedfs-service.yaml
    seaweedfs-routes.yaml
    create-bucket-job.yaml.tmpl
    data-connection.yaml.tmpl
  ceph-rgw/               ← ODF alternative
    kustomization.yaml
    ceph-rgw-objectbucketclaim.yaml.tmpl
    data-connection.yaml.tmpl
    README.md
  minio/                  ← Deprecated legacy
    kustomization.yaml
    minio-deployment.yaml
    minio-secret.yaml.tmpl
    minio-pvc.yaml.tmpl
    minio-service.yaml
    minio-routes.yaml
    minio-bucket-job.yaml.tmpl
    data-connection.yaml.tmpl
```
