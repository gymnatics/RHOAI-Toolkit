# Fix plan: GPU nodes, toolkit storage/demo bugs, 3.5 + 3.4 cluster repairs (2026-11-10)

Source findings: `docs/test-reports/toolkit-ops-2026-11-10.md`. Reference cluster for autorag:
`api.ocp.5msvc.sandbox5559.opentlc.com` (RHOAI 3.5.2, "good").

## What the reference cluster shows (validated read-only)

- autorag-demo there: OGXServer `autorag-ogx` Ready, created 2026-10-16 with **`rh-dev` + `overrideConfig: llama-stack-config`**
  (no baseConfig, no inline providers); `genai-pgvector`, `milvus-standalone`, `llamastack-postgres`, `bge-m3` all 1/1;
  DSPA Ready on **`seaweedfs-s3.autorag-demo.svc.cluster.local:8333`**; secret `autorag-ogx-connection` present.
- OGX API from inside the pod: `/v1/health` OK; models: Qwen3-8B (provider `maas-vllm-inference-1`, base_url
  `https://qwen3-8b-kserve-workload-svc.llm.svc.cluster.local:8000/v1`), granite-embedding-125m, nomic-embed-text-v1.5,
  Qwen3-Reranker-0.6B; no vector stores yet.
- `/v1/chat/completions` returns 500 *right now*: its GPU node restarted at 04:49 UTC and the old `qwen3-8b` /
  `qwen3-8b-eval` pods sit in `ContainerStatusUnknown` holding the single GPU, so the new pods are Pending
  ("8 Insufficient nvidia.com/gpu"). Config is good; the restart left stale pods.
- Broken 3.5 cluster vs reference: OGXServer still `rh` + `baseConfig` + inline providers (created 2026-09-21, pre-fix),
  and its `llama-stack-config` has `base_url: https://maas.apps.ocp.5msvc.sandbox5559.opentlc.com/v1`, the
  **reference cluster's** MaaS URL (copied across clusters). Current `deploy.sh` skips an existing config, so a plain
  redeploy would keep the wrong URL.

## Phase 1 — Toolkit fixes (repo)

| # | Change | Files | Verify |
|---|---|---|---|
| 1.1 | DSPA object storage templated from the active backend (`S3_HOST`, `S3_PORT`, `S3_SCHEME` from `get_storage_endpoint`) and a backend-neutral credentials secret `pipelines-s3-credentials` (`S3_ACCESS_KEY`/`S3_SECRET_KEY`, defaults admin/admin123), same as `lib/functions/pipeline-server.sh` | `demo/automl-demo/manifests/pipeline-server.yaml`, `demo/autorag-demo/manifests/pipeline-server.yaml`, both `deploy.sh` | envsubst render + `oc apply --dry-run=server` |
| 1.2 | Stop using `quay.io/minio/minio` (anonymous pulls now `unauthorized`; docker.io gone too). MinIO paths use the only pullable build `quay.io/opendatahub/minio:RELEASE.2019-08-14T20-37-41Z-license-compliance` (args adjusted for that version) with a warning recommending SeaweedFS | 7 manifests listed in the report; `lib/functions/storage-backend.sh` minio branch | `oc image info`; render + dry-run |
| 1.3 | n8n: reuse `N8N_ENCRYPTION_KEY` from the existing `n8n-secret` instead of generating a new one per run | `demo/n8n-demo/deploy.sh` | bash -n; logic test |
| 1.4 | MCP Lifecycle Operator: `Removed` in the 3.5 DSC manifest; `install-rhoai-35.sh` sets `Managed` only on OCP ≥ 4.22 (docs: Working with the MCP catalog §2.3) | `lib/manifests/rhoai/datasciencecluster-v3-35.yaml`, `scripts/install-rhoai-35.sh` | dry-run; toolkit-ops check |
| 1.5 | autorag 3.5 path: always run `_patch_ogx_config_vllm_url` (idempotent) even when the config exists; recreate the OGXServer when it still uses `baseConfig`; fix top-level `local` (line 356) | `demo/autorag-demo/deploy.sh` | bash -n; run on 3.5 cluster |
| 1.6 | `NAMESPACE="${1:-…}"` flag-parsing bug: default the namespace, let `-n` override | 8 demo `deploy.sh` | `bash -n`; `--delete` parse test |
| 1.7 | `manage-gpu-nodes.sh start`: after nodes are Ready, delete pods left in `ContainerStatusUnknown`/`Unknown` on those nodes so GPUs are released | `scripts/manage-gpu-nodes.sh` | run on 3.4 cluster |
| 1.8 | toolkit-ops: flag stale pods holding GPUs; update `reference/demo-checks.md` | `.claude/skills/toolkit-ops/` | `tests/run-tests.sh` |
| 1.9 | Docs: compat tracker rows (MinIO image, MCP LCO, Kueue wording), TROUBLESHOOTING entries | `docs/COMPATIBILITY-TRACKER.md`, `docs/TROUBLESHOOTING.md` | review diff |

## Phase 2 — 3.4 cluster (cluster-9tjvr, RHOAI 3.4.6)

1. Start the 5 stopped GPU instances: `scripts/manage-gpu-nodes.sh start` (local AWS creds belong to this account),
   approve CSRs, clean stale pods (1.7), wait for `nvidia.com/gpu` allocatable.
2. Move automl-demo, autorag-demo, pipeline-demo pipeline storage to SeaweedFS: re-run the fixed deploy scripts with
   `-n` (pipeline-demo: SeaweedFS backend via `setup_pipeline_server`), then remove the dead MinIO deployments.
3. `scripts/diagnose-maas.sh --fix` (payload-processing 1Gi, AUTH_SERVICE_TIMEOUT=2s).
4. NFD/OpenTelemetry stuck upgrades: re-check after nodes are back; if the new CSV is still Pending, delete the old
   `Replacing` CSV so OLM hands over CRD ownership.
5. Re-inject notebook env (pipeline-demo S3 keys, maas-ratelimit MODEL_ID/MAAS_ROUTING) and restart those workbenches.
6. Re-run `/toolkit-ops verify`.

## Phase 3 — 3.5 cluster (ocp.sclg6, RHOAI 3.5.1)

1. GPU nodes (7 stopped; local AWS creds are a different account): see decision below. Then clean stale pods.
2. `mcplifecycleoperator: Removed` (OCP 4.21).
3. autorag: start `bge-m3` (remove `serving.kserve.io/stop`), re-run fixed `demo/autorag-demo/deploy.sh -n autorag-demo`
   (re-points config to the in-cluster vLLM, recreates OGXServer as `rh-dev` + `overrideConfig`, creates genai-pgvector
   + connection secret, DSPA on SeaweedFS). Validate like the reference: health, models, a chat completion.
4. automl: re-run fixed `demo/automl-demo/deploy.sh -n automl-demo` (DSPA on SeaweedFS).
5. n8n: read the original key from the PVC (`/home/node/.n8n/config` via `oc debug`), put it in `n8n-secret`, restart.
6. `scripts/diagnose-maas.sh --fix` after models are up (stale WASM auth cache → gateway restart).
7. Re-run `/toolkit-ops verify`; update the report.

## Status (2026-11-10, end of day)

Phases 1-3 executed. Results and remaining items: `docs/test-reports/toolkit-ops-2026-11-10.md` "After the fixes".

## Decisions taken

- 3.5 GPU nodes: replace the stopped Machines (MachineSet creates new instances with in-cluster credentials; ~15 min
  for GPU drivers), or extract the Machine API credentials to start the existing instances.
- Reference cluster: also clear its stale GPU pods so its autorag LLM works again (optional; not requested).
