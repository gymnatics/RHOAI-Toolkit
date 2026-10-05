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
- **DSPA pipeline server** — `objectStorage.externalStorage` just gets a new host/port. See "DSPA Pipeline Server" below — this is now the default `setup_pipeline_server()` path, verified end-to-end against a live cluster.
- **Notebooks and workbenches** — env vars (`S3_ENDPOINT`, `AWS_ACCESS_KEY_ID`, etc.) are injected by the toolkit and updated automatically.

## DSPA Pipeline Server: MinIO Investigation (resolved)

The DSPA (`DataSciencePipelinesApplication`) operator can deploy its own built-in MinIO
(`objectStorage.minio.deploy: true`) independently of the toolkit's `storage-backend.sh`.
This was investigated (Oct 2026) to decide whether it should also migrate to SeaweedFS.

**Findings:**

| Question | Answer |
|---|---|
| Is `quay.io/opendatahub/minio` at risk of the same pull-gating as `quay.io/minio/minio`? | No — different org (`opendatahub`, not `minio`), `is_public: true`, state `NORMAL`. Not gated. |
| Is it actively maintained? | **No.** The repo has exactly **one tag ever published**: `RELEASE.2019-08-14T20-37-41Z-license-compliance`, last pushed 2022-08-15 (a mirror event, not a new build). No newer tag exists, so "pin to a newer ODH image" (Option C) isn't available — there is nothing newer to pin to. |
| CVE exposure? | **41 CVEs** across base OS packages (Alpine 3.9-era `libssl1.1`/`libcrypto1.1`, `curl`/`libcurl`, `musl`, `nghttp2-libs`, `libssh2`), including OpenSSL CVE-2021-3450 (improper cert validation) and CVE-2021-3449 (DoS). Quay's legacy scanner reports severity as "Unknown" but several of these have known CVSS scores in the Medium–High range upstream. |
| Does DSPA work correctly with SeaweedFS via `objectStorage.externalStorage`? | **Yes — confirmed live end-to-end** on `cluster-sclg6` (RHOAI 3.5.1): deployed SeaweedFS, pointed a fresh DSPA at it via `dspa-external.yaml`, got `ObjectStoreAvailable: True` and `Ready: True`, ran a real KFP v2 pipeline (write artifact → read artifact back across two pods), and independently verified via `boto3` against the SeaweedFS S3 API that the artifact objects physically existed in the bucket with correct content. No MinIO pod was created at any point. |

**Decision: Option A — switch the default to SeaweedFS.**

`setup_pipeline_server()` (`lib/functions/rhoai.sh`) now defaults to **SeaweedFS / external S3**
(auto-deployed via `storage-backend.sh` if not already present in the target namespace) instead
of DSPA's built-in MinIO. The built-in-MinIO path is still available (option 2 in the interactive
menu) for quick dev/testing, now with an explicit CVE/legacy warning. The existing-S3 detection
("Storage options" picker) was also fixed to recognize SeaweedFS deployments, not just MinIO — and
a latent bug where `grep` matched the **namespace** name (not just the deployment name) under
`oc get deployment -A` was fixed too (it would, for example, false-match every deployment in a
namespace literally named `*seaweedfs*`).

**Not touched:** `pipeline-demo` and `lmeval-demo`'s already-deployed, operator-managed MinIO pods
were left running as-is — migrating a live DSPA's storage backend requires a data migration (or
accepting pipeline run history loss) that's out of scope for a default-change. Redeploy those demos
(`./demo/pipeline-demo/deploy.sh --delete && ./demo/pipeline-demo/deploy.sh`) to pick up SeaweedFS.

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
