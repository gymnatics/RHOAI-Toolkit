# Debug playbook: failing check → cause → evidence → fix

Use with SKILL.md "Debug loop". For each FAIL/WARN: find the row, gather the evidence (read-only),
fact-check the expected state with `rhoai-knowledge` (live MCP), then propose the fix. Anything that
changes the cluster needs the user's go-ahead.

Where to look first, in order:
1. The check's own hint (`-> ...` line).
2. `docs/TROUBLESHOOTING.md` (grep the symptom), `docs/bugs/*.md`, `docs/COMPATIBILITY-TRACKER.md` (TRK-xxx).
3. The knowledge graph: `graphify query "<symptom>" --budget 2000`, `graphify explain "<path>::<fn>()"`.
4. `rhoai-knowledge`: `knowledge/rhoai-3.5-known-issues-and-gaps.md`, then live docs (search, then fetch with `query=`).

| Check id | Likely causes | Evidence to collect | Toolkit fix | Fact-check with rhoai-knowledge |
|---|---|---|---|---|
| `infra/cluster-reachable` | Cluster stopped (AWS sandbox), expired token, wrong KUBECONFIG | `oc whoami --show-server`; `echo $KUBECONFIG` | `scripts/manage-kubeconfig.sh`; `restart-cluster-instances.sh`; `scripts/approve-csrs.sh --auto` after restart | — |
| `infra/clusteroperators`, `nodes-ready`, `pending-csrs` | Post-restart CSR backlog, degraded ingress/auth | `oc get co`; `oc get csr \| grep Pending` | `scripts/approve-csrs.sh --auto` | — |
| `infra/ocp-version` | OCP outside the 3.5 support window | `oc get clusterversion` | upgrade OCP | SC "Supported OpenShift versions" (note install guide vs SC conflict) |
| `infra/gpu-allocatable` FAIL | GPU Operator ClusterPolicy not ready, driver/CUDA mismatch, NFD missing | `oc get clusterpolicy -o yaml`; `oc get pods -n nvidia-gpu-operator` | `lib/functions/troubleshooting.sh fix_gpu_operator_cuda_compatibility`; `scripts/setup-gpu-scheduling.sh` | `knowledge/adjacent/workload-and-accelerator-operators.md` |
| `infra/gpu-allocatable` WARN | GPU MachineSet scaled to 0 / instances stopped | `oc get machineset -n openshift-machine-api` | `scripts/manage-gpu-nodes.sh start`; `scripts/create-gpu-machineset.sh` | — |
| `operators/<pkg>` FAIL | InstallPlan pending (Manual approval), CSV Failed, catalog missing | `oc get csv,installplan -n <ns>`; `oc describe csv` | `scripts/check-pending-installplans.sh`; `scripts/check-operator-install-status.sh` | operator channel in docs prerequisites |
| `operators/rhods-channel` | fast-3.x fallback in install scripts (TRK) | `oc get sub rhods-operator -n redhat-ods-operator -o yaml` | change channel to `stable-3.5` (user approval) | upgrade guide ch.8 channel list |
| `platform/upgrade-gates` | 2.25→3.5 upgrade waiting on remediation | `oc get cm odh-upgrade-acks -n redhat-ods-operator -o yaml`; `oc describe dsc` | do the remediation, then ack that gate only | Upgrading 3.5 ch.5 (prerequisite resolution) and ch.7 |
| `platform/dsc-phase`, `dsc/<comp>` FAIL | Missing dependency operator, component prerequisite, known issue | `oc describe dsc default-dsc`; `oc get pods -n redhat-ods-applications`; operator logs `oc logs -n redhat-ods-operator deploy/rhods-operator` | per component (below) | dependency matrix row for the component; known issues list |
| `dsc/mcplifecycleoperator-ocp` | Toolkit enables MCP LCO on OCP < 4.22 | OCP version | set `mcplifecycleoperator: Removed` on < 4.22 (user approval); fix `datasciencecluster-v3-35.yaml` | MCP catalog guide §2.3 |
| `dsc/ogx` FAIL | Service Mesh 3 / cert-manager / NFD / GPU / PostgreSQL missing; RHOAIENG-96724 (OCI 401) | `oc get ogxserver -A`; operator logs | `docs/reference/BUG-REPORT-OGX-REGISTRY-AUTH-401.md`; `docs/bugs/autorag-ogx-3.5-cascade.md` | `knowledge/rhoai-3.5-known-issues-and-gaps.md` (OGX) |
| `dsc/kueue-state`, `kueue-operator` | embedded Kueue still Managed; RHBoK missing | `oc get sub -A \| grep kueue` | migrate Managed → Removed → Unmanaged | Managing OpenShift AI ch.8; Upgrading ch.5.1 |
| `dsc/trainer-jobset` | JobSet operator not installed | — | `oc apply -f lib/manifests/operators/jobset-subscription.yaml` (approval) | dependency matrix (Trainer v2) |
| `pods/<ns>` | CrashLoop/OOM (e.g. MCP LCO OOM RHOAIENG-82694, payload-processing OOM) | `oc describe pod`; `oc logs --previous` | `scripts/diagnose-maas.sh` (Issues 1, 5) | known issues list |
| `dashboard/flag-*` WARN | DP flags enabled by toolkit (TRK-001) | — | tell the user it's DP; leave or disable | RN ch.4 Developer Preview |
| `dashboard/reachable` | Gateway not programmed, DNS, route | `oc get gateway -A`; `oc get httproute -n redhat-ods-applications` | `scripts/fix-kuadrant-istio.sh` | networking-gateway-mesh knowledge file |
| `hwprofile/gpu-tolerations` | toleration `value` set with `Exists`, or missing | `oc get hardwareprofile -A -o yaml` | `scripts/fix-hardware-profile.sh`; `scripts/create-hardware-profile-quick.sh --all` | "Working with hardware profiles" guide |
| `hwprofile/kueue-namespaces` | toleration-based profile used in a Kueue-managed namespace | namespace labels | create a profile with a local queue | Managing OpenShift AI ch.8 restrictions |
| `storage/s3-backend` | SeaweedFS/MinIO not deployed or PVC pending | `oc get pods,pvc -n <ns>` | `scripts/setup-model-storage.sh`, `scripts/manage-storage.sh` | install guide "Object storage" |
| `maas/ModelsAsAServiceReady` | gateway/DB/TLS not configured yet | `oc describe dsc`; `scripts/setup-maas.sh --diagnose` | `scripts/setup-maas.sh --from-phase N` | `knowledge/tech-preview/models-as-a-service.md` |
| `maas/endpoint-auth` 200 | AuthPolicy missing (ungoverned) | `oc get authpolicy -A` | `scripts/check-maas-security.sh` | MaaS knowledge file |
| `maas-diag/*` | known RHOAIENG issues | message text | `scripts/diagnose-maas.sh --fix` (approval: it patches/restarts) | Jira ID in known issues |
| `serving/*` not Ready | GPU pending, image pull, wrong runtime/args, HW profile | `oc describe isvc/llmisvc`; predictor pod events/logs | `scripts/deploy-maas-model.sh`, `scripts/serve-model.sh`, `scripts/fix-hardware-profile.sh` | Deploying models guide; tool-calling parser rules (TOOLKIT-CONTEXT) |
| `demo:<x>/deployed` SKIP (unexpected) | demo never deployed / different namespace | `oc get ns` | `demo/<x>/deploy.sh -n <ns>` (always `-n`) | — |
| `demo:<x>/*` FAIL | see the demo row in `reference/demo-checks.md` | deploy.sh output; `oc get all -n <ns>` | re-run deploy; fix the defect listed | feature status (TP/DP) for the demo's feature |
| `demo:<x>/servedmodel` FAIL | Resource name used as the OpenAI model id instead of the served id | `oc get cm <cm> -n <ns> -o jsonpath='{.data.LLM_MODEL_NAME}'`; `oc get llminferenceservice -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,SERVED:.spec.model.name` | Set the served id in the ConfigMap, restart the consumer (e.g. `oc rollout restart deployment/<app>`) | — |
| `demo:open-webui-demo/probe openwebui` FAIL | `${MODEL_URL:-}` left unrendered by `envsubst`, or model detection picked a non-chat model / found none | `oc get cm openwebui-config -n open-webui -o jsonpath='{.data.OPENAI_API_BASE_URLS}'`; `oc get isvc,llmisvc -n open-webui` | Re-run `demo/open-webui-demo/deploy.sh -n open-webui [--model-url URL]` | TROUBLESHOOTING.md "Open WebUI Shows No Models" |
| `demo:nemo-guardrails-demo/probe nemo` FAIL | PII prompt not blocked (config/LLM issue), or no status returned (route/pod down, or `model_name` wrong in selfcheck mode) | `oc logs deploy/nemo-quickstart -n nemo-guardrails-demo`; `oc get cm nemo-quickstart-config -n nemo-guardrails-demo -o jsonpath='{.data.config\.yaml}'` | Fix `config.yaml` rails/model, or redeploy with `--selfcheck --model-url --model-name`; see "NeMo Guardrails `--selfcheck` Tests Fail With 404" in TROUBLESHOOTING.md | TROUBLESHOOTING.md Guardrails (NeMo) section |
| `demo:lemonade-stand-demo/probe lemonade-chat` FAIL | Expired NeMo token (`api-token-secret`) → "Backend error (401)"; or NeMo has no LLM (basic mode) → no text | `oc logs deploy/lemonade-stand -n nemo-guardrails-demo`; `oc get secret api-token-secret -n nemo-guardrails-demo`; `oc get cm nemo-quickstart-config -n nemo-guardrails-demo -o jsonpath='{.data.config\.yaml}'` | `./demo/nemo-guardrails-demo/deploy.sh -n nemo-guardrails-demo --selfcheck` (re-mints the token) then `./demo/lemonade-stand-demo/deploy.sh` | TROUBLESHOOTING.md "Lemonade Stand — Backend error (401)" |
| `demo:lemonade-stand-demo/probe lemonade-chat` WARN (`<think>` in reply) | `DISABLE_THINKING` env not set to `true`, or an older `app.py` without the strip/`/no_think` fix | `oc get deploy/lemonade-stand -n nemo-guardrails-demo -o jsonpath='{.spec.template.spec.containers[0].env}'` | Re-run `demo/lemonade-stand-demo/deploy.sh` (rebuilds the image); confirm `DISABLE_THINKING=true` | TROUBLESHOOTING.md "Lemonade Stand — Replies Show `<think>...</think>`" |
| `nb:*/wb:*` FAIL (pod) | GPU/HW profile, image tag missing in ImageStream | `oc describe pod <wb>-0`; `oc get is -n redhat-ods-applications` | fix profile / image tag (`lib/functions/workbench.sh:40`) | workbench troubleshooting (Managing resources ch.8.7) |
| `nb:*/wb:*-env-drift` | pod started before `inject_notebook_env` | compare `oc exec <wb>-0 -- env` with `oc get cm notebook-env -o yaml` | restart the workbench (approval). Do not use refresh-notebook-env.sh if demo-specific keys matter | — |
| `nb:*/<nb>-env` | key never injected (MAAS_API_KEY, MAAS_BASE_URL, TOKENIZER_HF_ID) | ConfigMap content | add key to `notebook-env` + restart, or fix deploy.sh | — |
| `nb:*/url:*` | endpoint moved/renamed, NetworkPolicy, TLS-only service | `oc get svc,networkpolicy -n <target-ns>` | `scripts/refresh-notebook-env.sh <ns>` | — |
| `nb:*/<nb>-import-*` | package not in image, no egress for pip | `oc exec ... pip list` | pip install / custom image / fix notebook | SC workbench image package tables |
| `nb:*/<nb>-exec` FAIL | runtime error in a cell | the hint's `jq` command on the output notebook | fix data/env/notebook | depends on error |

## Writing findings back

- Toolkit diverges from official docs (support tier, version, deprecated behaviour) → `compat-tracker`
  skill (new TRK row with source URL + lastModified).
- New symptom + fix → `docs/TROUBLESHOOTING.md` entry (delegate the write-up to `sonnet-scribe` with
  exact facts, then review).
- Upstream product bug → `docs/bugs/<topic>.md` using the rhoai-knowledge documentation workflow.
- Check logic wrong/missing → update `checks/*.sh` or `*-specs.conf`, add a fixture case in
  `tests/make-fixture.py` + assertion in `tests/run-tests.sh`, run `tests/run-tests.sh`.
