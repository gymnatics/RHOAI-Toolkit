<!-- Last reviewed: 2026-10-23 -->
<!-- Maintained by: compat-tracker skill (.claude/skills/compat-tracker/SKILL.md) -->
<!-- Baseline commit: 4de6f4a (plus uncommitted working-tree changes as of review date) -->

# RHOAI Toolkit Compatibility Tracker

Tracks where the toolkit diverges from official Red Hat / upstream state: what works,
what is broken or mislabelled now, and what will break on a known future date or release.

**Verification tags** -- every fact cites one:
- `[live]` confirmed on a running cluster (note cluster + date)
- `[src]` read from upstream source code / raw catalog / lifecycle API
- `[RN]` official release notes or product docs (docs.redhat.com)
- `[repo]` read from this repo's code
- `[unverified]` plausible but not confirmed -- re-check before acting

**Severity**: `High` blocks install/demo or is a support risk to customers · `Medium` wrong behaviour in an edge path or mislabelled support tier · `Low` hygiene / doc drift.

**Status**: `Open` · `Monitoring` (workaround in place, waiting on upstream) · `Future` (not broken yet; dated trigger) · `Resolved` (moved to Resolved log).

---

## 1. Platform Snapshot (as of last review)

| Item | Value | Tag |
|---|---|---|
| Latest GA | RHOAI 3.5.2 (3.5 GA 2026-08-27, EUS release) | [src] lifecycle API, catalog |
| Next release | RHOAI 3.6 -- EA only (`beta` channel `3.6.0-ea.2`), no docs | [src] catalog |
| 3.5 full support ends | 2027-03-27 (SupportedConfigs) / 2027-03-29 (API); EUS to 2028-02-28 | [src] |
| 3.4 full support ends | **2026-11-16** | [src] |
| 3.3 | **EOL 2026-10-05** | [src] |
| Default operator channel | `stable-3.x` (→3.5.2). `fast-3.x` frozen at 3.3.1 | [src] catalog |
| OCP support | 3.4/3.5: 4.19.9+–4.22; llm-d needs 4.20+ | [src] SupportedConfigs |
| RHCL | 3.5 docs: 1.4.x; latest 1.4.4; 1.5 exists but not referenced by RHOAI | [RN] |
| Upstream heads | llm-d 1.0.0, KServe 0.21.0, OGX 1.5.0, ogx-k8s-operator 0.17.0, Kuadrant 1.6.0 | [src] |

---

## 2. Open Items

| ID | Sev | Status | Area | Finding | Files | Source | Opened |
|---|---|---|---|---|---|---|---|
| TRK-001 | Medium | Open | Dashboard flags | Developer Preview flags `agentsCatalog`, `agentConfigManagement` are enabled under the "Technology Preview" label and on by default in the full/patch dashboard configs. DP = no Red Hat support. Also `gpuaas` already defaults `true` (GA group) so setting it is a no-op. | `lib/functions/rhoai.sh:1405` (uncommitted), `lib/manifests/rhoai/odh-dashboard-config-full.yaml`, `odh-dashboard-config-patch.yaml`, `scripts/enable-dashboard-features.sh` | [RN] 3.5 RN ch.4; [src] odh-dashboard `rhoai-3.5` `frontend/src/concepts/areas/const.ts` | 2026-10-23 |
| TRK-002 | Medium | Open | Install | Channel fallback when packagemanifest lookup fails is `fast-3.x`, which is frozen at 3.3.1 -- a "3.5 install" would install 3.3. Should fall back to `stable-3.5` / `stable-3.4`. | `scripts/install-rhoai-35.sh:171,185`, `scripts/install-rhoai-34.sh:152,166` | [src] catalog; [repo] | 2026-10-23 |
| TRK-003 | Medium | Monitoring | MaaS / RHCL | Toolkit requires RHCL ≥1.4.1 for 3.5, but RHOAIENG-76586: RHCL 1.4.x silently breaks rate limiting + gateway OOM. Workaround: stay on 1.3.5 or 2Gi gateway memory + identity filter on AuthPolicy. `diagnose-maas.sh` Issue 6 detects. 3.4 docs say RHCL 1.3.x (toolkit says 1.2+). | `scripts/setup-maas.sh`, `scripts/diagnose-maas.sh:188`, `lib/manifests/rhcl/operator/` | [RN] 3.5 known issues | 2026-10-23 |
| TRK-004 | High | Monitoring | OGX / AutoRAG | RHOAIENG-96724 + AutoRAG cascade on 3.5.0/3.5.1: OCI label 401 → `ogx.io/watch` Secret miss → empty `VLLM_*_API_TOKEN` EnvVarError → CRD merge strips Milvus fields (need `overrideConfig` + `rh-dev`) → nomic search-space failure under `HF_HUB_OFFLINE=1`. Workarounds in autorag-demo (`392a059`, `0ac7211`, `df8b5b4`, `d31ca81`). Re-test 3.5.2+. | `demo/autorag-demo/deploy.sh`, `demo/autorag-demo/manifests/ogxserver.yaml` | [live] cluster-sclg6 / Singtel 5msvc; `docs/bugs/autorag-ogx-3.5-cascade.md`; `docs/reference/BUG-REPORT-OGX-REGISTRY-AUTH-401.md` | 2026-10-15 |
| TRK-005 | Medium | Open | Operators | Kueue Subscription pinned `stable-v1.3` (required: Kueue 1.4+ breaks Trainer v2, RHOAIENG-87625/87965), but Kueue 1.3 is **not available on OCP 4.22** -- install likely fails on 4.22 clusters. | `lib/manifests/operators/kueue-subscription.yaml:7` | [RN] known issues; [unverified] live on 4.22 | 2026-10-23 |
| TRK-006 | Low | Open | Workbench | Stale default image tags may not exist on 3.5 clusters: `s2i-generic-data-science-notebook:3.4`, `jupyter-datascience-notebook:2024.2`. | `lib/functions/workbench.sh:40,244`, `lib/manifests/demo/financial-loan-workbench.yaml:25`, `lib/manifests/demo/pipeline-workbench.yaml:25` | [repo]; [unverified] live tags | 2026-10-23 |
| TRK-007 | Medium | Open | Deprecated (3.5) | Toolkit still deploys features deprecated in 3.5: FMS `GuardrailsOrchestrator` (→ NeMo Guardrails), `LMEvalJob` (→ EvalHub), `opendatahub.io/connection-type-ref` annotation (→ `connection-type-protocol`), ModelMesh in older DSC templates. Fine on 3.5; flag to customers; plan removal paths. | `scripts/deploy-guardrails.sh`, `lib/manifests/guardrails/orchestrator-cr.yaml`, `demo/lemonade-trustyai-demo/`, `demo/lmeval-demo/`, `lib/manifests/model-deployment/model-storage-secret*.yaml.tmpl` | [RN] 3.5 ch.5 | 2026-10-23 |
| TRK-008 | Low | Open | Docs | Official sources disagree on 3.5 support tiers -- EvalHub (RN: GA, SupportedConfigs: TP 0.3.0), Feast (SupportedConfigs GA, RN TP chapter lists it), KubeRay (RN 1.6.x vs SupportedConfigs 1.4.2). Toolkit docs/rules call EvalHub GA. Use the conservative tier with customers. | `.cursor/rules/rhoai-versions.mdc`, `docs/guides/rhoai-3.5/RHOAI-35-WHATS-NEW.md` | [RN] vs [src] SupportedConfigs | 2026-10-23 |
| TRK-010 | High | Open | Docs / Install | 3.5 manual guide tells users to `export RHOAI_CHANNEL="fast-3.x"` and lists it as "latest features" -- `fast-3.x` is frozen at 3.3.1, so following the guide installs 3.3. Use `stable-3.5` (or `stable-3.x` / `eus-3.5`). | `docs/guides/rhoai-3.5/RHOAI-35-MANUAL-INSTALLATION-GUIDE.md:230-248` (likely same in 3.4 guide) | [src] catalog | 2026-10-23 |
| TRK-011 | Medium | Open | Model serving | Stale vLLM images: manual guide §8A.3 uses `quay.io/modh/vllm:rhoai-2.22` (RHOAI 2.22 era); `servingruntime-vllm-redhat.yaml.tmpl` pins `registry.redhat.io/rhaiis/vllm-cuda-rhel9:3.3` while RHOAI 3.5 ships Red Hat AI Inference 3.5.0. Prefer the platform's built-in vLLM ServingRuntime template. Model-car OCI refs pinned at `registry.redhat.io/rhelai1/modelcar-*:1.5`; Red Hat AI 3 validated models now publish at **`registry.redhat.io/rhai/modelcar-<model>:3.0`** (e.g. `modelcar-openai-whisper-large-v3:3.0`, `modelcar-redhatai-gemma-3-12b-it:3.0`) per `docs/reference/RHAIE 3.5 Guide/Red_Hat_AI-3-Validated_models-en-US.pdf.md`; some entries still list `rhelai1/...:1.5`. | `docs/guides/rhoai-3.5/RHOAI-35-MANUAL-INSTALLATION-GUIDE.md` §8A.3, `lib/manifests/model-deployment/servingruntime-vllm-redhat.yaml.tmpl:31`, `lib/manifests/maas/models/*/llm/` | [repo]; [src] SupportedConfigs (RHAIIS 3.5.0); [unverified] newest modelcar tags | 2026-10-23 |
| TRK-012 | Low | Open | Storage | SeaweedFS image is the official one (`docker.io/chrislusf/seaweedfs`, mirrored at `ghcr.io/chrislusf/seaweedfs`) but unpinned `:latest` -- non-reproducible and subject to Docker Hub anonymous rate limits. Pin a release tag (4.49 as of 2026-10-23) or digest; cosign-signed since Sep 2026. Same `:latest` pattern on `quay.io/minio/minio`, `quay.io/minio/mc`, `docker.io/amazon/aws-cli`. | `lib/manifests/storage/seaweedfs/seaweedfs-deployment.yaml:39`, `lib/manifests/storage/minio/`, `lib/functions/storage-backend.sh` (aws-cli `oc run`) | [src] github.com/seaweedfs/seaweedfs `docker/README.md`, Helm `values.yaml` | 2026-10-23 |
| TRK-013 | Low | Open | Docs | Long-form 3.5 manual guide §10B.4 references `lib/manifests/maas/postgres-{pvc,service,deployment}.yaml`, but the files live in `lib/manifests/maas/platform/`. Also, the guide (and gateway templates) define `CLUSTER_DOMAIN` *without* `apps.`, while other docs use the full ingress domain. The standalone setup doc now uses `APPS_DOMAIN` + `CLUSTER_DOMAIN` explicitly. | `docs/guides/rhoai-3.5/RHOAI-35-MANUAL-INSTALLATION-GUIDE.md:1562-1567` | [repo] | 2026-10-23 |
| TRK-009 | Low | Open | Lifecycle | `install-rhoai-33.sh` / 3.3 menu paths still offered though 3.3 is EOL. Mark EOL in help text and menus. | `scripts/install-rhoai-33.sh`, `lib/menus/install.sh` | [src] lifecycle API | 2026-10-23 |
| TRK-014 | Medium | Open | Kueue | `TOOLKIT-CONTEXT.md` says Kueue `Managed` is "rejected" in 3.5; docs (Managing OpenShift AI 3.5 ch.8 "Manage workloads with Kueue", lastModified 2026-11-06) say `Managed` is deprecated and, if the Red Hat build of Kueue Operator is also installed, OpenShift AI stops reconciliation. Also: in namespaces labelled `kueue.openshift.io/managed=true`, hardware profiles cannot use node selectors or tolerations (toolkit gpu-profile uses tolerations). | `TOOLKIT-CONTEXT.md`, `lib/manifests/rhoai/hardware-profile-gpu.yaml`, `lib/manifests/templates/hardwareprofile-gpu.yaml.tmpl` | [RN] Managing OpenShift AI 3.5 ch.8, lastModified 2026-11-06 | 2026-11-10 |
| TRK-015 | High | Open | Model serving / GPU | `LLMInferenceService`/`InferenceService` templates have no GPU-architecture node affinity: on a cluster with both T4 (g4dn, compute 7.5) and L40S (g6e, 8.9) nodes, an FP8 Qwen3-8B (`modelcar-qwen3-8b-fp8-dynamic`) landed on a T4 and crash-looped ("FA2 is only supported on devices with compute capability >= 8"; EngineCore failed). Proposed: `nodeAffinity` `nvidia.com/gpu.compute.major` `Gt 7` for FP8 models. | `lib/manifests/maas/models/qwen3-8b/llm/model.yaml`, `lib/manifests/model-deployment/llminferenceservice.yaml.tmpl`, `lib/manifests/templates/llminferenceservice.yaml.tmpl` | [live] 2026-11-10 | 2026-11-10 |

---
| TRK-016 | High | Open | EvalHub / MLflow | RHOAIENG-67534 hit on 3.5.1 although the MLflow CR predates EvalHub: every job submission fails with MLflow "Workspace context is required"; pod restart doesn't help; workaround is recreating the EvalHub CR. Toolkit now creates MLflow before EvalHub; existing clusters need the recreate. Docs (Evaluating AI systems 3.5 §2.3/§2.28, lastModified 2026-11-06) also advise a dedicated EvalHub namespace instead of `redhat-ods-applications` (toolkit uses the latter). | `demo/lmeval-demo/deploy.sh`, `demo/lmeval-demo/manifests/evalhub.yaml` |
| TRK-017 | Medium | Monitoring | EvalHub | The EvalHub `lm_evaluation_harness` provider on RHOAI 3.5.1 lists 188 benchmarks but has no plain `mmlu` id; job submission returns HTTP 400 `resource_does_not_exist` for it. Use a benchmark id that is actually listed (e.g. `arc_easy`). Separately, eval-hub-sdk 0.4's `client.health()` returns a plain dict (`{"status": "healthy", ...}`), not an object with a `.status` attribute. Status: toolkit adapted (`evalhub-sdk-demo.ipynb` now lists benchmarks and checks one exists before submitting, and reads the health dict directly). | `demo/lmeval-demo/evalhub-sdk-demo.ipynb` | [live] cluster c35, 2026-11-11 | 2026-11-11 |

## 3. Future Breakage (dated / release-triggered)

| ID | Sev | Trigger | What breaks | Toolkit touchpoints | Source |
|---|---|---|---|---|---|
| TRK-101 | Medium | **2026-11-16** 3.4 full support ends | 3.4 install path becomes unsupported-for-new-installs; `install-rhoai-34.sh` should be marked legacy, defaults should point to 3.5 | `scripts/install-rhoai-34.sh`, menus, Makefile `setup-rhoai-34` | [src] lifecycle API |
| TRK-102 | High | **RHOAI 3.6 GA** (est. Nov–Dec 2026, [unverified]) | DSC **v3** storage version, **DSC v1 dropped**; v3 removes `modelregistry`, `trainingoperator`, `feastoperator`, `llamastackoperator`; adds `aiHub`, `data`, `databaseservice`. No `install-rhoai-36.sh`, no `is_rhoai_36_or_higher`, no `datasciencecluster-v3-36.yaml`. | `lib/manifests/rhoai/datasciencecluster-*.yaml`, `lib/utils/rhoai-version.sh`, `lib/functions/model-registry.sh`, `lib/functions/feast.sh`, `lib/functions/llamastack.sh` | [src] rhods-operator `rhoai-3.6` `api/datasciencecluster/` |
| TRK-103 | Medium | RHOAI 3.6 GA | Dashboard flags: `externalModels` removed; `toolCalling` default true→false; `genAiStudio`, `promptManagement`, `automl`, `autorag` become GA default-true (setting harmless). New TP: `skillRegistry`, `genAiImageUpload`, `genAiAudioUpload`, `genAiAgentDeployment`, `modelCapabilities`, `inferencePriorityField`, `dataRegistry`, `dataConnectHub`. `agentsCatalog`/`mcpCatalog` depend on `modelregistry` -- check how that maps to `aiHub`. | `lib/manifests/rhoai/odh-dashboard-config-*.yaml`, `lib/functions/rhoai.sh` `enable_tp_features_interactive` | [src] odh-dashboard `rhoai-3.6` |
| TRK-104 | Medium | ~3.6 (removal of deprecated kserve field) | `kserve.modelsAsService` "preserved at least through 3.6"; `Tenant` CRD deprecated; `LlamaStackDistribution` back-compat only. 3.4-era code paths that write these will stop working. | `scripts/setup-maas.sh` (3.4 branch), `lib/functions/llamastack.sh`, `scripts/add-model-to-playground.sh`, `lib/manifests/workshop/workshop-llamastack.yaml` | [src] `kserve_types.go`, `aigateway_types.go` rhoai-3.5 |
| TRK-105 | Medium | **2027-03-27** 3.5 full support ends | OGX + Kubeflow Training Operator v1 excluded from 3.5 EUS -- OGX users must move to 3.6+. AutoRAG demo on 3.5 becomes unsupported. | `demo/autorag-demo/`, `lib/functions/llamastack.sh`, DSC `trainingoperator` | [src] SupportedConfigs |
| TRK-106 | Low | Future (unscheduled) | KServe Serverless + ModelMesh deprecated in 3.5 -- removal expected. | `lib/manifests/rhoai/datasciencecluster-v1.yaml`, `-v2-32.yaml`, `lib/manifests/rhoai-minimal/`, `lib/menus/install.sh` | [RN] 3.5 ch.5 |
| TRK-107 | Medium | OGXServer distribution "rh-dev" removal (unscheduled z-stream) | `OGXServer` `spec.distribution.name` `rh-dev` now returns the API warning `spec.distribution.name "rh-dev" is deprecated, use "rh" instead` (seen on RHOAI 3.5.1, 2026-11-10). The toolkit's working autorag fix depends on `rh-dev` + `overrideConfig` (`rh` + `baseConfig` hits the `MilvusVectorIOConfig` validation bug, TRK-004). Re-test with `rh` + `overrideConfig` on the next z-stream before `rh-dev` is removed. | `demo/autorag-demo/deploy.sh`, `demo/autorag-demo/manifests/ogxserver.yaml` | [live] 2026-11-10 |

---

## 4. Verified Working

| Area | What | Version | Tag |
|---|---|---|---|
| Full install | `install-rhoai-35.sh` end-to-end incl. auto GPU MachineSet, MaaS, MLflow, observability, Grafana | 3.5.0 on OCP 4.21.31 (opentlc) | [live] `docs/TODO-e2e-install-test.md` |
| MaaS routing | Per-model URL routing (bare `spec.model.name`) and body-based routing (full id from `/v1/models`) both HTTP 200 | 3.5.0 GA, 2026-09-10 | [live] |
| MaaS auth | API-key auth after Authorino `SSL_CERT_FILE` fix (RHOAIENG-96854) | 3.5 | [live] commit cbeb018 |
| MaaS hardening | `AUTH_SERVICE_TIMEOUT=2s` (RHOAIENG-71638), `maas-gateway-access` label (RHOAIENG-83207) applied/checked | 3.5 | [repo] `setup-maas.sh`, `diagnose-maas.sh` |
| MCP | `MCPServer` CRs via MCP Lifecycle Operator appear in AI Asset Endpoints | 3.5 | [live] commits 4a9fbcf, 4de6f4a |
| Observability | Perses dashboard after StatefulSet `instance` label patch | 3.5 | [live] commit d16a18d |
| Playground | Qwen3-8B chat in GenAI Playground | 3.5 | [live] `playground-qwen3-8b-chat-verified.png` |

---

## 5. Support-Tier Usage Map (toolkit features → official tier)

Which toolkit-enabled features rely on TP / DP. Update when tiers change.

| Toolkit feature | How enabled | 3.4 | 3.5 | 3.6 (EA) |
|---|---|---|---|---|
| MaaS core | DSC `aigateway.modelsAsAService` (3.5) / `kserve.modelsAsService` (3.4) | GA | GA | GA |
| MaaS multi-tenancy (`AITenant`) | `setup-maas-oidc.sh` | -- | TP | ? |
| vLLM on MaaS | flag `vLLMDeploymentOnMaaS` | TP | TP | ? |
| External models / egress | `deploy-external-model.sh`, flag `externalModels` | TP | TP | flag removed |
| MaaS observability / usage logging | `--enable-observability`, `--enable-usage-logging` | TP | TP (Loki showback TP) | ? |
| llm-d | `LLMInferenceService` | GA | GA | GA |
| llm-d flow control | -- | TP | GA | -- |
| OGX / Llama Stack | DSC `ogx` / `llamastackoperator` | TP | GA (not in EUS) | GA |
| AutoML / AutoRAG | flags `automl`, `autorag`; demos | TP | TP | GA (flags) [src] |
| NeMo Guardrails | `deploy-nemo-guardrails.sh` | GA | GA | -- |
| FMS Guardrails Orchestrator | `deploy-guardrails.sh` | GA | **Deprecated** | ? |
| LM-Eval (`LMEvalJob`) | `lmeval-demo` | GA | **Deprecated** | ? |
| EvalHub | `lmeval-demo` | TP | TP/GA (conflict, TRK-008) | ? |
| MCP Lifecycle Operator | DSC `mcplifecycleoperator` | DP (manual) | TP | ? |
| MCP Catalog | flag `mcpCatalog` | DP | TP | ? |
| Agent Catalog | flag `agentsCatalog` | -- | **DP** | DP |
| Saved Playground agents | flag `agentConfigManagement` | -- | **DP** | ? |
| Agent Ops | flag `agentOps` | -- | TP (undocumented) | TP |
| GPU-as-a-Service page | flag `gpuaas` (default true) | -- | GA | GA |
| Feature Store | DSC `feastoperator` | GA/TP | GA/TP (conflict) | removed from DSC v3 |
| Spark Operator | DSC `sparkoperator` | DP→TP | GA | GA |
| Prompt management | flag `promptManagement` | TP | TP | GA |

---

## 6. Resolved Log

| ID | Resolved | How | Commit |
|---|---|---|---|
| -- | 2026-11-10 | AutoRAG/AutoML dashboard rejects plain-HTTP S3 connections ("S3 Connection must use HTTPS"); data connections now use the backend HTTPS Route via `get_storage_external_endpoint` (`lib/functions/storage-backend.sh`) in `demo/{autorag,automl}-demo/deploy.sh` | uncommitted |
| -- | 2026-10-15 | Authorino `SSL_CERT_FILE` wrong path from Red Hat doc (RHOAIENG-96854) | cbeb018 |
| -- | 2026-10-16 | Perses Service selector mismatch | d16a18d |
| -- | 2026-11-10 | MCP Lifecycle Operator enabled on OCP < 4.22 (docs "Working with the MCP catalog" 3.5 §2.3, lastModified 2026-08-26, require OpenShift 4.22+ and default the component to Removed as Technology Preview). `lib/manifests/rhoai/datasciencecluster-v3-35.yaml` now sets `mcplifecycleoperator` `Removed`; `scripts/install-rhoai-35.sh` `install_mcp_lifecycle_operator()` sets `Managed` only on OCP >= 4.22 and `Removed` otherwise | uncommitted |
| -- | 2026-11-10 | `quay.io/minio/minio` (all tags) and `docker.io/minio/minio` no longer anonymously pullable ("unauthorized", seen 2026-11-10); demo MinIO pods went `ImagePullBackOff` and DSPAs failed. 7 MinIO manifests now use `quay.io/opendatahub/minio:RELEASE.2019-08-14T20-37-41Z-license-compliance` (the image RHOAI's DSPA-managed MinIO uses; args `server /data`, `MINIO_ACCESS_KEY`/`MINIO_SECRET_KEY`, no console port); SeaweedFS remains the default and recommended backend | uncommitted |
| -- | 2026-11-10 | automl-demo and autorag-demo DSPA manifests hard-coded `minio.<ns>.svc:9000` + `minio-secret` even when SeaweedFS was deployed. `demo/{automl,autorag}-demo/manifests/pipeline-server.yaml` now render host/port/scheme from `get_storage_endpoint` and use a `pipelines-s3-credentials` secret; `deploy.sh` re-points an existing DSPA | uncommitted |
| -- | 2026-11-10 | `lib/functions/pipeline-server.sh` skipped an existing `pipelines-s3-credentials` secret, so after a MinIO→SeaweedFS switch the DSPA failed with "The access key ID you provided does not exist". Now always re-applies credentials when known | uncommitted |
| -- | 2026-11-10 | autorag OGX regression: commit `df8b5b4` (`overrideConfig`) dropped the `ogx.io/watch=true` label on `llama-stack-config` added in `392a059`; `OGXServer` then failed with "failed to find referenced ConfigMap autorag-demo/llama-stack-config". Also `deploy.sh` skipped patching an existing `llama-stack-config` (a config copied from another cluster kept that cluster's MaaS `base_url`), never migrated a pre-fix `OGXServer` (`rh` + `baseConfig`), and used `local` at top level. `demo/autorag-demo/deploy.sh` now labels the ConfigMap after patches, always re-applies endpoint patches, recreates an `OGXServer` that still has `baseConfig`, removed the top-level `local`, and reuses the existing `genai-pgvector` password on re-run | uncommitted |
| -- | 2026-11-10 | n8n-demo regenerated `N8N_ENCRYPTION_KEY` on every run ("Mismatching encryption keys" CrashLoop). Now reuses the key from the existing `n8n-secret` | uncommitted |
| -- | 2026-11-10 | Eight demo `deploy.sh` scripts set `NAMESPACE="${1:-default}"` so `./deploy.sh --delete` used the namespace "--delete". Now only a non-flag first argument is treated as a namespace | uncommitted |

---

## 7. Review Log

| Date | Reviewer | Scope | Baseline | Notes |
|---|---|---|---|---|
| 2026-11-10 | /toolkit-ops | Live verification of RHOAI 3.5.1 (OCP 4.21) and 3.4.6 (OCP 4.20) clusters | — | See `docs/test-reports/toolkit-ops-2026-11-10.md` and `docs/test-reports/toolkit-ops-2026-11-10-fix-plan.md`. |
| 2026-11-04 | sonnet-scribe | single item TRK-004 / AutoRAG cascade docs | — | Expanded TRK-004 Finding for full cascade; linked `docs/bugs/autorag-ogx-3.5-cascade.md` + 401 bug report. Status remains Monitoring. |
| 2026-10-23 | compat-tracker (initial) | Full: repo + 3.3/3.4/3.5 RN (TP/DP chapters) + SupportedConfigs + lifecycle API + rhods-operator/odh-dashboard source (3.4/3.5/3.6 branches) | 4de6f4a + uncommitted | Initial tracker. 9 open, 6 future. |
