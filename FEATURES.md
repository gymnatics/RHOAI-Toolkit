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
📖 [docs/guides/HARDWARE-PROFILE-SETUP.md](docs/guides/HARDWARE-PROFILE-SETUP.md)

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
4. Kubeconfig management
5. LlamaStack Demo UI deployment
6. Automatic detection of existing resources

### How to Use
```bash
./complete-setup.sh
```

### Main Menu Options
```
1) Complete Setup (OpenShift + RHOAI + GPU + MaaS) [Full]
2) Minimal RHOAI Setup (choose operators) [Flexible]
3) RHOAI Management (configure features, deploy models, etc.)
4) Create GPU MachineSet (add GPU nodes to existing cluster)
5) Configure Kubeconfig (login, set, or create kubeconfig) [Connection]
6) Help (show scripts and documentation)
7) Exit
```

### RHOAI Management Submenu
```
1) Enable Dashboard Features (Model Registry, GenAI Studio, etc.)
2) Deploy Model (interactive model deployment)
3) Add Model to Playground (test models interactively)
4) Setup MCP Servers (Model Context Protocol for tool calling)
5) Create GPU Hardware Profile (for model deployments)
6) Setup MaaS (Model as a Service API gateway)
7) Deploy LlamaStack Demo UI (chatbot frontend) [Demo]
8) Quick Start Wizard (run typical post-install workflow)
9) Approve Pending CSRs (Day 2 node management)
0) Back to Main Menu
```

### Features
- ✅ Automatic detection of existing OpenShift clusters
- ✅ Automatic detection of GPU nodes
- ✅ Automatic detection of RHOAI installation
- ✅ Interactive prompts with clear explanations
- ✅ Skip flags for advanced users
- ✅ Configuration reuse for faster reinstalls
- ✅ Kubeconfig management (login with token, switch configs)
- ✅ LlamaStack Demo UI deployment (chatbot frontend)

---

## 🤖 LlamaStack Demo UI

### What It Is
A Streamlit-based chatbot frontend that connects to LlamaStack and demonstrates MCP tool calling in real-time.

### Features
- ✅ **Fully Configurable** - All settings via environment variables
- ✅ **Works with Any MCP Server** - Not tied to specific tools
- ✅ **Custom System Prompts** - Define LLM behavior per deployment
- ✅ **Service Health Checks** - Real-time status for LlamaStack and MCP
- ✅ **Tool Discovery** - Automatically shows available tools from LlamaStack
- ✅ **Chat Interface** - Full conversation with tool call visualization

### How to Deploy
```bash
./complete-setup.sh
# Select: 3) RHOAI Management
# Select: 7) Deploy LlamaStack Demo UI
```

The script will:
1. Prompt for namespace, LlamaStack URL, Model ID, MCP Server URL
2. Auto-detect existing LlamaStack and MCP services
3. Build the container using OpenShift BuildConfig
4. Deploy the application with Route

### Configuration Options
| Variable | Description |
|----------|-------------|
| `LLAMASTACK_URL` | LlamaStack service endpoint |
| `MODEL_ID` | Model ID registered in LlamaStack |
| `MCP_SERVER_URL` | MCP server URL (for health checks) |
| `APP_TITLE` | Page title |
| `MCP_SERVER_NAME` | Name shown in architecture diagram |
| `SYSTEM_PROMPT` | Custom system prompt for the LLM |

### Full Documentation
📖 [demo/llamastack-demo/README.md](demo/llamastack-demo/README.md)

---

## 🔐 Kubeconfig Management

### What It Does
Interactive menu for managing OpenShift cluster connections without leaving the setup script.

### Options
1. **Login with token** - Paste `oc login --token=... --server=...` command
2. **Login with username/password** - For environments with password auth
3. **Set KUBECONFIG from existing file** - Pick from common locations
4. **Create new kubeconfig in workspace** - Creates `./kubeconfig`
5. **View current kubeconfig** - Shows config (tokens redacted)
6. **Test connection** - Verify connection and cluster info

### How to Use
```bash
./complete-setup.sh
# Select: 5) Configure Kubeconfig
```

### Why Use This?
- Quickly switch between clusters
- Save kubeconfig to workspace (portable)
- Add KUBECONFIG export to shell profile
- Test connection without leaving the menu

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

**Last Updated**: January 2026  
**RHOAI Version**: 3.0  
**OpenShift Version**: 4.19

