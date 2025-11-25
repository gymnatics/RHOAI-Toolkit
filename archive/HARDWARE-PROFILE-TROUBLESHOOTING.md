# Hardware Profile Troubleshooting

## Problem: GPU Hardware Profile Not Visible in UI

### Symptoms
- Hardware profile exists when you check `oc get hardwareprofile -n redhat-ods-applications`
- Profile appears in Settings → Hardware Profiles tab
- **BUT** profile is NOT available in the dropdown when deploying a model

### Root Causes

1. **Wrong Namespace**: Hardware profiles in RHOAI 3.0 are **namespace-scoped** for model deployment
2. **Wrong API version**: Using old API version or missing required annotations
3. **Missing Labels**: Required labels for UI discovery not present
4. **NFD Not Working**: Node Feature Discovery pods failing to pull images

#### Wrong Namespace ❌
```yaml
metadata:
  name: gpu-profile
  namespace: redhat-ods-applications  # Global namespace - not visible in project
```

#### Correct Namespace ✅
```yaml
metadata:
  name: gpu-profile
  namespace: my-project  # Same namespace as your project
```

#### Wrong API Version ❌
```yaml
apiVersion: dashboard.opendatahub.io/v1  # OLD - doesn't work for model deployment
kind: HardwareProfile
```

#### Correct API Version ✅
```yaml
apiVersion: infrastructure.opendatahub.io/v1  # CURRENT - works for model deployment
kind: HardwareProfile
```

### Why This Happens

RHOAI 3.0 made hardware profiles **namespace-scoped** for model deployment:
- Profiles in `redhat-ods-applications` are global but may not appear in project dropdowns
- Profiles must be created in the **same namespace** where you deploy models
- The UI only shows profiles from the current project namespace

Additionally, profiles need:
- Correct API version: `infrastructure.opendatahub.io/v1` (not `v1alpha1` or `dashboard.opendatahub.io/v1`)
- Required labels: `app.opendatahub.io/hardwareprofile: "true"`
- Required annotations for UI discovery

## Quick Fixes

### Fix 1: Create Hardware Profile in Your Namespace

```bash
./scripts/create-hardware-profile-in-namespace.sh <your-namespace>
```

This will create the GPU hardware profile in your project namespace where it will be visible in the UI.

### Fix 2: Fix Existing Profiles

```bash
./scripts/fix-hardware-profile.sh
```

This will:
1. Detect old API version profiles
2. Delete them (with confirmation)
3. Create a new profile with the correct configuration
4. Verify the fix

### Fix 3: Fix NFD Image Pull Issues

If Node Feature Discovery (NFD) pods are in `ImagePullBackOff`:

```bash
# Check NFD status
oc get pods -n openshift-nfd

# If pods show ImagePullBackOff, fix the NFD instance
oc apply -f - <<EOF
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

This removes the hardcoded image version that may not exist for your OpenShift version.

## Manual Fix

If you prefer to fix it manually:

### Step 1: Check Current Profile

```bash
oc get hardwareprofile -n redhat-ods-applications -o yaml
```

Look for the `apiVersion` field. If it's `dashboard.opendatahub.io/v1`, it needs to be fixed.

### Step 2: Delete Old Profile

```bash
oc delete hardwareprofile gpu-generic -n redhat-ods-applications
# or whatever your profile name is
```

### Step 3: Create Correct Profile

```bash
cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1alpha1
kind: HardwareProfile
metadata:
  name: gpu-profile
  namespace: redhat-ods-applications
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: GPU Profile
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
  tolerations:
    - effect: NoSchedule
      key: nvidia.com/gpu
      operator: Exists
EOF
```

### Step 4: Verify

```bash
# Check API version
oc get hardwareprofile gpu-profile -n redhat-ods-applications -o jsonpath='{.apiVersion}'
# Should output: infrastructure.opendatahub.io/v1alpha1

# Check display name
oc get hardwareprofile gpu-profile -n redhat-ods-applications -o jsonpath='{.metadata.annotations.opendatahub\.io/display-name}'
# Should output: GPU Profile
```

## Verification in UI

After applying the fix:

1. **Go to RHOAI Dashboard** → Settings → Hardware Profiles
   - You should see "GPU Profile" listed

2. **Deploy a Model** → AI Assets → Deploy Model
   - Click "Hardware profile" dropdown
   - You should now see "GPU Profile" as an option

3. **Select GPU Profile** and continue with deployment
   - The model will be scheduled on GPU nodes

## Required Fields for UI Discovery

For a hardware profile to be discovered by the model deployment UI, it MUST have:

| Field | Value | Purpose |
|-------|-------|---------|
| `apiVersion` | `infrastructure.opendatahub.io/v1alpha1` | Correct API version |
| `metadata.namespace` | `redhat-ods-applications` | System namespace |
| `metadata.annotations['opendatahub.io/display-name']` | Any string | Display name in UI |
| `metadata.annotations['opendatahub.io/disabled']` | `'false'` | Enable profile |
| `spec.identifiers` | Array with CPU, Memory, GPU | Resource definitions |

### Example identifiers Structure

```yaml
spec:
  identifiers:
    - defaultCount: '2'          # Default CPUs
      displayName: CPU
      identifier: cpu
      maxCount: '16'             # Max CPUs user can select
      minCount: 1                # Min CPUs required
      resourceType: CPU
    - defaultCount: 16Gi         # Default memory
      displayName: Memory
      identifier: memory
      maxCount: 64Gi             # Max memory user can select
      minCount: 1Gi              # Min memory required
      resourceType: Memory
    - defaultCount: 1            # Default GPUs
      displayName: GPU
      identifier: nvidia.com/gpu # Must match GPU resource name
      maxCount: 8                # Max GPUs user can select
      minCount: 1                # Min GPUs required
      resourceType: Accelerator  # Must be "Accelerator" for GPUs
```

## Common Mistakes

### ❌ Mistake 1: Wrong API Version
```yaml
apiVersion: dashboard.opendatahub.io/v1  # Wrong!
```
**Fix**: Use `infrastructure.opendatahub.io/v1alpha1`

### ❌ Mistake 2: Missing Annotations
```yaml
metadata:
  name: gpu-profile
  # Missing annotations!
```
**Fix**: Add required annotations:
```yaml
metadata:
  annotations:
    opendatahub.io/display-name: GPU Profile
    opendatahub.io/disabled: 'false'
```

### ❌ Mistake 3: Wrong Namespace
```yaml
metadata:
  namespace: my-project  # Wrong!
```
**Fix**: Must be in `redhat-ods-applications`

### ❌ Mistake 4: Simple identifiers Array
```yaml
spec:
  identifiers:
    - nvidia.com/gpu  # Too simple!
```
**Fix**: Use full structure with defaultCount, maxCount, etc.

## Tolerations (Optional but Recommended)

If your GPU nodes are tainted (common practice), add tolerations:

```yaml
spec:
  tolerations:
    - effect: NoSchedule
      key: nvidia.com/gpu
      operator: Exists
```

This ensures models can be scheduled on GPU nodes even if they have taints.

## Debugging Commands

### Check All Hardware Profiles
```bash
oc get hardwareprofile -n redhat-ods-applications
```

### Check API Version of Specific Profile
```bash
oc get hardwareprofile gpu-profile -n redhat-ods-applications -o jsonpath='{.apiVersion}'
```

### Check Full YAML
```bash
oc get hardwareprofile gpu-profile -n redhat-ods-applications -o yaml
```

### Check Dashboard Config
```bash
oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o yaml
```

Look for `disableHardwareProfiles: false` (should be false or absent).

## Related Issues

### Issue: Profile Shows in Settings but Not in Deployment

**Cause**: Wrong API version  
**Solution**: Run `./scripts/fix-hardware-profile.sh`

### Issue: Model Deployment Fails with "No GPU Available"

**Cause**: GPU nodes not labeled or profile tolerations missing  
**Solution**: 
1. Check GPU nodes: `oc get nodes -l nvidia.com/gpu.present=true`
2. Add tolerations to hardware profile (see above)

### Issue: Profile Disabled in UI

**Cause**: `opendatahub.io/disabled: 'true'` annotation  
**Solution**: Patch the profile:
```bash
oc patch hardwareprofile gpu-profile -n redhat-ods-applications \
  --type=merge -p '{"metadata":{"annotations":{"opendatahub.io/disabled":"false"}}}'
```

## References

- [CAI's guide to RHOAI 3.0](../CAI's%20guide%20to%20RHOAI%203.0.txt) - Section 0, Step 2
- [RHOAI 3.0 Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/3.0)
- [Hardware Profile API Reference](https://github.com/opendatahub-io/opendatahub-operator)

## Summary

✅ **Always use** `infrastructure.opendatahub.io/v1alpha1` for model deployment hardware profiles  
✅ **Include** required annotations for UI discovery  
✅ **Define** full identifiers structure with CPU, Memory, and GPU  
✅ **Add** tolerations if GPU nodes are tainted  
✅ **Use** `./scripts/fix-hardware-profile.sh` for quick fixes  

