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

## Demos

| Demo | Deploy | Namespace | Needs | Success signals (see demo-specs.conf) | Built-in test |
|---|---|---|---|---|---|
| maas-ratelimit-demo | `deploy.sh -n` | maas-ratelimit-demo | RHOAI 3.4+, MaaS, an LLMISVC | Notebook `rate-limit-testing` | none |
| open-webui-demo | `deploy.sh -n --model-url` | open-webui | a model URL | Deploy/Route `open-webui` | none (probes the 3.3-only `inference-gateway` host first) |
| nemo-guardrails-demo | `deploy.sh -n --name --selfcheck` | nemo-guardrails-demo | TrustyAI (NemoGuardrails CRD) | NemoGuardrails `nemo-quickstart` phase Ready, Route | `test_nemo_guardrails` (`lib/functions/nemo-guardrails.sh:118`), prompt-gated, warns only |
| lemonade-stand-demo | `deploy.sh` (env vars; no `--delete`) | nemo-guardrails-demo | nemo-guardrails-demo route | Deploy/Route `lemonade-stand` `/health` | rollout 120s |
| university-safeguard-demo | `deploy.sh -n --model-url --model-name --model-api-key` | acme-university-demo | API key for external model (defaults to a workshop MaaS URL) | NemoGuardrails `university-safeguard`, ISVC `hap-detector` | `test_university_safeguard`, prompt-gated |
| lemonade-trustyai-demo | `deploy.sh -n ...` (helm) | lemonade-trustyai-demo | helm, 1 GPU, TrustyAI | ISVCs `llama-32`, `guardrails-detector-ibm-hap`, `prompt-injection-detector` | soft rollouts. FMS Orchestrator deprecated in 3.5 |
| financial-loan-demo | `deploy.sh -n --llm-url --skip-webapp` | financial-loan-demo | S3, Kaggle dataset, GPU for workbench | Notebook `model-training` (1 GPU), Deploy/Route `microloan-webapp` | none |
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
| maas-ratelimit `maas-ratelimit-test` | with `MAAS_API_KEY` in pod env | key never injected; mint with `get_maas_api_key` (`demo/lib/rhoai-detect.sh:273`) |
| maas-ratelimit `maas-traffic-generator` | no | reads `MAAS_BASE_URL` (never injected), hard-coded models in `a-rh-department` |
| financial-loan `predictive-model-development` | with `--force` if the dataset is in S3 | Kaggle dataset; defaults still minio/minio123 |
| financial-loan `llm-model-fine-tuning` | no (GPU, HF downloads) | — |
| pipeline-demo `01..04` (Elyra) | no | `sample-loans.csv` never uploaded; 01 writes `artifacts`, 02/03 read `models`; 04 `MODEL_NAME` overwritten by the LLM name; no `.pipeline` file in the repo |
| lmeval `english-benchmark` | with `--force` (10-40 min) | needs internet for pip |
| lmeval `guidellm-benchmark`, `korean-mcq-benchmark` | no | import `evalhub` without a pip cell |
| lmeval `evalhub-sdk-demo` | no | `input()` when MODEL_NAME/MODEL_URL unresolved |

## Defects found (candidates for fixes / compat tracker)

1. Workbench env not applied on first deploy (`lib/functions/notebook-env.sh:424-453`: patches Notebook only when `envFrom` is missing; template already has it, so no restart).
2. ~~`NAMESPACE="${1:-...}"` flag-parsing bug in 8 demo scripts~~ **fixed 2026-11-10** (non-flag first arg only).
3. ~~autorag top-level `local`~~ **fixed 2026-11-10**, together with: re-patching an existing `llama-stack-config`, recreating a pre-fix (baseConfig) OGXServer, the missing `ogx.io/watch=true` label (regression from df8b5b4), and pgvector password reuse.
4. Workbench images default to `:3.4` tags on a 3.5 toolkit (`lib/functions/workbench.sh:40`, `:244`; `demo/financial-loan-demo/deploy.sh:332`); `create_workbench` never updates an existing Notebook.
5. `wait_for_workbench` checks pod phase Running, not Ready; clone errors are hidden (`2>/dev/null`).
6. lmeval injects `MLFLOW_TRACKING_URI` without the `/mlflow` suffix its own comment requires (`demo/lmeval-demo/deploy.sh:339` vs `:97`); `TOKENIZER_HF_ID` never injected; `demo-config-env` ConfigMaps never mounted.
7. 3.3-only `inference-gateway.<domain>` probes in open-webui (`deploy.sh:58`) and financial-loan (`:201`).
8. `scripts/deploy-demo-environment.sh is_deployed automl` checks `deployment minio` (SeaweedFS is the default).
9. No delete path for lemonade-stand; pipeline-demo `--delete` only removes the DSPA.
10. `scripts/test-demos.sh` (planned in `rhoai-version-bump/demo-test-matrix.md:56`) does not exist. `checks/run-all.sh` covers it.
11. ~~automl/autorag DSPA hard-coded MinIO host + `minio-secret`~~ **fixed 2026-11-10** (rendered from the storage backend, `pipelines-s3-credentials`).
12. ~~`quay.io/minio/minio` no longer anonymously pullable~~ **fixed 2026-11-10** (7 manifests pinned to `quay.io/opendatahub/minio:RELEASE.2019-08-14T20-37-41Z-license-compliance`; SeaweedFS recommended).
13. ~~`setup_pipeline_server` kept stale credentials secret~~ **fixed 2026-11-10**.
14. ~~n8n key regenerated on every deploy~~ **fixed 2026-11-10**.
15. Open: OGX `spec.distribution.name: rh-dev` now warns "deprecated, use rh"; the working autorag config depends on it.
16. Open: model templates have no GPU-architecture affinity; FP8 models can land on T4 (g4dn) nodes and crash.
