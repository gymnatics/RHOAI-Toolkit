# AutoRAG Demo (Technology Preview)

Automated RAG pipeline optimization -- finds the best retrieval-augmented generation configuration for your documents.

> **RHOAI 3.5+ note:** The Llama Stack Operator has been renamed to **OGX** (DSC field
> `llamastackoperator` -> `ogx`; CRD `LlamaStackDistribution` -> `OGXServer`). `deploy.sh`
> detects your RHOAI version automatically and deploys `manifests/ogxserver.yaml` (3.5+)
> or `manifests/llamastack.yaml` (3.4 and earlier) accordingly. See
> [docs/guides/rhoai-3.5/RHOAI-35-WHATS-NEW.md](../../docs/guides/rhoai-3.5/RHOAI-35-WHATS-NEW.md)
> for the full list of changes. On 3.5+, OGX bring-up needs a multi-step workaround cascade —
> see [Known issues (RHOAI 3.5)](#known-issues-rhoai-35) below.

## What AutoRAG Does

Provide documents and test questions, and AutoRAG automatically:
- Tests combinations of chunking, embedding, retrieval, and generation settings
- Evaluates each combination against your test data
- Ranks RAG patterns on a leaderboard by evaluation metrics
- Generates indexing and inference notebooks for the best patterns

## Deploy

```bash
./deploy.sh                    # Deploy infrastructure
./deploy.sh -n my-namespace    # Custom namespace
./deploy.sh --delete           # Remove
```

This deploys:
- SeaweedFS / pluggable S3 (document storage + pipeline artifacts)
- Milvus vector database (required by AutoRAG -- inline Milvus not supported)
- Pipeline Server (DSPA for Kubeflow Pipelines)
- S3 data connection with sample documents
- bge-m3 embedding `InferenceService` (remote CPU)

On RHOAI 3.5+ (`USE_OGX=true`), `deploy.sh` also automates OGX bring-up:
- Copies/extracts `llama-stack-config`, strips nomic, patches vLLM to the internal InferenceService URL
- Deploys pgvector
- Applies `OGXServer` via `overrideConfig` + `rh-dev` (`manifests/ogxserver.yaml`)
- Creates the `autorag-ogx-connection` secret

Much of the old "Post-Deploy Manual Setup" for creating a Llama Stack / OGX instance is therefore automated on 3.5+. Dashboard steps below still apply for creating the AutoRAG run.

**Verify OGX:** `oc get ogxserver autorag-ogx -n autorag-demo` → Phase Ready, then dashboard Develop and train > AutoRAG.

## Prerequisites

AutoRAG has the heaviest infrastructure requirements of any RHOAI feature:

| Requirement | RHOAI 3.4 and earlier | RHOAI 3.5+ |
|------------|------------------------|------------|
| Operator | `llamastackoperator: Managed` in DSC (auto-enabled by deploy script) | `ogx: Managed` in DSC (auto-enabled by deploy script) |
| Instance | Llama Stack instance with foundation + embedding models | OGXServer via `overrideConfig` (automated by deploy script) |
| Embedding Model | Deploy BAAI/bge-m3 (recommended) via Llama Stack | Remote CPU `bge-m3` InferenceService (deployed by this script) |
| Foundation Model | Any vLLM-served LLM registered with Llama Stack | vLLM InferenceService (internal URL — not MaaS gateway) |
| Remote Milvus | Deployed by this script | Deployed by this script |
| AI Pipelines | `aipipelines: Managed` in DSC | `aipipelines: Managed` in DSC |
| Gen AI Studio | `genAiStudio: true` in dashboard config | `genAiStudio: true` in dashboard config |

**Inference provider URL:** Point OGX at the InferenceService/internal cluster URL. Do not use the MaaS gateway URL — MaaS needs a bearer token that OGX cannot supply via env-var substitution.

## Known issues (RHOAI 3.5)

Full write-up: [docs/bugs/autorag-ogx-3.5-cascade.md](../../docs/bugs/autorag-ogx-3.5-cascade.md). OCI 401 deep dive: [docs/reference/BUG-REPORT-OGX-REGISTRY-AUTH-401.md](../../docs/reference/BUG-REPORT-OGX-REGISTRY-AUTH-401.md) (RHOAIENG-96724).

- **OCI label fetch HTTP 401** — operator anonymous OCI client; `baseConfig` alone is not enough
- **Secret/ConfigMap "not found"** — label referenced resources with `ogx.io/watch=true`
- **Empty `VLLM_*_API_TOKEN`** — set literal `unused` for internal endpoints
- **CRD providers/baseConfig strip runtime fields** — use `overrideConfig` + `rh-dev` (toolkit path); do not use `rh` + CRD providers
- **search-space-preparation fails (nomic offline)** — deploy.sh strips nomic; use remote bge-m3

Without OGX Ready, Milvus / bge-m3 / S3 / DSPA still work for narrated fallback demos.

## Post-Deploy Manual Setup

After running `deploy.sh`, complete these steps in the RHOAI dashboard. On RHOAI 3.4 and earlier, create/register the Llama Stack instance and connection as below. On RHOAI 3.5+, the OGXServer and `autorag-ogx-connection` secret are created by `deploy.sh` — skip to creating the AutoRAG run (and confirm the connection appears in the project).

### 1. Set Up Llama Stack Instance (RHOAI 3.4 and earlier)

1. Dashboard > Applications > Enabled
2. Find **Llama Stack** and create an instance
3. Configure with your deployed models:
   - Foundation model: your vLLM-served model
   - Embedding model: `BAAI/bge-m3` (recommended, ~1.1 GB fp16)

### 2. Register Milvus with Llama Stack (RHOAI 3.4 and earlier)

1. In Llama Stack settings, add a vector database
2. Type: **Milvus (remote)**
3. Endpoint: `milvus.autorag-demo.svc.cluster.local:19530`

### 3. Create Llama Stack / OGX Connection

1. Dashboard > autorag-demo project > Connections
2. Add connection: **Llama Stack** / OGX (or confirm `autorag-ogx-connection` from deploy.sh on 3.5+)
   - Base URL: your Llama Stack / OGX instance URL
   - API Key: your API key (as required)

### 4. Create AutoRAG Optimization Run

1. Dashboard > **Develop and train > AutoRAG**
2. Click **Create run**
3. Configure:
   - S3 Connection: `AutoRAG Documents`
   - Llama Stack / OGX Connection: (from step 3)
   - Optimization metric: e.g. **Answer correctness**
   - Upload test data: `sample-data/test-data.json`
4. Optional: Limit models (max 3 foundation + 2 embedding to avoid failures)
5. Click **Create run**

### 5. Evaluate and Use

1. Wait for the run to complete
2. Review RAG patterns on the leaderboard
3. Compare patterns by Sample Q&A responses
4. Save indexing and inference notebooks for the best pattern
5. Run notebooks in a workbench

## Sample Data

### Documents (`sample-data/docs/`)
Three markdown documents covering OpenShift AI topics:
- `openshift-ai-overview.md` -- Platform overview and architecture
- `model-serving-guide.md` -- Serving runtimes and deployment modes
- `pipelines-and-training.md` -- Pipelines, AutoML, and distributed training

### Test Data (`sample-data/test-data.json`)
10 question-answer pairs for evaluating RAG quality, covering topics like:
- Serving runtimes and deployment modes
- MaaS and API management
- AutoML workflow
- Hardware Profiles and GPU support

## Evaluation Metrics

| Metric | What It Measures |
|--------|-----------------|
| Answer correctness | Factual accuracy of generated answers |
| Context correctness | Relevance of retrieved documents |
| Faithfulness | Whether answers are grounded in retrieved context |
| Answer relevance | Whether answers address the question |

## Limitations (Technology Preview)

- English language documents only
- Remote Milvus only (inline not supported)
- Max 3 foundation models + 2 embedding models per run
- No OCR or table detection for PDFs
- No image processing in documents
