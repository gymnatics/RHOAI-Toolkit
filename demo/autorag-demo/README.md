# AutoRAG Demo (Technology Preview)

Automated RAG pipeline optimization -- finds the best retrieval-augmented generation configuration for your documents.

> **RHOAI 3.5+ note:** The Llama Stack Operator has been renamed to **OGX** (DSC field
> `llamastackoperator` -> `ogx`; CRD `LlamaStackDistribution` -> `OGXServer`). `deploy.sh`
> detects your RHOAI version automatically and deploys `manifests/ogxserver.yaml` (3.5+)
> or `manifests/llamastack.yaml` (3.4 and earlier) accordingly. See
> [docs/guides/rhoai-3.5/RHOAI-35-WHATS-NEW.md](../../docs/guides/rhoai-3.5/RHOAI-35-WHATS-NEW.md)
> for the full list of changes.

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
- MinIO (document storage + pipeline artifacts)
- Milvus vector database (required by AutoRAG -- inline Milvus not supported)
- Pipeline Server (DSPA for Kubeflow Pipelines)
- S3 data connection with sample documents

## Prerequisites

AutoRAG has the heaviest infrastructure requirements of any RHOAI feature:

| Requirement | RHOAI 3.4 and earlier | RHOAI 3.5+ |
|------------|------------------------|------------|
| Operator | `llamastackoperator: Managed` in DSC (auto-enabled by deploy script) | `ogx: Managed` in DSC (auto-enabled by deploy script) |
| Instance | Llama Stack instance with foundation + embedding models | OGXServer instance with foundation + embedding models |
| Embedding Model | Deploy BAAI/bge-m3 (recommended) via Llama Stack | Deploy BAAI/bge-m3 (recommended) via OGX |
| Foundation Model | Any vLLM-served LLM registered with Llama Stack | Any vLLM-served LLM registered with OGX |
| Remote Milvus | Deployed by this script | Deployed by this script |
| AI Pipelines | `aipipelines: Managed` in DSC | `aipipelines: Managed` in DSC |
| Gen AI Studio | `genAiStudio: true` in dashboard config | `genAiStudio: true` in dashboard config |

## Post-Deploy Manual Setup

After running `deploy.sh`, complete these steps in the RHOAI dashboard. The steps below
reference "Llama Stack" (RHOAI 3.4 and earlier); on RHOAI 3.5+ the equivalent dashboard
entries may be labeled "OGX" instead -- the underlying workflow is unchanged.

### 1. Set Up Llama Stack Instance

1. Dashboard > Applications > Enabled
2. Find **Llama Stack** and create an instance
3. Configure with your deployed models:
   - Foundation model: your vLLM-served model
   - Embedding model: `BAAI/bge-m3` (recommended, ~1.1 GB fp16)

### 2. Register Milvus with Llama Stack

1. In Llama Stack settings, add a vector database
2. Type: **Milvus (remote)**
3. Endpoint: `milvus.autorag-demo.svc.cluster.local:19530`

### 3. Create Llama Stack Connection

1. Dashboard > autorag-demo project > Connections
2. Add connection: **Llama Stack**
   - Base URL: your Llama Stack instance URL
   - API Key: your Llama Stack API key

### 4. Create AutoRAG Optimization Run

1. Dashboard > **Develop and train > AutoRAG**
2. Click **Create run**
3. Configure:
   - S3 Connection: `AutoRAG Documents`
   - Llama Stack Connection: (from step 3)
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
