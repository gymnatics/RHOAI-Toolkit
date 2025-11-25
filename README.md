# OpenShift AI Installation & Setup

Automated installation and configuration of Red Hat OpenShift AI (RHOAI) 3.0 on AWS with GPU support.

## Quick Start

```bash
# Complete setup (OpenShift + RHOAI + GPU + MaaS)
./complete-setup.sh

# Or use the interactive menu
./complete-setup.sh
# Then select: 1) Complete Setup
```

## What This Does

- ✅ Installs OpenShift 4.19 on AWS (us-east-2)
- ✅ Configures GPU support (NVIDIA H100, L40S, etc.)
- ✅ Installs RHOAI 3.0 with all operators
- ✅ Sets up hardware profiles for model deployment
- ✅ Configures Kueue for resource management
- ✅ Optional: MaaS (Model as a Service) setup

## Prerequisites

- macOS (Apple Silicon or Intel)
- AWS account with appropriate permissions
- Red Hat pull secret
- SSH key for OpenShift access

## Main Scripts

| Script | Purpose |
|--------|---------|
| `complete-setup.sh` | Master script with interactive menu |
| `scripts/openshift-installer-master.sh` | OpenShift installation |
| `scripts/create-gpu-machineset.sh` | Add GPU worker nodes |
| `scripts/create-hardware-profile.sh` | Create GPU hardware profiles |
| `scripts/cleanup-all.sh` | Clean up AWS resources |

## Hardware Profiles - IMPORTANT! 🎯

**If hardware profiles aren't showing in the dashboard**, read this:

📖 **[HARDWARE-PROFILE-FINAL-SOLUTION.md](HARDWARE-PROFILE-FINAL-SOLUTION.md)** ← **READ THIS FIRST**

Or see: [FEATURES.md](FEATURES.md) for a quick overview of all key features.

## Project Structure

```
.
├── complete-setup.sh              # Main entry point
├── README.md                      # This file
├── QUICK-REFERENCE.md            # Quick command reference
├── HARDWARE-PROFILE-FINAL-SOLUTION.md  # Hardware profile solution
├── HARDWARE-PROFILE-USAGE.md     # How to use hardware profiles
│
├── scripts/                      # Executable scripts
│   ├── openshift-installer-master.sh
│   ├── create-gpu-machineset.sh
│   ├── create-hardware-profile.sh
│   ├── cleanup-all.sh
│   └── setup-maas.sh
│
├── lib/                          # Reusable functions
│   ├── functions/                # Function libraries
│   │   ├── operators.sh
│   │   └── rhoai.sh
│   ├── manifests/                # Kubernetes manifests
│   │   ├── operators/
│   │   └── rhoai/
│   └── utils/                    # Utility functions
│       ├── colors.sh
│       └── common.sh
│
├── docs/                         # Detailed documentation
│   ├── INDEX.md                  # Documentation index
│   ├── README.md                 # Detailed setup guide
│   ├── TROUBLESHOOTING.md
│   ├── SETUP-COMPARISON.md
│   └── KSERVE-DEPLOYMENT-MODES.md
│
├── demo/                         # MaaS demo scripts
│   ├── README.md
│   ├── setup-demo-model.sh
│   ├── generate-maas-token.sh
│   └── test-maas-api.sh
│
├── tests/                        # Test scripts
├── diagnostics/                  # Diagnostic tools
└── archive/                      # Historical docs
```

## Common Tasks

### Install OpenShift + RHOAI

```bash
./complete-setup.sh
# Select: 1) Complete Setup
```

### Add GPU Worker Nodes

```bash
./scripts/create-gpu-machineset.sh
```

### Create Hardware Profile

```bash
./scripts/create-hardware-profile.sh <namespace>
```

### Setup MaaS

```bash
./scripts/setup-maas.sh
```

### Clean Up Everything

```bash
./scripts/cleanup-all.sh
```

## Troubleshooting

### Hardware Profiles Not Showing?

📖 Read: [HARDWARE-PROFILE-FINAL-SOLUTION.md](HARDWARE-PROFILE-FINAL-SOLUTION.md)

**TL;DR**: Hardware profiles in RHOAI 3.0 require a `scheduling` section:

```yaml
spec:
  scheduling:
    kueue:
      localQueueName: default
      priorityClass: None
    type: Queue
```

### Other Issues

- 📖 [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Common commands
- 📖 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Detailed troubleshooting
- 📖 [docs/INDEX.md](docs/INDEX.md) - Full documentation index

## Key Features

### ✅ Automated Installation
- One-command setup
- Interactive prompts for configuration
- Automatic prerequisite checks

### ✅ GPU Support
- NVIDIA GPU operator
- Node Feature Discovery (NFD)
- Dynamic MachineSet creation
- Hardware profiles for GPU workloads

### ✅ RHOAI 3.0
- Serverless + Kueue deployment mode
- Model deployment via Dashboard
- Auto-scaling and resource management
- GenAI Playground and Model Catalog

### ✅ MaaS (Optional)
- Model as a Service API
- Token-based authentication
- OpenAI-compatible endpoints
- Demo scripts included

## Configuration

### OpenShift Version

Default: 4.19 (configurable in installer script)

### AWS Region

Default: us-east-2 (supports H100 instances)

### GPU Instance Types

Supported:
- `p5.48xlarge` (H100)
- `g6e.xlarge`, `g6e.2xlarge`, `g6e.4xlarge` (L40S)
- Other NVIDIA GPU instances

### RHOAI Version

Default: 3.0 (`fast-3.x` channel)

## Documentation

### Essential Reading

1. 📖 [FEATURES.md](FEATURES.md) - **Key features overview**
2. 📖 [HARDWARE-PROFILE-FINAL-SOLUTION.md](HARDWARE-PROFILE-FINAL-SOLUTION.md) - Hardware profile solution
3. 📖 [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Quick commands
4. 📖 [docs/README.md](docs/README.md) - Complete documentation index

### Guides

- 📖 [docs/guides/GPU-TAINTS-RHOAI3.md](docs/guides/GPU-TAINTS-RHOAI3.md) - GPU taint configuration
- 📖 [docs/guides/TOOL-CALLING-GUIDE.md](docs/guides/TOOL-CALLING-GUIDE.md) - Enable function calling
- 📖 [docs/guides/MAAS-SERVING-RUNTIMES.md](docs/guides/MAAS-SERVING-RUNTIMES.md) - MaaS compatibility

### Reference

- 📖 [docs/reference/KSERVE-DEPLOYMENT-MODES.md](docs/reference/KSERVE-DEPLOYMENT-MODES.md) - Deployment modes
- 📖 [docs/reference/SETUP-COMPARISON.md](docs/reference/SETUP-COMPARISON.md) - Setup comparison

## Support

### Verification

```bash
# Check all operators
oc get csv -A | grep -E "nfd|gpu|kueue|lws|rhcl|rhods"

# Check DataScienceCluster
oc get datasciencecluster default-dsc

# Check hardware profiles
oc get hardwareprofiles -n redhat-ods-applications

# Check Kueue resources
oc get clusterqueue
oc get localqueue -n <namespace>
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Hardware profiles not showing | Read [HARDWARE-PROFILE-FINAL-SOLUTION.md](HARDWARE-PROFILE-FINAL-SOLUTION.md) |
| Kueue disabled | Check [docs/KUEUE-FIX-SUMMARY.md](docs/KUEUE-FIX-SUMMARY.md) |
| LWS operator failed | Check [docs/LWS-FIX-SUMMARY.md](docs/LWS-FIX-SUMMARY.md) |
| NFD pods failing | Check [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |

## Contributing

This is a personal project for OpenShift AI setup automation. Feel free to fork and adapt for your needs.

## License

MIT License - See LICENSE file for details

## References

- Red Hat OpenShift AI Documentation: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0
- Reference Repository: https://github.com/tsailiming/openshift-ai-bootstrap/tree/rhoai-3
- OpenShift Documentation: https://docs.openshift.com/

---

**Last Updated**: November 2025  
**RHOAI Version**: 3.0  
**OpenShift Version**: 4.19
