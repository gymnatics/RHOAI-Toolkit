# Compact Cluster + GPU Worker Setup Guide (RHOAI 3.4)

OpenShift Compact Cluster (3-node) + GPU Worker 1대로 RHOAI 3.4를 설치하는 가이드.
총 4대의 EC2 인스턴스로 Master/Worker 역할을 겸하면서 GPU 모델 서빙까지 운영한다.

> 이 문서만으로 전체 설치 과정을 수행할 수 있도록 모든 YAML과 명령어를 포함한다.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Compact Cluster (4 nodes)                       │
│                                                                     │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐       │
│  │  Master+Worker 0 │ │  Master+Worker 1 │ │  Master+Worker 2 │       │
│  │  m6a.4xlarge     │ │  m6a.4xlarge     │ │  m6a.4xlarge     │       │
│  │  16 vCPU / 64 GB │ │  16 vCPU / 64 GB │ │  16 vCPU / 64 GB │       │
│  │                  │ │                  │ │                  │       │
│  │  • etcd          │ │  • etcd          │ │  • etcd          │       │
│  │  • API Server    │ │  • API Server    │ │  • API Server    │       │
│  │  • Scheduler     │ │  • Scheduler     │ │  • Scheduler     │       │
│  │  ─────────────── │ │  ─────────────── │ │  ─────────────── │       │
│  │  • RHOAI Ops     │ │  • Router        │ │  • Monitoring    │       │
│  │  • KServe        │ │  • OAuth         │ │  • Demo Apps     │       │
│  │  • MaaS Gateway  │ │  • Model (CPU)   │ │  • MinIO         │       │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘       │
│                                                                     │
│  ┌─────────────────┐                                                │
│  │  GPU Worker      │  taint: nvidia.com/gpu:NoSchedule             │
│  │  g6e.4xlarge     │  → GPU 요청 파드만 스케줄 가능                    │
│  │  16 vCPU / 64 GB │                                                │
│  │  L40S 48GB x 1   │                                                │
│  │                  │                                                │
│  │  • vLLM (LLM)    │                                                │
│  │  • GPU Operator   │                                                │
│  └─────────────────┘                                                │
└─────────────────────────────────────────────────────────────────────┘
```

### vs Standard Cluster

| 항목 | Standard (8대) | Compact (4대) |
|------|---------------|---------------|
| Master | 3대 (control-plane only) | 3대 (control-plane + worker) |
| Worker | 3~4대 | 0대 |
| GPU Worker | 1대 | 1대 |
| 총 인스턴스 | 7~8대 | **4대** |
| 비용 | 100% | **~50%** |
| mastersSchedulable | false | **true** |
| 가용성 | 높음 | 데모/개발 수준 |

---

## 전체 설치 순서 요약

| Step | 내용 | 소요 시간 |
|------|------|----------|
| 1 | OpenShift Compact Cluster 설치 (worker=0) | ~40분 |
| 2 | GPU Worker MachineSet 추가 | ~10분 |
| 3 | NFD Operator 설치 | ~3분 |
| 4 | NVIDIA GPU Operator 설치 | ~5분 |
| 5 | cert-manager Operator 설치 | ~3분 |
| 6 | Kueue Operator 설치 | ~3분 |
| 7 | LWS Operator 설치 (llm-d용) | ~3분 |
| 8 | Service Mesh 3 + RHCL 설치 (MaaS용) | ~10분 |
| 9 | User Workload Monitoring 활성화 | ~1분 |
| 10 | RHOAI Operator 설치 | ~10분 |
| 11 | DataScienceCluster 생성 | ~5분 |
| 12 | MaaS Gateway + Dashboard 설정 | ~3분 |
| 13 | Hardware Profile 생성 | ~1분 |
| 14 | 검증 | ~5분 |

---

## Step 1: OpenShift Compact Cluster 설치

`install-config.yaml`에서 **worker replicas를 0**으로 설정하면
OpenShift installer가 자동으로 `mastersSchedulable: true`를 적용한다.

```yaml
apiVersion: v1
baseDomain: example.com
metadata:
  name: my-cluster
compute:
- name: worker
  replicas: 0              # Compact: worker VM 생성 안 함
  platform:
    aws:
      type: m6a.4xlarge
controlPlane:
  name: master
  replicas: 3              # Master 3대가 worker 역할 겸임
  platform:
    aws:
      type: m6a.4xlarge    # 16 vCPU, 64 GB (최소 권장)
networking:
  networkType: OVNKubernetes
platform:
  aws:
    region: us-east-2
pullSecret: '<pull-secret>'
sshKey: '<ssh-public-key>'
```

```bash
openshift-install create cluster --dir=./install-dir --log-level=info
```

설치 완료 후 확인:

```bash
# Master가 schedulable인지 확인
oc get scheduler cluster -o jsonpath='{.spec.mastersSchedulable}'
# → true

# 노드가 3개이고 모두 master,worker 역할인지 확인
oc get nodes
# NAME                  STATUS   ROLES                  AGE
# master-0.xxx          Ready    control-plane,master,worker   ...
# master-1.xxx          Ready    control-plane,master,worker   ...
# master-2.xxx          Ready    control-plane,master,worker   ...
```

---

## Step 2: GPU Worker MachineSet 추가

기존 Master MachineSet에서 클러스터 정보를 추출한 후 GPU MachineSet을 생성한다.

```bash
# 클러스터 ID, AMI, 서브넷 등 기존 MachineSet에서 추출
CLUSTER_ID=$(oc get -o jsonpath='{.status.infrastructureName}' infrastructure cluster)
REGION=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.placement.region}')
AZ="${REGION}a"
AMI_ID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.ami.id}')
IAM_PROFILE=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.iamInstanceProfile.id}')
```

GPU MachineSet 적용:

```yaml
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  name: <CLUSTER_ID>-gpu-worker-<AZ>    # 예: my-cluster-abc12-gpu-worker-us-east-2a
  namespace: openshift-machine-api
  labels:
    machine.openshift.io/cluster-api-cluster: <CLUSTER_ID>
  annotations:
    machine.openshift.io/GPU: '1'
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: <CLUSTER_ID>
      machine.openshift.io/cluster-api-machineset: <CLUSTER_ID>-gpu-worker-<AZ>
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: <CLUSTER_ID>
        machine.openshift.io/cluster-api-machine-role: gpu-worker
        machine.openshift.io/cluster-api-machine-type: gpu-worker
        machine.openshift.io/cluster-api-machineset: <CLUSTER_ID>-gpu-worker-<AZ>
        node-role.kubernetes.io/gpu-worker: ''
    spec:
      metadata:
        labels:
          node-role.kubernetes.io/gpu-worker: ''
      taints:
        - effect: NoSchedule
          key: nvidia.com/gpu
      providerSpec:
        value:
          apiVersion: machine.openshift.io/v1beta1
          kind: AWSMachineProviderConfig
          ami:
            id: <AMI_ID>
          instanceType: g6e.4xlarge       # L40S GPU 1개, 16 vCPU, 64 GB
          placement:
            availabilityZone: <AZ>
            region: <REGION>
          blockDevices:
            - ebs:
                encrypted: true
                volumeSize: 300
                volumeType: gp3
          credentialsSecret:
            name: aws-cloud-credentials
          iamInstanceProfile:
            id: <IAM_PROFILE>
          securityGroups:
            - filters:
                - name: 'tag:Name'
                  values:
                    - <CLUSTER_ID>-node
            - filters:
                - name: 'tag:Name'
                  values:
                    - <CLUSTER_ID>-lb
          subnet:
            filters:
              - name: 'tag:Name'
                values:
                  - <CLUSTER_ID>-private-<AZ>
          tags:
            - name: kubernetes.io/cluster/<CLUSTER_ID>
              value: owned
          userDataSecret:
            name: worker-user-data
```

> Toolkit 사용 시: `./scripts/create-gpu-machineset.sh --instance-type g6e.4xlarge --az <AZ> --replicas 1 --apply`

GPU 노드 Ready 대기 (약 5~10분):

```bash
oc get machines -n openshift-machine-api -w
oc get nodes -l node-role.kubernetes.io/gpu-worker
```

### GPU Taint 동작 원리

위 MachineSet에서 `taints`를 명시적으로 설정한다 (GPU Operator가 자동 추가하는 것이 아님):

```
GPU 요청 파드:  resources.limits.nvidia.com/gpu: 1
  → KServe/vLLM이 자동으로 toleration 추가 → GPU 노드에 스케줄

일반 파드:  GPU 요청 없음
  → toleration 없음 → GPU 노드 스케줄 불가 → Master 노드에 스케줄
```

---

## Step 3: NFD (Node Feature Discovery) Operator 설치

GPU 하드웨어를 감지하여 노드에 라벨을 부여한다.

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

Operator Ready 대기:

```bash
oc get csv -n openshift-nfd -w
# nfd.xxx   Succeeded 가 될 때까지 대기
```

NFD Instance 생성:

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

---

## Step 4: NVIDIA GPU Operator 설치

GPU 드라이버와 Device Plugin을 자동 설치한다.

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

Operator Ready 대기:

```bash
oc get csv -n nvidia-gpu-operator -w
# gpu-operator-certified.xxx   Succeeded
```

ClusterPolicy 생성 (GPU 드라이버, Device Plugin, DCGM 등 구성):

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
    runtimeClass: nvidia
    initContainer: {}
  driver:
    enabled: true
    useNvidiaDriverCRD: false
    licensingConfig:
      nlsEnabled: true
      secretName: ''
    kernelModuleType: auto
    certConfig:
      name: ''
    upgradePolicy:
      autoUpgrade: true
      maxParallelUpgrades: 1
      maxUnavailable: 25%
      drain:
        enable: false
        deleteEmptyDir: false
        force: false
        timeoutSeconds: 300
  devicePlugin:
    enabled: true
    config:
      name: ''
      default: ''
    mps:
      root: /run/nvidia/mps
  dcgm:
    enabled: true
  dcgmExporter:
    enabled: true
    serviceMonitor:
      enabled: true
  gfd:
    enabled: true
  toolkit:
    enabled: true
    installDir: /usr/local/nvidia
  validator:
    plugin:
      env: []
  nodeStatusExporter:
    enabled: true
  cdi:
    enabled: true
    default: false
  migManager:
    enabled: true
    config:
      default: all-disabled
      name: default-mig-parted-config
  mig:
    strategy: single
  vgpuDeviceManager:
    enabled: true
    config:
      default: default
  sandboxDevicePlugin:
    enabled: true
  sandboxWorkloads:
    enabled: false
    defaultWorkload: container
  vfioManager:
    enabled: true
  vgpuManager:
    enabled: false
  gdrcopy:
    enabled: false
  gds:
    enabled: false
  daemonsets:
    updateStrategy: RollingUpdate
    rollingUpdate:
      maxUnavailable: '1'
  kataManager:
    config:
      artifactsDir: /opt/nvidia-gpu-operator/artifacts/runtimeclasses
EOF
```

GPU 노드에서 드라이버 로딩 확인 (GPU Worker Ready 이후):

```bash
oc get pods -n nvidia-gpu-operator
oc get nodes -l nvidia.com/gpu.present=true
```

---

## Step 5: cert-manager Operator 설치

KServe, RHCL 등에서 사용하는 TLS 인증서를 자동 관리한다.

```bash
oc create namespace cert-manager-operator 2>/dev/null || true

oc apply -f - <<'EOF'
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
oc get csv -n cert-manager-operator -w
# cert-manager-operator.xxx   Succeeded
```

---

## Step 6: Kueue Operator 설치

워크로드 스케줄링 및 리소스 큐 관리를 담당한다.

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
oc get csv -n openshift-operators -w | grep kueue
# kueue-operator.xxx   Succeeded
```

---

## Step 7: LWS (LeaderWorkerSet) Operator 설치

llm-d 분산 추론에 필요하다.

```bash
oc create namespace openshift-lws-operator 2>/dev/null || true

oc apply -f - <<'EOF'
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
oc get csv -n openshift-lws-operator -w
# leader-worker-set.xxx   Succeeded
```

LWS Instance 생성:

```bash
oc apply -f - <<'EOF'
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

---

## Step 8: Service Mesh 3 + RHCL (Kuadrant) 설치

MaaS API Gateway와 인증(Authorino)을 담당한다.

### 8-1. Service Mesh 3 Operator

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

InstallPlan 수동 승인 (Manual approval):

```bash
# Pending InstallPlan 확인
oc get installplan -n openshift-operators

# Service Mesh InstallPlan 승인
PLAN=$(oc get installplan -n openshift-operators -o json | \
  jq -r '.items[] | select(.spec.approved==false) | select(.spec.clusterServiceVersionNames[] | contains("servicemeshoperator3")) | .metadata.name')
oc patch installplan "$PLAN" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
```

```bash
oc get csv -n openshift-operators | grep servicemesh
# servicemeshoperator3.xxx   Succeeded
```

### 8-2. RHCL (Kuadrant) Operator

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

```bash
oc get csv -n kuadrant-system -w
# rhcl-operator.xxx   Succeeded
```

### 8-3. Kuadrant Instance + Authorino TLS

```bash
# Kuadrant CR
oc apply -f - <<'EOF'
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
EOF

sleep 10

# Authorino TLS 설정
oc annotate svc/authorino-authorino-authorization \
  service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
  -n kuadrant-system 2>/dev/null || true

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

### 8-4. Istio 설정 (Kuadrant AuthPolicy 연동)

```bash
oc create namespace istio-system 2>/dev/null || true
oc create namespace istio-cni 2>/dev/null || true

# Istio 버전 확인 (이미 설치된 경우)
ISTIO_VERSION=$(oc get istio -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null || echo "v1.26.2")

# IstioCNI
oc apply -f - <<EOF
apiVersion: sailoperator.io/v1
kind: IstioCNI
metadata:
  name: default
  namespace: istio-system
spec:
  namespace: istio-cni
  version: $ISTIO_VERSION
EOF

# IstioCNI Ready 대기
oc wait istiocni/default -n istio-cni --for=condition=Ready --timeout=120s 2>/dev/null || sleep 30

# Istio
oc apply -f - <<EOF
apiVersion: sailoperator.io/v1
kind: Istio
metadata:
  name: default
  namespace: istio-system
spec:
  namespace: istio-system
  version: $ISTIO_VERSION
EOF

# GatewayClass
oc apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-default
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
```

Kuadrant Operator가 Istio를 인식하도록 재시작:

```bash
oc delete pod -n kuadrant-system -l app.kubernetes.io/name=kuadrant-operator 2>/dev/null || true
sleep 20

# Kuadrant Ready 확인
oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# → True
```

---

## Step 9: User Workload Monitoring 활성화

RHOAI 메트릭 수집에 필요하다.

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

## Step 10: RHOAI Operator 설치

```bash
# Namespace + OperatorGroup
oc create namespace redhat-ods-operator 2>/dev/null || true

oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
EOF
```

사용 가능한 채널 확인:

```bash
oc get packagemanifest rhods-operator -n openshift-marketplace \
  -o jsonpath='{.status.channels[*].name}'
# 예: fast-3.x  stable  stable-3.2  stable-3.3  stable-3.4  stable-3.x
```

Subscription 생성 (채널은 `stable-3.x` 또는 `stable-3.4` 권장):

```bash
oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  name: rhods-operator
  channel: stable-3.x          # 또는 stable-3.4
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

```bash
oc get csv -n redhat-ods-operator -w
# rhods-operator.3.4.0   Succeeded
```

---

## Step 11: DataScienceCluster 생성

RHOAI의 모든 컴포넌트를 정의하는 핵심 CR이다.

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
      argoWorkflowsControllers:
        managementState: Managed

    kserve:
      managementState: Managed
      modelsAsService:
        managementState: Managed          # MaaS GA (3.4)

    # Kueue는 별도 Operator(RHBOK)를 사용하므로 Unmanaged
    kueue:
      defaultClusterQueueName: default
      defaultLocalQueueName: default
      managementState: Unmanaged

    ray:
      managementState: Managed

    # Training Operator - JobSet operator 필요, 필요시 Managed로 변경
    trainingoperator:
      managementState: Removed

    modelregistry:
      managementState: Managed
      registriesNamespace: rhoai-model-registries

    trustyai:
      managementState: Managed

    feastoperator:
      managementState: Managed

    llamastackoperator:
      managementState: Managed

    # MLflow GA (3.4)
    mlflowoperator:
      managementState: Managed
EOF
```

Ready 대기:

```bash
# phase가 Ready가 될 때까지 대기 (약 5~10분)
oc get datasciencecluster default-dsc -w
# NAME          PHASE   AGE
# default-dsc   Ready   5m
```

---

## Step 12: MaaS Gateway + Dashboard 설정

### 12-1. Inference Gateway 생성

```bash
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster \
  -o jsonpath='{.spec.domain}' | sed 's/^apps\.//')

# GatewayClass
oc apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-gateway-controller
spec:
  controllerName: openshift.io/gateway-controller/v1
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF

# MaaS Default Gateway
oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: maas-default-gateway
  namespace: openshift-ingress
spec:
  gatewayClassName: openshift-gateway-controller
  listeners:
    - allowedRoutes:
        namespaces:
          from: All
      hostname: maas-api.apps.${CLUSTER_DOMAIN}
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

# Inference Gateway (llm-d)
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
      hostname: inference-gateway.apps.${CLUSTER_DOMAIN}
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

echo "MaaS endpoint: https://maas-api.apps.${CLUSTER_DOMAIN}"
echo "Inference endpoint: https://inference-gateway.apps.${CLUSTER_DOMAIN}"
```

### 12-2. Dashboard Feature 활성화

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
        "modelAsService": true,
        "disableLMEval": false
      }
    }
  }'
```

---

## Step 13: Hardware Profile 생성

RHOAI Dashboard에서 GPU를 선택할 수 있도록 Hardware Profile을 생성한다.

```bash
oc apply -f - <<'EOF'
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

---

## Step 14: 검증

```bash
# 노드 상태 (4개: Master+Worker 3 + GPU Worker 1)
oc get nodes

# Cluster Operators (전부 Available=True)
oc get co | grep -v "True.*False.*False"

# RHOAI
oc get datasciencecluster
oc get csv -n redhat-ods-operator

# 필수 Operators
oc get csv -A | grep -E "nfd|gpu-operator|kueue|leader-worker|cert-manager|rhcl|rhods|servicemesh"

# GPU
oc get nodes -l nvidia.com/gpu.present=true

# MaaS Gateway
oc get gateway -n openshift-ingress

# Hardware Profile
oc get hardwareprofiles -n redhat-ods-applications

# Dashboard URL
echo "https://$(oc get route data-science-gateway -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null || echo "data-science-gateway.apps.$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' | sed 's/^apps\.//')")"

# 리소스 사용률
oc adm top nodes
```

---

## 실측 리소스 사용률

m6a.4xlarge Master 노드 기준, RHOAI + 데모 앱 + 모델 2개 운영:

| 항목 | Master-0 | Master-1 | Master-2 | GPU Worker |
|------|---------|---------|---------|------------|
| CPU 실사용 | 11% | 33% | 16% | 1% |
| CPU 요청 | 80% | 66% | 64% | 32% |
| Memory 실사용 | 32% | 39% | 32% | 12% |
| Memory 요청 | 47% | 40% | 32% | 56% |
| Running Pods | 93 | 94 | 98 | 24 |

---

## 기존 Standard Cluster → Compact 전환

재설치 없이 기존 클러스터를 Compact로 전환할 수 있다:

```bash
# 1. Master를 schedulable로 변경
oc patch scheduler cluster --type=merge \
  -p '{"spec":{"mastersSchedulable":true}}'

# 2. Worker MachineSet을 0으로 스케일다운 (drain 자동 수행)
oc scale machineset <worker-machineset-name> \
  -n openshift-machine-api --replicas=0

# 3. 워크로드가 Master 노드로 재스케줄되는지 확인
oc get pods -A -o wide
```

drain이 stuck되면 finalizer 제거로 강제 삭제:

```bash
oc patch machine <machine-name> -n openshift-machine-api \
  --type=merge -p '{"metadata":{"finalizers":null}}'
```

---

## Limitations

| 항목 | 설명 |
|------|------|
| HA 제한 | Master 1대 장애 시 etcd 쿼럼은 유지(2/3)되나 워크로드 capacity 감소 |
| 리소스 경합 | etcd I/O와 워크로드가 같은 노드에서 경합 가능 (데모 수준에서는 문제 없음) |
| 공식 지원 | Compact Cluster 자체는 Red Hat 지원 구성이나, RHOAI와의 조합은 테스트 매트릭스에 없을 수 있음 |
| 확장성 | 워크로드 증가 시 Worker MachineSet을 다시 스케일업하여 Standard로 전환 가능 |
| llm-d 분산 추론 | OCP 4.20+ 필요 |

## Operator 요약 테이블

| Operator | Namespace | Channel | Source | 용도 |
|----------|-----------|---------|--------|------|
| NFD | openshift-nfd | stable | redhat-operators | GPU 하드웨어 감지 |
| NVIDIA GPU | nvidia-gpu-operator | stable | certified-operators | GPU 드라이버/런타임 |
| cert-manager | cert-manager-operator | stable-v1 | redhat-operators | TLS 인증서 관리 |
| Kueue | openshift-operators | stable-v1.3 | redhat-operators | 워크로드 스케줄링 |
| LWS | openshift-lws-operator | stable-v1.0 | redhat-operators | llm-d 분산 추론 |
| Service Mesh 3 | openshift-operators | stable | redhat-operators | Istio (MaaS 인프라) |
| RHCL (Kuadrant) | kuadrant-system | stable | redhat-operators | MaaS API Gateway/Auth |
| RHOAI | redhat-ods-operator | stable-3.x | redhat-operators | OpenShift AI 본체 |
