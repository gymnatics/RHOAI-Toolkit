<!-- GENERATED FILE: do not edit directly. Edit .claude/skills/manual-setup-configs/template.md, then run:
     python3 .claude/skills/manual-setup-configs/render.py
     Inline YAML is copied verbatim from lib/manifests/ at render time. -->
<!-- Last verified: 2026-10-23 against RHOAI 3.5.2 docs, odh-dashboard rhoai-3.5 source, and repo manifests -->
<!-- Retrieve with the /manual-setup-configs skill. Known drift is tracked in docs/COMPATIBILITY-TRACKER.md -->

# RHOAI 3.5: Manual Setup Configs and Commands (standalone)

A self-contained checklist for setting up a new cluster **by hand, without the toolkit repo**. Every resource is shown as full YAML that you paste into the shell (`oc apply -f - <<'EOF' … EOF`). It covers:
- operators
- DSCI and DSC states
- OdhDashboardConfig flags, labelled by support tier
- MaaS
- object storage
- model sources
- model deployment

Toolkit scripts appear only as optional "toolkit shortcut" notes.

**You need:** `oc` (logged in as cluster-admin), `jq`, `yq` (v4), `envsubst` (gettext), and `openssl`. Run every block in the **same shell session**, because later steps reuse exported variables.

**Two workflows:**

| Workflow | When | How to follow it |
|---|---|---|
| **A: Full platform with MaaS** | Central model gateway with API keys, subscriptions, token quotas, usage dashboards, external models | Steps 0–12 in order, including **2** and **5M** |
| **B: RHOAI without MaaS** | Workbenches, pipelines, per-project model serving (vLLM), Playground, guardrails, evaluation, with no central gateway yet | Steps 0–12, **skipping 2 and 5M**, with the substitutions in [Workflow B](#workflow-b-rhoai-35-without-maas). Add MaaS later with [B.9](#b9-adding-maas-later). |

**Support tiers used below:** **GA** = fully supported · **TP** = Technology Preview, no production SLA · **DP** = Developer Preview, **not supported by Red Hat at all**.

---

## 0. Preflight and variables

```bash
oc whoami && oc auth can-i '*' '*' --all-namespaces       # must be "yes" (cluster-admin)
oc get clusterversion -o jsonpath='{.items[0].status.desired.version}{"\n"}'
# RHOAI 3.5 supports OCP 4.19.9+ to 4.22. llm-d needs 4.20+. Kueue 1.3 is not available on 4.22 (see step 1).

oc get packagemanifest rhods-operator -n openshift-marketplace \
  -o jsonpath='{.status.defaultChannel}{"\n"}{.status.channels[*].name}{"\n"}'
# Use stable-3.5 (or eus-3.5 / stable-3.x). Do NOT use fast-3.x: it is frozen at 3.3.1.

# Two domain variables are used below:
export APPS_DOMAIN=$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}')   # e.g. apps.mycluster.example.com
export CLUSTER_DOMAIN=${APPS_DOMAIN#apps.}                                         # e.g. mycluster.example.com
echo "APPS_DOMAIN=$APPS_DOMAIN  CLUSTER_DOMAIN=$CLUSTER_DOMAIN"
```

---

## 1. Prerequisite operators

| Operator | Package / channel | Needed for | Workflow B? |
|---|---|---|---|
| Node Feature Discovery | `nfd` / `stable` | GPUs | Yes (if GPUs) |
| NVIDIA GPU Operator | `gpu-operator-certified` / `stable` (certified-operators) | GPUs | Yes (if GPUs) |
| cert-manager | `openshift-cert-manager-operator` / `stable-v1` | KServe, llm-d, OGX | Yes |
| Red Hat build of Kueue | `kueue-operator` / `stable-v1.3` | Queueing, distributed workloads | Optional |
| Leader Worker Set | `leader-worker-set` / `stable-v1.0` | llm-d (MaaS models) | Only for llm-d |
| OpenShift Service Mesh 3 | `servicemeshoperator3` / `stable` | OGX, llm-d gateway, MaaS | Yes if OGX / Playground RAG |
| JobSet *(optional)* | `jobset-operator` / `stable` | Only if DSC `trainer: Managed` | Optional |

> **Kueue:** stay on 1.3, because Kueue 1.4+ breaks Trainer v2 (RHOAIENG-87625). Kueue 1.3 is **not available on OCP 4.22**. On 4.22, either skip Kueue (set DSC `kueue: Removed`) or accept 1.4+ without Trainer v2.

### 1.1 Node Feature Discovery

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

until oc get crd nodefeaturediscoveries.nfd.openshift.io &>/dev/null; do echo "waiting for NFD CRD"; sleep 5; done

oc apply -f - <<'EOF'
---
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

until oc get crd clusterpolicies.nvidia.com &>/dev/null; do echo "waiting for ClusterPolicy CRD"; sleep 5; done

oc apply -f - <<'EOF'
---
apiVersion: nvidia.com/v1
kind: ClusterPolicy
metadata:
  name: gpu-cluster-policy
spec:
  vgpuDeviceManager:
    config:
      default: default
    enabled: true
  migManager:
    config:
      default: all-disabled
      name: default-mig-parted-config
    enabled: true
  operator:
    defaultRuntime: crio
    initContainer: {}
    runtimeClass: nvidia
    use_ocp_driver_toolkit: true
  dcgm:
    enabled: true
  gfd:
    enabled: true
  dcgmExporter:
    config:
      name: ''
    serviceMonitor:
      enabled: true
    enabled: true
  cdi:
    default: false
    enabled: true
  driver:
    licensingConfig:
      nlsEnabled: true
      secretName: ''
    kernelModuleType: auto
    certConfig:
      name: ''
    kernelModuleConfig:
      name: ''
    upgradePolicy:
      autoUpgrade: true
      drain:
        deleteEmptyDir: false
        enable: false
        force: false
        timeoutSeconds: 300
      maxParallelUpgrades: 1
      maxUnavailable: 25%
      podDeletion:
        deleteEmptyDir: false
        force: false
        timeoutSeconds: 300
      waitForCompletion:
        timeoutSeconds: 0
    repoConfig:
      configMapName: ''
    virtualTopology:
      config: ''
    enabled: true
    useNvidiaDriverCRD: false
  devicePlugin:
    config:
      name: ''
      default: ''
    mps:
      root: /run/nvidia/mps
    enabled: true
  gdrcopy:
    enabled: false
  kataManager:
    config:
      artifactsDir: /opt/nvidia-gpu-operator/artifacts/runtimeclasses
  mig:
    strategy: single
  sandboxDevicePlugin:
    enabled: true
  validator:
    plugin:
      env: []
  nodeStatusExporter:
    enabled: true
  daemonsets:
    rollingUpdate:
      maxUnavailable: '1'
    updateStrategy: RollingUpdate
  sandboxWorkloads:
    defaultWorkload: container
    enabled: false
  gds:
    enabled: false
  vgpuManager:
    enabled: false
  vfioManager:
    enabled: true
  toolkit:
    installDir: /usr/local/nvidia
    enabled: true
EOF
```

### 1.3 cert-manager

```bash
oc apply -f - <<'EOF'
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

### 1.4 Red Hat build of Kueue *(optional; skip on OCP 4.22)*

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

### 1.5 Leader Worker Set *(needed for llm-d / MaaS models)*

```bash
oc apply -f - <<'EOF'
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

until oc get crd leaderworkersetoperators.operator.openshift.io &>/dev/null; do echo "waiting for LWS CRD"; sleep 5; done

oc apply -f - <<'EOF'
---
apiVersion: operator.openshift.io/v1
kind: LeaderWorkerSetOperator
metadata:
  name: cluster
  namespace: openshift-lws-operator
spec:
  managementState: Managed
  logLevel: Normal
  operatorLogLevel: Normal
EOF
```

### 1.6 OpenShift Service Mesh 3

```bash
oc apply -f - <<'EOF'
---
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

### 1.7 JobSet *(only if you will set `trainer: Managed`)*

```bash
oc apply -f - <<'EOF'
# JobSet Operator - Required for Kubeflow Trainer v2 (RHOAI 3.3+)
# Install this BEFORE enabling trainer.managementState: Managed in DataScienceCluster
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
```

### 1.8 Approve pending InstallPlans and verify

Some subscriptions (for example Service Mesh dependencies) may use Manual approval:

```bash
oc get installplan -A -o json | jq -r '.items[] | select(.spec.approved==false) | "\(.metadata.namespace) \(.metadata.name) \(.spec.clusterServiceVersionNames|join(","))"'
# Approve each one you expect:
# oc patch installplan <name> -n <namespace> --type merge -p '{"spec":{"approved":true}}'

oc get csv -A | grep -Ei 'nfd|gpu-operator|cert-manager|kueue|leader-worker|servicemesh|jobset'   # all Succeeded
oc get clusterpolicy gpu-cluster-policy -o jsonpath='{.status.state}{"\n"}'   # "ready" once GPU nodes exist
```

### 1.9 GPU nodes (AWS)

Clone an existing worker MachineSet, then change the instance type and add the GPU taint. The GPU hardware profile in step 7 tolerates this taint.

```bash
export GPU_INSTANCE_TYPE=g6e.xlarge          # 1x L40S; e.g. g5.xlarge = 1x A10G
SRC=$(oc get machineset -n openshift-machine-api -o name | grep -v gpu | head -1)
export GPU_MS="$(basename "$SRC")-gpu"

oc get "$SRC" -n openshift-machine-api -o json | jq --arg n "$GPU_MS" --arg t "$GPU_INSTANCE_TYPE" '
  del(.status, .metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp,
      .metadata.generation, .metadata.annotations, .metadata.managedFields)
  | .metadata.name = $n
  | .spec.replicas = 1
  | .spec.selector.matchLabels["machine.openshift.io/cluster-api-machineset"] = $n
  | .spec.template.metadata.labels["machine.openshift.io/cluster-api-machineset"] = $n
  | .spec.template.spec.metadata.labels["node-role.kubernetes.io/gpu-worker"] = ""
  | .spec.template.spec.taints = [{"key":"nvidia.com/gpu","effect":"NoSchedule"}]
  | .spec.template.spec.providerSpec.value.instanceType = $t' | oc apply -f -

oc get machines -n openshift-machine-api -w        # about 10-15 min until the node is Ready
oc get nodes -l nvidia.com/gpu.present=true         # labelled by NFD + GPU Operator
```
> Toolkit shortcut: `./scripts/create-gpu-machineset.sh --instance-type g6e.xlarge --replicas 1 --apply`

### 1.10 User Workload Monitoring (needed for MaaS and KServe metrics)

> **Not an operator.** You won't find it in the Software Catalog / OperatorHub. It's a built-in part of OpenShift's monitoring stack (Cluster Monitoring Operator), switched on by setting `enableUserWorkload: true` in the `cluster-monitoring-config` ConfigMap in `openshift-monitoring`. Once enabled, Prometheus, Thanos Ruler and prometheus-operator pods start in `openshift-user-workload-monitoring`.

First check whether a ConfigMap already exists. If it does, **merge** `enableUserWorkload: true` into its `config.yaml` instead of replacing it:
```bash
oc get configmap cluster-monitoring-config -n openshift-monitoring -o yaml 2>/dev/null || echo "none yet"
```

If none exists:
```bash
oc apply -f - <<'EOF'
---
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

until oc get namespace openshift-user-workload-monitoring &>/dev/null; do sleep 5; done

oc apply -f - <<'EOF'
# User Workload Monitoring ConfigMap
# Enables Prometheus in the user-workload-monitoring namespace
# for capturing custom metrics from user workloads.
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-workload-monitoring-config
  namespace: openshift-user-workload-monitoring
data:
  config.yaml: |
    prometheus:
      retention: 24h
      resources:
        requests:
          cpu: 200m
          memory: 2Gi
EOF

oc get pods -n openshift-user-workload-monitoring   # prometheus-operator, prometheus-user-workload-*, thanos-ruler-* Running
```

---

## 2. MaaS prerequisites *(Workflow A only; skip for Workflow B)*

This step covers Red Hat Connectivity Link (Kuadrant, Authorino, Limitador), Istio, Authorino TLS, and the MaaS gateway. The MaaS database comes after the DSC, in step **5M**.

> **RHCL version caveat:** the 3.5 docs require RHCL 1.4.x, but **RHOAIENG-76586** says 1.4.x silently breaks rate limiting and causes gateway OOMs. The gateway below already raises proxy memory to 2Gi. Also add an identity filter to the AuthPolicy if you see rate-limit failures, or pin RHCL 1.3.5.

### 2.1 RHCL operator

```bash
oc apply -f - <<'EOF'
# RHCL 1.4.1+ Operator for RHOAI 3.5 MaaS
#
# Follows RHOAI 3.5 MaaS prerequisite pattern:
#   "installed the Red Hat Connectivity Link Operator version 1.4.1 or later
#    to the openshift-operators namespace and created a Kuadrant custom resource
#    in the kuadrant-system namespace with ready status."
#   — Red Hat OpenShift AI Self-Managed 3.5, Govern LLM access with Models-as-a-Service
#
# Note: RHCL's own install docs put everything in a single namespace (kuadrant-system).
# Both patterns work (AllNamespaces mode). We follow the RHOAI-specific prerequisite here
# because this toolkit deploys RHOAI and that's the tested/supported pattern for MaaS.
#
# openshift-operators already has a default OperatorGroup — no need to create one.
# Kuadrant CR is created separately via kuadrant-instance.yaml in kuadrant-system.
#
# RHCL 1.4.0 is DEPRECATED (auth failures, API key errors, gateway instability,
# gateway pod memory pressure from WASM plugin loading issues). RHCL 1.4.1+ fixes
# these issues, so we use Automatic approval on the `stable` channel — unlike the
# 3.4 manifest which pinned Manual to avoid auto-upgrading into the broken 1.4.0.
# If a future regression reappears, switch back to installPlanApproval: Manual and
# have the install script auto-approve plans (see install-rhoai-34.sh for the pattern).
#
# Service Mesh 3 (Sail): auto-installed as OLM dependency, uses Manual InstallPlan approval.
# RHCL 1.4 requires OpenShift Service Mesh 3.4 when Service Mesh is used explicitly.
# Prerequisites: cert-manager Operator 1.18+
---
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

until oc get csv -n openshift-operators 2>/dev/null | grep -q 'rhcl-operator.*Succeeded'; do
  echo "waiting for rhcl-operator (approve any pending servicemesh/authorino/limitador InstallPlans, see 1.8)"; sleep 10
done

# Prevent HTTP 500s under load (RHOAIENG-71638): raise the WASM auth timeout from 200ms to 2s
oc patch subscription rhcl-operator -n openshift-operators --type=merge \
  -p '{"spec":{"config":{"env":[{"name":"AUTH_SERVICE_TIMEOUT","value":"2s"}]}}}'
```

### 2.2 Kuadrant instance

```bash
oc create namespace kuadrant-system 2>/dev/null || true
oc apply -f - <<'EOF'
---
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
spec:
  observability:
    enable: true
EOF
```

### 2.3 Istio (gateway data plane for Kuadrant)

```bash
oc create namespace istio-system 2>/dev/null || true
oc create namespace istio-cni 2>/dev/null || true
export ISTIO_VERSION=$(oc get istio -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null)
export ISTIO_VERSION=${ISTIO_VERSION:-v1.26.2}      # check supported versions: oc explain istio.spec.version
echo "ISTIO_VERSION=$ISTIO_VERSION"

envsubst '${ISTIO_VERSION}' <<'EOF' | oc apply -f -
---
apiVersion: sailoperator.io/v1
kind: IstioCNI
metadata:
  name: default
  namespace: istio-system
spec:
  namespace: istio-cni
  version: ${ISTIO_VERSION}
EOF
until oc get istiocni default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; do echo "waiting for IstioCNI"; sleep 10; done

envsubst '${ISTIO_VERSION}' <<'EOF' | oc apply -f -
---
apiVersion: sailoperator.io/v1
kind: Istio
metadata:
  name: default
  namespace: istio-system
spec:
  namespace: istio-system
  version: ${ISTIO_VERSION}
EOF
until [ "$(oc get istio default -o jsonpath='{.status.state}' 2>/dev/null)" = "Healthy" ]; do echo "waiting for Istio"; sleep 10; done

oc apply -f - <<'EOF'
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-default
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
oc wait --for=condition=Accepted gatewayclass/openshift-default --timeout=120s

# Restart Kuadrant so it detects Istio
oc delete pod -n kuadrant-system -l app.kubernetes.io/name=kuadrant-operator --ignore-not-found
sleep 20
oc wait --for=condition=Ready kuadrant/kuadrant -n kuadrant-system --timeout=300s
```

### 2.4 Authorino TLS (service-ca)

```bash
oc annotate service authorino-authorino-authorization -n kuadrant-system \
  service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert --overwrite
until oc get secret authorino-server-cert -n kuadrant-system &>/dev/null; do echo "waiting for service-ca cert"; sleep 5; done

oc apply -f - <<'EOF'
---
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

# Trust the service-ca bundle. Do NOT use the /etc/ssl/certs/openshift-service-ca/... path
# from the product guide: it doesn't exist in the pod (RHOAIENG-96854).
oc -n kuadrant-system set env deployment/authorino \
  SSL_CERT_FILE=/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt \
  REQUESTS_CA_BUNDLE=/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt
oc wait --for=condition=Available deployment/authorino -n kuadrant-system --timeout=300s
oc -n kuadrant-system exec deployment/authorino -- ls -l /var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt
```

### 2.5 GatewayClasses and gateway resource overrides

```bash
oc apply -f - <<'EOF'
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-gateway-controller
spec:
  controllerName: openshift.io/gateway-controller/v1
---
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF

# 2Gi proxy memory for the WASM auth/rate-limit plugins (prevents gateway OOMKill)
oc apply -f - <<'EOF'
# Gateway proxy resource overrides for MaaS
# Increases memory limit from default 1Gi to 2Gi to prevent OOMKill
# when Kuadrant WASM extensions (Authorino auth, Limitador rate limiting) compile at startup.
# Referenced by Gateway spec.infrastructure.parametersRef.
# Tracked in RHOAIENG-68589.
# Uses "deployment" overlay key (Istio v1.27+); the old "resources" key is unsupported.
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: maas-gateway-options
  namespace: openshift-ingress
data:
  deployment: |
    spec:
      template:
        spec:
          containers:
          - name: istio-proxy
            resources:
              limits:
                memory: 2Gi
              requests:
                memory: 512Mi
EOF

oc get gatewayclass     # openshift-default, openshift-gateway-controller, openshift-ai-inference
```

### 2.6 Gateway TLS secret (pick one strategy)

```bash
export CERT_NAME=default-gateway-tls
```

**Strategy 1: cert-manager Certificate** (only if a ClusterIssuer exists):
```bash
export ISSUER_NAME=$(oc get clusterissuers -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); echo "ISSUER_NAME=$ISSUER_NAME"
envsubst '${CLUSTER_DOMAIN} ${ISSUER_NAME}' <<'EOF' | oc apply -f -
# cert-manager Certificate for gateway TLS
# Used when a ClusterIssuer is available
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: default-gateway-tls
  namespace: openshift-ingress
spec:
  secretName: default-gateway-tls
  duration: 2160h
  renewBefore: 360h
  commonName: "apps.${CLUSTER_DOMAIN}"
  dnsNames:
    - "apps.${CLUSTER_DOMAIN}"
    - "*.apps.${CLUSTER_DOMAIN}"
  issuerRef:
    name: ${ISSUER_NAME}
    kind: ClusterIssuer
  usages:
    - server auth
    - client auth
EOF
until oc get secret "$CERT_NAME" -n openshift-ingress &>/dev/null; do echo "waiting for cert-manager"; sleep 5; done
```

**Strategy 2: copy the router's wildcard certificate:**
```bash
oc get secret router-certs-default -n openshift-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/tls.crt
oc get secret router-certs-default -n openshift-ingress -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/tls.key
oc create secret tls "$CERT_NAME" --cert=/tmp/tls.crt --key=/tmp/tls.key -n openshift-ingress
rm -f /tmp/tls.crt /tmp/tls.key
```

**Strategy 3: wildcard certificate signed by the router CA:**
```bash
oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ca.crt
oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/ca.key
openssl req -new -newkey rsa:2048 -nodes -keyout /tmp/tls.key -out /tmp/tls.csr \
  -subj "/CN=*.${APPS_DOMAIN}" -addext "subjectAltName=DNS:*.${APPS_DOMAIN},DNS:${APPS_DOMAIN}"
openssl x509 -req -in /tmp/tls.csr -CA /tmp/ca.crt -CAkey /tmp/ca.key -CAcreateserial -out /tmp/tls.crt -days 365 \
  -extfile <(printf "subjectAltName=DNS:*.${APPS_DOMAIN},DNS:${APPS_DOMAIN}")
oc create secret tls "$CERT_NAME" --cert=/tmp/tls.crt --key=/tmp/tls.key -n openshift-ingress
rm -f /tmp/ca.crt /tmp/ca.key /tmp/tls.crt /tmp/tls.key /tmp/tls.csr /tmp/ca.srl
```

### 2.7 MaaS gateway

The gateway only accepts routes from namespaces labelled for gateway access (see 5M.4).

```bash
envsubst '${CLUSTER_DOMAIN} ${CERT_NAME}' <<'EOF' | oc apply -f -
# MaaS Gateway for RHOAI 3.4+
# Required annotations:
#   opendatahub.io/managed: "false" — lets MaaS controller manage auth policies
#   security.opendatahub.io/authorino-tls-bootstrap: "true" — enables TLS to Authorino
# Requires: GatewayClass, default-gateway-tls Secret, gateway-resources ConfigMap
#
# Route binding is restricted to namespaces labeled
# maas.opendatahub.io/gateway-access=true (least-privilege, matches the BU MaaS
# guide's Selector pattern). Every namespace that serves models or consumes this
# gateway must carry that label -- scripts/setup-maas.sh, scripts/deploy-maas-model.sh,
# and scripts/diagnose-maas.sh --fix all apply/verify it automatically.
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: maas-default-gateway
  namespace: openshift-ingress
  annotations:
    opendatahub.io/managed: "false"
    security.opendatahub.io/authorino-tls-bootstrap: "true"
spec:
  gatewayClassName: openshift-gateway-controller
  infrastructure:
    parametersRef:
      group: ""
      kind: ConfigMap
      name: maas-gateway-options
  listeners:
    - allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              maas.opendatahub.io/gateway-access: "true"
      hostname: maas.apps.${CLUSTER_DOMAIN}
      name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - group: ''
            kind: Secret
            name: ${CERT_NAME}
        mode: Terminate
EOF

oc annotate gateway maas-default-gateway -n openshift-ingress \
  security.opendatahub.io/authorino-tls-bootstrap="true" --overwrite
oc wait --for=condition=Programmed gateway/maas-default-gateway -n openshift-ingress --timeout=300s
```

*Optional:* a separate inference gateway, for direct model access outside MaaS governance:
```bash
envsubst '${CLUSTER_DOMAIN} ${CERT_NAME}' <<'EOF' | oc apply -f -
# llm-d inference gateway for direct model access outside MaaS governance
---
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
      hostname: inference-gateway.apps.${CLUSTER_DOMAIN}
      name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - group: ''
            kind: Secret
            name: ${CERT_NAME}
        mode: Terminate
EOF
```

### 2.8 Passthrough route (wildcard DNS → gateway service)

```bash
export ROUTE_NAME=maas-default-gateway-passthrough
export HOSTNAME="maas.${APPS_DOMAIN}"
export SERVICE_NAME=$(oc get svc -n openshift-ingress -l gateway.networking.k8s.io/gateway-name=maas-default-gateway -o jsonpath='{.items[0].metadata.name}')
echo "SERVICE_NAME=$SERVICE_NAME"

envsubst '${ROUTE_NAME} ${HOSTNAME} ${SERVICE_NAME}' <<'EOF' | oc apply -f -
# Passthrough Route: bridges *.apps.<cluster> DNS (OpenShift Router) to gateway LoadBalancer
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ${ROUTE_NAME}
  namespace: openshift-ingress
  labels:
    app.kubernetes.io/managed-by: rhoai-toolkit
  annotations:
    haproxy.router.openshift.io/timeout: 300s
spec:
  host: ${HOSTNAME}
  to:
    kind: Service
    name: ${SERVICE_NAME}
  port:
    targetPort: https
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: Redirect
EOF
```
> `HOSTNAME` shadows the shell's own `$HOSTNAME`. Run `unset HOSTNAME` (or open a new shell) after this step if anything relies on it.

```bash
# Checkpoint
oc get csv -n openshift-operators | grep -Ei 'rhcl|authorino|limitador'
oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
oc get gateway,route -n openshift-ingress
```

---

## 3. RHOAI operator

```bash
export RHOAI_CHANNEL=stable-3.5            # NOT fast-3.x
export INSTALL_PLAN_APPROVAL=Automatic
oc create namespace redhat-ods-operator 2>/dev/null || true

oc apply -f - <<'EOF'
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
EOF

envsubst '${RHOAI_CHANNEL} ${INSTALL_PLAN_APPROVAL}' <<'EOF' | oc apply -f -
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  name: rhods-operator
  channel: ${RHOAI_CHANNEL}
  installPlanApproval: ${INSTALL_PLAN_APPROVAL}
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

until oc get csv -n redhat-ods-operator 2>/dev/null | grep -q 'rhods-operator.3.5.*Succeeded'; do echo waiting; sleep 10; done
oc get csv -n redhat-ods-operator | grep rhods      # confirm 3.5.x, not 3.3.x
```

---

## 4. DSCInitialization

The defaults are fine: applications namespace `redhat-ods-applications`, monitoring `Managed`, trusted CA bundle `Managed`.

```bash
oc apply -f - <<'EOF'
# DSCInitialization for RHOAI 3.4
# Controls applications namespace, monitoring, and trusted CA bundle.
# Applied before DataScienceCluster to ensure operator reconciles correctly.
---
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization
metadata:
  name: default-dsci
spec:
  applicationsNamespace: redhat-ods-applications
  monitoring:
    managementState: Managed
    namespace: redhat-ods-monitoring
  trustedCABundle:
    managementState: Managed
    customCABundle: ""
EOF
oc wait --for=jsonpath='{.status.phase}'=Ready dscinitialization/default-dsci --timeout=300s
```

---

## 5. DataScienceCluster

API `datasciencecluster.opendatahub.io/v2`, name `default-dsc`.

| Component | State | Tier (3.5) | Notes / dependency |
|---|---|---|---|
| `dashboard` | Managed | GA | |
| `workbenches` | Managed | GA | `workbenchNamespace: rhods-notebooks`. RStudio images removed in 3.5. |
| `aipipelines` (+ `argoWorkflowsControllers: Managed`) | Managed | GA | Needs S3. Required for AutoML and AutoRAG. |
| `kserve` | Managed | GA | `defaultDeploymentMode: RawDeployment`, `rawDeploymentServiceConfig: Headed`. Add `nim: Managed` for NVIDIA NIM. Serverless and ModelMesh are deprecated. |
| `aigateway` + `aigateway.modelsAsAService` | Managed **(Workflow A)** / **Removed (Workflow B)** | GA | New in 3.5; note the spelling **"AsA"**. Replaces `kserve.modelsAsService`, which is deprecated; don't set both. |
| `kueue` | **Unmanaged** (or Removed) | GA | `Managed` is rejected in 3.5. Optional `autoCreateQueues: true`. |
| `ray` | Managed | GA | |
| `trainer` | **Removed** (Managed only if JobSet is installed) | GA | Kubeflow Trainer v2 |
| `trainingoperator` | **Removed** | Deprecated | Images removed in 3.5 |
| `modelregistry` | Managed | GA | Also required by the MCP Catalog and Agent Catalog dashboard pages |
| `trustyai` | Managed | GA | NeMo Guardrails, EvalHub. FMS Orchestrator and LM-Eval are deprecated. |
| `feastoperator` | Managed | GA / TP (sources conflict) | Feature Store |
| `ogx` | Managed | GA (excluded from 3.5 EUS) | Replaces `llamastackoperator`; don't set both. Needs Service Mesh 3, cert-manager, S3. |
| `mcplifecycleoperator` | Managed | **TP** | Lets the MCP Catalog deploy MCPServer CRs |
| `mlflowoperator` | Managed | GA | |
| `sparkoperator` | Managed *(optional)* | GA | Not in the YAML below; add `sparkoperator: {managementState: Managed}` if needed |

Save the DSC to a file, so Workflow B (and later edits) can modify it:
```bash
cat > dsc.yaml <<'EOF'
# DataScienceCluster for RHOAI 3.5
# This configuration enables all major components for a full RHOAI 3.5 installation
# Requires: NFD, GPU Operator, Kueue, cert-manager, RHCL v1.4.1+ (for MaaS), LWS (for llm-d)
# Optional: JobSet operator (required if trainer.managementState: Managed)
#
# Changes from 3.4:
#   - llamastackoperator is GONE. Replaced by the OGX Operator (DSC field: ogx).
#     OGX component requirements: Service Mesh 3.x, cert-manager, GPU nodes, NFD,
#     NVIDIA GPU Operator, S3-compatible storage. Responses API is GA on OGX.
#   - mcplifecycleoperator is now a first-class DSC component (Technology Preview).
#     Automatically deployed during standard install; enables the MCP Catalog.
#   - External OIDC authentication for MaaS is now GA.
#   - EvalHub is GA (managed via TrustyAI Operator); LM-Eval is deprecated.
#   - Flow control for llm-d is GA (BREAKING: API group inference.networking.x-k8s.io -> llm-d.ai)
#   - RHCL v1.4.1+ required (1.4.0 is deprecated due to auth/gateway issues)
#   - API version: datasciencecluster.opendatahub.io/v2 (unchanged)
#
# Reference: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5
apiVersion: datasciencecluster.opendatahub.io/v2
kind: DataScienceCluster
metadata:
  name: default-dsc
  labels:
    app.kubernetes.io/name: datasciencecluster
spec:
  components:
    # Dashboard - OpenShift AI web interface
    dashboard:
      managementState: Managed

    # Workbenches - Jupyter notebooks and IDEs
    # RStudio Server / CUDA-RStudio images removed in 3.5 (licensing compliance)
    workbenches:
      managementState: Managed
      workbenchNamespace: rhods-notebooks

    # AI Pipelines - ML workflow automation (required for AutoML/AutoRAG)
    aipipelines:
      managementState: Managed
      argoWorkflowsControllers:
        managementState: Managed

    # KServe - Model serving platform (required for vLLM, llm-d)
    kserve:
      managementState: Managed
      # RawDeployment with Headed config (required for Guardrails + TrustyAI)
      defaultDeploymentMode: RawDeployment
      rawDeploymentServiceConfig: Headed
      # NVIDIA NIM support
      nim:
        managementState: Managed
      # Optional in 3.5: customize OAuth proxy sidecar resources directly here instead of
      # editing inferenceservice-config ConfigMap, e.g.:
      # oauthProxy:
      #   resources:
      #     requests: { memory: "256Mi", cpu: "200m" }
      #     limits: { memory: "512Mi", cpu: "500m" }

    # AI Gateway - MaaS and Batch Gateway (NEW in 3.5)
    # REPLACES kserve.modelsAsService (deprecated; still respected through 3.6 but should
    # be migrated to aigateway.modelsAsAService). Note the spelling: "modelsAsAService".
    # Requires: RHCL operator, Gateway API
    # Conditions: AIGatewayReady, ModelsAsAServiceReady
    aigateway:
      managementState: Managed
      # MaaS - Models as a Service (core GA since 3.4; external OIDC now GA in 3.5)
      # GA: subscriptions, API keys, llm-d serving, external OIDC auth, body-based routing
      # TP: vLLM runtime, observability dashboard, external model egress
      # maas-controller runs in redhat-ods-applications; maas-api in redhat-ai-gateway-infra
      modelsAsAService:
        managementState: Managed

    # Kueue - Workload scheduling
    # Set to Unmanaged when using Red Hat Build of Kueue Operator (standalone)
    kueue:
      defaultClusterQueueName: default
      defaultLocalQueueName: default
      managementState: Unmanaged
      # New in 3.5: autoCreateQueues (only takes effect when managementState is Unmanaged)
      # Defaults to false. Set to true to let the Operator auto-create default queues.
      # autoCreateQueues: false

    # Ray - Distributed computing framework (KubeRay upgraded to 1.6.x in 3.5)
    ray:
      managementState: Managed

    # Trainer - Kubeflow Trainer v2 (GA)
    # IMPORTANT: Requires JobSet operator to be installed first!
    # Set to Removed if JobSet is not installed
    trainer:
      managementState: Removed

    # Training Operator - Legacy distributed training (deprecated, images removed in 3.5)
    trainingoperator:
      managementState: Removed

    # Model Registry - Model versioning and tracking
    modelregistry:
      managementState: Managed
      registriesNamespace: rhoai-model-registries

    # TrustyAI - Model explainability, fairness, NeMo Guardrails, and EvalHub (GA)
    # NeMo Guardrails is the single recommended framework; FMS Guardrails Orchestrator
    # is deprecated in 3.5 (still functional, plan migration for existing deployments)
    trustyai:
      managementState: Managed

    # Feast Operator - Feature Store (Technology Preview)
    # New in 3.5: SparkApplication batch engine support
    feastoperator:
      managementState: Managed

    # OGX Operator - GenAI orchestration, RAG, agentic workflows
    # REPLACES llamastackoperator in 3.5. Formerly "Llama Stack".
    # Requires: Service Mesh 3.x, cert-manager, GPU nodes, NFD, NVIDIA GPU Operator,
    # S3-compatible object storage for model artifacts.
    ogx:
      managementState: Managed

    # MCP Lifecycle Operator - runtime infrastructure for MCP servers (Technology Preview)
    # New first-class DSC component in 3.5. Automatically deployed during standard
    # install; enables the MCP Catalog to deploy/serve MCP servers end-to-end.
    mcplifecycleoperator:
      managementState: Managed

    # MLflow Operator - Experiment tracking, model versioning
    mlflowoperator:
      managementState: Managed
EOF

oc apply -f dsc.yaml             # Workflow A. For Workflow B, see B.4 instead.

oc get dsc default-dsc -o json | jq -r '.status.conditions[] | "\(.type)=\(.status) \(.reason // "")"'
# Expect True: Ready, KserveReady, DashboardReady, WorkbenchesReady, OGXReady, TrustyAIReady,
#   ModelRegistryReady, MLflowOperatorReady, MCPLifecycleOperatorReady, AIGatewayReady
# ModelsAsAServiceReady stays False until step 5M is done; its .message says what is missing.
# Expect False/Removed: TrainerReady, TrainingOperatorReady (unless enabled)

# Toggle a single component later:
oc patch dsc default-dsc --type=merge -p '{"spec":{"components":{"trainer":{"managementState":"Managed"}}}}'
```

---

## 5M. MaaS database and namespace labels *(Workflow A only)*

MaaS needs PostgreSQL 14+ (API keys, subscriptions). In 3.5, MaaS workloads live in `redhat-ai-gateway-infra`. This is a POC database; for production, use RDS, Crunchy Postgres, or similar, and create only the `maas-db-config` secret (5M.3).

### 5M.1 Namespace and credentials

```bash
oc create namespace redhat-ai-gateway-infra 2>/dev/null || true
oc get maastenantconfig default-tenant -n models-as-a-service -o jsonpath='{.status.infraNamespace}{"\n"}' 2>/dev/null   # expect redhat-ai-gateway-infra

export PG_USER=maas PG_DB=maas
export PG_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
export PG_IMAGE=$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[0].spec.relatedImages[?(@.name=="postgresql_16_image")].image}' 2>/dev/null)
export PG_IMAGE=${PG_IMAGE:-registry.redhat.io/rhel9/postgresql-16:latest}
echo "PG_IMAGE=$PG_IMAGE"
```

### 5M.2 PostgreSQL

```bash
oc apply -n redhat-ai-gateway-infra -f - <<'EOF'
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  labels:
    app: postgres
    purpose: poc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  labels:
    app: postgres
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
EOF

envsubst '${PG_IMAGE} ${PG_USER} ${PG_PASSWORD} ${PG_DB}' <<'EOF' | oc apply -n redhat-ai-gateway-infra -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  labels:
    app: postgres
    purpose: poc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: ${PG_IMAGE}
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRESQL_USER
              value: "${PG_USER}"
            - name: POSTGRESQL_PASSWORD
              value: "${PG_PASSWORD}"
            - name: POSTGRESQL_DATABASE
              value: "${PG_DB}"
          volumeMounts:
            - name: data
              mountPath: /var/lib/pgsql/data
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: "1"
              memory: 1Gi
          readinessProbe:
            exec:
              command: ["pg_isready", "-U", "${PG_USER}", "-d", "${PG_DB}"]
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            exec:
              command: ["pg_isready", "-U", "${PG_USER}", "-d", "${PG_DB}"]
            initialDelaySeconds: 15
            periodSeconds: 10
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: postgres-data
EOF

oc rollout status deployment/postgres -n redhat-ai-gateway-infra --timeout=300s
```

### 5M.3 Database secrets

```bash
oc create secret generic postgres-creds -n redhat-ai-gateway-infra \
  --from-literal=user="$PG_USER" --from-literal=password="$PG_PASSWORD" --from-literal=database="$PG_DB" \
  --dry-run=client -o yaml | oc apply -f -

ENCODED_PASSWORD=$(printf '%s' "$PG_PASSWORD" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
printf '%s' "postgresql://${PG_USER}:${ENCODED_PASSWORD}@postgres.redhat-ai-gateway-infra.svc:5432/${PG_DB}?sslmode=disable" | \
  oc create secret generic maas-db-config -n redhat-ai-gateway-infra --from-file=DB_CONNECTION_URL=/dev/stdin \
    --dry-run=client -o yaml | oc label --local -f - app=maas-api --dry-run=client -o yaml | oc apply -f -

oc rollout restart deployment/maas-api -n redhat-ai-gateway-infra 2>/dev/null || true
unset PG_PASSWORD ENCODED_PASSWORD
```

### 5M.4 Namespace labels for gateway access

The MaaS gateway uses a namespace selector. HTTPRoutes (including maas-api's own) in unlabelled namespaces are rejected with "namespace is not allowed by the parent":

```bash
for ns in redhat-ods-applications redhat-ai-gateway-infra models-as-a-service; do
  oc label namespace "$ns" maas.opendatahub.io/gateway-access=true --overwrite
done
# Add the same label to every namespace where you deploy MaaS models (e.g. "llm" in 10b).
```

```bash
# Checkpoint
oc get dsc default-dsc -o jsonpath='{.status.conditions[?(@.type=="ModelsAsAServiceReady")].status} {.status.conditions[?(@.type=="ModelsAsAServiceReady")].message}{"\n"}'
oc get pods -n redhat-ai-gateway-infra
```

---

## 6. OdhDashboardConfig

Resource: `odhdashboardconfig/odh-dashboard-config` in `redhat-ods-applications`; flags go under `spec.dashboardConfig`. Tiers come from odh-dashboard `rhoai-3.5` source (`techPreviewFlags` = TP, `devTemporaryFeatureFlags` = DP) and the 3.5 release notes.

| Flag | Value | Tier | Purpose |
|---|---|---|---|
| `disableModelRegistry` | false | GA | Model Registry UI |
| `disableModelCatalog` | false | GA | Model Catalog |
| `disableKServeMetrics` | false | GA | Serving metrics |
| `modelAsService` | true (A) / **false (B)** | GA | MaaS UI (default true) |
| `roleManagement` | true | GA | Custom RBAC roles UI (default true in 3.5) |
| `gpuaas` | *(leave alone)* | GA | Infrastructure / GPU page, default **true** |
| `disableLMEval` | false | Deprecated | LM-Eval UI. EvalHub is the replacement. |
| `genAiStudio` | true | TP | GenAI Studio / Playground |
| `mcpCatalog` | true | TP | AI Hub → MCP Servers (needs modelregistry) |
| `mcpRegistry` | true | TP | MCP Registry tab (needs mlflow) |
| `automl` / `autorag` | true | TP | AutoML / AutoRAG |
| `guardrails` | true | TP | Guardrails in deployments / Playground |
| `promptManagement` / `globalProjectPrompts` | true | TP | MLflow prompt registry in Playground |
| `genAiTracing` | true | TP | Playground chat metrics + MLflow traces |
| `llmdTemplates` | true | TP | Unified GenAI deploy wizard (topology templates) |
| `llmGatewayField` | true | TP | Gateway selection in deploy wizard |
| `vLLMDeploymentOnMaaS` | true (A only) | TP | vLLM runtime for MaaS |
| `observabilityDashboard` | true (A only) | TP | MaaS usage dashboard |
| `externalModels` | true (A only) | TP | External models tab (removed in 3.6) |
| `externalVectorStores` | true | TP | Existing vector stores as RAG sources |
| `aiAssetCustomEndpoints` | true | TP | Custom endpoints in AI asset endpoints |
| `connectionTest` | true | TP | "Verify connection" button |
| `deploymentWizardYAMLViewer` | true | TP | YAML view in deploy wizard |
| `toolCalling` | *(default true)* | TP | Validated tool-calling args in catalog |
| `agentOps` | true | TP (undocumented) | Agent ops plugin |
| `agentsCatalog` | true | **DP** | AI Hub → Agents catalog (needs modelregistry) |
| `agentConfigManagement` | true | **DP** | Save Playground configs as agents |
| ~~`maasAuthPolicies`~~ | **never set** | Removed | The CEL webhook rejects the whole patch |
| ~~`disableKueue`, `disableHardwareProfiles`~~ | **never set** | Deprecated | |

```bash
until oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; do sleep 5; done

# GA set
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge -p '{
  "spec": {"dashboardConfig": {
    "disableModelRegistry": false, "disableModelCatalog": false, "disableKServeMetrics": false,
    "modelAsService": true, "roleManagement": true
}}}'

# Technology Preview set (trim to what you need)
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge -p '{
  "spec": {
    "dashboardConfig": {
      "genAiStudio": true, "mcpCatalog": true, "mcpRegistry": true,
      "automl": true, "autorag": true, "guardrails": true,
      "promptManagement": true, "globalProjectPrompts": true, "genAiTracing": true,
      "llmdTemplates": true, "llmGatewayField": true,
      "vLLMDeploymentOnMaaS": true, "observabilityDashboard": true,
      "externalModels": true, "externalVectorStores": true, "aiAssetCustomEndpoints": true,
      "connectionTest": true, "deploymentWizardYAMLViewer": true, "agentOps": true
    },
    "genAiStudioConfig": {"aiAssetCustomEndpoints": {"clusterDomains": [], "externalProviders": true}}
}}'

# Developer Preview (unsupported; only enable deliberately)
# oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge \
#   -p '{"spec":{"dashboardConfig":{"agentsCatalog":true,"agentConfigManagement":true}}}'

# Verify
oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o jsonpath='{.spec.dashboardConfig}' | jq .
echo "Dashboard: https://rh-ai.${APPS_DOMAIN}"
```

---

## 7. Hardware profile (GPU)

```bash
oc apply -f - <<'EOF'
---
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: gpu-profile
    opendatahub.io/description: 'GPU hardware profile for NVIDIA GPU workloads with tolerations'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
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
oc get hardwareprofile gpu-profile -n redhat-ods-applications
```

The profile must keep `scheduling.node.nodeSelector: {nvidia.com/gpu.present: 'true'}` and the toleration `nvidia.com/gpu` / `Exists` / `NoSchedule`, or GPU pods won't schedule.

---

## 8. Object storage (S3)

| Backend | Image | S3 endpoint (in-cluster) | Notes |
|---|---|---|---|
| **SeaweedFS** (used below) | Official: `docker.io/chrislusf/seaweedfs:<tag>`, mirrored at `ghcr.io/chrislusf/seaweedfs:<tag>` (no Quay image) | `http://seaweedfs.<ns>.svc.cluster.local:8333` | The YAML below uses `:latest`; pin a release instead (latest is `4.49`, 2026-10-23) |
| MinIO | `quay.io/minio/minio:latest`, `quay.io/minio/mc:latest` | `http://minio.<ns>.svc.cluster.local:9000` | |
| ODF Ceph RGW | (ODF) | from ObjectBucketClaim | |
| AWS S3 | -- | `https://s3.<region>.amazonaws.com` | Bring your own bucket and keys; skip to 8.3 |

**SeaweedFS image provenance.** Source: <https://github.com/seaweedfs/seaweedfs>, `docker/README.md`, and the Helm chart `k8s/charts/seaweedfs/values.yaml` (default `chrislusf/seaweedfs`).
- CI pushes every release to Docker Hub `chrislusf/seaweedfs` and GHCR `ghcr.io/chrislusf/seaweedfs`. Images published since September 2026 are cosign-signed (keyless).
  ```bash
  cosign verify \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    --certificate-identity-regexp '^https://github.com/seaweedfs/seaweedfs/\.github/workflows/container_release_unified\.yml@' \
    chrislusf/seaweedfs:4.49
  ```
- Anonymous Docker Hub pulls are rate-limited. On busy clusters, use `ghcr.io/chrislusf/seaweedfs:<tag>` or mirror the image.

### 8.1 Deploy SeaweedFS

```bash
export NS=storage S3_ACCESS_KEY=admin S3_SECRET_KEY=$(openssl rand -hex 16) STORAGE_SIZE=100Gi
export S3_ENDPOINT=http://seaweedfs.${NS}.svc.cluster.local:8333
oc create namespace $NS 2>/dev/null || true

envsubst '${S3_ACCESS_KEY} ${S3_SECRET_KEY}' <<'EOF' | oc apply -n $NS -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: seaweedfs-s3-config
  labels:
    app.kubernetes.io/name: seaweedfs
    app.kubernetes.io/component: storage
stringData:
  s3.json: |
    {
      "identities": [
        {
          "name": "admin",
          "credentials": [
            {
              "accessKey": "${S3_ACCESS_KEY}",
              "secretKey": "${S3_SECRET_KEY}"
            }
          ],
          "actions": ["Admin", "Read", "Write", "List", "Tagging"]
        }
      ]
    }
EOF

envsubst '${STORAGE_SIZE}' <<'EOF' | oc apply -n $NS -f -
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: seaweedfs-data
  labels:
    app.kubernetes.io/name: seaweedfs
    app.kubernetes.io/component: storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${STORAGE_SIZE}
EOF

oc apply -n $NS -f - <<'EOF'
# SeaweedFS all-in-one Deployment for OpenShift
#
# Runs master + volume + filer + S3 gateway in a single pod using 'weed server'.
# Suitable for demos and single-node deployments. For production multi-replica
# topology, use the SeaweedFS Helm chart with openshift-values.yaml instead:
#   https://github.com/seaweedfs/seaweedfs/blob/master/k8s/charts/seaweedfs/openshift-values.yaml
#
# OpenShift SCC compliance:
#   - runAsNonRoot: true (no UID specified; OpenShift assigns from namespace range)
#   - drop: ALL capabilities
#   - seccompProfile: RuntimeDefault
#   - PVC storage (no hostPath)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: seaweedfs
  labels:
    app.kubernetes.io/name: seaweedfs
    app.kubernetes.io/component: storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: seaweedfs
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/name: seaweedfs
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: seaweedfs
        image: docker.io/chrislusf/seaweedfs:latest
        imagePullPolicy: IfNotPresent
        command:
        - weed
        args:
        - server
        - -dir=/data
        - -s3
        - -s3.port=8333
        - -s3.config=/etc/seaweedfs/s3.json
        - -master.port=9333
        - -volume.port=8080
        # -volume.max: each S3 bucket/collection needs its own dedicated
        # SeaweedFS volume (default 30GB each), and volumes are NOT shared
        # across collections. `-volume.max=0` ("unlimited, calculated from
        # free disk / default volume size") still only worked out to ~8 on a
        # 200Gi PVC -- SeaweedFS also eagerly pre-allocates several empty,
        # collection-less volumes at startup, so by the time a 2nd bucket in
        # the same namespace needs a volume, all slots were already used and
        # every PutObject failed with "no free volumes left" / "topo failed
        # to pick 1 from 0 node candidates" (confirmed live on cluster-sclg6
        # 2026-09-28: 'datasets' bucket got a volume fine, 'models' -- a 2nd,
        # different bucket in the same namespace -- then failed every write).
        # An explicit generous count avoids the ambiguous "0" auto-calc.
        - -volume.max=50
        - -filer
        - -filer.port=8888
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        ports:
        - name: s3
          containerPort: 8333
          protocol: TCP
        - name: master
          containerPort: 9333
          protocol: TCP
        - name: filer
          containerPort: 8888
          protocol: TCP
        - name: volume
          containerPort: 8080
          protocol: TCP
        resources:
          requests:
            cpu: 100m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 2Gi
        volumeMounts:
        - name: data
          mountPath: /data
        - name: s3-config
          mountPath: /etc/seaweedfs
          readOnly: true
        livenessProbe:
          httpGet:
            path: /cluster/status
            port: master
          initialDelaySeconds: 20
          periodSeconds: 15
        readinessProbe:
          tcpSocket:
            port: s3
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: seaweedfs-data
      - name: s3-config
        secret:
          secretName: seaweedfs-s3-config
---
---
apiVersion: v1
kind: Service
metadata:
  name: seaweedfs-s3
  labels:
    app.kubernetes.io/name: seaweedfs
spec:
  type: ClusterIP
  ports:
  - name: s3
    port: 8333
    targetPort: s3
  - name: master
    port: 9333
    targetPort: master
  - name: filer
    port: 8888
    targetPort: filer
  selector:
    app.kubernetes.io/name: seaweedfs
---
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: seaweedfs-s3
  labels:
    app.kubernetes.io/name: seaweedfs
spec:
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  port:
    targetPort: s3
  to:
    kind: Service
    name: seaweedfs-s3
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: seaweedfs-admin
  labels:
    app.kubernetes.io/name: seaweedfs
spec:
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  port:
    targetPort: master
  to:
    kind: Service
    name: seaweedfs-s3
EOF

oc rollout status deploy/seaweedfs -n $NS --timeout=300s
echo "S3 access key: $S3_ACCESS_KEY  secret key: $S3_SECRET_KEY  (save these)"
```

### 8.2 Create buckets (one Job run per bucket)

Save the Job template once, then run it per bucket:
```bash
cat > create-bucket-job.yaml.tmpl <<'EOF'
# Generic S3 bucket creation job (works with any S3-compatible backend)
# Uses aws-cli instead of MinIO's mc for portability.
---
apiVersion: batch/v1
kind: Job
metadata:
  name: create-bucket
  labels:
    app.kubernetes.io/name: s3-bucket-setup
spec:
  ttlSecondsAfterFinished: 60
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: awscli
        image: docker.io/amazon/aws-cli:latest
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        env:
        - name: AWS_ACCESS_KEY_ID
          value: "${S3_ACCESS_KEY}"
        - name: AWS_SECRET_ACCESS_KEY
          value: "${S3_SECRET_KEY}"
        - name: AWS_DEFAULT_REGION
          value: "us-east-1"
        command: ["/bin/sh", "-c"]
        args:
          - |
            set -e
            ENDPOINT="${S3_ENDPOINT}"
            BUCKET="${BUCKET_NAME}"

            echo "Waiting for S3 endpoint at $ENDPOINT..."
            RETRIES=0
            until aws --endpoint-url "$ENDPOINT" s3 ls 2>/dev/null; do
              RETRIES=$((RETRIES + 1))
              if [ $RETRIES -ge 30 ]; then
                echo "Timeout waiting for S3 endpoint"
                exit 1
              fi
              sleep 3
            done

            echo "S3 endpoint is ready"

            if aws --endpoint-url "$ENDPOINT" s3 ls "s3://$BUCKET" 2>/dev/null; then
              echo "Bucket '$BUCKET' already exists"
            else
              aws --endpoint-url "$ENDPOINT" s3 mb "s3://$BUCKET"
              echo "Bucket '$BUCKET' created"
            fi

            echo "Done!"
      restartPolicy: Never
  backoffLimit: 3
EOF

for BUCKET_NAME in models pipelines; do
  export BUCKET_NAME
  oc delete job/create-bucket -n $NS --ignore-not-found --wait=true
  envsubst '${S3_ACCESS_KEY} ${S3_SECRET_KEY} ${BUCKET_NAME} ${S3_ENDPOINT}' < create-bucket-job.yaml.tmpl | oc create -n $NS -f -
  oc wait --for=condition=complete job/create-bucket -n $NS --timeout=120s
done
```

### 8.3 S3 data connection in a project

This shows up in the dashboard, and is used by pipelines, AutoRAG, and S3-stored models:
```bash
export PROJECT=my-project BUCKET_NAME=models DISPLAY_NAME="SeaweedFS models"
oc new-project $PROJECT 2>/dev/null || true
oc label namespace $PROJECT opendatahub.io/dashboard=true --overwrite

envsubst '${S3_ACCESS_KEY} ${S3_SECRET_KEY} ${S3_ENDPOINT} ${BUCKET_NAME} ${DISPLAY_NAME}' <<'EOF' | oc apply -n $PROJECT -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: aws-connection-minio
  labels:
    opendatahub.io/dashboard: "true"
    opendatahub.io/managed: "true"
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: "${DISPLAY_NAME}"
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "${S3_ACCESS_KEY}"
  AWS_SECRET_ACCESS_KEY: "${S3_SECRET_KEY}"
  AWS_S3_ENDPOINT: "${S3_ENDPOINT}"
  AWS_S3_BUCKET: "${BUCKET_NAME}"
  AWS_DEFAULT_REGION: "us-east-1"
EOF
```

---

## 9. Model sources (OCI / registry URLs)

Use `storageUri: oci://...` (YAML), or in the dashboard a **URI** connection with an `oci://` value.

| Source | Example URL | Support |
|---|---|---|
| Red Hat AI 3 validated modelcars (`registry.redhat.io`, covered by the cluster's global pull secret) | `oci://registry.redhat.io/rhai/modelcar-redhatai-gemma-3-12b-it:3.0` · `oci://registry.redhat.io/rhai/modelcar-openai-whisper-large-v3:3.0` · older: `oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:1.5` | Supported. Check AI Hub → Catalog for current paths and tags. |
| Community modelcar catalog (Quay) | `oci://quay.io/redhat-ai-services/modelcar-catalog:<model-tag>` | Community, unsupported |
| CPU test model (llm-d simulator) | `ghcr.io/llm-d/llm-d-inference-sim:v0.7.1` / `quay.io/opendatahub/llm-d-inference-sim` | Test only. Pin **v0.7.1** (v0.9+ breaks). |
| S3 | `s3://<bucket>/<path>` + S3 data connection | -- |

For a private Quay or other registry, create a pull secret in the project and link it:
```bash
oc create secret docker-registry my-quay-pull --docker-server=quay.io \
  --docker-username='<robot>' --docker-password='<token>' -n $PROJECT
oc secrets link default my-quay-pull --for=pull -n $PROJECT
```

**vLLM runtime image:** use the platform's built-in vLLM ServingRuntime template, which ships the correct 3.5 image. Don't use `quay.io/modh/vllm:rhoai-2.22` (RHOAI 2.22 era) or `rhaiis/vllm-cuda-rhel9:3.3*`.

---

## 10. Deploy a model

**Which CR?** It depends on the runtime, not the RHOAI version:
- **llm-d** (MaaS / distributed inference) → `LLMInferenceService` (`serving.kserve.io/v1alpha1`)
- **vLLM and everything else** (OpenVINO, NIM, MLServer, AutoGluon) → `ServingRuntime` + `InferenceService` (`serving.kserve.io/v1beta1`)

### 10a. vLLM InferenceService (both workflows)

```bash
export PROJECT=my-models
oc new-project $PROJECT 2>/dev/null || oc project $PROJECT
oc label namespace $PROJECT opendatahub.io/dashboard=true --overwrite

# 1. Instantiate the built-in vLLM GPU ServingRuntime template
oc get templates -n redhat-ods-applications | grep -i vllm         # pick the CUDA / NVIDIA one
oc process -n redhat-ods-applications <vllm-cuda-template-name> | oc apply -n $PROJECT -f -
oc get servingruntime -n $PROJECT                                   # note its name -> RUNTIME
export RUNTIME=<servingruntime-name>

# 2. InferenceService (all three hardware-profile annotations are required for the dashboard)
export HWP_RV=$(oc get hardwareprofile gpu-profile -n redhat-ods-applications -o jsonpath='{.metadata.resourceVersion}')
cat <<EOF | oc apply -n $PROJECT -f -
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: qwen3-8b
  labels:
    opendatahub.io/dashboard: "true"
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    openshift.io/display-name: qwen3-8b
    opendatahub.io/hardware-profile-name: gpu-profile
    opendatahub.io/hardware-profile-namespace: redhat-ods-applications
    opendatahub.io/hardware-profile-resource-version: "${HWP_RV}"
spec:
  predictor:
    model:
      modelFormat: { name: vLLM }
      runtime: ${RUNTIME}
      storageUri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:1.5
      args: ["--max-model-len=8192", "--enable-auto-tool-choice", "--tool-call-parser=hermes"]
      resources:
        requests: { cpu: "2", memory: 12Gi, nvidia.com/gpu: "1" }
        limits:   { cpu: "4", memory: 24Gi, nvidia.com/gpu: "1" }
    tolerations:
      - { key: nvidia.com/gpu, operator: Exists, effect: NoSchedule }
EOF

oc wait --for=condition=Ready inferenceservice/qwen3-8b -n $PROJECT --timeout=900s
oc get inferenceservice qwen3-8b -n $PROJECT -o jsonpath='{.status.url}{"\n"}'
```

Tool-call parser by model family: `hermes` (Qwen), `llama3_json` (Llama), `mistral` (Mistral).

### 10b. llm-d LLMInferenceService behind MaaS *(Workflow A only)*

Requires steps 2 and 5M, plus `aigateway.modelsAsAService: Managed`. This example deploys Qwen3-8B in namespace `llm` with two subscriptions (free at 100 tokens/min, premium at 100k tokens/min) for all authenticated users.

```bash
oc create namespace llm 2>/dev/null || true
oc label namespace llm maas.opendatahub.io/gateway-access=true opendatahub.io/dashboard=true --overwrite

# The model (LLMInferenceService). The pinned image line can be removed to use the platform default.
oc apply -n llm -f - <<'EOF'
# Qwen3-8B FP8 (dynamic quantization) on Red Hat AI Inference Server (vLLM CUDA).
# A real, non-simulated 8B-parameter LLM with tool-calling support (hermes parser),
# used across multiple demos (LMEval/EvalHub benchmarks, AutoRAG, NeMo Guardrails,
# financial-loan-demo) per docs/TODO-next-session.md's "Dual Qwen3-8B Endpoint
# Architecture" section.
#
# Sizing note: resource requests/limits below are intentionally smaller than the
# generic "Qwen3-8B needs 8 CPU / 32Gi" guidance in docs/guides/
# INTERACTIVE-MODEL-DEPLOYMENT.md -- that guidance assumes a larger instance type.
# A single g6e.xlarge (4 vCPU / ~32Gi RAM, 1x L40S 48GB VRAM) node cannot fit an
# 8-CPU/32Gi-limit pod once daemonset overhead (GPU Operator, NFD, OVN, etc.) is
# accounted for (allocatable is ~3.5 CPU / ~29Gi). These limits (cpu:3, memory:24Gi)
# fit comfortably on a single g6e.xlarge with room for the DaemonSets already there.
# GPU VRAM (48GB) is not the constraint for an 8B FP8 model (~9GB weights) -- the
# node's CPU/RAM is. If deploying to a larger GPU node type, feel free to raise
# these limits.
#
# NOTE: verify the exact modelcar image tag against the current Red Hat registry
# catalog (registry.redhat.io) before production use -- tags are updated over time.
---
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-8b
  # Namespace set by kustomization.yaml `namespace:` transformer (default: llm).
spec:
  model:
    name: RedHatAI/Qwen3-8B-FP8-dynamic
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:1.5
  replicas: 1
  router:
    route: {}
    gateway:
      refs:
        - name: maas-default-gateway
          namespace: openshift-ingress
  template:
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
    containers:
      - name: main
        image: registry.redhat.io/rhaiis/vllm-cuda-rhel9:3.3.0
        args:
          - "--max-model-len=8192"
          - "--enable-auto-tool-choice"
          - "--tool-call-parser=hermes"
        resources:
          requests:
            cpu: "2"
            memory: 12Gi
          limits:
            cpu: "3"
            memory: 24Gi
            nvidia.com/gpu: "1"
EOF

# MaaS registration, access policy, and subscriptions
oc apply -f - <<'EOF'
---
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSModelRef
metadata:
  name: qwen3-8b
  namespace: llm
spec:
  modelRef:
    kind: LLMInferenceService
    name: qwen3-8b
---
---
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSAuthPolicy
metadata:
  name: qwen3-8b-access
  namespace: models-as-a-service
spec:
  modelRefs:
    - name: qwen3-8b
      namespace: llm
  subjects:
    groups:
      - name: system:authenticated
---
---
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSSubscription
metadata:
  name: qwen3-8b-free
  namespace: models-as-a-service
spec:
  modelRefs:
    - name: qwen3-8b
      namespace: llm
      tokenRateLimits:
        - limit: 100
          window: 1m
  owner:
    groups:
      - name: system:authenticated
  priority: 10
---
---
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSSubscription
metadata:
  name: qwen3-8b-premium
  namespace: models-as-a-service
spec:
  modelRefs:
    - name: qwen3-8b
      namespace: llm
      tokenRateLimits:
        - limit: 100000
          window: 1m
  owner:
    groups:
      - name: system:authenticated
  priority: 20
EOF

oc wait --for=condition=Ready llminferenceservice/qwen3-8b -n llm --timeout=1200s
oc get maasmodelref qwen3-8b -n llm -o jsonpath='{.status.phase}{"\n"}'      # Ready
```

**Verify MaaS end to end** (create an API key, list models, call chat):
```bash
MAAS_HOST="https://maas.${APPS_DOMAIN}"
API_KEY=$(curl -sk -X POST "$MAAS_HOST/maas-api/v1/api-keys" \
  -H "Authorization: Bearer $(oc whoami -t)" -H 'Content-Type: application/json' \
  -d '{"name":"manual-test","subscription":"qwen3-8b-free","expiresIn":"1h"}' | jq -r .key)
echo "API key: ${API_KEY:0:12}..."

curl -sk "$MAAS_HOST/v1/models" -H "Authorization: Bearer $API_KEY" | jq -r '.data[].id'

# Body-based routing: "model" = full id from /v1/models
MODEL_ID=$(curl -sk "$MAAS_HOST/v1/models" -H "Authorization: Bearer $API_KEY" | jq -r '.data[0].id')
curl -sk "$MAAS_HOST/v1/chat/completions" -H "Authorization: Bearer $API_KEY" -H 'Content-Type: application/json' \
  -d "{\"model\":\"$MODEL_ID\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"max_tokens\":50}" | jq .

# Per-model URL routing: "model" = spec.model.name of the LLMInferenceService
curl -sk "$MAAS_HOST/llm/qwen3-8b/v1/chat/completions" -H "Authorization: Bearer $API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"RedHatAI/Qwen3-8B-FP8-dynamic","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}' | jq .

# Exceed the free tier (100 tokens/min) to see HTTP 429 with Retry-After
```

**Known post-install issues to check:**
- HTTP 500 under load: confirm `AUTH_SERVICE_TIMEOUT=2s` on the RHCL subscription (2.1).
- HTTPRoute "not allowed by the parent": add the namespace label (5M.4).
- API key works but calls return 500 `AUTH_FAILURE refId 002`: wrong Authorino `SSL_CERT_FILE` (2.4).
- Gateway OOMKilled: check that `maas-gateway-options` (2Gi) is referenced by the gateway (2.5, 2.7).

> Toolkit shortcuts: `./scripts/deploy-maas-model.sh --model auto`, `./scripts/verify-maas.sh`, `./scripts/diagnose-maas.sh --fix`

---

## 11. Optional add-ons

These need the toolkit repo or the official docs. They aren't required for the base platform.

| Feature | Toolkit shortcut | Official docs (docs.redhat.com, RHOAI 3.5) | Tier |
|---|---|---|---|
| Pipeline server (DSPA) | `./scripts/install-rhoai-35.sh --setup-pipelines` | *Working with AI pipelines* | GA |
| MCP servers (MCPServer CRs) | `./scripts/setup-mcp-servers.sh -n <ns> --non-interactive` | *Working with the MCP catalog* | TP |
| NeMo Guardrails | `./scripts/deploy-nemo-guardrails.sh` | *Enabling AI safety with Guardrails* | GA |
| GPU/vLLM dashboards | `./scripts/deploy-dashboards.sh --dashboard all` | *Monitoring your AI systems* | -- |
| Users | `./scripts/setup-users.sh --num-users 5` | OpenShift *Authentication and authorization* | -- |
| Let's Encrypt TLS | `./scripts/setup-letsencrypt-tls.sh` | -- | -- |

---

## 12. Final verification

```bash
oc get csv -A | grep -v Succeeded | grep -v '^NAMESPACE'        # should be empty
oc get dsci default-dsci -o jsonpath='{.status.phase}{"\n"}'     # Ready
oc get dsc default-dsc -o jsonpath='{.status.phase}{"\n"}'       # Ready
oc get pods -n redhat-ods-applications | grep -vE 'Running|Completed'
oc get hardwareprofile -A
oc get inferenceservice,llminferenceservice -A
```

---

## Workflow B: RHOAI 3.5 without MaaS

Use this when the customer wants the platform (workbenches, pipelines, model serving, Playground, guardrails, evaluation) but **not** the central Models-as-a-Service gateway yet. Follow steps 0–12 above, **skipping 2 and 5M**, with the substitutions below. Everything not mentioned is unchanged.

**What you give up without MaaS:** a single gateway endpoint, self-service API keys, subscriptions and token rate limits, the MaaS usage/showback dashboard, external model egress (OpenAI/Bedrock/Gemini through the gateway), and the vLLM-on-MaaS flag. Each model gets its **own endpoint** per project, secured with OpenShift token authentication (Kubernetes RBAC), with no quotas.

### B.1 Operators (step 1)

Apply only what you need from step 1:

| Operator / setting | Needed without MaaS? | Why |
|---|---|---|
| NFD (1.1) + NVIDIA GPU Operator (1.2) | **Yes** (if GPUs) | GPU workloads |
| cert-manager (1.3) | **Yes** | KServe, OGX |
| OpenShift Service Mesh 3 (1.6) | **Yes, if using OGX / Playground RAG** | OGX dependency |
| Red Hat build of Kueue (1.4) | Optional | Queueing / distributed workloads (DSC `kueue: Unmanaged`), else set `kueue: Removed` |
| Leader Worker Set (1.5) | **Only for llm-d** | Skip if serving with vLLM `InferenceService` only |
| JobSet (1.7) | Only if `trainer: Managed` | |
| User Workload Monitoring (1.10; *built-in, not an operator*: ConfigMap setting) | Recommended | KServe/vLLM metrics in the dashboard |

### B.2 Skip step 2 and step 5M entirely

Don't install RHCL or Kuadrant, Istio for Kuadrant, Authorino TLS, the MaaS gateway, or the MaaS PostgreSQL DB.

> **llm-d note:** in 3.5, Distributed Inference with llm-d lists RHCL, cert-manager and LWS as dependencies, and authentication is required for every llm-d deployment. Without RHCL you must deploy llm-d with `security.opendatahub.io/enable-auth: "false"` (unauthenticated) and provide your own Gateway. **Without MaaS, use vLLM `InferenceService` (B.6).** It needs none of these.

### B.3 RHOAI operator and DSCI (steps 3–4)

Unchanged.

### B.4 DataScienceCluster (instead of `oc apply -f dsc.yaml` in step 5)

Create `dsc.yaml` with the step 5 heredoc, then apply it with MaaS removed:

| Component | Workflow B state |
|---|---|
| `aigateway` (+ `modelsAsAService`) | **Removed** |
| `kserve` | Managed (`RawDeployment`, `Headed`); leave `kserve.modelsAsService` **unset** |
| `kueue` | `Unmanaged` if the Kueue operator is installed, otherwise **Removed** |

```bash
yq '.spec.components.aigateway.managementState = "Removed"
    | .spec.components.aigateway.modelsAsAService.managementState = "Removed"' dsc.yaml | oc apply -f -
# Without the Kueue operator, add:  | .spec.components.kueue.managementState = "Removed"   inside the yq expression

oc get dsc default-dsc -o json | jq -r '.status.conditions[] | "\(.type)=\(.status)"'
# Expect True: Ready, KserveReady, DashboardReady, WorkbenchesReady, OGXReady, ...
# AIGatewayReady / ModelsAsAServiceReady: False/Removed is expected here.
```

### B.5 Dashboard flags (instead of step 6 patches)

Same GA/TP/DP table as step 6, with these differences:

| Flag | Workflow B | Why |
|---|---|---|
| `modelAsService` | **false** | Hides the MaaS UI (it defaults to true) |
| `vLLMDeploymentOnMaaS`, `observabilityDashboard`, `externalModels` | **leave unset/false** | MaaS-only features |
| `genAiStudioConfig.aiAssetCustomEndpoints.externalProviders` | optional | Lets the Playground call external OpenAI-compatible endpoints directly, without MaaS |
| `genAiStudio`, `mcpCatalog`, `guardrails`, `promptManagement`, `genAiTracing`, `automl`, `autorag`, … (TP) | as needed | Work without MaaS |

```bash
until oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; do sleep 5; done

# GA set (MaaS off)
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge -p '{
  "spec": {"dashboardConfig": {
    "disableModelRegistry": false, "disableModelCatalog": false, "disableKServeMetrics": false,
    "modelAsService": false, "roleManagement": true
}}}'

# Technology Preview set without MaaS-only flags (trim to what you need)
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge -p '{
  "spec": {"dashboardConfig": {
    "genAiStudio": true, "mcpCatalog": true, "mcpRegistry": true,
    "automl": true, "autorag": true, "guardrails": true,
    "promptManagement": true, "globalProjectPrompts": true, "genAiTracing": true,
    "externalVectorStores": true, "aiAssetCustomEndpoints": true,
    "connectionTest": true, "deploymentWizardYAMLViewer": true
}}}'
```

### B.6 Deploy models without MaaS (instead of step 10)

Steps 7–9 (hardware profile, storage, model sources) are unchanged. Use **10a (vLLM `InferenceService`)** and skip 10b.

**Dashboard path (recommended):** Project → Deploy model → choose the vLLM NVIDIA GPU runtime, the hardware profile, and the model location (OCI `oci://…` URI connection or S3). Then:
- **Model access**: tick to create an external route (otherwise the model is cluster-internal only).
- **Require token authentication**: tick to protect the endpoint with an OpenShift service-account token.
- **Add as AI asset endpoint**: tick so the model appears in Gen AI studio → AI asset endpoints and the **Playground**.

**CLI path:** the 10a commands create an internal-only endpoint. To expose and secure it the way the dashboard does, toggle the route and auth in the dashboard afterwards (edit the deployment), or set them in YAML **[verify exact keys on your cluster]**:
```yaml
metadata:
  labels:
    networking.kserve.io/visibility: exported        # external route [verify]
  annotations:
    security.opendatahub.io/enable-auth: "true"      # token auth [verify for InferenceService]
```
To confirm, toggle the setting once in the dashboard, then read back what it set: `oc get inferenceservice <name> -n $PROJECT -o yaml | yq '.metadata'`.

**Calling the model:**
```bash
URL=$(oc get inferenceservice qwen3-8b -n $PROJECT -o jsonpath='{.status.url}')
TOKEN=$(oc whoami -t)        # admin testing only; apps should use the token shown in the dashboard / a dedicated SA
curl -sk "$URL/v1/models" -H "Authorization: Bearer $TOKEN" | jq -r '.data[].id'      # the served model name
curl -sk "$URL/v1/chat/completions" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-8b","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}'
```

**Access control without MaaS:** grant app teams access per project with Kubernetes RBAC (namespace roles or service accounts). There are no per-team token quotas. If quotas are needed, that's the trigger to add MaaS (B.9).

### B.7 Guardrails, Playground and OGX without MaaS

- **NeMo Guardrails** points at the model's own endpoint (internal service URL or route) instead of the MaaS gateway. See *Enabling AI safety with Guardrails* in the RHOAI 3.5 docs.
- **Playground**: needs the model added as an AI asset endpoint (B.6) plus `genAiStudio: true`.
- **OGX / AutoRAG**: configure the OGX inference provider with the InferenceService URL (internal `https://<isvc>-predictor.<ns>.svc.cluster.local:8443/v1` or the route), not a MaaS URL.
- Toolkit demos that **require MaaS** (if you later use the repo): `maas-ratelimit-demo`, `deploy-maas-model.sh`, `deploy-external-model.sh`, `verify-maas.sh`.

### B.8 Verification (instead of step 12)

```bash
oc get csv -A | grep -v Succeeded | grep -v '^NAMESPACE'                 # empty
oc get dsc default-dsc -o jsonpath='{.status.phase}{"\n"}'               # Ready
oc get dsc default-dsc -o jsonpath='{.spec.components.aigateway.managementState}{"\n"}'   # Removed
oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o jsonpath='{.spec.dashboardConfig.modelAsService}{"\n"}'  # false
oc get inferenceservice -A
oc get crd | grep -E 'kuadrant|maas' || echo "no MaaS/RHCL CRDs (expected)"
```

### B.9 Adding MaaS later

No reinstall is needed. In order:
1. **Operators:** install Leader Worker Set (1.5), then do all of **step 2** (RHCL, Kuadrant, Istio, Authorino TLS, gateway). Check the RHCL caveat RHOAIENG-76586 first.
2. **DSC:** enable the AI gateway:
   ```bash
   oc patch dsc default-dsc --type=merge -p '{"spec":{"components":{"aigateway":{"managementState":"Managed","modelsAsAService":{"managementState":"Managed"}}}}}'
   oc get dsc default-dsc -o json | jq -r '.status.conditions[]|select(.type|test("AIGateway|ModelsAsAService"))|"\(.type)=\(.status)"'
   ```
3. **Database and labels:** do **step 5M**.
4. **Dashboard:** set `modelAsService: true`. Optionally add the MaaS TP flags (`vLLMDeploymentOnMaaS`, `observabilityDashboard`, `externalModels`).
5. **Models:** MaaS fronts **llm-d `LLMInferenceService`** models (10b). Existing vLLM `InferenceService` models keep working on their own endpoints. To put them behind MaaS, either redeploy them as `LLMInferenceService` (10b), or enable `vLLMDeploymentOnMaaS` (**TP**) and publish them through the MaaS UI.
6. **Verify** with the 10b end-to-end checks, then **repoint consumers** (Playground, NeMo, OGX, apps) from per-model URLs to `https://maas.${APPS_DOMAIN}/…` with an `sk-oai-…` API key.

---

Troubleshooting (toolkit repo): `docs/TROUBLESHOOTING.md`. Known drift and upstream bugs: `docs/COMPATIBILITY-TRACKER.md`. Official docs: <https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5>.
