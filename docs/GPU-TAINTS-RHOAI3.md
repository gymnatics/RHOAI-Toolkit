# GPU Taints and Tolerations in RHOAI 3.0

## TL;DR - The Answer

**Q: Do I still need to put taints on GPU nodes in RHOAI 3.0?**

**A: Yes, you should still taint GPU nodes, but the toleration configuration has changed.**

- **RHOAI 2.x**: Tolerations were configured in the `InferenceService` or `ServingRuntime`
- **RHOAI 3.0 with Kueue**: Tolerations are configured in the **`ResourceFlavor`**, not the hardware profile

## The Issue

When you deploy a model using a GPU hardware profile, you might see:

```
Error: Pod has untoler
ated taint {nvidia.com/gpu: NoSchedule}
```

This happens even though:
- ✅ Your hardware profile specifies `nvidia.com/gpu` as the GPU identifier
- ✅ Your GPU nodes are labeled correctly
- ✅ Your GPU nodes have the taint `nvidia.com/gpu:NoSchedule`

**Why?** The `ResourceFlavor` used by Kueue doesn't have the toleration configured.

## The Solution

### Step 1: Check if your GPU nodes are tainted

```bash
oc get nodes -l nvidia.com/gpu.present=true -o json | jq -r '.items[] | {name: .metadata.name, taints: .spec.taints}'
```

**Expected output**:
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

### Step 2: Check the ResourceFlavor

```bash
oc get resourceflavor nvidia-gpu-flavor -o yaml
```

If `spec: {}` is empty, you need to add tolerations.

### Step 3: Update the ResourceFlavor

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

### Step 4: Verify

```bash
oc get resourceflavor nvidia-gpu-flavor -o jsonpath='{.spec.tolerations}'
```

**Expected output**:
```json
[{"effect":"NoSchedule","key":"nvidia.com/gpu","operator":"Exists"}]
```

## How RHOAI 3.0 Kueue Works

### Architecture

```
Hardware Profile (nvidia-gpu)
    ↓ references
LocalQueue (default)
    ↓ uses
ClusterQueue (cluster-queue)
    ↓ uses
ResourceFlavor (nvidia-gpu-flavor)
    ↓ defines
Node Selection + Tolerations
```

### Key Components

1. **Hardware Profile** (`HardwareProfile`)
   - Defines resource requirements (CPU, Memory, GPU)
   - Specifies Kueue queue name (`localQueueName: default`)
   - Does **NOT** contain tolerations

2. **LocalQueue** (`LocalQueue`)
   - Namespace-scoped queue
   - References a ClusterQueue

3. **ClusterQueue** (`ClusterQueue`)
   - Cluster-scoped resource pool
   - References ResourceFlavors

4. **ResourceFlavor** (`ResourceFlavor`)
   - Defines node selection criteria (`nodeLabels`)
   - Defines tolerations for taints
   - **This is where GPU tolerations go!**

## Complete ResourceFlavor Configuration

### For GPU Nodes with Taints

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  # Select nodes with GPU
  nodeLabels:
    nvidia.com/gpu.present: "true"
  
  # Tolerate GPU taint
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
```

### For GPU Nodes WITHOUT Taints

If your GPU nodes are **not** tainted (not recommended for production):

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  # Only node selection, no tolerations needed
  nodeLabels:
    nvidia.com/gpu.present: "true"
```

## Should You Taint GPU Nodes?

### ✅ Recommended: YES, taint GPU nodes

**Reasons**:
1. **Resource Protection**: Prevents non-GPU workloads from consuming GPU nodes
2. **Cost Optimization**: GPU instances are expensive; don't waste them on CPU workloads
3. **Predictable Scheduling**: GPU workloads always land on GPU nodes
4. **Multi-tenancy**: Better isolation between GPU and non-GPU workloads

### How to Taint GPU Nodes

```bash
# Taint all GPU nodes
oc adm taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu=:NoSchedule
```

### How to Remove Taints (if needed)

```bash
# Remove taint from all GPU nodes
oc adm taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu-
```

## Verification Checklist

After configuring ResourceFlavor, verify everything works:

### 1. Check ResourceFlavor

```bash
oc get resourceflavor nvidia-gpu-flavor -o yaml
```

Expected:
- ✅ `spec.nodeLabels` includes `nvidia.com/gpu.present: "true"`
- ✅ `spec.tolerations` includes the GPU taint toleration

### 2. Check ClusterQueue

```bash
oc get clusterqueue cluster-queue -o yaml
```

Expected:
- ✅ `spec.resourceGroups` includes `nvidia-gpu-flavor`

### 3. Check LocalQueue

```bash
oc get localqueue default -n <your-namespace> -o yaml
```

Expected:
- ✅ `spec.clusterQueue: cluster-queue`

### 4. Deploy a Test Model

```bash
# Deploy via UI with GPU hardware profile
# Or via YAML:
cat <<'EOF' | oc apply -f -
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: test-gpu-model
  namespace: your-namespace
  labels:
    kueue.x-k8s.io/queue-name: default
spec:
  replicas: 1
  model:
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest
    name: test-model
  router:
    route: {}
    gateway: {}
  template:
    containers:
    - name: main
      resources:
        limits:
          nvidia.com/gpu: "1"
        requests:
          nvidia.com/gpu: "1"
EOF
```

### 5. Check Workload Status

```bash
# Check if workload is admitted
oc get workload -n <your-namespace>

# Check pod status
oc get pods -n <your-namespace> | grep test-gpu-model
```

Expected:
- ✅ Workload status: `Admitted`
- ✅ Pod status: `Running` (not `Pending` with taint error)

## Common Issues

### Issue 1: "untolerated taint" error

**Symptom**:
```
Pod has untolerated taint {nvidia.com/gpu: NoSchedule}
```

**Solution**:
Update `nvidia-gpu-flavor` ResourceFlavor with tolerations (see Step 3 above)

### Issue 2: Workload stuck in "Pending"

**Symptom**:
```bash
oc get workload
NAME              QUEUE     ADMITTED   AGE
test-model-xxxx   default   False      5m
```

**Solutions**:
1. Check ClusterQueue has capacity:
   ```bash
   oc get clusterqueue cluster-queue -o yaml
   ```
2. Check ResourceFlavor exists and is referenced:
   ```bash
   oc get resourceflavor
   ```
3. Check LocalQueue exists in your namespace:
   ```bash
   oc get localqueue -n <namespace>
   ```

### Issue 3: Pod scheduled on non-GPU node

**Symptom**: Pod runs but can't find GPU

**Solution**: Add `nodeLabels` to ResourceFlavor:
```yaml
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
```

## Comparison: RHOAI 2.x vs 3.0

| Aspect | RHOAI 2.x | RHOAI 3.0 (with Kueue) |
|--------|-----------|------------------------|
| **Toleration Location** | InferenceService / ServingRuntime | ResourceFlavor |
| **Node Selection** | InferenceService nodeSelector | ResourceFlavor nodeLabels |
| **Resource Management** | Kubernetes native | Kueue (queue-based) |
| **Hardware Profiles** | Optional | Required for UI deployment |
| **Taints Needed?** | Yes | Yes (still recommended) |

## What the CAI Guide Says

The CAI guide mentions taints/tolerations **only once**, in a brief note:

> "Create a Hardware Profile for GPU (this is an example for the SNO deployment of RHOAI in the demo environment, you may have to adapt it to your own environment, **especially if you need to add tolerations in case your GPU Nodes are tainted**):"

**Key observations**:
1. ❌ The CAI guide does **NOT** provide details on how to add tolerations
2. ❌ The CAI guide does **NOT** mention ResourceFlavors at all
3. ❌ The example hardware profile in the guide has **no tolerations**
4. ✅ The CAI guide **does** mention that hardware profiles need to specify the LocalQueue for Kueue

**Important quote from CAI guide (Section 10 - Kueue)**:
> "After enabling Kueue, the previous non-kueue Hardware Profiles are no longer active. **A new hardware profile must be created, and it needs to specify the LocalQueue.**"

**What's missing from CAI guide**:
- How to configure ResourceFlavors with tolerations
- Where tolerations should go in RHOAI 3.0 (ResourceFlavor vs HardwareProfile)
- How to handle tainted GPU nodes with Kueue

This is why many users encounter the "untolerated taint" error - the CAI guide doesn't cover this critical configuration!

## References

- Kueue ResourceFlavor Documentation: https://kueue.sigs.k8s.io/docs/concepts/resource_flavor/
- RHOAI 3.0 Documentation: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0
- RHOAI 3.0 Kueue Documentation: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0/html/managing_openshift_ai/managing-workloads-with-kueue
- CAI's guide to RHOAI 3.0 (Section 2 - Hardware Profiles, Section 10 - Kueue)

---

**Last Updated**: November 2025  
**RHOAI Version**: 3.0  
**Tested**: ✅ Working with tainted GPU nodes  
**CAI Guide Coverage**: ⚠️ Mentions taints but doesn't explain configuration

