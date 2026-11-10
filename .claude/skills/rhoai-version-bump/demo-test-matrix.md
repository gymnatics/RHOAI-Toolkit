# Demo Test Matrix

Used by `rhoai-version-bump` Phase 7. Run from the repo root, in the order listed (dependencies first). **core** = the default `--demos core` set.

Conventions:
- `$NS` is the demo's default namespace.
- **Ready** = readiness checks. **Func** = functional proof that the demo works. **Clean** = teardown.
- `R()` means "the route host": `R() { oc get route "$1" -n "$2" -o jsonpath='{.spec.host}'; }`
- Wait helper: `oc wait --for=condition=Ready pod --all -n $NS --timeout=900s`, then `oc get pods -n $NS` with no pods outside `Running|Completed`.
- Checks marked **[refine]** are a first draft. Tighten them after the first real run and record what worked in the run log.

## 0. Platform prerequisites (must PASS before any demo)

| Step | Command | Pass criteria |
|---|---|---|
| Storage | `./scripts/setup-model-storage.sh --backend seaweedfs` | `oc rollout status deploy/seaweedfs -n <ns>` succeeds |
| Hardware profile | `oc get hardwareprofile gpu-profile -n redhat-ods-applications` | Exists, has the `nvidia.com/gpu` toleration |
| Shared LLM (MaaS) | `./scripts/deploy-maas-model.sh --model auto` | `oc get llminferenceservice -A` shows Ready=True; `./scripts/verify-maas.sh` passes |
| MCP | `./scripts/setup-mcp-servers.sh --non-interactive` | `oc get mcpserver -n ai-tenants` Ready; listed in AI asset endpoints |

## 1. Demos

| # | Demo | Tier | Prereqs | Deploy | Ready | Func | RBAC check | Clean |
|---|---|---|---|---|---|---|---|---|
| 1 | maas-ratelimit | **core** | MaaS model | `./demo/maas-ratelimit-demo/deploy.sh` | Pods Ready in `maas-ratelimit-demo`; workbench Notebook Ready | Create a key, send calls past the subscription token limit, expect HTTP **429**. Run the demo notebook headless with `jupyter nbconvert --execute` **[refine]** | Workbench SA can read the injected env secret | `./demo/maas-ratelimit-demo/deploy.sh --delete` |
| 2 | open-webui | **core** | Any LLM endpoint | `./demo/open-webui-demo/deploy.sh` | `deployment/open-webui` Available | `curl -sk https://$(R open-webui open-webui)` returns HTTP 200; the model list includes the detected model **[refine]** | -- | `./demo/open-webui-demo/deploy.sh --delete` |
| 3 | nemo-guardrails | **core** | LLM endpoint | `./demo/nemo-guardrails-demo/deploy.sh` | NemoGuardrails CR / pods Ready | A PII prompt (email/name) is **blocked or masked**; a benign prompt passes | -- | `./demo/nemo-guardrails-demo/deploy.sh --delete` |
| 4 | lemonade-stand | | nemo-guardrails (#3) | `./demo/lemonade-stand-demo/deploy.sh` | `deployment/lemonade-stand` Available | `https://$(R lemonade-stand nemo-guardrails-demo)` returns 200; an off-topic prompt is refused **[refine]** | -- | Delete the `lemonade-stand` resources in `nemo-guardrails-demo` (no `--delete` flag) |
| 5 | university-safeguard | | LLM endpoint | `./demo/university-safeguard-demo/deploy.sh` | `inferenceservice/hap-detector` Ready; pods Ready in `acme-university-demo` | PII, HAP and regex prompts are each blocked | -- | `./demo/university-safeguard-demo/deploy.sh --delete` |
| 6 | lemonade-trustyai | | 1 GPU | `./demo/lemonade-trustyai-demo/deploy.sh` | `guardrails-orchestrator`, `lemonade-stand`, `shiny-dashboard` Available | The app returns 200; a detector flags a test prompt. Note: FMS Orchestrator is **deprecated in 3.5** | -- | `./demo/lemonade-trustyai-demo/deploy.sh --delete` |
| 7 | financial-loan | **core** | MaaS / LLM | `./demo/financial-loan-demo/deploy.sh` | Predictive InferenceService Ready; `deployment/microloan-webapp` Available; Notebook Ready | The webapp route returns 200; a sample loan scoring returns a prediction plus an LLM explanation **[refine]** | Workbench SA RBAC (fixed in 6396716) | `./demo/financial-loan-demo/deploy.sh --delete` |
| 8 | pipeline | **core** | S3 storage | `./demo/pipeline-demo/deploy.sh` | DSPA Ready (`oc get dspa -n pipeline-demo`); Notebook Ready | Submit the demo pipeline; the run reaches **Succeeded** (`oc get workflow -n pipeline-demo`) **[refine]** | `pipeline-runner-*` SA can create pods | `./demo/pipeline-demo/deploy.sh --delete` |
| 9 | lmeval | **core** | LLM endpoint; TrustyAI | `./demo/lmeval-demo/deploy.sh` | `evalhub` CR Ready; `inferenceservice/qwen3-8b-eval` Ready | `./demo/lmeval-demo/run-benchmark.sh` completes one small benchmark; results visible in MLflow **[refine]** | EvalHub job SA + service-ca CM (fixed in 0ff5ab7) | `./demo/lmeval-demo/deploy.sh --delete` |
| 10 | automl | | DSPA, S3 | `./demo/automl-demo/deploy.sh` | DSPA `pipelines-definition` Ready | The AutoML pipeline run Succeeded (TP) **[refine]** | -- | `./demo/automl-demo/deploy.sh --delete` |
| 11 | autorag | **core** | DSPA, S3, LLM, OGX | `./demo/autorag-demo/deploy.sh` | Milvus, Postgres and embedding model Ready; **OGXServer phase Ready** (RHOAIENG-96724 workaround applied); `autorag-ogx-connection` secret exists | The AutoRAG run reaches the leaderboard, or at minimum OGX `/v1/models` lists the LLM plus the embedding model **[refine]** | -- | `./demo/autorag-demo/deploy.sh --delete` |
| 12 | mlflow-tracing | **core** | 1 GPU / LLM; image builds | `./demo/mlflow-tracing-demo/deploy.sh` | `banking-dashboard`, `customer-analyst` and the other agent Deployments Available | Dashboard route 200; send one query; a new trace appears in MLflow with multiple agent spans **[refine]** | -- | `./demo/mlflow-tracing-demo/deploy.sh --delete` |
| 13 | lightspeed | **core** | LLM (InferenceService or LLMInferenceService) | `./demo/lightspeed-demo/deploy.sh deploy` | `olsconfig cluster` Ready; `deployment/customer-portal` Available | `./demo/lightspeed-demo/deploy.sh broken-app`, then ask OLS to diagnose: an MCP tool call is made and the context window is respected | OLS SA / MCP read RBAC | `./demo/lightspeed-demo/deploy.sh cleanup` |
| 14 | n8n | | -- | `./demo/n8n-demo/deploy.sh` | `deployment/n8n` Available | `https://$(R n8n n8n)` returns 200 | -- | `./demo/n8n-demo/deploy.sh --delete` |
| 15 | feast / banking | **core** | -- | `./scripts/deploy-demo-environment.sh --skip-core --components feast` | FeatureStore CR Ready; label `feature-store-ui: enabled`; namespace has `opendatahub.io/dashboard=true` | The feature store appears in the dashboard; online feature retrieval from the notebook returns values **[refine]** | -- | Delete namespace `feast-demo` |
| 16 | model-catalog | | -- | `./scripts/deploy-demo-environment.sh --skip-core --components model-catalog` | The custom catalog source ConfigMap applied | Custom models visible under AI Hub → Catalog | -- | `oc delete -f lib/manifests/demo/custom-model-catalog.yaml` |
| 17 | guidellm | | LLM endpoint | Toolkit menu → Demos → GuideLLM (`deploy_guidellm`) | Job created | The job completes with TTFT/ITL output | -- | Delete the job |
| 18 | nim | | NGC key; 1× L40S/T4 | `./demo/nim-demo/deploy.sh --ngc-key $NGC_API_KEY` | NIM InferenceService Ready | A `/v1/chat/completions` call returns 200 | -- | `./demo/nim-demo/deploy.sh --delete` |
| 19 | agentic-platform | | 1× A10G; Keycloak, Kagenti (DP) | `./demo/agentic-platform-demo/deploy/deploy-all.sh` | Pods Ready in `team1`, `keycloak`, `kagenti-system` | The loan agent completes one request through the MCP gateway **[refine]** | Keycloak client + agent SA | Per the demo README |
| 20 | marketing-assistant | | **3× L40S** | `./demo/marketing-assistant-demo/deploy.sh` | Per the upstream repo | Per the upstream repo | -- | `./demo/marketing-assistant-demo/deploy.sh --delete` |

**Not run on RHOAI 3.4+:** `maas-demo` (3.3 tier-based MaaS only). Record it as `N/A (3.3-only)`.

## 2. Skip rules
- No GPU node: skip 6, 12, 18, 19 and 20, plus the GPU-model parts of 0. Use `--model simulator` for MaaS.
- No `NGC_API_KEY`: skip 18. Fewer than 3 GPUs: skip 20.
- External-provider demos need API keys in the environment. Skip them if the keys are absent and never prompt for keys inline.

## 3. Maintaining this matrix
- When a demo is added or renamed (`demo/*/deploy.sh`, or the registry at the top of `scripts/deploy-demo-environment.sh`), add or update its row here.
- After each run, replace **[refine]** checks that were validated with the exact command used, and copy any new failure modes into the demo README's troubleshooting section.
- Once the rows have stabilised, build `scripts/test-demos.sh` from them (one function per row: deploy, ready, func, clean) so Phase 7 becomes deterministic.
