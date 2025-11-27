# Key Features Guide

Quick reference for the main features of this OpenShift AI installation toolkit.

## 🎯 Hardware Profiles

### What They Are
Hardware profiles define resource requirements (CPU, Memory, GPU) for model deployments in RHOAI 3.0.

### Critical Configuration
**MUST include this `scheduling` section**:
```yaml
spec:
  scheduling:
    kueue:
      localQueueName: default
      priorityClass: None
    type: Queue
```

Without this, profiles won't appear in the RHOAI dashboard!

### How to Create
```bash
# Interactive creation (prompts for resources)
./scripts/create-hardware-profile.sh <namespace>

# Or use the complete setup menu
./complete-setup.sh
# Select: 2) Create GPU Hardware Profile
```

### Where They Go
- **Global profiles**: `redhat-ods-applications` namespace (visible in all projects)
- **Project profiles**: Specific project namespace (visible only in that project)

### Full Documentation
📖 [HARDWARE-PROFILE-FINAL-SOLUTION.md](HARDWARE-PROFILE-FINAL-SOLUTION.md)

---

## 🔧 Interactive GPU Taint Detection

### What It Does
Automatically detects GPU nodes and their taint status, then configures the Kueue ResourceFlavor appropriately.

### When It Runs
- During installation (automatically)
- When you run `./scripts/fix-gpu-resourceflavor.sh`

### Interactive Prompts

#### If GPU Nodes Are Tainted:
```
✓ GPU nodes are tainted with nvidia.com/gpu:NoSchedule

Configure ResourceFlavor with GPU toleration? (Y/n):
```

#### If GPU Nodes Are NOT Tainted:
```
✓ GPU nodes are NOT tainted

Do you want to taint GPU nodes now? (y/N):
```

### Why Taint GPU Nodes?
1. **Cost savings**: Prevents non-GPU workloads on expensive GPU instances
2. **Resource protection**: Reserves GPU nodes for GPU workloads only
3. **Predictable scheduling**: GPU models always land on GPU nodes

### Full Documentation
📖 [INTERACTIVE-TAINT-FEATURE.md](INTERACTIVE-TAINT-FEATURE.md)  
📖 [docs/guides/GPU-TAINTS-RHOAI3.md](docs/guides/GPU-TAINTS-RHOAI3.md)

---

## 🛠️ Tool Calling (Function Calling)

### What It Is
Allows models to call external functions/tools during inference.

### Quick Setup for Qwen Models
Add this environment variable:
```yaml
env:
  - name: VLLM_ADDITIONAL_ARGS
    value: "--enable-auto-tool-choice --tool-call-parser=hermes"
```

### Model-Specific Parsers
| Model | Parser |
|-------|--------|
| Qwen (Qwen3-4B, Qwen3-8B) | `hermes` |
| Llama 3.2 | `llama3_json` |
| Mistral | `mistral` |

### Full Documentation
📖 [docs/guides/TOOL-CALLING-GUIDE.md](docs/guides/TOOL-CALLING-GUIDE.md)

---

## 🌐 Model as a Service (MaaS)

### What It Is
Centralized API gateway for serving models with authentication, rate limiting, and billing tracking.

### Key Limitation
**Only `llm-d` serving runtime works with MaaS through the UI.**

`vLLM` does NOT support MaaS through the dashboard.

### How to Enable
1. Deploy model with `llm-d` runtime
2. Check "Enable Model as a Service"
3. Check "Require authentication" (recommended)

### Full Documentation
📖 [docs/guides/MAAS-SERVING-RUNTIMES.md](docs/guides/MAAS-SERVING-RUNTIMES.md)  
📖 [demo/README.md](demo/README.md)

---

## 💾 Configuration Reuse

### What It Does
Saves your installation configuration so you don't have to re-enter the same details every time.

### What Gets Saved
- Cluster name and domain
- AWS region
- Master/Worker instance types
- VPC settings (new or existing)
- Subnet IDs

### How It Works
1. **First installation**: After configuration, you're asked to save settings
2. **Subsequent runs**: Automatically offers to reuse saved configuration
3. **Quick edits**: Option to modify specific values without re-entering everything

### Interactive Options
```
Would you like to use this saved configuration?

  1) Yes - Use saved configuration (quick)
  2) No - Enter new configuration
  3) Edit - Modify specific values
```

### Use Cases
- **Retry failed installations**: Quick cleanup and retry with same settings
- **Multiple clusters**: Deploy multiple clusters with similar configuration
- **Temporary environments**: Update only VPC/subnet IDs when switching AWS accounts

### Security
- Pull secrets and SSH keys stored separately (not in config file)
- Configuration file has secure permissions (chmod 600)
- Only non-sensitive settings are saved

### Full Documentation
📖 [docs/guides/CONFIGURATION-REUSE.md](docs/guides/CONFIGURATION-REUSE.md)

---

## 🚀 Complete Setup Script

### What It Does
Master script with interactive menu for:
1. Complete OpenShift + RHOAI installation
2. GPU hardware profile creation
3. MaaS setup
4. Automatic detection of existing resources

### How to Use
```bash
./complete-setup.sh
```

### Menu Options
```
1) Complete Setup - Full installation
2) Create GPU Hardware Profile - For existing clusters
3) Setup MaaS Only - Assumes RHOAI exists
4) Exit
```

### Features
- ✅ Automatic detection of existing OpenShift clusters
- ✅ Automatic detection of GPU nodes
- ✅ Automatic detection of RHOAI installation
- ✅ Interactive prompts with clear explanations
- ✅ Skip flags for advanced users
- ✅ Configuration reuse for faster reinstalls

---

## 🧹 Cleanup Script

### What It Does
Comprehensive cleanup of all AWS resources created during installation.

### What It Cleans
- OpenShift cluster (via `openshift-install destroy`)
- Elastic IPs (releases unassociated IPs)
- NAT Gateways (with proper wait for deletion)
- VPCs and subnets
- Security groups and network interfaces
- Route tables (including orphaned ones)

### How to Use
```bash
./scripts/cleanup-all.sh
```

### Safety Features
- Lists resources before deletion
- Asks for confirmation
- Provides detailed progress updates
- Handles dependencies correctly

---

## 📊 Quick Reference

### Common Commands
```bash
# Full installation
./complete-setup.sh

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

### Verification Commands
```bash
# Check all operators
oc get csv -A | grep -E "nfd|gpu|kueue|lws|rhcl|rhods"

# Check RHOAI
oc get datasciencecluster

# Check hardware profiles
oc get hardwareprofiles -n redhat-ods-applications

# Check GPU nodes
oc get nodes -l nvidia.com/gpu.present=true

# Check ResourceFlavor
oc get resourceflavor nvidia-gpu-flavor -o yaml
```

---

## 📚 More Information

- [README.md](README.md) - Main project documentation
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Command cheat sheet
- [docs/README.md](docs/README.md) - Complete documentation index
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Troubleshooting guide

---

**Last Updated**: November 2025  
**RHOAI Version**: 3.0  
**OpenShift Version**: 4.19

