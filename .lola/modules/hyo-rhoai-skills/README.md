# hyo-rhoai-skills

Production-ready AI skills for Red Hat OpenShift AI (RHOAI) model deployment and operations.

This repository combines the [rh-ai-engineer](https://github.com/RHEcosystemAppEng/agentic-collections) skills from Red Hat Ecosystem Engineering with a custom **hf-model-deploy** skill that solves real-world model download failures on OpenShift AI.

## Installation

### Using Lola (recommended)

```bash
lola mod add https://github.com/hyogrin/hyo-rhoai-skills.git
lola install hyo-rhoai-skills -a cursor
```

### Global Installation (all projects)

```bash
lola install hyo-rhoai-skills -a cursor --scope user
```

### Using .lola-req (declarative)

```
https://github.com/hyogrin/hyo-rhoai-skills.git@main
```

```bash
lola sync
```

### Manual

```bash
cp -r skills/* /path/to/your-project/.cursor/skills/
```

## Available Skills

### From rh-ai-engineer (Red Hat Ecosystem Engineering)

| Skill | Description |
|-------|-------------|
| `/ds-project-setup` | Create and configure Data Science Projects with namespace, data connections, pipeline server, and model serving |
| `/workbench-manage` | Create and manage Jupyter notebook workbenches with image selection, resources, and lifecycle |
| `/model-deploy` | Deploy AI/ML models with vLLM, NIM, or Caikit+TGIS runtimes |
| `/model-registry` | Register, version, and promote ML models in the Model Registry across environments |
| `/pipeline-manage` | Create, run, schedule, and monitor Data Science Pipelines (Kubeflow Pipelines 2.0) |
| `/nim-setup` | Configure NVIDIA NIM platform on OpenShift AI (NGC credentials, Account CR) |
| `/serving-runtime-config` | Configure custom ServingRuntime CRs for model serving frameworks |
| `/debug-inference` | Troubleshoot failed or slow InferenceService deployments |
| `/ai-observability` | Analyze model performance, GPU utilization, cluster health, and distributed traces |
| `/model-monitor` | Configure TrustyAI bias detection (SPD, DIR) and data drift monitoring |
| `/guardrails-config` | Deploy TrustyAI Guardrails Orchestrator with input/output content safety detectors |

### Custom Addition

| Skill | Description |
|-------|-------------|
| **`/hf-model-deploy`** | Stable, failure-resistant model weight acquisition and deployment |

## /hf-model-deploy — What Makes It Different

The upstream `model-deploy` skill assumes the model is already accessible. **hf-model-deploy** solves the #1 pain point: **unreliable model weight downloads** during KServe storage-initializer execution.

**Strategy Priority:**

1. **OCI ModelCar** — Models as container images (zero download at startup)
2. **S3/MinIO Pre-Cache** — Download once to object storage, serve many (enterprise-grade)
3. **PVC Pre-Cache** — Local volume caching with `hf_transfer` (single-pod)
4. **Direct hf://** — AVOID for models >10GB (hangs, no resume)

**Includes:**
- OCI ModelCar catalog discovery (quay.io API search)
- S3/MinIO full setup with HF→S3 transfer Job
- PVC-based download with `hf_transfer` (fast, resumable)
- GPU VRAM vs model size guide
- Tool calling configuration for all major model families
- Troubleshooting table for common deployment failures
- Ansible role example for declarative deployment

## MCP Servers

This pack includes MCP server configurations in `mcps.json`:

| Server | Type | Requirement | Description |
|--------|------|-------------|-------------|
| `openshift` | Container (podman) | **Required** | Kubernetes resource CRUD, pod management, logs, events |
| `rhoai` | Local process (uvx) | **Preferred** | RHOAI-specific convenience tools: model deployment, serving runtimes, data connections |
| `ai-observability` | Remote HTTP | **Optional** | vLLM metrics, GPU monitoring, distributed tracing |

## Supported Runtimes

| Runtime | Use Case | Setup Required |
|---------|----------|----------------|
| vLLM | Default for open-source LLMs (Llama, Granite, Qwen, Mixtral) | None |
| NVIDIA NIM | Optimized inference with TensorRT-LLM on NVIDIA GPUs | `/nim-setup` |
| Caikit+TGIS | Models in Caikit format with gRPC API | Model conversion |

## Prerequisites

- OpenShift cluster with RHOAI operator installed
- `oc` CLI authenticated
- `podman` for running containerized MCP servers
- GPU nodes available (NVIDIA)
- `KUBECONFIG` environment variable set

## Tested Environments

| Platform | Version | GPU |
|----------|---------|-----|
| OpenShift | 4.16+ | L4, L40S, A100 |
| RHOAI | 2.16+ / 3.0+ | NVIDIA |
| vLLM | 0.6.x+ (Red Hat image) | CUDA 12+ |

## Project Structure

```
hyo-rhoai-skills/
├── README.md                           # This file (English)
├── README_ko.md                        # Korean version
├── CLAUDE.md                           # AI assistant guidance
├── mcps.json                           # MCP server configurations
├── LICENSE
├── .gitignore
└── skills/
    ├── hf-model-deploy/                # [Custom] Model weight acquisition
    │   ├── SKILL.md
    │   └── ansible-role-example.yml
    ├── model-deploy/                   # Deploy models (vLLM/NIM/Caikit)
    ├── ds-project-setup/               # Data Science Project setup
    ├── workbench-manage/               # Workbench management
    ├── model-registry/                 # Model Registry operations
    ├── pipeline-manage/                # Data Science Pipelines
    ├── nim-setup/                      # NVIDIA NIM configuration
    ├── serving-runtime-config/         # Custom ServingRuntime CRs
    ├── debug-inference/                # InferenceService troubleshooting
    ├── ai-observability/               # Performance & GPU analysis
    ├── model-monitor/                  # TrustyAI bias/drift monitoring
    ├── guardrails-config/              # Content safety guardrails
    └── references/                     # Shared reference docs
```

## Contributing

1. Fork this repository
2. Create a skill under `skills/<skill-name>/SKILL.md`
3. Test with `lola mod add ./ && lola install hyo-rhoai-skills -a cursor`
4. Submit a PR

## Credits

- **rh-ai-engineer skills**: [RHEcosystemAppEng/agentic-collections](https://github.com/RHEcosystemAppEng/agentic-collections)
- **hf-model-deploy**: Custom skill developed to solve production model download failures

## License

Apache License 2.0
