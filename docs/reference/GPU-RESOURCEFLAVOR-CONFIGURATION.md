# How GPU ResourceFlavor Toleration Was Configured

## Summary

When you encountered the "untolerated taint" error, I configured the Kueue `ResourceFlavor` to add GPU tolerations. Here's exactly how it was done:

---

## The Problem

You were getting this error when deploying models:
```
Pod has untolerated taint {nvidia.com/gpu: NoSchedule}
```

Even though:
- ✅ Your GPU hardware profile specified `nvidia.com/gpu` as the identifier
- ✅ Your GPU nodes were properly labeled
- ✅ Your GPU nodes had the taint `nvidia.com/gpu:NoSchedule`

**Root Cause**: In RHOAI 3.0 with Kueue, tolerations are **NOT** configured in the HardwareProfile. They must be configured in the **ResourceFlavor**.

---

## The Solution - Step by Step

### Step 1: Detected GPU Node Taints

The script checked if your GPU nodes were tainted:

```bash
# Check for GPU nodes
gpu_nodes=$(oc get nodes -l nvidia.com/gpu.present=true -o name)

# Check if they have the nvidia.com/gpu taint
has_taint=$(oc get nodes -l nvidia.com/gpu.present=true -o json | \
  jq -r '.items[].spec.taints[]? | select(.key=="nvidia.com/gpu") | .key')
```

**Result**: Your GPU nodes were tainted with `nvidia.com/gpu:NoSchedule`

### Step 2: Updated the ResourceFlavor

The script applied this YAML to your cluster:

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  # Node selector - tells Kueue which nodes to use
  nodeLabels:
    nvidia.com/gpu.present: "true"
  
  # Toleration - allows pods to schedule on tainted GPU nodes
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
```

**Command used**:
```bash
cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF
```

### Step 3: Verified the Configuration

```bash
# Check the ResourceFlavor
oc get resourceflavor nvidia-gpu-flavor -o yaml

# Check tolerations specifically
oc get resourceflavor nvidia-gpu-flavor -o jsonpath='{.spec.tolerations}'
```

**Expected output**:
```json
[{"effect":"NoSchedule","key":"nvidia.com/gpu","operator":"Exists"}]
```

---

## How Kueue ResourceFlavor Works

### The Flow

```
User deploys model with GPU hardware profile
    ↓
Hardware Profile references LocalQueue "default"
    ↓
LocalQueue references ClusterQueue "cluster-queue"
    ↓
ClusterQueue uses ResourceFlavor "nvidia-gpu-flavor"
    ↓
ResourceFlavor defines:
  - nodeLabels: which nodes to use
  - tolerations: which taints to tolerate
    ↓
Kueue creates Workload with these specs
    ↓
Pod is scheduled on GPU node (taint is tolerated)
```

### Key Components

1. **HardwareProfile** (what you configure in UI):
   ```yaml
   spec:
     identifiers:
       - identifier: nvidia.com/gpu  # GPU resource
     scheduling:
       kueue:
         localQueueName: default  # References LocalQueue
   ```

2. **LocalQueue** (namespace-scoped):
   ```yaml
   apiVersion: kueue.x-k8s.io/v1beta1
   kind: LocalQueue
   metadata:
     name: default
     namespace: your-namespace
   spec:
     clusterQueue: cluster-queue  # References ClusterQueue
   ```

3. **ClusterQueue** (cluster-scoped):
   ```yaml
   apiVersion: kueue.x-k8s.io/v1beta1
   kind: ClusterQueue
   metadata:
     name: cluster-queue
   spec:
     resourceGroups:
     - flavors:
       - name: nvidia-gpu-flavor  # References ResourceFlavor
   ```

4. **ResourceFlavor** (cluster-scoped) - **THIS IS WHERE TOLERATIONS GO**:
   ```yaml
   apiVersion: kueue.x-k8s.io/v1beta1
   kind: ResourceFlavor
   metadata:
     name: nvidia-gpu-flavor
   spec:
     nodeLabels:
       nvidia.com/gpu.present: "true"  # Node selection
     tolerations:  # <-- TOLERATIONS HERE!
     - key: nvidia.com/gpu
       operator: Exists
       effect: NoSchedule
   ```

---

## Where This Configuration Lives

### In Your Scripts

**1. Main function**: `lib/functions/rhoai.sh`

Function: `configure_gpu_resourceflavor()`

Lines: 290-425

This function:
- Checks if GPU nodes exist
- Checks if GPU nodes are tainted
- Interactively prompts to add tolerations
- Applies the ResourceFlavor YAML
- Verifies the configuration

**2. Standalone script**: `scripts/fix-gpu-resourceflavor.sh`

This is a standalone version you can run anytime:
```bash
./scripts/fix-gpu-resourceflavor.sh
```

**3. Integrated into workflows**:
- `integrated-workflow-v2.sh` (line 362)
- `scripts/integrated-workflow.sh` (line 1040)

Both call `configure_gpu_resourceflavor` after RHOAI installation.

---

## The YAML Breakdown

### What Each Field Does

```yaml
apiVersion: kueue.x-k8s.io/v1beta1  # Kueue API version
kind: ResourceFlavor                 # Resource type
metadata:
  name: nvidia-gpu-flavor            # Name (must match ClusterQueue reference)
  labels:
    platform.opendatahub.io/part-of: kueue  # Label for RHOAI integration
spec:
  # Node selection - WHERE to schedule
  nodeLabels:
    nvidia.com/gpu.present: "true"   # Only nodes with this label
  
  # Tolerations - WHAT taints to tolerate
  tolerations:
  - key: nvidia.com/gpu              # Taint key
    operator: Exists                 # Match if key exists (any value)
    effect: NoSchedule               # Taint effect to tolerate
```

### Toleration Operator Options

- **`Exists`**: Tolerate if the taint key exists (ignores value)
  ```yaml
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
  ```
  Tolerates: `nvidia.com/gpu:NoSchedule`, `nvidia.com/gpu=any-value:NoSchedule`

- **`Equal`**: Tolerate only if key and value match
  ```yaml
  - key: nvidia.com/gpu
    operator: Equal
    value: "true"
    effect: NoSchedule
  ```
  Tolerates: `nvidia.com/gpu=true:NoSchedule` only

**We use `Exists`** because GPU node taints typically don't have a value:
```bash
oc adm taint nodes <node-name> nvidia.com/gpu=:NoSchedule
#                                                ^ no value
```

---

## Why This Wasn't in the CAI Guide

The CAI guide mentions taints **once**, briefly:

> "Create a Hardware Profile for GPU (this is an example for the SNO deployment of RHOAI in the demo environment, you may have to adapt it to your own environment, **especially if you need to add tolerations in case your GPU Nodes are tainted**):"

**What's missing**:
1. ❌ How to add tolerations
2. ❌ Where to add tolerations (ResourceFlavor vs HardwareProfile)
3. ❌ What ResourceFlavors are
4. ❌ How Kueue scheduling works

**Why it's missing**:
- The CAI guide focuses on a Single Node OpenShift (SNO) demo environment
- SNO typically doesn't use taints (only 1 node)
- The guide doesn't cover production multi-node scenarios

---

## Documentation Created

I created comprehensive documentation for this:

### 1. **`docs/guides/GPU-TAINTS-RHOAI3.md`**
- Complete guide on GPU taints and Kueue ResourceFlavors
- Step-by-step configuration
- Verification checklist
- Comparison with RHOAI 2.x
- What the CAI guide says (and doesn't say)

### 2. **`scripts/fix-gpu-resourceflavor.sh`**
- Standalone script to fix ResourceFlavor
- Interactive taint detection
- Prompts for configuration
- Verification steps

### 3. **Function in `lib/functions/rhoai.sh`**
- `configure_gpu_resourceflavor()` function
- Integrated into workflow scripts
- Automatic during RHOAI installation

---

## How to Verify It's Working

### 1. Check ResourceFlavor
```bash
oc get resourceflavor nvidia-gpu-flavor -o yaml
```

Look for:
```yaml
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
  tolerations:
  - effect: NoSchedule
    key: nvidia.com/gpu
    operator: Exists
```

### 2. Check GPU Node Taints
```bash
oc get nodes -l nvidia.com/gpu.present=true -o json | \
  jq -r '.items[] | {name: .metadata.name, taints: .spec.taints}'
```

Look for:
```json
{
  "name": "ip-10-0-110-2.us-east-2.compute.internal",
  "taints": [
    {
      "effect": "NoSchedule",
      "key": "nvidia.com/gpu"
    }
  ]
}
```

### 3. Deploy a Test Model
```bash
./scripts/deploy-llmd-model.sh
```

Select a GPU model and deploy. The pod should:
- ✅ Schedule on GPU node
- ✅ Tolerate the taint
- ✅ Start successfully

### 4. Check Workload
```bash
oc get workload -n <namespace>
```

Should show:
```
NAME              QUEUE     ADMITTED   AGE
model-name-xxxx   default   True       1m
```

---

## Key Takeaways

1. **In RHOAI 3.0 with Kueue, tolerations go in ResourceFlavor, NOT HardwareProfile**

2. **The ResourceFlavor YAML**:
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

3. **The command to apply it**:
   ```bash
   oc apply -f resourceflavor.yaml
   ```

4. **Your scripts now do this automatically** during RHOAI installation

5. **You can also run it manually**:
   ```bash
   ./scripts/fix-gpu-resourceflavor.sh
   ```

---

## References

- **Code**: `lib/functions/rhoai.sh` (lines 290-425)
- **Script**: `scripts/fix-gpu-resourceflavor.sh`
- **Documentation**: `docs/guides/GPU-TAINTS-RHOAI3.md`
- **Kueue Docs**: https://kueue.sigs.k8s.io/docs/concepts/resource_flavor/

---

**That's exactly how I configured the GPU ResourceFlavor toleration for you!** 🎯

