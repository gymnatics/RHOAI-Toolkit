# Hardware Profile Final Fix - Complete Solution

## Issue

Hardware profiles were showing "no enabled or valid hardware profiles are available" when trying to deploy models in RHOAI dashboard.

## Root Cause Analysis

After extensive investigation, the issue was **missing required annotations** on the global hardware profiles. The profiles were missing:

1. `opendatahub.io/description` - Description of the profile
2. `opendatahub.io/managed: "false"` - Indicates the profile is not managed by the system

## Comparison: Working vs Non-Working Profile

### default-profile (WORKING)
```yaml
metadata:
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/description: "Provides a baseline hardware profile..."
    opendatahub.io/disabled: "false"
    opendatahub.io/display-name: "default-profile"
    opendatahub.io/managed: "false"  # ← REQUIRED
  labels:
    app.kubernetes.io/part-of: hardwareprofile  # ← REQUIRED
    app.opendatahub.io/hardwareprofile: "true"
```

### gpu-profile (NOT WORKING - Before Fix)
```yaml
metadata:
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: "false"
    opendatahub.io/display-name: "GPU Profile"
    # ❌ MISSING: opendatahub.io/description
    # ❌ MISSING: opendatahub.io/managed
  labels:
    # ❌ MISSING: app.kubernetes.io/part-of
    app.opendatahub.io/hardwareprofile: "true"
```

## Solution Applied

### Step 1: Added Missing Labels
```bash
oc label hardwareprofile gpu-profile -n redhat-ods-applications \
  app.kubernetes.io/part-of=hardwareprofile --overwrite

oc label hardwareprofile small-gpu-profile -n redhat-ods-applications \
  app.kubernetes.io/part-of=hardwareprofile --overwrite

oc label hardwareprofile test-gpu-profile -n redhat-ods-applications \
  app.kubernetes.io/part-of=hardwareprofile --overwrite
```

### Step 2: Added Missing Annotations
```bash
oc annotate hardwareprofile gpu-profile -n redhat-ods-applications \
  opendatahub.io/description="GPU hardware profile for NVIDIA GPU workloads" \
  opendatahub.io/managed=false --overwrite

oc annotate hardwareprofile small-gpu-profile -n redhat-ods-applications \
  opendatahub.io/description="Small GPU profile for testing and development" \
  opendatahub.io/managed=false --overwrite

oc annotate hardwareprofile test-gpu-profile -n redhat-ods-applications \
  opendatahub.io/description="Test GPU profile for large workloads" \
  opendatahub.io/managed=false --overwrite
```

### Step 3: Removed Project-Scoped Duplicates
```bash
oc delete hardwareprofile gpu-profile -n 0-demo
```

## Required Annotations and Labels for Hardware Profiles

### Required Labels
1. **`app.opendatahub.io/hardwareprofile: "true"`**
   - Identifies the resource as a hardware profile
   - **Required**: Yes

2. **`app.kubernetes.io/part-of: hardwareprofile`**
   - Groups the profile with other hardware profiles
   - **Required**: Yes (profiles won't appear without this!)

### Required Annotations
1. **`opendatahub.io/disabled: "false"`**
   - Enables the profile
   - **Required**: Yes

2. **`opendatahub.io/display-name: "Profile Name"`**
   - Display name shown in the UI
   - **Required**: Yes

3. **`opendatahub.io/description: "Description text"`**
   - Description of the profile
   - **Required**: Yes (profiles marked as "invalid" without this!)

4. **`opendatahub.io/managed: "false"`**
   - Indicates user-managed (not system-managed)
   - **Required**: Yes (profiles marked as "invalid" without this!)

5. **`opendatahub.io/dashboard-feature-visibility: '[]'`**
   - Controls visibility in dashboard features
   - **Required**: Yes (empty array means visible everywhere)

## Correct Hardware Profile Template

```yaml
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: my-gpu-profile
  namespace: redhat-ods-applications  # Global scope
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: 'My GPU Profile'
    opendatahub.io/description: 'Description of the profile'
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
```

## Current Configuration

### Global Hardware Profiles (redhat-ods-applications)

All profiles are now properly configured:

| Profile | Display Name | CPU | Memory | GPU | Status |
|---------|-------------|-----|--------|-----|--------|
| default-profile | default-profile | 2-4 | 2-8Gi | 0 | ✅ Valid |
| gpu-profile | GPU Profile | 2-16 | 16-64Gi | 1-8 | ✅ Valid |
| small-gpu-profile | Small GPU Profile | 2-8 | 8-32Gi | 1-2 | ✅ Valid |
| test-gpu-profile | Test GPU Profile | 4-32 | 32-128Gi | 2-8 | ✅ Valid |

## Verification Commands

### Check All Profiles
```bash
oc get hardwareprofiles -n redhat-ods-applications
```

### Verify Required Annotations
```bash
oc get hardwareprofile gpu-profile -n redhat-ods-applications \
  -o jsonpath='{.metadata.annotations}' | jq .
```

### Verify Required Labels
```bash
oc get hardwareprofile gpu-profile -n redhat-ods-applications \
  -o jsonpath='{.metadata.labels}' | jq .
```

### Check Profile Validity
```bash
oc get hardwareprofiles -n redhat-ods-applications -o json | \
  jq -r '.items[] | {
    name: .metadata.name,
    disabled: .metadata.annotations."opendatahub.io/disabled",
    managed: .metadata.annotations."opendatahub.io/managed",
    hasDescription: (.metadata.annotations."opendatahub.io/description" != null),
    hasPartOfLabel: (.metadata.labels."app.kubernetes.io/part-of" != null)
  }'
```

## Understanding Global vs Project-Scoped Profiles

### Global Profiles (redhat-ods-applications)
- **Visibility**: Accessible in **ALL projects** across the cluster
- **Management**: Managed by cluster administrators
- **Use Case**: Standard profiles for organization-wide use
- **Location**: `redhat-ods-applications` namespace
- **Example**: default-profile, gpu-profile

### Project-Scoped Profiles (project namespaces)
- **Visibility**: Only accessible within that specific project
- **Management**: Managed by project users/admins
- **Use Case**: Custom profiles for specific teams
- **Location**: Project namespace (e.g., `0-demo`, `my-project`)
- **Example**: Team-specific GPU configurations

## Best Practices

### 1. Use Global Profiles for Standard Configurations
```bash
# Create in redhat-ods-applications for cluster-wide access
oc apply -f my-profile.yaml -n redhat-ods-applications
```

### 2. Always Include All Required Annotations
```yaml
annotations:
  opendatahub.io/dashboard-feature-visibility: '[]'
  opendatahub.io/disabled: 'false'
  opendatahub.io/display-name: 'Profile Name'
  opendatahub.io/description: 'Profile description'
  opendatahub.io/managed: 'false'
```

### 3. Always Include All Required Labels
```yaml
labels:
  app.opendatahub.io/hardwareprofile: 'true'
  app.kubernetes.io/part-of: hardwareprofile
```

### 4. Don't Use Scheduling Constraints
```yaml
# ❌ DON'T DO THIS - filters profiles from UI
spec:
  scheduling:
    node:
      nodeSelector:
        nvidia.com/gpu.present: "true"

# ✅ DO THIS - let GPU resource request handle scheduling
spec:
  identifiers:
    - identifier: nvidia.com/gpu
      resourceType: Accelerator
```

## Troubleshooting

### "No enabled or valid hardware profiles are available"

**Check 1**: Verify all required annotations exist
```bash
oc get hardwareprofile <name> -n redhat-ods-applications \
  -o jsonpath='{.metadata.annotations}' | jq .
```

**Check 2**: Verify all required labels exist
```bash
oc get hardwareprofile <name> -n redhat-ods-applications \
  -o jsonpath='{.metadata.labels}' | jq .
```

**Check 3**: Verify profile is not disabled
```bash
oc get hardwareprofile <name> -n redhat-ods-applications \
  -o jsonpath='{.metadata.annotations.opendatahub\.io/disabled}'
# Should output: false
```

**Check 4**: Hard refresh the dashboard
- Chrome/Edge: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows/Linux)
- Firefox: Cmd+Shift+R (Mac) or Ctrl+F5 (Windows/Linux)

### Profile Appears in Settings But Not in Model Deployment

This usually means missing annotations. Ensure:
- ✅ `opendatahub.io/description` exists
- ✅ `opendatahub.io/managed: "false"` exists
- ✅ `app.kubernetes.io/part-of: hardwareprofile` label exists

## Summary

✅ **Problem**: Hardware profiles showing as "no enabled or valid"  
✅ **Root Cause**: Missing required annotations (`description`, `managed`) and label (`part-of`)  
✅ **Solution**: Added all required annotations and labels to global profiles  
✅ **Result**: All 4 hardware profiles now valid and accessible in all projects  

## Related Documentation

- [HARDWARE-PROFILE-GLOBAL-FIX.md](HARDWARE-PROFILE-GLOBAL-FIX.md) - Previous fix attempt
- [HARDWARE-PROFILE-FIX.md](docs/HARDWARE-PROFILE-FIX.md) - Original hardware profile fix
- [HARDWARE-PROFILE-TROUBLESHOOTING.md](docs/HARDWARE-PROFILE-TROUBLESHOOTING.md) - Troubleshooting guide

Your hardware profiles are now correctly configured and should be visible when deploying models! 🚀

