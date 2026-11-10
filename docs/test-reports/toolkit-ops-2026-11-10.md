# toolkit-ops verification: RHOAI 3.5 and 3.4 sandboxes (2026-11-10)

Run with `/toolkit-ops verify` (`.claude/skills/toolkit-ops/checks/run-all.sh`), read-only. Nothing on either
cluster was changed. The demos and platform phases were re-run after fixing five false alarms in the checks
(see "Check fixes"); the notebook phase is from the first run.

| | 3.5 cluster | 3.4 cluster |
|---|---|---|
| API | api.ocp.sclg6.sandbox323.opentlc.com | api.cluster-9tjvr.9tjvr.sandbox2001.opentlc.com |
| OpenShift / RHOAI | 4.21.31 / 3.5.1 | 4.20.23 / 3.4.6 (full support ends 2026-11-16) |
| Platform + demos phases | 95 PASS, 13 WARN, 17 FAIL, 10 SKIP | 96 PASS, 8 WARN, 19 FAIL, 10 SKIP |
| Notebook phase | 3 workbenches checked, 1 not Ready | 3 workbenches checked, 1 not Ready |

## Main finding: the GPU workers are stopped on both clusters

All GPU worker instances are EC2-`stopped` (`machine.openshift.io/instance-state=stopped`): 7 g6e.xlarge on 3.5,
5 g6e.2xlarge on 3.4. Their nodes are NotReady ("Kubelet stopped posting node status"). Everything scheduled
there is unavailable, and the DaemonSets (machine-config-daemon, multus, node-exporter) can't finish rolling
out, so ClusterVersion reports Failing and machine-config/monitoring (and network on 3.4) are degraded.

This alone explains these FAILs: the GPU models (3.4: qwen3-8b-fp8-dynamic-no-maas, nemotron-nano-8b,
qwen3-coder-30b, redhataiqwen3-8b; 3.5: llm/qwen3-8b), the MaaSModelRefs on top of them, the financial-loan
`model-training` workbench (1 GPU) on both clusters, and 3.4 lightspeed (OLSConfig NotReady, needs the model).

**Fix (needs your approval: starts instances, costs money):** `scripts/manage-gpu-nodes.sh start` on each
cluster, then `scripts/approve-csrs.sh --auto` and re-run the checks.

Also stopped on purpose on 3.5 (`serving.kserve.io/stop=true`): `autorag-demo/bge-m3`, `llm/qwen3-8b-eval`,
`llm/simulator`. autorag and lmeval need them started.

## Pipelines and storage (MinIO vs SeaweedFS)

| Cluster | DSPA | Object store | State | Cause |
|---|---|---|---|---|
| 3.5 | pipeline-demo | `seaweedfs-s3.pipeline-demo.svc:8333` | **Ready** | correct: `setup_pipeline_server` is backend-aware |
| 3.5 | lmeval-demo | DSPA-managed MinIO (`quay.io/opendatahub/minio:RELEASE.2019-08-14...`) | Ready | built-in MinIO; image already cached |
| 3.5 | automl-demo, autorag-demo | `minio.<ns>.svc.cluster.local:9000` | **Not Ready**: `lookup minio...: no such host` | **toolkit bug**: `demo/automl-demo/manifests/pipeline-server.yaml:19` and autorag's copy hard-code a MinIO host/port and `minio-secret`. `deploy.sh` now deploys SeaweedFS (`seaweedfs-s3`, port 8333), so the DSPA points at a service that doesn't exist |
| 3.4 | pipeline-demo, automl-demo, autorag-demo | `minio.<ns>.svc...:9000` | **Not Ready**: connection refused | MinIO pods in ImagePullBackOff: `quay.io/minio/minio:latest` returns **`unauthorized`** to anonymous pulls |

The `quay.io/minio/minio` pull failure isn't limited to 3.4 demos. These toolkit manifests reference it:
`lib/manifests/pipeline/minio-pipelines.yaml`, `lib/manifests/model-storage/minio-deployment.yaml`,
`lib/manifests/observability/usage-logging/minio.yaml`, `lib/manifests/storage/minio.yaml`,
`lib/manifests/storage/minio/minio-deployment.yaml`, `demo/autorag-demo/manifests/minio.yaml`,
`demo/automl-demo/manifests/minio.yaml`. On 3.5, `redhat-ods-monitoring/minio-usage-logs` (MaaS usage logging)
runs only because the image is cached on its node, and will fail on the next reschedule. The other 3.4 MinIO
pods (a-rh-dept, financial-loan-demo, model-storage) are in the same position.

**Fixes (repo changes, need your approval):**
1. Template the automl/autorag DSPA object store from the storage backend (host, port, scheme, secret), the
   way `lib/functions/pipeline-server.sh` does for pipeline-demo.
2. Replace `quay.io/minio/minio:latest` with a pullable image, or move those paths to SeaweedFS (the
   toolkit default; `docs/guides/S3-BACKEND-MIGRATION.md`).

**Cluster fix for 3.5 automl/autorag DSPAs (needs approval):** point `spec.objectStorage.externalStorage` at
`seaweedfs-s3.<ns>.svc` port `8333` with the SeaweedFS credentials secret (as in pipeline-demo), or redeploy
after fix 1.

## Other FAILs

| Cluster | Check | Cause | Fix |
|---|---|---|---|
| 3.5 | `platform/dsc-phase` (ogx degraded), `demo:autorag-demo` autorag-ogx CrashLoop, genai-pgvector + autorag-ogx-connection missing | The OGXServer `autorag-ogx` was created 2026-09-21 with `rh` + `baseConfig`, before the toolkit fix (df8b5b4, 2026-10-16: `rh-dev` + `overrideConfig`). Startup fails with `ValidationError: MilvusVectorIOConfig token, persistence: Field required`, the CRD-merge bug in `docs/bugs/autorag-ogx-3.5-cascade.md`. OGX vector providers and AutoRAG are Technology Preview. | Redeploy autorag with the current toolkit: `demo/autorag-demo/deploy.sh -n autorag-demo` (approval). Start `bge-m3` first |
| 3.5 | `dsc/mcplifecycleoperator-ocp` | MCP Lifecycle Operator Managed on OCP 4.21; docs require 4.22+ (Working with the MCP catalog 3.5 §2.3) | Set `mcplifecycleoperator: Removed` (approval), and fix `datasciencecluster-v3-35.yaml` |
| 3.5 | `maas/endpoint-auth` 503 + `maas-diag/wasm-shim-stale-auth-cache` | Stale WASM auth cache in the gateway (`/maas-api/v1/health` 503); backing models down as well | `scripts/diagnose-maas.sh --fix` restarts the gateway pod (approval), after the GPU nodes are back |
| 3.5 | `demo:n8n-demo` CrashLoop | `Mismatching encryption keys`: `demo/n8n-demo/deploy.sh:58` generates a new `N8N_ENCRYPTION_KEY` on every run, which no longer matches the key saved on the PVC (toolkit defect, predicted in `reference/demo-checks.md`) | Restore the original key or recreate the PVC (approval); fix deploy.sh to reuse the existing Secret |
| 3.4 | `operators/nfd` Pending | OLM upgrade stuck: new CSV `nfd.4.20.0-202607141145` Pending because the CRDs are still owned by `...202607071454` (Replacing). Same pattern for opentelemetry-operator | Check the old CSV and InstallPlans; usually resolved by removing the stuck old CSV (approval) |
| 3.4 | `maas-diag/payload-processing-oom`, `wasm-auth-timeout` | Known issues RHOAIENG-88898 (256Mi limit) and RHOAIENG-71638 (200ms auth timeout) | `scripts/diagnose-maas.sh --fix` (approval) |
| 3.4 | `demo:lmeval-demo/isvc:qwen3-8b-eval` | namespace `llm` doesn't exist on this cluster | expected if the eval model was never deployed here |

## Notebooks

| Cluster | Workbench | Result |
|---|---|---|
| both | maas-ratelimit `rate-limit-testing` | Ready, env matches ConfigMap. `maas-ratelimit-test` needs `MAAS_API_KEY` (never injected). 3.4 is also missing `MODEL_ID`, `MAAS_ROUTING`, and the repo clone (2026-06-06) predates `maas-traffic-generator.ipynb` |
| both | pipeline-demo `ai-pipelines` | Ready. 3.5: env complete, S3 is SeaweedFS. 3.4: `DATA_BUCKET`, `ARTIFACTS_BUCKET`, `S3_BUCKET` missing, `S3_ENDPOINT` (minio) unreachable. The missing keys are exactly the ones `scripts/refresh-notebook-env.sh` drops, so it was probably run there. The Elyra notebooks have known defects regardless (no sample data upload, bucket mismatch) |
| both | lmeval `model-benchmarking` | Ready. `guidellm-benchmark` and `korean-mcq-benchmark` fail on `import evalhub` (no pip cell). 3.5: `DIRECT_ROUTE_URL` unreachable because `qwen3-8b-eval` is stopped |
| both | financial-loan `model-training` | Not Ready: GPU workbench on a stopped node |
| both | feast `feature-store` | not deployed (SKIP) |

No notebook was executed: `--execute` runs notebook code and was not approved. Image tags: all 3.5
workbenches use `s2i-generic-data-science-notebook:3.4` (3.5 images are 2025.2). Workbench repo clones track
GitHub main and are 1-5 months old, so local fixes aren't inside the pods until re-cloned.

## WARNs worth knowing

- DP features enabled on 3.5: `agentsCatalog`, `agentConfigManagement` (TRK-001).
- RHCL 1.4.3 on 3.5 (RHOAIENG-76586). 3.4 runs RHCL 1.3.4.
- Unapproved InstallPlans on both clusters (3.5 includes one in `redhat-ods-operator`: a pending RHOAI update).
- 3.5 `rhods-operator` pods have restarted 41-68 times (Ready now).
- 3.4 logged in as `kube:admin` (RHOAI docs require an IdP cluster-admin).

## Not checked

Demos not deployed (SKIP): 3.5: university-safeguard, lemonade-trustyai, lightspeed, nim, marketing-assistant,
agentic-platform, feast, llamastack. 3.4: university-safeguard, mlflow-tracing, n8n, marketing-assistant,
agentic-platform, feast, llamastack, and others with no namespace. No E2E MaaS run (`verify-maas.sh` deploys
resources). No notebooks executed.

## Check fixes made during this run

False alarms found on the live clusters and fixed in `.claude/skills/toolkit-ops/checks/`, each with a
regression test (`tests/run-tests.sh`: 58/58):
1. DSPA condition with `==` in the jsonpath was parsed wrong (split on the last `=` now).
2. MaaS endpoint taken from `get_maas_endpoint`'s human-readable output (now the gateway hostname).
3. `diagnose-maas.sh --json` output preceded by a banner line (now stripped).
4. 3.5-only dashboard flags expected on 3.4.
5. Pods that are Ready but restarted often reported as unhealthy (now a separate WARN); models stopped on
   purpose reported as FAIL (now INFO/WARN). NotReady nodes now name stopped cloud instances as the cause.

## After the fixes (same day)

Plan and execution: `docs/test-reports/toolkit-ops-2026-11-10-fix-plan.md`.

| | 3.5 cluster | 3.4 cluster |
|---|---|---|
| Before | 31 FAIL (incl. notebooks) | 29 FAIL |
| After | **8 FAIL**, 149 PASS | **8 FAIL**, 151 PASS |

Done:
- GPU nodes: 3.5: 7 stopped g6e.xlarge machines replaced (MachineSets recreated them). 3.4: 5 g6e.2xlarge restarted
  with `manage-gpu-nodes.sh start` (AWS capacity was short in us-east-2a; retried until all started).
  Reference cluster: g6e.xlarge MachineSet scaled 1 -> 3 (a GPU workbench was holding its only GPU).
- 3.5 autorag: OGX `Ready`, `/v1/health` OK, same 4 models as the reference cluster, and a chat completion through OGX
  to the in-cluster Qwen3-8B returns. Causes fixed: pre-fix OGXServer (rh + baseConfig) recreated; config re-pointed
  from the reference cluster's MaaS URL to `qwen3-8b-kserve-workload-svc.llm.svc.cluster.local:8000`; missing
  `ogx.io/watch=true` label (regression from df8b5b4) added; DSPA moved to SeaweedFS.
- 3.5 `qwen3-8b`: was crash-looping on a T4 (g4dn.metal, compute 7.5) after the L40S nodes were stopped; pinned with
  node affinity `nvidia.com/gpu.compute.major Gt 7`; Ready on an L40S.
- Pipelines: 3.5 automl + autorag and 3.4 automl + autorag + pipeline-demo DSPAs all Ready on SeaweedFS (object store
  verified). Dead MinIO deployments removed on 3.4 (PVCs kept).
- 3.5: MCP Lifecycle Operator set to Removed (OCP 4.21); n8n key restored from its PVC (1/1); MaaS gateway restarted.
- 3.4: MaaS fixes applied (`AUTH_SERVICE_TIMEOUT=2s`); pipeline-demo and maas-ratelimit workbench env re-injected and
  restarted.
- Reference cluster: autorag chat through OGX works again.

Remaining FAILs:
| Cluster | Check | Status |
|---|---|---|
| 3.5 | `platform/dsc-phase` "degraded: ogx" | `OGXReady=True`, OGX component and all 3 OGXServers Ready; DSC summary looks stale (should clear on next reconcile) |
| 3.5 | `maas/models` simulator | stopped on purpose (`serving.kserve.io/stop=true`) |
| 3.5 | lmeval `DIRECT_ROUTE_URL` | `qwen3-8b-eval` stopped on purpose |
| 3.4 | `operators/nfd` Pending (and OpenTelemetry) — **won't fix** (3.4 cluster is a short-lived reference environment) | deleting the stuck old CSVs exposed broken install plans (ServiceAccounts missing). Needs a resubscribe (delete Pending CSVs + Subscription, recreate Subscription; backups in `/tmp/tops/olm/`). Not done: needs approval |
| 3.4 | `maas-diag/payload-processing-oom` — **won't fix** (reference env) | `diagnose-maas.sh --fix` set 1Gi + `managed=false`, but the 3.4 operator reverted the limit to 256Mi |
| 3.4 | lmeval `qwen3-8b-eval` | namespace `llm` was never created on this cluster |
| both | notebooks | known notebook defects (evalhub pip cell, traffic-generator env, stale repo clones in workbenches, financial-loan env keys dropped by an earlier `refresh-notebook-env.sh`) |
