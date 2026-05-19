# RHOAI Manual Installation Guide

A complete step-by-step guide for manually deploying Red Hat OpenShift AI (RHOAI) 3.3 on OpenShift, with all required YAMLs and `oc` commands. Covers installation with and without MaaS, plus optional components.

> **Target:** RHOAI 3.3 on OpenShift 4.19–4.21. Adjust channel values for other versions.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Phase 1: Core Operators (Required)](#phase-1-core-operators-required)
  - [1.1 Node Feature Discovery (NFD)](#11-node-feature-discovery-nfd)
  - [1.2 NVIDIA GPU Operator](#12-nvidia-gpu-operator)
  - [1.3 cert-manager Operator](#13-cert-manager-operator)
  - [1.4 User Workload Monitoring](#14-user-workload-monitoring)
- [Phase 2: RHOAI Operator](#phase-2-rhoai-operator)
  - [2.1 Install RHOAI Operator](#21-install-rhoai-operator)
  - [2.2 Create DataScienceCluster (without MaaS)](#22-create-datasciencecluster-without-maas)
  - [2.3 Enable Dashboard Features](#23-enable-dashboard-features)
  - [2.4 Create Hardware Profile](#24-create-hardware-profile)
- [Phase 3: Deploy a Model (vLLM — No MaaS)](#phase-3-deploy-a-model-vllm--no-maas)
  - [3.1 Create a Project](#31-create-a-project)
  - [3.2 Deploy ServingRuntime + InferenceService](#32-deploy-servingruntime--inferenceservice)
- [Phase 4: Enable MaaS (Optional)](#phase-4-enable-maas-optional)
  - [4.1 Install Kueue Operator](#41-install-kueue-operator)
  - [4.2 Install LeaderWorkerSet (LWS) Operator](#42-install-leaderworkerset-lws-operator)
  - [4.3 Install Service Mesh 3 (for RHCL)](#43-install-service-mesh-3-for-rhcl)
  - [4.4 Install Red Hat Connectivity Link (RHCL)](#44-install-red-hat-connectivity-link-rhcl)
  - [4.5 Configure Authorino TLS](#45-configure-authorino-tls)
  - [4.6 Enable MaaS in DataScienceCluster](#46-enable-maas-in-datasciencecluster)
  - [4.7 Create Inference Gateway](#47-create-inference-gateway)
  - [4.8 Enable MaaS Dashboard Features](#48-enable-maas-dashboard-features)
  - [4.9 Deploy a Model with llm-d (MaaS)](#49-deploy-a-model-with-llm-d-maas)
- [Phase 5: Optional Components](#phase-5-optional-components)
  - [5.1 GPU Worker Nodes (AWS)](#51-gpu-worker-nodes-aws)
  - [5.2 Kubeflow Trainer v2 (JobSet)](#52-kubeflow-trainer-v2-jobset)
  - [5.3 Feature Store (Feast)](#53-feature-store-feast)
  - [5.4 Model Storage (MinIO)](#54-model-storage-minio)
  - [5.5 Grafana Monitoring](#55-grafana-monitoring)
  - [5.6 MaaS Tier-Based Rate Limiting](#56-maas-tier-based-rate-limiting)
- [Phase 6: Model Registry, Pipeline Server, and MCP Server](#phase-6-model-registry-pipeline-server-and-mcp-server)
  - [6.1 Model Registry](#61-model-registry)
  - [6.2 Pipeline Server (Data Science Pipelines)](#62-pipeline-server-data-science-pipelines)
  - [6.3 Kubernetes MCP Server (OpenShift MCP)](#63-kubernetes-mcp-server-openshift-mcp)
- [Verification Commands](#verification-commands)
- [Troubleshooting](#troubleshooting)
- [Quick Reference: What Needs What](#quick-reference-what-needs-what)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                     OpenShift 4.19+                              │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    RHOAI 3.3 Operator                       │ │
│  │  ┌──────────┐ ┌────────┐ ┌───────────┐ ┌───────────────┐   │ │
│  │  │Dashboard │ │KServe  │ │Model      │ │Workbenches    │   │ │
│  │  │          │ │        │ │Registry   │ │(Jupyter)      │   │ │
│  │  └──────────┘ └────────┘ └───────────┘ └───────────────┘   │ │
│  │  ┌──────────┐ ┌────────┐ ┌───────────┐ ┌───────────────┐   │ │
│  │  │TrustyAI  │ │Ray     │ │LlamaStack │ │AI Pipelines   │   │ │
│  │  └──────────┘ └────────┘ └───────────┘ └───────────────┘   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌─────────── Required ───────────┐  ┌── Optional (for MaaS) ──┐│
│  │ NFD → GPU Operator             │  │ Kueue                   ││
│  │ cert-manager                   │  │ LWS (LeaderWorkerSet)   ││
│  │ User Workload Monitoring       │  │ Service Mesh 3          ││
│  └────────────────────────────────┘  │ RHCL (Kuadrant)         ││
│                                      └──────────────────────────┘│
│  ┌─────────── Optional ──────────────────────────────────────┐   │
│  │ JobSet (for Trainer v2)  │  Feast (Feature Store)         │   │
│  │ MLflow (Experiment Track)│  Grafana (Dashboards)          │   │
│  └───────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

**Two installation paths:**

| Path | Components | Use Case |
|------|-----------|----------|
| **Without MaaS** | NFD + GPU + cert-manager + RHOAI | Model serving with vLLM via direct routes |
| **With MaaS** | Above + Kueue + LWS + Service Mesh 3 + RHCL | Authenticated API gateway with llm-d, tiered access |

---

## Prerequisites

### Platform Requirements
- **OpenShift**: 4.19–4.21 (4.20+ required for llm-d)
- **Cluster**: Minimum 2 worker nodes, 8 CPUs / 32 GiB RAM each
- **Storage**: Default StorageClass with dynamic provisioning
- **GPU nodes**: At least 1 node with NVIDIA GPU (for model serving)

### CLI Tools Required
```bash
oc version        # OpenShift CLI, logged in as cluster-admin
```

### Check Available RHOAI Channels
```bash
oc get packagemanifest rhods-operator -n openshift-marketplace \
  -o jsonpath='{.status.channels[*].name}' | tr ' ' '\n'
```

Common channels: `fast-3.x`, `stable-3.3`, `stable-3.2`

---

## Phase 1: Core Operators (Required)

These operators are required regardless of whether you use MaaS.

### 1.1 Node Feature Discovery (NFD)

NFD detects hardware features (GPUs, etc.) and labels nodes accordingly.

```bash
oc apply -f - <<'EOF'
---
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

**Wait for the operator, then create the NFD instance:**

```bash
oc wait --for=condition=CatalogSourcesUnhealthy=False \
  subscription/nfd -n openshift-nfd --timeout=300s

# Verify CSV is ready
oc get csv -n openshift-nfd | grep nfd
```

```bash
oc apply -f - <<'EOF'
apiVersion: nfd.openshift.io/v1
kind: NodeFeatureDiscovery
metadata:
  name: nfd-instance
  namespace: openshift-nfd
spec:
  instance: ""
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

### 1.2 NVIDIA GPU Operator

Installs GPU drivers and runtime on nodes with NVIDIA GPUs.

```bash
oc apply -f - <<'EOF'
---
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

**Wait for the CRD, then create ClusterPolicy:**

```bash
echo "Waiting for ClusterPolicy CRD..."
until oc get crd clusterpolicies.nvidia.com &>/dev/null; do sleep 10; done
echo "CRD available."
```

```bash
oc apply -f - <<'EOF'
apiVersion: nvidia.com/v1
kind: ClusterPolicy
metadata:
  name: gpu-cluster-policy
spec:
  operator:
    defaultRuntime: crio
    use_ocp_driver_toolkit: true
  dcgm:
    enabled: true
  dcgmExporter:
    serviceMonitor:
      enabled: true
    enabled: true
  driver:
    enabled: true
    useNvidiaDriverCRD: false
    upgradePolicy:
      autoUpgrade: true
      maxParallelUpgrades: 1
      maxUnavailable: 25%
  devicePlugin:
    enabled: true
  gfd:
    enabled: true
  toolkit:
    enabled: true
  validator:
    plugin:
      env: []
  nodeStatusExporter:
    enabled: true
  daemonsets:
    updateStrategy: RollingUpdate
  mig:
    strategy: single
  cdi:
    enabled: true
    default: false
  sandboxWorkloads:
    enabled: false
  vfioManager:
    enabled: true
  vgpuManager:
    enabled: false
  gds:
    enabled: false
  gdrcopy:
    enabled: false
EOF
```

> **Note:** If you experience driver issues, pin the version by adding under `driver:`:
> ```yaml
> driver:
>   repository: nvcr.io/nvidia
>   image: driver
>   version: 570.195.03
> ```

### 1.3 cert-manager Operator

Required for KServe TLS certificates.

```bash
oc apply -f - <<'EOF'
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cert-manager-operator
  namespace: cert-manager-operator
spec: {}
---
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

```bash
echo "Waiting for cert-manager CSV..."
until oc get csv -n cert-manager-operator 2>/dev/null | grep -q Succeeded; do sleep 10; done
echo "cert-manager ready."
```

### 1.4 User Workload Monitoring

Enables Prometheus metrics collection for RHOAI components.

```bash
oc apply -f - <<'EOF'
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

## Phase 2: RHOAI Operator

### 2.1 Install RHOAI Operator

```bash
oc apply -f - <<'EOF'
---
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

> **Channel options:** `fast-3.x` (latest 3.x), `stable-3.3` (pinned), `stable-3.2` (older)

**Wait for RHOAI operator to be ready:**

```bash
echo "Waiting for RHOAI operator..."
until oc get csv -n redhat-ods-operator 2>/dev/null | grep rhods | grep -q Succeeded; do
  sleep 15
  echo "  still waiting..."
done
echo "RHOAI operator ready."
```

### 2.2 Create DataScienceCluster (without MaaS)

This DSC enables all core components **without** MaaS. The `modelsAsService` field is omitted.

```bash
oc apply -f - <<'EOF'
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
      workbenchNamespace: rhods-notebooks
    aipipelines:
      managementState: Managed
    kserve:
      managementState: Managed
      defaultDeploymentMode: RawDeployment
      rawDeploymentServiceConfig: Headed
      nim:
        managementState: Managed
    kueue:
      managementState: Unmanaged
    ray:
      managementState: Managed
    trainingoperator:
      managementState: Managed
    modelregistry:
      managementState: Managed
      registriesNamespace: rhoai-model-registries
    trustyai:
      managementState: Managed
    feastoperator:
      managementState: Managed
    llamastackoperator:
      managementState: Managed
    mlflowoperator:
      managementState: Managed
EOF
```

**Wait for DSC to become ready:**

```bash
echo "Waiting for DataScienceCluster..."
until [ "$(oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}' 2>/dev/null)" = "Ready" ]; do
  sleep 15
  echo "  phase: $(oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}' 2>/dev/null)"
done
echo "DataScienceCluster is Ready."
```

### 2.3 Enable Dashboard Features

```bash
oc patch odhdashboardconfig odh-dashboard-config \
  -n redhat-ods-applications \
  --type=merge \
  -p '{
    "spec": {
      "dashboardConfig": {
        "disableModelRegistry": false,
        "disableModelCatalog": false,
        "disableKServeMetrics": false,
        "genAiStudio": true,
        "disableLMEval": false,
        "disableKueue": false
      }
    }
  }'
```

### 2.4 Create Hardware Profile

Hardware profiles define GPU scheduling and resource defaults for model deployments.

```bash
oc apply -f - <<'EOF'
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: gpu-profile
  namespace: redhat-ods-applications
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: GPU Profile
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
    type: Node
    node:
      nodeSelector:
        nvidia.com/gpu.present: 'true'
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
EOF
```

> **Important:** The `scheduling` section with tolerations is critical. Without it, model pods will not schedule on GPU nodes that have the `nvidia.com/gpu:NoSchedule` taint.

**At this point, RHOAI is installed and functional (without MaaS).** You can deploy models using vLLM via direct routes. Continue to [Phase 3](#phase-3-deploy-a-model-vllm--no-maas) to deploy a model, or skip to [Phase 4](#phase-4-enable-maas-optional) to add MaaS.

---

## Phase 3: Deploy a Model (vLLM — No MaaS)

This deploys a model using the standard vLLM ServingRuntime + InferenceService pattern. No MaaS or llm-d required.

### 3.1 Create a Project

```bash
oc new-project ai-models
oc label namespace ai-models opendatahub.io/dashboard=true
```

### 3.2 Deploy ServingRuntime + InferenceService

**Option A: OCI / ModelCar (recommended — no storage setup needed)**

```bash
MODEL_NAME="qwen3-8b"

# Create ServingRuntime
oc apply -f - <<EOF
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: ${MODEL_NAME}
  namespace: ai-models
  annotations:
    opendatahub.io/apiProtocol: REST
    opendatahub.io/recommended-accelerators: '["nvidia.com/gpu"]'
    opendatahub.io/template-name: rhaiis-cuda-runtime
    openshift.io/display-name: ${MODEL_NAME}
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  annotations:
    prometheus.io/path: /metrics
    prometheus.io/port: '8080'
  containers:
    - args:
        - '--port=8080'
        - '--model=/mnt/models'
        - '--served-model-name={{.Name}}'
      command:
        - python
        - '-m'
        - vllm.entrypoints.openai.api_server
      env:
        - name: HF_HOME
          value: /tmp/hf_home
      image: registry.redhat.io/rhaiis/vllm-cuda-rhel9:3.3
      name: kserve-container
      ports:
        - containerPort: 8080
          protocol: TCP
      volumeMounts:
        - mountPath: /dev/shm
          name: shm
  multiModel: false
  supportedModelFormats:
    - autoSelect: true
      name: vLLM
  volumes:
    - emptyDir:
        medium: Memory
        sizeLimit: 2Gi
      name: shm
EOF

# Create InferenceService
oc apply -f - <<EOF
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: ${MODEL_NAME}
  namespace: ai-models
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    opendatahub.io/hardware-profile-name: gpu-profile
    opendatahub.io/hardware-profile-namespace: redhat-ods-applications
    openshift.io/display-name: ${MODEL_NAME}
  labels:
    opendatahub.io/dashboard: 'true'
    opendatahub.io/genai-asset: 'true'
spec:
  predictor:
    minReplicas: 1
    maxReplicas: 1
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
    model:
      modelFormat:
        name: vLLM
      runtime: ${MODEL_NAME}
      resources:
        limits:
          cpu: '4'
          memory: 32Gi
          nvidia.com/gpu: '1'
        requests:
          cpu: '2'
          memory: 8Gi
          nvidia.com/gpu: '1'
      storageUri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b:latest
      args:
        - '--max-model-len=4096'
        - '--dtype=half'
        - '--gpu-memory-utilization=0.95'
EOF
```

**Option B: S3 Storage (MinIO)**

See [5.4 Model Storage (MinIO)](#54-model-storage-minio) to set up MinIO first, then use `storageUri` with `storage.key`:

```yaml
# Replace the storageUri block with:
      storage:
        key: aws-connection-my-storage
        path: Qwen/Qwen3-8B-Instruct
```

**Wait and test:**

```bash
oc wait --for=condition=Ready inferenceservice/${MODEL_NAME} \
  -n ai-models --timeout=600s

# Get the route URL
ROUTE=$(oc get inferenceservice ${MODEL_NAME} -n ai-models \
  -o jsonpath='{.status.url}')
echo "Model URL: ${ROUTE}"

# Test
curl -sk "${ROUTE}/v1/models"
curl -sk "${ROUTE}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-8b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

**Enable tool calling** by adding these args to the InferenceService:

```yaml
args:
  - '--enable-auto-tool-choice'
  - '--tool-call-parser=hermes'   # hermes for Qwen, llama3_json for Llama, mistral for Mistral
```

---

## Phase 4: Enable MaaS (Optional)

MaaS (Models as a Service) provides an authenticated API gateway for model access using llm-d serving runtime. This requires several additional operators.

### 4.1 Install Kueue Operator

Kueue handles workload scheduling for llm-d. cert-manager must be installed first (done in Phase 1).

```bash
oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kueue-operator
  namespace: openshift-operators
spec:
  channel: stable-v1.3
  installPlanApproval: Automatic
  name: kueue-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

```bash
echo "Waiting for Kueue CSV..."
until oc get csv -n openshift-operators 2>/dev/null | grep kueue | grep -q Succeeded; do sleep 10; done
echo "Kueue ready."
```

### 4.2 Install LeaderWorkerSet (LWS) Operator

LWS enables multi-node inference for llm-d.

```bash
oc apply -f - <<'EOF'
---
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
```

```bash
echo "Waiting for LWS CSV..."
until oc get csv -n openshift-lws-operator 2>/dev/null | grep leader-worker | grep -q Succeeded; do sleep 10; done
echo "LWS ready."
```

### 4.3 Install Service Mesh 3 (for RHCL)

RHCL requires Service Mesh 3 (Istio/Sail). The Service Mesh 3 operator uses **Manual** install plan approval because it often requires explicit approval of multiple components (servicemesh, kiali, sail).

```bash
oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: servicemeshoperator3
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Manual
  name: servicemeshoperator3
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

**Approve pending InstallPlans** (Service Mesh creates multiple):

```bash
echo "Approving Service Mesh InstallPlans..."
sleep 30  # Wait for InstallPlans to be created

for plan in $(oc get installplan -n openshift-operators -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}'); do
  CSV_NAMES=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}')
  if echo "$CSV_NAMES" | grep -qiE 'servicemesh|istio|kiali|sail'; then
    echo "  Approving: $plan ($CSV_NAMES)"
    oc patch installplan "$plan" -n openshift-operators --type=merge \
      -p '{"spec": {"approved": true}}'
  fi
done

echo "Waiting for Service Mesh CSV..."
until oc get csv -n openshift-operators 2>/dev/null | grep servicemesh | grep -q Succeeded; do
  sleep 15
  # Re-approve any new InstallPlans
  for plan in $(oc get installplan -n openshift-operators -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}'); do
    CSV_NAMES=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}')
    if echo "$CSV_NAMES" | grep -qiE 'servicemesh|istio|kiali|sail'; then
      oc patch installplan "$plan" -n openshift-operators --type=merge \
        -p '{"spec": {"approved": true}}'
    fi
  done
done
echo "Service Mesh 3 ready."
```

### 4.4 Install Red Hat Connectivity Link (RHCL)

RHCL provides API gateway (Kuadrant) and authentication (Authorino) for MaaS.

```bash
oc apply -f - <<'EOF'
---
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
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhcl-operator
  namespace: kuadrant-system
spec:
  channel: stable
  installPlanApproval: Automatic
  name: rhcl-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

**Wait for RHCL and create Kuadrant instance:**

```bash
echo "Waiting for Kuadrant CRD..."
until oc get crd kuadrants.kuadrant.io &>/dev/null; do sleep 10; done
echo "CRD available."

oc apply -f - <<'EOF'
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
EOF
```

### 4.5 Configure Authorino TLS

Authorino handles authentication for MaaS. It needs a TLS certificate from cert-manager.

```bash
# Create a self-signed Issuer and Certificate for Authorino
oc apply -f - <<'EOF'
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: authorino-selfsigned
  namespace: kuadrant-system
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: authorino-server-cert
  namespace: kuadrant-system
spec:
  secretName: authorino-server-cert
  issuerRef:
    name: authorino-selfsigned
    kind: Issuer
  dnsNames:
    - authorino-authorino-authorization.kuadrant-system.svc
    - authorino-authorino-authorization.kuadrant-system.svc.cluster.local
  duration: 8760h
  renewBefore: 720h
EOF
```

**Wait for the certificate secret, then create Authorino:**

```bash
echo "Waiting for Authorino TLS secret..."
until oc get secret authorino-server-cert -n kuadrant-system &>/dev/null; do sleep 5; done
echo "Secret ready."

oc apply -f - <<'EOF'
apiVersion: operator.authorino.kuadrant.io/v1beta1
kind: Authorino
metadata:
  name: authorino
  namespace: kuadrant-system
spec:
  replicas: 1
  clusterWide: true
  listener:
    tls:
      enabled: true
      certSecretRef:
        name: authorino-server-cert
  oidcServer:
    tls:
      enabled: false
EOF
```

### 4.6 Enable MaaS in DataScienceCluster

Patch the existing DSC to enable MaaS:

```bash
oc patch datasciencecluster default-dsc --type=merge -p '{
  "spec": {
    "components": {
      "kserve": {
        "modelsAsService": {
          "managementState": "Managed"
        }
      }
    }
  }
}'

echo "Waiting 30s for MaaS components to reconcile..."
sleep 30
```

### 4.7 Create Inference Gateway

The Gateway provides the external endpoint for MaaS API calls.

```bash
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
echo "Cluster domain: ${CLUSTER_DOMAIN}"

# Create GatewayClass
oc apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF

# Create Gateway
cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/rev: openshift-gateway
  name: openshift-ai-inference
  namespace: openshift-ingress
spec:
  gatewayClassName: openshift-ai-inference
  listeners:
    - allowedRoutes:
        namespaces:
          from: All
      hostname: inference-gateway.${CLUSTER_DOMAIN}
      name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - group: ''
            kind: Secret
            name: default-gateway-tls
        mode: Terminate
EOF
```

**Verify the Gateway is programmed:**

```bash
oc get gateway -n openshift-ingress
# NAME                      CLASS                    ADDRESS   PROGRAMMED   AGE
# openshift-ai-inference    openshift-ai-inference   ...       True         ...
```

### 4.8 Enable MaaS Dashboard Features

```bash
oc patch odhdashboardconfig odh-dashboard-config \
  -n redhat-ods-applications \
  --type=merge \
  -p '{
    "spec": {
      "dashboardConfig": {
        "genAiStudio": true,
        "modelAsService": true,
        "disableModelRegistry": false,
        "disableModelCatalog": false,
        "disableKServeMetrics": false,
        "disableLMEval": false,
        "disableKueue": false
      }
    }
  }'
```

**Restart controllers to pick up changes:**

```bash
oc delete pod -n redhat-ods-applications -l app=odh-model-controller
oc delete pod -n redhat-ods-applications -l control-plane=kserve-controller-manager
```

### 4.9 Deploy a Model with llm-d (MaaS)

llm-d uses `LLMInferenceService` (not `InferenceService`). Only llm-d supports MaaS.

```bash
NAMESPACE="llm-serving"
MODEL_NAME="qwen3-8b"

oc new-project ${NAMESPACE} 2>/dev/null || oc project ${NAMESPACE}

oc apply -f - <<EOF
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: ${MODEL_NAME}
  namespace: ${NAMESPACE}
  labels:
    kueue.x-k8s.io/queue-name: default
    opendatahub.io/dashboard: "true"
    opendatahub.io/genai-asset: "true"
  annotations:
    security.opendatahub.io/enable-auth: "true"
    openshift.io/display-name: Qwen3-8B
spec:
  replicas: 1
  model:
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b:latest
    name: ${MODEL_NAME}
  router:
    route: {}
    gateway: {}
    scheduler: {}
  template:
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
    containers:
      - name: main
        env:
          - name: VLLM_ADDITIONAL_ARGS
            value: "--enable-auto-tool-choice --tool-call-parser=hermes"
        resources:
          limits:
            cpu: '4'
            memory: 16Gi
            nvidia.com/gpu: "1"
          requests:
            cpu: '2'
            memory: 8Gi
            nvidia.com/gpu: "1"
EOF
```

**Wait and test via MaaS endpoint:**

```bash
oc wait --for=condition=Ready llminferenceservice/${MODEL_NAME} \
  -n ${NAMESPACE} --timeout=600s

CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')

# Get a token
TOKEN=$(oc create token default -n ${NAMESPACE} \
  --duration=1h --audience=https://kubernetes.default.svc)

# Test via MaaS Gateway
curl -sk "https://inference-gateway.${CLUSTER_DOMAIN}/${NAMESPACE}/${MODEL_NAME}/v1/models" \
  -H "Authorization: Bearer ${TOKEN}"

curl -sk "https://inference-gateway.${CLUSTER_DOMAIN}/${NAMESPACE}/${MODEL_NAME}/v1/chat/completions" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "'${MODEL_NAME}'",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

---

## Phase 5: Optional Components

### 5.1 GPU Worker Nodes (AWS)

If your cluster doesn't have GPU nodes yet, create a MachineSet. This example creates `g6e.xlarge` nodes.

```bash
# Use the toolkit script for interactive setup:
./scripts/create-gpu-machineset.sh

# Or manually — get your cluster's infrastructure ID:
INFRA_ID=$(oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}')
REGION=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.aws.region}')
AZ="${REGION}a"

echo "Infra ID: ${INFRA_ID}"
echo "Region: ${REGION}, AZ: ${AZ}"
```

The generated MachineSet will include:
- Instance type (e.g., `g6e.xlarge`, `g6e.2xlarge`, `g6e.4xlarge`, `p5.48xlarge`)
- Taint `nvidia.com/gpu:NoSchedule` to prevent non-GPU workloads scheduling there
- Labels `node-role.kubernetes.io/gpu-worker` and `nvidia.com/gpu.present=true`

After the GPU node is ready, the GPU Operator will automatically install drivers.

### 5.2 Kubeflow Trainer v2 (JobSet)

Trainer v2 (GA in 3.3) requires the JobSet operator. Install it **before** enabling Trainer in the DSC.

```bash
# Install JobSet operator
oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: jobset-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: jobset-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo "Waiting for JobSet CSV..."
until oc get csv -n openshift-operators 2>/dev/null | grep jobset | grep -q Succeeded; do sleep 10; done
echo "JobSet ready."

# Now enable Trainer in DSC
oc patch datasciencecluster default-dsc --type=merge -p '{
  "spec": {
    "components": {
      "trainer": {
        "managementState": "Managed"
      },
      "trainingoperator": {
        "managementState": "Removed"
      }
    }
  }
}'
```

> **Warning:** Do NOT set `trainer.managementState: Managed` without installing JobSet first — the DSC will fail to reconcile.

### 5.3 Feature Store (Feast)

Feast is enabled in the DSC by default (`feastoperator: Managed`). To deploy a FeatureStore instance:

```bash
NAMESPACE="feast-demo"

oc new-project ${NAMESPACE} 2>/dev/null || oc project ${NAMESPACE}
oc label namespace ${NAMESPACE} opendatahub.io/dashboard=true --overwrite

oc apply -f - <<'EOF'
apiVersion: feast.dev/v1alpha1
kind: FeatureStore
metadata:
  name: banking
  namespace: feast-demo
  labels:
    feature-store-ui: enabled
    opendatahub.io/dashboard: "true"
spec:
  feastProject: banking
  feastProjectDir:
    git:
      ref: rbac
      url: 'https://github.com/RHRolun/banking-feature-store'
  services:
    offlineStore:
      server:
        logLevel: debug
    onlineStore:
      server:
        logLevel: debug
    registry:
      local:
        server:
          restAPI: true
EOF
```

**Key requirements for dashboard visibility (especially after 3.2 → 3.3 upgrade):**
- Label `feature-store-ui: enabled` on the FeatureStore
- Label `opendatahub.io/dashboard: "true"` on the FeatureStore
- Label `opendatahub.io/dashboard=true` on the namespace
- `spec.services.registry.local.server.restAPI: true`

### 5.4 Model Storage (MinIO)

Set up MinIO for S3-compatible model storage. Useful for serving models downloaded from HuggingFace.

```bash
# Use the toolkit:
./scripts/setup-model-storage.sh

# Then download a model:
./scripts/download-model.sh s3 Qwen/Qwen3-8B-Instruct
```

Or manually deploy MinIO:

```bash
NAMESPACE="model-storage"
oc new-project ${NAMESPACE} 2>/dev/null || oc project ${NAMESPACE}
oc label namespace ${NAMESPACE} opendatahub.io/dashboard=true --overwrite

# Create MinIO Secret
oc apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: minio
  namespace: model-storage
type: Opaque
stringData:
  MINIO_ROOT_USER: minio
  MINIO_ROOT_PASSWORD: minio123
EOF

# Create PVC
oc apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: models-pvc
  namespace: model-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
EOF

# Create MinIO Deployment
oc apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: model-storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
        - name: minio
          image: quay.io/minio/minio:latest
          command: ["minio", "server", "/data", "--console-address", ":9001"]
          envFrom:
            - secretRef:
                name: minio
          ports:
            - containerPort: 9000
            - containerPort: 9001
          volumeMounts:
            - mountPath: /data
              name: data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: models-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: model-storage
spec:
  selector:
    app: minio
  ports:
    - name: api
      port: 9000
      targetPort: 9000
    - name: console
      port: 9001
      targetPort: 9001
EOF

# Create S3 data connection secret (for RHOAI to use)
oc apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: aws-connection-my-storage
  namespace: model-storage
  labels:
    opendatahub.io/dashboard: 'true'
    opendatahub.io/managed: 'true'
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: MinIO Storage
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: minio
  AWS_SECRET_ACCESS_KEY: minio123
  AWS_S3_ENDPOINT: http://minio.model-storage.svc:9000
  AWS_S3_BUCKET: models
  AWS_DEFAULT_REGION: us-east-1
EOF
```

Then deploy an InferenceService using S3 storage:

```yaml
spec:
  predictor:
    model:
      storage:
        key: aws-connection-my-storage
        path: Qwen/Qwen3-8B-Instruct
```

### 5.5 Grafana Monitoring

Deploy Grafana for vLLM and GPU metrics dashboards.

```bash
NAMESPACE="grafana"
oc new-project ${NAMESPACE} 2>/dev/null || oc project ${NAMESPACE}

# Deploy Grafana
oc apply -f lib/manifests/grafana/grafana-deployment.yaml

# Import dashboards via Grafana UI:
# - lib/manifests/grafana/vllm-dashboard.json
# - lib/manifests/grafana/vllm-advanced-dashboard.json
# - lib/manifests/grafana/nvidia-dcgm-dashboard.json
```

Configure a Prometheus data source in Grafana pointing to:
```
https://thanos-querier.openshift-monitoring.svc.cluster.local:9091
```

Use the token from `lib/manifests/grafana/prometheus-token.yaml` for authentication.

### 5.6 MaaS Tier-Based Rate Limiting

After MaaS is set up (Phase 4), you can add tiered rate limiting. See [MAAS-SETUP-STEP-BY-STEP.md](MAAS-SETUP-STEP-BY-STEP.md) for the complete walkthrough covering:

1. ServiceAccount creation per tier (free/premium/enterprise)
2. RBAC RoleBindings for `llminferenceservices` access
3. `tier-to-group-mapping` ConfigMap
4. AuthPolicy with tier lookup metadata
5. TokenRateLimitPolicy with per-tier limits

---

## Phase 6: Model Registry, Pipeline Server, and MCP Server

### 6.1 Model Registry

Per RHAIE 3.3 Guide Chapter 2–3: requires external MySQL 5.x+ (recommended 8.x).

#### 6.1.1 Enable Model Registry in DSC

```bash
oc patch datasciencecluster default-dsc --type=merge -p '{
  "spec": {
    "components": {
      "modelregistry": {
        "managementState": "Managed",
        "registriesNamespace": "rhoai-model-registries"
      }
    }
  }
}'
```

Wait for operator to reconcile:

```bash
oc get modelregistry default-modelregistry -o jsonpath='{.status.phase}'
# Should return: Ready
```

#### 6.1.2 Enable in Dashboard

```bash
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
  --type=merge -p '{"spec":{"dashboardConfig":{"disableModelRegistry":false}}}'
```

#### 6.1.3 Deploy MySQL 8.0

```bash
REGISTRY_NAME="model-registry"
NS="rhoai-model-registries"

# Ensure namespace exists
oc create namespace $NS 2>/dev/null || true

# Create credentials (replace <password> and <root-password> with your values)
oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${REGISTRY_NAME}-mysql-credentials
  namespace: $NS
  labels:
    app: ${REGISTRY_NAME}-mysql
type: Opaque
stringData:
  MYSQL_DATABASE: mlmddb
  MYSQL_USER: mlmd
  MYSQL_PASSWORD: <password>
  MYSQL_ROOT_PASSWORD: <root-password>
EOF

# Deploy MySQL 8
oc apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${REGISTRY_NAME}-mysql
  namespace: $NS
  labels:
    app: ${REGISTRY_NAME}-mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${REGISTRY_NAME}-mysql
  template:
    metadata:
      labels:
        app: ${REGISTRY_NAME}-mysql
    spec:
      containers:
      - name: mysql
        image: registry.redhat.io/rhel9/mysql-80:latest
        ports:
        - containerPort: 3306
        envFrom:
        - secretRef:
            name: ${REGISTRY_NAME}-mysql-credentials
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql/data
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: "1"
            memory: 1Gi
        readinessProbe:
          exec:
            command: ["/bin/bash", "-c", "mysqladmin ping -u root -p\${MYSQL_ROOT_PASSWORD}"]
          initialDelaySeconds: 20
          periodSeconds: 10
      volumes:
      - name: data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: ${REGISTRY_NAME}-mysql
  namespace: $NS
spec:
  ports:
  - port: 3306
    targetPort: 3306
  selector:
    app: ${REGISTRY_NAME}-mysql
EOF
```

Wait for MySQL to be ready:

```bash
oc get pods -n $NS -l app=${REGISTRY_NAME}-mysql -w
# Wait for 1/1 Running
```

#### 6.1.4 Create ModelRegistry CR

```bash
oc apply -f - <<EOF
apiVersion: modelregistry.opendatahub.io/v1beta1
kind: ModelRegistry
metadata:
  name: $REGISTRY_NAME
  namespace: $NS
spec:
  grpc:
    port: 9090
  rest:
    port: 8080
    serviceRoute: enabled
  mysql:
    host: ${REGISTRY_NAME}-mysql.${NS}.svc.cluster.local
    port: 3306
    database: mlmddb
    username: mlmd
    passwordSecret:
      name: ${REGISTRY_NAME}-mysql-credentials
      key: MYSQL_PASSWORD
EOF
```

#### 6.1.5 Verify

```bash
# Check ModelRegistry status
oc get modelregistry.modelregistry.opendatahub.io -n $NS

# Check pods
oc get pods -n $NS

# Get REST API route
oc get route -n $NS | grep $REGISTRY_NAME

# MySQL connection (from a pod)
# mysql -h ${REGISTRY_NAME}-mysql.${NS}.svc.cluster.local -u mlmd -p mlmddb

# Port-forward for local access
# oc port-forward svc/${REGISTRY_NAME}-mysql 3306:3306 -n $NS
```

Dashboard access: **Settings → Model resources and operations → AI registry settings**

---

### 6.2 Pipeline Server (Data Science Pipelines)

Per RHAIE 3.3 Guide Chapter 1: requires S3-compatible storage for pipeline artifacts.

#### 6.2.1 Ensure AI Pipelines Enabled in DSC

```bash
oc get datasciencecluster default-dsc \
  -o jsonpath='{.spec.components.aipipelines.managementState}'
# Should return: Managed
```

If not:

```bash
oc patch datasciencecluster default-dsc --type=merge -p '{
  "spec": {"components": {"aipipelines": {"managementState": "Managed"}}}
}'
```

#### 6.2.2 Choose S3 Storage

**Option A: Reuse existing MinIO** (e.g., from model-storage namespace)

```bash
PROJECT_NS="my-ai-project"

# Find existing MinIO
oc get deployment -A | grep minio

# Get credentials from existing secret
MINIO_NS="model-storage"  # adjust to your MinIO namespace
oc get secret -n $MINIO_NS | grep -E "minio|aws-connection"

# Extract credentials
S3_ACCESS=$(oc get secret aws-connection-minio -n $MINIO_NS \
  -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
S3_SECRET=$(oc get secret aws-connection-minio -n $MINIO_NS \
  -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
S3_HOST="minio.${MINIO_NS}.svc.cluster.local"
S3_PORT="9000"

echo "Host: $S3_HOST  Access: $S3_ACCESS"
```

**Option B: Deploy new MinIO in project namespace**

```bash
PROJECT_NS="my-ai-project"
S3_ACCESS="minio"
S3_SECRET="$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)"
S3_HOST="minio.${PROJECT_NS}.svc.cluster.local"
S3_PORT="9000"

oc apply -f - -n $PROJECT_NS <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pipelines-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 50Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  labels:
    app: minio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        args: ["server", "/data", "--console-address", ":9001"]
        env:
        - name: MINIO_ROOT_USER
          value: "$S3_ACCESS"
        - name: MINIO_ROOT_PASSWORD
          value: "$S3_SECRET"
        ports:
        - containerPort: 9000
        - containerPort: 9001
        volumeMounts:
        - name: data
          mountPath: /data
        readinessProbe:
          httpGet:
            path: /minio/health/ready
            port: 9000
          initialDelaySeconds: 10
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minio-pipelines-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: minio
spec:
  ports:
  - port: 9000
    name: api
  - port: 9001
    name: console
  selector:
    app: minio
EOF

# Wait for MinIO
oc get pods -n $PROJECT_NS -l app=minio -w

echo "MinIO credentials: $S3_ACCESS / $S3_SECRET"
```

#### 6.2.3 Create S3 Credentials Secret

```bash
oc apply -f - -n $PROJECT_NS <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: pipelines-s3-credentials
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "$S3_ACCESS"
  AWS_SECRET_ACCESS_KEY: "$S3_SECRET"
EOF
```

#### 6.2.4 Create DataSciencePipelinesApplication CR

```bash
oc apply -f - -n $PROJECT_NS <<EOF
apiVersion: datasciencepipelinesapplications.opendatahub.io/v1
kind: DataSciencePipelinesApplication
metadata:
  name: dspa
spec:
  dspVersion: v2
  apiServer:
    deploy: true
    pipelineStore: kubernetes
  objectStorage:
    externalStorage:
      host: "$S3_HOST"
      port: "$S3_PORT"
      bucket: pipelines
      scheme: http
      s3CredentialsSecret:
        secretName: pipelines-s3-credentials
        accessKey: AWS_ACCESS_KEY_ID
        secretKey: AWS_SECRET_ACCESS_KEY
EOF
```

#### 6.2.5 Verify

```bash
# Wait for pipeline server
oc get dspa dspa -n $PROJECT_NS -w
# Wait for Ready=True

# Check pods
oc get pods -n $PROJECT_NS | grep ds-pipeline

# Get API route
oc get route ds-pipeline-dspa -n $PROJECT_NS \
  -o jsonpath='https://{.spec.host}'
```

Pipeline server is now accessible via:
- **Dashboard:** Projects → your project → Pipelines → Import pipeline
- **Python SDK:**
  ```python
  from kfp import Client
  token = "$(oc whoami -t)"
  route = "$(oc get route ds-pipeline-dspa -n $PROJECT_NS -o jsonpath='{.spec.host}')"
  client = Client(host=f"https://{route}", existing_token=token, ssl_ca_cert=False)
  client.list_pipelines()
  ```

---

### 6.3 Kubernetes MCP Server (OpenShift MCP)

Source: [openshift/openshift-mcp-server](https://github.com/openshift/openshift-mcp-server)

Provides AI agents with Kubernetes/OpenShift operations (pods, deployments, services, logs, Helm, Tekton) via Model Context Protocol.

#### Method A: Helm Chart (requires `helm` + `git`)

```bash
NAMESPACE="my-ai-project"

# Clone just the chart
tmpdir=$(mktemp -d)
git clone --depth=1 --filter=blob:none --sparse \
    https://github.com/openshift/openshift-mcp-server.git "$tmpdir/repo"
cd "$tmpdir/repo" && git sparse-checkout set charts/kubernetes-mcp-server

# Install with Helm
helm upgrade --install kubernetes-mcp-server \
    "$tmpdir/repo/charts/kubernetes-mcp-server" \
    --namespace $NAMESPACE \
    --set server.readOnly=true \
    --set server.port=8080 \
    --set server.stateless=true \
    --set "server.toolsets={core,events}" \
    --set ingress.enabled=false \
    --set route.enabled=false

# Add cluster-wide RBAC (Helm chart only creates namespace-scoped)
SA_NAME=$(oc get sa -n $NAMESPACE -o name 2>/dev/null | grep mcp | head -1 | cut -d/ -f2)
SA_NAME="${SA_NAME:-kubernetes-mcp-server}"
oc create clusterrolebinding kubernetes-mcp-server-$NAMESPACE \
    --clusterrole=view \
    --serviceaccount=$NAMESPACE:$SA_NAME

# Cleanup
rm -rf "$tmpdir"
```

#### Method B: OpenShift BuildConfig (requires only `oc`)

```bash
NAMESPACE="my-ai-project"

# Build on-cluster from GitHub
oc new-build --name=kubernetes-mcp-server --strategy=docker \
    --dockerfile='FROM registry.access.redhat.com/ubi9/go-toolset:latest AS builder
WORKDIR /opt/app-root/src
RUN git clone --depth=1 https://github.com/openshift/openshift-mcp-server.git . && \
    CGO_ENABLED=0 go build -o /opt/app-root/kubernetes-mcp-server ./cmd/kubernetes-mcp-server/
FROM registry.access.redhat.com/ubi9-micro:latest
COPY --from=builder /opt/app-root/kubernetes-mcp-server /usr/local/bin/kubernetes-mcp-server
USER 1001
ENTRYPOINT ["kubernetes-mcp-server"]' \
    -n $NAMESPACE

# Wait for build (2-3 minutes)
oc logs -f bc/kubernetes-mcp-server -n $NAMESPACE

# Create ServiceAccount + cluster RBAC
oc apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kubernetes-mcp-server
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-mcp-server-$NAMESPACE
subjects:
- kind: ServiceAccount
  name: kubernetes-mcp-server
  namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
EOF

# Deploy
oc apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubernetes-mcp-server
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kubernetes-mcp-server
  template:
    metadata:
      labels:
        app: kubernetes-mcp-server
    spec:
      serviceAccountName: kubernetes-mcp-server
      containers:
      - name: server
        image: image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/kubernetes-mcp-server:latest
        args: ["--port=8080", "--stateless", "--read-only", "--toolsets=core,events"]
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: kubernetes-mcp-server
  namespace: $NAMESPACE
spec:
  selector:
    app: kubernetes-mcp-server
  ports:
  - port: 8080
    targetPort: 8080
EOF
```

#### 6.3.3 Verify and Use

```bash
# Verify deployment
oc rollout status deployment/kubernetes-mcp-server -n $NAMESPACE

# MCP endpoint (for LlamaStack / AI Asset registration)
echo "http://kubernetes-mcp-server.${NAMESPACE}.svc.cluster.local:8080/mcp"
```

**Register in RHOAI Dashboard:**
Dashboard → Settings → AI asset endpoints → Add endpoint:
- **Name:** `Kubernetes-MCP-Server`
- **URL:** `http://kubernetes-mcp-server.<namespace>.svc.cluster.local:8080/mcp`
- **Type:** `streamable-http`

**Use with LlamaStack:**
```yaml
tool_groups:
- toolgroup_id: mcp::kubernetes
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://kubernetes-mcp-server.<namespace>.svc.cluster.local:8080/mcp
```

**Available toolset options:** `core`, `config`, `events`, `helm`, `tekton`, `exec`

> **Note:** Use `--read-only` (default) for shared clusters. Remove it only if you need write/delete operations.

---

## Verification Commands

```bash
# === Operators ===
oc get csv -A | grep -E "nfd|gpu|kueue|lws|rhcl|rhods|cert-manager|servicemesh|jobset"

# === RHOAI Status ===
oc get datasciencecluster
oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}'
oc get datasciencecluster default-dsc -o yaml | grep -A 50 installedComponents

# === Dashboard Route ===
oc get route -n redhat-ods-applications | grep dashboard

# === Hardware Profiles ===
oc get hardwareprofiles -n redhat-ods-applications

# === GPU Nodes ===
oc get nodes -l nvidia.com/gpu.present=true

# === Model Serving ===
oc get inferenceservice -A
oc get llminferenceservice -A

# === MaaS (if enabled) ===
oc get gateway -n openshift-ingress
oc get gatewayclass
oc get kuadrant -n kuadrant-system
oc get authorino -n kuadrant-system

# === Feature Store ===
oc get featurestore -A

# === Model Registry ===
oc get modelregistry.modelregistry.opendatahub.io -n rhoai-model-registries
oc get route -n rhoai-model-registries

# === Pipeline Server ===
oc get dspa -A
oc get route -A | grep ds-pipeline

# === MCP Server ===
oc get deployment -A | grep kubernetes-mcp-server

# === All Pods Health ===
oc get pods -n redhat-ods-applications --field-selector=status.phase!=Running,status.phase!=Succeeded
```

---

## Troubleshooting

### RHOAI operator stuck installing

```bash
# Check InstallPlan
oc get installplan -n redhat-ods-operator
# Approve if stuck on Manual:
oc patch installplan <name> -n redhat-ods-operator --type=merge \
  -p '{"spec": {"approved": true}}'
```

### DataScienceCluster not reaching Ready

```bash
oc describe datasciencecluster default-dsc
oc get pods -n redhat-ods-applications | grep -v Running | grep -v Completed
```

### Model pod not scheduling (Pending)

```bash
oc describe pod -n <namespace> -l serving.kserve.io/inferenceservice=<model-name>
# Check for: tolerations missing, insufficient GPU, wrong nodeSelector
```

Ensure your Hardware Profile includes the GPU scheduling section and the InferenceService has matching tolerations.

### Authorino not working (401 errors on MaaS)

```bash
# Restart controllers
oc delete pod -n redhat-ods-applications -l app=odh-model-controller
oc delete pod -n redhat-ods-applications -l control-plane=kserve-controller-manager

# Check AuthPolicy
oc get authpolicy -n openshift-ingress

# Check Authorino pods
oc get pods -n kuadrant-system
```

### Gateway not programmed

```bash
oc describe gateway openshift-ai-inference -n openshift-ingress
# Check for Service Mesh / Istio issues
oc get pods -n openshift-operators | grep istio
```

### Feature Store not visible in dashboard

```bash
# Add required labels
oc label featurestore <name> -n <ns> feature-store-ui=enabled --overwrite
oc label featurestore <name> -n <ns> opendatahub.io/dashboard=true --overwrite
oc label namespace <ns> opendatahub.io/dashboard=true --overwrite

# Enable REST API
oc patch featurestore <name> -n <ns> --type=merge \
  -p '{"spec":{"services":{"registry":{"local":{"server":{"restAPI":true}}}}}}'
```

---

## Quick Reference: What Needs What

| Component | Required Operators | Phase |
|-----------|-------------------|-------|
| **Basic RHOAI** | NFD, GPU, cert-manager | 1–2 |
| **Model Serving (vLLM)** | Above | 3 |
| **MaaS / llm-d** | Above + Kueue, LWS, Service Mesh 3, RHCL | 4 |
| **Trainer v2** | Above + JobSet | 5.2 |
| **Feature Store** | Basic RHOAI (Feast in DSC) | 5.3 |
| **Workbenches** | Basic RHOAI | 2 (included) |
| **AI Pipelines** | Basic RHOAI + S3 storage | 2 (included) |
| **LlamaStack** | Basic RHOAI + cert-manager, Service Mesh 3, NFD, GPU | 2 (included) |
| **Model Registry** | Basic RHOAI + MySQL 8.x | 6.1 |
| **Pipeline Server** | Basic RHOAI + S3 storage (MinIO) | 6.2 |
| **MCP Server** | Basic RHOAI (oc or helm) | 6.3 |

### Operator Channel Quick Reference

| Operator | Namespace | Channel | Source |
|----------|-----------|---------|--------|
| NFD | `openshift-nfd` | `stable` | `redhat-operators` |
| GPU Operator | `nvidia-gpu-operator` | `stable` | `certified-operators` |
| cert-manager | `cert-manager-operator` | `stable-v1` | `redhat-operators` |
| RHOAI | `redhat-ods-operator` | `fast-3.x` | `redhat-operators` |
| Kueue | `openshift-operators` | `stable-v1.3` | `redhat-operators` |
| LWS | `openshift-lws-operator` | `stable-v1.0` | `redhat-operators` |
| Service Mesh 3 | `openshift-operators` | `stable` | `redhat-operators` |
| RHCL | `kuadrant-system` | `stable` | `redhat-operators` |
| JobSet | `openshift-operators` | `stable` | `redhat-operators` |
