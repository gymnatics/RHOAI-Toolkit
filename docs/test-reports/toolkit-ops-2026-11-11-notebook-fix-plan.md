# Plan: notebooks, workbenches and remaining toolkit defects (2026-11-11)

Scope: everything still open in `docs/test-reports/toolkit-ops-2026-11-10.md` and
`.claude/skills/toolkit-ops/reference/demo-checks.md`, on the **RHOAI 3.5 cluster** (ocp.sclg6, 3.5.1).
The 3.4 cluster is out of scope (reference only, expiring). The reference autorag cluster (ocp.5msvc) is
currently unreachable and not needed.

## State this morning (read-only check)

- 3.5: all 8 g6e GPU instances are EC2-`stopped` again (the 7 replaced yesterday plus the original one). No
  CronJob in the cluster does this, so it comes from outside (sandbox policy or a `manage-gpu-nodes.sh stop`).
  GPU models, the financial-loan GPU workbench, autorag LLM calls and lmeval are down until they return.
- 3.5: pending Manual InstallPlans: `rhods-operator.3.5.2`, `servicemeshoperator3.v3.4.3` / `v3.5.0`.
- 3.5 workbench images: ImageStreams have `3.5` and `2025.2` tags; the toolkit still creates workbenches with `:3.4`.

## A. Repo fixes (then commit + push to main)

| # | Fix | Files |
|---|---|---|
| A1 | lmeval notebooks: add a `%pip install eval-hub-sdk[client]` cell to `guidellm-benchmark` and `korean-mcq-benchmark`; `evalhub-sdk-demo`: replace `input()` with env vars and a clear error; `MLFLOW_TRACKING_URI` gets the `/mlflow` suffix its own comment requires; inject `TOKENIZER_HF_ID` — **done; 2026-11-11 verification needed two more `evalhub-sdk-demo` fixes (`client.health()` dict handling, `mmlu`→`arc_easy` benchmark id) — see follow-up section below** | `demo/lmeval-demo/**/*.ipynb`, `demo/lmeval-demo/deploy.sh` |
| A2 | maas-ratelimit: deploy mints a MaaS API key (`get_maas_api_key`, subscription matching the model, e.g. `qwen3-8b-free`) and injects `MAAS_API_KEY` + `MAAS_BASE_URL`; `maas-traffic-generator` reads the endpoint and the model list from `/v1/models` instead of hard-coded `a-rh-department` models | `demo/maas-ratelimit-demo/deploy.sh`, both notebooks |
| A3 | pipeline-demo: upload `data/sample-loans.csv` to `datasets`; 02/03 read the bucket 01 writes (`ARTIFACTS_BUCKET`); 04 uses its own `REGISTERED_MODEL_NAME` (not the LLM `MODEL_NAME`); `--delete` also removes the workbench/storage it created | `demo/pipeline-demo/deploy.sh`, `pipeline-elyra/*.ipynb` |
| A4 | Workbench env: after `inject_notebook_env` changes the ConfigMap, restart the workbench pod if it's running with an older env (today nothing restarts it, so first-deploy notebooks see only `NAMESPACE`) | `lib/functions/notebook-env.sh` |
| A5 | `refresh-notebook-env.sh`: merge into the existing ConfigMap instead of rebuilding it (it drops MODEL_ID, MAAS_ROUTING, LIMIT, MLFLOW_TRACKING_URI, bucket names) | `scripts/refresh-notebook-env.sh`, `notebook-env.sh` |
| A6 | Workbench image default follows the RHOAI version (`:3.5` on 3.5, `:3.4` on 3.4); `wait_for_workbench` waits for Ready (not just Running); clone errors are shown, not hidden | `lib/functions/workbench.sh`, `demo/financial-loan-demo/deploy.sh` |
| A7 | GPU-architecture affinity for FP8 models (TRK-015): `nvidia.com/gpu.compute.major Gt 7` in the toolkit's qwen3-8b manifests/templates | `lib/manifests/maas/models/qwen3-8b/**`, LLMISVC templates |
| A8 | Small defects: drop the 3.3-only `inference-gateway` probes (open-webui, financial-loan); `deploy-demo-environment.sh` checks SeaweedFS for automl; lemonade-stand `--delete`; `install-rhoai-3{4,5}.sh` channel fallback `fast-3.x` → `stable-3.x` (compat tracker); label DP dashboard flags as DP in `enable_tp_features_interactive` (TRK-001); unused `demo-config-env` ConfigMaps | various |
| A9 | toolkit-ops: update `notebook-specs.conf` classes for fixed notebooks, tests, docs (TROUBLESHOOTING, tracker, demo-checks) | `.claude/skills/toolkit-ops/`, `docs/` |

Verify: `bash -n`, notebook JSON validity, toolkit-ops offline tests, server dry-run of changed manifests.

## B. 3.5 cluster

1. GPU nodes back (see question 1), `manage-gpu-nodes.sh cleanup`, confirm `qwen3-8b` Ready (affinity already set).
2. Push A first, then update each workbench's repo copy (`git pull`; see question 3).
3. Re-run the fixed deploys: maas-ratelimit, lmeval, pipeline-demo, financial-loan (`-n`, non-interactive where
   possible) to inject the full env; restart workbenches.
4. Start `qwen3-8b-eval` (lmeval needs it). Leave `simulator` stopped (its subscription is Failed; not used).
5. Validate with `/toolkit-ops notebooks --execute` (see question 4) and re-run the full checks; update the report.

## Not planned (needs your call)

- ~~financial-loan `predictive-model-development` needs the Kaggle microloan dataset in S3. Without a Kaggle token
  it stays "needs-data".~~ **Done 2026-11-11**: the dataset was present in S3 on c35, the notebook ran headless
  PASS, and `deploy.sh` gained `--deploy-model` to deploy the resulting model — see follow-up section below.
  `llm-model-fine-tuning` (GPU + Hugging Face downloads, long) is still not auto-run.
- Elyra `.pipeline` file for pipeline-demo (README promises one; none exists): can add one, but untested in UI.
- RHOAI 3.5.2 / Service Mesh upgrades (question 2).

## 2026-11-11 follow-up: financial-loan end to end, lmeval notebooks, inline manifest cleanup

Verified live on RHOAI 3.5.1 / OCP 4.21, sandbox c35.

### Financial-loan predictive model (new, closes the Kaggle-dataset item above)

- `demo/financial-loan-demo/deploy.sh` gained `--deploy-model`: (re)deploys only the predictive model and
  repoints the web app, then exits (`./demo/financial-loan-demo/deploy.sh -n financial-loan-demo --deploy-model`).
  A normal deploy also calls it (non-fatal) once the trained model exists in S3.
- New functions `ensure_predictive_runtime` (`ServingRuntime` `mlserver-runtime` from template
  `mlserver-runtime-template` in `redhat-ods-applications`) and `deploy_predictive_model` (checks
  `s3://models/microloan/model.joblib` via an aws-cli pod, renders
  `demo/financial-loan-demo/manifests/predictive-inferenceservice.yaml.tmpl`, waits up to 300s for Ready, sets
  `SKLEARN_API_URL` in ConfigMap `webapp-config`, restarts `deployment/microloan-webapp`).
- The model artifact comes from running `demo/financial-loan-demo/notebooks/predictive-model-development.ipynb`
  in workbench `model-training`; it uploads `model.joblib` to bucket `models`, prefix `microloan/`, via data
  connection `aws-connection-minio`.
- Result: predictive notebook executed headless PASS; `deploy.sh -n financial-loan-demo --deploy-model` → ISVC
  `microloan-sklearn` Ready; POST sample applicant 1 to `/api/predict` → Approved, 71.7% approval, log
  `✓ API prediction: 71.7% non-default, 28.3% default` and `✓ Using API endpoint for prediction` (previously the
  app silently used `Using mock prediction`). `check-demos.sh --demo financial-loan-demo`: 7 PASS, 0 FAIL.

### Financial-loan LLM model id bug (fixed)

- `/api/explain` returned a template sentence instead of an LLM explanation; web app log showed
  `LLM Response status: 404` and `The model \`qwen3-8b\` does not exist.`. Cause: `webapp-config`
  `LLM_MODEL_NAME` held the LLMInferenceService resource name (`qwen3-8b`) instead of the served id
  (`RedHatAI/Qwen3-8B-FP8-dynamic`).
- New shared helper `resolve_served_model_id <name> <namespace>` in `lib/functions/notebook-env.sh`
  (LLMInferenceService `spec.model.name`, else InferenceService `--served-model-name`, else the resource name).
  `demo/financial-loan-demo/deploy.sh` uses it for both `webapp-config` and `demo-config-env`.
- Result: after the fix, `/api/explain` → HTTP 200 with a generated explanation.

### lmeval notebooks (extends A1)

- `evalhub-sdk-demo.ipynb`: `client.health()` in eval-hub-sdk 0.4 returns a plain dict, not an object
  (`health.status` raised `AttributeError`); fixed to read the dict directly. Job submit also failed with HTTP
  400 `resource_does_not_exist` for benchmark id `mmlu` (not present among the 188 benchmarks the RHOAI 3.5.1
  `lm_evaluation_harness` provider lists); the notebook now checks `arc_easy` exists first and uses it, and
  passes `tokenizer` (`TOKENIZER_HF_ID`) since the served name `qwen3-8b-eval` is not an HF id.
- Note: `jupyter nbconvert --execute` writes no output file when a cell fails; use `--allow-errors` to capture
  tracebacks.
- Results (`check-notebooks.sh --demo lmeval-demo --execute --force`): english-benchmark PASS, guidellm-benchmark
  PASS, korean-mcq-benchmark PASS, evalhub-sdk-demo FAIL before fix → all cells PASS after fix (ARC-Easy job
  completed; safety-and-fairness-v1 collection job submitted).

### Inline manifest cleanup (repo rule: manifests live in their own files)

- New `demo/financial-loan-demo/manifests/webapp-config.yaml.tmpl` (ConfigMap `webapp-config`) replaces a
  heredoc in `deploy.sh`.
- New `demo/autorag-demo/manifests/ogx-connection-secret.yaml.tmpl` (Secret `autorag-ogx-connection`) replaces a
  heredoc in autorag `deploy.sh`.
- Data connections in automl-demo, autorag-demo and financial-loan-demo `deploy.sh` now call
  `create_data_connection` (`lib/functions/storage-backend.sh`), which renders
  `lib/manifests/storage/<backend>/data-connection.yaml.tmpl`, instead of inline Secret heredocs. New env
  overrides: `DATA_CONNECTION_NAME` (default `aws-connection-minio`), `DATA_CONNECTION_ENDPOINT`,
  `DATA_CONNECTION_COMPAT` (default true, also creates compat secret `aws-connection-my-storage`). New helper
  `get_storage_external_endpoint <ns>`. Also fixed a latent bug: the minio template referenced `MINIO_*` vars
  that `create_data_connection` never set; it now uses the same `S3_*` vars as seaweedfs/ceph-rgw.

### toolkit-ops skill

- New check type `servedmodel` in `checks/check-demos.sh` (target `configmap/NAME`, 5th field = key, default
  `LLM_MODEL_NAME`): PASS if the value is an id served by some LLMInferenceService or InferenceService, FAIL
  otherwise. Read-only.
- `checks/demo-specs.conf` financial-loan-demo gained `servedmodel configmap/webapp-config LLM_MODEL_NAME` and
  `isvc microloan-sklearn`.
- Offline skill tests: 61 assertions pass.

### Known remaining

- Workbenches still on `:3.4` image tags on RHOAI 3.5 (WARN).
- The toolkit-ops check for EvalHub notebooks still runs the GitHub `main` copy of `evalhub-sdk-demo.ipynb` in
  the pod, so the fix is only effective in pods after it is pushed to `main` and the workbench repo
  (`clone_repo_in_workbench`) is pulled.
