# RHOAI Toolkit

End-to-end automation for installing and configuring **Red Hat OpenShift AI (RHOAI)** on AWS, including GPU support, Models as a Service (MaaS), MCP servers, and TLS certificate management.

> **[한국어 설치 가이드](setup-guide_KO.md)** | **[English Setup Guide](setup-guide_EN.md)**

---

## Quick Start

```bash
# 1. Clone and enter
git clone <repo-url> && cd RHOAI-Toolkit

# 2. Configure AWS credentials
aws configure

# 3. Launch the toolkit
./rhoai-toolkit.sh
```

---

## What Gets Installed

Option **3) Install RHOAI 3.x** installs the full stack automatically:

| Component | Description |
|-----------|-------------|
| NFD Operator | Node Feature Discovery (GPU detection) |
| NVIDIA GPU Operator | GPU drivers and runtime |
| Kueue (RHBOK) | Workload scheduling with quota management |
| cert-manager | Certificate management |
| LWS Operator | LeaderWorkerSet for llm-d distributed inference |
| JobSet Operator | Required for Kubeflow Trainer v2 |
| RHCL (Kuadrant) | API gateway, auth, rate limiting for MaaS |
| RHOAI 3.4 Operator | Red Hat OpenShift AI platform |
| DataScienceCluster | All AI/ML components configured |
| Observability Stack | COO, OpenTelemetry, Tempo, Grafana dashboards |
| MCP Gateway + Servers | Model Context Protocol server catalog |
| Dashboard Features | All RHOAI 3.4 feature flags enabled |

---

## Main Menu

```
RHOAI 3.x (Current):
  1) Complete Setup (OpenShift + RHOAI 3.x + GPU + MaaS) [From Scratch]
  2) Minimal RHOAI 3.x Setup (choose operators) [Flexible]
  3) Install RHOAI 3.x (all prerequisites + MaaS included) [Recommended]

RHOAI 2.x / Workshop:
  4) Workshop Demo Setup (RHOAI 2.25 + GenAI Workshop)
  5) Install RHOAI 2.x Only

Management & Tools:
  6) RHOAI Management (configure features, deploy models, etc.)
  7) Create GPU MachineSet
  8) GPU & ClusterPolicy Management
  9) Configure Kubeconfig
  a) TLS Certificate Setup (Let's Encrypt / Self-signed)
  h) Help
  0) Exit
```

---

## Key Workflows

### New Cluster (from scratch)
```bash
./rhoai-toolkit.sh   # Select 1) Complete Setup
```
Installs OpenShift on AWS, creates GPU nodes, then runs full RHOAI 3.x installation.

### Existing Cluster
```bash
./rhoai-toolkit.sh   # Select 3) Install RHOAI 3.x
```
Detects cluster, installs all prerequisites and RHOAI. Idempotent - safe to re-run.

### Deploy a Model
```bash
./scripts/serve-model.sh                    # Interactive preset menu
./scripts/serve-model.sh oci qwen3-4b oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b
./scripts/serve-model.sh hf gemma4-e2b google/gemma-4-E2B-it
```

### Setup TLS Certificates
```bash
./rhoai-toolkit.sh   # Select a) TLS Certificate Setup
# Or directly:
./scripts/setup-letsencrypt-tls.sh
```
Supports Let's Encrypt (Route53 DNS-01) and self-signed certificates.
Applies to Ingress Router, Gateway API, and KServe.

### Manage Cluster Instances (AWS)
```bash
./restart-cluster-instances.sh status    # Check instance status
./restart-cluster-instances.sh restart   # Full restart with CSR approval
./restart-cluster-instances.sh stop      # Stop all instances
```

---

## Directory Structure

```
├── rhoai-toolkit.sh              # Main interactive menu
├── setup-guide_EN.md             # English step-by-step guide
├── setup-guide_KO.md             # Korean step-by-step guide
├── scripts/
│   ├── install-rhoai-34.sh       # RHOAI 3.4 full installer
│   ├── install-rhoai-33.sh       # RHOAI 3.3 installer
│   ├── serve-model.sh            # Model deployment (OCI/S3/PVC/HF)
│   ├── create-gpu-machineset.sh  # GPU node creation (AWS)
│   ├── setup-maas.sh             # MaaS API gateway setup
│   ├── setup-letsencrypt-tls.sh  # TLS certificate management
│   ├── deploy-mcp-servers.sh     # MCP server deployment
│   └── ...                       # 30+ utility scripts
├── lib/
│   ├── functions/                # Reusable bash functions
│   ├── manifests/                # Kubernetes YAML manifests
│   │   ├── operators/            # NFD, GPU, Kueue, LWS, etc.
│   │   ├── rhoai/                # DataScienceCluster configs
│   │   ├── tls/                  # Let's Encrypt templates
│   │   ├── mcp/                  # MCP Gateway + server manifests
│   │   └── ...
│   └── utils/                    # OS compat, colors, config
├── demo/                         # Demo applications
│   ├── maas-demo/                # MaaS interactive demo
│   ├── llamastack-demo/          # LlamaStack chatbot
│   └── guardrails-demo/          # TrustyAI guardrails
├── docs/                         # Documentation
│   ├── guides/                   # How-to guides
│   └── TROUBLESHOOTING.md        # Common issues
└── diagnostics/                  # Diagnostic scripts
```

---

## RHOAI Versions Supported

| Version | Use Case |
|---------|----------|
| **RHOAI 3.4** | Latest GA - MaaS GA, MLflow GA, MCP Catalog, Trainer v2 |
| RHOAI 3.3 | MaaS TP, llm-d, Llama Stack 0.4.2 |
| RHOAI 2.25 | Workshops, demos |

---

## Dashboard Features (RHOAI 3.4)

The installer automatically enables all dashboard features:

- **Gen AI Studio** - Playground, prompt management, AI asset endpoints
- **Models as a Service** - Subscription-based model governance with API keys
- **MCP Catalog** - Browse and deploy MCP servers from AI Hub
- **Observability Dashboard** - Monitor model performance and cluster health
- **Gateway Discovery** - Select gateways during model deployment
- **Kueue Integration** - Hardware profile selection with quota management

---

## Prerequisites

- **OpenShift 4.19+** (or AWS account for new cluster)
- **AWS credentials** (Access Key, Secret Key, Route53 domain)
- **OpenShift Pull Secret** ([download](https://console.redhat.com/openshift/install/pull-secret))
- **CLI tools**: `oc`, `aws`, `jq`, `yq`

---

## Documentation

| Document | Description |
|----------|-------------|
| [Setup Guide (EN)](setup-guide_EN.md) | Step-by-step English guide |
| [Setup Guide (KO)](setup-guide_KO.md) | Step-by-step Korean guide |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues and fixes |
| [Quick Reference](QUICK-REFERENCE.md) | Command cheat sheet |
| [Features](FEATURES.md) | Feature reference |
