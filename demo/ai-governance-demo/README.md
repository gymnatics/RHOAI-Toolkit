# AI Governance Demo (launcher)

The demo itself lives in its own repo, [rhoai-ai-governance-demo](https://github.com/gymnatics/rhoai-ai-governance-demo) (private; ask for access). This folder only clones it and runs its scripts with the toolkit available (for example, the workbench helper and the toolkit-ops checks).

What the demo shows on RHOAI 3.5, with a fictional "Acme Bank" and four app teams:
- **Access:** catalog deploy, MaaS self-service API keys, per-app access control, live quota changes.
- **Cost:** chargeback per team and cost centre, budget alert at 80% with a cut-off at 100%.
- **Safety:** NeMo Guardrails PII masking (with an Indonesian identifier pack), prompt-injection defence, output-leak blocking, per-app policies.
- **Audit:** a read-only auditor trail in MLflow.

## Usage

```bash
oc login ...                                             # cluster admin
./demo/ai-governance-demo/deploy.sh                      # clone to ~/ai-governance-demo and run scripts/setup.sh --with-workbench
./demo/ai-governance-demo/deploy.sh --verify             # health check before a session
./demo/ai-governance-demo/deploy.sh --delete             # teardown; restores the cluster-wide settings it changed
```

| Option | Effect |
|---|---|
| `--repo URL` / `AIGOV_DEMO_REPO` | Repo to clone (default `https://github.com/gymnatics/rhoai-ai-governance-demo.git`; ignored if `--dir` already holds a checkout) |
| `--dir PATH` / `AIGOV_DEMO_DIR` | Checkout location (default `~/ai-governance-demo`) |
| `-n NS` | Demo namespace (default `ai-governance-demo`) |
| `--no-workbench` | Skip creating the JupyterLab workbench |
| anything else | Passed to `scripts/setup.sh` (e.g. `--gpu-nodes 2`, `--with-loki`, `--no-wait`) |

## Prerequisites

Everything below except the GPU can be installed with this toolkit:
- RHOAI 3.5 with MaaS, TrustyAI, MLflow and llm-d (`scripts/install-rhoai-35.sh`, `scripts/setup-maas.sh`)
- Keycloak (RHBK) as the cluster IdP
- user-workload monitoring with user alert routing
- at least one free NVIDIA GPU (`scripts/create-gpu-machineset.sh`)
- optional: SeaweedFS (`scripts/setup-model-storage.sh --backend seaweedfs`) for the Loki usage logs

After setup, open `RUN-THROUGH.local.html` in the demo checkout for the step-by-step run sheet.
