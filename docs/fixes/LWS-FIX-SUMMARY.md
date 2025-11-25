# Leader Worker Set (LWS) Operator Fix Summary

## Issue Encountered

After manually installing the Leader Worker Set operator through the OpenShift UI, the operator showed as "Unknown" with the error:
- **Error**: "catalog sources unhealthy or something"
- **Root Cause**: Multiple OperatorGroups in the same namespace

## Root Cause Analysis

The `openshift-lws-operator` namespace had **2 duplicate OperatorGroups**:
1. `leader-worker-set-operator` (created by earlier script attempts)
2. `lws-operator-group` (created by script)

This caused the error:
```
Multiple OperatorGroup found in the same namespace
```

When multiple OperatorGroups exist in the same namespace, the Operator Lifecycle Manager (OLM) cannot determine which one to use, blocking the installation.

## Solution Applied

### 1. Deleted Duplicate OperatorGroups
```bash
oc delete operatorgroup leader-worker-set-operator -n openshift-lws-operator
oc delete operatorgroup lws-operator-group -n openshift-lws-operator
```

### 2. Created Single, Clean OperatorGroup
```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-lws-operator  # Name matches namespace
  namespace: openshift-lws-operator
spec:
  targetNamespaces:
  - openshift-lws-operator
```

**Key Change**: OperatorGroup name now matches the namespace name (`openshift-lws-operator`) to avoid naming conflicts.

### 3. Result
After creating the clean OperatorGroup, the operator installed successfully:
```
leader-worker-set.v1.0.0   Red Hat build of Leader Worker Set   1.0.0   Succeeded
```

## Correct LWS Installation Configuration

```yaml
# 1. Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-lws-operator

---
# 2. OperatorGroup (IMPORTANT: name matches namespace)
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-lws-operator
  namespace: openshift-lws-operator
spec:
  targetNamespaces:
  - openshift-lws-operator

---
# 3. Subscription
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: leader-worker-set
  namespace: openshift-lws-operator
spec:
  channel: stable-v1.0
  installPlanApproval: Automatic
  name: leader-worker-set
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

## Changes Made to Scripts

### File: `lib/functions/operators.sh`

**Function**: `install_lws_operator()`

**Changes**:
1. **Added duplicate OperatorGroup detection and cleanup**:
   ```bash
   local existing_ogs=$(oc get operatorgroup -n "$lws_namespace" -o name 2>/dev/null | wc -l)
   if [ "$existing_ogs" -gt 1 ]; then
       print_step "Removing duplicate OperatorGroups..."
       oc delete operatorgroup --all -n "$lws_namespace"
       sleep 2
   fi
   ```

2. **Changed OperatorGroup name** to match namespace:
   - ❌ Old: `name: lws-operator-group`
   - ✅ New: `name: openshift-lws-operator`

3. **Split namespace and OperatorGroup creation** into separate steps for clarity

## Why This Matters

### Best Practice: OperatorGroup Naming
- **Recommendation**: Name the OperatorGroup the same as the namespace
- **Reason**: Avoids confusion and potential conflicts
- **Example**: For namespace `openshift-lws-operator`, use OperatorGroup name `openshift-lws-operator`

### Multiple OperatorGroups Error
- **Rule**: Only ONE OperatorGroup per namespace
- **Why**: OLM needs to know which OperatorGroup controls operator installations
- **Impact**: Multiple OperatorGroups block ALL operator installations in that namespace

## Verification

After the fix, verify LWS is working:

```bash
# 1. Check only one OperatorGroup exists
oc get operatorgroup -n openshift-lws-operator
# Should show: openshift-lws-operator

# 2. Check CSV is Succeeded
oc get csv -n openshift-lws-operator | grep leader
# Should show: leader-worker-set.v1.0.0 ... Succeeded

# 3. Check subscription is healthy
oc get subscription leader-worker-set -n openshift-lws-operator
# Should show: leader-worker-set ... stable-v1.0

# 4. Verify in OpenShift Console
# Navigate to: Operators → Installed Operators
# Namespace: openshift-lws-operator
# Should see: "Red Hat build of Leader Worker Set" with status "Succeeded"
```

## Prevention in Future Installations

The updated `lib/functions/operators.sh` now:
1. ✅ Checks for duplicate OperatorGroups before installation
2. ✅ Cleans up duplicates automatically
3. ✅ Uses namespace-matching OperatorGroup name
4. ✅ Provides clear status messages during installation

## Related Files Updated

1. **`lib/functions/operators.sh`** - Fixed `install_lws_operator()` function
2. **`docs/CLUSTER-RESTART-ISSUES.md`** - Added "Multiple OperatorGroup" troubleshooting
3. **`LWS-FIX-SUMMARY.md`** - This document

## Lessons Learned

1. **Always check for existing OperatorGroups** before creating new ones
2. **Name OperatorGroups to match their namespace** for clarity
3. **The "Unknown" status** in the UI often indicates an OperatorGroup conflict
4. **Multiple OperatorGroups** is a silent blocker - no obvious error in UI
5. **Manual cleanup** of duplicates is sometimes necessary before automated scripts can work

## Summary

✅ **Problem**: Multiple OperatorGroups blocking LWS installation  
✅ **Solution**: Delete duplicates, create single OperatorGroup with namespace-matching name  
✅ **Result**: LWS operator now installs successfully  
✅ **Prevention**: Scripts updated to detect and prevent this issue in future  

The Leader Worker Set operator is now properly installed and ready for use with RHOAI workload management!

