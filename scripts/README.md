# Scripts Reference — Categorized Catalog

Every script in `scripts/`, categorized by function. For each: filename, one-line purpose, key CLI flags.

---

## 1. Installation

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `install-rhoai-35.sh` | Full RHOAI 3.5 install (OGX, MCP Lifecycle Op, RHCL 1.4.1+, aigateway.modelsAsAService) | `--skip-prerequisites`, `--skip-rhcl`, `--skip-maas`, `--skip-node-scaling`, `--skip-maas-db`, `--no-llmd`, `--channel <ch>`, `--enable-vllm-maas`, `--enable-observability`, `--enable-tp-features`, `--enable-usage-logging`, `--deploy-grafana`, `--postgres-connection <url>`, `--domain <domain>`, `--timeout <s>` |
| `install-rhoai-34.sh` | Full RHOAI 3.4 install (MaaS core GA, NeMo Guardrails GA, MLflow) | `--skip-prerequisites`, `--skip-rhcl`, `--skip-maas`, `--skip-node-scaling`, `--skip-maas-db`, `--no-llmd`, `--channel <ch>`, `--enable-vllm-maas`, `--enable-observability`, `--deploy-grafana`, `--postgres-connection <url>`, `--domain <domain>`, `--setup-users`, `--num-users <N>`, `--setup-pipelines` |
| `install-rhoai-33.sh` | **Legacy/deprecated.** Full RHOAI 3.3 install (MaaS TP, tier-based) | `--skip-prerequisites`, `--skip-rhcl`, `--skip-maas`, `--skip-node-scaling`, `--no-llmd`, `--channel <ch>`, `--domain <domain>` |
| `install-rhoai-minimal.sh` | Minimal RHOAI install — choose operators interactively (no MaaS/llm-d) | `--minimal`, `--full`, `--with-kueue`, `--with-llmd` |
| `openshift-installer-master.sh` | All-in-one OpenShift cluster installation on AWS (VPC, install-config, bootstrap) | *(interactive — prompts for cluster name, domain, region, instance types, VPC, SSH key, pull secret)* |

## 2. MaaS Infrastructure

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `setup-maas.sh` | Phased MaaS platform setup: RHCL → Gateway → PostgreSQL → DSC (version-branched 3.4 vs 3.5) | `--from-phase <N>`, `--diagnose`, `--enable-redis`, `--enable-observability` |
| `diagnose-maas.sh` | Check the BU guide's 11 post-upgrade issues; optionally auto-fix the safe ones | `--fix`, `--json` |
| `verify-maas.sh` | 6-phase E2E verification (infra health → simulator deploy → API → auth → rate limit → cleanup) | `--no-cleanup`, `--cleanup-only` |
| `cleanup-maas.sh` | Reverse-order MaaS teardown (models → external models → OIDC → platform → gateway → operators) | `--dry-run`, `--yes`, `--keep-operators`, `--from-phase <N>` |
| `setup-maas-oidc.sh` | Deploy demo Keycloak + configure external OIDC on MaaS tenant (or BYO IdP) | `--configure-only`, `--client-id <id>`, `--issuer-url <url>`, `--ttl <s>`, `--cleanup`, `--test` |
| `fix-kuadrant-istio.sh` | Fix Kuadrant "MissingDependency" for Istio (approve Service Mesh InstallPlans, create Istio/IstioCNI, restart) | *(no flags — fully automatic)* |
| `setup-llmd.sh` | Set up llm-d prerequisites: GatewayClass, Gateway, LeaderWorkerSetOperator | *(no flags)* |
| `enable-dashboard-features.sh` | Enable Model Registry, GenAI Studio, Model Catalog, MaaS, LMEval dashboard flags | *(no flags — applies a manifest)* |

## 3. Model Deployment

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `deploy-maas-model.sh` | Deploy a model from `lib/manifests/maas/models/{model}/` via Kustomize with GPU auto-detection | `--model <name\|auto>`, `-n <namespace>`, `--delete`, `--disconnected-registry <host>` |
| `deploy-external-model.sh` | Deploy OpenAI/Gemini/Bedrock external model through MaaS gateway | `--provider <openai\|gemini\|bedrock>`, `--api-key <key>`, `--delete`, `--force` |
| `deploy-llmd-model.sh` | Interactive model deployment — auto-detects runtimes, catalogs models, configures resources | *(interactive — no CLI flags)* |
| `serve-model.sh` | Deploy model from S3/PVC/OCI with vLLM or vLLM-Omni runtime | `<mode> <name> <model_path> [extra_vllm_args]`; env: `NAMESPACE`, `RUNTIME=vllm\|omni`, `MAAS_PUBLISH=true` |
| `download-model.sh` | Download HuggingFace model(s) to S3 (MinIO/SeaweedFS) or PVC | `<s3\|pvc> <model1> [model2…]`; env: `HF_TOKEN`, `NAMESPACE`, `MINIO_NAMESPACE`, `BUCKET_NAME` |
| `add-model-to-playground.sh` | Add a deployed model endpoint to the GenAI Playground (LlamaStack or OGX) | `-n <namespace>`, `-m <model>`, `-t <max-tokens>`, `--tls-verify`, `--api-token <token>`, `--skip-config` |
| `add-serving-runtime.sh` | Add/manage custom serving runtimes (vLLM community, vLLM-Omni, Red Hat vLLM) | `--preset <omni\|vllm-community\|vllm-redhat>`, `--print`, `--list`, `--export-all <dir>`, `-n <ns>`, `--version <tag>` |
| `deploy-qwen3-4b-with-tools.sh` | Deploy Qwen3-4B with tool calling enabled via YAML (hermes parser) | `<namespace>` (positional) |
| `deploy-simulator-model.sh` | **Deprecated** wrapper → forwards to `deploy-maas-model.sh --model simulator` | `-n <namespace>`, `--delete` |
| `deploy-nim.sh` | Full NVIDIA NIM platform setup + model deployment (NGC creds, dashboard, monitoring) | `-n <namespace>`, `--ngc-key <key>`, `--model <preset>`, `--gpu-count <N>`, `--skip-platform`, `--deploy-grafana`, `--delete` |
| `deploy-nemo-guardrails.sh` | Thin wrapper → `demo/nemo-guardrails-demo/deploy.sh` | `[namespace]`, `--selfcheck`, `--delete` |
| `deploy-guardrails.sh` | Deploy TrustyAI Guardrails Orchestrator (PII detection, safety filters) | `[namespace]` (positional, interactive) |
| `deploy-university-safeguard-demo.sh` | Thin wrapper → `demo/university-safeguard-demo/deploy.sh` | `-n <namespace>`, `--delete` |
| `manage-model-catalog.sh` | Add/remove/list/rename entries in the RHOAI Model Catalog | `list`, `add`, `remove`, `rename`, `add-from-registry`, `apply` (or interactive menu) |

## 4. GPU & Hardware

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `create-gpu-machineset.sh` | Create a GPU MachineSet on AWS (g6e, p5, spot instances) | `--instance-type <type>`, `--spot`, `--spot-max-price <price>`, `--az <zone>`, `--replicas <N>`, `--volume-size <GB>`, `--apply` |
| `manage-gpu-nodes.sh` | AWS EC2 stop/start GPU instances directly (preserves node identity, EBS, drivers) | `status\|stop\|start`, `--machineset <name>`, `--no-wait`, `--timeout <s>` |
| `create-hardware-profile.sh` | Create GPU HardwareProfile in a namespace (interactive — Kueue or Node scheduling) | `[namespace]` (positional, interactive) |
| `create-hardware-profile-in-namespace.sh` | Create GPU hardware profile from template in a specified namespace | `[namespace]` (positional) |
| `create-hardware-profile-quick.sh` | Quick pre-configured GPU profiles (small/medium/large) | `[namespace]`, `--all` |
| `create-project-hardware-profiles.sh` | Create all 3 hardware profile sizes (gpu, small-gpu, large-gpu) in a project namespace | `[namespace]` (positional) |
| `fix-hardware-profile.sh` | Fix hardware profile visibility in RHOAI dashboard (old API versions, missing labels) | *(interactive — no flags)* |
| `fix-gpu-resourceflavor.sh` | Fix Kueue ResourceFlavor tolerations for tainted GPU nodes | *(no flags — auto-detects and patches)* |
| `setup-gpu-scheduling.sh` | Auto-configure GPU scheduling: ResourceFlavor + ClusterQueue + HardwareProfile | `[namespace]` (positional) |

## 5. Diagnostics

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `diagnose-maas.sh` | (Also in MaaS) 11-issue MaaS post-upgrade triage + auto-fix | `--fix`, `--json` |
| `check-maas-security.sh` | Audit MaaSModelRefs for missing MaaSAuthPolicy/MaaSSubscription (ungoverned models) | *(no flags)* |
| `check-pending-installplans.sh` | Find and optionally approve all pending OLM InstallPlans across namespaces | *(no flags — optionally offers approval)* |
| `check-operator-install-status.sh` | Wait for an operator subscription to be fully installed (InstallPlan → CSV Succeeded) | `<subscription-name> <namespace> [timeout]` (positional) |
| `check-aws-prerequisites.sh` | Validate AWS environment before OpenShift install (CLI, Route53, quotas, SSH) | *(no flags)* |
| `diagnose-aws-credentials.sh` | Comprehensive AWS credentials diagnostic (env vars, config files, STS, profiles) | *(no flags)* |
| `approve-csrs.sh` | Approve pending Certificate Signing Requests (new nodes, node reboots) | `--auto`, `--watch` |

## 6. Cleanup

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `cleanup-all.sh` | Destroy OpenShift cluster + clean up ALL AWS resources (VPCs, EIPs, NAT GWs, etc.) | `--local-only` / `-l`, or interactive menu |
| `cleanup-maas.sh` | (Also in MaaS) Reverse-order MaaS teardown | `--dry-run`, `--yes`, `--keep-operators`, `--from-phase <N>` |

## 7. Security / Access

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `create-restricted-client-admin.sh` | cluster-admin for a client that can't mutate Machine API / delete Nodes (ValidatingAdmissionPolicy) | `--client-user <name>`, `--client-password <pw>`, `--owner-user <name>`, `--owner-group <name>`, `--idp-name <name>`, `--test`, `--remove` |
| `check-maas-security.sh` | (Also in Diagnostics) Audit ungoverned MaaS models | *(no flags)* |
| `scan-for-secrets.sh` | Scan repo for exposed AWS keys, passwords, private keys; check .gitignore | *(no flags)* |
| `install-pre-commit-hook.sh` | Install git pre-commit hook that blocks commits containing sensitive data | *(interactive — install/uninstall/status)* |
| `setup-letsencrypt-tls.sh` | Automated TLS certificate setup: Let's Encrypt (Route53 DNS-01) or self-signed | `letsencrypt`, `selfsigned`, `status`, `check-gateways`, `fix-gateways`, `--non-interactive`, `--email <email>` |

## 8. Observability

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `deploy-dashboards.sh` | Deploy GPU (DCGM) and vLLM monitoring dashboards to Observe tab or Grafana | `--method native\|grafana`, `--dashboard all\|dcgm\|vllm\|vllm-advanced`, `--delete` |

## 9. Storage

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `manage-storage.sh` | **General-purpose S3 storage CLI** — deploy, bucket CRUD, data connections, cluster-wide status | Subcommands: `deploy`, `status`, `info`, `bucket create\|list\|delete\|ls`, `connect`, `delete`. See `--help` for each. |
| `setup-model-storage.sh` | Deploy S3-compatible storage (SeaweedFS/Ceph-RGW/MinIO) + RHOAI data connection (model-focused convenience wrapper) | `--backend seaweedfs\|ceph-rgw\|minio`, `-n <namespace>`, `-b <bucket>`, `--storage-size <size>`, `--access-key`, `--secret-key`, `--skip-data-connection`, `--data-connection-ns <ns>` |

## 10. Utility

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `manage-kubeconfig.sh` | Interactive kubeconfig management (show, clear, set, logout) | `--show`, `--clear`, `--set`, `--logout` |
| `refresh-aws-credentials.sh` | Prompt-based AWS credentials refresh for demo platforms with temporary creds | *(interactive — prompts for key/secret/token)* |
| `setup-users.sh` | Create demo users (htpasswd), organize into groups, optionally create MaaS subscriptions | `--num-users <N>`, `--admin-group <name>`, `--user-group <name>`, `--password <pw>`, `--create-subscription`, `--model-name <name>`, `--model-namespace <ns>` |
| `clone-toolkit-in-workbenches.sh` | Retry the rhoai-toolkit git clone in workbench pods that weren't Running at deploy time | `-n <ns1,ns2>`, `--all-ns` |
| `refresh-notebook-env.sh` | Re-detect model endpoints and update workbench notebook-env ConfigMaps | `<namespace>`, `--all`, `--list` |
| `setup-mcp-servers.sh` | Configure MCP (Model Context Protocol) servers for GenAI Playground (GitHub, K8s, Brave, etc.) | *(interactive — prompts for server selection and API keys)* |
| `manage-mcp-servers.sh` | Deploy/register/status/tools for MCP server pods (AI Asset + LlamaStack registration) | `deploy <name>`, `register <name>`, `status`, `tools` (or interactive menu) |

## 11. Orchestration

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `integrated-workflow-v2.sh` | End-to-end orchestration: OpenShift cluster → GPU nodes → RHOAI → Playground + dashboard | `--skip-openshift`, `--skip-gpu`, `--skip-rhoai` |
| `deploy-demo-environment.sh` | Deploy all demo components on an existing RHOAI 3.4+ cluster (17 components) | `--skip-core`, `--components <list>`, `--exclude <list>`, `--model <name>`, `--list`, `--status` |
| `setup-node-scheduler.sh` | CronJob-based worker/GPU node scheduling (8 AM up, 6 PM down, Mon-Fri, Asia/Singapore) | `--trigger up\|down`, `--extend <duration>`, `--hold-status`, `--cancel-hold`, `--status`, `--remove` |

---

## Typical Usage Flows

### Fresh Installation (Recommended)
```bash
./scripts/install-rhoai-35.sh               # Full RHOAI 3.5 install
./scripts/create-gpu-machineset.sh           # Add GPU nodes
./scripts/deploy-maas-model.sh --model auto  # Deploy a model
```

### Existing Cluster — Add MaaS
```bash
./scripts/setup-maas.sh                      # RHCL + Gateway + PostgreSQL + DSC
./scripts/deploy-maas-model.sh --model simulator   # Verify with simulator
./scripts/verify-maas.sh                     # E2E verification
```

### Demo Environment
```bash
./scripts/deploy-demo-environment.sh --skip-core --list   # See components
./scripts/deploy-demo-environment.sh --skip-core           # Deploy all
```

### Cleanup
```bash
./scripts/cleanup-maas.sh --dry-run          # Preview MaaS teardown
./scripts/cleanup-all.sh                     # Full cluster + AWS cleanup
```

## Notes

- All scripts are idempotent (safe to run repeatedly)
- Scripts check for existing resources before creating
- Most scripts require `oc login` to an OpenShift cluster
- Run from the repository root directory
- See `docs/TROUBLESHOOTING.md` for common issues
