# RHOAI Toolkit - Step-by-Step 설치 가이드

AWS 환경에서 OpenShift 클러스터 설치부터 RHOAI 3.4 설치, GPU 설정, 모델 배포까지 전체 과정을 안내합니다.

---

## 사전 준비물 체크리스트

시작하기 전에 아래 항목이 준비되었는지 확인하세요.

- [ ] **AWS Access Key ID** (`AKIAV...` 형태)
- [ ] **AWS Secret Access Key**
- [ ] **OpenShift Pull Secret** 파일 (`pull-secret.txt`)
  - 다운로드: https://console.redhat.com/openshift/install/pull-secret
- [ ] **AWS Route53 도메인** (예: `.sandbox1785.opentlc.com`)
- [ ] **AWS Region** (예: `us-east-2`)

---

## Step 0: 로컬 환경 설정

### 0-1. 필수 도구 설치 확인

```bash
# 각 도구가 설치되어 있는지 확인
oc version          # OpenShift CLI (4.14+)
aws --version       # AWS CLI (2.x)
jq --version        # JSON 처리 (1.6+)
yq --version        # YAML 처리 (4.x)
```

> **설치 안 되어 있다면:**
> - oc CLI: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/
> - AWS CLI: `brew install awscli` / https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html
> - jq: `brew install jq` (macOS) 또는 `sudo yum install jq` (Linux)
> - yq: `brew install yq` (macOS) 또는 https://github.com/mikefarah/yq

### 0-2. AWS CLI 설정

```bash
aws configure
```

프롬프트에 아래 값을 입력합니다:

```
AWS Access Key ID [None]: <여기에 Access Key 입력>
AWS Secret Access Key [None]: <여기에 Secret Key 입력>
Default region name [None]: us-east-2
Default output format [None]: json
```

### 0-3. 설정 확인

```bash
# AWS 자격증명 테스트
aws sts get-caller-identity

# Route53 도메인 확인
aws route53 list-hosted-zones --query 'HostedZones[].Name' --output table
```

> **확인 포인트:** `get-caller-identity`가 정상적으로 Account/Arn을 출력하면 성공입니다.

### 0-4. SSH 키 설정

OpenShift 클러스터 설치 시 SSH 키가 필요합니다.

```bash
# SSH 키가 있는지 확인
ls ~/.ssh/id_rsa.pub 2>/dev/null || ls ~/.ssh/id_ed25519.pub 2>/dev/null

# 없으면 새로 생성
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# SSH agent 시작 및 키 등록
eval $(ssh-agent)
ssh-add ~/.ssh/id_ed25519
```

> **참고:** `id_rsa` 키가 이미 있다면 `ssh-add ~/.ssh/id_rsa`를 사용하세요.

### 0-5. Pull Secret 파일 위치 확인

```bash
# pull-secret.txt가 있는 경로 확인
ls -la ~/pull-secret.txt
# 또는 다운로드한 위치
```

> **팁:** 파일 경로를 기억해 두세요. 클러스터 설치 시 입력해야 합니다.

---

## Step 1: OpenShift 클러스터 설치

### 1-1. 툴킷 실행

```bash
cd /path/to/RHOAI-Toolkit
./rhoai-toolkit.sh
```

### 1-2. 메인 메뉴에서 선택

```
╔════════════════════════════════════════════════════════════════╗
║                    Main Menu                                   ║
╚════════════════════════════════════════════════════════════════╝

RHOAI 3.x (Current):
1) Complete Setup (OpenShift + RHOAI 3.x + GPU + MaaS) [Full]   ← 선택하지 마세요
2) Minimal RHOAI 3.x Setup (choose operators) [Flexible]
3) Install RHOAI 3.x [Recommended]                               ← 아직 아닙니다

Management & Tools:
9) Configure Kubeconfig [Connection]
```

**지금 할 일:** 아직 클러스터가 없으므로, 메뉴에서 `1`을 선택합니다.

> **이미 클러스터가 있다면?** → [Step 2](#step-2-클러스터-연결-확인)로 바로 이동하세요.

### 1-3. 설치 과정에서 입력할 값

스크립트가 아래 값들을 물어봅니다. 미리 준비하세요.

| 항목 | 입력 예시 | 설명 |
|------|-----------|------|
| Cluster Name | `my-cluster` | 원하는 클러스터 이름 |
| Base Domain | `sandbox1785.opentlc.com` | Route53 도메인 |
| AWS Region | `us-east-2` | AWS 리전 |
| Master Instance Type | `m6i.xlarge` | 기본값 사용 권장 |
| Worker Instance Type | `m6i.2xlarge` | 기본값 사용 권장 |
| Worker Replicas | `2` | 최소 2개 |
| Pull Secret Path | `/path/to/pull-secret.txt` | Pull Secret 파일 경로 |

### 1-4. 설치 대기

> **소요 시간:** 약 30~45분
>
> 설치 중 아래와 같은 메시지가 나오면 정상입니다:
> ```
> INFO Waiting up to 40m0s for the cluster at https://api.my-cluster.sandbox1785.opentlc.com:6443 to initialize...
> ```

### 1-5. 설치 완료 확인

설치가 완료되면 아래 정보가 표시됩니다:

```
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run
    export KUBECONFIG=/path/to/auth/kubeconfig
INFO Access the OpenShift web-console here:
    https://console-openshift-console.apps.my-cluster.sandbox1785.opentlc.com
```

**반드시 기록할 것:**
- `KUBECONFIG` 경로
- Web Console URL
- `kubeadmin` 패스워드

---

## Step 2: 클러스터 연결 확인

### 2-1. Kubeconfig 설정

```bash
# 설치 직후라면 이미 설정되어 있을 수 있습니다
export KUBECONFIG=/path/to/auth/kubeconfig

# 또는 oc login 사용
oc login https://api.my-cluster.sandbox1785.opentlc.com:6443 \
  -u kubeadmin -p <password>
```

### 2-2. 연결 확인

```bash
oc whoami                    # 현재 로그인 사용자
oc get nodes                 # 노드 목록
oc get clusterversion        # OpenShift 버전
```

> **확인 포인트:**
> - `oc whoami`가 사용자 이름을 출력
> - `oc get nodes`에 Master/Worker 노드가 `Ready` 상태
> - OpenShift 버전이 **4.19+** 인지 확인

---

## Step 3: RHOAI 3.4 설치

### 3-1. 메인 메뉴에서 3번 선택

```bash
./rhoai-toolkit.sh
```

```
3) Install RHOAI 3.x [Recommended]    ← 이것을 선택
```

### 3-2. 버전 선택

```
╔════════════════════════════════════════════════════════════════╗
║              RHOAI Installation - Version Selection            ║
╚════════════════════════════════════════════════════════════════╝

  1) RHOAI 3.4 [Latest GA]          ← 1번 선택
     MaaS GA, MLflow GA, native vLLM multi-node

  2) RHOAI 3.3
```

### 3-3. 설치 진행 확인

스크립트가 자동으로 아래 순서대로 설치합니다:

```
[1/10] ▶ Checking prerequisites...
[2/10] ▶ Scaling cluster nodes...
[3/10] ▶ Installing NFD Operator...
[4/10] ▶ Installing NVIDIA GPU Operator...
[5/10] ▶ Installing Kueue Operator...
[6/10] ▶ Installing cert-manager Operator...
[7/10] ▶ Installing LWS Operator...
[8/10] ▶ Installing RHCL Operator...
[9/10] ▶ Installing RHOAI Operator...
[10/10] ▶ Creating DataScienceCluster...
```

### 3-4. 채널 선택 (중간에 물어봄)

```
Available RHOAI Channels:

Stable Channels:
  1) stable-3.x [default]    ← 기본값(Enter) 권장

Select channel (1-N) [default: 1]:
```

> **권장:** 그냥 Enter를 눌러 `stable-3.x`를 선택하세요.

### 3-5. 설치 완료

```
╔════════════════════════════════════════════════════════════════╗
║          RHOAI 3.4 Installation Complete!                      ║
╚════════════════════════════════════════════════════════════════╝

Dashboard URL: https://data-science-gateway.apps.my-cluster.sandbox1785.opentlc.com
Inference Gateway: https://inference-gateway.apps.my-cluster.sandbox1785.opentlc.com
```

### 3-6. 설치 확인

```bash
oc get datasciencecluster           # Phase: Ready 확인
oc get csv -n redhat-ods-operator   # Succeeded 확인
oc get pods -n redhat-ods-applications | head -20   # Pod 상태 확인
```

> **소요 시간:** 약 20~30분 (오퍼레이터 설치 + DSC 준비)

---

## Step 4: GPU 노드 추가

> **이미 Step 3에서 자동 생성되었을 수 있습니다.** 아래 명령어로 확인하세요.

### 4-1. GPU 노드 확인

```bash
oc get machineset -n openshift-machine-api | grep gpu
oc get nodes -l nvidia.com/gpu.present=true
```

### 4-2. GPU 노드가 없다면

```bash
./rhoai-toolkit.sh
# 7) Create GPU MachineSet 선택
```

또는 직접 실행:

```bash
./scripts/create-gpu-machineset.sh
```

**선택 항목:**

| 항목 | 권장 값 | 설명 |
|------|---------|------|
| Instance Type | `g6e.xlarge` | 1x L40S GPU, 가장 저렴 |
| Spot Instance | `Y` | 비용 절약 (최대 90%) |
| Replicas | `1` | 시작은 1개로 |

### 4-3. GPU 노드 Ready 대기

```bash
# GPU 노드가 Ready될 때까지 확인 (5~10분 소요)
watch "oc get nodes -l nvidia.com/gpu.present=true"
```

### 4-4. GPU 동작 확인

```bash
./rhoai-toolkit.sh
# 8) GPU & ClusterPolicy Management
# 9) Run nvidia-smi on GPU Node
```

> **확인 포인트:** `nvidia-smi`가 GPU 정보를 출력하면 성공

---

## Step 5: 모델 배포 (선택)

### 5-1. Quick Start Wizard 사용

```bash
./rhoai-toolkit.sh
# 6) RHOAI Management
# 6) Quick Start Wizard ✨
```

Wizard가 안내하는 4단계:
1. Dashboard Features 활성화
2. 모델 배포 (선택)
3. Playground에 모델 추가 (선택)
4. MCP Server 설정 (선택)

### 5-2. 또는 직접 모델 배포

```bash
# OCI 이미지에서 직접 배포 (가장 빠름)
./scripts/serve-model.sh

# HuggingFace에서 다운로드 후 배포
./scripts/setup-model-storage.sh         # MinIO 설정
./scripts/download-model.sh s3 Qwen/Qwen3-8B-Instruct   # 모델 다운로드
```

---

## Step 6: MaaS 설정 (선택)

### 6-1. MaaS 설정

```bash
./rhoai-toolkit.sh
# 6) RHOAI Management
# 2) AI Services & Infrastructure
# 1) Setup MaaS
```

또는 직접:

```bash
./scripts/setup-maas.sh
```

### 6-2. MaaS 엔드포인트 확인

```bash
# RHOAI 3.4 통합 MaaS
curl -k https://inference-gateway.apps.my-cluster.sandbox1785.opentlc.com/v1/models
```

---

## 설치 후 확인 명령어 모음

```bash
# 전체 상태 확인
oc get datasciencecluster                          # DSC 상태
oc get csv -A | grep -E "nfd|gpu|kueue|lws|rhcl|rhods"   # 오퍼레이터 상태
oc get nodes -l nvidia.com/gpu.present=true        # GPU 노드
oc get hardwareprofiles -n redhat-ods-applications  # 하드웨어 프로필
oc get gateway -n openshift-ingress                 # MaaS 게이트웨이
oc get inferenceservice -A                          # 배포된 모델
```

---

## 문제 해결

| 증상 | 확인 명령어 | 해결 방법 |
|------|-------------|-----------|
| 클러스터 연결 안됨 | `oc whoami` | `./rhoai-toolkit.sh` → 9번 (Configure Kubeconfig) |
| GPU 노드 NotReady | `oc get nodes` | CSR 승인: `./rhoai-toolkit.sh` → 6 → 7 (Day 2 Operations) |
| GPU Operator 오류 | `oc get csv -n nvidia-gpu-operator` | `./rhoai-toolkit.sh` → 8번 → 4 (Check GPU Operator Status) |
| RHOAI 설치 중 멈춤 | `oc get csv -n redhat-ods-operator` | InstallPlan 확인: `./scripts/check-pending-installplans.sh` |
| 모델 배포 실패 | `oc get pods -n <namespace>` | `./rhoai-toolkit.sh` → 6 → 8 (Troubleshooting) |
| Dashboard 접근 불가 | 브라우저에서 URL 확인 | `oc get route -n redhat-ods-applications` |

> 자세한 문제 해결은 [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)를 참고하세요.

---

## 전체 소요 시간 예상

| 단계 | 소요 시간 | 비고 |
|------|-----------|------|
| Step 0: 환경 설정 | 5~10분 | 도구 설치 제외 |
| Step 1: OpenShift 설치 | 30~45분 | AWS 인프라 생성 포함 |
| Step 2: 연결 확인 | 2분 | |
| Step 3: RHOAI 설치 | 20~30분 | 오퍼레이터 10개 설치 |
| Step 4: GPU 노드 | 5~10분 | 노드 프로비저닝 |
| Step 5: 모델 배포 | 5~15분 | 모델 크기에 따라 다름 |
| **합계** | **약 1시간~1시간 30분** | |
