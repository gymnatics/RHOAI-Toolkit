# Demo and notebook reference (survey of 2026-11-10, commit 4de6f4a + working tree)

What each demo deploys, how to verify it, and the defects found. Machine-readable checks live in
`checks/demo-specs.conf` and `checks/notebook-specs.conf`; this file is the evidence behind them.
Paths are repo-relative. "Soft" = the script continues on failure (`|| true`).

## Before deploying any demo

- Prefer `-n <namespace>`. (Until 2026-11-10 eight scripts treated a leading flag such as `--delete` as
  the namespace; fixed, but older checkouts on other machines may still have it.)
- Several deploys prompt interactively (see "Prompts"). Run them in a terminal, not headless.
- Workbench demos: after `deploy.sh` finishes, run `check-notebooks.sh --demo <demo>`. The
  `notebook-env` ConfigMap is filled **after** the workbench pod starts, and nothing restarts the pod,
  so on a first deploy notebooks only see `NAMESPACE` (env-drift FAIL). Fix: restart the workbench
  (with user approval). `scripts/refresh-notebook-env.sh <ns>` restarts it, but drops demo-specific
  keys (MODEL_ID, MAAS_ROUTING, LIMIT, MLFLOW_TRACKING_URI, MODEL_SERVED_NAME, S3 bucket names).
- New check type `servedmodel` (added 2026-11-11, `checks/check-demos.sh`): target `configmap/NAME`,
  5th field = key (default `LLM_MODEL_NAME`). PASS only if the ConfigMap value is a model id actually
  served by some `LLMInferenceService` (`spec.model.name`) or `InferenceService` (name or
  `--served-model-name`), not just a resource name. Read-only. See `checks/demo-specs.conf`'s header
  for the full list of check types and their condition syntax.
- New check type `probe` (added 2026-11-11, `checks/check-demos.sh`): target = Route name, 5th field =
  probe kind. HTTP only through the app's Route, no cluster changes. Kinds: `openwebui` (signs in with
  empty credentials, `WEBUI_AUTH=False`, and requires `/api/models` to list at least one model other than
  `arena-model`); `nemo` (POST `/v1/guardrail/checks` with a PII prompt using `oc whoami -t`; PASS only if
  `blocked`; uses the configured `model_name` in selfcheck mode); `lemonade-chat` (POST `/api/chat`; FAIL
  on an error event such as "Backend error (401)" or no text; WARN if the reply contains `<think>`).

## Demos

| Demo | Deploy | Namespace | Needs | Success signals (see demo-specs.conf) | Built-in test |
|---|---|---|---|---|---|
| maas-ratelimit-demo | `deploy.sh -n` | maas-ratelimit-demo | RHOAI 3.4+, MaaS, an LLMISVC | Notebook `rate-limit-testing` | none |
| open-webui-demo | `deploy.sh -n --model-url --delete` | open-webui | a chat model (auto-detected if `--model-url` omitted) | Deploy/Route `open-webui`, probe `openwebui` (lists a non-`arena-model` model) | none (probes the 3.3-only `inference-gateway` host first) |
| nemo-guardrails-demo | `deploy.sh -n --name --selfcheck --model-url --model-name --delete` | nemo-guardrails-demo | TrustyAI (NemoGuardrails CRD); selfcheck auto-detects a chat model if `--model-url`/`--model-name` omitted | NemoGuardrails `nemo-quickstart` phase Ready, Route, Secret `api-token-secret`, probe `nemo` (PII prompt blocked) | `test_nemo_guardrails` (`lib/functions/nemo-guardrails.sh:136`), runs by default when stdin is not a TTY, warns only |
| lemonade-stand-demo | `deploy.sh` (env vars) / `deploy.sh --delete` | nemo-guardrails-demo | nemo-guardrails-demo route, deployed with `--selfcheck` (an LLM configured) | Deploy/Route `lemonade-stand` `/health`, probe `lemonade-chat` (chat answers, no `<think>`) | rollout 120s |
| university-safeguard-demo | `deploy.sh -n --model-url --model-name --model-api-key` | acme-university-demo | API key for external model (defaults to a workshop MaaS URL) | NemoGuardrails `university-safeguard`, ISVC `hap-detector` | `test_university_safeguard`, prompt-gated |
| lemonade-trustyai-demo | `deploy.sh -n ...` (helm) | lemonade-trustyai-demo | helm, 1 GPU, TrustyAI | ISVCs `llama-32`, `guardrails-detector-ibm-hap`, `prompt-injection-detector` | soft rollouts. FMS Orchestrator deprecated in 3.5 |
| financial-loan-demo | `deploy.sh -n --llm-url --skip-webapp --deploy-model` | financial-loan-demo | S3, Kaggle dataset, GPU for workbench | Notebook `model-training` (1 GPU), Deploy/Route `microloan-webapp`, ISVC `microloan-sklearn`, servedmodel check on `configmap/webapp-config` `LLM_MODEL_NAME` | none |
| pipeline-demo | `deploy.sh -n` | pipeline-demo | S3, DSPA | DSPA `pipelines-definition` Ready, Notebook `ai-pipelines` | none |
| lmeval-demo | `deploy.sh -n` | lmeval-demo (+ `llm`, `redhat-ods-applications`) | EvalHub, GPU, namespace `llm` | Notebook `model-benchmarking`, EvalHub `evalhub` Ready, ISVC `qwen3-8b-eval` | `run-benchmark.sh --status` |
| automl-demo (TP) | `deploy.sh -n` | automl-demo | DSPA | DSPA, Secret `aws-connection-automl-data`, ServingRuntime `kserve-autogluonserver` | none |
| autorag-demo (TP) | `deploy.sh -n` | autorag-demo | DSPA, Ready LLMISVC, HF egress | DSPA, `milvus-standalone`, `llamastack-postgres`, ISVC `bge-m3`; 3.5: `genai-pgvector`, `autorag-ogx`, Secret `autorag-ogx-connection` | soft rollouts |
| mlflow-tracing-demo | `deploy.sh` (fixed ns) | mlflow-tracing-demo | DSC mlflowoperator | 6 Deployments + Route `banking-dashboard` | soft rollouts |
| lightspeed-demo | `deploy.sh deploy` | lightspeed-demo, `0-test` | Lightspeed operator, `oc-mcp-server` in `0-test` | OLSConfig `cluster` overallStatus Ready | waits OLSConfig |
| n8n-demo | `deploy.sh -n` | n8n | — | Deploy/Route `n8n` | soft. Redeploy rotates the encryption key |
| nim-demo | `deploy.sh -n --ngc-key --model` | nim-demo | GPU, NGC key | any ISVC Ready | ISVC wait 900s |
| marketing-assistant-demo | `deploy.sh` (upstream) | marketing-assistant | 3x L40S | all Deployments ready | none |
| agentic-platform-demo | `deploy/deploy-all.sh` (edit `env.sh` CLUSTER_DOMAIN) | team1, keycloak, dify, ... | MaaS model, MLflow | `loan-agent` Deploy/Route, ISVC `hap-detector`, `dify-api` | none |
| feast-demo / banking-demo | menu `deploy_banking_demo` (`lib/functions/feast.sh:67`) | current project (set `FEAST_NS`) | DSC feastoperator | FeatureStore `banking` + 3 visibility rules, Notebook `feature-store` | service checks |
| llamastack-demo | manual `oc apply` (pre-OGX LlamaStackDistribution) | demo-test | — | Deploy `llamastack-mcp-demo` | none |
| guidellm-demo | menu `deploy_guidellm` | any | a model URL | pod `app=guidellm` | manual `oc rsh` |
| maas-demo | 3.3 only (`deploy-app.sh` exits on 3.4+) | — | — | not checked | — |

Prompts that block headless deploys: pipeline/lmeval `setup_pipeline_server` storage picker (lmeval hides
it with `2>/dev/null`), financial-loan Kaggle token, nemo/university test prompts, nemo `--selfcheck`,
mlflow-tracing (mlflowoperator), marketing confirm, all of feast `deploy_banking_demo`, guidellm.

## Notebooks

All notebooks reach the workbench by `git clone` of GitHub `gymnatics/RHOAI-Toolkit` **main** into
`/opt/app-root/src/RHOAI-Toolkit` (`lib/functions/workbench.sh` `clone_repo_in_workbench`). Local, unpushed
edits never reach the workbench.

| Notebook | Runs headless? | Blocker |
|---|---|---|
| feast-demo `feast-online-retrieval`, `feast-banking-complex` | **yes** (class safe) | none; `feast` is in the image |
| maas-ratelimit `maas-ratelimit-test` | **yes** | keys minted by deploy.sh into secret `maas-api-keys` (fixed 2026-11-11) |
| maas-ratelimit `maas-traffic-generator` | with `--force` (long) | fixed 2026-11-11: models discovered, `MAAS_BASE_URL` injected |
| financial-loan `predictive-model-development` | with `--force` if the dataset is in S3 (ran headless PASS 2026-11-11 on c35) | Kaggle dataset; defaults still minio/minio123; uploads `model.joblib` to `s3://models/microloan/`, which `deploy.sh --deploy-model` then deploys as ISVC `microloan-sklearn` |
| financial-loan `llm-model-fine-tuning` | no (GPU, HF downloads) | — |
| pipeline-demo `01..04` (Elyra) | **yes** (verified 2026-11-11) | fixed: sample data uploaded, one artifacts bucket, `REGISTERED_MODEL_NAME`, `REGISTRY_URL`. Still no `.pipeline` file |
| lmeval `english-benchmark` | with `--force` (10-40 min) | needs internet for pip |
| lmeval `guidellm-benchmark`, `korean-mcq-benchmark` | with `--force` (long) | pip cell added 2026-11-11 |
| lmeval `evalhub-sdk-demo` | with `--force` (long) | `input()` replaced by a clear error 2026-11-11; `client.health()` dict handling + `arc_easy` benchmark (not `mmlu`, which doesn't exist on this provider) + `tokenizer` arg fixed 2026-11-11 (ran headless PASS on c35). Fix only effective in pods after it is pushed and the workbench repo is pulled |

## Defects found (candidates for fixes / compat tracker)

1. ~~Workbench env not applied on first deploy~~ **fixed 2026-11-11** (`inject_notebook_env` merges keys and restarts the workbench pod when the env hash changes; hash kept in a Notebook metadata annotation because the CRD prunes `spec.template.metadata`).
2. ~~`NAMESPACE="${1:-...}"` flag-parsing bug in 8 demo scripts~~ **fixed 2026-11-10** (non-flag first arg only).
3. ~~autorag top-level `local`~~ **fixed 2026-11-10**, together with: re-patching an existing `llama-stack-config`, recreating a pre-fix (baseConfig) OGXServer, the missing `ogx.io/watch=true` label (regression from df8b5b4), and pgvector password reuse.
4. ~~Workbench images default to `:3.4` tags~~ **fixed 2026-11-11** for new workbenches (`workbench_image`); existing workbenches keep their image.
5. ~~`wait_for_workbench` checks Running, not Ready~~ **fixed 2026-11-11**
6. ~~lmeval `MLFLOW_TRACKING_URI` without `/mlflow`; `TOKENIZER_HF_ID` never injected~~ **fixed 2026-11-11** (`demo-config-env` ConfigMaps still unused)
7. ~~3.3-only `inference-gateway` probes~~ **fixed 2026-11-11** (only on 3.3)
8. ~~`deploy-demo-environment.sh is_deployed automl` checks MinIO~~ **fixed 2026-11-11** (checks the DSPA)
9. ~~No delete for lemonade-stand; pipeline-demo `--delete` only DSPA~~ **fixed 2026-11-11**
10. `scripts/test-demos.sh` (planned in `rhoai-version-bump/demo-test-matrix.md:56`) does not exist. `checks/run-all.sh` covers it.
11. ~~automl/autorag DSPA hard-coded MinIO host + `minio-secret`~~ **fixed 2026-11-10** (rendered from the storage backend, `pipelines-s3-credentials`).
12. ~~`quay.io/minio/minio` no longer anonymously pullable~~ **fixed 2026-11-10** (7 manifests pinned to `quay.io/opendatahub/minio:RELEASE.2019-08-14T20-37-41Z-license-compliance`; SeaweedFS recommended).
13. ~~`setup_pipeline_server` kept stale credentials secret~~ **fixed 2026-11-10**.
14. ~~n8n key regenerated on every deploy~~ **fixed 2026-11-10**.
15. Open: OGX `spec.distribution.name: rh-dev` now warns "deprecated, use rh"; the working autorag config depends on it.
16. ~~Model templates have no GPU-architecture affinity~~ **fixed 2026-11-11** for the FP8 models (qwen3-8b, gemma, granite-tiny-gpu)
17. ~~financial-loan: no predictive model ever deployed, `/api/predict` silently used the mock/local fallback~~ **fixed 2026-11-11** (`deploy.sh --deploy-model`, `ensure_predictive_runtime`/`deploy_predictive_model`, ISVC `microloan-sklearn`)
18. ~~financial-loan: `webapp-config` `LLM_MODEL_NAME` held the LLMInferenceService resource name instead of the served model id, `/api/explain` got HTTP 404~~ **fixed 2026-11-11** (`resolve_served_model_id()` in `lib/functions/notebook-env.sh`)
19. ~~lmeval `evalhub-sdk-demo.ipynb`: `client.health()` dict `AttributeError`; benchmark id `mmlu` does not exist in the RHOAI 3.5.1 provider~~ **fixed 2026-11-11** (reads the dict directly; uses `arc_easy` after checking it exists; passes `tokenizer`)
20. ~~Open WebUI: `manifests/open-webui.yaml` used `${MODEL_URL:-}`, which `envsubst` leaves as literal text (ConfigMap held `OPENAI_API_BASE_URLS=${MODEL_URL:-}`); detection took the first `InferenceService` in the cluster (could be an embedding/sklearn model) and never considered `LLMInferenceService`~~ **fixed 2026-11-11** (manifest uses `${MODEL_URL}` rendered with an explicit `envsubst` var list; detection uses `detect_direct_llm_endpoint`; new `MODEL_TLS_VERIFY`/`AIOHTTP_CLIENT_SESSION_SSL` for in-cluster https endpoints; `deploy.sh` restarts the deployment)
21. ~~NeMo Guardrails: `setup_nemo_guardrails_auth` minted a 336h (14-day) token into `api-token-secret` once and never refreshed it, so it expired (2026-10-05 on c35) and lemonade-stand (which copies the token) got 401~~ **fixed 2026-11-11** (token re-minted on every deploy, default 8760h/1 year; also affects university-safeguard-demo, which shares the function)
22. ~~NeMo Guardrails `--selfcheck` prompted interactively for a namespace/name and guessed `https://<name>-predictor.<ns>.svc:8080/v1` with the resource name as model id; built-in tests and sample curl commands sent `"model": "test"`, which vLLM 404s on~~ **fixed 2026-11-11** (auto-detects the chat model via `detect_direct_llm_endpoint`/`resolve_served_model_id`, new `--model-url --model-name` flags; tests/samples read `model_name` from the `<name>-config` ConfigMap via `_nemo_request_model`)
23. ~~lemonade-stand: replies showed Qwen3's `<think>...` reasoning and were cut off at `max_tokens=300` (NeMo's streaming path doesn't apply `chat_template_kwargs.enable_thinking: false`, and doesn't pass the client system message through, so `/no_think` in the system prompt had no effect)~~ **fixed 2026-11-11** (`app.py` appends `/no_think` to the user message instead, env `DISABLE_THINKING` default `true`; strips a leading `<think>...</think>` block from streamed and non-streamed replies)
