# OpenShift AI Installation Toolkit

A comprehensive toolkit for installing and configuring **OpenShift** with **Red Hat OpenShift AI (RHOAI) 3.x** on AWS, including GPU support, Model as a Service (MaaS), and GenAI capabilities.

> **Latest:** RHOAI 3.3 is now supported. See [What's New in RHOAI 3.3](docs/guides/RHOAI-33-WHATS-NEW.md) for details.

## Quick Start

```bash
./rhoai-toolkit.sh
```

This single command provides an interactive menu to:
- Install OpenShift cluster on AWS
- Set up RHOAI with all components
- Create GPU nodes
- Deploy AI models
- Configure MaaS API

---

## Features

| Feature | Description |
|---------|-------------|
| **One-Click Setup** | Interactive menu-driven installation |
| **GPU Support** | Automated GPU MachineSet creation (g6e, p5 instances) |
| **RHOAI 3.x** | Full RHOAI installation with Kueue, LWS, and Hardware Profiles |
| **Model Serving** | vLLM, vLLM-Omni (multimodal), llm-d, and community runtimes |
| **MaaS API** | Model as a Service with authentication via Kuadrant |
| **HuggingFace to S3** | Download models from HuggingFace to MinIO for deployment |
| **GenAI Playground** | Interactive model testing interface |
| **LlamaStack Demo** | Chatbot frontend with MCP tool calling |
| **Cross-Platform** | Works on macOS and Linux |

---

## Prerequisites

- **AWS Account** with appropriate permissions
- **OpenShift Pull Secret** from [console.redhat.com](https://console.redhat.com/openshift/install/pull-secret)
- **AWS CLI** configured (`aws configure`)
- **oc CLI** (OpenShift client)
- **Route53 Hosted Zone** for your domain

---

## Repository Structure

```
├── rhoai-toolkit.sh              # Main interactive setup script
├── scripts/                      # 32+ utility scripts
│   ├── create-gpu-machineset.sh  # GPU node creation (AWS)
│   ├── setup-maas.sh             # MaaS API gateway (version-aware)
│   ├── serve-model.sh            # Model deployment
│   ├── install-rhoai-33.sh       # RHOAI 3.3 full installation
│   ├── install-rhoai-minimal.sh  # Minimal RHOAI install
│   ├── deploy-llmd-model.sh      # llm-d model deployment
│   └── cleanup-all.sh            # Resource cleanup
│
├── lib/
│   ├── functions/                # Reusable bash functions
│   ├── manifests/                # Kubernetes YAML templates
│   └── utils/                    # Utility libraries (os-compat, colors, etc.)
│
├── docs/
│   ├── guides/                   # How-to guides
│   ├── reference/                # Technical reference
│   └── TROUBLESHOOTING.md        # Common issues and solutions
│
├── demo/
│   ├── maas-demo/                # MaaS demo with Streamlit
│   ├── llamastack-demo/          # Chatbot with MCP tool calling
│   └── guardrails-demo/          # AI safety demo
│
└── diagnostics/                  # Diagnostic scripts
```

---

## Usage

### Full Installation

```bash
./rhoai-toolkit.sh
```

Select from the menu:
1. **Complete Setup** - OpenShift + RHOAI 3.x + GPU + MaaS
2. **Minimal Setup** - Choose which operators to install
3. **Install RHOAI 3.3** - Recommended for new installs

### Individual Operations

```bash
# Create GPU nodes
./scripts/create-gpu-machineset.sh

# Set up MaaS API
./scripts/setup-maas.sh

# Deploy a model
./scripts/serve-model.sh

# Setup model storage (MinIO) and download from HuggingFace
./scripts/setup-model-storage.sh
./scripts/download-model.sh s3 Qwen/Qwen3-8B-Instruct

# Clean up resources
./scripts/cleanup-all.sh
```

---

## Supported Serving Runtimes

| Runtime | Use Case | CR Type | MaaS |
|---------|----------|---------|------|
| **vLLM (Red Hat)** | Text LLMs (default) | InferenceService | No |
| **vLLM (Community)** | Newer models (Qwen3.5, etc.) | InferenceService | No |
| **vLLM-Omni** | Multimodal: FLUX, SD3, audio | InferenceService | No |
| **llm-d** | MaaS, multi-replica | LLMInferenceService | Yes |

---

## Quick Reference

### Common Commands

```bash
# Full installation
./rhoai-toolkit.sh

# RHOAI 3.3 direct install
./scripts/install-rhoai-33.sh

# Add GPU nodes
./scripts/create-gpu-machineset.sh

# Create hardware profile
./scripts/create-hardware-profile.sh <namespace>

# Fix GPU tolerations
./scripts/fix-gpu-resourceflavor.sh

# Setup MaaS
./scripts/setup-maas.sh

# Clean up everything
./scripts/cleanup-all.sh
```

### Verification

```bash
# Check all operators
oc get csv -A | grep -E "nfd|gpu|kueue|lws|rhcl|rhods"

# Check RHOAI
oc get datasciencecluster

# Check hardware profiles
oc get hardwareprofiles -n redhat-ods-applications

# Check GPU nodes
oc get nodes -l nvidia.com/gpu.present=true

# Check MaaS (3.3+)
oc get gateway -n openshift-ingress

# Restart components
oc delete pod -n redhat-ods-applications -l app=odh-model-controller
oc delete pod -n kuadrant-system -l control-plane=controller-manager
```

### Operator Logs

```bash
oc logs -n redhat-ods-operator -l name=rhods-operator --tail=50
oc logs -n nvidia-gpu-operator -l app=gpu-operator --tail=50
oc logs -n kuadrant-system -l control-plane=controller-manager --tail=50
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [docs/guides/](docs/guides/) | Step-by-step guides |
| [docs/reference/](docs/reference/) | Technical reference |

### Key Guides

- [RHOAI 3.3 Installation](docs/guides/RHOAI-33-INSTALLATION.md)
- [What's New in RHOAI 3.3](docs/guides/RHOAI-33-WHATS-NEW.md)
- [Manual Installation Guide](docs/guides/RHOAI-MANUAL-INSTALLATION-GUIDE.md)
- [Hardware Profile Setup](docs/guides/HARDWARE-PROFILE-SETUP.md)
- [GPU Taints Configuration](docs/guides/GPU-TAINTS-RHOAI3.md)
- [MaaS Setup](docs/guides/MAAS-SETUP-STEP-BY-STEP.md)
- [Tool Calling](docs/guides/TOOL-CALLING-GUIDE.md)
- [llm-d Setup](docs/guides/LLMD-SETUP-GUIDE.md)

---

## Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| `oc` | 4.14+ | OpenShift CLI |
| `aws` | 2.x | AWS CLI |
| `jq` | 1.6+ | JSON processing |
| `yq` | 4.x | YAML processing |

---

## Contributing

1. Scripts should use the OS compatibility layer (`lib/utils/os-compat.sh`)
2. Follow existing code style and patterns
3. Update documentation when adding features
4. Test on both macOS and Linux

---

## External Resources

- [RHOAI 3.3 Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.3)
- [RHOAI Supported Configurations](https://access.redhat.com/articles/rhoai-supported-configs)
- [OpenShift Documentation](https://docs.openshift.com)
- [Kueue Documentation](https://kueue.sigs.k8s.io/)
- [KServe Documentation](https://kserve.github.io/website/)

---

**License:** Apache License 2.0
