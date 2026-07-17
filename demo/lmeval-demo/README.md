# LMEval + EvalHub Demo

LLM evaluation benchmarks with MLflow tracking on RHOAI, powered by EvalHub (Technology Preview).

## EvalHub (Technology Preview)

EvalHub is a centralized evaluation orchestration service that provides:
- **Dashboard UI**: Develop and train > Evaluations -- visual job management
- **SDK**: `eval-hub-sdk[client]` Python library for programmatic evaluations
- **CLI**: `evalhub` command for terminal workflows
- **Providers**: lm-evaluation-harness, Garak, GuideLLM, LightEval
- **Collections**: Pre-built benchmark suites (leaderboard-v2, safety-and-fairness-v1)
- **MLflow integration**: Automatic experiment tracking and result logging

## Benchmarks

### English (via CLI -- LMEvalJob CRs)

| Benchmark | Task | What it measures | Shots |
|-----------|------|-----------------|-------|
| MMLU | `mmlu` | 57-subject knowledge | 5 |
| ARC Challenge | `arc_challenge` | Science QA | 25 |
| HellaSwag | `hellaswag` | Commonsense reasoning | 10 |
| Winogrande | `winogrande` | Coreference resolution | 5 |
| TruthfulQA | `truthfulqa_mc2` | Truthfulness | 0 |
| GSM8K | `gsm8k` | Math reasoning | 5 |
| IFEval | `ifeval` | Instruction following | 0 |
| BBH | `bbh` | BIG-Bench Hard reasoning | 3 |

### Korean (via workbench notebooks -- EvalHub SDK)

| Benchmark | Samples | What it measures |
|-----------|---------|-----------------|
| KMMLU | 35,030 | Korean multi-task understanding |
| CLIcK | 1,995 | Cultural + linguistic intelligence |
| KoBEST | 6,100+ | Balanced evaluation tasks |
| HAE-RAE | 1,538 | Korean language proficiency |

### Performance (language-agnostic -- GuideLLM)

TTFT, ITL, throughput, latency under load.

## Deploy

```bash
./deploy.sh                    # Deploy infrastructure + EvalHub CR
./deploy.sh --delete           # Remove
```

This deploys:
- EvalHub via TrustyAI Operator CR (SQLite backend for demo)
- LMEval RBAC (ServiceAccount + ClusterRoleBinding)
- Korean lab repo (cloned for workbench notebooks)

For production use with PostgreSQL:
```bash
# Edit manifests/evalhub-postgresql.yaml with your PostgreSQL credentials
oc apply -f manifests/evalhub-postgresql.yaml -n lmeval-demo
```

## Run English Benchmarks (CLI)

```bash
./run-benchmark.sh --list              # See available benchmarks
./run-benchmark.sh mmlu                # Run MMLU
./run-benchmark.sh reasoning           # ARC + HellaSwag + Winogrande
./run-benchmark.sh truthful-math       # TruthfulQA + GSM8K
./run-benchmark.sh ifeval-bbh          # IFEval + BBH
./run-benchmark.sh all-english         # Run all English benchmarks
./run-benchmark.sh --status            # Check job progress
```

The script auto-detects your deployed model and submits `LMEvalJob` CRs.

## Use EvalHub SDK (Workbench)

1. Create a workbench in the RHOAI dashboard
2. Upload `evalhub-sdk-demo.ipynb`
3. Install: `pip install "eval-hub-sdk[client]"`
4. Run the notebook to:
   - Discover providers and benchmarks
   - Submit evaluation jobs programmatically
   - Run pre-built collection suites
   - Retrieve and display results

## Use EvalHub Dashboard UI

1. Ensure `disableLMEval: false` in OdhDashboardConfig
2. Dashboard > Develop and train > Evaluations
3. Browse benchmark tasks and collections
4. Select a model and run evaluations
5. View scores and metrics in the results view

### Tokenizer Mismatch (common failure)

The "Model or agent name" field in the UI is used as **both** the vLLM served model
name and the HuggingFace tokenizer ID. For Red Hat AI catalog models these differ:

| Field | Value |
|-------|-------|
| vLLM served name | `redhataiqwen3-8b-fp8-dynamic` |
| HuggingFace tokenizer | `RedHatAI/Qwen3-8B-FP8-dynamic` |

If your eval jobs fail with tokenizer errors, use the **served model name** in the
"Model or agent name" field, then check **"Add additional arguments"** and add:

```
tokenizer=RedHatAI/Qwen3-8B-FP8-dynamic
```

To find the correct tokenizer ID for any model, check the vLLM container's model
path or look up the model on HuggingFace. For Red Hat AI catalog models the pattern
is `RedHatAI/<Model-Name-With-Proper-Casing>`.

## Run Korean & Performance Benchmarks (Workbench Notebooks)

Vendored notebooks in `notebooks/` auto-detect the deployed model and EvalHub endpoint:

| Notebook | What it does |
|----------|-------------|
| `notebooks/guidellm-benchmark.ipynb` | GuideLLM performance profiling (TTFT, ITL, throughput) |
| `notebooks/korean-mcq-benchmark.ipynb` | Korean MCQ evaluation (KMMLU, CLIcK, HAE-RAE) with MLflow |

1. Create a workbench in the RHOAI dashboard (namespace `lmeval-demo`)
2. Upload the notebook(s) from `notebooks/`
3. Install: `pip install "eval-hub-sdk[client]"`
4. Run — the config cell auto-detects the model via `oc get inferenceservice`

> Notebooks adapted from [hyogrin/rhoai-lmeval-builder-lab](https://github.com/hyogrin/rhoai-lmeval-builder-lab).
> The Korean MCQ provider YAML (`../adapters/korean-mcq/`) is in the upstream repo — clone it if you need custom provider definitions.

## Prerequisites

- TrustyAI operator enabled (`trustyai: Managed` in DSC)
- A model deployed via InferenceService
- `disableLMEval: false` in OdhDashboardConfig (for dashboard Evaluations UI)
- For Korean benchmarks: MLflow for tracking
