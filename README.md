# OpenShift + RHOAI Installation Scripts

Automated installation scripts for OpenShift clusters with Red Hat OpenShift AI (RHOAI), GPU support, and Model as a Service (MaaS).

## 🚀 Quick Start

### For New Installations

```bash
# Full installation (OpenShift + GPU + RHOAI + MaaS)
./integrated-workflow.sh

# Or use the complete setup wrapper
./complete-setup.sh
```

### For Existing Clusters

```bash
# Install RHOAI on existing cluster
./integrated-workflow.sh --skip-openshift --skip-gpu

# Enable GenAI and MaaS features
./enable-genai-maas.sh

# Set up MaaS API infrastructure
./setup-maas.sh
```

## 📁 Project Structure

```
.
├── Main Installation Scripts
│   ├── openshift-installer-master.sh    # OpenShift cluster installation
│   ├── integrated-workflow.sh           # Complete RHOAI + GPU setup
│   ├── complete-setup.sh                # Master wrapper script
│   ├── enable-genai-maas.sh             # Enable GenAI Playground & MaaS UI
│   └── setup-maas.sh                    # MaaS API infrastructure
│
├── Utility Scripts
│   ├── create-gpu-machineset.sh         # Create GPU worker nodes
│   ├── cleanup-all.sh                   # Clean up AWS resources
│   └── fix-rhcl-operator.sh             # Fix RHCL operator issues
│
├── tests/                               # Test scripts
│   ├── test-audience-extraction.sh
│   └── test-audience-extraction-v2.sh
│
├── diagnostics/                         # Diagnostic tools
│   ├── diagnose-authorino.sh
│   └── check-operator-pod.sh
│
└── docs/                                # Documentation
    ├── README.md                        # Detailed documentation
    └── TROUBLESHOOTING.md               # Troubleshooting guide
```

## 🎯 Main Scripts

### 1. OpenShift Installation
```bash
./openshift-installer-master.sh
```
Interactive script to install OpenShift on AWS with GPU-capable regions.

### 2. Integrated Workflow (RHOAI + GPU)
```bash
./integrated-workflow.sh [OPTIONS]

Options:
  --skip-openshift    Skip OpenShift installation
  --skip-gpu          Skip GPU worker node creation
  --skip-rhoai        Skip RHOAI installation
```
Installs complete RHOAI stack with:
- Node Feature Discovery (NFD)
- NVIDIA GPU Operator
- Red Hat Connectivity Link (RHCL/Kuadrant)
- Red Hat OpenShift AI
- GenAI Playground
- Model as a Service (MaaS) UI

### 3. Complete Setup (Master Wrapper)
```bash
./complete-setup.sh [OPTIONS]

Options:
  --with-maas         Automatically set up MaaS API
  --skip-maas         Skip MaaS API setup prompt
  --maas-only         Only set up MaaS (skip OpenShift/RHOAI)
```
Orchestrates the entire installation process.

### 4. Enable GenAI & MaaS Features
```bash
./enable-genai-maas.sh
```
For existing RHOAI installations - enables:
- GenAI Playground
- Model as a Service UI
- Required operators (LWS, Kueue)

### 5. MaaS API Setup
```bash
./setup-maas.sh
```
Sets up MaaS API infrastructure:
- RHCL/Kuadrant operators
- Gateway and routes
- Authentication policies
- MaaS API deployment

## 🔧 Utility Scripts

### Create GPU MachineSet
```bash
./create-gpu-machineset.sh
```
Interactive script to create GPU worker nodes with dynamic cluster detection.

### Cleanup Resources
```bash
./cleanup-all.sh
```
Comprehensive cleanup of AWS resources (VPCs, subnets, NAT gateways, etc.).

### Fix RHCL Operator
```bash
./fix-rhcl-operator.sh
```
Fixes RHCL operator installation issues (OperatorGroup configuration).

## 📚 Documentation

- **[Detailed Documentation](docs/README.md)** - Complete setup guide
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## 🧪 Testing & Diagnostics

### Test Scripts (`tests/`)
- `test-audience-extraction.sh` - Test JWT token audience extraction
- `test-audience-extraction-v2.sh` - Test with base64 padding fix

### Diagnostic Scripts (`diagnostics/`)
- `diagnose-authorino.sh` - Diagnose Authorino/RHCL issues
- `check-operator-pod.sh` - Check operator pod status

## ⚙️ Prerequisites

- **macOS or Linux** with bash
- **AWS Account** with appropriate permissions
- **OpenShift CLI** (`oc`)
- **AWS CLI** configured
- **jq** for JSON parsing (`brew install jq`)
- **Red Hat Pull Secret** from console.redhat.com

## 🎓 Supported Versions

- **OpenShift**: 4.19+
- **RHOAI**: 2.17 - 3.0
- **GPU Instances**: H100 (p5.48xlarge), L40S (g6e.*)

## 🔗 Quick Links

- [OpenShift Documentation](https://docs.openshift.com/)
- [RHOAI Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/)
- [GitHub Repository](https://github.com/gymnatics/openshift-installation)

## 📝 Example Workflows

### Fresh Installation
```bash
# 1. Install OpenShift + RHOAI + GPU + MaaS
./complete-setup.sh --with-maas

# 2. Create additional GPU nodes
./create-gpu-machineset.sh

# 3. Deploy a model with MaaS enabled
# (Use RHOAI Dashboard)
```

### Existing Cluster
```bash
# 1. Install RHOAI
./integrated-workflow.sh --skip-openshift

# 2. Set up MaaS
./setup-maas.sh

# 3. Deploy models
# (Use RHOAI Dashboard)
```

### Troubleshooting
```bash
# Diagnose RHCL/Authorino issues
./diagnostics/diagnose-authorino.sh

# Fix RHCL operator
./fix-rhcl-operator.sh

# Check operator status
./diagnostics/check-operator-pod.sh
```

## 🤝 Contributing

This is a personal project for automating OpenShift + RHOAI installations. Feel free to fork and adapt for your needs!

## 📄 License

MIT License - See repository for details.

## 🆘 Support

For issues and questions:
1. Check [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
2. Review script output and logs
3. Use diagnostic scripts in `diagnostics/`
4. Open an issue on GitHub

---

**Last Updated**: November 2025
**Maintained By**: gymnatics

