# Manual RHOAI 3.0 Setup Guide

Complete step-by-step guide to manually install Red Hat OpenShift AI 3.0 on OpenShift 4.19+.

## Prerequisites

- OpenShift 4.19+ cluster
- Cluster admin access
- `oc` CLI installed and logged in
- GPU nodes (optional, but required for model inference)

---

## Quick Reference: What to Install

### Minimum Required (vLLM only)
```
✅ Node Feature Discovery (NFD)
✅ NVIDIA GPU Operator
✅ RHOAI 3.0 Operator
✅ User Workload Monitoring (ConfigMap)
```

### Full Installation (llm-d + MaaS)
```
✅ Node Feature Discovery (NFD)
✅ NVIDIA GPU Operator
✅ Leader Worker Set (LWS) Operator
✅ Red Hat Build of Kueue Operator
✅ Red Hat Connectivity Link (RHCL) Operator
✅ RHOAI 3.0 Operator
✅ User Workload Monitoring (ConfigMap)
```

---

## Step 1: Enable User Workload Monitoring

Required for KServe metrics.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
    alertmanagerMain:
      enableUserAlertmanagerConfig: true
```

Apply:
```bash
oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
    alertmanagerMain:
      enableUserAlertmanagerConfig: true
EOF
```

---

## Step 2: Install Node Feature Discovery (NFD) Operator

### 2a. Create Namespace and Subscription

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-nfd
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nfd
  namespace: openshift-nfd
spec:
  targetNamespaces:
  - openshift-nfd
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nfd
  namespace: openshift-nfd
spec:
  channel: stable
  installPlanApproval: Automatic
  name: nfd
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

Apply:
```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-nfd
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nfd
  namespace: openshift-nfd
spec:
  targetNamespaces:
  - openshift-nfd
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nfd
  namespace: openshift-nfd
spec:
  channel: stable
  installPlanApproval: Automatic
  name: nfd
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

### 2b. Wait for Operator and Create NFD Instance

```bash
# Wait for operator
until oc get csv -n openshift-nfd 2>/dev/null | grep -q "nfd.*Succeeded"; do
  echo "Waiting for NFD operator..."
  sleep 10
done
```

Create NFD instance:
```yaml
apiVersion: nfd.openshift.io/v1
kind: NodeFeatureDiscovery
metadata:
  name: nfd-instance
  namespace: openshift-nfd
spec:
  operand:
    image: registry.redhat.io/openshift4/ose-node-feature-discovery-rhel9:v4.19
    servicePort: 12000
  workerConfig:
    configData: |
      core:
        sleepInterval: 60s
```

Apply:
```bash
oc apply -f - <<EOF
apiVersion: nfd.openshift.io/v1
kind: NodeFeatureDiscovery
metadata:
  name: nfd-instance
  namespace: openshift-nfd
spec:
  operand:
    image: registry.redhat.io/openshift4/ose-node-feature-discovery-rhel9:v4.19
    servicePort: 12000
  workerConfig:
    configData: |
      core:
        sleepInterval: 60s
EOF
```

---

## Step 3: Install NVIDIA GPU Operator

### 3a. Create Namespace and Subscription

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: nvidia-gpu-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nvidia-gpu-operator-group
  namespace: nvidia-gpu-operator
spec:
  targetNamespaces:
  - nvidia-gpu-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator-certified
  namespace: nvidia-gpu-operator
spec:
  channel: stable
  installPlanApproval: Automatic
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF
```

### 3b. Wait for Operator and Create ClusterPolicy

```bash
# Wait for CRD
until oc get crd clusterpolicies.nvidia.com &>/dev/null; do
  echo "Waiting for GPU operator CRD..."
  sleep 10
done
```

Create ClusterPolicy (only needed if you have GPU nodes):
```bash
oc apply -f - <<EOF
apiVersion: nvidia.com/v1
kind: ClusterPolicy
metadata:
  name: gpu-cluster-policy
spec:
  operator:
    defaultRuntime: crio
    use_ocp_driver_toolkit: true
  driver:
    enabled: true
  dcgm:
    enabled: true
  dcgmExporter:
    enabled: true
  devicePlugin:
    enabled: true
  gfd:
    enabled: true
  migManager:
    enabled: true
  nodeStatusExporter:
    enabled: true
  toolkit:
    enabled: true
  validator:
    plugin:
      env:
        - name: WITH_WORKLOAD
          value: "false"
EOF
```

---

## Step 4: Install RHOAI 3.0 Operator

### 4a. Create Namespace and Subscription

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: redhat-ods-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: redhat-ods-operator
  namespace: redhat-ods-operator
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  channel: fast-3.x
  installPlanApproval: Automatic
  name: rhods-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

### 4b. Wait for Operator

```bash
# Wait for RHOAI CRDs (may take 3-5 minutes)
until oc get crd datascienceclusters.datasciencecluster.opendatahub.io &>/dev/null; do
  echo "Waiting for RHOAI CRDs..."
  sleep 15
done

echo "RHOAI Operator is ready!"
```

---

## Step 5: Create DSCInitialization

```bash
oc apply -f - <<EOF
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization
metadata:
  name: default-dsci
spec:
  applicationsNamespace: redhat-ods-applications
  monitoring:
    managementState: Managed
    namespace: redhat-ods-monitoring
  serviceMesh:
    auth:
      audiences:
        - 'https://kubernetes.default.svc'
    controlPlane:
      metricsCollection: Istio
      name: data-science-smcp
      namespace: istio-system
    managementState: Managed
  trustedCABundle:
    customCABundle: ''
    managementState: Managed
EOF
```

---

## Step 6: Create DataScienceCluster

This is the main RHOAI configuration. Customize based on your needs.

```bash
oc apply -f - <<EOF
apiVersion: datasciencecluster.opendatahub.io/v2
kind: DataScienceCluster
metadata:
  name: default-dsc
  labels:
    app.kubernetes.io/name: datasciencecluster
spec:
  components:
    dashboard:
      managementState: Managed
    workbenches:
      managementState: Managed
    datasciencepipelines:
      managementState: Managed
    aipipelines:
      managementState: Managed
    kserve:
      managementState: Managed
    modelmeshserving:
      managementState: Managed
    modelregistry:
      managementState: Managed
      registriesNamespace: rhoai-model-registries
    ray:
      managementState: Managed
    trainingoperator:
      managementState: Managed
    trustyai:
      managementState: Managed
    feastoperator:
      managementState: Managed
    llamastackoperator:
      managementState: Managed
    kueue:
      defaultClusterQueueName: default
      defaultLocalQueueName: default
      managementState: Unmanaged
EOF
```

---

## Step 7: Wait for Dashboard

```bash
# Wait for dashboard deployment
until oc get deployment rhods-dashboard -n redhat-ods-applications &>/dev/null; do
  echo "Waiting for dashboard deployment..."
  sleep 15
done

# Wait for pods
oc wait --for=condition=Available deployment/rhods-dashboard \
    -n redhat-ods-applications --timeout=300s

# Get dashboard URL
echo "Dashboard URL:"
echo "https://$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}')"
```

---

## Step 8: Configure Dashboard Features

Enable GenAI Studio, Model Registry, and other features:

```bash
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
  --type merge \
  -p '{
    "spec": {
      "dashboardConfig": {
        "disableModelRegistry": false,
        "disableModelCatalog": false,
        "disableKServeMetrics": false,
        "genAiStudio": true,
        "modelAsService": true,
        "disableLMEval": false,
        "disableKueue": false,
        "disableHardwareProfiles": false
      }
    }
  }'
```

---

## Step 9: Create Hardware Profile (for GPU workloads)

```bash
oc apply -f - <<EOF
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: gpu-profile
  namespace: redhat-ods-applications
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: GPU Profile
    opendatahub.io/description: 'GPU hardware profile for NVIDIA GPU workloads'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
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
  scheduling:
    kueue:
      localQueueName: default
      priorityClass: None
    type: Queue
EOF
```

---

## Step 10: Create a Namespace for Your Models

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ai-models
  labels:
    opendatahub.io/dashboard: 'true'
EOF
```

---

## Optional: Install Additional Operators

### Leader Worker Set (LWS) - Required for llm-d

```bash
oc apply -f - <<EOF
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
  channel: stable
  name: leader-worker-set
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# Wait and create instance
sleep 60
oc apply -f - <<EOF
apiVersion: operator.openshift.io/v1
kind: LeaderWorkerSetOperator
metadata:
  name: cluster
  namespace: openshift-lws-operator
spec:
  managementState: Managed
EOF
```

### Red Hat Build of Kueue - For distributed workloads

```bash
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kueue-operator
  namespace: openshift-operators
spec:
  channel: stable
  name: kueue-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

### Red Hat Connectivity Link (RHCL/Kuadrant) - For llm-d auth

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: kuadrant-system
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kuadrant-system
  namespace: kuadrant-system
spec:
  targetNamespaces:
    - kuadrant-system
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhcl-operator
  namespace: kuadrant-system
spec:
  channel: stable
  name: rhcl-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# Wait and create Kuadrant instance
sleep 60
oc apply -f - <<EOF
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
spec: {}
EOF
```

---

## Verification

### Check Operators
```bash
echo "=== Operator Status ==="
oc get csv -n openshift-nfd | grep nfd
oc get csv -n nvidia-gpu-operator | grep gpu
oc get csv -n redhat-ods-operator | grep rhods
```

### Check RHOAI Components
```bash
echo "=== RHOAI Status ==="
oc get datasciencecluster default-dsc
oc get pods -n redhat-ods-applications | head -20
```

### Check Dashboard
```bash
echo "=== Dashboard URL ==="
echo "https://$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}')"
```

### Check GPU Nodes
```bash
echo "=== GPU Nodes ==="
oc get nodes -l nvidia.com/gpu.present=true
```

---

## Troubleshooting

### Webhook Errors
If you see webhook errors when creating DSCInitialization:
```bash
# Wait for webhook service
oc get svc -n redhat-ods-operator | grep rhods
oc get endpoints -n redhat-ods-operator
```

### Dashboard Not Loading
```bash
# Check pods
oc get pods -n redhat-ods-applications | grep dashboard

# Check route
oc get route rhods-dashboard -n redhat-ods-applications
```

### GPU Not Detected
```bash
# Check NFD labels
oc get nodes -o json | jq '.items[].metadata.labels | keys | map(select(startswith("feature.node.kubernetes.io/pci-10de")))'

# Check GPU operator pods
oc get pods -n nvidia-gpu-operator
```

---

## Quick Deploy Commands (All-in-One)

For a fast setup, run all commands in sequence:

```bash
# 1. User Workload Monitoring
oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
EOF

# 2-9. Run the automated script
./scripts/install-rhoai-minimal.sh --minimal
```

---

## Next Steps

1. **Access Dashboard**: Open the dashboard URL in your browser
2. **Create Project**: Create a Data Science project
3. **Deploy Model**: Use vLLM or llm-d serving runtime
4. **Test in Playground**: Use GenAI Studio Playground

For automated setup, use:
```bash
./rhoai-toolkit.sh
```

---

## References

- [CAI's Guide to RHOAI 3.0](./CAI's%20guide%20to%20RHOAI%203.0.txt)
- [Red Hat OpenShift AI Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0)
- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/openshift/contents.html)

