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
| A1 | lmeval notebooks: add a `%pip install eval-hub-sdk[client]` cell to `guidellm-benchmark` and `korean-mcq-benchmark`; `evalhub-sdk-demo`: replace `input()` with env vars and a clear error; `MLFLOW_TRACKING_URI` gets the `/mlflow` suffix its own comment requires; inject `TOKENIZER_HF_ID` | `demo/lmeval-demo/**/*.ipynb`, `demo/lmeval-demo/deploy.sh` |
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

- financial-loan `predictive-model-development` needs the Kaggle microloan dataset in S3. Without a Kaggle token
  it stays "needs-data". `llm-model-fine-tuning` (GPU + Hugging Face downloads, long) is not auto-run.
- Elyra `.pipeline` file for pipeline-demo (README promises one; none exists): can add one, but untested in UI.
- RHOAI 3.5.2 / Service Mesh upgrades (question 2).
