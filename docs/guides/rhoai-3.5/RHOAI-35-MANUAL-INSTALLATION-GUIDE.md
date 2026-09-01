# Red Hat OpenShift AI 3.5 — Manual Installation Guide

This guide covers step-by-step manual installation of Red Hat OpenShift AI (RHOAI) 3.5
on OpenShift Container Platform 4.19–4.22. It provides two installation paths depending on
whether you need Models-as-a-Service (MaaS) or direct model serving only.

> **Automated alternative:** Run `scripts/install-rhoai-35.sh` for a fully automated
> installation that handles all phases described here.

Reference: [RHOAI 3.5 Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5)

---

## Table of Contents

- [1. Architecture Overview](#1-architecture-overview)
- [2. Prerequisites](#2-prerequisites)
- [3. Phase 1: Core Operators (Both Paths)](#3-phase-1-core-operators-both-paths)
- [4. Phase 2: RHOAI Operator (Both Paths)](#4-phase-2-rhoai-operator-both-paths)
- [Path A: RHOAI Without MaaS](#path-a-rhoai-without-maas)
  - [5A. DataScienceCluster (No MaaS)](#5a-datasciencecluster-no-maas)
  - [6A. Dashboard Features (No MaaS)](#6a-dashboard-features-no-maas)
  - [7A. Hardware Profile](#7a-hardware-profile)
  - [8A. Deploy a Model (vLLM)](#8a-deploy-a-model-vllm)
  - [9A. Verification (No MaaS)](#9a-verification-no-maas)
- [Path B: RHOAI With MaaS](#path-b-rhoai-with-maas)
  - [5B. MaaS Prerequisites](#5b-maas-prerequisites)
  - [6B. Red Hat Connectivity Link](#6b-red-hat-connectivity-link)
  - [7B. Authorino TLS](#7b-authorino-tls)
  - [8B. Gateway Setup](#8b-gateway-setup)
  - [9B. DataScienceCluster (MaaS)](#9b-datasciencecluster-maas)
  - [10B. PostgreSQL and MaaS Database](#10b-postgresql-and-maas-database)
  - [11B. Dashboard Features (MaaS)](#11b-dashboard-features-maas)
  - [12B. Verify MaaS Platform](#12b-verify-maas-platform)
  - [13B. Deploy Model (llm-d and MaaS CRs)](#13b-deploy-model-llm-d-and-maas-crs)
  - [14B. End-to-End Verification](#14b-end-to-end-verification)
- [Observability (Optional)](#observability-optional)
- [Optional Components](#optional-components)
- [Troubleshooting](#troubleshooting)
- [Quick Reference: What Needs What](#quick-reference-what-needs-what)

---

## 1. Architecture Overview

RHOAI 3.5 supports two deployment topologies. Choose the path that matches your needs.

### Path A: Without MaaS (Direct Model Serving)

```
+---------------------+
|  OpenShift 4.19–4.22|
+---------------------+
         |
   +-----+------+
   |  Operators  |
   |  NFD, GPU,  |
   | cert-manager|
   +-----+------+
         |
   +-----+------+
   |   RHOAI    |
   |  Operator  |
   +-----+------+
         |
   +-----+----------+
   | DataScience     |
   | Cluster         |
   |  - Dashboard    |
   |  - KServe       |
   |  - Workbenches  |
   |  - Pipelines    |
   |  - ModelRegistry|
   |  - TrustyAI     |
   |  - OGX          |
   |  - MCP Lifecycle|
   +-----+----------+
         |
   +-----+----------+
   | Model Serving   |
   |  ServingRuntime  |
   |  InferenceService|
   +-----+----------+
         |
   +-----+----------+
   | OpenShift Route |
   | (direct access) |
   +----------------+
```

Users access models directly via OpenShift Routes. No authentication gateway,
no subscription management. Best for teams that manage their own access control
or run models internally.

### Path B: With MaaS (Full Platform)

```
+---------------------+
|  OpenShift 4.19–4.22|
+---------------------+
         |
   +-----+------+--------+
   |  Operators           |
   |  NFD, GPU, cert-mgr, |
   |  RHCL 1.4.1+,       |
   |  Svc Mesh 3.4,      |
   |  Kueue, LWS         |
   +-----+------+--------+
         |
   +-----+------+
   |   RHOAI    |
   |  Operator  |
   +-----+------+
         |
   +-----+----------+
   | DataScience     |
   | Cluster         |
   |  - All Path A   |
   |  - MaaS         |
   +-----+----------+
         |
   +-----+---------+     +-------------------+
   | Kuadrant /    |     | PostgreSQL        |
   | Authorino     |     | (API keys/        |
   | (auth + rate  |     |  subscriptions)   |
   |  limiting)    |     | redhat-ai-gateway |
   +-----+---------+     | -infra namespace  |
         |               +--------+----------+
         |                        |
   +-----+----------+            |
   | Istio Gateway  +------------+
   | maas-default-  |
   | gateway        |
   +-----+----------+
         |
   +-----+----------+
   | MaaS Control   |
   | Plane          |
   |  MaasTenantCfg |
   |  MaaSModelRef  |
   |  MaaSAuthPolicy|
   |  MaaSSubscript.|
   |  TokenRateLimit|
   +-----+----------+
         |
   +-----+----------+
   | llm-d Runtime  |
   | LLMInference   |
   | Service        |
   +-----+----------+
         |
   +-----+----------+
   | maas.apps.*    |
   | (API gateway)  |
   +----------------+
```

Users access models through an authenticated API gateway with API keys,
subscription tiers, and token-based rate limiting. Supports llm-d distributed
inference runtime. Best for multi-tenant platforms serving LLMs at scale.

> **New in 3.5:** MaaS infrastructure workloads (`maas-api`, `maas-controller`,
> PostgreSQL, `maas-db-config` secret) now live in the `redhat-ai-gateway-infra`
> namespace instead of `redhat-ods-applications`. The `maas-controller` auto-creates
> gateway policies (`AuthPolicy`, `TokenRateLimitPolicy`) — no manual rate-limit
> or EnvoyFilter setup is required.

### Key Differences

| Aspect | Path A (No MaaS) | Path B (With MaaS) |
|--------|-------------------|---------------------|
| Model CR | `InferenceService` (v1beta1) | `LLMInferenceService` (v1alpha1) |
| Runtime | vLLM, OpenVINO, Caikit-TGIS | llm-d (distributed inference) |
| Access | OpenShift Route (direct) | MaaS Gateway (API keys) |
| Auth | OpenShift RBAC only | Authorino + MaaS subscriptions |
| Rate Limiting | None | Token-based via TokenRateLimitPolicy |
| Extra Operators | None | RHCL 1.4.1+, Service Mesh 3.4, Kueue, LWS |
| Database | None | PostgreSQL (API key storage) |
| Infra Namespace | N/A | `redhat-ai-gateway-infra` |

---

## 2. Prerequisites

### Cluster Requirements

- OpenShift Container Platform 4.19–4.22
- Cluster-admin access
- At least 2 worker nodes (3+ recommended for production)
- GPU nodes required for GPU model serving (NVIDIA L40S, A100, H100, etc.)

> **Note:** Distributed inference with llm-d (Path B) requires OCP 4.20+.

### CLI Tools

Verify all required CLI tools are installed:

```bash
# Required
oc version
jq --version

# Optional (for PostgreSQL password generation)
openssl version
```

### Cluster Login and Permissions

```bash
# Verify login
oc whoami

# Verify cluster-admin
oc auth can-i create clusterrole
```

### OpenShift Version Check

```bash
OCP_VERSION=$(oc version -o json | jq -r '.openshiftVersion' | cut -d. -f1,2)
echo "OpenShift version: $OCP_VERSION"

# RHOAI 3.5 requires OCP 4.19–4.22
if [[ "$OCP_VERSION" < "4.19" ]]; then
  echo "ERROR: RHOAI 3.5 requires OpenShift 4.19 or later"
  exit 1
fi
```

### RHOAI Channel Selection

Check available channels on your cluster:

```bash
oc get packagemanifest rhods-operator -n openshift-marketplace \
  -o jsonpath='{.status.channels[*].name}' | tr ' ' '\n' | sort -V
```

Choose one:
- `fast-3.x` — Latest features, rolling updates
- `stable-3.5` — Pinned to 3.5 stream
- `eus-3.5` — Extended Update Support for 3.5

Set the channel for use throughout this guide:

```bash
export RHOAI_CHANNEL="fast-3.x"
```

### Cluster Domain

Determine your cluster domain (used throughout the guide):

```bash
export CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster \
  -o jsonpath='{.spec.domain}' | sed 's/^apps\.//')
echo "Cluster domain: $CLUSTER_DOMAIN"
```

---

## 3. Phase 1: Core Operators (Both Paths)

These operators are required regardless of which path you choose.

### 3.1 Node Feature Discovery (NFD)

NFD detects hardware features on nodes and labels them accordingly.
Required for the GPU Operator to identify GPU-equipped nodes.

```bash
oc apply -f lib/manifests/operators/nfd-operator.yaml
```

Wait for the operator:

```bash
oc wait csv -n openshift-nfd -l operators.coreos.com/nfd.openshift-nfd \
  --for=jsonpath='{.status.phase}'=Succeeded --timeout=300s 2>/dev/null || \
  echo "Waiting for NFD CSV..." && sleep 30
```

If `oc wait` on CSV labels is not available, poll manually:

```bash
until oc get csv -n openshift-nfd 2>/dev/null | grep -q "nfd.*Succeeded"; do
  echo "Waiting for NFD operator..."
  sleep 10
done
```

Create the NFD instance:

```bash
oc apply -f lib/manifests/operators/nfd-instance.yaml
```

**Verify:**

```bash
oc get csv -n openshift-nfd | grep nfd
oc get nodefeaturediscovery -n openshift-nfd
```

### 3.2 NVIDIA GPU Operator

The GPU Operator manages NVIDIA drivers, device plugins, and monitoring for
GPU-equipped nodes. If you have no GPUs yet, install the operator now — it will
reconcile automatically when GPU nodes join.

```bash
oc apply -f lib/manifests/operators/gpu-operator.yaml
```

Wait for the operator:

```bash
until oc get csv -n nvidia-gpu-operator 2>/dev/null | grep -q "gpu-operator.*Succeeded"; do
  echo "Waiting for GPU Operator..."
  sleep 10
done
```

Create the ClusterPolicy:

```bash
oc apply -f lib/manifests/operators/gpu-clusterpolicy.yaml
```

**Verify:**

```bash
oc get csv -n nvidia-gpu-operator | grep gpu
oc get clusterpolicy gpu-cluster-policy
```

If GPU nodes are present, verify driver pods:

```bash
oc get pods -n nvidia-gpu-operator -l app=nvidia-driver-daemonset
```

### 3.3 cert-manager Operator

Required by KServe for webhook certificates and by RHCL (Path B).
RHOAI 3.5 requires cert-manager **1.19 or 1.20**.

```bash
oc create namespace cert-manager-operator 2>/dev/null || true
oc apply -f lib/manifests/operators/certmanager-operatorgroup.yaml
oc apply -f lib/manifests/operators/certmanager-subscription.yaml
```

Wait for the operator:

```bash
until oc get csv -n cert-manager-operator 2>/dev/null | grep -q "cert-manager.*Succeeded"; do
  echo "Waiting for cert-manager Operator..."
  sleep 10
done
```

**Verify:**

```bash
oc get csv -n cert-manager-operator | grep cert-manager
oc get pods -n cert-manager
```

### 3.4 User Workload Monitoring

Required for RHOAI metrics. Also required by MaaS for token usage tracking (Path B).

```bash
oc apply -f lib/manifests/monitoring/cluster-monitoring-config.yaml
```

**Verify:**

```bash
oc get configmap cluster-monitoring-config -n openshift-monitoring -o yaml | grep enableUserWorkload
```

Expected output: `enableUserWorkload: true`

### Phase 1 Checkpoint

Confirm all core operators are running:

```bash
echo "=== Core Operators ==="
echo "NFD:          $(oc get csv -n openshift-nfd 2>/dev/null | grep nfd | awk '{print $NF}')"
echo "GPU:          $(oc get csv -n nvidia-gpu-operator 2>/dev/null | grep gpu | awk '{print $NF}')"
echo "cert-manager: $(oc get csv -n cert-manager-operator 2>/dev/null | grep cert-manager | awk '{print $NF}')"
echo "UWM:          $(oc get configmap cluster-monitoring-config -n openshift-monitoring -o jsonpath='{.data.config\.yaml}' 2>/dev/null | grep -c 'enableUserWorkload: true') (1=enabled)"
```

All operators should show `Succeeded`.

---

## 4. Phase 2: RHOAI Operator (Both Paths)

### 4.1 Install the RHOAI Operator

Create the namespace and install the operator:

```bash
oc create namespace redhat-ods-operator 2>/dev/null || true
oc apply -f lib/manifests/rhoai/rhoai-operatorgroup.yaml

export RHOAI_CHANNEL
envsubst '${RHOAI_CHANNEL}' < lib/manifests/rhoai/rhoai-subscription.yaml | oc apply -f -
```

Wait for the operator:

```bash
until oc get csv -n redhat-ods-operator 2>/dev/null | grep -q "rhods.*Succeeded"; do
  echo "Waiting for RHOAI Operator..."
  sleep 10
done
echo "RHOAI Operator ready"
```

**Verify:**

```bash
oc get csv -n redhat-ods-operator | grep rhods
```

### 4.2 Apply DSCInitialization

DSCInitialization controls the applications namespace, monitoring settings, and
trusted CA bundle. It must be applied before the DataScienceCluster.

```bash
oc apply -f lib/manifests/rhoai/dscinitialization.yaml
```

Wait for it to be ready:

```bash
oc wait --for=jsonpath='{.status.phase}'=Ready \
  dscinitialization/default-dsci --timeout=120s
```

**Verify:**

```bash
oc get dscinitialization default-dsci -o jsonpath='{.status.phase}'
# Expected: Ready
```

### Phase 2 Checkpoint

```bash
echo "=== RHOAI Operator ==="
echo "Operator CSV: $(oc get csv -n redhat-ods-operator 2>/dev/null | grep rhods | awk '{print $1, $NF}')"
echo "DSCI Status:  $(oc get dscinitialization default-dsci -o jsonpath='{.status.phase}' 2>/dev/null)"
echo "Channel:      $RHOAI_CHANNEL"
```

---

At this point, choose your path:

- **Path A** — If you need direct model serving without MaaS, continue to [5A](#5a-datasciencecluster-no-maas)
- **Path B** — If you need the full MaaS platform, continue to [5B](#5b-maas-prerequisites)

---

# Path A: RHOAI Without MaaS

This path deploys RHOAI for direct model serving. Models are served via vLLM
(or other runtimes) and accessed through OpenShift Routes. No API gateway,
no subscription management, no rate limiting.

## 5A. DataScienceCluster (No MaaS)

Create a DataScienceCluster without MaaS. Apply this manifest directly:

```bash
cat <<'EOF' | oc apply -f -
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
      argoWorkflowsControllers:
        managementState: Managed
    kserve:
      managementState: Managed
      defaultDeploymentMode: RawDeployment
      rawDeploymentServiceConfig: Headed
      nim:
        managementState: Managed
    # aigateway replaces kserve.modelsAsService in 3.5
    aigateway:
      managementState: Removed
      modelsAsAService:
        managementState: Removed
    kueue:
      managementState: Unmanaged
    ray:
      managementState: Managed
    trainer:
      managementState: Removed
    trainingoperator:
      managementState: Removed
    modelregistry:
      managementState: Managed
      registriesNamespace: rhoai-model-registries
    trustyai:
      managementState: Managed
    feastoperator:
      managementState: Managed
    ogx:
      managementState: Managed
    mcplifecycleoperator:
      managementState: Managed
    mlflowoperator:
      managementState: Managed
EOF
```

> **Key differences from Path B:** `aigateway.modelsAsAService` is set to `Removed`.
>
> **Key differences from RHOAI 3.4:**
> - `llamastackoperator` is replaced by `ogx` (OGX Operator replaces Llama Stack)
> - `mcplifecycleoperator` is a new first-class DSC component (no manual GitHub install needed)
> - API version remains `datasciencecluster.opendatahub.io/v2`

Wait for the DSC to become ready:

```bash
echo "Waiting for DataScienceCluster..."
until oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Ready"; do
  PHASE=$(oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}' 2>/dev/null)
  echo "  DSC phase: $PHASE"
  sleep 15
done
echo "DataScienceCluster is Ready"
```

Wait for key readiness conditions:

```bash
oc wait --for=jsonpath='{.status.conditions[?(@.type=="DashboardReady")].status}'=True \
  datasciencecluster/default-dsc --timeout=300s

oc wait --for=jsonpath='{.status.conditions[?(@.type=="KserveReady")].status}'=True \
  datasciencecluster/default-dsc --timeout=300s
```

**Verify:**

```bash
oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}'
# Expected: Ready
```

## 6A. Dashboard Features (No MaaS)

Enable basic dashboard features. MaaS-specific flags are not needed.

```bash
# Wait for dashboard config to exist
until oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; do
  echo "Waiting for dashboard config..."
  sleep 5
done

oc patch odhdashboardconfig odh-dashboard-config \
  -n redhat-ods-applications --type=merge -p '{
    "spec": {
      "dashboardConfig": {
        "disableModelRegistry": false,
        "disableModelCatalog": false,
        "disableKServeMetrics": false,
        "disableLMEval": false,
        "roleManagement": true
      }
    }
  }'
```

> **New in 3.5:** `roleManagement` is enabled by default — it provides the
> custom RBAC role creation UI in the dashboard.

**Verify:**

```bash
oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
  -o jsonpath='{.spec.dashboardConfig}' | jq .
```

## 7A. Hardware Profile

Create a GPU hardware profile so the dashboard can schedule GPU workloads
with proper tolerations.

```bash
oc apply -f lib/manifests/rhoai/hardware-profile-gpu.yaml
```

**Verify:**

```bash
oc get hardwareprofile gpu-profile -n redhat-ods-applications
```

> **Critical:** GPU hardware profiles MUST include scheduling tolerations for
> `nvidia.com/gpu`. Without them, pods will not schedule on tainted GPU nodes.
> Deployed models MUST have ALL THREE annotations for the dashboard to show the
> correct profile name:
> - `opendatahub.io/hardware-profile-name`
> - `opendatahub.io/hardware-profile-namespace`
> - `opendatahub.io/hardware-profile-resource-version`

## 8A. Deploy a Model (vLLM)

This section shows how to deploy a model with the vLLM runtime and access it
via an OpenShift Route. This example uses a Granite model from an S3-compatible
storage backend.

### 8A.1 Create a Model Namespace

```bash
oc new-project my-models 2>/dev/null || oc project my-models
```

### 8A.2 Create Model Storage Secret

If your model is stored in S3-compatible storage (MinIO, AWS S3, etc.):

```bash
oc create secret generic model-s3-creds \
  --from-literal=AWS_ACCESS_KEY_ID="<your-access-key>" \
  --from-literal=AWS_SECRET_ACCESS_KEY="<your-secret-key>" \
  --from-literal=AWS_DEFAULT_ENDPOINT="<your-s3-endpoint>" \
  --from-literal=AWS_S3_BUCKET="<your-bucket>" \
  --from-literal=AWS_DEFAULT_REGION="us-east-1" \
  -n my-models
```

### 8A.3 Create a ServingRuntime

```bash
cat <<'EOF' | oc apply -n my-models -f -
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: vllm-runtime
  annotations:
    opendatahub.io/recommended-accelerators: '["nvidia.com/gpu"]'
    openshift.io/display-name: vLLM Runtime
spec:
  annotations:
    prometheus.io/port: "8080"
    prometheus.io/path: /metrics
  multiModel: false
  supportedModelFormats:
    - autoSelect: true
      name: vLLM
  containers:
    - name: kserve-container
      image: quay.io/modh/vllm:rhoai-2.22
      command:
        - python
        - -m
        - vllm.entrypoints.openai.api_server
      args:
        - "--port=8080"
        - "--model=/mnt/models"
        - "--served-model-name={{.Name}}"
        - "--max-model-len=4096"
      ports:
        - containerPort: 8080
          protocol: TCP
      env:
        - name: HF_HUB_CACHE
          value: /tmp/hf_cache
      resources:
        requests:
          cpu: "2"
          memory: 8Gi
        limits:
          cpu: "4"
          memory: 16Gi
EOF
```

### 8A.4 Create an InferenceService

```bash
cat <<'EOF' | oc apply -n my-models -f -
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: granite-8b
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    opendatahub.io/hardware-profile-name: gpu-profile
    opendatahub.io/hardware-profile-namespace: redhat-ods-applications
  labels:
    opendatahub.io/dashboard: "true"
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: vllm-runtime
      storageUri: "s3://models/granite-3.3-8b-instruct"
      resources:
        requests:
          nvidia.com/gpu: "1"
        limits:
          nvidia.com/gpu: "1"
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
EOF
```

> **Note:** Adjust `storageUri` and GPU resource counts to match your setup.

### 8A.5 Wait for the Model to Be Ready

```bash
echo "Waiting for InferenceService to be ready..."
until oc get inferenceservice granite-8b -n my-models \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; do
  echo "  Status: $(oc get inferenceservice granite-8b -n my-models -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)"
  sleep 15
done
echo "Model is ready"
```

### 8A.6 Get the Model Endpoint

```bash
MODEL_URL=$(oc get inferenceservice granite-8b -n my-models \
  -o jsonpath='{.status.url}')
echo "Model URL: $MODEL_URL"
```

If using RawDeployment mode, get the route:

```bash
oc get routes -n my-models
```

### 8A.7 Test Inference

```bash
MODEL_ROUTE=$(oc get route -n my-models -o jsonpath='{.items[0].spec.host}')

curl -sk "https://${MODEL_ROUTE}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite-8b",
    "messages": [{"role": "user", "content": "Hello, how are you?"}],
    "max_tokens": 50
  }'
```

## 9A. Verification (No MaaS)

Run through these checks to confirm a successful Path A installation.

```bash
echo "=== Path A Verification ==="
echo ""

# RHOAI Operator
echo "1. RHOAI Operator:"
oc get csv -n redhat-ods-operator | grep rhods
echo ""

# DataScienceCluster
echo "2. DataScienceCluster:"
oc get datasciencecluster default-dsc -o jsonpath='  Phase: {.status.phase}{"\n"}'
echo ""

# Dashboard
echo "3. Dashboard URL:"
DASHBOARD=$(oc get route -n redhat-ods-applications -o jsonpath='{.items[?(@.metadata.name=="rh-ai")].spec.host}' 2>/dev/null)
if [ -z "$DASHBOARD" ]; then
  DASHBOARD=$(oc get route -n redhat-ods-applications -o jsonpath='{.items[?(@.metadata.name=="data-science-gateway")].spec.host}' 2>/dev/null)
fi
echo "  https://${DASHBOARD}"
echo ""

# Hardware Profile
echo "4. Hardware Profiles:"
oc get hardwareprofile -n redhat-ods-applications
echo ""

# KServe
echo "5. KServe:"
oc get csv -n redhat-ods-applications 2>/dev/null | grep -i kserve || echo "  KServe managed by DSC"
echo ""

# Model (if deployed)
echo "6. Deployed Models:"
oc get inferenceservice -A 2>/dev/null || echo "  No models deployed yet"
echo ""

# OGX (new in 3.5)
echo "7. OGX Operator:"
oc get datasciencecluster default-dsc -o jsonpath='  ogx: {.spec.components.ogx.managementState}{"\n"}'
echo ""

# MCP Lifecycle Operator (new in 3.5)
echo "8. MCP Lifecycle Operator:"
oc get datasciencecluster default-dsc -o jsonpath='  mcplifecycleoperator: {.spec.components.mcplifecycleoperator.managementState}{"\n"}'
echo ""

echo "=== Path A Complete ==="
```

**Path A installation is complete.** Skip to [Observability (Optional)](#observability-optional)
or [Optional Components](#optional-components) for additional features.

---

# Path B: RHOAI With MaaS

This path deploys the full MaaS platform: authenticated API gateway, subscription-based
model access, token-based rate limiting, and the llm-d distributed inference runtime.

> **Important:** Complete Phases 1–2 (Sections 3–4) before starting Path B.

## 5B. MaaS Prerequisites

MaaS requires additional operators beyond the core set. Install them now.

### 5B.1 Red Hat Build of Kueue

Kueue manages workload scheduling and resource quotas.

```bash
oc apply -f lib/manifests/operators/kueue-subscription.yaml
```

Wait for the operator:

```bash
until oc get csv -n openshift-operators 2>/dev/null | grep -q "kueue.*Succeeded"; do
  echo "Waiting for Kueue operator..."
  sleep 10
done
echo "Kueue operator ready"
```

### 5B.2 Leader Worker Set (LWS)

LWS is required for llm-d distributed inference (multi-pod model serving).

```bash
oc create namespace openshift-lws-operator 2>/dev/null || true
oc apply -f lib/manifests/operators/lws-operatorgroup.yaml
oc apply -f lib/manifests/operators/lws-subscription.yaml
```

Wait for the operator:

```bash
until oc get csv -n openshift-lws-operator 2>/dev/null | grep -q "leader-worker-set.*Succeeded"; do
  echo "Waiting for LWS operator..."
  sleep 10
done
echo "LWS operator ready"
```

Create the LWS operator CR:

```bash
oc apply -f lib/manifests/operators/lws-operator-cr.yaml
```

### 5B.3 OpenShift Service Mesh 3.4

Service Mesh 3.4 (Sail/Istio) is required by RHCL 1.4.1+ for the API gateway.
The subscription uses `installPlanApproval: Manual`, so you must approve
InstallPlans after they are created.

> **Changed in 3.5:** Service Mesh **3.4** is now required (was 3.2+ in RHOAI 3.4).

```bash
oc apply -f lib/manifests/operators/servicemesh3-subscription.yaml
```

Wait for the InstallPlan and approve it:

```bash
echo "Waiting for Service Mesh InstallPlan..."
until oc get installplan -n openshift-operators -o json 2>/dev/null | \
  jq -e '[.items[] | select(.spec.approved == false)] | length > 0' &>/dev/null; do
  sleep 5
done

# Approve all pending Service Mesh / Kiali InstallPlans
for PLAN in $(oc get installplan -n openshift-operators --no-headers 2>/dev/null | awk '{print $1}'); do
  APPROVED=$(oc get installplan "$PLAN" -n openshift-operators -o jsonpath='{.spec.approved}')
  CSVS=$(oc get installplan "$PLAN" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}')
  if [ "$APPROVED" = "false" ] && echo "$CSVS" | grep -qiE "servicemesh|kiali|sail"; then
    echo "Approving InstallPlan: $PLAN ($CSVS)"
    oc patch installplan "$PLAN" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
  fi
done
```

Wait for the operator with periodic re-approval:

```bash
until oc get csv -n openshift-operators 2>/dev/null | grep -q "servicemeshoperator3.*Succeeded"; do
  echo "Waiting for Service Mesh 3 operator..."
  # Re-approve any new pending InstallPlans on each iteration
  for PLAN in $(oc get installplan -n openshift-operators --no-headers 2>/dev/null | awk '{print $1}'); do
    APPROVED=$(oc get installplan "$PLAN" -n openshift-operators -o jsonpath='{.spec.approved}')
    CSVS=$(oc get installplan "$PLAN" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}')
    if [ "$APPROVED" = "false" ] && echo "$CSVS" | grep -qiE "servicemesh|kiali|sail"; then
      oc patch installplan "$PLAN" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
    fi
  done
  sleep 10
done
echo "Service Mesh 3 operator ready"
```

### MaaS Prerequisites Checkpoint

```bash
echo "=== MaaS Prerequisites ==="
echo "Kueue:        $(oc get csv -n openshift-operators 2>/dev/null | grep kueue | awk '{print $NF}')"
echo "LWS:          $(oc get csv -n openshift-lws-operator 2>/dev/null | grep leader-worker-set | awk '{print $NF}')"
echo "Service Mesh: $(oc get csv -n openshift-operators 2>/dev/null | grep servicemeshoperator3 | awk '{print $NF}')"
```

All should show `Succeeded`.

## 6B. Red Hat Connectivity Link

RHCL provides Kuadrant (API management), Authorino (auth), Limitador (rate limiting),
and Gateway API integration. RHOAI 3.5 MaaS requires RHCL **v1.4.1+**.

> **Changed in 3.5:** RHCL now uses **Automatic** install plan approval on the
> `stable` channel. The 3.4 guide used Manual approval to avoid the broken 1.4.0
> release — that bug is fixed in 1.4.1+, so Automatic is now safe.

### 6B.1 Install the RHCL Operator

```bash
oc apply -f lib/manifests/rhcl/rhcl-operator-35.yaml
```

Wait for the operator. Since RHCL 1.4.1+ uses Automatic approval, no manual
InstallPlan approval is needed for the RHCL subscription itself. However,
Service Mesh (a dependency) still uses Manual approval — continue approving
those InstallPlans:

```bash
ELAPSED=0
until oc get csv -n openshift-operators 2>/dev/null | grep -q "rhcl-operator.*Succeeded"; do
  # Re-approve any pending Service Mesh / dependency InstallPlans
  for PLAN in $(oc get installplan -n openshift-operators --no-headers 2>/dev/null | awk '{print $1}'); do
    APPROVED=$(oc get installplan "$PLAN" -n openshift-operators -o jsonpath='{.spec.approved}' 2>/dev/null)
    CSVS=$(oc get installplan "$PLAN" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}' 2>/dev/null)
    if [ "$APPROVED" = "false" ] && echo "$CSVS" | grep -qiE "servicemesh|kiali|sail|authorino|limitador|dns-operator"; then
      echo "Approving dependency InstallPlan: $PLAN ($CSVS)"
      oc patch installplan "$PLAN" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
    fi
  done
  echo "Waiting for rhcl-operator... (${ELAPSED}s)"
  sleep 10
  ELAPSED=$((ELAPSED + 10))
  if [ $ELAPSED -ge 300 ]; then
    echo "WARNING: RHCL operator not ready after 300s"
    break
  fi
done
```

Verify RHCL component operators:

```bash
echo "=== RHCL Components ==="
for COMP in authorino dns limitador rhcl; do
  STATUS=$(oc get csv -n openshift-operators 2>/dev/null | grep -i "$COMP" | awk '{print $1, $NF}')
  echo "  $COMP: ${STATUS:-not found}"
done
```

### 6B.2 Create Kuadrant Instance

Kuadrant is the API management layer. Create it in the `kuadrant-system` namespace
as specified by the RHOAI 3.5 MaaS documentation.

```bash
oc create namespace kuadrant-system 2>/dev/null || true
oc apply -f lib/manifests/rhcl/kuadrant-instance.yaml
```

The Kuadrant instance has `observability.enable: true` for metrics collection.

### 6B.3 Set Up Istio

Kuadrant requires Istio for the gateway data plane.

```bash
oc create namespace istio-system 2>/dev/null || true
oc create namespace istio-cni 2>/dev/null || true
```

Determine the Istio version from the Sail operator:

```bash
export ISTIO_VERSION=$(oc get istio -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null || echo "v1.26.2")
echo "Istio version: $ISTIO_VERSION"
```

Create IstioCNI:

```bash
envsubst '${ISTIO_VERSION}' < lib/manifests/rhcl/istiocni.yaml | oc apply -f -
```

Wait for IstioCNI:

```bash
until oc get istiocni default -n istio-system \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; do
  echo "Waiting for IstioCNI..."
  sleep 10
done
echo "IstioCNI is ready"
```

Create the Istio instance:

```bash
envsubst '${ISTIO_VERSION}' < lib/manifests/rhcl/istio.yaml | oc apply -f -
```

Wait for Istio to be healthy:

```bash
until [ "$(oc get istio default -n istio-system -o jsonpath='{.status.state}' 2>/dev/null)" = "Healthy" ]; do
  echo "Waiting for Istio... State: $(oc get istio default -n istio-system -o jsonpath='{.status.state}' 2>/dev/null)"
  sleep 10
done
echo "Istio is healthy"
```

Create the default GatewayClass:

```bash
oc apply -f lib/manifests/rhcl/gatewayclass-default.yaml
```

Wait for the GatewayClass to be accepted:

```bash
oc wait --for=condition=Accepted gatewayclass/openshift-default --timeout=120s
```

### 6B.4 Restart Kuadrant to Detect Istio

After Istio is installed, restart the Kuadrant operator so it discovers the
Istio installation:

```bash
oc delete pod -n kuadrant-system -l app.kubernetes.io/name=kuadrant-operator 2>/dev/null || true
sleep 20
```

Wait for Kuadrant to be ready:

```bash
oc wait --for=condition=Ready kuadrant/kuadrant -n kuadrant-system --timeout=120s
```

If `oc wait` times out, poll manually:

```bash
until oc get kuadrant kuadrant -n kuadrant-system \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; do
  echo "Waiting for Kuadrant... Reason: $(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)"
  sleep 10
done
echo "Kuadrant is ready"
```

### RHCL Checkpoint

```bash
echo "=== RHCL Stack ==="
echo "RHCL Operator:  $(oc get csv -n openshift-operators 2>/dev/null | grep rhcl | awk '{print $NF}')"
echo "Istio:          $(oc get istio default -n istio-system -o jsonpath='{.status.state}' 2>/dev/null)"
echo "IstioCNI:       $(oc get istiocni default -n istio-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
echo "Kuadrant:       $(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
echo "GatewayClass:   $(oc get gatewayclass openshift-default -o jsonpath='{.metadata.name}' 2>/dev/null)"
```

## 7B. Authorino TLS

RHOAI 3.5 uses OpenShift service-ca for Authorino TLS (not cert-manager Certificate
as in 3.3). This is a multi-step process.

### 7B.1 Annotate Authorino Service for service-ca

Tell OpenShift's service-ca controller to generate a TLS certificate for Authorino:

```bash
oc annotate service authorino-authorino-authorization \
  -n kuadrant-system \
  service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
  --overwrite
```

### 7B.2 Wait for the TLS Secret

The service-ca operator will generate the `authorino-server-cert` secret:

```bash
until oc get secret authorino-server-cert -n kuadrant-system &>/dev/null; do
  echo "Waiting for service-ca to generate authorino-server-cert..."
  sleep 5
done
echo "authorino-server-cert secret generated"
```

### 7B.3 Patch Authorino CR for TLS Listener

Enable the TLS listener on the Authorino CR, pointing to the generated cert:

```bash
oc patch authorino authorino -n kuadrant-system --type=merge --patch '{
  "spec": {
    "listener": {
      "tls": {
        "enabled": true,
        "certSecretRef": {
          "name": "authorino-server-cert"
        }
      }
    }
  }
}'
```

Alternatively, you can apply the full Authorino TLS manifest:

```bash
oc apply -f lib/manifests/rhcl/authorino-tls.yaml
```

### 7B.4 Configure TLS Certificate Validation

Set environment variables on the Authorino deployment so it trusts the
OpenShift service-ca bundle:

```bash
oc -n kuadrant-system set env deployment/authorino \
  SSL_CERT_FILE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt \
  REQUESTS_CA_BUNDLE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt
```

Wait for Authorino to be available after the rollout:

```bash
oc wait --for=condition=Available deployment/authorino \
  -n kuadrant-system --timeout=300s
```

### 7B.5 Verify Authorino TLS

```bash
echo "=== Authorino TLS ==="
echo "Service annotation: $(oc get service authorino-authorino-authorization -n kuadrant-system \
  -o jsonpath='{.metadata.annotations.service\.beta\.openshift\.io/serving-cert-secret-name}' 2>/dev/null)"
echo "TLS secret exists:  $(oc get secret authorino-server-cert -n kuadrant-system &>/dev/null && echo 'yes' || echo 'no')"
echo "TLS listener:       $(oc get authorino authorino -n kuadrant-system \
  -o jsonpath='{.spec.listener.tls.enabled}' 2>/dev/null)"
echo "Authorino ready:    $(oc get deployment authorino -n kuadrant-system \
  -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)"
```

Expected output:

```
Service annotation: authorino-server-cert
TLS secret exists:  yes
TLS listener:       true
Authorino ready:    True
```

## 8B. Gateway Setup

The MaaS gateway is the entry point for all model API requests. It requires
specific annotations, a resource ConfigMap to prevent OOMKill, and a TLS secret.

### 8B.1 Create GatewayClasses

```bash
oc apply -f lib/manifests/rhcl/gatewayclass-gateway-controller.yaml
oc apply -f lib/manifests/rhcl/gatewayclass-ai-inference.yaml
```

**Verify:**

```bash
oc get gatewayclass
```

Expected: `openshift-default`, `openshift-gateway-controller`, `openshift-ai-inference`

### 8B.2 Apply Gateway Resource Overrides

The gateway proxy needs 2Gi memory to handle WASM plugin compilation
(Authorino auth + Limitador rate limiting). Without this, the proxy OOMKills.

```bash
oc apply -f lib/manifests/rhcl/gateway-resources.yaml
```

This creates a ConfigMap `maas-gateway-options` in `openshift-ingress`:

```bash
oc get configmap maas-gateway-options -n openshift-ingress -o yaml
```

### 8B.3 Create the MaaS Gateway

The gateway template requires two variables: the cluster domain and the TLS
secret name.

```bash
export CLUSTER_DOMAIN
export CERT_NAME="default-gateway-tls"

envsubst '${CLUSTER_DOMAIN} ${CERT_NAME}' \
  < lib/manifests/rhcl/gateway-maas.yaml | oc apply -f -
```

> **Key annotations on the gateway:**
> - `opendatahub.io/managed: "false"` — Lets the MaaS controller manage auth policies
> - `security.opendatahub.io/authorino-tls-bootstrap: "true"` — Enables TLS to Authorino
>
> The gateway also references `maas-gateway-options` via `spec.infrastructure.parametersRef`
> for the 2Gi memory limit.

Wait for the gateway to be programmed:

```bash
oc wait --for=condition=Programmed gateway/maas-default-gateway \
  -n openshift-ingress --timeout=120s
```

### 8B.4 Create the Inference Gateway (Optional)

For direct model access outside MaaS governance:

```bash
envsubst '${CLUSTER_DOMAIN} ${CERT_NAME}' \
  < lib/manifests/rhcl/gateway-inference.yaml | oc apply -f -
```

### 8B.5 Create Gateway TLS Secret

The gateways need a TLS secret for HTTPS listeners. Choose one of these strategies:

**Strategy 1: cert-manager Certificate (if ClusterIssuer exists)**

```bash
ISSUER_NAME=$(oc get clusterissuers -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$ISSUER_NAME" ]; then
  export ISSUER_NAME
  envsubst '${CLUSTER_DOMAIN} ${ISSUER_NAME}' \
    < lib/manifests/rhcl/gateway-tls-certificate.yaml | oc apply -f -

  # Wait for cert-manager to create the secret
  until oc get secret default-gateway-tls -n openshift-ingress &>/dev/null; do
    echo "Waiting for cert-manager to generate TLS secret..."
    sleep 5
  done
  echo "TLS secret created by cert-manager"
fi
```

**Strategy 2: Copy from existing wildcard certificate**

```bash
# Check for existing wildcard certs in openshift-ingress
oc get secrets -n openshift-ingress | grep tls

# Copy from router-certs-default (if it has a valid wildcard cert)
oc get secret router-certs-default -n openshift-ingress \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/tls.crt
oc get secret router-certs-default -n openshift-ingress \
  -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/tls.key

oc create secret tls default-gateway-tls \
  --cert=/tmp/tls.crt --key=/tmp/tls.key \
  -n openshift-ingress
rm /tmp/tls.crt /tmp/tls.key
```

**Strategy 3: Self-signed from OpenShift router-ca**

```bash
# Extract router CA
oc get secret router-ca -n openshift-ingress-operator \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ca.crt
oc get secret router-ca -n openshift-ingress-operator \
  -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/ca.key

# Generate wildcard cert signed by router CA
openssl req -new -newkey rsa:2048 -nodes \
  -keyout /tmp/tls.key -out /tmp/tls.csr \
  -subj "/CN=*.apps.${CLUSTER_DOMAIN}" \
  -addext "subjectAltName=DNS:*.apps.${CLUSTER_DOMAIN},DNS:apps.${CLUSTER_DOMAIN}"

openssl x509 -req -in /tmp/tls.csr \
  -CA /tmp/ca.crt -CAkey /tmp/ca.key -CAcreateserial \
  -out /tmp/tls.crt -days 365 \
  -extfile <(printf "subjectAltName=DNS:*.apps.${CLUSTER_DOMAIN},DNS:apps.${CLUSTER_DOMAIN}")

oc create secret tls default-gateway-tls \
  --cert=/tmp/tls.crt --key=/tmp/tls.key \
  -n openshift-ingress
rm /tmp/ca.crt /tmp/ca.key /tmp/tls.crt /tmp/tls.key /tmp/tls.csr /tmp/ca.srl
```

### 8B.6 Annotate Gateway for Authorino TLS

```bash
oc annotate gateway maas-default-gateway \
  -n openshift-ingress \
  security.opendatahub.io/authorino-tls-bootstrap="true" \
  --overwrite
```

### 8B.7 Create Passthrough Routes

The `*.apps.<cluster>` wildcard DNS points to the default OpenShift Router,
but gateway pods get their own LoadBalancer service. Passthrough Routes bridge
the two.

Find the gateway service name:

```bash
MAAS_SVC=$(oc get svc -n openshift-ingress \
  -l gateway.networking.k8s.io/gateway-name=maas-default-gateway \
  -o jsonpath='{.items[0].metadata.name}')
echo "MaaS gateway service: $MAAS_SVC"
```

Create the passthrough route:

```bash
export ROUTE_NAME="maas-default-gateway-passthrough"
export HOSTNAME="maas.apps.${CLUSTER_DOMAIN}"
export SERVICE_NAME="$MAAS_SVC"

envsubst '${ROUTE_NAME} ${HOSTNAME} ${SERVICE_NAME}' \
  < lib/manifests/rhcl/gateway-passthrough-route.yaml | oc apply -f -
```

If you also created the inference gateway:

```bash
INFERENCE_SVC=$(oc get svc -n openshift-ingress \
  -l gateway.networking.k8s.io/gateway-name=openshift-ai-inference \
  -o jsonpath='{.items[0].metadata.name}')

export ROUTE_NAME="openshift-ai-inference-passthrough"
export HOSTNAME="inference-gateway.apps.${CLUSTER_DOMAIN}"
export SERVICE_NAME="$INFERENCE_SVC"

envsubst '${ROUTE_NAME} ${HOSTNAME} ${SERVICE_NAME}' \
  < lib/manifests/rhcl/gateway-passthrough-route.yaml | oc apply -f -
```

### Gateway Checkpoint

```bash
echo "=== Gateway Setup ==="
echo "GatewayClasses:"
oc get gatewayclass --no-headers 2>/dev/null | sed 's/^/  /'
echo ""
echo "Gateways:"
oc get gateway -n openshift-ingress --no-headers 2>/dev/null | sed 's/^/  /'
echo ""
echo "Routes:"
oc get route -n openshift-ingress --no-headers 2>/dev/null | sed 's/^/  /'
echo ""
echo "TLS Secret:"
oc get secret default-gateway-tls -n openshift-ingress --no-headers 2>/dev/null | sed 's/^/  /'
echo ""
echo "Resource ConfigMap:"
oc get configmap maas-gateway-options -n openshift-ingress --no-headers 2>/dev/null | sed 's/^/  /'
```

## 9B. DataScienceCluster (MaaS)

Create the DataScienceCluster with MaaS enabled. This uses the full manifest
from the toolkit.

```bash
oc apply -f lib/manifests/rhoai/datasciencecluster-v3-35.yaml
```

> **Key difference from Path A:** This manifest sets `aigateway.modelsAsAService: Managed`
> (note: `modelsAsAService` with "AsA", not "As"), enabling the ai-gateway-operator,
> MaaS controller, MaaS CRDs, and `MaasTenantConfig` auto-creation in the
> `models-as-a-service` namespace. The deprecated `kserve.modelsAsService` field is
> no longer used (though still accepted through 3.6 with a warning).
>
> **Key differences from RHOAI 3.4 DSC:**
> - `llamastackoperator` → `ogx` (OGX Operator replaces Llama Stack)
> - New component: `mcplifecycleoperator: Managed` (MCP Lifecycle Operator)
> - API version remains `datasciencecluster.opendatahub.io/v2`

Wait for core components to be ready. RHOAI 3.5 adds the `AIGatewayReady`
condition — wait for it in addition to `DashboardReady` and `KserveReady`:

```bash
echo "Waiting for DataScienceCluster..."

# Wait for Dashboard
oc wait --for=jsonpath='{.status.conditions[?(@.type=="DashboardReady")].status}'=True \
  datasciencecluster/default-dsc --timeout=300s
echo "DashboardReady: True"

# Wait for KServe
oc wait --for=jsonpath='{.status.conditions[?(@.type=="KserveReady")].status}'=True \
  datasciencecluster/default-dsc --timeout=300s
echo "KserveReady: True"

# Wait for Model Controller (new in 3.5)
oc wait --for=jsonpath='{.status.conditions[?(@.type=="AIGatewayReady")].status}'=True \
  datasciencecluster/default-dsc --timeout=300s
echo "AIGatewayReady: True"
```

> **Note:** The `ModelsAsAServiceReady` condition will initially be `False`. This is
> expected — it stays `False` until the gateway, database, and TLS are all configured.
> The condition's `message` field tells you exactly what is missing:
> ```bash
> oc get datasciencecluster default-dsc \
>   -o jsonpath='{.status.conditions[?(@.type=="ModelsAsAServiceReady")].message}'
> ```

**Verify:**

```bash
oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}'
```

## 10B. PostgreSQL and MaaS Database

MaaS requires PostgreSQL 14+ for API key validation and subscription management.
The `maas-db-config` secret must exist before the MaaS controller can fully
reconcile.

> **Changed in 3.5:** MaaS infrastructure workloads now live in the
> `redhat-ai-gateway-infra` namespace instead of `redhat-ods-applications`.
> This includes the `maas-db-config` secret, `maas-api` deployment,
> `maas-controller` deployment, and the POC PostgreSQL deployment.
>
> To discover the actual infrastructure namespace:
> ```bash
> oc get maastenantconfig default-tenant -n models-as-a-service \
>   -o jsonpath='{.status.infraNamespace}'
> # Expected: redhat-ai-gateway-infra
> ```

> **Production note:** For production deployments, use AWS RDS, Crunchy Postgres
> Operator, or Azure Database for PostgreSQL instead of the POC deployment below.

### 10B.1 Create the Infrastructure Namespace

The `redhat-ai-gateway-infra` namespace should be auto-created by the MaaS
controller when the DSC is applied. Verify it exists, or create it:

```bash
oc create namespace redhat-ai-gateway-infra 2>/dev/null || true
```

### 10B.2 Generate Database Credentials

```bash
PG_USER="maas"
PG_DB="maas"
PG_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
echo "Generated PostgreSQL password (save this): $PG_PASSWORD"
```

### 10B.3 Resolve PostgreSQL Image

Use the image pinned in the RHOAI operator CSV when available:

```bash
PG_IMAGE=$(oc get csv -l 'olm.copiedFrom=redhat-ods-operator' \
  -o jsonpath='{.items[0].spec.relatedImages[?(@.name=="postgresql_16_image")].image}' 2>/dev/null)

if [ -z "$PG_IMAGE" ]; then
  PG_IMAGE="registry.redhat.io/rhel9/postgresql-16:latest"
  echo "Using default PostgreSQL image"
else
  echo "Using operator-pinned PostgreSQL image"
fi
echo "PG_IMAGE: $PG_IMAGE"
```

### 10B.4 Deploy PostgreSQL

Deploy PostgreSQL in the `redhat-ai-gateway-infra` namespace:

```bash
oc apply -n redhat-ai-gateway-infra -f lib/manifests/maas/postgres-pvc.yaml
oc apply -n redhat-ai-gateway-infra -f lib/manifests/maas/postgres-service.yaml

export PG_IMAGE PG_USER PG_PASSWORD PG_DB
envsubst '${PG_IMAGE} ${PG_USER} ${PG_PASSWORD} ${PG_DB}' \
  < lib/manifests/maas/postgres-deployment.yaml | oc apply -n redhat-ai-gateway-infra -f -
```

Wait for PostgreSQL:

```bash
oc rollout status deployment/postgres -n redhat-ai-gateway-infra --timeout=120s
```

### 10B.5 Create Database Secrets

Store the raw credentials for reference:

```bash
oc create secret generic postgres-creds \
  --from-literal=user="$PG_USER" \
  --from-literal=password="$PG_PASSWORD" \
  --from-literal=database="$PG_DB" \
  -n redhat-ai-gateway-infra --dry-run=client -o yaml | \
  oc apply -n redhat-ai-gateway-infra -f -
```

Create the `maas-db-config` secret that the MaaS controller reads.
The password must be URL-encoded:

```bash
ENCODED_PASSWORD=$(printf '%s' "$PG_PASSWORD" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
DB_URL="postgresql://${PG_USER}:${ENCODED_PASSWORD}@postgres.redhat-ai-gateway-infra.svc:5432/${PG_DB}?sslmode=disable"

printf '%s' "$DB_URL" | \
  oc create secret generic maas-db-config \
    --from-file=DB_CONNECTION_URL=/dev/stdin \
    --dry-run=client -o yaml | \
  oc label --local -f - app=maas-api --dry-run=client -o yaml | \
  oc apply -n redhat-ai-gateway-infra -f -
```

> **Important:** The PostgreSQL service hostname uses the fully qualified name
> `postgres.redhat-ai-gateway-infra.svc` since the `maas-api` and PostgreSQL
> are now co-located in the same `redhat-ai-gateway-infra` namespace. If using
> a short hostname `postgres`, that works too since they share a namespace.

> **For external PostgreSQL:** If using an external database, skip the deployment
> steps and create only the `maas-db-config` secret:
> ```bash
> printf 'postgresql://user:pass@host:5432/db?sslmode=require' | \
>   oc create secret generic maas-db-config \
>     --from-file=DB_CONNECTION_URL=/dev/stdin \
>     -n redhat-ai-gateway-infra
> ```

### 10B.6 Restart MaaS API to Pick Up Database

After creating the `maas-db-config` secret, restart the `maas-api` deployment
in the infra namespace so it picks up the new database configuration:

```bash
oc rollout restart deployment/maas-api -n redhat-ai-gateway-infra 2>/dev/null || true
```

> **Note:** If `maas-api` hasn't been deployed yet (it's deployed by the MaaS
> controller after the DSC reconciles), this command will produce a "not found"
> error, which is harmless. The controller will pick up the secret on its next
> reconciliation cycle.

### 10B.7 Clean Up Environment

```bash
unset PG_PASSWORD ENCODED_PASSWORD DB_URL
```

### PostgreSQL Checkpoint

```bash
echo "=== PostgreSQL ==="
echo "PVC:            $(oc get pvc postgres-data -n redhat-ai-gateway-infra -o jsonpath='{.status.phase}' 2>/dev/null)"
echo "Deployment:     $(oc rollout status deployment/postgres -n redhat-ai-gateway-infra --timeout=5s 2>&1 | tail -1)"
echo "maas-db-config: $(oc get secret maas-db-config -n redhat-ai-gateway-infra &>/dev/null && echo 'exists' || echo 'MISSING')"
echo "postgres-creds: $(oc get secret postgres-creds -n redhat-ai-gateway-infra &>/dev/null && echo 'exists' || echo 'MISSING')"
```

## 11B. Dashboard Features (MaaS)

Enable the MaaS-specific dashboard flags. These control visibility of MaaS
features in the RHOAI dashboard.

```bash
# Wait for dashboard config to exist
until oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; do
  echo "Waiting for dashboard config..."
  sleep 5
done

oc patch odhdashboardconfig odh-dashboard-config \
  -n redhat-ods-applications --type=merge -p '{
    "spec": {
      "dashboardConfig": {
        "disableModelRegistry": false,
        "disableModelCatalog": false,
        "disableKServeMetrics": false,
        "genAiStudio": true,
        "modelAsService": true,
        "vLLMDeploymentOnMaaS": true,
        "roleManagement": true,
        "disableLMEval": false
      }
    }
  }'
```

**Dashboard flags explained:**

| Flag | Purpose | Status |
|------|---------|--------|
| `modelAsService` | Core MaaS functionality | Required (GA) |
| `genAiStudio` | MaaS user-facing features | Required (GA) |
| ~~`maasAuthPolicies`~~ | ~~MaaS admin features~~ | **REMOVED in 3.5** — CEL validation rejects; baked into MaaS GA |
| `roleManagement` | Custom RBAC role creation UI | Enabled by default in 3.5 |
| `vLLMDeploymentOnMaaS` | "Publish as MaaS" in deploy wizard | Technology Preview |
| `disableLMEval` | Enable LM evaluation | false = enabled |
| `disableModelRegistry` | Enable Model Registry | false = enabled |

> **New in 3.5:** `roleManagement` is enabled by default and provides a custom
> RBAC role creation UI in the RHOAI dashboard.

> **Technology Preview: Observability Dashboard**
> To enable the MaaS observability dashboard, also add:
> ```bash
> oc patch odhdashboardconfig odh-dashboard-config \
>   -n redhat-ods-applications --type=merge -p '{
>     "spec": {
>       "dashboardConfig": {
>         "observabilityDashboard": true
>       }
>     }
>   }'
> ```
> This requires the Cluster Observability Operator (COO). See
> [Observability (Optional)](#observability-optional).

> **Technology Preview: Additional 3.5 Flags**
> These flags are new in 3.5 but remain Technology Preview:
> ```bash
> oc patch odhdashboardconfig odh-dashboard-config \
>   -n redhat-ods-applications --type=merge -p '{
>     "spec": {
>       "dashboardConfig": {
>         "mcpCatalog": true,
>         "llmdTemplates": true,
>         "externalModels": true
>       }
>     }
>   }'
> ```
> - `mcpCatalog` — MCP server catalog management
> - `llmdTemplates` — Topology selector wizard for LLMInferenceService
> - `externalModels` — External model endpoint configuration

**Verify:**

```bash
oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
  -o jsonpath='{.spec.dashboardConfig}' | jq '{modelAsService, genAiStudio, vLLMDeploymentOnMaaS, roleManagement, mcpCatalog}'
```

Expected:

```json
{
  "modelAsService": true,
  "genAiStudio": true,
  "vLLMDeploymentOnMaaS": true,
  "roleManagement": true,
  "mcpCatalog": true
}
```

## 12B. Verify MaaS Platform

Run a comprehensive verification of the MaaS platform before deploying models.

### 12B.1 MaaS CRDs

MaaS CRDs should be installed — RHOAI 3.5 adds new CRDs beyond the 3.4 set:

```bash
echo "=== MaaS CRDs ==="
oc get crd | grep -E "maas.opendatahub.io|tokenratelimitpolicies"
echo ""
MAAS_CRD_COUNT=$(oc get crd 2>/dev/null | grep -c "maas.opendatahub.io")
echo "Found MaaS CRDs: $MAAS_CRD_COUNT (expected: 5+)"
```

Expected CRDs:

- `maasauthpolicies.maas.opendatahub.io`
- `maasmodelrefs.maas.opendatahub.io`
- `maassubscriptions.maas.opendatahub.io`
- `tenants.maas.opendatahub.io`
- `externalmodels.maas.opendatahub.io`
- `maastenantconfigs.maas.opendatahub.io` (new in 3.5)
- `aitenants.maas.opendatahub.io` (new in 3.5, multi-tenancy TP)

Additionally, verify the `TokenRateLimitPolicy` CRD from Kuadrant:

```bash
oc get crd tokenratelimitpolicies.kuadrant.io
```

### 12B.2 MaasTenantConfig

The MaaS controller auto-creates a `MaasTenantConfig` in the `models-as-a-service`
namespace. This is a new resource in 3.5 that configures the tenant infrastructure:

```bash
oc get maastenantconfig default-tenant -n models-as-a-service
```

Verify the infrastructure namespace it points to:

```bash
oc get maastenantconfig default-tenant -n models-as-a-service \
  -o jsonpath='{.status.infraNamespace}'
# Expected: redhat-ai-gateway-infra
```

> **Note:** The `MaasTenantConfig` must exist before `MaaSSubscription` or
> `MaaSAuthPolicy` resources can be created (admission webhook dependency).

### 12B.3 MaaS Controller

Verify the `maas-controller` is running in the infrastructure namespace:

```bash
oc get deployment maas-controller -n redhat-ai-gateway-infra
oc get pods -n redhat-ai-gateway-infra -l app=maas-controller
```

### 12B.4 Auto-Created Gateway Policies

In RHOAI 3.5, the `maas-controller` automatically creates gateway-level policies.
No manual rate-limit or EnvoyFilter setup is required.

```bash
echo "=== Auto-Created Gateway Policies ==="

# AuthPolicy — denies unauthenticated traffic
echo "maas-gateway-auth (AuthPolicy):"
oc get authpolicy maas-gateway-auth -n openshift-ingress 2>/dev/null && echo "  Found" || echo "  NOT FOUND (may still be creating)"

# TokenRateLimitPolicy — denies unsubscribed traffic
echo "gateway-default-deny (TokenRateLimitPolicy):"
oc get tokenratelimitpolicy gateway-default-deny -n openshift-ingress 2>/dev/null && echo "  Found" || echo "  NOT FOUND (may still be creating)"

# MaaS API auth policy — protects the MaaS API endpoint
echo "maas-api-auth-policy (AuthPolicy):"
oc get authpolicy maas-api-auth-policy -n redhat-ai-gateway-infra 2>/dev/null && echo "  Found" || echo "  NOT FOUND (may still be creating)"
```

> **Note:** These policies are created automatically by the `maas-controller`.
> If they don't appear immediately, wait a few minutes for the controller to
> finish bootstrapping. Manual rate-limit/EnvoyFilter configuration from
> RHOAI 3.4 scripts may **conflict** — remove any manual rate-limit setup.

### 12B.5 Tenant

The MaaS controller also auto-creates a `default-tenant` in the
`models-as-a-service` namespace:

```bash
oc get tenant default-tenant -n models-as-a-service
oc get tenant default-tenant -n models-as-a-service \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

> **Note:** The Tenant will show `Ready: True` only after the `maas-db-config`
> secret exists in `redhat-ai-gateway-infra`. If it shows `Degraded`, verify
> the database secret.

### 12B.6 ModelsAsAServiceReady Condition

Check the `ModelsAsAServiceReady` condition on the DSC. This condition stays
`False` until all three prerequisites are met:
1. `maas-default-gateway` exists and is Programmed
2. `maas-db-config` secret exists in the infrastructure namespace
3. Authorino TLS is configured

```bash
echo "=== ModelsAsAServiceReady ==="
echo "Status: $(oc get datasciencecluster default-dsc \
  -o jsonpath='{.status.conditions[?(@.type=="ModelsAsAServiceReady")].status}' 2>/dev/null)"
echo "Message: $(oc get datasciencecluster default-dsc \
  -o jsonpath='{.status.conditions[?(@.type=="ModelsAsAServiceReady")].message}' 2>/dev/null)"
```

If `ModelsAsAServiceReady` is `False`, the message will tell you exactly what is
missing. Address each issue and the condition will transition to `True`.

### 12B.7 Gateway Annotations

```bash
echo "=== Gateway Annotations ==="
echo "opendatahub.io/managed: $(oc get gateway maas-default-gateway -n openshift-ingress \
  -o jsonpath='{.metadata.annotations.opendatahub\.io/managed}' 2>/dev/null)"
echo "authorino-tls-bootstrap: $(oc get gateway maas-default-gateway -n openshift-ingress \
  -o jsonpath='{.metadata.annotations.security\.opendatahub\.io/authorino-tls-bootstrap}' 2>/dev/null)"
```

Expected: `false` and `true` respectively.

### 12B.8 Authorino TLS

```bash
echo "=== Authorino TLS ==="
echo "TLS enabled:    $(oc get authorino authorino -n kuadrant-system -o jsonpath='{.spec.listener.tls.enabled}' 2>/dev/null)"
echo "Cert secret:    $(oc get secret authorino-server-cert -n kuadrant-system &>/dev/null && echo 'exists' || echo 'MISSING')"
```

### 12B.9 Health Endpoint

```bash
echo "=== MaaS Health ==="
HEALTH=$(curl -sk "https://maas.apps.${CLUSTER_DOMAIN}/maas-api/health" 2>/dev/null)
echo "Response: $HEALTH"
```

Expected: `{"status":"healthy"}` or similar. If the endpoint is not reachable,
the MaaS API pods may still be starting.

### 12B.10 Full Platform Status

```bash
echo "============================================================"
echo "  MaaS Platform Status Summary (RHOAI 3.5)"
echo "============================================================"
echo ""
echo "Operators:"
echo "  RHOAI:        $(oc get csv -n redhat-ods-operator 2>/dev/null | grep rhods | awk '{print $NF}')"
echo "  RHCL:         $(oc get csv -n openshift-operators 2>/dev/null | grep rhcl | awk '{print $NF}')"
echo "  Service Mesh: $(oc get csv -n openshift-operators 2>/dev/null | grep servicemesh | awk '{print $NF}')"
echo "  Kueue:        $(oc get csv -n openshift-operators 2>/dev/null | grep kueue | awk '{print $NF}')"
echo "  LWS:          $(oc get csv -n openshift-lws-operator 2>/dev/null | grep leader-worker | awk '{print $NF}')"
echo ""
echo "Infrastructure:"
echo "  Istio:        $(oc get istio default -n istio-system -o jsonpath='{.status.state}' 2>/dev/null)"
echo "  Kuadrant:     $(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
echo "  Authorino TLS: $(oc get authorino authorino -n kuadrant-system -o jsonpath='{.spec.listener.tls.enabled}' 2>/dev/null)"
echo ""
echo "MaaS (RHOAI 3.5):"
echo "  DSC Phase:              $(oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}' 2>/dev/null)"
echo "  AIGatewayReady:   $(oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[?(@.type=="AIGatewayReady")].status}' 2>/dev/null)"
echo "  ModelsAsAServiceReady:   $(oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[?(@.type=="ModelsAsAServiceReady")].status}' 2>/dev/null)"
echo "  MaaS CRDs:              $(oc get crd 2>/dev/null | grep -c maas.opendatahub.io)/5+"
echo "  MaasTenantConfig:       $(oc get maastenantconfig default-tenant -n models-as-a-service &>/dev/null && echo 'exists' || echo 'MISSING')"
echo "  Infra Namespace:        $(oc get maastenantconfig default-tenant -n models-as-a-service -o jsonpath='{.status.infraNamespace}' 2>/dev/null || echo 'unknown')"
echo "  Tenant:                 $(oc get tenant default-tenant -n models-as-a-service -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
echo "  DB Config:              $(oc get secret maas-db-config -n redhat-ai-gateway-infra &>/dev/null && echo 'exists' || echo 'MISSING')"
echo "  maas-controller:        $(oc get deployment maas-controller -n redhat-ai-gateway-infra -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo '0') replica(s)"
echo "  Gateway:                $(oc get gateway maas-default-gateway -n openshift-ingress &>/dev/null && echo 'exists' || echo 'MISSING')"
echo "  maas-gateway-auth:   $(oc get authpolicy maas-gateway-auth -n openshift-ingress &>/dev/null && echo 'exists' || echo 'MISSING')"
echo "  gateway-default-deny:   $(oc get tokenratelimitpolicy gateway-default-deny -n openshift-ingress &>/dev/null && echo 'exists' || echo 'MISSING')"
echo ""
echo "Endpoints:"
echo "  Dashboard:    https://$(oc get route -n redhat-ods-applications -o jsonpath='{.items[0].spec.host}' 2>/dev/null)"
echo "  MaaS API:     https://maas.apps.${CLUSTER_DOMAIN}"
echo "  Inference:    https://inference-gateway.apps.${CLUSTER_DOMAIN}"
echo "============================================================"
```

## 13B. Deploy Model (llm-d and MaaS CRs)

This section deploys a CPU-only simulator model for platform validation.
The simulator requires no GPU and starts in ~30 seconds.

### 13B.1 Create Model Namespace

```bash
export MODEL_NAMESPACE="simulator-ns"
oc new-project "$MODEL_NAMESPACE" 2>/dev/null || oc project "$MODEL_NAMESPACE"
```

### 13B.2 Deploy the LLMInferenceService

The simulator uses the `llm-d-inference-sim` container:

```bash
envsubst '${MODEL_NAMESPACE}' \
  < lib/manifests/maas/simulator/llminferenceservice.yaml | oc apply -f -
```

Wait for the model to be ready:

```bash
echo "Waiting for simulator model..."
until oc get llminferenceservice simulator -n "$MODEL_NAMESPACE" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; do
  echo "  Status: $(oc get llminferenceservice simulator -n "$MODEL_NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)"
  sleep 10
done
echo "Simulator model is ready"
```

### 13B.3 Register with MaaS (MaaSModelRef)

The MaaSModelRef links the LLMInferenceService to the MaaS control plane:

```bash
envsubst '${MODEL_NAMESPACE}' \
  < lib/manifests/maas/simulator/maas-model-ref.yaml | oc apply -f -
```

### 13B.4 Create Authorization Policy (MaaSAuthPolicy)

Grant all authenticated users access to the simulator:

```bash
envsubst '${MODEL_NAMESPACE}' \
  < lib/manifests/maas/simulator/maas-auth-policy.yaml | oc apply -f -
```

> **Note:** The admission webhook requires a `MaasTenantConfig` CR to exist
> before `MaaSAuthPolicy` or `MaaSSubscription` can be created. If you get
> admission errors, wait for the `maas-controller` to finish bootstrapping
> the `MaasTenantConfig`.

### 13B.5 Create Subscriptions (MaaSSubscription)

Subscriptions define rate limits per group of users. Create a free tier
(100 tokens/min) and a premium tier (100,000 tokens/min):

```bash
# Free tier (100 tokens/min)
envsubst '${MODEL_NAMESPACE}' \
  < lib/manifests/maas/simulator/maas-subscription-free.yaml | oc apply -f -

# Premium tier (100,000 tokens/min)
envsubst '${MODEL_NAMESPACE}' \
  < lib/manifests/maas/simulator/maas-subscription-premium.yaml | oc apply -f -
```

### 13B.6 Verify Model Registration

```bash
echo "=== MaaS Model ==="
echo "LLMInferenceService:"
oc get llminferenceservice -n "$MODEL_NAMESPACE"
echo ""
echo "MaaSModelRef:"
oc get maasmodelref -n "$MODEL_NAMESPACE"
echo ""
echo "MaaSAuthPolicy:"
oc get maasauthpolicy -n models-as-a-service
echo ""
echo "MaaSSubscription:"
oc get maassubscription -n models-as-a-service
```

### 13B.7 Deploying GPU Models with llm-d

For production GPU models, create an `LLMInferenceService` that references
your model storage and requests GPU resources. Example for a Granite model:

```bash
cat <<EOF | oc apply -f -
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: granite-8b
  namespace: my-models
spec:
  modelSpec:
    url: oci://quay.io/modh/granite-3.3-8b-instruct:latest
    accelerator:
      count: 1
      productName: NVIDIA-L40S
EOF
```

Then register it with MaaS:

```bash
cat <<EOF | oc apply -f -
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSModelRef
metadata:
  name: granite-8b
  namespace: my-models
spec:
  llmInferenceServiceRef:
    name: granite-8b
---
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSAuthPolicy
metadata:
  name: granite-8b-access
  namespace: models-as-a-service
spec:
  modelRef:
    name: granite-8b
    namespace: my-models
  subjects:
    - kind: Group
      name: system:authenticated
---
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSSubscription
metadata:
  name: granite-8b-standard
  namespace: models-as-a-service
spec:
  modelRef:
    name: granite-8b
    namespace: my-models
  priority: 10
  subjects:
    - kind: Group
      name: system:authenticated
  tokenRateLimits:
    - limit: 10000
      window: 1m
EOF
```

> **llm-d Flow Control (New in 3.5 — Breaking Change from 3.4 TP):**
> If you configured flow control during the 3.4 Technology Preview, you must
> update your resources:
> - API group: `inference.networking.x-k8s.io` → `llm-d.ai`
> - Metrics prefix: `inference_extension_` → `llm_d_epp_`
> - `saturationDetector` moved to `flowControl.saturationDetector`
> - `InferenceObjective` API: `inference.networking.x-k8s.io/v1alpha1` → `llm-d.ai/v1alpha2`

## 14B. End-to-End Verification

This section verifies the complete MaaS pipeline: API key generation, inference,
authentication rejection, and rate limiting.

### 14B.1 Generate an API Key

Log into the RHOAI dashboard and navigate to Settings > API Keys, or use the
MaaS API directly:

```bash
# First, get the MaaS API token for your user
# (requires login as a real user, not kube:admin)
# The dashboard generates keys with the sk-oai- prefix
```

For testing with the simulator, you can use a service account token:

```bash
SA_TOKEN=$(oc create token default -n "$MODEL_NAMESPACE" --duration=1h 2>/dev/null)
```

### 14B.2 Test Inference via Gateway

```bash
MAAS_ENDPOINT="https://maas.apps.${CLUSTER_DOMAIN}"

# Health check
curl -sk "${MAAS_ENDPOINT}/maas-api/health"
echo ""

# Inference (using service account token for testing)
curl -sk "${MAAS_ENDPOINT}/v1/chat/completions" \
  -H "Authorization: Bearer ${SA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "simulator",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 50
  }'
```

> **New in 3.5:** MaaS supports body-based model routing to `/v1/chat/completions`.
> The `model` field in the request body determines which backend model serves
> the request — this is the OpenAI-compatible routing pattern.

### 14B.3 Test Authentication Rejection

Requests without valid credentials should be rejected:

```bash
# No auth header — should get 401 or 403
curl -sk -o /dev/null -w "HTTP Status: %{http_code}\n" \
  "${MAAS_ENDPOINT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model": "simulator", "messages": [{"role": "user", "content": "test"}]}'
```

Expected: HTTP 401 or 403.

### 14B.4 Test Rate Limiting

With the free tier subscription (100 tokens/min), rapid requests should
eventually trigger rate limiting:

```bash
echo "Sending rapid requests to test rate limiting..."
for i in $(seq 1 20); do
  STATUS=$(curl -sk -o /dev/null -w "%{http_code}" \
    "${MAAS_ENDPOINT}/v1/chat/completions" \
    -H "Authorization: Bearer ${SA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"model": "simulator", "messages": [{"role": "user", "content": "Generate a long response"}], "max_tokens": 100}')
  echo "  Request $i: HTTP $STATUS"
  if [ "$STATUS" = "429" ]; then
    echo "  Rate limit triggered at request $i"
    break
  fi
done
```

HTTP 429 indicates rate limiting is working. Rate limiting in 3.5 uses
`TokenRateLimitPolicy` (replacing `RateLimitPolicy` from 3.4).

### 14B.5 Verification Summary

```bash
echo "============================================================"
echo "  End-to-End Verification Complete (RHOAI 3.5)"
echo "============================================================"
echo ""
echo "MaaS Endpoint: https://maas.apps.${CLUSTER_DOMAIN}"
echo "Health:        $(curl -sk "https://maas.apps.${CLUSTER_DOMAIN}/maas-api/health" 2>/dev/null)"
echo ""
echo "Models registered:"
oc get maasmodelref -A --no-headers 2>/dev/null | sed 's/^/  /'
echo ""
echo "Active subscriptions:"
oc get maassubscription -n models-as-a-service --no-headers 2>/dev/null | sed 's/^/  /'
echo ""
echo "Auth policies:"
oc get maasauthpolicy -n models-as-a-service --no-headers 2>/dev/null | sed 's/^/  /'
echo ""
echo "Auto-created policies:"
oc get authpolicy -n openshift-ingress --no-headers 2>/dev/null | sed 's/^/  /'
oc get tokenratelimitpolicy -n openshift-ingress --no-headers 2>/dev/null | sed 's/^/  /'
echo "============================================================"
```

**Path B installation is complete.**

---

# Observability (Optional)

Applies to both paths. For Path B, this enables the MaaS observability dashboard
(Technology Preview) which provides per-model usage metrics and token tracking.

## Install Cluster Observability Operator (COO)

COO provides Perses dashboards for metrics visualization.

```bash
oc apply -f lib/manifests/observability/coo-namespace.yaml
oc apply -f lib/manifests/observability/coo-operatorgroup.yaml
oc apply -f lib/manifests/observability/coo-subscription.yaml
```

Wait for the operator:

```bash
until oc get csv -n openshift-cluster-observability-operator 2>/dev/null | \
  grep -q "cluster-observability-operator.*Succeeded"; do
  echo "Waiting for COO operator..."
  sleep 10
done
echo "COO operator ready"
```

## Configure Gateway Telemetry (Path B Only)

These resources add per-model, per-user, per-subscription labels to gateway
metrics. Requires RHCL and the MaaS gateway.

```bash
oc apply -f lib/manifests/observability/gateway-telemetry-policy.yaml
oc apply -f lib/manifests/observability/istio-gateway-telemetry.yaml
```

Enable the observability dashboard flag if not already set:

```bash
oc patch odhdashboardconfig odh-dashboard-config \
  -n redhat-ods-applications --type=merge -p '{
    "spec": {
      "dashboardConfig": {
        "observabilityDashboard": true
      }
    }
  }'
```

> **Note on llm-d metrics (3.5):** Distributed Inference metrics now use the
> `llm_d_epp_` prefix. The old `inference_extension_` prefix is deprecated but
> still available. Update any custom Prometheus dashboards or alerts:
> - `llm_d_epp_request_total`
> - `llm_d_epp_request_duration_seconds`
> - `llm_d_epp_request_ttft_seconds`
> - `llm_d_epp_scheduler_e2e_duration_seconds`
> - `llm_d_epp_average_kv_cache_utilization`
> - `llm_d_epp_flow_control_queue_size`

**Verify:**

```bash
echo "=== Observability ==="
echo "COO:              $(oc get csv -n openshift-cluster-observability-operator 2>/dev/null | grep cluster-observability | awk '{print $NF}')"
echo "TelemetryPolicy:  $(oc get telemetrypolicy maas-telemetry -n openshift-ingress &>/dev/null && echo 'exists' || echo 'not found')"
echo "Istio Telemetry:  $(oc get telemetry latency-per-subscription -n openshift-ingress &>/dev/null && echo 'exists' || echo 'not found')"
```

---

# Optional Components

These components enhance the RHOAI platform but are not required for basic
model serving or MaaS.

## JobSet Operator and Kubeflow Trainer v2

Required for distributed training workloads. Install JobSet first, then
update the DataScienceCluster.

### Install JobSet Operator

```bash
oc apply -f lib/manifests/operators/jobset-subscription.yaml

until oc get csv -n openshift-operators 2>/dev/null | grep -q "jobset.*Succeeded"; do
  echo "Waiting for JobSet operator..."
  sleep 10
done
echo "JobSet operator ready"
```

### Enable Trainer in DataScienceCluster

```bash
oc patch datasciencecluster default-dsc --type=merge -p '{
  "spec": {
    "components": {
      "trainer": {
        "managementState": "Managed"
      }
    }
  }
}'
```

> **Important:** The Trainer component requires JobSet to be installed first.
> If you enable Trainer without JobSet, the DSC will fail to reconcile.

## Feast Feature Store

Feast is enabled in the DSC by default (`feastoperator: Managed`). To make it
visible in the dashboard, label your namespace:

```bash
oc label namespace <your-namespace> opendatahub.io/dashboard=true
```

Feature Store dashboard visibility also requires:
- Label: `feature-store-ui: enabled` on the FeatureStore CR
- `spec.services.registry.local.server.restAPI: true` in the FeatureStore spec

> **New in 3.5:** SparkApplication batch engine support for Feast.

## OGX (Replaces Llama Stack)

OGX is enabled in the DSC by default (`ogx: Managed`). It provides GenAI
orchestration, RAG, and agentic workflows. The Responses API is GA on OGX in 3.5.

OGX requires:
- Red Hat OpenShift Service Mesh Operator 3.x
- cert-manager Operator
- GPU-enabled nodes with NFD + NVIDIA GPU Operator
- S3-compatible object storage

## MCP Lifecycle Operator

The MCP Lifecycle Operator is now a first-class DSC component in 3.5
(`mcplifecycleoperator: Managed`). No manual GitHub installation is needed —
the RHOAI operator deploys and manages it automatically.

This enables the MCP Catalog to deploy and serve MCP servers end-to-end.

## MLflow Experiment Tracking

MLflow is enabled in the DSC by default (`mlflowoperator: Managed`). Create an
MLflow server instance:

```bash
oc apply -f lib/manifests/rhoai/mlflow-cr.yaml
```

Wait for MLflow:

```bash
until oc get mlflow mlflow -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -q "True"; do
  echo "Waiting for MLflow..."
  sleep 10
done
echo "MLflow ready: $(oc get mlflow mlflow -o jsonpath='{.status.url}' 2>/dev/null)"
```

## Model Registry

Model Registry is enabled in the DSC by default. It uses the
`rhoai-model-registries` namespace. Configure a PostgreSQL backend for
production use, or use the default SQLite for testing.

## AI Pipelines (DSPA)

AI Pipelines are enabled in the DSC. To deploy a pipeline server in a namespace,
create a DataSciencePipelinesApplication (DSPA) resource with S3-compatible
object storage. See the RHOAI documentation for DSPA configuration.

## Hardware Profile

If you skipped this in Path A, create the GPU hardware profile now:

```bash
oc apply -f lib/manifests/rhoai/hardware-profile-gpu.yaml
```

---

# Troubleshooting

## Common Issues

### DSC Shows "Degraded" or Stuck

```bash
# Check conditions (including new 3.5 conditions)
oc get datasciencecluster default-dsc -o json | jq '.status.conditions[] | {type, status, message}'

# Check operator logs
oc logs -n redhat-ods-operator deploy/rhods-operator --tail=50
```

Common causes:
- Missing prerequisite operator (Kueue, cert-manager)
- Trainer enabled without JobSet operator
- MaaS enabled without RHCL/Kuadrant
- Using `llamastackoperator` field (3.4) instead of `ogx` (3.5) — DSC validation will fail

### ModelsAsAServiceReady is False

This condition tells you exactly what is missing. Check the message:

```bash
oc get datasciencecluster default-dsc \
  -o jsonpath='{.status.conditions[?(@.type=="ModelsAsAServiceReady")].message}'
```

Common causes:
1. `maas-default-gateway` not yet created or not Programmed
2. `maas-db-config` secret missing from `redhat-ai-gateway-infra`
3. Authorino TLS not configured

### AIGatewayReady is False

```bash
oc get datasciencecluster default-dsc \
  -o jsonpath='{.status.conditions[?(@.type=="AIGatewayReady")].message}'

# Check maas-controller deployment
oc get deployment maas-controller -n redhat-ai-gateway-infra
oc logs -n redhat-ai-gateway-infra deploy/maas-controller --tail=30
```

### Gateway Pod OOMKilled

The gateway proxy needs 2Gi memory for WASM plugin compilation. Verify the
resource ConfigMap is applied:

```bash
oc get configmap maas-gateway-options -n openshift-ingress -o yaml
```

Verify the gateway references it:

```bash
oc get gateway maas-default-gateway -n openshift-ingress \
  -o jsonpath='{.spec.infrastructure.parametersRef}' | jq .
```

If the pod is still OOMKilled, increase the memory limit in the ConfigMap.

### MaaS Tenant Shows "Degraded"

Usually caused by a missing or malformed `maas-db-config` secret:

```bash
# Check if secret exists in the CORRECT namespace (redhat-ai-gateway-infra for 3.5)
oc get secret maas-db-config -n redhat-ai-gateway-infra

# Check the key format
oc get secret maas-db-config -n redhat-ai-gateway-infra \
  -o jsonpath='{.data.DB_CONNECTION_URL}' | base64 -d
```

The URL format must be: `postgresql://user:pass@host:5432/db?sslmode=...`

> **Migration from 3.4:** If upgrading from 3.4, the `maas-db-config` secret
> needs to be recreated in `redhat-ai-gateway-infra` (it was in
> `redhat-ods-applications` in 3.4).

### MaaSSubscription/MaaSAuthPolicy Admission Rejected

In 3.5, the admission webhook requires a `MaasTenantConfig` CR to exist before
`MaaSSubscription` or `MaaSAuthPolicy` resources can be created. If you see
admission errors:

```bash
# Check if MaasTenantConfig exists
oc get maastenantconfig default-tenant -n models-as-a-service

# If not, wait for the maas-controller to create it
oc get pods -n redhat-ai-gateway-infra -l app=maas-controller
```

The controller will auto-create the `MaasTenantConfig` once it finishes
bootstrapping. Retry your `MaaSSubscription`/`MaaSAuthPolicy` creation after.

### Authorino TLS Not Working

Verify each step:

```bash
# 1. Service annotation
oc get service authorino-authorino-authorization -n kuadrant-system \
  -o jsonpath='{.metadata.annotations}' | jq .

# 2. Secret exists
oc get secret authorino-server-cert -n kuadrant-system

# 3. TLS enabled on Authorino CR
oc get authorino authorino -n kuadrant-system -o jsonpath='{.spec.listener.tls}'

# 4. Env vars set
oc get deployment authorino -n kuadrant-system -o json | \
  jq '.spec.template.spec.containers[0].env[] | select(.name | test("SSL|CA"))'

# 5. Authorino is available
oc wait --for=condition=Available deployment/authorino -n kuadrant-system --timeout=10s
```

### Gateway Returns 503

Common causes:
- TLS secret `default-gateway-tls` missing in `openshift-ingress`
- Passthrough Route not created or pointing to wrong service
- Gateway service not yet created by Istio

```bash
# Check TLS secret
oc get secret default-gateway-tls -n openshift-ingress

# Check route target matches actual service
oc get route -n openshift-ingress -o wide
oc get svc -n openshift-ingress -l gateway.networking.k8s.io/gateway-name=maas-default-gateway
```

### RHCL Issues

RHCL 1.4.1+ uses Automatic approval, but dependencies (Service Mesh) may still
use Manual approval. Check for unapproved plans:

```bash
oc get installplan -n openshift-operators -o json | \
  jq '.items[] | select(.spec.approved == false) | {name: .metadata.name, csvs: .spec.clusterServiceVersionNames}'
```

Approve manually:

```bash
PLAN_NAME="<plan-name-from-above>"
oc patch installplan "$PLAN_NAME" -n openshift-operators \
  --type merge -p '{"spec":{"approved":true}}'
```

### InferenceService Stuck in "Unknown" or Not Ready

```bash
# Check events
oc get events -n <namespace> --sort-by='.lastTimestamp' | tail -20

# Check predictor pod
oc get pods -n <namespace> -l serving.kserve.io/inferenceservice=<name>
oc logs -n <namespace> <pod-name> -c kserve-container --tail=30

# Common issue: storage credentials
oc get secret -n <namespace> | grep -i s3
```

### Service Mesh InstallPlan Not Approved

Service Mesh 3 uses Manual approval. Check and approve:

```bash
for PLAN in $(oc get installplan -n openshift-operators --no-headers | awk '{print $1}'); do
  APPROVED=$(oc get installplan "$PLAN" -n openshift-operators -o jsonpath='{.spec.approved}')
  if [ "$APPROVED" = "false" ]; then
    CSVS=$(oc get installplan "$PLAN" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}')
    echo "Unapproved: $PLAN ($CSVS)"
    # Uncomment to approve:
    # oc patch installplan "$PLAN" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
  fi
done
```

### Kuadrant Not Ready

If Kuadrant shows NotReady after Istio installation, restart the operator:

```bash
oc delete pod -n kuadrant-system -l app.kubernetes.io/name=kuadrant-operator
sleep 20
oc wait --for=condition=Ready kuadrant/kuadrant -n kuadrant-system --timeout=120s
```

### llm-d Flow Control Migration Issues (3.4 → 3.5)

If you configured flow control during the 3.4 TP, update all resources:

```bash
# Check for old API group references
oc get inferenceObjective -A 2>/dev/null
oc get endpointPickerConfig -A 2>/dev/null

# These must be recreated with:
#   API group: llm-d.ai (was inference.networking.x-k8s.io)
#   InferenceObjective: llm-d.ai/v1alpha2 (was inference.networking.x-k8s.io/v1alpha1)
#   saturationDetector → flowControl.saturationDetector
```

### WVA ConfigMap Rename (Upgrade from 3.4)

The Workload Variant Autoscaler ConfigMap is renamed in 3.5:

```bash
# Old name (3.4)
oc get configmap workload-variant-autoscaler-wva-variantautoscaling-config \
  -n redhat-ods-applications -o yaml > wva-config-backup.yaml 2>/dev/null

# New name (3.5)
# workload-variant-autoscaler-manager-config
# Your customized values are NOT preserved — reapply from backup
```

---

# Quick Reference: What Needs What

## Component Dependency Matrix

| Component | Required By | Namespace |
|-----------|------------|-----------|
| NFD | GPU Operator | `openshift-nfd` |
| GPU Operator | GPU model serving | `nvidia-gpu-operator` |
| cert-manager (1.19/1.20) | KServe, RHCL | `cert-manager-operator` |
| UWM | RHOAI metrics, MaaS | `openshift-monitoring` |
| RHOAI Operator | Everything | `redhat-ods-operator` |
| DSCInitialization | DataScienceCluster | — |
| Kueue | Workload scheduling (MaaS) | `openshift-operators` |
| LWS | llm-d (distributed inference) | `openshift-lws-operator` |
| Service Mesh 3.4 | RHCL/Istio gateway | `openshift-operators` |
| RHCL 1.4.1+ | Kuadrant, Authorino, Limitador | `openshift-operators` |
| Kuadrant | MaaS auth + rate limiting | `kuadrant-system` |
| Istio | Gateway data plane | `istio-system` |
| PostgreSQL | MaaS API keys | `redhat-ai-gateway-infra` |
| JobSet | Kubeflow Trainer v2 | `openshift-operators` |
| COO | Observability dashboard | `openshift-cluster-observability-operator` |

## Path A (No MaaS) — Operator Install Order

```
1. NFD
2. GPU Operator
3. cert-manager (1.19/1.20)
4. UWM (ConfigMap)
5. RHOAI Operator
6. DSCInitialization
7. DataScienceCluster (aigateway.modelsAsAService: Removed, ogx: Managed, mcplifecycleoperator: Managed)
8. Dashboard patch (roleManagement: true)
9. Hardware Profile
10. ServingRuntime + InferenceService
```

## Path B (MaaS) — Operator Install Order

```
 1. NFD
 2. GPU Operator
 3. cert-manager (1.19/1.20)
 4. UWM (ConfigMap)
 5. Kueue
 6. LWS
 7. Service Mesh 3.4 (approve InstallPlans)
 8. RHCL 1.4.1+ (Automatic approval — approve dependency InstallPlans)
 9. Kuadrant
10. IstioCNI + Istio
11. GatewayClasses (wait for Accepted condition)
12. Authorino TLS (service-ca)
13. Gateway resource ConfigMap
14. Gateway (maas-default-gateway, wait for Programmed condition)
15. Gateway TLS secret
16. Passthrough Routes
17. RHOAI Operator
18. DSCInitialization
19. DataScienceCluster (aigateway.modelsAsAService: Managed, ogx: Managed, mcplifecycleoperator: Managed)
20. Wait for AIGatewayReady, check ModelsAsAServiceReady
21. PostgreSQL + maas-db-config secret (in redhat-ai-gateway-infra)
22. Restart maas-api to pick up DB config
23. Dashboard patch (MaaS flags + roleManagement: true)
24. Verify auto-created gateway policies (maas-gateway-auth, gateway-default-deny)
25. LLMInferenceService + MaaS CRs
```

## Key Namespaces

| Namespace | Purpose |
|-----------|---------|
| `redhat-ods-operator` | RHOAI operator |
| `redhat-ods-applications` | Dashboard, model serving |
| `redhat-ai-gateway-infra` | MaaS infrastructure (maas-api, maas-controller, PostgreSQL, maas-db-config) |
| `redhat-ods-monitoring` | RHOAI monitoring |
| `kuadrant-system` | Kuadrant, Authorino |
| `openshift-ingress` | Gateway, Routes, auto-created policies |
| `istio-system` | Istio control plane |
| `istio-cni` | Istio CNI |
| `models-as-a-service` | MaaS Tenant, MaasTenantConfig, subscriptions, auth policies |
| `openshift-operators` | Kueue, RHCL, Service Mesh subscriptions |
| `openshift-nfd` | NFD operator |
| `nvidia-gpu-operator` | GPU operator |
| `cert-manager-operator` | cert-manager operator |
| `openshift-lws-operator` | LWS operator |

## Key Endpoints

| Endpoint | URL Pattern |
|----------|-------------|
| RHOAI Dashboard | `https://rh-ai.apps.<cluster>` |
| MaaS API Gateway | `https://maas.apps.<cluster>` |
| MaaS Health | `https://maas.apps.<cluster>/maas-api/health` |
| Inference Gateway | `https://inference-gateway.apps.<cluster>` |
| Model Route (Path A) | `https://<model>-<namespace>.apps.<cluster>` |

## Key Secrets

| Secret | Namespace | Purpose |
|--------|-----------|---------|
| `default-gateway-tls` | `openshift-ingress` | Gateway HTTPS TLS cert |
| `authorino-server-cert` | `kuadrant-system` | Authorino TLS (service-ca) |
| `maas-db-config` | `redhat-ai-gateway-infra` | MaaS DB connection URL |
| `postgres-creds` | `redhat-ai-gateway-infra` | PostgreSQL credentials |

## Key CRDs (New/Changed in 3.5)

| CRD | Purpose |
|-----|---------|
| `maastenantconfigs.maas.opendatahub.io` | Tenant infrastructure configuration (auto-created) |
| `aitenants.maas.opendatahub.io` | Multi-tenancy (Technology Preview) |
| `tokenratelimitpolicies.kuadrant.io` | Token-based rate limiting (replaces RateLimitPolicy) |

## Auto-Created Resources (3.5)

| Resource | Kind | Namespace | Purpose |
|----------|------|-----------|---------|
| `maas-gateway-auth` | AuthPolicy | `openshift-ingress` | Denies unauthenticated traffic |
| `gateway-default-deny` | TokenRateLimitPolicy | `openshift-ingress` | Denies unsubscribed traffic |
| `maas-api-auth-policy` | AuthPolicy | `redhat-ai-gateway-infra` | Protects MaaS API endpoint |
| `maas-authorino-allow` | NetworkPolicy | `redhat-ai-gateway-infra` | Allows Authorino to reach MaaS API |

## Version Comparison: 3.4 vs 3.5

```
                          RHOAI 3.4              RHOAI 3.5
                          ─────────              ─────────
OCP Support              4.19–4.21              4.19–4.22
RHCL Version             1.2+ (Manual pin)      1.4.1+ (Automatic)
Service Mesh             3.2+                   3.4
cert-manager             1.18+                  1.19/1.20
KubeRay                  1.4.2                  1.6.x
MaaS Infra NS            redhat-ods-applications redhat-ai-gateway-infra
DSC GenAI field          llamastackoperator     ogx
MCP Lifecycle            Manual GitHub install  DSC component (mcplifecycleoperator)
MaaS External OIDC       TP                     GA
EvalHub                  TP                     GA
llm-d Flow Control       TP                     GA (breaking API change)
llm-d Metrics Prefix     inference_extension_   llm_d_epp_
Gateway Policies         Manual                 Auto-created by maas-controller
Rate Limit CRD           RateLimitPolicy        TokenRateLimitPolicy
DSC Conditions           DashboardReady,        + AIGatewayReady,
                         KserveReady            ModelsAsAServiceReady
```

## Manifest Files Reference

All manifests are under `lib/manifests/`. Templates using `envsubst` are noted.

| Category | File | Variables |
|----------|------|-----------|
| **Operators** | `operators/nfd-operator.yaml` | — |
| | `operators/nfd-instance.yaml` | — |
| | `operators/gpu-operator.yaml` | — |
| | `operators/gpu-clusterpolicy.yaml` | — |
| | `operators/certmanager-operatorgroup.yaml` | — |
| | `operators/certmanager-subscription.yaml` | — |
| | `operators/kueue-subscription.yaml` | — |
| | `operators/lws-operatorgroup.yaml` | — |
| | `operators/lws-subscription.yaml` | — |
| | `operators/lws-operator-cr.yaml` | — |
| | `operators/servicemesh3-subscription.yaml` | — |
| | `operators/jobset-subscription.yaml` | — |
| **RHOAI** | `rhoai/rhoai-operatorgroup.yaml` | — |
| | `rhoai/rhoai-subscription.yaml` | `${RHOAI_CHANNEL}` |
| | `rhoai/dscinitialization.yaml` | — |
| | `rhoai/datasciencecluster-v3-35.yaml` | — |
| | `rhoai/hardware-profile-gpu.yaml` | — |
| | `rhoai/mlflow-cr.yaml` | — |
| **RHCL** | `rhcl/rhcl-operator-35.yaml` | — |
| | `rhcl/kuadrant-instance.yaml` | — |
| | `rhcl/authorino-tls.yaml` | — |
| | `rhcl/gatewayclass-default.yaml` | — |
| | `rhcl/gatewayclass-gateway-controller.yaml` | — |
| | `rhcl/gatewayclass-ai-inference.yaml` | — |
| | `rhcl/gateway-resources.yaml` | — |
| | `rhcl/istiocni.yaml` | `${ISTIO_VERSION}` |
| | `rhcl/istio.yaml` | `${ISTIO_VERSION}` |
| | `rhcl/gateway-maas.yaml` | `${CLUSTER_DOMAIN}`, `${CERT_NAME}` |
| | `rhcl/gateway-inference.yaml` | `${CLUSTER_DOMAIN}`, `${CERT_NAME}` |
| | `rhcl/gateway-tls-certificate.yaml` | `${CLUSTER_DOMAIN}`, `${ISSUER_NAME}` |
| | `rhcl/gateway-passthrough-route.yaml` | `${ROUTE_NAME}`, `${HOSTNAME}`, `${SERVICE_NAME}` |
| **MaaS** | `maas/postgres-pvc.yaml` | — |
| | `maas/postgres-deployment.yaml` | `${PG_IMAGE}`, `${PG_USER}`, `${PG_PASSWORD}`, `${PG_DB}` |
| | `maas/postgres-service.yaml` | — |
| | `maas/simulator/llminferenceservice.yaml` | `${MODEL_NAMESPACE}` |
| | `maas/simulator/maas-model-ref.yaml` | `${MODEL_NAMESPACE}` |
| | `maas/simulator/maas-auth-policy.yaml` | `${MODEL_NAMESPACE}` |
| | `maas/simulator/maas-subscription-free.yaml` | `${MODEL_NAMESPACE}` |
| | `maas/simulator/maas-subscription-premium.yaml` | `${MODEL_NAMESPACE}` |
| **Monitoring** | `monitoring/cluster-monitoring-config.yaml` | — |
| **Observability** | `observability/coo-namespace.yaml` | — |
| | `observability/coo-operatorgroup.yaml` | — |
| | `observability/coo-subscription.yaml` | — |
| | `observability/gateway-telemetry-policy.yaml` | — |
| | `observability/istio-gateway-telemetry.yaml` | — |
