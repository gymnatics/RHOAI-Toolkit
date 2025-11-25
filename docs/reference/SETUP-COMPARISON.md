# Setup Comparison: Reference Repo vs Our Installation

## Overview

Comprehensive comparison between the reference repository ([tsailiming/openshift-ai-bootstrap, rhoai-3 branch](https://github.com/tsailiming/openshift-ai-bootstrap/tree/rhoai-3)) and our RHOAI 3.0 installation.

---

## Installation Flow Comparison

### Reference Repository Flow

```makefile
make setup-rhoai:
  1. add-gpu-operator (NFD + GPU Operator)
  2. add-nfs-provisioner
  3. Install Kueue operator (but DSC sets it to Removed!)
  4. Install RHOAI operator
  5. Create DataScienceCluster
  6. Configure Dashboard
  7. Create Hardware Profiles
  8. Enable User Workload Monitoring

make setup-llmd (for llm-d/distributed inference):
  1. Create Gateway
  2. Install LWS operator
  3. Install RHCL (Kuadrant) operator
  4. Create Kuadrant CR
  5. Configure Authorino with TLS
  6. Restart model controller pods
```

### Our Installation Flow

```bash
complete-setup.sh → integrated-workflow-v2.sh:
  1. Install NFD operator
  2. Install GPU Operator
  3. Install cert-manager operator
  4. Install LWS operator
  5. Install Kueue operator
  6. Install RHCL (Kuadrant) operator
  7. Install RHOAI operator
  8. Create DataScienceCluster
  9. Configure Dashboard
  10. Create Hardware Profiles
  11. Enable User Workload Monitoring
  12. Setup MaaS (optional)
```

---

## Operator Comparison

| Operator | Reference Repo | Our Setup | Match? |
|----------|---------------|-----------|--------|
| **NFD** | ✅ `openshift-nfd` | ✅ `openshift-nfd` | ✅ |
| **GPU** | ✅ `nvidia-gpu-operator` | ✅ `nvidia-gpu-operator` | ✅ |
| **Kueue** | ✅ `openshift-kueue-operator` (installed but DSC=Removed) | ✅ `openshift-operators` | ⚠️ Different namespace! |
| **LWS** | ✅ `openshift-lws-operator` | ✅ `openshift-lws-operator` | ✅ |
| **RHCL** | ✅ `openshift-operators` (AllNamespaces) | ✅ `kuadrant-system` | ⚠️ Different namespace! |
| **cert-manager** | ❌ Not installed | ✅ `cert-manager-operator` | ⚠️ We have extra! |
| **RHOAI** | ✅ `redhat-ods-operator` | ✅ `redhat-ods-operator` | ✅ |

### Key Differences

#### 1. **Kueue Operator Namespace**

**Reference Repo**:
```yaml
apiVersion: v1
kind: Namespace
metadata:    
  name: openshift-kueue-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:  
  name: openshift-kueue-operator
  namespace: openshift-kueue-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kueue-operator
  namespace: openshift-kueue-operator  # ← Dedicated namespace
spec:
  channel: stable-v1.1
  name: kueue-operator
```

**Our Setup**:
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kueue-operator
  namespace: openshift-operators  # ← openshift-operators (AllNamespaces)
spec:
  channel: stable-v1.1
  name: kueue-operator
```

**Impact**: 
- Reference repo: Kueue operator scoped to its own namespace
- Our setup: Kueue operator watches all namespaces
- **Both work**, but reference repo is more isolated

#### 2. **RHCL (Kuadrant) Operator Namespace**

**Reference Repo**:
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhcl-operator
  namespace: openshift-operators  # ← AllNamespaces mode
spec:
  channel: stable
  name: rhcl-operator
```

**Our Setup**:
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhcl-operator
  namespace: kuadrant-system  # ← OwnNamespace mode (WRONG!)
spec:
  channel: stable
  name: rhcl-operator
```

**Impact**: 
- ❌ **Our setup is WRONG!** RHCL requires `AllNamespaces` mode
- This was causing the `UnsupportedOperatorGroup` error we fixed earlier
- We should move RHCL subscription to `openshift-operators`

#### 3. **cert-manager Operator**

**Reference Repo**: ❌ Not installed (not needed for RawDeployment mode)

**Our Setup**: ✅ Installed in `cert-manager-operator` namespace

**Impact**:
- cert-manager is required for Kueue when using `managementState: Unmanaged`
- Reference repo doesn't need it because Kueue is `Removed`
- **Our setup is correct** for Serverless + Kueue mode

---

## DataScienceCluster Comparison

### Reference Repository

```yaml
apiVersion: datasciencecluster.opendatahub.io/v2
kind: DataScienceCluster
metadata:
  name: default-dsc
spec:
  components:
    kserve:
      managementState: Managed
      rawDeploymentServiceConfig: Headless  # ← RawDeployment mode
      nim:
        managementState: Managed
    kueue:
      defaultClusterQueueName: default
      defaultLocalQueueName: default
      managementState: Removed  # ← Kueue disabled!
    # ... other components
```

### Our Setup

```yaml
apiVersion: datasciencecluster.opendatahub.io/v2
kind: DataScienceCluster
metadata:
  name: default-dsc
spec:
  components:
    kserve:
      managementState: Managed
      # No rawDeploymentServiceConfig (Serverless mode)
    kueue:
      defaultClusterQueueName: default
      defaultLocalQueueName: default
      managementState: Unmanaged  # ← Kueue enabled!
    # ... other components
```

**Key Differences**:
1. **KServe Mode**: Reference uses `RawDeployment`, we use `Serverless`
2. **Kueue**: Reference has `Removed`, we have `Unmanaged`
3. **Deployment Strategy**: Different approaches (see `KSERVE-DEPLOYMENT-MODES.md`)

---

## Hardware Profile Comparison

### Reference Repository

```yaml
kind: HardwareProfile
apiVersion: infrastructure.opendatahub.io/v1
metadata:
  name: nvidia-gpu  
  namespace: redhat-ods-applications
spec:
  description: 'Nvidia GPU'
  displayName: 'Nvidia GPU'
  enabled: true
  identifiers:
    - defaultCount: 2
      displayName: CPU
      identifier: cpu
      maxCount: 4
      minCount: 1
      resourceType: CPU
    - defaultCount: 4Gi
      displayName: Memory
      identifier: memory
      maxCount: 32Gi
      minCount: 2Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: Nvidia GPU
      identifier: nvidia.com/gpu
      maxCount: 2
      minCount: 1
      resourceType: Accelerator
```

### Our Setup

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

**Differences**:
- Our setup has higher resource limits (more flexible)
- Otherwise identical format
- **Both correct** for RHOAI 3.0

**Note**: The `description`, `displayName`, and `enabled` fields are **stripped out** when the resource is created (converted to v1 API), but they can still be specified in the YAML.

---

## llm-d (Distributed Inference) Setup

### Reference Repository Approach

```makefile
make setup-llmd:
  1. Create Gateway (for distributed inference routing)
  2. Install LWS operator
  3. Install RHCL (Kuadrant) operator in openshift-operators
  4. Create Kuadrant CR in kuadrant-system
  5. Configure Authorino with TLS
  6. Restart model controller pods
```

**Key Files**:
- `yaml/rhoai/gateway.yaml.tmpl` - Gateway for llm-d
- `yaml/rhoai/lws.yaml` - LWS operator subscription
- `yaml/rhoai/kuadrant.yaml` - RHCL operator subscription
- `yaml/rhoai/kuadrant-cr.yaml` - Kuadrant instance
- `yaml/rhoai/authorino.yaml` - Authorino configuration

### Our Setup

We installed all these operators during the main setup, but we don't have a separate `setup-llmd` step. Our setup is more integrated:

1. ✅ LWS operator installed
2. ✅ RHCL (Kuadrant) operator installed
3. ✅ Kuadrant CR created (for MaaS)
4. ✅ Authorino configured with TLS (for MaaS)
5. ❌ No Gateway for llm-d (we don't use llm-d)

**Difference**: 
- Reference repo has a **separate llm-d setup** for distributed inference
- Our setup focuses on **MaaS** (Model as a Service) instead
- Both use similar infrastructure (Kuadrant, Authorino)

---

## Issues Found in Our Setup

### 1. ❌ RHCL Operator in Wrong Namespace

**Problem**: Our RHCL subscription is in `kuadrant-system` with `OwnNamespace` mode

**Should Be**: In `openshift-operators` with `AllNamespaces` mode

**Fix**:
```bash
# Delete current subscription
oc delete subscription rhcl-operator -n kuadrant-system

# Create correct subscription
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhcl-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: rhcl-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

### 2. ⚠️ Kueue Operator in Different Namespace

**Current**: Our Kueue is in `openshift-operators` (AllNamespaces)

**Reference**: Kueue is in `openshift-kueue-operator` (OwnNamespace)

**Impact**: Both work, but reference repo's approach is more isolated

**Recommendation**: Keep as-is (our approach works fine)

### 3. ✅ cert-manager Extra Operator

**Current**: We have cert-manager installed

**Reference**: They don't have cert-manager

**Impact**: We need it for Kueue with `managementState: Unmanaged`

**Recommendation**: Keep it (required for our Serverless + Kueue setup)

---

## Recommendations

### High Priority

1. **Fix RHCL Operator Namespace** ⚠️
   - Move RHCL subscription from `kuadrant-system` to `openshift-operators`
   - This fixes the `UnsupportedOperatorGroup` error permanently

### Medium Priority

2. **Consider Kueue Namespace** (Optional)
   - Current setup works fine
   - Reference repo's isolated approach is cleaner
   - Only change if you want better isolation

### Low Priority

3. **Add llm-d Support** (Optional)
   - Only if you need distributed inference
   - Requires Gateway configuration
   - Not needed for standard model serving

---

## Verification Checklist

Use this checklist to verify your setup matches the reference repo where needed:

### Operators

- [x] NFD installed in `openshift-nfd`
- [x] GPU Operator installed in `nvidia-gpu-operator`
- [x] Kueue operator installed (namespace differs, but works)
- [x] LWS operator installed in `openshift-lws-operator`
- [ ] RHCL operator in `openshift-operators` (currently in `kuadrant-system` - **FIX NEEDED**)
- [x] cert-manager installed (extra, but needed for our setup)
- [x] RHOAI operator installed in `redhat-ods-operator`

### DataScienceCluster

- [x] KServe managementState: Managed
- [x] Kueue managementState: Unmanaged (reference has Removed)
- [x] Dashboard managementState: Managed
- [x] Other components configured

### Hardware Profiles

- [x] nvidia-gpu profile created in `redhat-ods-applications`
- [x] Using `infrastructure.opendatahub.io/v1` API
- [x] Correct identifiers (CPU, Memory, GPU)

### Dashboard Configuration

- [x] genAiStudio: true
- [x] modelAsService: true
- [x] hardwareProfileOrder: []
- [x] No deprecated fields

### Kuadrant/MaaS (if using)

- [x] Kuadrant CR created in `kuadrant-system`
- [x] Authorino configured with TLS
- [x] Gateway configured (for MaaS, not llm-d)

---

## Summary

### What's Different

1. **Deployment Mode**: Reference uses RawDeployment, we use Serverless + Kueue
2. **Kueue State**: Reference has Removed, we have Unmanaged
3. **RHCL Namespace**: Reference in `openshift-operators`, we're in `kuadrant-system` (**WRONG**)
4. **cert-manager**: We have it (needed for Kueue), reference doesn't
5. **Use Case**: Reference for demos/llm-d, we're for production/MaaS

### What's the Same

1. ✅ NFD, GPU, LWS operators - same configuration
2. ✅ RHOAI operator - same version and channel
3. ✅ Hardware profile format - identical
4. ✅ Dashboard configuration - similar (minus deprecated fields)
5. ✅ Kuadrant infrastructure - same components

### Action Items

1. **Fix RHCL operator namespace** - move to `openshift-operators`
2. **Verify hardware profiles work** - test model deployment
3. **Consider adding llm-d support** - if needed for distributed inference

---

## References

- Reference Repository: [tsailiming/openshift-ai-bootstrap (rhoai-3 branch)](https://github.com/tsailiming/openshift-ai-bootstrap/tree/rhoai-3)
- Our Repository: [gymnatics/openshift-installation](https://github.com/gymnatics/openshift-installation)
- Related Docs:
  - `KSERVE-DEPLOYMENT-MODES.md` - RawDeployment vs Serverless comparison
  - `RHOAI-3.0-HARDWARE-PROFILE-FIX.md` - Hardware profile configuration
  - `KUEUE-FIX-SUMMARY.md` - Kueue setup and fixes

