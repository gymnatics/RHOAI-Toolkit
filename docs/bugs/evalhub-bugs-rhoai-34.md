# EvalHub Bugs — RHOAI 3.4.0

## Summary

Multiple bugs in the EvalHub (Technology Preview) component of RHOAI 3.4.0 prevent reliable model evaluation through both the Dashboard UI and the Python SDK. The `lighteval` provider (default) is largely unusable for standard LLM benchmarks; only the `lm_evaluation_harness` provider produces correct MLflow-tracked results, and even that requires specific workarounds.

## Environment

- OpenShift 4.20
- RHOAI 3.4.0 (`rhods-operator.3.4.0`)
- EvalHub deployed via DSC (`trustyai: Managed`)
- EvalHub adapter images: `community-lighteval:v0.2.0`, `lm-evaluation-harness` (built-in)
- eval-hub-sdk 0.1.6
- Model: Qwen3-8B FP8 Dynamic via vLLM (InferenceService + LLMInferenceService)
- MLflow deployed via DSC (`mlflowoperator: Managed`)

---

## API Payloads Captured

### Working payload (SDK → single benchmark → `lm_evaluation_harness`)

Submitted via `eval-hub-sdk` `client.jobs.submit()` from notebook:

```python
single_request = JobSubmissionRequest(
    name="arc-easy-eval",
    description="ARC Easy science reasoning (limit=20) - redhataiqwen3-8b-fp8-dynamic",
    tags=["english", "arc", "reasoning", "redhataiqwen3-8b-fp8-dynamic"],
    model=ModelConfig(
        url="https://redhataiqwen3-8b-fp8-dynamic-no-maas-0-test.apps.cluster-9tjvr.9tjvr.sandbox2001.opentlc.com/v1",
        name="redhataiqwen3-8b-fp8-dynamic",
    ),
    benchmarks=[
        BenchmarkConfig(
            id="arc_easy",
            provider_id="lm_evaluation_harness",
            parameters={"num_fewshot": 0, "limit": 20, "tokenizer": "Qwen/Qwen3-8B"},
        ),
    ],
    experiment=ExperimentConfig(
        name="english-arc-easy-eval",
        tags=[
            ExperimentTag(key="language", value="english"),
            ExperimentTag(key="benchmark_suite", value="arc_easy"),
            ExperimentTag(key="model", value="redhataiqwen3-8b-fp8-dynamic"),
        ],
    ),
)
```

This correctly creates an EvalHub job with `parameters: {"num_fewshot": 0, "limit": 20, "tokenizer": "Qwen/Qwen3-8B"}` in the job spec ConfigMap, the adapter picks up the tokenizer, and an MLflow run is created with metrics.

### Broken payload (Dashboard UI → "Benchmark suite" / collection → `lm_evaluation_harness`)

Job spec extracted from ConfigMap (`oc get configmap <uuid>-spec -o jsonpath='{.data.job\.json}'`):

```json
{
    "benchmark_id": "leaderboard_math_hard",
    "benchmark_index": 5,
    "model": {
        "name": "redhataiqwen3-8b-fp8-dynamic",
        "url": "https://redhataiqwen3-8b-fp8-dynamic-kserve-workload-svc.0-test.svc:8000/v1"
    },
    "parameters": {},
    "provider_id": "lm_evaluation_harness"
}
```

Note:
- `"parameters": {}` — the `{"tokenizer": "RedHatAI/Qwen3-8B-FP8-dynamic"}` entered in the Dashboard UI "additional arguments" field was **silently dropped**
- `model.url` points to the **internal** service-ca endpoint (the Dashboard auto-discovers it), causing SSL verification failures in the adapter
- All 6 jobs in the "Leaderboard" collection had identical empty `parameters`

### Broken payload (Dashboard UI → "Benchmark suite" / collection → `lighteval`)

Job spec extracted from a `lighteval` collection run:

```json
{
    "benchmark_id": "mmlu",
    "benchmark_index": 0,
    "model": {
        "name": "redhataiqwen3-8b-fp8-dynamic",
        "url": "https://redhataiqwen3-8b-fp8-dynamic-kserve-workload-svc.0-test.svc:8000/v1"
    },
    "parameters": {},
    "provider_id": "lighteval"
}
```

The `lighteval` adapter translates this into:

```
lighteval endpoint litellm \
    model_name=openai/redhataiqwen3-8b-fp8-dynamic,base_url=https://...:8000/v1,api_key=dummy \
    mmlu|0 \
    --output-dir /tmp/lighteval_ye8hmcpr \
    --no-push-to-hub --save-details
```

No `--max-samples` flag (despite `limit` in parameters), no tokenizer override, and `limit=None` visible in adapter logs.

---

## Bug 1: "Benchmark suite" path does not forward parameters to jobs

### Severity: High

### Description

When creating an evaluation run via the Dashboard UI using the **"Benchmark suite"** (collection) path, the `additionalArguments` JSON entered by the user is **not forwarded** to individual benchmark job specs. Each job gets `"parameters": {}` regardless of what was entered.

### Steps to Reproduce

1. Open RHOAI Dashboard → Develop and train → Evaluations
2. Click "New evaluation run" → select **"Benchmark suite"**
3. Select a collection (e.g. "Leaderboard")
4. Fill in model endpoint and check "Add additional arguments"
5. Enter: `{"tokenizer": "RedHatAI/Qwen3-8B-FP8-dynamic"}`
6. Click "Start evaluation run"
7. Inspect job spec: `oc get configmap <job-uuid>-spec -n lmeval-demo -o jsonpath='{.data.job\.json}' | python3 -m json.tool`

### Expected

Each benchmark job in the collection should have `parameters: {"tokenizer": "RedHatAI/Qwen3-8B-FP8-dynamic"}`.

### Actual

Job spec ConfigMap shows `"parameters": {}`. All 6 leaderboard benchmark jobs had empty parameters. The tokenizer parameter is lost, causing `lm_evaluation_harness` jobs to fail with:

```
Repository Not Found for url: https://huggingface.co/redhataiqwen3-8b-fp8-dynamic/resolve/main/tokenizer_config.json
```

The adapter tries to use the served model name (`redhataiqwen3-8b-fp8-dynamic`) as a HuggingFace tokenizer ID, which doesn't exist.

### Impact

The "Benchmark suite" UI path is the primary way users run standardized evaluation suites (leaderboard, etc.). Without `parameters` forwarding, key settings like `tokenizer`, `num_fewshot`, and `limit` are all silently dropped, making this path unusable for models where the served name doesn't match the HuggingFace model ID (which is the majority of Red Hat AI models).

### Workaround

Use the **"Single benchmark"** path in the Dashboard UI, or submit via the `eval-hub-sdk` Python SDK where `BenchmarkConfig.parameters` is correctly forwarded to the job spec.

---

## Bug 2: `lighteval` adapter does not create MLflow runs

### Severity: High

### Description

The `community-lighteval:v0.2.0` adapter does **not** log evaluation results to MLflow. The MLflow experiment is created (experiment entry visible in MLflow UI), but no runs or metrics are recorded. Results are stored only in EvalHub's internal database.

### Steps to Reproduce

1. Submit an evaluation job using the `lighteval` provider (default in Dashboard UI)
2. Wait for job completion
3. Open MLflow UI → navigate to the experiment

### Expected

An MLflow run should be created with benchmark metrics (e.g. `acc`, `acc_norm`, `exact_match`).

### Actual

The MLflow experiment exists but contains **zero runs**. No metrics are logged. The EvalHub job results page shows metrics, but they are only in EvalHub's database, not in MLflow.

Additionally, LightEval's metric names (e.g. `aime24|0.avg@n:n=1`) do not match EvalHub's registered `primary_score.metric` (e.g. `acc`), causing pass/fail test results to show as nil.

### Workaround

Use the `lm_evaluation_harness` provider instead of `lighteval`. This provider correctly creates MLflow runs with proper metric names. Requires:
- `tokenizer` parameter in benchmark config (e.g. `Qwen/Qwen3-8B`)
- External route URL for the model endpoint (standard TLS, not internal service-ca)

---

## Bug 3: `lighteval` adapter ignores `limit` parameter

### Severity: Medium

### Description

The `lighteval` adapter does not translate the `limit` (or `max_samples`) parameter from `BenchmarkConfig.parameters` to the LightEval CLI's `--max-samples` flag. Full datasets always run regardless of the configured limit.

### Steps to Reproduce

1. Submit a job with `lighteval` provider and `parameters: {"limit": 5}`:

```python
BenchmarkConfig(
    id="mmlu",
    provider_id="lighteval",
    parameters={"limit": 5},
)
```

2. Monitor the adapter pod logs

### Expected

LightEval CLI should be invoked with `--max-samples 5`, running only 5 questions.

### Actual

Adapter logs show `limit=None`. The CLI command has no `--max-samples` flag:

```
lighteval endpoint litellm model_name=openai/redhataiqwen3-8b-fp8-dynamic,base_url=https://...:8000/v1,api_key=dummy mmlu|0 --output-dir /tmp/lighteval_... --no-push-to-hub --save-details
```

Full MMLU (14,042 questions) runs, taking 4-8 hours instead of minutes.

### Workaround

Use smaller benchmarks (e.g. `arc_easy` = 2,376 questions, `truthfulqa_mc1` = 817) instead of relying on `limit`. Or switch to `lm_evaluation_harness` provider.

---

## Bug 4: `lighteval` adapter does not support `loglikelihood` (MC benchmarks)

### Severity: Medium

### Description

The `lighteval` adapter's LiteLLM endpoint model does not implement the `loglikelihood` method. All multiple-choice benchmarks that require log-probability computation fail with `NotImplementedError`.

### Affected Benchmarks

All MC-type benchmarks: `arc_easy`, `arc_challenge`, `mmlu`, `hellaswag`, `winogrande`, `truthfulqa:mc`, `openbookqa`, and any benchmark using `SamplingMethod.LOGPROBS`.

### Error

```
NotImplementedError: loglikelihood is not implemented for LiteLLMEndpointModel
```

### Workaround

For `lighteval` provider: only generative benchmarks work (e.g. `gsm8k`, `aime24` — those using `SamplingMethod.GREEDY_UNTIL`).

For MC benchmarks: use the `lm_evaluation_harness` provider, which properly supports logprobs via the `local-completions` model type.

---

## Bug 5: RBAC missing `status-events` resource

### Severity: Medium

### Description

The `evalhub-evaluations-writer` Role created by the EvalHub operator does not include the `status-events` resource. Job pods cannot post status updates back to EvalHub, causing jobs to appear stuck at "pending" in the UI even while actively running.

### Symptom

- Job pods are running and producing output
- EvalHub UI shows job status as "Pending" indefinitely
- Pod logs show permission errors when attempting to post status events

### Fix Applied

Added `status-events` to the `evalhub-evaluations-writer` Role:

```yaml
- apiGroups: ["trustyai.opendatahub.io"]
  resources: ["evaluations", "evaluations/status", "status-events"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
```

This should be included in the operator's default Role template.

---

## Bug 6: eval-hub-sdk 0.1.6 `Benchmark` model requires `description` field

### Severity: Low

### Description

The `eval-hub-sdk` Python package (v0.1.6) has a Pydantic model `Benchmark` with `description` and `category` as **required** fields (`str`, not `Optional[str]`). However, the EvalHub server returns benchmarks without these fields for some providers (notably the `lm_evaluation_harness` provider's benchmarks), causing `ValidationError` when calling `client.benchmarks.list()`.

### Error

```
ValidationError: 6 validation errors for ProviderList
items.4.benchmarks.0.description
  Field required [type=missing, ...]
items.4.benchmarks.1.description
  Field required [type=missing, ...]
...
```

### Workaround

Monkey-patch the Pydantic model before calling `benchmarks.list()`:

```python
from evalhub.models.api import Benchmark, Provider, ProviderList

for field_name in ("description", "category"):
    if field_name in Benchmark.model_fields:
        Benchmark.model_fields[field_name].default = None
        Benchmark.model_fields[field_name].annotation = str | None
Benchmark.model_rebuild(force=True)
Provider.model_rebuild(force=True)
ProviderList.model_rebuild(force=True)
```

All three models in the dependency chain must be rebuilt with `force=True`.

---

## Bug 7: SSL certificate verification failure with internal service-ca endpoints

### Severity: Low (by design, but undocumented)

### Description

EvalHub adapter pods cannot connect to model endpoints that use OpenShift's internal service-ca TLS certificates. The adapter's Python `requests` library does not trust the service-ca, causing `CERTIFICATE_VERIFY_FAILED` errors.

Some failed job pods also had `REQUESTS_CA_BUNDLE` and `SSL_CERT_FILE` environment variables set to `/etc/pki/ca-trust/source/anchors/service-ca.crt`, which caused the reverse problem: Python's requests library would ONLY trust the internal service-ca, failing to connect to external sites like `huggingface.co` for tokenizer downloads.

### Workaround

Use the InferenceService's **external route URL** (e.g. `https://<isvc>-<ns>.apps.<cluster>/v1`) instead of the internal service URL (`https://<svc>.<ns>.svc:8000/v1`). The external route uses the cluster's standard ingress TLS certificate, which is trusted by default.

---

## Summary of Provider Capabilities

| Capability | `lighteval` (v0.2.0) | `lm_evaluation_harness` |
|---|---|---|
| Generative benchmarks (gsm8k, aime24) | ✅ Works | ✅ Works |
| MC benchmarks (arc, mmlu, hellaswag) | ❌ `NotImplementedError: loglikelihood` | ✅ Works |
| MLflow run creation | ❌ No runs logged | ✅ Runs + metrics logged |
| `limit` / `max_samples` parameter | ❌ Ignored | ✅ Works |
| Tokenizer auto-detection | ❌ Uses model name as tokenizer | ❌ Requires explicit `tokenizer` param |
| Internal service-ca endpoints | ❌ SSL verification fails | ❌ SSL verification fails |
| External route endpoints | ✅ Works | ✅ Works |

**Recommendation**: Use `lm_evaluation_harness` provider for all evaluations until `lighteval` adapter bugs are fixed. Requires:
1. `model.url` = external route URL (standard TLS)
2. `model.name` = vLLM served model name
3. `parameters.tokenizer` = HuggingFace model ID (e.g. `Qwen/Qwen3-8B`)
