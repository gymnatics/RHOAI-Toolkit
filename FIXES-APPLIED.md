# Fixes Applied - RHOAI 3.0 Hardware Profiles & NFD

## Summary

Fixed two critical issues preventing GPU hardware profiles from appearing in the RHOAI 3.0 UI:

1. **NFD Image Pull Failure** - Node Feature Discovery couldn't start
2. **Hardware Profile Namespace Scoping** - Profiles weren't visible in project namespaces

---

## Issue 1: NFD Image Pull Failure ❌→✅

### Problem
```
Error: ImagePullBackOff
Back-off pulling image "registry.redhat.io/openshift4/ose-node-feature-discovery:v4.19"
reading manifest v4.19: manifest unknown
```

### Root Cause
The NFD instance manifest had a hardcoded image version (`v4.19`) that doesn't exist in the Red Hat registry.

### Fix Applied
**File**: `lib/manifests/operators/nfd-instance.yaml`

**Before**:
```yaml
spec:
  operand:
    image: registry.redhat.io/openshift4/ose-node-feature-discovery:v4.19
    imagePullPolicy: Always
```

**After**:
```yaml
spec:
  operand:
    servicePort: 12000
```

**Result**: NFD operator now uses the correct default image for your OpenShift version.

### Verification
```bash
# Check NFD pods are running
oc get pods -n openshift-nfd

# Check GPU node has proper labels
oc get node <gpu-node-name> -L nvidia.com/gpu.present
# Should show: nvidia.com/gpu.present=true
```

---

## Issue 2: Hardware Profile Not Visible in UI ❌→✅

### Problem
- Hardware profile exists in `redhat-ods-applications` namespace
- Profile shows in Settings → Hardware Profiles
- **BUT** profile NOT in dropdown when deploying models

### Root Causes

1. **Namespace Scoping**: RHOAI 3.0 hardware profiles are namespace-scoped
   - Profiles in `redhat-ods-applications` are global but not visible in projects
   - Must create profile in the **same namespace** where you deploy models

2. **Missing Labels**: Required label for UI discovery
   - `app.opendatahub.io/hardwareprofile: "true"` was missing

3. **API Version**: Using `v1alpha1` instead of stable `v1`

4. **Missing Annotations**: Several required annotations were missing

### Fix Applied

**File**: `lib/functions/rhoai.sh` - Updated `create_gpu_hardware_profile()`

**Key Changes**:
- Use `infrastructure.opendatahub.io/v1` (stable API)
- Add required labels:
  - `app.opendatahub.io/hardwareprofile: "true"`
  - `app.kubernetes.io/part-of: hardwareprofile`
- Add required annotations:
  - `opendatahub.io/managed: "false"`
  - `opendatahub.io/description`
- Remove scheduling constraints (nodeSelector) that hide profile when no GPU nodes match

**Complete Working Profile**:
```yaml
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: gpu-profile
  namespace: <your-project-namespace>  # ← Must be in project namespace!
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: GPU Profile
    opendatahub.io/description: 'GPU hardware profile for NVIDIA GPU workloads'
    opendatahub.io/managed: 'false'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'  # ← Required!
    app.kubernetes.io/part-of: hardwareprofile  # ← Required!
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
```

---

## New Tools Created

### 1. `scripts/create-hardware-profile-in-namespace.sh`
Create GPU hardware profile in any namespace.

**Usage**:
```bash
# Interactive mode
./scripts/create-hardware-profile-in-namespace.sh

# Specify namespace
./scripts/create-hardware-profile-in-namespace.sh my-project
```

### 2. Updated `scripts/fix-hardware-profile.sh`
Now prompts for namespace and creates profile with correct configuration.

**Usage**:
```bash
./scripts/fix-hardware-profile.sh
```

---

## How to Use

### For New Installations
The updated scripts will automatically:
1. Install NFD with correct configuration (no hardcoded image)
2. Create hardware profile in appropriate namespace
3. Add all required labels and annotations

### For Existing Installations

#### Fix NFD (if pods are failing)
```bash
# Apply the fix
oc apply -f lib/manifests/operators/nfd-instance.yaml

# Wait for pods to restart
oc get pods -n openshift-nfd -w
```

#### Create Hardware Profile in Your Project
```bash
# Option 1: Use helper script
./scripts/create-hardware-profile-in-namespace.sh my-project

# Option 2: Use fix script
./scripts/fix-hardware-profile.sh
```

#### Verify
```bash
# Check profile exists in your namespace
oc get hardwareprofile -n my-project

# Refresh browser (Cmd+Shift+R)
# Go to RHOAI Dashboard → Your Project → Deploy Model
# GPU Profile should appear in Hardware Profile dropdown
```

---

## Key Learnings

### RHOAI 3.0 Changes

1. **Hardware Profiles are Namespace-Scoped**
   - Create in each namespace where you deploy models
   - Global profiles in `redhat-ods-applications` may not appear in UI

2. **API Version Stability**
   - Use `infrastructure.opendatahub.io/v1` (stable)
   - Not `v1alpha1` or `dashboard.opendatahub.io/v1`

3. **Required Metadata**
   - Labels: `app.opendatahub.io/hardwareprofile: "true"`
   - Annotations: `opendatahub.io/managed`, `opendatahub.io/display-name`

4. **NFD Image Versions**
   - Don't hardcode image versions
   - Let operator choose correct version for OpenShift

### Best Practices

1. **Always create hardware profiles in project namespaces**
2. **Use the helper scripts** for consistent configuration
3. **Verify NFD is running** before expecting GPU detection
4. **Check GPU node labels** to ensure NFD discovered the GPU

---

## Troubleshooting

### Profile Still Not Visible?

1. **Check namespace**:
   ```bash
   oc get hardwareprofile -n <your-project-namespace>
   ```

2. **Check labels**:
   ```bash
   oc get hardwareprofile gpu-profile -n <namespace> -o jsonpath='{.metadata.labels}'
   ```
   Should include: `app.opendatahub.io/hardwareprofile: "true"`

3. **Restart dashboard**:
   ```bash
   oc delete pod -n redhat-ods-applications -l app=rhods-dashboard
   ```

4. **Hard refresh browser**: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows/Linux)

### NFD Still Failing?

1. **Check pods**:
   ```bash
   oc get pods -n openshift-nfd
   ```

2. **Check events**:
   ```bash
   oc get events -n openshift-nfd --sort-by='.lastTimestamp' | tail -20
   ```

3. **Verify NFD instance**:
   ```bash
   oc get nodefeaturediscovery nfd-instance -n openshift-nfd -o yaml
   ```
   Should NOT have hardcoded `image:` field

---

## Documentation

- **Detailed Troubleshooting**: `docs/HARDWARE-PROFILE-TROUBLESHOOTING.md`
- **Quick Reference**: `QUICK-REFERENCE.md`
- **Main README**: `README.md`

---

## Status

✅ **NFD Fixed**: Pods running, GPU nodes labeled  
✅ **Hardware Profile Fixed**: Correct API version, labels, and namespace  
✅ **Scripts Updated**: All future installations will work correctly  
✅ **Documentation Updated**: Comprehensive troubleshooting guides  

**All changes committed and pushed to Git repository.**

