# Kueue Fix Summary - Model Deployment Issue

## Problem

User reported error when trying to deploy models:
```
Kueue is disabled in this cluster

This project uses local queue for workload allocation, which relies on Kueue. 
To deploy a model or create a workbench in this project, ask your administrator 
to enable Kueue or change this project's workload allocation strategy.
```

## Root Cause Analysis

The issue had multiple layers:

### 1. Kueue Set to `Removed` Instead of `Unmanaged`
- **Problem**: DataScienceCluster had Kueue `managementState: Removed`
- **Impact**: Kueue was completely disabled, preventing model deployment
- **Correct State**: Should be `Unmanaged` (not `Managed` or `Removed`)

### 2. Missing cert-manager Dependency
- **Problem**: Kueue operator requires cert-manager to be installed
- **Error**: `"KueueOperator reconciliation failed: please make sure that cert-manager is installed on your cluster"`
- **Impact**: Kueue controller couldn't deploy, so CRDs for ClusterQueue/LocalQueue/ResourceFlavor were missing

### 3. Duplicate Kueue Subscriptions
- **Problem**: Two Kueue subscriptions existed:
  - `openshift-kueue-system` with channel `stable` (incorrect)
  - `openshift-operators` with channel `stable-v1.1` (correct)
- **Impact**: Resource conflicts and confusion

## Solution Applied

### Step 1: Set Kueue to Unmanaged in DSC
```bash
oc patch datasciencecluster default-dsc --type='merge' \
  -p '{"spec":{"components":{"kueue":{"managementState":"Unmanaged","defaultClusterQueueName":"default","defaultLocalQueueName":"default"}}}}'
```

### Step 2: Enable Kueue in Dashboard
```bash
oc patch odhdashboardconfig odh-dashboard-config \
  -n redhat-ods-applications \
  --type merge \
  -p '{"spec":{"dashboardConfig":{"disableKueue":false}}}'
```

### Step 3: Install cert-manager Operator
```bash
# Create namespace
oc create namespace cert-manager-operator

# Create OperatorGroup (AllNamespaces mode)
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cert-manager-operator
  namespace: cert-manager-operator
spec: {}
EOF

# Install cert-manager subscription
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-cert-manager-operator
  namespace: cert-manager-operator
spec:
  channel: stable-v1
  installPlanApproval: Automatic
  name: openshift-cert-manager-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

### Step 4: Clean Up Duplicate Kueue Subscription
```bash
# Delete duplicate in openshift-kueue-system
oc delete subscription kueue-operator -n openshift-kueue-system
oc delete csv kueue-operator.v1.1.0 -n openshift-kueue-system
```

### Step 5: Wait for Kueue to Reconcile
After cert-manager was installed, the Kueue operator automatically:
- Deployed the Kueue controller
- Created the necessary CRDs (ClusterQueue, LocalQueue, ResourceFlavor)
- Created the default ClusterQueue and LocalQueue

## Verification

### 1. Check Kueue CR Status
```bash
oc get kueue default-kueue
# Should show: READY=True, REASON=(empty)
```

### 2. Check Kueue CRDs
```bash
oc get crd | grep -E "clusterqueue|localqueue|resourceflavor"
# Should show:
# clusterqueues.kueue.x-k8s.io
# localqueues.kueue.x-k8s.io
# resourceflavors.kueue.x-k8s.io
```

### 3. Check ClusterQueue and LocalQueue
```bash
oc get clusterqueue
# Should show: default ClusterQueue

oc get localqueue -A
# Should show: default LocalQueue in your project namespace
```

### 4. Check Project Label
```bash
oc get namespace 0-demo -o jsonpath='{.metadata.labels.kueue\.openshift\.io/managed}'
# Should show: true
```

### 5. Check Dashboard Config
```bash
oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
  -o jsonpath='{.spec.dashboardConfig.disableKueue}'
# Should show: false
```

## Results

✅ **Kueue CR**: Ready  
✅ **cert-manager**: Installed (v1.18.0)  
✅ **Kueue CRDs**: Installed  
✅ **ClusterQueue**: Created (default)  
✅ **LocalQueue**: Created in 0-demo  
✅ **Dashboard**: Kueue enabled  
✅ **Project Label**: kueue.openshift.io/managed=true  

## Understanding Kueue in RHOAI 3.0

### What is Kueue?
Kueue is a workload queue management system that provides:
- **Resource Quotas**: Limit resources per project/team
- **Fair Sharing**: Distribute GPU/CPU resources fairly
- **Priority Scheduling**: High-priority workloads run first
- **Multi-tenancy**: Isolate workloads between teams

### When to Use Kueue?
- ✅ **Multi-tenant environments** with shared GPU resources
- ✅ **Resource-constrained clusters** needing fair allocation
- ✅ **Priority-based scheduling** for different workload types
- ❌ **Single-user clusters** with dedicated resources (optional)

### Kueue Management States

1. **`Managed`** (NOT supported in RHOAI 3.0):
   - RHOAI manages Kueue installation and configuration
   - **Deprecated**: This mode is no longer available

2. **`Unmanaged`** (Correct for RHOAI 3.0):
   - Kueue operator is installed separately
   - RHOAI uses Kueue but doesn't manage it
   - Administrator controls Kueue configuration
   - **This is the correct state for model deployment**

3. **`Removed`** (Disables Kueue):
   - Kueue is completely disabled
   - Projects cannot use queue-based workload management
   - **This was causing the error**

### Required Components for Kueue

1. ✅ **Kueue Operator** (Red Hat build of Kueue)
   - Package: `kueue-operator`
   - Channel: `stable-v1.1`
   - Namespace: `openshift-operators`

2. ✅ **cert-manager Operator**
   - Package: `openshift-cert-manager-operator`
   - Channel: `stable-v1`
   - Namespace: `cert-manager-operator`
   - **Required by Kueue** for webhook certificates

3. ✅ **DSC Configuration**
   ```yaml
   kueue:
     managementState: Unmanaged
     defaultClusterQueueName: default
     defaultLocalQueueName: default
   ```

4. ✅ **Dashboard Configuration**
   ```yaml
   dashboardConfig:
     disableKueue: false
   ```

5. ✅ **Project Label**
   ```yaml
   metadata:
     labels:
       kueue.openshift.io/managed: "true"
   ```

## How Model Deployment Works with Kueue

When you deploy a model in a Kueue-enabled project:

1. **InferenceService is created** with label `kueue.x-k8s.io/queue-name: default`
2. **Kueue intercepts the workload** and checks resource availability
3. **If resources are available**, Kueue admits the workload
4. **Pods are scheduled** with resource guarantees
5. **Workload runs** until completion or deletion

### Example InferenceService with Kueue
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: my-model
  namespace: 0-demo
  labels:
    kueue.x-k8s.io/queue-name: default  # Required for Kueue
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: llm-d
```

## Common Issues and Solutions

### Issue: "Kueue is disabled"
**Solution**: Set Kueue to `Unmanaged` in DSC and enable in dashboard

### Issue: "ResourceFlavor not found"
**Solution**: Install cert-manager operator

### Issue: "LocalQueue not found"
**Solution**: Add label `kueue.openshift.io/managed=true` to namespace

### Issue: Kueue operator logs show cert-manager error
**Solution**: Install cert-manager operator with proper OperatorGroup

## Files to Update

The following scripts should be updated to include cert-manager installation:

### 1. `lib/functions/operators.sh`
Add a new function:
```bash
# Install cert-manager Operator (required by Kueue)
install_certmanager_operator() {
    print_header "Installing cert-manager Operator"
    
    # Check if already installed
    if check_operator_installed "cert-manager-operator" "cert-manager-operator"; then
        print_success "cert-manager Operator already installed"
        return 0
    fi
    
    print_step "Creating cert-manager-operator namespace..."
    oc create namespace cert-manager-operator 2>/dev/null || true
    
    print_step "Creating OperatorGroup..."
    cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cert-manager-operator
  namespace: cert-manager-operator
spec: {}
EOF
    
    print_step "Installing cert-manager Operator subscription..."
    cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-cert-manager-operator
  namespace: cert-manager-operator
spec:
  channel: stable-v1
  installPlanApproval: Automatic
  name: openshift-cert-manager-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
    
    # Wait for operator to be ready
    print_step "Waiting for cert-manager operator to be ready..."
    local timeout=180
    local elapsed=0
    until oc get csv -n cert-manager-operator 2>/dev/null | grep -q "cert-manager-operator.*Succeeded"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "cert-manager operator not ready yet (continuing anyway)"
            return 1
        fi
        echo "Waiting for cert-manager operator... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "cert-manager operator installation complete"
}
```

### 2. `lib/functions/rhoai.sh`
Update the `install_rhoai_operator` function to:
1. Install cert-manager before Kueue
2. Set Kueue to `Unmanaged` (not `Removed`)
3. Enable Kueue in dashboard

### 3. Workflow Scripts
Update `integrated-workflow-v2.sh` and `scripts/integrated-workflow.sh` to:
1. Call `install_certmanager_operator` before Kueue
2. Ensure DSC has Kueue set to `Unmanaged`

## Summary

**Key Takeaways**:
1. ✅ Kueue requires `managementState: Unmanaged` (not `Removed` or `Managed`)
2. ✅ cert-manager is a **required dependency** for Kueue
3. ✅ Projects need `kueue.openshift.io/managed=true` label
4. ✅ Dashboard needs `disableKueue: false`
5. ✅ Clean up duplicate Kueue subscriptions

**Installation Order**:
1. cert-manager Operator
2. Kueue Operator
3. Set DSC Kueue to `Unmanaged`
4. Enable Kueue in dashboard
5. Label projects with `kueue.openshift.io/managed=true`

The model deployment should now work! 🚀

