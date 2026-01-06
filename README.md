# OpenShift AI Installation Toolkit

A comprehensive toolkit for installing and configuring **OpenShift** with **Red Hat OpenShift AI (RHOAI) 3.0** on AWS, including GPU support, Model as a Service (MaaS), and GenAI capabilities.

## Quick Start

```bash
# Run the interactive setup
./complete-setup.sh
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
| **RHOAI 3.0** | Full RHOAI installation with Kueue, LWS, and Hardware Profiles |
| **MaaS API** | Model as a Service with authentication via Kuadrant |
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
├── complete-setup.sh           # Main interactive setup script
├── FEATURES.md                 # Feature quick reference
├── QUICK-REFERENCE.md          # Common commands cheat sheet
│
├── scripts/                    # Utility scripts
│   ├── create-gpu-machineset.sh
│   ├── setup-maas.sh
│   ├── cleanup-all.sh
│   └── ...
│
├── lib/                        # Shared libraries
│   ├── functions/              # Reusable functions
│   ├── manifests/              # Kubernetes manifests
│   └── utils/                  # Utility libraries
│
├── docs/                       # Documentation
│   ├── guides/                 # How-to guides
│   ├── reference/              # Reference documentation
│   ├── fixes/                  # Fix documentation
│   └── TROUBLESHOOTING.md
│
├── demo/                       # Demo applications
│   └── llamastack-demo/        # Chatbot frontend
│
├── diagnostics/                # Diagnostic scripts
└── archive/                    # Legacy/deprecated files
```

---

## Usage

### Full Installation

```bash
./complete-setup.sh
```

Select from the menu:
1. **OpenShift Installation** - Install cluster on AWS
2. **RHOAI Management** - Install/configure RHOAI
3. **GPU Management** - Create GPU nodes
4. **Model Deployment** - Deploy AI models
5. **Configure Kubeconfig** - Manage cluster connections

### Individual Operations

```bash
# Create GPU nodes
./scripts/create-gpu-machineset.sh

# Set up MaaS API
./scripts/setup-maas.sh

# Deploy a model
./scripts/deploy-llmd-model.sh

# Clean up resources
./scripts/cleanup-all.sh
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [FEATURES.md](FEATURES.md) | Quick feature reference |
| [QUICK-REFERENCE.md](QUICK-REFERENCE.md) | Common commands |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Problem solving |
| [docs/guides/](docs/guides/) | Step-by-step guides |
| [docs/reference/](docs/reference/) | Technical reference |

### Key Guides

- [Hardware Profile Setup](docs/guides/HARDWARE-PROFILE-SETUP.md)
- [GPU Taints Configuration](docs/guides/GPU-TAINTS-RHOAI3.md)
- [MaaS Setup](docs/guides/MAAS-SERVING-RUNTIMES.md)
- [Tool Calling](docs/guides/TOOL-CALLING-GUIDE.md)
- [Configuration Reuse](docs/guides/CONFIGURATION-REUSE.md)

---

## Typical Workflow

### 1. Install OpenShift Cluster

```bash
./complete-setup.sh
# Select: 1) OpenShift Installation → 1) Install New Cluster
```

### 2. Install RHOAI

```bash
./complete-setup.sh
# Select: 2) RHOAI Management → 1) Install RHOAI
```

### 3. Add GPU Nodes

```bash
./complete-setup.sh
# Select: 3) GPU Management → 1) Create GPU MachineSet
```

### 4. Deploy a Model

```bash
./complete-setup.sh
# Select: 4) Model Deployment → 1) Deploy Model
```

---

## Requirements

### Software

| Tool | Version | Purpose |
|------|---------|---------|
| `oc` | 4.14+ | OpenShift CLI |
| `aws` | 2.x | AWS CLI |
| `jq` | 1.6+ | JSON processing |
| `yq` | 4.x | YAML processing |

### AWS Resources

- VPC with public/private subnets (or let installer create)
- Route53 hosted zone
- Service quotas for chosen instance types

---

## Troubleshooting

### Common Issues

**Cluster connection issues:**
```bash
./complete-setup.sh
# Select: 5) Configure Kubeconfig
```

**GPU nodes not ready:**
```bash
oc get nodes -l nvidia.com/gpu.present=true
oc get machineset -n openshift-machine-api
```

**Model deployment failures:**
```bash
oc get inferenceservice -A
oc describe inferenceservice <name> -n <namespace>
```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more solutions.

---

## Contributing

1. Scripts should use the OS compatibility layer (`lib/utils/os-compat.sh`)
2. Follow existing code style and patterns
3. Update documentation when adding features
4. Test on both macOS and Linux

---

## License

Apache License 2.0

---

## External Resources

- [RHOAI 3.0 Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0)
- [OpenShift Documentation](https://docs.openshift.com)
- [Kueue Documentation](https://kueue.sigs.k8s.io/)
- [KServe Documentation](https://kserve.github.io/website/)
