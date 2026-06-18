# hyo-rhoai-skills

Red Hat OpenShift AI (RHOAI) 모델 배포 및 운영을 위한 실전 AI 스킬 모음입니다.

Red Hat Ecosystem Engineering의 [rh-ai-engineer](https://github.com/RHEcosystemAppEng/agentic-collections) 스킬과 OpenShift AI에서 실제로 겪는 모델 다운로드 실패 문제를 해결하는 커스텀 **hf-model-deploy** 스킬을 결합한 레포지토리입니다.

## 설치 방법

### Lola 사용 (추천)

```bash
lola mod add https://github.com/hyogrin/hyo-rhoai-skills.git
lola install hyo-rhoai-skills -a cursor
```

### 전역 설치 (모든 프로젝트에 적용)

```bash
lola install hyo-rhoai-skills -a cursor --scope user
```

### .lola-req 사용 (선언형 관리)

```
https://github.com/hyogrin/hyo-rhoai-skills.git@main
```

```bash
lola sync
```

### 수동 설치

```bash
cp -r skills/* /path/to/your-project/.cursor/skills/
```

## 제공 스킬

### rh-ai-engineer 스킬 (Red Hat Ecosystem Engineering 원본)

| 스킬 | 설명 |
|------|------|
| `/ds-project-setup` | Data Science Project 생성 및 구성 (네임스페이스, 데이터 연결, 파이프라인 서버, 모델 서빙) |
| `/workbench-manage` | Jupyter 노트북 Workbench 생성 및 관리 |
| `/model-deploy` | vLLM, NIM, Caikit+TGIS 런타임으로 AI/ML 모델 배포 |
| `/model-registry` | Model Registry에서 ML 모델 등록, 버전 관리, 프로모션 |
| `/pipeline-manage` | Data Science Pipelines 생성, 실행, 스케줄, 모니터링 |
| `/nim-setup` | NVIDIA NIM 플랫폼 구성 (NGC 인증, Account CR) |
| `/serving-runtime-config` | 커스텀 ServingRuntime CR 구성 |
| `/debug-inference` | 실패하거나 느린 InferenceService 트러블슈팅 |
| `/ai-observability` | 모델 성능, GPU 사용률, 클러스터 상태, 분산 트레이싱 분석 |
| `/model-monitor` | TrustyAI 편향 감지(SPD, DIR) 및 데이터 드리프트 모니터링 |
| `/guardrails-config` | TrustyAI Guardrails Orchestrator 배포 (입출력 콘텐츠 안전 감지기) |

### 커스텀 추가 스킬

| 스킬 | 설명 |
|------|------|
| **`/hf-model-deploy`** | 안정적이고 실패에 강한 모델 가중치 획득 및 배포 |

## /hf-model-deploy — 뭐가 다른가?

업스트림 `model-deploy` 스킬은 모델이 이미 접근 가능하다고 가정합니다. **hf-model-deploy**는 가장 큰 고충인 **KServe storage-initializer의 불안정한 모델 다운로드**를 해결합니다.

**전략 우선순위:**

1. **OCI ModelCar** — 모델을 컨테이너 이미지로 (시작 시 다운로드 제로)
2. **S3/MinIO Pre-Cache** — 오브젝트 스토리지에 한 번 다운, 여러 번 서빙 (엔터프라이즈급)
3. **PVC Pre-Cache** — `hf_transfer`로 로컬 볼륨 캐싱 (단일 Pod용)
4. **Direct hf://** — 10GB 초과 모델에 사용 금지 (hang, resume 불가)

**포함 내용:**
- OCI ModelCar 카탈로그 검색 (quay.io API)
- S3/MinIO 전체 구성 + HF→S3 전송 Job
- PVC 기반 다운로드 (`hf_transfer` 고속 병렬, 이어받기 지원)
- GPU VRAM vs 모델 크기 가이드
- 주요 모델 패밀리별 Tool Calling 설정법
- 일반적인 배포 실패 트러블슈팅 가이드
- Ansible Role 참고 구현

## MCP 서버

`mcps.json`에 MCP 서버 구성이 포함되어 있습니다:

| 서버 | 타입 | 필수 여부 | 설명 |
|------|------|-----------|------|
| `openshift` | 컨테이너 (podman) | **필수** | Kubernetes 리소스 CRUD, Pod 관리, 로그, 이벤트 |
| `rhoai` | 로컬 프로세스 (uvx) | **권장** | RHOAI 전용 도구: 모델 배포, 서빙 런타임, 데이터 연결 |
| `ai-observability` | 원격 HTTP | **선택** | vLLM 메트릭, GPU 모니터링, 분산 트레이싱 |

## 지원 런타임

| 런타임 | 용도 | 사전 설정 |
|--------|------|-----------|
| vLLM | 오픈소스 LLM 기본 (Llama, Granite, Qwen, Mixtral) | 없음 |
| NVIDIA NIM | TensorRT-LLM 최적화 추론 | `/nim-setup` |
| Caikit+TGIS | Caikit 포맷 모델 + gRPC API | 모델 변환 필요 |

## 전제 조건

- RHOAI 오퍼레이터가 설치된 OpenShift 클러스터
- `oc` CLI 인증 완료
- `podman` (MCP 서버 컨테이너 실행용)
- GPU 노드 (NVIDIA)
- `KUBECONFIG` 환경변수 설정

## 검증된 환경

| 플랫폼 | 버전 | GPU |
|--------|------|-----|
| OpenShift | 4.16+ | L4, L40S, A100 |
| RHOAI | 2.16+ / 3.0+ | NVIDIA |
| vLLM | 0.6.x+ (Red Hat 이미지) | CUDA 12+ |

## 프로젝트 구조

```
hyo-rhoai-skills/
├── README.md                           # 영문 README
├── README_ko.md                        # 한국어 README (이 파일)
├── CLAUDE.md                           # AI 어시스턴트 가이드
├── mcps.json                           # MCP 서버 설정
├── LICENSE
├── .gitignore
└── skills/
    ├── hf-model-deploy/                # [커스텀] 모델 가중치 획득
    │   ├── SKILL.md
    │   └── ansible-role-example.yml
    ├── model-deploy/                   # 모델 배포 (vLLM/NIM/Caikit)
    ├── ds-project-setup/               # Data Science Project 설정
    ├── workbench-manage/               # Workbench 관리
    ├── model-registry/                 # Model Registry 운영
    ├── pipeline-manage/                # Data Science Pipelines
    ├── nim-setup/                      # NVIDIA NIM 구성
    ├── serving-runtime-config/         # 커스텀 ServingRuntime CR
    ├── debug-inference/                # InferenceService 트러블슈팅
    ├── ai-observability/               # 성능 및 GPU 분석
    ├── model-monitor/                  # TrustyAI 편향/드리프트 모니터링
    ├── guardrails-config/              # 콘텐츠 안전 가드레일
    └── references/                     # 공유 참조 문서
```

## 다른 프로젝트에서 사용하기

```bash
# 방법 1: lola로 전역 설치 (모든 프로젝트에 적용)
lola install hyo-rhoai-skills -a cursor --scope user

# 방법 2: 특정 프로젝트에만 설치
cd /path/to/my-project
lola install hyo-rhoai-skills -a cursor

# 방법 3: .lola-req로 프로젝트 의존성 관리
echo "https://github.com/hyogrin/hyo-rhoai-skills.git@main" >> .lola-req
lola sync

# 방법 4: 업데이트
lola mod update hyo-rhoai-skills && lola update
```

## 기여 방법

1. 이 레포를 Fork
2. `skills/<skill-name>/SKILL.md` 아래에 스킬 생성
3. `lola mod add ./ && lola install hyo-rhoai-skills -a cursor`로 테스트
4. PR 제출

## 크레딧

- **rh-ai-engineer 스킬**: [RHEcosystemAppEng/agentic-collections](https://github.com/RHEcosystemAppEng/agentic-collections)
- **hf-model-deploy**: 프로덕션 모델 다운로드 실패 문제를 해결하기 위해 자체 개발한 커스텀 스킬

## 라이선스

Apache License 2.0
