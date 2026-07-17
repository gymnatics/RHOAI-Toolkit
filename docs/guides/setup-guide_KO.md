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
- [ ] **HuggingFace Token** (gated 모델 사용 시 필수, 선택사항)
  - Gemma 4 E2B (`google/gemma-4-E2B-it`) — Apache 2.0, 토큰 **불필요**
  - Llama, Mistral 등 gated 모델 — 토큰 **필수**
  - 발급: https://huggingface.co/settings/tokens
  - 설정: `export HF_TOKEN=hf_your_token_here` (`.bashrc` 또는 `.zshrc`에 추가 권장)

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

### 5-1. 프리셋 모델 빠른 배포

```bash
./scripts/serve-model.sh
```

인수 없이 실행하면 프리셋 메뉴가 나옵니다:

```
1) Gemma 4 E2B (google/gemma-4-E2B-it)  — 1 GPU, 5B, Apache 2.0
2) Qwen2.5-Coder-7B (OCI ModelCar)            — 코딩 특화, 1 GPU
3) Custom S3 model
4) Custom PVC model
5) Custom OCI model
```

### 5-2. 인터랙티브 배포 (더 많은 옵션)

```bash
./rhoai-toolkit.sh
# 6) RHOAI Management → 1) Deploy Model
```

런타임 선택 (llm-d, vLLM, vLLM-Community, vLLM-Gemma4, vLLM-Omni)부터 모델 카탈로그 (9개 프리셋), 네임스페이스, 리소스, tool-calling, 인증까지 단계별로 설정합니다.

스토리지 옵션: **OCI, S3 (MinIO), PVC, HuggingFace URL** 모두 지원.

### 5-3. CLI 자동화 (스크립트/파이프라인용)

```bash
# serve-model.sh CLI 모드 (mode name path [vllm_args])
./scripts/serve-model.sh oci qwen3-4b oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b
./scripts/serve-model.sh s3 qwen3-8b Qwen/Qwen3-8B-Instruct
./scripts/serve-model.sh hf gemma4-e2b google/gemma-4-E2B-it  # Apache 2.0, 토큰 불필요

# 환경변수로 네임스페이스/런타임 지정
NAMESPACE=my-project RUNTIME=vllm-gemma4 \
  ./scripts/serve-model.sh hf gemma4-e2b google/gemma-4-E2B-it

# 추가 vLLM 인수
./scripts/serve-model.sh oci my-model oci://quay.io/... "--max-model-len 8192 --enable-auto-tool-choice"
```

지원 모드:

| 모드 | 설명 | URI 형식 |
|------|------|----------|
| `oci` | OCI ModelCar 레지스트리 | `oci://registry.redhat.io/...` |
| `s3` | S3 (MinIO/AWS) 스토리지 | 상대 경로 (예: `Qwen/Qwen3-8B`) |
| `pvc` | PVC 볼륨 | 상대 경로 (예: `meta-llama/...`) |
| `hf` | HuggingFace 모델 | 모델 ID (예: `google/gemma-4-E2B-it`) |

환경변수: `NAMESPACE` (default: demo), `RUNTIME` (default: vllm), `HF_TOKEN`, `HF_TOKEN_SECRET`

### 5-4. HuggingFace 모델 다운로드 후 S3 배포

```bash
./scripts/setup-model-storage.sh                          # MinIO 설정
./scripts/download-model.sh s3 Qwen/Qwen3-8B-Instruct    # 모델 다운로드
./scripts/serve-model.sh s3 qwen3-8b Qwen/Qwen3-8B-Instruct  # 배포
```

### 5-5. Quick Start Wizard

```bash
./rhoai-toolkit.sh
# 6) RHOAI Management → 6) Quick Start Wizard ✨
```

Wizard가 안내하는 4단계:
1. Dashboard Features 활성화
2. 모델 배포 (선택)
3. Playground에 모델 추가 (선택)
4. MCP Server 설정 (선택)

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

## 클러스터 인스턴스 관리 (AWS)

Red Hat Demo Platform 등 sandbox 환경에서는 인스턴스 상태가 포탈과 동기화되지 않을 수 있습니다. 아래 스크립트로 모든 EC2 인스턴스를 일괄 관리할 수 있습니다.

> **전제 조건:** 이 스크립트는 OpenShift를 설치한 디렉토리에서 실행해야 합니다.
> installer kubeconfig(`openshift-cluster-install/auth/kubeconfig`)의 client certificate를 사용하여
> 클러스터 재시작 후 OAuth 복구 전에도 인증할 수 있습니다.

```bash
# 상태 확인
./restart-cluster-instances.sh status

# 전체 재시작 (stop → start → API 대기 → 오퍼레이터 안정화)
./restart-cluster-instances.sh restart

# 정지만
./restart-cluster-instances.sh stop

# 시작만
./restart-cluster-instances.sh start
```

> **동작 흐름 (start/restart):**
> 1. Pre-flight: installer kubeconfig(client certificate) 확인
> 2. `metadata.json`에서 클러스터 infra ID/리전 자동 감지
> 3. EC2 인스턴스 stop/start
> 4. Phase 1: API 서버 healthz 대기
> 5. Phase 2: kubelet CSR 자동 승인 (client cert 인증, OAuth 불필요)
> 6. Phase 3: OAuth/Ingress 복구 대기
> 7. Phase 4: oc login + 잔여 CSR 승인 + 오퍼레이터 안정화

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
