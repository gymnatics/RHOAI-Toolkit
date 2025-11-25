# Interactive GPU Taint Detection Feature

## Overview

The installation scripts now intelligently detect GPU node taints and interactively configure the Kueue ResourceFlavor based on your actual cluster state.

## What Changed

### Before ❌
- Scripts would configure tolerations without checking if nodes were tainted
- No visibility into GPU node status
- No option to taint nodes during setup
- Manual intervention required after installation

### After ✅
- Automatically detects GPU nodes
- Checks if GPU nodes are tainted
- Interactive prompts with clear explanations
- Option to taint GPU nodes during setup
- Configures ResourceFlavor based on reality

## How It Works

### 1. GPU Node Detection
```
✓ Found 1 GPU node(s):
  - ip-10-0-110-2.us-east-2.compute.internal
```

### 2. Taint Detection

#### Scenario A: GPU Nodes ARE Tainted
```
✓ GPU nodes are tainted with nvidia.com/gpu:NoSchedule

GPU nodes are tainted to prevent non-GPU workloads.
ResourceFlavor needs toleration to schedule GPU workloads.

Configure ResourceFlavor with GPU toleration? (Y/n):
```

**Default: Yes** - Adds toleration to ResourceFlavor

#### Scenario B: GPU Nodes are NOT Tainted
```
✓ GPU nodes are NOT tainted

GPU nodes are not tainted.
This means any workload can be scheduled on GPU nodes.

Recommendation: Taint GPU nodes to reserve them for GPU workloads only.
Command: oc adm taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu=:NoSchedule

Do you want to taint GPU nodes now? (y/N):
```

**Default: No** - Configures ResourceFlavor without toleration

If you choose **Yes**:
1. Taints the GPU nodes
2. Adds toleration to ResourceFlavor
3. Verifies configuration

## Where This Runs

### 1. During Installation
- `integrated-workflow-v2.sh` (default modular version)
- `scripts/integrated-workflow.sh` (legacy version)

Both automatically call `configure_gpu_resourceflavor()` after RHOAI installation.

### 2. Standalone Fix Script
```bash
./scripts/fix-gpu-resourceflavor.sh
```

Use this to:
- Fix existing installations
- Reconfigure ResourceFlavor after adding GPU nodes
- Change taint configuration

## Configuration Examples

### With Tainted GPU Nodes
```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
```

### Without Tainted GPU Nodes
```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
```

## Best Practices

### ✅ Recommended: Taint GPU Nodes

**Why?**
1. **Cost Optimization**: GPU instances are expensive; don't waste them on CPU workloads
2. **Resource Protection**: Prevents non-GPU workloads from consuming GPU nodes
3. **Predictable Scheduling**: GPU workloads always land on GPU nodes
4. **Multi-tenancy**: Better isolation between GPU and non-GPU workloads

**How?**
```bash
oc adm taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu=:NoSchedule
```

### When NOT to Taint

Only skip tainting if:
- You have a single-node cluster (SNO)
- You want to allow CPU workloads on GPU nodes
- You're in a development/testing environment

## Verification

After configuration, verify:

```bash
# Check GPU node taints
oc get nodes -l nvidia.com/gpu.present=true -o json | jq -r '.items[] | {name: .metadata.name, taints: .spec.taints}'

# Check ResourceFlavor
oc get resourceflavor nvidia-gpu-flavor -o yaml

# Expected output (with taints):
# spec:
#   nodeLabels:
#     nvidia.com/gpu.present: "true"
#   tolerations:
#   - effect: NoSchedule
#     key: nvidia.com/gpu
#     operator: Exists
```

## Troubleshooting

### Issue: "ResourceFlavor 'nvidia-gpu-flavor' not found"

**Cause**: Kueue hasn't created the default ResourceFlavors yet

**Solution**: 
1. Ensure Kueue operator is installed
2. Ensure Kueue is set to `Unmanaged` in DataScienceCluster
3. Wait a few minutes for Kueue to reconcile
4. Run `./scripts/fix-gpu-resourceflavor.sh`

### Issue: "No GPU nodes found"

**Cause**: GPU nodes don't have the `nvidia.com/gpu.present=true` label

**Solution**:
1. Check if GPU operator is installed: `oc get csv -n nvidia-gpu-operator`
2. Check if ClusterPolicy is ready: `oc get clusterpolicy gpu-cluster-policy`
3. Wait for NFD to label nodes (may take 5-10 minutes)
4. Verify: `oc get nodes --show-labels | grep gpu`

### Issue: "untolerated taint" error when deploying models

**Cause**: GPU nodes are tainted but ResourceFlavor doesn't have toleration

**Solution**:
```bash
./scripts/fix-gpu-resourceflavor.sh
```

Choose "Yes" when prompted to add toleration.

## Related Documentation

- [docs/GPU-TAINTS-RHOAI3.md](docs/GPU-TAINTS-RHOAI3.md) - Complete guide on GPU taints in RHOAI 3.0
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - General troubleshooting
- [README.md](README.md) - Main project documentation

## Example Session

```
=== Configuring Kueue ResourceFlavor for GPU Nodes ===

Checking for GPU nodes...
✓ Found 1 GPU node(s):
  - ip-10-0-110-2.us-east-2.compute.internal

Checking GPU node taints...
✓ GPU nodes are tainted with nvidia.com/gpu:NoSchedule

GPU nodes are tainted to prevent non-GPU workloads.
ResourceFlavor needs toleration to schedule GPU workloads.

Configure ResourceFlavor with GPU toleration? (Y/n): Y

Updating nvidia-gpu-flavor ResourceFlavor with toleration...
resourceflavor.kueue.x-k8s.io/nvidia-gpu-flavor configured

✓ ResourceFlavor configured with GPU toleration

✓ Node selector: nvidia.com/gpu.present=true
✓ Toleration: nvidia.com/gpu:NoSchedule
```

---

**Last Updated**: November 2025  
**Feature Added**: Interactive GPU taint detection  
**Scripts Updated**: All installation workflows + standalone fix script
