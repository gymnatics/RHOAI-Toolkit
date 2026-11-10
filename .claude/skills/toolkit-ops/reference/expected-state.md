# Expected state: what the checks enforce, and why

Every rule in `checks/*.sh` maps to a row here. **Official** rows were verified live through the
red-hat-docs MCP server on 2026-11-10 (page `lastModified` shown). **Toolkit** rows come from the
toolkit's own manifests and docs (source of truth for *intended* state, not for product facts).
Before changing a rule, or when a check disagrees with a live cluster, re-verify with the
`rhoai-knowledge` skill (live MCP first).

Abbreviations: SC = Supported Configurations (access.redhat.com/articles/rhoai-supported-configs),
RN = RHOAI 3.5 release notes, DOCS = docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5/html/.

## Infrastructure (`check-infra.sh`)

| Rule | Value | Source |
|---|---|---|
| OpenShift version | 4.19.9 to 4.22 | SC (rhoai-knowledge `rhoai-3.5-feature-status.md`). **Conflict:** the 3.5 install guide §3.1.1 text says "4.19 to 4.20" (DOCS `installing_and_uninstalling_openshift_ai_self-managed/installing-and-deploying-openshift-ai_install`, lastModified 2026-11-06). SC governs support status. |
| llm-d (and so MaaS) | OCP 4.20+ | Same install guide §3.1.1 |
| MCP Lifecycle Operator | OCP 4.22+ | DOCS `working_with_the_mcp_catalog/enabling-mcp-lifecycle-management` §2.3 prerequisites (lastModified 2026-08-26) |
| Workers | ≥ 2 with ≥ 8 CPU / 32 GiB (SNO: 32 CPU / 128 GiB) | Install guide §3.1.1 "Cluster configuration". The check accepts ≥ 30 GiB capacity because 32 GiB nodes report slightly less. |
| Default StorageClass | required, dynamic provisioning | Install guide §3.1.1 "Storage requirements" |
| Identity provider | required; kubeadmin not allowed | Install guide §3.1.1 "Identity provider configuration" |
| Open Data Hub | must not be installed | Install guide §3.1.1 |
| OLMv1 catalog | default (TP) on OCP 4.21+; web-console installs of NFD/GPU may redirect to ClusterExtensions | Install guide §3.1.1 note |
| Service Mesh 2 | cannot coexist with OCP Gateway API | rhoai-knowledge `adjacent/rhoai-feature-dependency-matrix.md` |
| User Workload Monitoring | needed by MaaS, llm-d metrics | dependency matrix (MaaS row); toolkit `lib/functions/maas-verify.sh verify_maas_35` |
| GPU taint `nvidia.com/gpu` | HardwareProfiles must tolerate it | Toolkit: `lib/manifests/rhoai/hardware-profile-gpu.yaml`, TOOLKIT-CONTEXT Critical Gotchas |

## Platform (`check-platform.sh`)

| Rule | Value | Source |
|---|---|---|
| RHOAI channel | `stable-3.5` or `eus-3.5`; `fast-3.x` is frozen at 3.3.1 | DOCS `upgrading_openshift_ai_self-managed/upgrading-the-openshift-ai-operator_upgrade` (lastModified 2026-11-06); fast-3.x freeze: TOOLKIT-CONTEXT lifecycle table (catalog check 2026-10-23) |
| DSC health | `status.phase=Ready`, `ReconcileComplete=True`; no pods outside Running/Succeeded in `redhat-ods-applications` | Same upgrade chapter, Verification |
| Upgrade gates | `ProvisioningProgress` reason `AdminAckRequired` → `odh-upgrade-acks` ConfigMap; ack only after remediation, never in bulk | DOCS `upgrading_openshift_ai_self-managed/acknowledging-upgrade-gates_upgrade` ch.7 |
| Component installed | `.status.installedComponents.<component>` true | MCP catalog §2.3 and MLflow ch.4.2 verification steps |
| Expected component states | `lib/manifests/rhoai/datasciencecluster-v3-35.yaml` (3.4: `-v3-34.yaml`) | Toolkit source of truth (`.cursor/rules/manifests-source-of-truth.mdc`) |
| `mcplifecycleoperator` | defaults to `Removed`; TP; needs OCP 4.22+. **The toolkit sets `Managed` on every cluster.** | MCP catalog §2.1.1, §2.3 |
| `kueue` | `Unmanaged` (needs the Red Hat build of Kueue operator) or `Removed`. `Managed` (embedded) is deprecated; with the Kueue operator also installed, OpenShift AI stops reconciliation. **Not "rejected"** (TOOLKIT-CONTEXT wording is stronger than the docs). | DOCS `managing_openshift_ai/managing-workloads-with-kueue` ch.8 (lastModified 2026-11-06) |
| Kueue + HardwareProfiles | in namespaces labelled `kueue.openshift.io/managed=true`, profiles must use a local queue, not node selectors/tolerations | Same ch.8 "Restrictions" |
| `trainer` | needs the JobSet operator; Trainer v2 only works with Kueue 1.3 (RHOAIENG-87625) | dependency matrix; TOOLKIT-CONTEXT known issues |
| `mlflowoperator` | defaults to `Removed`; `mlflow` dashboard flag deprecated since 3.4 | DOCS `working_with_mlflow/tracking-experiments-with-mlflow-in-workbenches` ch.4.2 |
| DP dashboard flags | `agentsCatalog`, `agentConfigManagement` (+ `agentOpsDeploy`) are Developer Preview (unsupported) | RN ch.4; compat tracker TRK-001 |
| `maasAuthPolicies` flag | removed in 3.5 (webhook rejects) | RN ch.5; TOOLKIT-CONTEXT |
| Dashboard flags expected | `lib/manifests/rhoai/odh-dashboard-config-patch.yaml` | Toolkit |
| RHCL | 1.4.0 deprecated; 1.4.x hits RHOAIENG-76586 | TOOLKIT-CONTEXT; dependency matrix ("RHCL 1.4.x, Kuadrant ≥ 1.4.2") |
| Lifecycle | 3.4 full support ends 2026-11-16; 3.3 EOL 2026-10-05 | rhoai-knowledge `sources/portal/lifecycle_dates.md` (Product Life Cycles API) |
| GPU HardwareProfile | toleration `nvidia.com/gpu`, `operator: Exists`, empty `value` | TOOLKIT-CONTEXT Critical Gotchas; TROUBLESHOOTING "toleration value must be empty" |

## MaaS (`check-maas.sh`)

| Rule | Value | Source |
|---|---|---|
| DSC field | 3.5: `aigateway.modelsAsAService`; 3.4: `kserve.modelsAsService` | RN 3.5; `datasciencecluster-v3-35.yaml` |
| Conditions | 3.5: `AIGatewayReady`, `ModelsAsAServiceReady` (stays False until gateway + DB + TLS exist) | `scripts/install-rhoai-35.sh` waits; TOOLKIT-CONTEXT MaaS deep dive |
| Infra namespace | 3.5: `redhat-ai-gateway-infra`; 3.4: `redhat-ods-applications` | `lib/utils/rhoai-version.sh get_maas_infra_namespace` |
| Database | PostgreSQL 14+, customer-provided; secret `maas-db-config` key `DB_CONNECTION_URL` | dependency matrix; `verify_maas_35` |
| Gateway | `maas-default-gateway` in `openshift-ingress`, Programmed, listener hostname set (RHOAIENG-89775) | `verify_maas_35`; `scripts/diagnose-maas.sh` Issue 4 |
| Auth enforced | `/v1/models` without a key → 401/403 | Toolkit behaviour (`scripts/verify-maas.sh` phase 4) |
| Known issues | 11 checks in `scripts/diagnose-maas.sh` (read-only without `--fix`) | RHOAIENG IDs in that script |

## Workbenches and notebooks (`check-notebooks.sh`)

| Rule | Value | Source |
|---|---|---|
| Workbench object | `Notebook` (kubeflow.org); pod `<name>-0`; container name = Notebook name; stop annotation `kubeflow-resource-stopped` | DOCS `working_on_projects/managing-access-to-projects_projects` §5.1.3; MLflow ch.4.1.3; toolkit `lib/manifests/workbench/notebook-template.yaml` |
| Env delivery | `envFrom: configMapRef notebook-env`; env vars are fixed at pod start | Toolkit template; Kubernetes semantics |
| MLflow env | annotation `opendatahub.io/mlflow-instance` → `MLFLOW_TRACKING_URI`, `MLFLOW_K8S_INTEGRATION`, `MLFLOW_TRACKING_AUTH`; URI skipped if the Gateway hostname is unknown at start (degraded) | MLflow ch.4.1.1, 4.1.4 |
| Elyra | not available in code-server images | DOCS `working_on_projects/using-project-workbenches_projects` §2.1.2 |
| Headless execution | `jupyter nbconvert --execute` (nbconvert 7.16 in 2025.2 images); papermill is not shipped | SC image package tables (repo copy `docs/reference/RHAIE 3.5 Guide/...Supported_Configurations...`) |
| 3.5 image tags | 2025.2 (the toolkit still defaults to `:3.4` tags) | Same; `lib/functions/workbench.sh:40` |
