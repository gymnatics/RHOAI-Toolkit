# RHOAI 3.0 Hardware Profile - Final Solution

## Problem Summary

Hardware profiles were not appearing as "valid" when deploying models in RHOAI 3.0, showing "no enabled or valid hardware profiles are available" error.

## Root Cause

The hardware profile format changed between RHOAI 2.x and RHOAI 3.0. We were using annotations and labels that were correct for RHOAI 2.x but not fully compatible with RHOAI 3.0.

## Solution - Correct RHOAI 3.0 Format

Based on the working reference repository ([tsailiming/openshift-ai-bootstrap, rhoai-3 branch](https://github.com/tsailiming/openshift-ai-bootstrap/tree/rhoai-3)), here's the correct format:

### Hardware Profile YAML

```yaml
kind: HardwareProfile
apiVersion: infrastructure.opendatahub.io/v1
metadata:
  name: nvidia-gpu
  namespace: redhat-ods-applications
spec:
  description: 'Nvidia GPU hardware profile for GPU workloads'
  displayName: 'Nvidia GPU'
  enabled: true
  identifiers:
    - defaultCount: 2
      displayName: CPU
      identifier: cpu
      maxCount: 16
      minCount: 1
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
```

### Key Differences from RHOAI 2.x

| Field | RHOAI 2.x | RHOAI 3.0 |
|-------|-----------|-----------|
| API Version | `infrastructure.opendatahub.io/v1alpha1` | `infrastructure.opendatahub.io/v1` |
| `description` | `spec.description` | `spec.description` (but stripped in v1) |
| `displayName` | `spec.displayName` | `spec.displayName` (but stripped in v1) |
| `enabled` | `spec.enabled` | `spec.enabled` (but stripped in v1) |
| Dashboard Config | `disableHardwareProfiles: false` | Field removed (deprecated) |
| Kueue Management | `managementState: Managed` | `managementState: Removed` or `Unmanaged` |

### Dashboard Configuration

```yaml
apiVersion: opendatahub.io/v1alpha
kind: OdhDashboardConfig
metadata:
  name: odh-dashboard-config
  namespace: redhat-ods-applications
spec:
  dashboardConfig:
    disableTracking: false
    genAiStudio: true
    modelAsService: true
  hardwareProfileOrder: []
  notebookController:
    enabled: true
    notebookNamespace: rhods-notebooks
    pvcSize: 20Gi
  templateDisablement: []
  templateOrder: []
```

**Note**: `disableHardwareProfiles` field is **deprecated and removed** in RHOAI 3.0.

### DataScienceCluster Configuration

```yaml
apiVersion: datasciencecluster.opendatahub.io/v2
kind: DataScienceCluster
metadata:
  name: default-dsc
spec:
  components:
    kueue:
      defaultClusterQueueName: default
      defaultLocalQueueName: default
      managementState: Removed  # ← Use "Removed", not "Managed"
    # ... other components
```

## Important Notes

1. **API Version**: Always use `infrastructure.opendatahub.io/v1` for RHOAI 3.0
2. **Spec Fields**: While `description`, `displayName`, and `enabled` can be specified in the YAML, they are **stripped out** when the resource is created in the cluster (converted to v1)
3. **No Annotations Needed**: Unlike our previous attempts, you don't need to add `opendatahub.io/description`, `opendatahub.io/managed`, etc. as annotations
4. **No Labels Needed**: You don't need `app.kubernetes.io/part-of` or other labels
5. **Kueue**: In RHOAI 3.0, Kueue should be set to `Removed` (not `Managed` or `Unmanaged`)
6. **No Scheduling Constraints**: Don't add `nodeSelector` or `tolerations` to the hardware profile - let the GPU resource request handle scheduling

## Verification Steps

### 1. Check Hardware Profiles

```bash
oc get hardwareprofiles -n redhat-ods-applications
```

Expected output:
```
NAME              AGE
default-profile   3d
nvidia-gpu        1m
```

### 2. Verify Profile Details

```bash
oc get hardwareprofile nvidia-gpu -n redhat-ods-applications -o yaml
```

### 3. Check DataScienceCluster Status

```bash
oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
```

Expected: `"status": "True"`

### 4. Restart Dashboard

```bash
oc delete pods -l app=rhods-dashboard -n redhat-ods-applications
oc rollout status deployment/rhods-dashboard -n redhat-ods-applications
```

### 5. Hard Refresh Browser

- **Chrome/Edge**: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows/Linux)
- **Firefox**: Cmd+Shift+R (Mac) or Ctrl+F5 (Windows/Linux)

### 6. Test in Dashboard

1. Navigate to: Data Science Projects → 0-demo → Deploy model
2. Check: Hardware profile dropdown should show both `default-profile` and `nvidia-gpu`

## Troubleshooting

### Profile Still Not Visible

1. **Check Dashboard Logs**:
   ```bash
   oc logs -n redhat-ods-applications deployment/rhods-dashboard --tail=50 | grep -i "hardware\|profile"
   ```

2. **Verify GPU Node**:
   ```bash
   oc get nodes -l nvidia.com/gpu.present=true
   oc get nodes -o json | jq -r '.items[] | select(.status.capacity."nvidia.com/gpu" != null) | {name: .metadata.name, gpu: .status.capacity."nvidia.com/gpu"}'
   ```

3. **Check NFD**:
   ```bash
   oc get pods -n openshift-nfd
   ```

4. **Clear Browser Cache**:
   - Clear all cached images and files
   - Try incognito/private browsing mode

### DataScienceCluster Not Ready

```bash
oc get datasciencecluster default-dsc -o yaml
```

Look for conditions and error messages in the status section.

## Reference

- **Working Repository**: [tsailiming/openshift-ai-bootstrap (rhoai-3 branch)](https://github.com/tsailiming/openshift-ai-bootstrap/tree/rhoai-3)
- **Date**: November 23, 2025
- **RHOAI Version**: 3.0
- **RHAIIS Version**: 3.2.3

## Applied Changes

### 1. Deleted Old Profiles

```bash
oc delete hardwareprofile gpu-profile small-gpu-profile test-gpu-profile cai-gpu-profile reference-gpu-profile -n redhat-ods-applications
```

### 2. Created New Profile

```bash
oc apply -f - <<EOF
kind: HardwareProfile
apiVersion: infrastructure.opendatahub.io/v1
metadata:
  name: nvidia-gpu
  namespace: redhat-ods-applications
spec:
  description: 'Nvidia GPU hardware profile for GPU workloads'
  displayName: 'Nvidia GPU'
  enabled: true
  identifiers:
    - defaultCount: 2
      displayName: CPU
      identifier: cpu
      maxCount: 16
      minCount: 1
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
EOF
```

### 3. Updated Kueue Configuration

```bash
oc patch datasciencecluster default-dsc --type=merge -p '{"spec":{"components":{"kueue":{"managementState":"Removed"}}}}'
```

### 4. Restarted Dashboard

```bash
oc delete pods -l app=rhods-dashboard -n redhat-ods-applications
```

## Summary

✅ **Hardware Profile**: Using correct RHOAI 3.0 v1 API format  
✅ **Kueue**: Set to `Removed` (not `Unmanaged` or `Managed`)  
✅ **Dashboard**: Restarted to pick up changes  
✅ **No Deprecated Fields**: Removed `disableHardwareProfiles` from dashboard config  
✅ **Simplified Format**: No extra annotations or labels needed  

The hardware profiles should now be visible and functional in the RHOAI 3.0 dashboard! 🚀

