# Hardware Profile Global Scope Fix

## Issue

Hardware profiles were not appearing in the RHOAI dashboard when deploying models, except for the default profile.

## Root Cause

1. **Duplicate Profiles**: Same profile names existed in both `redhat-ods-applications` (global) and `0-demo` (project-scoped)
2. **Scheduling Constraints**: Global profiles had nodeSelector and tolerations that filtered them out when GPU nodes weren't detected properly
3. **Scope Confusion**: Mix of global and project-scoped profiles caused dashboard confusion

## Understanding Hardware Profile Scopes in RHOAI 3.0

### Global-Scoped Profiles
- **Location**: `redhat-ods-applications` namespace
- **Visibility**: Accessible in **ALL projects** across the cluster
- **Use Case**: Standard profiles that should be available everywhere
- **Example**: default-profile, gpu-profile, small-gpu-profile

### Project-Scoped Profiles
- **Location**: Specific project namespace (e.g., `0-demo`, `my-project`)
- **Visibility**: Only accessible within that specific project
- **Use Case**: Custom profiles for specific teams or use cases
- **Example**: A special profile for a specific team's workload

## Solution Applied

### Step 1: Removed Duplicate Project-Scoped Profiles
```bash
oc delete hardwareprofile gpu-profile small-gpu-profile test-gpu-profile -n 0-demo
```

**Why**: Having duplicates caused confusion. Global profiles should be the source of truth.

### Step 2: Removed Scheduling Constraints from Global Profiles
```bash
oc patch hardwareprofile gpu-profile -n redhat-ods-applications --type=json \
  -p='[{"op": "remove", "path": "/spec/scheduling"}]'
```

**Why**: Scheduling constraints (nodeSelector, tolerations) were filtering profiles out of the UI. The GPU resource request in the `identifiers` section is sufficient for proper scheduling.

### Step 3: Verified All Global Profiles
```bash
oc get hardwareprofiles -n redhat-ods-applications
```

**Result**: All profiles are now:
- ✅ In `redhat-ods-applications` (global scope)
- ✅ Enabled (`disabled: false`)
- ✅ No scheduling constraints
- ✅ Properly configured with GPU identifiers

## Current Configuration

### Global Hardware Profiles (in redhat-ods-applications)

1. **default-profile**
   - Scope: GLOBAL
   - CPU: 2-4 cores
   - Memory: 2-8Gi
   - GPU: None
   - Use: CPU-only workloads

2. **gpu-profile** (GPU Profile)
   - Scope: GLOBAL
   - CPU: 2-16 cores
   - Memory: 16-64Gi
   - GPU: 1-8 GPUs
   - Use: Standard GPU workloads

3. **small-gpu-profile** (Small GPU Profile)
   - Scope: GLOBAL
   - CPU: 2-8 cores
   - Memory: 8-32Gi
   - GPU: 1-2 GPUs
   - Use: Testing and development

4. **test-gpu-profile** (Test GPU Profile)
   - Scope: GLOBAL
   - CPU: 4-32 cores
   - Memory: 32-128Gi
   - GPU: 2-8 GPUs
   - Use: Large GPU workloads

## Verification

### Check Global Profiles
```bash
oc get hardwareprofiles -n redhat-ods-applications
```

### Check Project-Scoped Profiles (should be empty)
```bash
oc get hardwareprofiles -n 0-demo
```

### Verify Profile Configuration
```bash
oc get hardwareprofile gpu-profile -n redhat-ods-applications -o yaml
```

### Test in RHOAI Dashboard
1. Go to RHOAI Dashboard
2. Navigate to Data Science Projects → 0-demo
3. Click "Deploy model"
4. Check "Hardware profile" dropdown
5. You should see all 4 profiles

## Best Practices

### When to Use Global Profiles
- ✅ Standard configurations used across multiple projects
- ✅ Organization-wide hardware standards
- ✅ Profiles that should be available to all users
- ✅ Managed by cluster administrators

### When to Use Project-Scoped Profiles
- ✅ Team-specific configurations
- ✅ Special hardware requirements for a specific project
- ✅ Temporary or experimental profiles
- ✅ Profiles with strict access control

### Creating Global Profiles
```bash
# Create in redhat-ods-applications namespace
oc apply -f - <<EOF
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: my-global-profile
  namespace: redhat-ods-applications
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: My Global Profile
    opendatahub.io/description: 'Description of the profile'
    opendatahub.io/managed: 'false'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
    app.kubernetes.io/part-of: hardwareprofile
spec:
  identifiers:
    - defaultCount: '4'
      displayName: CPU
      identifier: cpu
      maxCount: '16'
      minCount: 2
      resourceType: CPU
    - defaultCount: 16Gi
      displayName: Memory
      identifier: memory
      maxCount: 64Gi
      minCount: 8Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 4
      minCount: 1
      resourceType: Accelerator
EOF
```

### Creating Project-Scoped Profiles
```bash
# Create in specific project namespace
oc apply -f - <<EOF
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: my-project-profile
  namespace: my-project
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: My Project Profile
    opendatahub.io/description: 'Project-specific profile'
    opendatahub.io/managed: 'false'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
    app.kubernetes.io/part-of: hardwareprofile
spec:
  identifiers:
    # ... same as above
EOF
```

## Key Takeaways

1. ✅ **Global profiles** in `redhat-ods-applications` appear in ALL projects
2. ✅ **Project-scoped profiles** only appear in their specific project
3. ✅ **Don't use scheduling constraints** in profiles - let the GPU resource request handle scheduling
4. ✅ **Avoid duplicate profile names** across global and project scopes
5. ✅ **Use global profiles** for standard configurations
6. ✅ **Use project-scoped profiles** for team-specific needs

## Troubleshooting

### Profiles Not Appearing in UI

**Check 1**: Verify profile is in correct namespace
```bash
# For global profiles
oc get hardwareprofiles -n redhat-ods-applications

# For project-scoped profiles
oc get hardwareprofiles -n <your-project>
```

**Check 2**: Verify profile is enabled
```bash
oc get hardwareprofile <profile-name> -n redhat-ods-applications \
  -o jsonpath='{.metadata.annotations.opendatahub\.io/disabled}'
# Should output: false
```

**Check 3**: Verify profile has no scheduling constraints
```bash
oc get hardwareprofile <profile-name> -n redhat-ods-applications \
  -o jsonpath='{.spec.scheduling}'
# Should output: (empty)
```

**Check 4**: Verify profile has correct labels
```bash
oc get hardwareprofile <profile-name> -n redhat-ods-applications \
  -o jsonpath='{.metadata.labels}'
# Should include: app.opendatahub.io/hardwareprofile: "true"
```

**Check 5**: Hard refresh the dashboard
- Chrome/Edge: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)
- Firefox: Ctrl+F5 (Windows/Linux) or Cmd+Shift+R (Mac)

### Profile Appears But Can't Be Selected

**Issue**: Profile has scheduling constraints that don't match available nodes

**Solution**: Remove scheduling constraints
```bash
oc patch hardwareprofile <profile-name> -n redhat-ods-applications \
  --type=json -p='[{"op": "remove", "path": "/spec/scheduling"}]'
```

## Related Documentation

- [HARDWARE-PROFILE-FIX.md](docs/HARDWARE-PROFILE-FIX.md) - Original hardware profile fix
- [HARDWARE-PROFILE-TROUBLESHOOTING.md](docs/HARDWARE-PROFILE-TROUBLESHOOTING.md) - Troubleshooting guide
- [HARDWARE-PROFILE-USAGE.md](HARDWARE-PROFILE-USAGE.md) - Usage guide

## Summary

✅ **Problem**: Hardware profiles not appearing in model deployment UI  
✅ **Root Cause**: Duplicate profiles + scheduling constraints  
✅ **Solution**: Use global profiles in `redhat-ods-applications` without scheduling constraints  
✅ **Result**: All 4 hardware profiles now visible in ALL projects  

Your hardware profiles are now properly configured and should be visible when deploying models! 🚀

