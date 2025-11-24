# Fixes Applied - Hardware Profile & NFD Issues

## 🎯 Summary

Fixed two critical issues preventing GPU hardware profiles from appearing in the RHOAI dashboard:

1. **Hardware profiles are namespace-scoped** in RHOAI 3.0
2. **NFD image pull failure** preventing GPU detection

## 🔧 Issues Fixed

### 1. Hardware Profile Not Visible in UI ✅

**Problem**: GPU hardware profile existed but didn't appear in model deployment dropdown.

**Root Causes**:
- ❌ Profile created in `redhat-ods-applications` (wrong namespace)
- ❌ Missing required labels for UI discovery
- ❌ Scheduling constraints hide profile when no GPU nodes match selector

**Solution**:
- ✅ Create profiles in the **same namespace** where you deploy models
- ✅ Add required labels: `app.opendatahub.io/hardwareprofile: "true"`
- ✅ Remove `spec.scheduling` constraints (GPU resource request still works)

### 2. NFD Pods in ImagePullBackOff ✅

**Problem**: Node Feature Discovery pods couldn't pull images, preventing GPU detection.

**Root Cause**:
- ❌ NFD CR specified `image: registry.redhat.io/openshift4/ose-node-feature-discovery:v4.19`
- ❌ The `v4.19` tag doesn't exist in the registry

**Solution**:
- ✅ Removed explicit image override from NFD CR
- ✅ Let NFD operator use correct default image
- ✅ NFD pods now running successfully
- ✅ GPU nodes properly labeled with `nvidia.com/gpu.present=true`

## 📝 Changes Made

### Scripts Updated

1. **`lib/functions/rhoai.sh`**
   - `create_gpu_hardware_profile()` now creates profiles in current namespace
   - Removes scheduling constraints for better visibility
   - Adds all required labels and annotations

2. **`scripts/create-hardware-profile.sh`** (NEW)
   - Helper script to create GPU profiles in any namespace
   - Usage: `./scripts/create-hardware-profile.sh [namespace]`

3. **`scripts/fix-hardware-profile.sh`** (UPDATED)
   - Now operates on current namespace
   - Removes scheduling constraints
   - Comprehensive verification

### Documentation Added

1. **`docs/HARDWARE-PROFILE-FIX.md`** (NEW)
   - Complete troubleshooting guide
   - Explains namespace-scoped profiles
   - Quick fix steps and manual procedures
   - NFD troubleshooting

2. **`docs/HARDWARE-PROFILE-TROUBLESHOOTING.md`** (EXISTING)
   - Detailed API version and structure info
   - Manual fix procedures

3. **`QUICK-REFERENCE.md`** (EXISTING)
   - Quick reference for common issues

## 🚀 How to Use

### For New Installations

The updated scripts will automatically:
1. Create hardware profiles in the correct namespace
2. Add all required labels and annotations
3. Skip scheduling constraints

### For Existing Clusters

**Quick Fix**:
```bash
# Switch to your project
oc project my-project

# Fix the hardware profile
./scripts/fix-hardware-profile.sh

# Refresh your browser
```

**Create in Multiple Namespaces**:
```bash
./scripts/create-hardware-profile.sh project-1
./scripts/create-hardware-profile.sh project-2
./scripts/create-hardware-profile.sh project-3
```

## 📊 Verification

### Check NFD is Working

```bash
# NFD pods should be Running
oc get pods -n openshift-nfd

# GPU nodes should have the label
oc get nodes -l nvidia.com/gpu.present=true
```

### Check Hardware Profile

```bash
# Switch to your project
oc project my-project

# Profile should exist
oc get hardwareprofile gpu-profile

# Check it has correct labels
oc get hardwareprofile gpu-profile -o jsonpath='{.metadata.labels}' | jq .
```

### Check in UI

1. Go to RHOAI Dashboard
2. Navigate to model deployment
3. "GPU Profile" should appear in the hardware profile dropdown

## 🎓 Key Learnings

### Hardware Profiles in RHOAI 3.0

**Namespace-Scoped**:
- Profiles must be in the **same namespace** as your model deployment
- Creating in `redhat-ods-applications` won't make them visible for model deployment
- Each project needs its own hardware profile

**Required Metadata**:
```yaml
metadata:
  labels:
    app.opendatahub.io/hardwareprofile: "true"  # REQUIRED for UI discovery
    app.kubernetes.io/part-of: hardwareprofile   # REQUIRED
  annotations:
    opendatahub.io/display-name: "GPU Profile"   # REQUIRED
    opendatahub.io/disabled: "false"             # REQUIRED
```

**Scheduling Constraints**:
- Profiles with `spec.scheduling.node.nodeSelector` are hidden when no matching nodes exist
- Better to omit scheduling section - GPU resource request still schedules on GPU nodes

### NFD Image Tags

- Don't hardcode image tags in NFD CR
- Let the operator manage the correct image version
- The `v4.19` tag pattern doesn't exist in registry

## 🔗 Related Documentation

- [docs/HARDWARE-PROFILE-FIX.md](docs/HARDWARE-PROFILE-FIX.md) - Complete fix guide
- [docs/HARDWARE-PROFILE-TROUBLESHOOTING.md](docs/HARDWARE-PROFILE-TROUBLESHOOTING.md) - Detailed troubleshooting
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Quick reference card
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - General troubleshooting

## ✅ Status

- [x] NFD pods running successfully
- [x] GPU nodes properly labeled
- [x] Hardware profile creation fixed
- [x] Scripts updated
- [x] Documentation complete
- [x] Changes committed and pushed to Git

All fixes have been applied and tested! 🎉
