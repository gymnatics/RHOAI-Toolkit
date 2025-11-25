# GPU Hardware Profile - Complete Fix Guide

## 🎯 The Problem

You created a GPU hardware profile but it doesn't appear in the dropdown when deploying models in the RHOAI dashboard.

## 🔍 Root Causes (In Order of Likelihood)

### 1. **Wrong Namespace** ⚠️ (MOST COMMON)

**Problem**: Hardware profiles in RHOAI 3.0 are **namespace-scoped**. The profile must exist in the **same namespace** where you're deploying the model.

**Check**:
```bash
# What namespace are you deploying in?
oc project

# Does the profile exist in THIS namespace?
oc get hardwareprofile -n $(oc project -q)
```

**Fix**:
```bash
# Create profile in your current namespace
./scripts/create-hardware-profile.sh

# Or specify a namespace
./scripts/create-hardware-profile.sh my-project
```

### 2. **Missing Required Labels** ⚠️

**Problem**: The profile is missing the label that the UI uses to discover it.

**Check**:
```bash
oc get hardwareprofile gpu-profile -n $(oc project -q) -o jsonpath='{.metadata.labels}'
```

**Required**:
- `app.opendatahub.io/hardwareprofile: "true"`
- `app.kubernetes.io/part-of: hardwareprofile`

**Fix**:
```bash
./scripts/fix-hardware-profile.sh
```

### 3. **Scheduling Constraints Hide Profile** ⚠️

**Problem**: If the profile has `spec.scheduling.node.nodeSelector` for GPU nodes, the UI hides it when no matching nodes exist.

**Check**:
```bash
oc get hardwareprofile gpu-profile -n $(oc project -q) -o jsonpath='{.spec.scheduling}'
```

**Fix**: Remove scheduling constraints (the GPU resource request will still schedule on GPU nodes):
```bash
./scripts/fix-hardware-profile.sh
```

### 4. **Wrong API Version** (Less Common)

**Problem**: Using `dashboard.opendatahub.io/v1` instead of `infrastructure.opendatahub.io/v1`.

**Check**:
```bash
oc get hardwareprofile gpu-profile -n $(oc project -q) -o jsonpath='{.apiVersion}'
```

**Should be**: `infrastructure.opendatahub.io/v1` (or `v1alpha1`)

**Fix**:
```bash
./scripts/fix-hardware-profile.sh
```

## 🚀 Quick Fix (Recommended)

Run this script in your project namespace:

```bash
# Switch to your project
oc project my-project

# Fix/create the hardware profile
./scripts/fix-hardware-profile.sh
```

This will:
1. ✅ Create profile in the correct namespace
2. ✅ Add all required labels and annotations
3. ✅ Remove scheduling constraints
4. ✅ Use correct API version

## 📋 Manual Fix Steps

If you prefer to fix it manually:

### Step 1: Switch to Your Project Namespace

```bash
oc project my-project-name
```

### Step 2: Create the Hardware Profile

```bash
cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: gpu-profile
  namespace: $(oc project -q)
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: GPU Profile
    opendatahub.io/description: 'GPU hardware profile for NVIDIA GPU workloads'
    opendatahub.io/managed: 'false'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
    app.kubernetes.io/part-of: hardwareprofile
spec:
  identifiers:
    - defaultCount: '2'
      displayName: CPU
      identifier: cpu
      maxCount: '16'
      minCount: 1
      resourceType: CPU
    - defaultCount: 16Gi
      displayName: Memory
      identifier: memory
      maxCount: 64Gi
      minCount: 1Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 8
      minCount: 1
      resourceType: Accelerator
EOF
```

### Step 3: Verify

```bash
oc get hardwareprofile gpu-profile -n $(oc project -q)
```

### Step 4: Refresh Browser

Hard refresh your browser (Cmd+Shift+R or Ctrl+Shift+R) and check the model deployment page.

## 🔧 Troubleshooting

### Profile Still Not Visible?

1. **Check you're in the right namespace**:
   ```bash
   oc project
   oc get hardwareprofile
   ```

2. **Restart the dashboard**:
   ```bash
   oc delete pod -n redhat-ods-applications -l app=rhods-dashboard
   ```
   Wait 30 seconds, then refresh your browser.

3. **Check dashboard logs**:
   ```bash
   oc logs -n redhat-ods-applications -l app=rhods-dashboard -c rhods-dashboard --tail=50 | grep hardwareprofile
   ```

### NFD Not Working?

If Node Feature Discovery pods are in `ImagePullBackOff`:

```bash
# Check NFD status
oc get pods -n openshift-nfd

# Fix: Remove image override
cat <<EOF | oc apply -f -
apiVersion: nfd.openshift.io/v1
kind: NodeFeatureDiscovery
metadata:
  name: nfd-instance
  namespace: openshift-nfd
spec:
  operand:
    servicePort: 12000
  workerConfig:
    configData: |
      core:
        sleepInterval: 60s
      sources:
        pci:
          deviceClassWhitelist:
            - "0200"
            - "03"
            - "12"
          deviceLabelFields:
            - "vendor"
EOF
```

## 📚 Key Concepts

### Namespace-Scoped Profiles

In RHOAI 3.0, hardware profiles are **namespace-scoped** for model deployment:

- ❌ Creating in `redhat-ods-applications` → Not visible for model deployment
- ✅ Creating in **your project namespace** → Visible in model deployment UI

### Required Metadata

For UI discovery, the profile MUST have:

```yaml
metadata:
  labels:
    app.opendatahub.io/hardwareprofile: "true"  # REQUIRED
    app.kubernetes.io/part-of: hardwareprofile   # REQUIRED
  annotations:
    opendatahub.io/display-name: "GPU Profile"   # REQUIRED
    opendatahub.io/disabled: "false"             # REQUIRED
    opendatahub.io/managed: "false"              # RECOMMENDED
```

### Scheduling Constraints

**Without constraints** (Recommended):
```yaml
spec:
  identifiers:
    - # CPU, Memory, GPU definitions
  # No scheduling section
```
✅ Profile always visible
✅ GPU resource request still schedules on GPU nodes

**With constraints** (Not recommended):
```yaml
spec:
  scheduling:
    type: Node
    node:
      nodeSelector:
        nvidia.com/gpu.present: "true"
```
❌ Profile hidden when no GPU nodes match
❌ More complex configuration

## 🎓 Best Practices

1. **Create profiles in project namespaces**, not system namespaces
2. **Use the helper scripts** (`create-hardware-profile.sh`, `fix-hardware-profile.sh`)
3. **Don't add scheduling constraints** unless absolutely necessary
4. **Test in the UI** after creating profiles
5. **Document your namespaces** where profiles are deployed

## 📞 Still Having Issues?

1. Check `docs/TROUBLESHOOTING.md` for general RHOAI issues
2. Verify NFD and GPU operators are working
3. Check GPU nodes are properly labeled:
   ```bash
   oc get nodes -l nvidia.com/gpu.present=true
   ```
4. Review dashboard logs for errors

## 🔗 Related Documentation

- [HARDWARE-PROFILE-TROUBLESHOOTING.md](HARDWARE-PROFILE-TROUBLESHOOTING.md) - Detailed troubleshooting
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General RHOAI troubleshooting
- [../QUICK-REFERENCE.md](../QUICK-REFERENCE.md) - Quick reference card

