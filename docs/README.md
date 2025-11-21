# OpenShift Installation with RHOAI

Automated scripts for installing OpenShift on AWS with Red Hat OpenShift AI (RHOAI) and GPU support.

## 🚀 Quick Start

### Full Installation (New Cluster)
```bash
./integrated-workflow.sh
```

This will:
1. Install OpenShift cluster on AWS
2. Create GPU worker nodes
3. Install RHOAI (you select version 2.17-3.0)

**Time**: 60-90 minutes

### Add RHOAI to Existing Cluster
```bash
export KUBECONFIG=/path/to/your/kubeconfig
./integrated-workflow.sh --skip-openshift
```

**Time**: 30-45 minutes

### Only Install RHOAI
```bash
export KUBECONFIG=/path/to/your/kubeconfig
./integrated-workflow.sh --skip-openshift --skip-gpu
```

**Time**: 20-30 minutes

## 📋 What Gets Installed

### OpenShift Cluster (Phase 1)
- VPC with public and private subnets
- NAT Gateways and Internet Gateway
- OpenShift 4.19+ cluster on AWS
- Cluster credentials saved to `cluster-info.txt`

### GPU Workers (Phase 2)
- GPU MachineSets with proper labels and taints
- Support for L40S (g6e) and H100 (p5) instances
- Customizable storage and replica count

### RHOAI (Phase 3)
- Node Feature Discovery (NFD)
- Nvidia GPU Operator
- Red Hat OpenShift AI (2.17 - 3.0)
- KServe for model serving
- Data Science Pipelines
- Workbenches with GPU support
- RHOAI Dashboard

## 📦 Scripts Overview

| Script | Purpose |
|--------|---------|
| `integrated-workflow.sh` | **Main script** - Full OpenShift + RHOAI installation |
| `openshift-installer-master.sh` | OpenShift cluster installation on AWS |
| `create-gpu-machineset.sh` | Create GPU worker nodes dynamically |
| `cleanup-all.sh` | Clean up all AWS resources |
| `fix-macos-security.sh` | Fix macOS security warnings |

## 🎯 RHOAI Version Selection

During installation, select from:

| Version | OpenShift | Channel | Notes |
|---------|-----------|---------|-------|
| 2.17-2.18 | 4.16+ | fast | Older |
| 2.19-2.21 | 4.17+ | stable | Stable |
| 2.22-2.23 | 4.18-4.19+ | stable-2.23 | Stable |
| 2.24-2.25 | 4.20+ | stable | Latest 2.x |
| **3.0** | **4.20+** | **fast-3.x** | **Latest** |

**Recommendations**:
- OpenShift 4.19 → Use RHOAI 2.23
- OpenShift 4.20+ → Use RHOAI 3.0

## 🔧 Prerequisites

### Required Tools
- `oc` - OpenShift CLI
- `aws` - AWS CLI (configured)
- `jq`, `yq` - JSON/YAML processors
- `make`, `git` - Build tools

### Required Credentials
- AWS account with admin permissions
- Red Hat pull secret
- SSH key (or script will generate one)

### AWS Permissions
- EC2, VPC, Route53, IAM
- Service quotas for GPU instances
- Elastic IP quota (at least 3)

## 📖 Detailed Usage

### Integrated Workflow Options

```bash
./integrated-workflow.sh [OPTIONS]

Options:
  --skip-openshift    Skip OpenShift cluster installation
  --skip-gpu          Skip GPU worker node creation
  --skip-rhoai        Skip RHOAI installation
  --help, -h          Show help message
```

### GPU Instance Types

| Instance | GPUs | Model | vCPUs | Memory | Use Case |
|----------|------|-------|-------|--------|----------|
| g6e.xlarge | 1 | L40S | 4 | 16 GB | Development |
| g6e.2xlarge | 1 | L40S | 8 | 32 GB | Small models |
| g6e.4xlarge | 1 | L40S | 16 | 64 GB | Medium models |
| g6e.12xlarge | 4 | L40S | 48 | 192 GB | Large models |
| p5.48xlarge | 8 | H100 | 192 | 2 TB | Largest models |

### Create Additional GPU Workers

```bash
./create-gpu-machineset.sh
```

The script will:
1. Extract cluster configuration automatically
2. Prompt for GPU instance type
3. Show available subnets from existing MachineSets
4. Configure storage (default or custom)
5. Set replica count
6. Generate and apply the MachineSet

## 🎓 Common Workflows

### 1. Fresh Installation
```bash
# Start installation
./integrated-workflow.sh

# Follow prompts:
# - Configure AWS credentials
# - Select RHOAI version
# - Configure GPU workers

# Access RHOAI Dashboard
oc get route rhods-dashboard -n redhat-ods-applications
```

### 2. Scale GPU Workers
```bash
# Scale existing MachineSet
oc scale machineset <gpu-machineset-name> --replicas=3 -n openshift-machine-api

# Or create new GPU MachineSet
./create-gpu-machineset.sh
```

### 3. Verify GPU Detection
```bash
# Check GPU nodes
oc get nodes -l node-role.kubernetes.io/gpu-worker

# Verify GPU capacity
oc get nodes -l node-role.kubernetes.io/gpu-worker \
  -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
```

### 4. Access RHOAI Dashboard
```bash
# Get dashboard URL
echo "https://$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}')"

# Login with cluster credentials (from cluster-info.txt)
```

## 🧹 Cleanup

### Remove Entire Cluster
```bash
./cleanup-all.sh
```

This will:
- Run `openshift-install destroy cluster`
- Release Elastic IPs
- Delete VPCs and subnets
- Clean up NAT Gateways
- Remove orphaned route tables

### Remove RHOAI Only
```bash
oc delete DataScienceCluster default-dsc
oc delete DSCInitialization default-dsci
oc delete subscription rhods-operator -n redhat-ods-operator
```

## 🛠️ Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed troubleshooting guide.

### Quick Fixes

**GPU Operator Not Ready**
```bash
oc get pods -n nvidia-gpu-operator
oc logs -n nvidia-gpu-operator -l app=nvidia-device-plugin-daemonset
```

**RHOAI Dashboard Not Accessible**
```bash
oc get pods -n redhat-ods-applications -l app=rhods-dashboard
oc logs -n redhat-ods-applications -l app=rhods-dashboard
```

**GPU Not Detected**
```bash
oc get nodes -l nvidia.com/gpu.present=true
oc describe node <gpu-node-name> | grep nvidia.com/gpu
```

## 📁 File Structure

```
openshift-installation/
├── integrated-workflow.sh          # Main automation script
├── openshift-installer-master.sh   # OpenShift installation
├── create-gpu-machineset.sh        # GPU MachineSet creation
├── cleanup-all.sh                  # Cleanup script
├── fix-macos-security.sh           # macOS security fix
├── cluster-info.txt                # Cluster credentials (generated)
├── README.md                       # This file
└── TROUBLESHOOTING.md              # Troubleshooting guide
```

## 🔒 Security Notes

- `pull-secret.txt` is gitignored (contains sensitive data)
- `cluster-info.txt` contains cluster credentials (gitignored)
- SSH keys are gitignored
- Never commit AWS credentials

## 💡 Best Practices

1. **Use tmux for long installations**
   ```bash
   tmux new -s openshift-install
   ./integrated-workflow.sh
   # Detach: Ctrl+B, then D
   ```

2. **Keep Mac awake during installation**
   ```bash
   caffeinate -d -i -m -u &
   ```

3. **Monitor installation progress**
   ```bash
   # Watch cluster operators
   watch oc get co
   
   # Watch RHOAI installation
   watch oc get pods -n redhat-ods-operator
   ```

4. **Save cluster credentials**
   - Credentials are saved to `cluster-info.txt`
   - Back up this file securely

## 📚 Resources

- [Red Hat OpenShift AI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai)
- [OpenShift Documentation](https://docs.openshift.com/)
- [Nvidia GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [KServe Documentation](https://kserve.github.io/website/)

## 🤝 Contributing

When adding features:
1. Test on a fresh cluster
2. Update documentation
3. Add error handling
4. Follow existing code style

## 📝 Version History

- **v3.0** - Added RHOAI 3.0 support (fast-3.x channel)
- **v2.0** - Integrated workflow script combining all phases
- **v1.0** - Initial OpenShift + GPU installation scripts

## 🎉 What's Next?

After successful installation:
1. ✅ Access RHOAI Dashboard
2. ✅ Create a Data Science Project
3. ✅ Launch GPU-enabled Workbench
4. ✅ Deploy models with KServe
5. ✅ Build AI/ML applications

---

**Happy AI/ML Development!** 🚀
