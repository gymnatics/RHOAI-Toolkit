# OpenShift Installation & RHOAI Setup

Automated scripts for installing OpenShift on AWS with Red Hat OpenShift AI (RHOAI), GPU workers, GenAI Playground, and Model as a Service (MaaS).

## 🎯 Quick Start

### Complete Setup (Recommended)
```bash
./complete-setup.sh
```

**Interactive Menu Mode** (default when run without arguments):
1. **Complete Setup** - Full OpenShift + RHOAI + GPU + MaaS installation
2. **Create GPU Hardware Profile** - Interactive profile creation with custom resources
3. **Setup MaaS Only** - MaaS API infrastructure (assumes RHOAI exists)
4. **Exit**

**Non-Interactive Mode** (with command-line arguments):
- `--with-maas` - Automatically set up MaaS API (no prompt)
- `--skip-maas` - Skip MaaS API setup (no prompt)
- `--maas-only` - Only set up MaaS (skip OpenShift/RHOAI)
- `--skip-openshift` - Skip OpenShift installation (use existing cluster)
- `--skip-gpu` - Skip GPU worker node creation
- `--skip-rhoai` - Skip RHOAI installation
- `--legacy` - Use legacy/original version (scripts/integrated-workflow.sh)

### Direct Usage
```bash
# Modular version (default, recommended)
./integrated-workflow-v2.sh

# Legacy version (backup)
./scripts/integrated-workflow.sh
```

**Why Modular?**
- ✅ Cleaner code organization
- ✅ Reusable function modules in `lib/`
- ✅ Better maintainability
- ✅ Same functionality as the original

## 📁 Project Structure

```
.
├── complete-setup.sh                    # 🎯 Main entry point (uses modular by default)
├── integrated-workflow-v2.sh            # ⭐ Modular RHOAI workflow (DEFAULT)
│
├── lib/                                 # 📦 Modular functions and manifests
│   ├── functions/                       # Reusable function modules
│   │   ├── operators.sh                 # Operator installation functions
│   │   └── rhoai.sh                     # RHOAI-specific functions
│   ├── manifests/                       # YAML manifest files
│   │   ├── operators/                   # NFD, GPU operator manifests
│   │   ├── rhcl/                        # RHCL/Kuadrant manifests
│   │   └── rhoai/                       # RHOAI manifests
│   └── utils/                           # Utility functions
│       ├── colors.sh                    # Color definitions
│       └── common.sh                    # Common helper functions
│
├── scripts/                             # Utility & legacy scripts
│   ├── openshift-installer-master.sh    # OpenShift cluster installation
│   ├── integrated-workflow.sh           # Legacy RHOAI workflow (use --legacy)
│   ├── cleanup-all.sh                   # Clean up AWS resources
│   ├── create-gpu-machineset.sh         # Create GPU worker nodes
│   ├── enable-genai-maas.sh             # Enable GenAI Playground & MaaS UI
│   └── setup-maas.sh                    # MaaS API infrastructure
│
├── tests/                               # Test scripts
│   ├── test-audience-extraction.sh
│   └── test-audience-extraction-v2.sh
│
├── diagnostics/                         # Diagnostic tools
│   ├── diagnose-authorino.sh
│   └── check-operator-pod.sh
│
├── docs/                                # Documentation
│   ├── README.md                        # Detailed documentation
│   └── TROUBLESHOOTING.md               # Troubleshooting guide
│
└── archive/                             # Legacy/deprecated scripts
    ├── fix-macos-security.sh
    ├── fix-rhcl-operator.sh
    └── README.md
```

## 🔧 Individual Scripts

### Main Workflow Scripts

**Modular Version (Recommended - Default)**
```bash
./integrated-workflow-v2.sh [OPTIONS]

Options:
  --skip-openshift    Skip OpenShift installation
  --skip-gpu          Skip GPU worker node creation
  --skip-rhoai        Skip RHOAI installation
```
Uses modular functions from `lib/` - cleaner and more maintainable.

**Legacy Version (Backup)**
```bash
./scripts/integrated-workflow.sh [OPTIONS]
```
Original monolithic version - still works, kept for compatibility.

### Utility Scripts
```bash
./scripts/openshift-installer-master.sh  # OpenShift cluster installation
./scripts/create-gpu-machineset.sh       # Create GPU worker nodes
./scripts/enable-genai-maas.sh           # Enable GenAI & MaaS UI
./scripts/setup-maas.sh                  # Set up MaaS API infrastructure
./scripts/cleanup-all.sh                 # Clean up AWS resources
```

See `scripts/README.md` and `lib/README.md` for detailed documentation.

## 📋 Prerequisites

### Required Tools
- AWS CLI configured with credentials
- `oc` (OpenShift CLI)
- `jq` (for JSON parsing)
- `git`

### AWS Requirements
- Valid AWS account with appropriate permissions
- Route53 hosted zone for DNS
- Sufficient service quotas (Elastic IPs, EC2 instances, VPCs)
- Access to GPU instance types in your region (p5.48xlarge, g6e.*)

### Red Hat Requirements
- Red Hat pull secret (from https://console.redhat.com/openshift/install/pull-secret)
- SSH public key for cluster access

## 🚀 Usage Examples

### Fresh Installation
```bash
# Complete setup with MaaS
./complete-setup.sh --with-maas

# Or interactive (will prompt for MaaS)
./complete-setup.sh
```

### Existing RHOAI Installation
```bash
# Enable GenAI and MaaS features
./scripts/enable-genai-maas.sh

# Set up MaaS API
./scripts/setup-maas.sh

# Create GPU nodes
./scripts/create-gpu-machineset.sh
```

### Step-by-Step Installation
```bash
# 1. Install OpenShift + RHOAI + GenAI/MaaS
./scripts/integrated-workflow.sh

# 2. Create GPU nodes
./scripts/create-gpu-machineset.sh

# 3. Set up MaaS API (optional)
./scripts/setup-maas.sh
```

### Cleanup
```bash
# Clean up all AWS resources
./scripts/cleanup-all.sh
```

## 📖 What Gets Installed

### OpenShift Components
- OpenShift 4.19+ cluster on AWS
- VPC with public and private subnets
- NAT Gateways and Internet Gateway
- Route53 DNS configuration
- Master and worker nodes

### RHOAI Components
- Node Feature Discovery (NFD)
- NVIDIA GPU Operator
- Red Hat OpenShift AI Operator
- Service Mesh 3.x (auto-installed)
- Serverless (Knative) (auto-installed)
- Red Hat Connectivity Link (RHCL/Kuadrant)
- Leader Worker Set (LWS) Operator
- Kueue Operator

### GenAI & MaaS Features
- GenAI Playground UI
- Model as a Service UI
- `llm-d` serving runtime
- GPU hardware profiles
- MaaS API infrastructure (optional)
- Authentication policies (Authorino)
- Rate limiting (Limitador)

## 🔍 Key Features

- **Interactive Prompts**: Guides you through configuration
- **Version Selection**: Choose OpenShift and RHOAI versions
- **GPU Support**: Automated GPU worker node creation (p5.48xlarge, g6e.*)
- **Idempotent**: Safe to run multiple times
- **Comprehensive Cleanup**: Handles complex AWS resource dependencies
- **Dynamic Configuration**: Adapts to your cluster and AWS environment
- **Skip Flags**: Skip components you've already installed

## 📚 Documentation

- **Detailed Guide**: See `docs/README.md` for comprehensive documentation
- **Troubleshooting**: See `docs/TROUBLESHOOTING.md` for common issues
- **Script Documentation**: See `scripts/README.md` for utility script details

## 🛠️ Troubleshooting

### GPU Hardware Profiles

**Create Hardware Profile Interactively** 🆕
```bash
./complete-setup.sh
# Select option 2: Create GPU Hardware Profile
```
This interactive wizard will prompt you for:
- Target namespace
- CPU resources (default, min, max)
- Memory resources (default, min, max)
- GPU resources (default, min, max)
- Profile name and display name

**Or use the standalone script:**
```bash
./scripts/create-hardware-profile.sh [namespace]
```

**Fix Existing Profile:**
```bash
./scripts/fix-hardware-profile.sh
```

See `docs/HARDWARE-PROFILE-FIX.md` for complete troubleshooting guide.

### Common Issues

**GPU Hardware Profile Not Visible in Model Deployment UI** ⚠️
```bash
./scripts/fix-hardware-profile.sh
```
See `docs/HARDWARE-PROFILE-TROUBLESHOOTING.md` for details.

**macOS Security Warning**
```bash
xattr -d com.apple.quarantine openshift-install
chmod +x openshift-install
```

**Pull Secret Issues**
- Use the file path option instead of pasting
- Ensure no extra whitespace or newlines

**AWS Quota Limits**
- Check Elastic IP limits (default: 5 per region)
- Request quota increases if needed

**Operator Installation Failures**
- Scripts are idempotent - safe to re-run
- Check operator logs: `oc logs -n openshift-operators <pod-name>`

For more troubleshooting, see `docs/TROUBLESHOOTING.md`.

## 🤝 Contributing

This is a personal automation project. Feel free to fork and adapt to your needs.

## 📝 License

MIT License - See LICENSE file for details.

## ⚠️ Important Notes

- **Costs**: Running OpenShift on AWS incurs costs. Monitor your AWS billing.
- **Security**: Never commit sensitive files (pull secrets, SSH keys, cluster configs).
- **Cleanup**: Always run `./scripts/cleanup-all.sh` when done to avoid unnecessary charges.
- **Long-Running**: Installation can take 45-60 minutes. Use `tmux` or `caffeinate` on macOS.

## 🎓 Learning Resources

- [OpenShift Documentation](https://docs.openshift.com/)
- [RHOAI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai/)
- [AWS OpenShift Guide](https://docs.openshift.com/container-platform/latest/installing/installing_aws/preparing-to-install-on-aws.html)
