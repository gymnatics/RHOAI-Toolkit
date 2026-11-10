# AutoRAG / OGX on RHOAI 3.5 — Failure Cascade and Workarounds

**Status**: Workarounds applied in toolkit; upstream [RHOAIENG-96724](https://redhat.atlassian.net/browse/RHOAIENG-96724) still open (re-test 3.5.2+)

**Component**: OGX Operator + AutoRAG (TP) pipeline

**Affected**: RHOAI 3.5.0, 3.5.1 (confirmed)

**Clusters**: cluster-sclg6 (OCP 4.21.31), Singtel 5msvc sandbox

**Demo**: `demo/autorag-demo/`

**Commits**: `392a059`, `0ac7211`, `df8b5b4`, `d31ca81`

---

Infra from `deploy.sh` (S3/SeaweedFS, Milvus, DSPA, bge-m3) works independently. Failures are in OGX orchestration and then AutoRAG pipeline search-space prep. Issues below are listed in the order hit during bring-up.

## Cascade

| # | Failure | Fix in toolkit |
|---|---|---|
| 1 | OCI label fetch HTTP 401 (RHOAIENG-96724) | Bypass via config ConfigMap; full path uses `overrideConfig` (Issue 4) |
| 2 | Secret/ConfigMap "not found" despite existing | Label with `ogx.io/watch=true` (`392a059`) |
| 3 | Empty `VLLM_*_API_TOKEN` → EnvVarError | Literal `unused` (`0ac7211`) |
| 4 | CRD config merge strips runtime fields | `overrideConfig` + `rh-dev`, no CRD providers (`df8b5b4`) |
| 5 | search-space-preparation (nomic offline) | Strip nomic; use remote bge-m3 (`deploy.sh` patches) |
| 6 | OGXServer applied to `default` on re-run | Unconditional `export NAMESPACE` (`d31ca81`) |

### Issue 1 — OCI label fetch HTTP 401 (RHOAIENG-96724)

**Symptom:** OGXServer `Phase: Failed`, `ConfigGenerationFailed`, HTTP 401 fetching `registry.redhat.io/rhoai/odh-ogx-core-rhel9@sha256:...` labels.

**Root cause:** Operator's in-process OCI-label client is anonymous; kubelet pull of the same digest works.

**Deep dive:** [BUG-REPORT-OGX-REGISTRY-AUTH-401.md](../reference/BUG-REPORT-OGX-REGISTRY-AUTH-401.md)

**Early workaround (insufficient alone):** `spec.baseConfig` ConfigMap from extracted `com.ogx.config.config.yaml` label. Gets past ConfigGenerationFailed but leads into Issues 2–5.

### Issue 2 — Secret/ConfigMap not found despite existing

**Symptom:** "Secret not found" for secrets that exist and RBAC allows.

**Root cause:** Operator namespace-scoped informer only watches resources with `ogx.io/watch=true`.

**Fix:** Label Secrets/ConfigMaps referenced by OGXServer with `ogx.io/watch=true`.

**Commit:** `392a059`

### Issue 3 — Empty VLLM_API_TOKEN / VLLM_EMBEDDING_API_TOKEN → EnvVarError

**Symptom:** OGX pod CrashLoopBackOff with EnvVarError on empty-string env vars.

**Fix:** Set tokens to literal `unused` (internal endpoints need no auth).

**Commit:** `0ac7211`; see `demo/autorag-demo/manifests/ogxserver.yaml` `VLLM_API_TOKEN_1`.

### Issue 4 — CRD config merge strips runtime-required fields → CrashLoopBackOff

**Symptom:** After baseConfig succeeds, pod still CrashLoopBackOff; pydantic `MilvusVectorIOConfig` missing `token` (string) and `persistence.backend` — operator CRD providers/baseConfig path strips them.

**Fix (current toolkit path):**
- Use `spec.overrideConfig` pointing at `llama-stack-config` ConfigMap + `distribution.name: rh-dev`
- NO providers in CRD spec
- Inject `PGVECTOR_*` / `VLLM_*` via `workload.overrides.env`
- Copy working config from `ai-studio-demo` (or extract OCI labels as fallback)
- Deploy pgvector for vector_io backend

Do **not** use `rh` + baseConfig + CRD providers — that re-enters the broken merge path.

**Commit:** `df8b5b4` — verified `autorag-ogx` Phase Ready on Singtel 5msvc.

**Manifest:** `demo/autorag-demo/manifests/ogxserver.yaml`

### Issue 5 — AutoRAG pipeline fails at search-space-preparation (nomic offline)

**Symptom:** Optimization run fails during search-space-preparation.

**Root cause:** Base `llama-stack-config` registers `nomic-ai/nomic-embed-text` / nomic-embed-text-v1.5; OGX runs with `HF_HUB_OFFLINE=1` so the model cannot download; AutoRAG still offers it as an embedding option.

**Fix:** `_patch_ogx_config_remove_offline_models` in `demo/autorag-demo/deploy.sh` strips nomic from registered models; use remote CPU `bge-m3` InferenceService + pre-cached granite embedding if present.

**Related:** Also patch copied config so vLLM `base_url` uses the internal service URL, not the MaaS external route (MaaS needs a bearer token OGX cannot supply via env-var substitution) — `_patch_ogx_config_vllm_url`.

### Issue 6 — deploy.sh NAMESPACE not exported on idempotent re-run

**Symptom:** OGXServer silently applied to `default` namespace on re-run when earlier resources already exist.

**Fix:** Unconditional `export NAMESPACE` at top of deploy path.

**Commit:** `d31ca81` (2026-09-21)

---

## Current toolkit behaviour

`demo/autorag-demo/deploy.sh` on RHOAI 3.5+ (`USE_OGX=true`) applies the full stack automatically: copy/extract llama-stack-config, strip nomic, patch vLLM URL, deploy pgvector, apply overrideConfig OGXServer, create `autorag-ogx-connection` secret.

**Verify:**

```bash
oc get ogxserver autorag-ogx -n autorag-demo   # Phase Ready
```

Then dashboard: Develop and train > AutoRAG.

## What still works without OGX Ready

Milvus, bge-m3, S3 docs bucket, DSPA pipeline server — useful for narrated fallback demos.

## Open / re-test

- RHOAIENG-96724 on 3.5.2+
- Whether `rh` + fixed operator can replace the `overrideConfig` / `rh-dev` path

## Links

- [BUG-REPORT-OGX-REGISTRY-AUTH-401.md](../reference/BUG-REPORT-OGX-REGISTRY-AUTH-401.md) — Issue 1 deep dive
- [COMPATIBILITY-TRACKER.md](../COMPATIBILITY-TRACKER.md) TRK-004
- `SINGTEL-DEMO-PLAN.md` Phase 3.5
- [demo/autorag-demo/README.md](../../demo/autorag-demo/README.md)
