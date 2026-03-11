# RHOAI 3.3 Installation Guide

This guide covers the installation of Red Hat OpenShift AI (RHOAI) 3.3 on OpenShift 4.19+.

## Key Differences from 3.2

### New Features in 3.3
- **Kubeflow Trainer v2** - GA release replacing Training Operator v1
- **IBM Spyre AI accelerators** - GA support on IBM Power
- **Model catalog allow/disallow** - Admin control over visible models
- **vLLM-Gaudi 1.23** - Enhanced Intel Gaudi support
- **MLServer ServingRuntime** - Tech Preview for scikit-learn, XGBoost, LightGBM
- **Llama Stack 0.4.2** - OpenAI-compatible RAG annotations (Tech Preview)
- **MaaS Zero-Touch setup** - Simplified Models-as-a-Service configuration

### Breaking Changes
- Dashboard URL changed: `data-science-gateway.apps.<cluster>` (not `rhods-dashboard-...`)
- CodeFlare Operator removed (functionality moved to KubeRay)
- Caikit-NLP and TGIS components removed
- Resource naming now uses `data-science-` prefix

### Deprecations
- Ray-based multi-node vLLM template (will be removed in 3.4)
- Kubeflow Training Operator v1 (migrate to Trainer v2)
- KServe Serverless deployment mode
- Accelerator Profiles (replaced by Hardware Profiles)

## Prerequisites

### Platform Requirements
- **OpenShift**: 4.19 - 4.21 (4.20+ required for llm-d)
- **Cluster**: Minimum 2 worker nodes with 8 CPUs, 32 GiB RAM each
- **Storage**: Default storage class with dynamic provisioning
- **Identity Provider**: Configured for authentication

### Required Operators (Install BEFORE RHOAI)

| Operator | Purpose | Required For |
|----------|---------|--------------|
| Node Feature Discovery (NFD) | GPU detection | GPU workloads |
| NVIDIA GPU Operator | GPU drivers | NVIDIA GPUs |
| Red Hat Build of Kueue | Workload scheduling | Distributed workloads, GPU scheduling |
| cert-manager Operator | Certificate management | KServe, llm-d, distributed workloads |
| Red Hat Connectivity Link (RHCL) | API gateway | MaaS, llm-d auth |
| Red Hat Leader Worker Set (LWS) | Multi-node inference | llm-d multi-GPU/MoE |

### NVIDIA Driver Version Note
Due to a known issue with the latest NVIDIA GPU Operator, pin the driver version:
```yaml
# In ClusterPolicy
driver:
  repository: nvcr.io/nvidia
  image: driver
  version: 570.195.03
```

## Installation Steps

### Step 1: Install Required Operators

```bash
# Install NFD Operator
oc apply -f lib/manifests/operators/nfd-operator.yaml

# Wait for NFD, then create instance
oc apply -f lib/manifests/operators/nfd-instance.yaml

# Install GPU Operator
oc apply -f lib/manifests/operators/gpu-operator.yaml

# Wait for GPU Operator, then create ClusterPolicy
oc apply -f lib/manifests/operators/gpu-clusterpolicy.yaml

# Install Kueue Operator
oc apply -f lib/manifests/operators/kueue-subscription.yaml

# Install cert-manager
oc apply -f lib/manifests/operators/certmanager-namespace.yaml
oc apply -f lib/manifests/operators/certmanager-operatorgroup.yaml
oc apply -f lib/manifests/operators/certmanager-subscription.yaml

# Install LWS (for llm-d multi-node)
oc apply -f lib/manifests/operators/lws-namespace.yaml
oc apply -f lib/manifests/operators/lws-operatorgroup.yaml
oc apply -f lib/manifests/operators/lws-subscription.yaml
```

### Step 2: Install RHCL (for MaaS/llm-d)

```bash
# Create kuadrant-system namespace
oc create namespace kuadrant-system

# Install RHCL Operator in kuadrant-system namespace
# (Use OperatorHub or CLI)

# Create Kuadrant instance
oc apply -f - <<EOF
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
EOF

# Annotate Authorino service for TLS
oc annotate svc/authorino-authorino-authorization \
  service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
  -n kuadrant-system

# Update Authorino for TLS
oc apply -f - <<EOF
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

### Step 3: Enable User Workload Monitoring

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

### Step 4: Install RHOAI Operator

```bash
# Create namespace
oc create namespace redhat-ods-operator

# Create OperatorGroup
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
EOF

# Create Subscription (fast-3.x channel for 3.3)
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  name: rhods-operator
  channel: fast-3.x
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# Wait for operator to be ready
./scripts/check-operator-install-status.sh rhods-operator redhat-ods-operator
```

### Step 5: Create DataScienceCluster

```bash
oc apply -f lib/manifests/rhoai/datasciencecluster-v3.yaml
```

See `lib/manifests/rhoai/datasciencecluster-v3.yaml` for the full configuration.

### Step 6: Enable Dashboard Features

```bash
# Update OdhDashboardConfig
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
        "modelAsService": true,
        "disableLMEval": false
      }
    }
  }'
```

### Step 7: Create Gateway for llm-d/MaaS

```bash
# Create GatewayClass
oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF

# Create Gateway (replace <cluster-domain>)
oc apply -f - <<EOF
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
      hostname: inference-gateway.apps.<cluster-domain>
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

### Step 8: Create Hardware Profile

```bash
oc apply -f - <<EOF
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: gpu-profile
  name: gpu-profile
  namespace: redhat-ods-applications
spec:
  identifiers:
    - defaultCount: '1'
      displayName: CPU
      identifier: cpu
      maxCount: '8'
      minCount: 1
      resourceType: CPU
    - defaultCount: 12Gi
      displayName: Memory
      identifier: memory
      maxCount: 24Gi
      minCount: 1Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 4
      minCount: 1
      resourceType: Accelerator
EOF
```

## Verification

```bash
# Check RHOAI operator
oc get csv -n redhat-ods-operator | grep rhods

# Check DataScienceCluster status
oc get datasciencecluster -o jsonpath='{.items[0].status.phase}'
# Should return: Ready

# Check installed components
oc get datasciencecluster -o yaml | grep -A 50 installedComponents

# Check dashboard route
oc get route -n redhat-ods-applications | grep dashboard

# Check GPU nodes
oc get nodes -l nvidia.com/gpu.present=true

# Check hardware profiles
oc get hardwareprofiles -n redhat-ods-applications
```

## Deploying Models

### vLLM with Tool Calling

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    opendatahub.io/hardware-profile-namespace: redhat-ods-applications
    opendatahub.io/hardware-profile-name: gpu-profile
  name: llama-32-3b-instruct
  namespace: ai-bu-shared
spec:
  predictor:
    model:
      args:
        - '--dtype=half'
        - '--max-model-len=20000'
        - '--gpu-memory-utilization=0.95'
        - '--enable-auto-tool-choice'
        - '--tool-call-parser=llama3_json'
        - '--chat-template=/opt/app-root/template/tool_chat_template_llama3.2_json.jinja'
      modelFormat:
        name: vLLM
      resources:
        limits:
          nvidia.com/gpu: '1'
        requests:
          nvidia.com/gpu: '1'
      storageUri: 'oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct'
```

### llm-d with MaaS (Authentication)

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-sample
  namespace: llama-serving
  labels:
    kueue.x-k8s.io/queue-name: default
    opendatahub.io/dashboard: "true"
    opendatahub.io/genai-asset: "true"
  annotations:
    security.opendatahub.io/enable-auth: "true"  # Enable auth
spec:
  replicas: 1
  model:
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:latest
    name: RedHatAI/Qwen3-8B-FP8-dynamic
  router:
    route: {}
    gateway: {}
    scheduler: {}
  template:
    containers:
    - name: main
      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: "--enable-auto-tool-choice --tool-call-parser=hermes"
      resources:
        limits:
          nvidia.com/gpu: "1"
        requests:
          nvidia.com/gpu: "1"
```

## Known Issues in 3.3

1. **RAG uploads fail on disconnected clusters** - Workaround: Set `HF_HUB_OFFLINE=1` env var
2. **TrainJob fails after upgrade** - Delete and recreate affected TrainJobs
3. **Dashboard URLs return 404 after 2.x→3.x upgrade** - Use new URL format
4. **Kueue 1.2 fails with legacy CRDs** - Delete legacy v1alpha1 CRDs

## Troubleshooting

### Authorino Not Working
```bash
# Restart controllers
oc delete pod -n redhat-ods-applications -l app=odh-model-controller
oc delete pod -n redhat-ods-applications -l control-plane=kserve-controller-manager

# Verify AuthPolicy
oc get authPolicy -n openshift-ingress
```

### Model Deployment Fails
```bash
# Check InferenceService status
oc describe inferenceservice <name> -n <namespace>

# Check predictor pod logs
oc logs -n <namespace> -l serving.kserve.io/inferenceservice=<name> -c kserve-container
```

## References

- [RHOAI 3.3 Release Notes](docs/reference/RHAIE%203.3%20Guide/Red_Hat_OpenShift_AI_Self-Managed-3.3-Release_notes-en-US.pdf.md)
- [RHOAI 3.3 Installation Guide](docs/reference/RHAIE%203.3%20Guide/Red_Hat_OpenShift_AI_Self-Managed-3.3-Installing_and_uninstalling_OpenShift_AI_Self-Managed-en-US.pd.md)
- [MaaS Guide](docs/reference/RHAIE%203.3%20Guide/Red_Hat_OpenShift_AI_Self-Managed-3.3-Govern_LLM_access_with_Models-as-a-Service-en-US.pdf.md)
