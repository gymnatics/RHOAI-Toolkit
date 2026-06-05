# RHOAI Full Demo Environment

Deploy all major RHOAI capabilities on a single cluster with one command, or pick and choose individual components.

## Quick Start

```bash
# Deploy everything (assumes RHOAI 3.4 is already installed)
./scripts/deploy-demo-environment.sh --skip-core

# Or via Makefile
make setup-demo-environment

# Or interactive menu
./rhoai-toolkit.sh → RHOAI Management → Demos → 16) Deploy Full Demo Environment
```

## Components

| # | Component | Namespace | Entry Point | GPU Required |
|---|-----------|-----------|-------------|--------------|
| 1 | Feast Banking Demo | demo | `deploy_banking_demo()` (toolkit) | No |
| 2 | MCP Server + AI Playground | demo | `scripts/setup-mcp-servers.sh` | No |
| 3 | MaaS (llm-d) | models-as-a-service | `scripts/deploy-llmd-model.sh` | Yes |
| 4 | Financial Loan Demo | financial-loan-demo | `demo/financial-loan-demo/deploy.sh` | Yes (fine-tuning) |
| 5 | AI Pipeline Demo | pipeline-demo | `demo/pipeline-demo/deploy.sh` | No |
| 6 | Open WebUI | open-webui | `demo/open-webui-demo/deploy.sh` | No |
| 7 | n8n | n8n | `demo/n8n-demo/deploy.sh` | No |
| 8 | Model Catalog | rhoai-model-registries | `scripts/manage-model-catalog.sh` | No |
| 9 | NeMo Guardrails | nemo-guardrails-demo | `demo/nemo-guardrails-demo/deploy.sh` | No (basic) / Yes (self-check) |
| 10 | LMEval + EvalHub (TP) | lmeval-demo | `demo/lmeval-demo/deploy.sh` | Yes (benchmarks) |
| 11 | MaaS Rate Limiting | maas-ratelimit-demo | `demo/maas-ratelimit-demo/deploy.sh` | No (uses API key) |
| 12 | AutoML (TP) | automl-demo | `demo/automl-demo/deploy.sh` | No (CPU training) |
| 13 | AutoRAG (TP) | autorag-demo | `demo/autorag-demo/deploy.sh` | Yes (LLM + embeddings) |
| 14 | Marketing Assistant | marketing-assistant | `demo/marketing-assistant-demo/deploy.sh` | Yes (3x L40S) |

Marketing Assistant Demo is **not** included in deploy-all due to heavy GPU requirements (3x L40S).

### Technology Preview Features

| Feature | What It Does | Dashboard Location | Key Prerequisites |
|---------|-------------|-------------------|-------------------|
| AutoML | Automated model training (AutoGluon + KFP) | Develop and train > AutoML | Pipeline Server, S3 data |
| AutoRAG | Automated RAG pipeline optimization | Develop and train > AutoRAG | Llama Stack, Milvus, Pipeline Server |
| EvalHub | Centralized LLM evaluation orchestration | Develop and train > Evaluations | TrustyAI Managed, `disableLMEval: false` |

## Individual Deployment

Every component can be deployed independently:

```bash
# Deploy specific components
./demo/n8n-demo/deploy.sh
./demo/financial-loan-demo/deploy.sh
./demo/pipeline-demo/deploy.sh
./demo/nemo-guardrails-demo/deploy.sh
./demo/lmeval-demo/deploy.sh
./demo/maas-ratelimit-demo/deploy.sh
./demo/automl-demo/deploy.sh
./demo/autorag-demo/deploy.sh
./demo/open-webui-demo/deploy.sh
./demo/marketing-assistant-demo/deploy.sh

# Standalone scripts
./scripts/deploy-nemo-guardrails.sh
./scripts/manage-model-catalog.sh

# Makefile targets
make deploy-n8n
make deploy-financial-loan
make deploy-pipeline-demo
make deploy-nemo-guardrails
make deploy-lmeval-lab
make deploy-maas-ratelimit
make deploy-automl
make deploy-autorag
make deploy-open-webui
make manage-model-catalog
```

## Selective Deployment

```bash
# Deploy only specific components
./scripts/deploy-demo-environment.sh --components feast,n8n,open-webui

# Deploy everything except heavy GPU demos
./scripts/deploy-demo-environment.sh --exclude marketing

# List available components
./scripts/deploy-demo-environment.sh --list
```

## External Repositories

Some demos clone external GitHub repos at deploy time. Configuration is in `lib/external-repos.conf`:

| Repo | Default Ref | Used By |
|------|-------------|---------|
| cbtham/micro-financial-loan | main | Financial Loan Demo (notebooks vendored locally) |
| gymnatics/Marketing-Assistant-Demo | main | Marketing Assistant |
| JPishikawa/demo-guardrail | main | NeMo Guardrails reference |
| hyogrin/rhoai-lmeval-builder-lab | main | LMEval Builder Lab (key notebooks vendored locally) |

Repos are cloned to `$HOME/.rhoai-demos/` and updated on each deploy. To pin a version, edit the ref in `lib/external-repos.conf`.

**Vendored Notebooks:** Key demo notebooks are vendored into this repo under `demo/*/notebooks/` with hardcoded cluster values replaced by environment variables. The deploy scripts auto-generate a `demo-config-env` ConfigMap with cluster-specific values. See `ATTRIBUTION.md` in each notebooks directory for original source credits.

## Architecture

```
scripts/deploy-demo-environment.sh    (master orchestrator)
  ├── demo/financial-loan-demo/deploy.sh
  ├── demo/pipeline-demo/deploy.sh
  ├── demo/open-webui-demo/deploy.sh
  ├── demo/n8n-demo/deploy.sh
  ├── demo/nemo-guardrails-demo/deploy.sh
  ├── demo/lmeval-demo/deploy.sh
  ├── demo/maas-ratelimit-demo/deploy.sh
  ├── demo/automl-demo/deploy.sh
  ├── demo/autorag-demo/deploy.sh
  └── (existing toolkit functions for feast, mcp, maas)

Each deploy.sh:
  ├── sources lib/utils/colors.sh + common.sh
  ├── sources lib/functions/*.sh
  ├── applies lib/manifests/**/*.yaml via envsubst
  └── self-contained, runs standalone
```

## GPU Requirements

**Minimum for everything to work: 1 GPU (L4 24GB or L40S 48GB)**

All GPU-dependent demos share a single model (e.g. Qwen3-4B) via the MaaS inference gateway. The deploy script auto-detects GPU availability and offers to deploy a shared model.

| What | GPU? | Why |
|------|------|-----|
| Shared model (Qwen3-4B) | 1 GPU | Serves all demos via MaaS gateway |
| Loan prediction (scikit-learn) | CPU | MLServer runtime |
| Loan LLM explanation | Shared | Calls Qwen3-4B via MaaS |
| Open WebUI | Shared | Connects to MaaS gateway |
| NeMo Guardrails (self-check) | Shared | Calls model for validation |
| LMEval benchmarks | Shared | Evaluates model endpoint |
| AI Playground / MCP | Shared | LlamaStack calls model |
| AutoML training | CPU | AutoGluon runs on CPU (4 CPU, 16 GiB) |
| AutoRAG optimization | Shared | Llama Stack calls model for generation |
| EvalHub evaluations | Shared | Evaluates model via providers |
| Feast, Pipeline, n8n, Catalog | None | No model needed |
| Marketing Assistant | 3x L40S | Dedicated (not in deploy-all) |

The deploy script checks for GPU nodes and deployed models at startup. If no model is found, it prompts you to deploy one.

## Prerequisites

- RHOAI 3.4 installed and configured
- `oc` CLI logged in to the cluster
- At least 1 GPU node for model serving (script will prompt if missing)
- For NeMo Guardrails: TrustyAI component enabled in DSC
- For LMEval/EvalHub: TrustyAI operator installed, `disableLMEval: false` in dashboard config
- For AutoML: AI Pipelines enabled (`aipipelines: Managed`)
- For AutoRAG: Llama Stack Operator (`llamastackoperator: Managed`), Milvus, Gen AI Studio

## Cleanup

Each demo supports `--delete`:

```bash
./demo/n8n-demo/deploy.sh --delete
./demo/financial-loan-demo/deploy.sh --delete
./demo/nemo-guardrails-demo/deploy.sh --delete
./demo/automl-demo/deploy.sh --delete
./demo/autorag-demo/deploy.sh --delete
```
