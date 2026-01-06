# Verification Checklist - Kueue and Model Deployment

## Current Cluster Status ✅

Based on the fixes applied, your cluster should now have:

### 1. Operators Installed
- ✅ **cert-manager**: v1.18.0 in `cert-manager-operator` namespace
- ✅ **Kueue**: v1.1.0 in `openshift-operators` namespace
- ✅ **Leader Worker Set**: v1.0.0 in `openshift-lws-operator` namespace
- ✅ **NFD**: Node Feature Discovery
- ✅ **GPU Operator**: NVIDIA GPU operator
- ✅ **RHCL**: Red Hat Connectivity Link (Kuadrant)
- ✅ **RHOAI**: Red Hat OpenShift AI 3.0

### 2. Kueue Configuration
- ✅ **Kueue CR**: Ready status
- ✅ **DSC Kueue**: `managementState: Unmanaged`
- ✅ **Dashboard**: `disableKueue: false`
- ✅ **ClusterQueue**: `default` created
- ✅ **LocalQueue**: `default` in `0-demo` namespace
- ✅ **Project Label**: `kueue.openshift.io/managed=true` on `0-demo`

### 3. Hardware Profiles
- ✅ **default-profile**: In `redhat-ods-applications`
- ✅ **gpu-profile**: In `redhat-ods-applications`
- ✅ **small-gpu-profile**: In `redhat-ods-applications`
- ✅ **test-gpu-profile**: In `redhat-ods-applications`

## Quick Verification Commands

Run these commands to verify everything is working:

```bash
# 1. Check all operators are Succeeded
echo "=== Checking Operators ==="
oc get csv -n cert-manager-operator | grep cert-manager
oc get csv -n openshift-operators | grep kueue
oc get csv -n openshift-lws-operator | grep leader
oc get csv -n nvidia-gpu-operator | grep gpu
oc get csv -n openshift-nfd | grep nfd
oc get csv -n kuadrant-system | grep rhcl
oc get csv -n redhat-ods-operator | grep rhods

# 2. Check Kueue is Ready
echo ""
echo "=== Checking Kueue Status ==="
oc get kueue default-kueue

# 3. Check Kueue Resources
echo ""
echo "=== Checking Kueue Resources ==="
oc get clusterqueue
oc get localqueue -n 0-demo

# 4. Check Dashboard Config
echo ""
echo "=== Checking Dashboard Config ==="
oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
  -o jsonpath='{.spec.dashboardConfig.disableKueue}'
echo ""

# 5. Check Project Label
echo ""
echo "=== Checking Project Label ==="
oc get namespace 0-demo -o jsonpath='{.metadata.labels.kueue\.openshift\.io/managed}'
echo ""

# 6. Check Hardware Profiles
echo ""
echo "=== Checking Hardware Profiles ==="
oc get hardwareprofiles -n redhat-ods-applications
```

## Expected Output

### Operators (all should show "Succeeded")
```
cert-manager-operator.v1.18.0   cert-manager Operator for Red Hat OpenShift   1.18.0    Succeeded
kueue-operator.v1.1.0           Red Hat build of Kueue                         1.1.0     Succeeded
leader-worker-set.v1.0.0        Red Hat build of Leader Worker Set             1.0.0     Succeeded
```

### Kueue Status
```
NAME            READY   REASON
default-kueue   True    
```

### Kueue Resources
```
NAME      COHORT   PENDING WORKLOADS
default            0

NAMESPACE   NAME      CLUSTERQUEUE   PENDING WORKLOADS   ADMITTED WORKLOADS
0-demo      default   default        0                   0
```

### Dashboard Config
```
false
```

### Project Label
```
true
```

### Hardware Profiles
```
NAME                AGE
default-profile     3d
gpu-profile         3d
small-gpu-profile   1h
test-gpu-profile    1h
```

## Testing Model Deployment

### 1. Access RHOAI Dashboard
```bash
# Get dashboard URL
oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}'
```

### 2. Navigate to Model Deployment
1. Go to **Data Science Projects**
2. Select **0-demo** project
3. Click **Deploy model**

### 3. Verify Kueue is Working
You should now see:
- ✅ **No "Kueue is disabled" error**
- ✅ **Hardware profiles are available** in the dropdown
- ✅ **Model deployment form is fully functional**

### 4. Deploy a Test Model
Try deploying a simple model to verify everything works:
- **Model Name**: test-model
- **Model Framework**: vLLM
- **Runtime**: llm-d
- **Hardware Profile**: gpu-profile or small-gpu-profile
- **Model Location**: Any valid model path

## Troubleshooting

### If Kueue Still Shows as Disabled

```bash
# 1. Check Kueue CR status
oc get kueue default-kueue -o yaml

# 2. If status shows "Not Ready", check for errors
oc get kueue default-kueue -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'

# 3. Check cert-manager is running
oc get pods -n cert-manager

# 4. Check Kueue operator logs
oc logs -n openshift-operators deployment/openshift-kueue-operator --tail=50
```

### If Hardware Profiles Don't Appear

```bash
# 1. Verify profiles exist in redhat-ods-applications
oc get hardwareprofiles -n redhat-ods-applications

# 2. Check if profiles have correct labels
oc get hardwareprofiles -n redhat-ods-applications -o yaml | grep -A 2 labels

# 3. Refresh the dashboard (hard refresh: Cmd+Shift+R on Mac)
```

### If Model Deployment Fails

```bash
# 1. Check if project has Kueue label
oc get namespace 0-demo -o jsonpath='{.metadata.labels}'

# 2. Check if LocalQueue exists
oc get localqueue -n 0-demo

# 3. Check InferenceService status
oc get inferenceservice -n 0-demo
oc describe inferenceservice <model-name> -n 0-demo
```

## Scripts Updated

The following scripts now include cert-manager, LWS, and Kueue installation:

### Main Workflow Scripts
1. **`integrated-workflow-v2.sh`** (Modular version - default)
   - Uses functions from `lib/functions/operators.sh`
   - Automatically installs cert-manager when Kueue is installed

2. **`scripts/integrated-workflow.sh`** (Legacy version)
   - Now includes inline cert-manager, LWS, and Kueue installation functions
   - Matches functionality of modular version

### Function Libraries
1. **`lib/functions/operators.sh`**
   - `install_certmanager_operator()` - New function
   - `install_kueue_operator()` - Enhanced with cert-manager check
   - `install_lws_operator()` - Enhanced with duplicate cleanup

2. **`lib/functions/rhoai.sh`**
   - `create_datasciencecluster_v2()` - Kueue set to Unmanaged
   - `configure_rhoai_dashboard()` - Kueue enabled

## Future Installations

When you run `./rhoai-toolkit.sh` in the future, it will:
1. ✅ Install cert-manager automatically
2. ✅ Install LWS operator in dedicated namespace
3. ✅ Install Kueue operator with correct channel
4. ✅ Configure DSC with Kueue Unmanaged
5. ✅ Enable Kueue in dashboard
6. ✅ Create default ClusterQueue and LocalQueue

No manual intervention needed! 🎉

## Summary

**What Was Fixed:**
- ❌ **Before**: Kueue disabled, cert-manager missing, model deployment failed
- ✅ **After**: Kueue enabled, cert-manager installed, model deployment works

**Installation Order:**
1. NFD Operator
2. GPU Operator
3. RHCL Operator (Kuadrant)
4. **cert-manager Operator** ← NEW
5. **Leader Worker Set Operator** ← NEW
6. **Kueue Operator** ← NEW
7. RHOAI Operator
8. DataScienceCluster (with Kueue Unmanaged)

**Key Configuration:**
- Kueue: `managementState: Unmanaged` (not Removed or Managed)
- Dashboard: `disableKueue: false`
- Projects: `kueue.openshift.io/managed=true` label

Your cluster is now ready for model deployment! 🚀

