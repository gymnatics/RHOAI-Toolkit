# toolkit-ops check report

- Date: 2026-11-11 15:49 +08
- Cluster: https://api.ocp.sclg6.sandbox323.opentlc.com:6443 | OpenShift 4.21.31 | RHOAI 3.5.1
- Phases: infra,platform,serving,maas,demos,notebooks 

- FAIL: 1
- WARN: 15
- PASS: 168
- INFO: 24
- SKIP: 13

## Triage (2026-11-11, after the fixes in commit 61fa06c)

- `maas/models`: the run reported FAIL for `llm/simulator`; the simulator is stopped on purpose
  (`serving.kserve.io/stop=true`). check-maas.sh now reports this as WARN (re-checked live: WARN), and the
  counts and row above were corrected to match.
- `platform/dsc-phase` FAIL "degraded: ogx": product status aggregation. The demo OGXServers work (autorag chat
  completion OK); the Playground OGXServers report `ConfigGenerated` False (informational). Not a toolkit defect.
- Workbench `:3.4` image WARNs: existing Notebooks keep their image; new deploys pick the 3.5 tag
  (`workbench_image`). Switching requires restarting the workbenches (user approval).
- Restart WARNs: accumulated over the GPU auto-stop/start cycles; all pods are Ready.
- Pending InstallPlans: not approved (never bulk-approve; check with scripts/check-pending-installplans.sh).
- Demos: financial-loan 7/7 PASS (predict through the model API, explain through the LLM); lmeval notebooks
  executed headless earlier the same day, all four PASS after the evalhub-sdk-demo fix.
- Not done: notebooks were not re-executed in this run (no `--execute`); the 3.4 cluster is out of scope.

| Status | Area | Check | Result | Next step |
|---|---|---|---|---|
| FAIL | platform | dsc-phase | DSC default-dsc phase=Not Ready Some modules are degraded: ogx | oc describe dsc default-dsc; see per-component results below |
| WARN | maas | models | MaaSModelRefs not Ready because the model is stopped on purpose (serving.kserve.io/stop=true): llm/simulator | Start the model before using it through MaaS (user approval) |
| WARN | operators | rhcl-version | RHCL 1.4.3: RHOAIENG-76586 (1.4.x rate limiting / gateway OOM) applies | scripts/diagnose-maas.sh Issue 6 |
| WARN | operators | pending-installplans | Unapproved InstallPlans: openshift-operators/install-hggj7,openshift-operators/install-wrvq5,redhat-ods-operator/install-hpczs | scripts/check-pending-installplans.sh (approve only if expected) |
| WARN | pods | redhat-ods-operator-restarts | Ready but restarted often: rhods-operator-574857d665-68d7k(43, last: ?),rhods-operator-574857d665-mzpdk(72, last: Completed),rhods-operator-574857d665-nmtf9(76, last: Error) | oc logs -n redhat-ods-operator <pod> --previous (OOMKilled -> limits; Error -> logs) |
| WARN | pods | redhat-ods-applications-restarts | Ready but restarted often: agent-ops-ui-5f459647b7-wzcs9(19, last: ?),ai-gateway-operator-f856bf789-bkvww(57, last: Error),automl-ui-7b845bdcfc-g98xd(19, last: ?),autorag-ui-6756d9478d-c2qsg(19, last: ?),dashboard-operator-57bf5594ff-rdhx2(52, last: Error),dashboard-redirect-76d7b5555f-k74qs(19, last: ?),dashboard-redirect-76 | oc logs -n redhat-ods-applications <pod> --previous (OOMKilled -> limits; Error -> logs) |
| WARN | pods | redhat-ods-monitoring-restarts | Ready but restarted often: data-science-perses-0(6, last: ?),data-science-prometheus-cluster-proxy-56446d648-mjz44(19, last: ?),data-science-prometheus-namespace-proxy-584c49c8d9-sb2pf(19, last: ?),minio-usage-logs-5849f55c75-lgpf9(21, last: ?),usage-logs-tenancy-proxy-f67dd75f4-zllhq(19, last: ?) | oc logs -n redhat-ods-monitoring <pod> --previous (OOMKilled -> limits; Error -> logs) |
| WARN | pods | redhat-ai-gateway-infra-restarts | Ready but restarted often: maas-api-95947c4b8-wcm6k(38, last: Error),postgres-8bdd7889b-ztvpp(22, last: ?) | oc logs -n redhat-ai-gateway-infra <pod> --previous (OOMKilled -> limits; Error -> logs) |
| WARN | dashboard | flag-agentsCatalog | agentsCatalog=true is a Developer Preview feature (unsupported) | Label as DP to users; TRK-001 in docs/COMPATIBILITY-TRACKER.md |
| WARN | dashboard | flag-agentConfigManagement | agentConfigManagement=true is a Developer Preview feature (unsupported) | Label as DP to users; TRK-001 in docs/COMPATIBILITY-TRACKER.md |
| WARN | dashboard | flags | Differs from toolkit patch: disableKueue=unset(want false)  | scripts/enable-dashboard-features.sh (or flags intentionally changed) |
| WARN | maas-diag | envoy-extproc-corruption | [Low] Envoy 1.35.10 detected. No workaround exists for chained ext_proc corruption below 1.37.1 -- tracked as OSSM-15498 | scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval) |
| WARN | nb:maas-ratelimit-demo | wb:rate-limit-testing-image | Image s2i-generic-data-science-notebook:3.4 is a 3.4 tag on RHOAI 3.5 | lib/functions/workbench.sh:40 default; create_workbench never updates an existing Notebook |
| WARN | nb:financial-loan-demo | wb:model-training-image | Image pytorch:3.4 is a 3.4 tag on RHOAI 3.5 | lib/functions/workbench.sh:40 default; create_workbench never updates an existing Notebook |
| WARN | nb:pipeline-demo | wb:ai-pipelines-image | Image s2i-generic-data-science-notebook:3.4 is a 3.4 tag on RHOAI 3.5 | lib/functions/workbench.sh:40 default; create_workbench never updates an existing Notebook |
| WARN | nb:lmeval-demo | wb:model-benchmarking-image | Image s2i-generic-data-science-notebook:3.4 is a 3.4 tag on RHOAI 3.5 | lib/functions/workbench.sh:40 default; create_workbench never updates an existing Notebook |
| INFO | infra | ocp-mcp-lco | OpenShift 4.21 < 4.22: MCP Lifecycle Operator (TP) requires 4.22+ |  |
| INFO | infra | olmv1-catalog | OCP 4.21+: OLMv1 catalog is on by default (TP); web-console installs of NFD/GPU may redirect to ClusterExtensions. CLI Subscriptions (toolkit default) are unaffected |  |
| INFO | platform | rhoai-version | RHOAI 3.5.1 on OpenShift 4.21.31 |  |
| INFO | dsc | kueue | Unmanaged |  |
| INFO | dsc | mcplifecycleoperator | Removed |  |
| INFO | dsc | trainer | Removed |  |
| INFO | dsc | trainingoperator | Removed |  |
| INFO | serving | llmisvc:llm/simulator | Stopped on purpose (serving.kserve.io/stop=true) | Start it in the dashboard or remove the annotation (user approval) before demos that need it |
| INFO | maas | governance | 2 LLMInferenceService(s) without MaaS labels | scripts/check-maas-security.sh |
| INFO | nb:maas-ratelimit-demo | maas-ratelimit-test-exec | Runnable headless: add --execute to run it |  |
| INFO | nb:maas-ratelimit-demo | maas-traffic-generator-exec | class=long: run with --execute --force |  |
| INFO | nb:financial-loan-demo | predictive-model-development-exec | class=needs-data (Kaggle dataset at s3://datasets/microloan-dataset/application_train.csv): run with --execute --force |  |
| INFO | nb:financial-loan-demo | llm-model-fine-tuning-import-transformers | transformers not in image (notebook pip-installs it: needs internet egress) |  |
| INFO | nb:financial-loan-demo | llm-model-fine-tuning-import-peft | peft not in image (notebook pip-installs it: needs internet egress) |  |
| INFO | nb:financial-loan-demo | llm-model-fine-tuning-import-trl | trl not in image (notebook pip-installs it: needs internet egress) |  |
| INFO | nb:financial-loan-demo | llm-model-fine-tuning-exec | class=gpu: not auto-run (GPU + Hugging Face downloads, long) |  |
| INFO | nb:pipeline-demo | 01-data-prep-exec | Runnable headless: add --execute to run it |  |
| INFO | nb:pipeline-demo | 02-train-exec | Runnable headless: add --execute to run it |  |
| INFO | nb:pipeline-demo | 03-evaluate-exec | Runnable headless: add --execute to run it |  |
| INFO | nb:pipeline-demo | 04-register-exec | Runnable headless: add --execute to run it |  |
| INFO | nb:lmeval-demo | english-benchmark-exec | class=long: run with --execute --force |  |
| INFO | nb:lmeval-demo | guidellm-benchmark-exec | class=long: run with --execute --force |  |
| INFO | nb:lmeval-demo | korean-mcq-benchmark-exec | class=long: run with --execute --force |  |
| INFO | nb:lmeval-demo | evalhub-sdk-demo-exec | class=long: run with --execute --force |  |
| SKIP | operators | jobset-operator | JobSet (Trainer v2) not installed (optional) |  |
| SKIP | maas-diag | mcp-lifecycle-oom | [-] MCP Lifecycle Operator not found (mcplifecycleoperator may be Removed) | scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval) |
| SKIP | maas-diag | external-model-migration | [-] No externalmodel.maas.opendatahub.io resources found | scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval) |
| SKIP | demo:university-safeguard-demo | deployed | not deployed (namespace acme-university-demo missing) |  |
| SKIP | demo:lemonade-trustyai-demo | deployed | not deployed (namespace lemonade-trustyai-demo missing) |  |
| SKIP | demo:lightspeed-demo | deployed | not deployed (olsconfig/cluster missing) |  |
| SKIP | demo:nim-demo | deployed | not deployed (namespace nim-demo missing) |  |
| SKIP | demo:marketing-assistant-demo | deployed | not deployed (namespace marketing-assistant missing) |  |
| SKIP | demo:agentic-platform-demo | deployed | not deployed (namespace team1 missing) |  |
| SKIP | demo:feast-demo | deployed | not deployed (namespace feast-demo missing) |  |
| SKIP | demo:llamastack-demo | deployed | not deployed (namespace demo-test missing) |  |
| SKIP | nb:feast-demo | feast-online-retrieval | demo not deployed |  |
| SKIP | nb:feast-demo | feast-banking-complex | demo not deployed |  |
| PASS | infra | tool-oc | oc found |  |
| PASS | infra | tool-jq | jq found |  |
| PASS | infra | tool-curl | curl found |  |
| PASS | infra | tool-git | git found |  |
| PASS | infra | cluster-user | Logged in as admin |  |
| PASS | infra | cluster-admin | User has cluster-admin |  |
| PASS | infra | identity-provider | 2 identity provider(s) configured |  |
| PASS | infra | ocp-version | OpenShift 4.21.31 (RHOAI 3.5 SC: 4.19.9 to 4.22) |  |
| PASS | infra | clusterversion | ClusterVersion healthy |  |
| PASS | infra | clusteroperators | All ClusterOperators available |  |
| PASS | infra | pending-csrs | No pending CSRs |  |
| PASS | infra | nodes-ready | All nodes Ready |  |
| PASS | infra | capacity | 7 worker(s) with >= 8 CPU / 32 GiB |  |
| PASS | infra | gpu-allocatable | GPU allocatable: ip-10-0-1-242.us-east-2.compute.internal=1,ip-10-0-1-78.us-east-2.compute.internal=8,ip-10-0-16-29.us-east-2.compute.internal=1,ip-10-0-30-41.us-east-2.compute.internal=1,ip-10-0-61-79.us-east-2.compute.internal=1,ip-10-0-70-7.us-east-2.compute.internal=1,ip-10-0-73-91.us-east-2.compute.internal=1,ip-10-0-74-209.us-east-2.compute.internal=1,ip-10-0-9-222.us-east-2.compute.internal=1 |  |
| PASS | infra | gpu-taint | GPU nodes tainted nvidia.com/gpu (HardwareProfiles must tolerate it) |  |
| PASS | infra | default-storageclass | Default StorageClass: gp3-csi |  |
| PASS | infra | no-odh | Open Data Hub not installed |  |
| PASS | infra | user-workload-monitoring | User Workload Monitoring enabled |  |
| PASS | operators | rhods-operator | rhods-operator.3.5.1 (channel stable-3.5) Succeeded |  |
| PASS | operators | openshift-cert-manager-operator | cert-manager-operator.v1.20.1 (channel stable-v1) Succeeded |  |
| PASS | operators | servicemeshoperator3 | servicemeshoperator3.v3.4.2 (channel stable) Succeeded |  |
| PASS | operators | leader-worker-set | leader-worker-set.v1.0.1 (channel stable-v1.0) Succeeded |  |
| PASS | operators | rhcl-operator | rhcl-operator.v1.4.3 (channel stable) Succeeded |  |
| PASS | operators | nfd | nfd.4.21.0-202611041433 (channel stable) Succeeded |  |
| PASS | operators | gpu-operator-certified | gpu-operator-certified.v26.7.2 (channel stable) Succeeded |  |
| PASS | operators | kueue-operator | kueue-operator.v1.3.2 (channel stable-v1.3) Succeeded |  |
| PASS | operators | cluster-observability-operator | cluster-observability-operator.v1.5.5 (channel stable) Succeeded |  |
| PASS | platform | dsci | DSCInitialization Ready |  |
| PASS | dsc | aigateway | Managed, ready=True |  |
| PASS | dsc | aipipelines | Managed, ready=True |  |
| PASS | dsc | dashboard | Managed, ready=True |  |
| PASS | dsc | feastoperator | Managed, ready=True |  |
| PASS | dsc | kserve | Managed, ready=True |  |
| PASS | dsc | mlflowoperator | Managed, ready=True |  |
| PASS | dsc | modelregistry | Managed, ready=True |  |
| PASS | dsc | ogx | Managed, ready=True |  |
| PASS | dsc | ray | Managed, ready=True |  |
| PASS | dsc | trustyai | Managed, ready=True |  |
| PASS | dsc | workbenches | Managed, ready=True |  |
| PASS | pods | redhat-ods-operator | All pods Running and Ready |  |
| PASS | pods | redhat-ods-applications | All pods Running and Ready |  |
| PASS | pods | redhat-ods-monitoring | All pods Running and Ready |  |
| PASS | pods | redhat-ai-gateway-infra | All pods Running and Ready |  |
| PASS | dashboard | reachable | https://rh-ai.apps.ocp.sclg6.sandbox323.opentlc.com -> HTTP 302 |  |
| PASS | gateway | gateways | Gateways Programmed: openshift-ingress/data-science-gateway=True,openshift-ingress/maas-default-gateway=True,openshift-ingress/openshift-ai-inference=True |  |
| PASS | hwprofile | gpu-tolerations | 2 profile(s), 1 GPU profile(s) tolerate nvidia.com/gpu |  |
| PASS | storage | s3-backend | S3 backends: automl-demo/seaweedfs=1/1,autorag-demo/seaweedfs=1/1,financial-loan-demo/seaweedfs=1/1,lmeval-demo/minio-pipelines-definition=1/1,pipeline-demo/seaweedfs=1/1,redhat-ods-monitoring/minio-usage-logs=1/1 |  |
| PASS | serving | isvc:autorag-demo/bge-m3 | Ready (https://bge-m3-autorag-demo.apps.ocp.sclg6.sandbox323.opentlc.com) |  |
| PASS | serving | isvc:financial-loan-demo/microloan-sklearn | Ready (https://microloan-sklearn-financial-loan-demo.apps.ocp.sclg6.sandbox323.opentlc.com) |  |
| PASS | serving | isvc:llm/qwen3-8b-eval | Ready (http://qwen3-8b-eval-predictor.llm.svc.cluster.local) |  |
| PASS | serving | llmisvc:llm/qwen3-8b | Ready (https://maas.apps.ocp.sclg6.sandbox323.opentlc.com/llm/qwen3-8b) |  |
| PASS | maas | enabled | MaaS Managed in DSC |  |
| PASS | maas | AIGatewayReady | AIGatewayReady=True |  |
| PASS | maas | ModelsAsAServiceReady | ModelsAsAServiceReady=True |  |
| PASS | maas | crd-maassubscriptions | CRD present |  |
| PASS | maas | crd-maasauthpolicies | CRD present |  |
| PASS | maas | crd-maasmodelrefs | CRD present |  |
| PASS | maas | maas-api | maas-api 1/1 in redhat-ai-gateway-infra |  |
| PASS | maas | db-config | maas-db-config has DB_CONNECTION_URL |  |
| PASS | maas | tenant | Tenant Ready |  |
| PASS | maas | gateway | maas-default-gateway Programmed (maas.apps.ocp.sclg6.sandbox323.opentlc.com) |  |
| PASS | maas | kuadrant | Kuadrant Ready |  |
| PASS | maas | authorino-tls | Authorino listener TLS enabled |  |
| PASS | maas | endpoint-auth | https://maas.apps.ocp.sclg6.sandbox323.opentlc.com/v1/models -> 401 without key (auth enforced) |  |
| PASS | maas-diag | gateway-namespace-label | [-] Required namespaces are labeled maas.opendatahub.io/gateway-access=true | scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval) |
| PASS | maas-diag | gateway-hostname-discovery | [-] Gateway hostname=maas.apps.ocp.sclg6.sandbox323.opentlc.com, Programmed=True | scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval) |
| PASS | maas-diag | payload-processing-oom | [-] Memory limit is 1Gi (above the risky 256Mi default) | scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval) |
| PASS | maas-diag | rhcl-14x-oom | [-] RHCL rhcl-operator.v1.4.3 installed, gateway memory=2Gi (sufficient) | scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval) |
| PASS | maas-diag | wasm-auth-timeout | [-] AUTH_SERVICE_TIMEOUT=2s | scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval) |
| PASS | maas-diag | token-rate-limit-default | [-] 6 subscription(s), none using the problematic 1000/hr default | scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval) |
| PASS | maas-diag | duplicate-playground-endpoints | [-] No leftover LlamaStackDistribution found (or OGX not Managed) | scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval) |
| PASS | maas-diag | wasm-shim-stale-auth-cache | [-] No WASM auth-cache errors in recent gateway logs (health check: HTTP 503) | scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval) |
| PASS | demo:maas-ratelimit-demo | notebook:rate-limit-testing | workbench pod rate-limit-testing-0 Ready (deep checks: check-notebooks.sh) |  |
| PASS | demo:maas-ratelimit-demo | exists:configmap/notebook-env | configmap/notebook-env exists |  |
| PASS | demo:open-webui-demo | deploy:open-webui | 1 deployment(s) ready |  |
| PASS | demo:open-webui-demo | route:open-webui | https://open-webui-open-webui.apps.ocp.sclg6.sandbox323.opentlc.com -> 200 |  |
| PASS | demo:nemo-guardrails-demo | field:nemoguardrails/nemo-quickstart | nemoguardrails/nemo-quickstart .status.phase=Ready |  |
| PASS | demo:nemo-guardrails-demo | exists:secret/api-token-secret | secret/api-token-secret exists |  |
| PASS | demo:nemo-guardrails-demo | route:nemo-quickstart | https://nemo-quickstart-nemo-guardrails-demo.apps.ocp.sclg6.sandbox323.opentlc.com -> 401 |  |
| PASS | demo:lemonade-stand-demo | deploy:lemonade-stand | 1 deployment(s) ready |  |
| PASS | demo:lemonade-stand-demo | route:lemonade-stand/health | https://lemonade-stand-nemo-guardrails-demo.apps.ocp.sclg6.sandbox323.opentlc.com/health -> 200 |  |
| PASS | demo:financial-loan-demo | notebook:model-training | workbench pod model-training-0 Ready (deep checks: check-notebooks.sh) |  |
| PASS | demo:financial-loan-demo | exists:secret/aws-connection-minio | secret/aws-connection-minio exists |  |
| PASS | demo:financial-loan-demo | deploy:microloan-webapp | 1 deployment(s) ready |  |
| PASS | demo:financial-loan-demo | route:microloan-webapp | https://microloan-webapp-financial-loan-demo.apps.ocp.sclg6.sandbox323.opentlc.com -> 200 |  |
| PASS | demo:financial-loan-demo | exists:configmap/webapp-config | configmap/webapp-config exists |  |
| PASS | demo:financial-loan-demo | servedmodel:configmap/webapp-config | LLM_MODEL_NAME=RedHatAI/Qwen3-8B-FP8-dynamic is a served model id |  |
| PASS | demo:financial-loan-demo | isvc:microloan-sklearn | Ready: microloan-sklearn |  |
| PASS | demo:pipeline-demo | field:datasciencepipelinesapplications/pipelines-definition | datasciencepipelinesapplications/pipelines-definition .status.conditions[?(@.type=="Ready")].status=True |  |
| PASS | demo:pipeline-demo | notebook:ai-pipelines | workbench pod ai-pipelines-0 Ready (deep checks: check-notebooks.sh) |  |
| PASS | demo:lmeval-demo | notebook:model-benchmarking | workbench pod model-benchmarking-0 Ready (deep checks: check-notebooks.sh) |  |
| PASS | demo:lmeval-demo | field:evalhub/evalhub | evalhub/evalhub .status.phase=Ready |  |
| PASS | demo:lmeval-demo | exists:serviceaccount/lmeval-sa | serviceaccount/lmeval-sa exists |  |
| PASS | demo:lmeval-demo | isvc:qwen3-8b-eval | Ready: qwen3-8b-eval |  |
| PASS | demo:automl-demo | field:datasciencepipelinesapplications/pipelines-definition | datasciencepipelinesapplications/pipelines-definition .status.conditions[?(@.type=="Ready")].status=True |  |
| PASS | demo:automl-demo | exists:secret/aws-connection-automl-data | secret/aws-connection-automl-data exists |  |
| PASS | demo:automl-demo | exists:servingruntime/kserve-autogluonserver | servingruntime/kserve-autogluonserver exists |  |
| PASS | demo:autorag-demo | field:datasciencepipelinesapplications/pipelines-definition | datasciencepipelinesapplications/pipelines-definition .status.conditions[?(@.type=="Ready")].status=True |  |
| PASS | demo:autorag-demo | exists:secret/aws-connection-autorag-docs | secret/aws-connection-autorag-docs exists |  |
| PASS | demo:autorag-demo | deploy:milvus-standalone | 1 deployment(s) ready |  |
| PASS | demo:autorag-demo | deploy:llamastack-postgres | 1 deployment(s) ready |  |
| PASS | demo:autorag-demo | isvc:bge-m3 | Ready: bge-m3 |  |
| PASS | demo:autorag-demo | deploy:genai-pgvector | 1 deployment(s) ready |  |
| PASS | demo:autorag-demo | exists:configmap/llama-stack-config | configmap/llama-stack-config exists |  |
| PASS | demo:autorag-demo | deploy:autorag-ogx | 1 deployment(s) ready |  |
| PASS | demo:autorag-demo | exists:secret/autorag-ogx-connection | secret/autorag-ogx-connection exists |  |
| PASS | demo:mlflow-tracing-demo | deploy:orchestrator | 1 deployment(s) ready |  |
| PASS | demo:mlflow-tracing-demo | deploy:risk-assessor | 1 deployment(s) ready |  |
| PASS | demo:mlflow-tracing-demo | deploy:compliance-reviewer | 1 deployment(s) ready |  |
| PASS | demo:mlflow-tracing-demo | deploy:customer-analyst | 1 deployment(s) ready |  |
| PASS | demo:mlflow-tracing-demo | deploy:mongodb-mcp | 1 deployment(s) ready |  |
| PASS | demo:mlflow-tracing-demo | deploy:banking-dashboard | 1 deployment(s) ready |  |
| PASS | demo:mlflow-tracing-demo | route:banking-dashboard | https://banking-dashboard-mlflow-tracing-demo.apps.ocp.sclg6.sandbox323.opentlc.com -> 200 |  |
| PASS | demo:n8n-demo | deploy:n8n | 1 deployment(s) ready |  |
| PASS | demo:n8n-demo | route:n8n | https://n8n-n8n.apps.ocp.sclg6.sandbox323.opentlc.com -> 200 |  |
| PASS | nb:maas-ratelimit-demo | wb:rate-limit-testing | Workbench maas-ratelimit-demo/rate-limit-testing running and Ready |  |
| PASS | nb:maas-ratelimit-demo | wb:rate-limit-testing-repo | Toolkit cloned at c271d44 2026-11-11 (local checkout 61fa06c; pod tracks GitHub main, not local edits) |  |
| PASS | nb:maas-ratelimit-demo | wb:rate-limit-testing-env-drift | Pod env matches ConfigMap notebook-env (14 keys) |  |
| PASS | nb:maas-ratelimit-demo | maas-ratelimit-test-env | Required env vars present |  |
| PASS | nb:maas-ratelimit-demo | url:MAAS_ENDPOINT | MAAS_ENDPOINT reachable from pod (HTTP 404) |  |
| PASS | nb:maas-ratelimit-demo | maas-ratelimit-test-import-requests | import requests OK |  |
| PASS | nb:maas-ratelimit-demo | maas-traffic-generator-env | Required env vars present |  |
| PASS | nb:maas-ratelimit-demo | url:MAAS_BASE_URL | MAAS_BASE_URL reachable from pod (HTTP 404) |  |
| PASS | nb:maas-ratelimit-demo | maas-traffic-generator-import-requests | import requests OK |  |
| PASS | nb:financial-loan-demo | wb:model-training | Workbench financial-loan-demo/model-training running and Ready |  |
| PASS | nb:financial-loan-demo | wb:model-training-repo | Toolkit cloned at c271d44 2026-11-11 (local checkout 61fa06c; pod tracks GitHub main, not local edits) |  |
| PASS | nb:financial-loan-demo | wb:model-training-env-drift | Pod env matches ConfigMap notebook-env (21 keys) |  |
| PASS | nb:financial-loan-demo | predictive-model-development-env | Required env vars present |  |
| PASS | nb:financial-loan-demo | url:S3_ENDPOINT | S3_ENDPOINT reachable from pod (HTTP 403) |  |
| PASS | nb:financial-loan-demo | url:MODEL_REGISTRY_URL | MODEL_REGISTRY_URL reachable from pod (HTTP 404) |  |
| PASS | nb:financial-loan-demo | predictive-model-development-import-boto3 | import boto3 OK |  |
| PASS | nb:financial-loan-demo | predictive-model-development-import-pandas | import pandas OK |  |
| PASS | nb:financial-loan-demo | predictive-model-development-import-xgboost | import xgboost OK |  |
| PASS | nb:financial-loan-demo | predictive-model-development-import-shap | import shap OK |  |
| PASS | nb:financial-loan-demo | predictive-model-development-import-dotenv | import dotenv OK |  |
| PASS | nb:financial-loan-demo | llm-model-fine-tuning-env | Required env vars present |  |
| PASS | nb:pipeline-demo | wb:ai-pipelines | Workbench pipeline-demo/ai-pipelines running and Ready |  |
| PASS | nb:pipeline-demo | wb:ai-pipelines-repo | Toolkit cloned at d807203 2026-11-11 (local checkout 61fa06c; pod tracks GitHub main, not local edits) |  |
| PASS | nb:pipeline-demo | wb:ai-pipelines-env-drift | Pod env matches ConfigMap notebook-env (18 keys) |  |
| PASS | nb:pipeline-demo | 01-data-prep-env | Required env vars present |  |
| PASS | nb:pipeline-demo | url:S3_ENDPOINT | S3_ENDPOINT reachable from pod (HTTP 403) |  |
| PASS | nb:pipeline-demo | 01-data-prep-import-boto3 | import boto3 OK |  |
| PASS | nb:pipeline-demo | 01-data-prep-import-pandas | import pandas OK |  |
| PASS | nb:pipeline-demo | 02-train-env | Required env vars present |  |
| PASS | nb:pipeline-demo | 02-train-import-boto3 | import boto3 OK |  |
| PASS | nb:pipeline-demo | 02-train-import-pandas | import pandas OK |  |
| PASS | nb:pipeline-demo | 02-train-import-sklearn | import sklearn OK |  |
| PASS | nb:pipeline-demo | 03-evaluate-env | Required env vars present |  |
| PASS | nb:pipeline-demo | 03-evaluate-import-boto3 | import boto3 OK |  |
| PASS | nb:pipeline-demo | 03-evaluate-import-pandas | import pandas OK |  |
| PASS | nb:pipeline-demo | 03-evaluate-import-sklearn | import sklearn OK |  |
| PASS | nb:pipeline-demo | 04-register-env | Required env vars present |  |
| PASS | nb:pipeline-demo | 04-register-import-boto3 | import boto3 OK |  |
| PASS | nb:pipeline-demo | 04-register-import-requests | import requests OK |  |
| PASS | nb:lmeval-demo | wb:model-benchmarking | Workbench lmeval-demo/model-benchmarking running and Ready |  |
| PASS | nb:lmeval-demo | wb:model-benchmarking-repo | Toolkit cloned at 61fa06c 2026-11-11 (local checkout 61fa06c; pod tracks GitHub main, not local edits) |  |
| PASS | nb:lmeval-demo | wb:model-benchmarking-env-drift | Pod env matches ConfigMap notebook-env (17 keys) |  |
| PASS | nb:lmeval-demo | english-benchmark-env | Required env vars present |  |
| PASS | nb:lmeval-demo | url:EVALHUB_URL | EVALHUB_URL reachable from pod (HTTP 401) |  |
| PASS | nb:lmeval-demo | url:DIRECT_ROUTE_URL | DIRECT_ROUTE_URL reachable from pod (HTTP 404) |  |
| PASS | nb:lmeval-demo | english-benchmark-import-evalhub | import evalhub OK |  |
| PASS | nb:lmeval-demo | guidellm-benchmark-env | Required env vars present |  |
| PASS | nb:lmeval-demo | guidellm-benchmark-import-evalhub | import evalhub OK |  |
| PASS | nb:lmeval-demo | korean-mcq-benchmark-env | Required env vars present |  |
| PASS | nb:lmeval-demo | korean-mcq-benchmark-import-evalhub | import evalhub OK |  |
| PASS | nb:lmeval-demo | korean-mcq-benchmark-import-yaml | import yaml OK |  |
| PASS | nb:lmeval-demo | evalhub-sdk-demo-env | Required env vars present |  |
| PASS | nb:lmeval-demo | evalhub-sdk-demo-import-evalhub | import evalhub OK |  |
