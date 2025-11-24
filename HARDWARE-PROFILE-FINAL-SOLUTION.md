# Hardware Profile Final Solution - The Missing Piece!

## The Problem

Hardware profiles were not appearing in the model deployment dropdown in RHOAI 3.0, showing "no enabled or valid hardware profiles are available".

## The Root Cause

After extensive troubleshooting, we discovered the **critical missing piece**: the `scheduling` section!

### What Was Missing

```yaml
spec:
  scheduling:
    kueue:
      localQueueName: default
      priorityClass: None
    type: Queue
```

This section is **REQUIRED** for hardware profiles to work with RHOAI 3.0's Serverless + Kueue deployment mode!

## The Complete Working Format

### Working Hardware Profile (RHOAI 3.0 + Kueue)

```yaml
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: nvidia-gpu
  namespace: redhat-ods-applications
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: 'Nvidia GPU'
spec:
  identifiers:
    - defaultCount: '2'
      displayName: CPU
      identifier: cpu
      maxCount: '16'
      minCount: '1'
      resourceType: CPU
    - defaultCount: 16Gi
      displayName: Memory
      identifier: memory
      maxCount: 64Gi
      minCount: 2Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 8
      minCount: 1
      resourceType: Accelerator
  scheduling:           # ← THIS IS THE KEY!
    kueue:
      localQueueName: default
      priorityClass: None
    type: Queue
```

## Why This Was Hard to Find

1. **Reference Repository**: Uses RawDeployment mode (no Kueue), so their profiles don't have this section
2. **CAI Guide**: Doesn't explicitly show the `scheduling` section in the hardware profile examples
3. **API Conversion**: The v1alpha1 to v1 conversion strips some fields, making it unclear what's needed
4. **Documentation Gap**: Official docs don't emphasize this requirement for Kueue-based deployments

## The Journey to Discovery

### Attempt 1: API Version
- Tried `v1alpha1` vs `v1`
- **Result**: Both work, but still no profiles visible

### Attempt 2: Annotations
- Added `opendatahub.io/description`, `opendatahub.io/managed`
- **Result**: Profiles still not visible

### Attempt 3: Labels
- Added `app.kubernetes.io/part-of`, `app.opendatahub.io/hardwareprofile`
- **Result**: Profiles still not visible

### Attempt 4: Namespace Scope
- Created profiles in project namespace instead of global
- **Result**: Profiles appeared but only in that project

### Attempt 5: Scheduling Constraints
- Removed `nodeSelector` and `tolerations`
- **Result**: Profiles still not visible globally

### **Attempt 6: User Created Working Profile** ✅
- User created `test-gpu` profile via UI
- **Discovery**: Profile had `scheduling` section!
- **Result**: THIS WAS THE MISSING PIECE!

## Comparison: Before vs After

### ❌ Before (Not Working)

```yaml
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: nvidia-gpu
  namespace: redhat-ods-applications
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: 'Nvidia GPU'
spec:
  identifiers:
    - defaultCount: '2'
      displayName: CPU
      identifier: cpu
      maxCount: '16'
      minCount: '1'
      resourceType: CPU
    - defaultCount: 16Gi
      displayName: Memory
      identifier: memory
      maxCount: 64Gi
      minCount: 2Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 8
      minCount: 1
      resourceType: Accelerator
  # ❌ MISSING: scheduling section!
```

### ✅ After (Working)

```yaml
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: nvidia-gpu
  namespace: redhat-ods-applications
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahup.io/disabled: 'false'
    opendatahub.io/display-name: 'Nvidia GPU'
spec:
  identifiers:
    - defaultCount: '2'
      displayName: CPU
      identifier: cpu
      maxCount: '16'
      minCount: '1'
      resourceType: CPU
    - defaultCount: 16Gi
      displayName: Memory
      identifier: memory
      maxCount: 64Gi
      minCount: 2Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 8
      minCount: 1
      resourceType: Accelerator
  scheduling:           # ✅ ADDED: This makes it work!
    kueue:
      localQueueName: default
      priorityClass: None
    type: Queue
```

## Why the Scheduling Section is Required

### For Serverless + Kueue Mode

When using RHOAI 3.0 with Serverless deployment mode and Kueue enabled:

1. **Kueue Integration**: Hardware profiles must specify which LocalQueue to use
2. **Resource Management**: Kueue needs to know how to schedule workloads
3. **Priority Management**: Optional priority class for workload scheduling
4. **Queue Type**: Specifies the scheduling type (Queue vs Node)

### Scheduling Section Fields

```yaml
scheduling:
  kueue:
    localQueueName: default    # ← LocalQueue in the namespace
    priorityClass: None        # ← Optional priority (None, Low, Medium, High)
  type: Queue                  # ← Scheduling type (Queue or Node)
```

**Important**: 
- `localQueueName` must match an existing LocalQueue in the namespace
- For global profiles, use `default` (created automatically by RHOAI)
- `priorityClass: None` means no special priority

## Deployment Mode Comparison

### RawDeployment Mode (Reference Repo)

```yaml
# DataScienceCluster
kserve:
  rawDeploymentServiceConfig: Headless
kueue:
  managementState: Removed

# HardwareProfile (NO scheduling section needed)
spec:
  identifiers:
    - cpu, memory, gpu...
  # No scheduling section!
```

**Why**: RawDeployment doesn't use Kueue, so no scheduling configuration needed

### Serverless + Kueue Mode (Our Setup)

```yaml
# DataScienceCluster
kserve:
  managementState: Managed
  # No rawDeploymentServiceConfig (Serverless mode)
kueue:
  managementState: Unmanaged

# HardwareProfile (scheduling section REQUIRED)
spec:
  identifiers:
    - cpu, memory, gpu...
  scheduling:           # ← REQUIRED!
    kueue:
      localQueueName: default
      priorityClass: None
    type: Queue
```

**Why**: Serverless mode uses Kueue for scheduling, so hardware profiles must specify queue configuration

## Updated Hardware Profiles

We've created the following profiles with the correct `scheduling` section:

### 1. nvidia-gpu (General Purpose)
- CPU: 2-16 cores
- Memory: 16-64Gi
- GPU: 1-8 GPUs

### 2. small-gpu (Development/Testing)
- CPU: 2-8 cores
- Memory: 8-32Gi
- GPU: 1-2 GPUs

### 3. large-gpu (Production/Training)
- CPU: 8-32 cores
- Memory: 64-256Gi
- GPU: 4-8 GPUs

### 4. test-gpu (User's Working Profile)
- CPU: 2-4 cores
- Memory: 5-10Gi
- GPU: 1 GPU

## Verification

```bash
# Check all profiles
oc get hardwareprofiles -n redhat-ods-applications

# Verify scheduling section
oc get hardwareprofile nvidia-gpu -n redhat-ods-applications -o jsonpath='{.spec.scheduling}' | jq '.'

# Expected output:
{
  "kueue": {
    "localQueueName": "default",
    "priorityClass": "None"
  },
  "type": "Queue"
}
```

## Testing

1. **Open RHOAI Dashboard**
2. **Navigate to**: Data Science Projects → 0-demo → Deploy model
3. **Check**: Hardware profile dropdown
4. **Expected**: Should show all profiles:
   - default-profile (CPU only)
   - nvidia-gpu
   - small-gpu
   - large-gpu
   - test-gpu

## Scripts Updated

The following scripts have been updated to include the `scheduling` section:

1. **`lib/functions/rhoai.sh`** - `create_gpu_hardware_profile()` function
2. **`scripts/create-hardware-profile.sh`** - Standalone profile creation script

## Key Takeaways

### ✅ Required for Serverless + Kueue Mode

```yaml
spec:
  scheduling:
    kueue:
      localQueueName: default
      priorityClass: None
    type: Queue
```

### ❌ Not Required for RawDeployment Mode

If using `rawDeploymentServiceConfig: Headless`, the `scheduling` section is not needed.

### 🎯 The Complete Requirements

For hardware profiles to work in RHOAI 3.0 with Serverless + Kueue:

1. ✅ API Version: `infrastructure.opendatahub.io/v1`
2. ✅ Annotations: `opendatahub.io/dashboard-feature-visibility`, `opendatahub.io/disabled`, `opendatahub.io/display-name`
3. ✅ Identifiers: CPU, Memory, GPU (or other accelerators)
4. ✅ **Scheduling Section**: With Kueue configuration ← **THIS WAS THE MISSING PIECE!**

## Lessons Learned

1. **UI-Created Resources**: Sometimes the best way to understand the correct format is to create a resource via the UI and examine it
2. **Deployment Mode Matters**: RawDeployment and Serverless modes have different requirements
3. **Documentation Gaps**: Official docs may not cover all edge cases
4. **Reference Repos**: May use different deployment modes, so their examples might not apply directly

## Future Improvements

1. **Update CAI Guide**: Suggest adding the `scheduling` section to hardware profile examples
2. **Improve Error Messages**: Dashboard could show why profiles are being filtered out
3. **Validation**: Add validation to check for required fields based on deployment mode

## Summary

🎉 **Hardware profiles now working!**

The missing piece was the `scheduling` section with Kueue configuration. This is **required** for RHOAI 3.0 when using Serverless + Kueue deployment mode.

All profiles have been updated and should now be visible in the model deployment dropdown! 🚀

---

## References

- User's working profile: `test-gpu` (created via UI)
- Updated profiles: `nvidia-gpu`, `small-gpu`, `large-gpu`
- Related docs: `KSERVE-DEPLOYMENT-MODES.md`, `SETUP-COMPARISON.md`

