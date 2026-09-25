# Ceph RGW (OpenShift Data Foundation) S3 Backend

## Prerequisites

This backend requires **OpenShift Data Foundation (ODF)** to be installed and configured:

1. Install the ODF operator from OperatorHub
2. Create a `StorageCluster` CR in the `openshift-storage` namespace
3. Verify the NooBaa S3 endpoint is healthy:
   ```bash
   oc get noobaa -n openshift-storage
   oc get storageclass openshift-storage.noobaa.io
   ```

## How It Works

Instead of deploying a standalone S3 server (like SeaweedFS or MinIO), the Ceph RGW
backend uses ODF's **ObjectBucketClaim (OBC)** mechanism:

1. The toolkit creates an `ObjectBucketClaim` in the target namespace
2. ODF auto-provisions:
   - An S3 bucket (name derived from `generateBucketName` prefix)
   - A `Secret` with `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
   - A `ConfigMap` with `BUCKET_HOST`, `BUCKET_PORT`, `BUCKET_NAME`, `BUCKET_REGION`
3. `storage-backend.sh` reads these auto-generated credentials to create the
   RHOAI data-connection secrets that KServe/DSPA/notebooks consume

## Usage

```bash
# Via setup-model-storage.sh
./scripts/setup-model-storage.sh --backend=ceph-rgw

# Via deploy scripts
export S3_BACKEND=ceph-rgw
./demo/autorag-demo/deploy.sh
```

## Limitations

- Requires ODF (not available on all clusters, especially lightweight sandboxes)
- Bucket names are auto-generated (prefixed, not exact) — consumers use the
  data-connection secret which contains the real name
- No standalone admin console (use `oc` or `noobaa` CLI for management)
