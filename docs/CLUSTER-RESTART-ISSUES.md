# Cluster Restart Issues - Troubleshooting Guide

## Problem: RHOAI Dashboard Shows "Could not load component state" After Cluster Restart

### Symptoms
- After stopping and restarting your AWS environment
- RHOAI dashboard loads but shows error: "Could not load component state"
- Operators show "Unknown" status in OpenShift console
- DataScienceCluster status shows "Not Ready"

### Root Cause

When the cluster is stopped and restarted, operator subscriptions may fail to reconcile properly due to:

1. **Incorrect Package Names**: Operator package names changed or were incorrect
2. **Wrong Channels**: Operator channels use versioned names (e.g., `stable-v1.1` not `stable`)
3. **Namespace Requirements**: Some operators (like LWS) require specific namespaces
4. **Kueue Configuration**: Kueue set to `Unmanaged` but missing required resources

## Quick Fix

### Step 1: Check DataScienceCluster Status

```bash
oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
```

If it shows `"status": "False"`, check which component is failing:

```bash
oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}'
```

### Step 2: Fix Kueue (Most Common Issue)

If the error mentions Kueue:

```bash
# Set Kueue to Removed in DSC
oc patch datasciencecluster default-dsc --type=merge -p '{"spec":{"components":{"kueue":{"managementState":"Removed"}}}}'

# Wait for reconciliation
sleep 20

# Check status
oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}'
```

### Step 3: Fix Leader Worker Set

If LWS operator shows "Unknown" or "Failed":

```bash
# Check for duplicate OperatorGroups
oc get operatorgroup -n openshift-lws-operator

# If you see multiple OperatorGroups, delete them all
oc delete operatorgroup --all -n openshift-lws-operator

# Delete any failed subscriptions/CSVs
oc delete subscription leader-worker-set -n openshift-operators 2>/dev/null || true
oc delete csv -n openshift-operators -l operators.coreos.com/leader-worker-set.openshift-operators 2>/dev/null || true

# Reinstall in correct namespace with clean OperatorGroup
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-lws-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-lws-operator
  namespace: openshift-lws-operator
spec:
  targetNamespaces:
  - openshift-lws-operator
---
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
EOF

# Wait for installation
sleep 30
oc get csv -n openshift-lws-operator | grep leader
```

### Step 4: Fix Kueue Operator (If Needed)

If you want to use Kueue for workload management:

```bash
# Check if Kueue operator exists
oc get csv -n openshift-operators | grep kueue

# If not installed or wrong version:
oc delete subscription kueue-operator -n openshift-operators 2>/dev/null || true

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kueue-operator
  namespace: openshift-operators
spec:
  channel: stable-v1.1
  installPlanApproval: Automatic
  name: kueue-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# Wait for installation
sleep 30
oc get csv -n openshift-operators | grep kueue
```

## Detailed Troubleshooting

### Check All Operator Statuses

```bash
echo "=== Checking All Operators ==="
oc get csv -n openshift-operators
oc get csv -n openshift-lws-operator
oc get csv -n kuadrant-system
```

### Check Operator Subscriptions

```bash
echo "=== Checking Subscriptions ==="
oc get subscriptions -n openshift-operators
oc get subscriptions -n openshift-lws-operator
```

### Check Install Plans

```bash
echo "=== Checking Install Plans ==="
oc get installplan -n openshift-operators
```

If install plans show `APPROVED: false`, approve them:

```bash
oc patch installplan <install-plan-name> -n openshift-operators --type merge --patch '{"spec":{"approved":true}}'
```

### Check DataScienceCluster Components

```bash
oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions}' | jq '.[] | select(.status=="False")'
```

## Operator-Specific Issues

### Kueue Operator

**Problem**: Package name confusion
- ❌ Wrong: `openshift-kueue-operator`
- ✅ Correct: `kueue-operator`

**Problem**: Channel doesn't exist
- ❌ Wrong: `channel: stable`
- ✅ Correct: `channel: stable-v1.1`

**Problem**: DSC expects Kueue but it's not configured
- **Solution**: Set Kueue to `Removed` in DSC unless you need workload management

### Leader Worker Set (LWS)

**Problem**: UnsupportedOperatorGroup error
- **Cause**: LWS doesn't support `AllNamespaces` mode
- **Solution**: Install in dedicated `openshift-lws-operator` namespace with proper OperatorGroup

**Problem**: Multiple OperatorGroup error
- **Cause**: Duplicate OperatorGroups in the same namespace
- **Error**: "Multiple OperatorGroup found in the same namespace"
- **Solution**: Delete all OperatorGroups and create a single one with name matching the namespace
- ✅ Correct: OperatorGroup name = `openshift-lws-operator` (matches namespace)

**Problem**: Package name confusion
- ❌ Wrong: `lws-operator`
- ✅ Correct: `leader-worker-set`

**Problem**: Channel doesn't exist
- ❌ Wrong: `channel: stable`
- ✅ Correct: `channel: stable-v1.0`

## Prevention

### Updated Scripts

The main scripts have been updated with:

1. **Correct Package Names**:
   - `kueue-operator` (not `openshift-kueue-operator`)
   - `leader-worker-set` (not `lws-operator`)

2. **Correct Channels**:
   - Kueue: `stable-v1.1`
   - LWS: `stable-v1.0`

3. **Proper Namespace Configuration**:
   - LWS installed in `openshift-lws-operator` with dedicated OperatorGroup
   - Kueue installed in `openshift-operators` (AllNamespaces)

4. **DSC Configuration**:
   - Kueue set to `Removed` by default (can be enabled later if needed)

### Files Updated

- `lib/functions/operators.sh`:
  - `install_kueue_operator()` - Fixed package name and channel
  - `install_lws_operator()` - Fixed package name, channel, and namespace

- `lib/functions/rhoai.sh`:
  - DataScienceCluster creation - Kueue set to `Removed`

- `scripts/integrated-workflow.sh`:
  - Legacy workflow - Kueue set to `Removed`

## Verification

After applying fixes, verify everything is working:

```bash
# 1. Check DSC is Ready
oc get datasciencecluster default-dsc

# Should show: NAME          READY   REASON
#              default-dsc   True    

# 2. Check all operators are Succeeded
oc get csv -n openshift-operators | grep -E "kueue|rhods"
oc get csv -n openshift-lws-operator | grep leader

# 3. Access RHOAI Dashboard
echo "Dashboard URL:"
echo "https://data-science-gateway.apps.<your-cluster-domain>"

# 4. Check dashboard loads without errors
# Open in browser and verify no "Could not load component state" error
```

## When to Enable Kueue

Kueue is optional and only needed if you want:
- Workload queue management
- Resource quotas and fair sharing
- Priority-based scheduling
- Multi-tenancy with resource limits

If you don't need these features, leave Kueue as `Removed` in the DSC.

To enable Kueue later:

```bash
# 1. Ensure Kueue operator is installed (see Step 4 above)

# 2. Set Kueue to Unmanaged in DSC
oc patch datasciencecluster default-dsc --type=merge -p '{"spec":{"components":{"kueue":{"managementState":"Unmanaged","defaultClusterQueueName":"default","defaultLocalQueueName":"default"}}}}'

# 3. Enable in dashboard
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type merge -p '{"spec":{"dashboardConfig":{"disableKueue":false}}}'
```

## Related Documentation

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting
- [HARDWARE-PROFILE-FIX.md](HARDWARE-PROFILE-FIX.md) - Hardware profile issues
- [FIXES-APPLIED.md](../FIXES-APPLIED.md) - Summary of all fixes

## Summary

**Key Takeaways**:
1. ✅ Kueue: Use `kueue-operator` package with `stable-v1.1` channel
2. ✅ LWS: Use `leader-worker-set` package with `stable-v1.0` channel in `openshift-lws-operator` namespace
3. ✅ DSC: Set Kueue to `Removed` unless you need workload management
4. ✅ After cluster restart: Check DSC status and fix any failed operators

The updated scripts will prevent these issues in future installations!

