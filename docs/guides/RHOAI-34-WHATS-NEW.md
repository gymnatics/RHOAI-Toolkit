# What's New in RHOAI 3.4

> Official documentation: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4

## GA Promotions (from Tech Preview in 3.3)

### Models-as-a-Service (MaaS) — Core Platform Now GA
The MaaS core platform is GA, but several sub-features remain Technology Preview:

**GA (fully supported):**
- Subscription-based model access with configurable token quotas and rate limiting
- Self-service API key generation and management (permanent + temporary keys)
- Priority-based subscription assignment
- Group-based access control (OpenShift groups, API key group snapshots)
- Configurable token quotas per model per subscription
- Authorization policy integration
- Support for distributed inference with llm-d

**Still Technology Preview within MaaS:**
- External OIDC authentication (enterprise identity provider integration)
- vLLM runtime support for MaaS (enable via `vLLMDeploymentOnMaaS` dashboard flag)
- Observability dashboard (usage tracking, showback reporting, CSV export)
- Routing to external model providers (OpenAI, Anthropic via `ExternalModel` CR)

### NeMo Guardrails — Now GA
- `/v1/guardrails/checks` endpoint for standalone policy queries
- Full OpenAI compatibility with `/v1/models/` endpoint
- New regex rails for regex-based guardrail logic
- Multi-replica support for scalability
- OpenTelemetry support out of the box
- Automatic redeployment on config changes (zero-downtime)

### MLServer ServingRuntime for KServe — Now GA
- Deploy scikit-learn, XGBoost, LightGBM, ONNX models natively
- Auto-configuration of environment variables for well-known file names

### MLflow Operator — Managed DSC Component
- `mlflowoperator` is now an official component in the DataScienceCluster CR
- The deprecated `mlflow` dashboard feature flag is no longer required
- Kubernetes namespaces as workspaces with RBAC authorization

## New Technology Preview Features

### AutoML
- Automated ML model training via Kubeflow Pipelines + AutoGluon
- Dashboard UI for configuring optimization runs
- Supports: Binary Classification, Multiclass Classification, Regression, Time Series
- Model leaderboard, trained model artifacts, generated Jupyter notebooks

### AutoRAG
- Automated RAG pipeline optimization
- Dashboard UI for configuration, evaluation, and notebook generation
- Finds optimal RAG configurations for documents and use cases

### vLLM Runtime for MaaS (also a MaaS sub-feature TP)
- Deploy models with vLLM through MaaS interface
- Enable via `vLLMDeploymentOnMaaS` flag in OdhDashboardConfig
- Same subscription governance as llm-d models

### External OIDC Authentication for MaaS (also a MaaS sub-feature TP)
- Integrate with external identity providers
- OIDC group mapping to subscriptions
- No OpenShift accounts required for every user

### MaaS Observability Dashboard (also a MaaS sub-feature TP)
- Subscription-level metrics (tokens, requests, errors)
- Token consumption tracking by user/subscription/model
- Configurable time ranges, filtering, CSV export
- Prometheus metrics integration

### External Model Egress (also a MaaS sub-feature TP)
- Route requests to external providers (OpenAI, Anthropic, etc.)
- `ExternalModel` custom resource for provider config
- Same governance policies apply as internal models

### Workload Variant Autoscaler (WVA) for llm-d
- Inference-aware autoscaling based on KV cache utilization and queue length
- Saturation-based spare capacity modeling

### Priority-based Flow Control for llm-d
- Priority tiers for workload classes
- Configurable queuing policies
- Latency-sensitive requests served ahead of batch traffic

### Gateway Discovery for llm-d
- Self-service Gateway selection in model serving UI
- Namespace-scoped network isolation
- Gateway discovery REST API

### EvalHub (Evaluation Stack)
- UI for model evaluations in the dashboard
- SDK and CLI (`eval-hub-sdk`) for programmatic evaluation
- Supports LM-Eval, RAGAS, Garak, GuideLLM frameworks
- Results tracked in MLflow

### Other Tech Preview Features
- **Text embedding models** in Model Catalog (Granite Embedding, Nomic, Qwen3, MiniLM)
- **Artifact signing** for model registry (cryptographic signing/verification)
- **YAML viewer** for llm-d deployments (real-time preview, manual edit mode)
- **Recommended vLLM configs** in model catalog (H200 optimized recipes)

## Enhancements

### llm-d
- **Prometheus metrics** for all components (EPP, vLLM engine, prefix cache)
- **Simplified scheduler config** via `endpointPickerConfig` field
- **vLLM args via `args` field** (standard Kubernetes container args)
- **Migration guide** from vLLM InferenceService to LLMInferenceService
- vLLM access logs disabled by default in LLMInferenceServiceConfig

### Model Registry
- **OCI-compliant storage** — register models, auto-convert to ModelCar OCI images
- **PostgreSQL backend** — configure from dashboard
- **Default database** for testing (not for production)

### Workbenches
- Images default to **Red Hat Python index** (not PyPI)
- MLFlow SDK pre-installed in workbench/runtime images

### Llama Stack (0.6.0)
- **Responses API** (Technology Preview) — OpenAI-compatible
- **Connectors** — high-level abstraction for MCP registries
- **Conversations API** — multi-turn context-aware chats
- **Garak evaluation provider** — LLM security scanning
- TLS and proxy configuration for all remote inference providers
- IBM Power and KubeRay support

### Kubeflow Trainer
- **JIT checkpointing** — automatic state save before interruptions
- **S3 storage** for checkpoints (background uploads, no training pause)

## MaaS Architecture Changes (3.3 → 3.4)

The MaaS setup has changed significantly between versions:

| Aspect | 3.3 | 3.4 |
|--------|-----|-----|
| Access model | Tier-based (ConfigMaps) | **Subscription-based** (CRDs) |
| TLS for Authorino | cert-manager Certificate | **OpenShift service-ca** annotation |
| Gateway annotations | None special | `opendatahub.io/managed: "false"` + `security.opendatahub.io/authorino-tls-bootstrap: "true"` |
| New CRDs | N/A | MaaSSubscription, MaaSAuthPolicy, MaaSModelRef, Tenant, ExternalModel |
| Tenant CR | N/A | Auto-created in `models-as-a-service` namespace |
| API key prefix | N/A | `sk-oai-` prefix |
| RHCL version | v1.1+ | **v1.2+** |
| Dashboard URL | `data-science-gateway.apps.<cluster>` | **`rh-ai.apps.<cluster>`** (old URL auto-redirects) |
| PostgreSQL | Not required | **PostgreSQL 14+** required. Secret: `maas-db-config` with key `DB_CONNECTION_URL` in `redhat-ods-applications` |
| Dashboard flags | `modelAsService` | + `maasAuthPolicies`, `observabilityDashboard` (TP), `vLLMDeploymentOnMaaS` (TP) |

### MaaS TLS Setup (3.4 method)
```bash
# 1. Annotate Authorino service for service-ca cert
oc annotate service authorino-authorino-authorization \
  -n kuadrant-system \
  service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert --overwrite

# 2. Patch Authorino CR for TLS listener
oc patch authorino authorino -n kuadrant-system --type=merge --patch '{
  "spec": { "listener": { "tls": { "enabled": true, "certSecretRef": { "name": "authorino-server-cert" } } } }
}'

# 3. Set TLS cert env vars on Authorino deployment
oc -n kuadrant-system set env deployment/authorino \
  SSL_CERT_FILE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt \
  REQUESTS_CA_BUNDLE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt

# 4. Annotate gateway for TLS bootstrap
oc annotate gateway maas-default-gateway -n openshift-ingress \
  security.opendatahub.io/authorino-tls-bootstrap="true" --overwrite
```

### MaaS PostgreSQL Requirement (3.4)
MaaS requires PostgreSQL 14+ for API key storage and validation. The secret format is:
```bash
# The secret key MUST be DB_CONNECTION_URL (a single connection string)
oc create secret generic maas-db-config \
  -n redhat-ods-applications \
  --from-literal=DB_CONNECTION_URL='postgresql://username:password@hostname:5432/database?sslmode=require'
```

The install script (`install-rhoai-34.sh`) handles this:
- **Default**: Deploys a POC PostgreSQL with 5Gi PVC (not production-grade)
- **`--postgres-connection <url>`**: Uses your external PostgreSQL
- **`--skip-maas-db`**: Skips DB setup (you manage it yourself)

For production, use AWS RDS, Crunchy Postgres Operator, or Azure Database for PostgreSQL.
The `maas-db-config` secret must exist before `modelsAsService` becomes Managed, or restart `maas-api` after creating it:
```bash
oc rollout restart deployment/maas-api -n redhat-ods-applications
```

Reference: https://opendatahub-io.github.io/models-as-a-service/latest/install/maas-setup/#database-setup

## DSC Changes from 3.3

The DataScienceCluster CR for 3.4 uses API version `datasciencecluster.opendatahub.io/v2`. Key changes:
- `mlflowoperator.managementState: Managed` is now officially documented as a managed component
- `kserve.modelsAsService.managementState: Managed` enables MaaS (core GA)
- No new DSC component fields for AutoML/AutoRAG (they use AI Pipelines)

## Dashboard Config Changes

```yaml
spec:
  dashboardConfig:
    disableModelRegistry: false
    disableModelCatalog: false
    disableKServeMetrics: false
    genAiStudio: true              # MaaS user-facing features
    modelAsService: true           # Core MaaS functionality
    maasAuthPolicies: true         # MaaS admin features (subscriptions, auth policies)
    disableLMEval: false
    # Technology Preview flags (optional):
    # vLLMDeploymentOnMaaS: true   # Enable vLLM runtime for MaaS
    # observabilityDashboard: true # Enable MaaS usage monitoring dashboard
```

The `mlflow` dashboard flag is **deprecated** — MLflow availability is now determined by the `mlflowoperator` DSC component state.

## Installation

Use the toolkit:
```bash
# Interactive
./rhoai-toolkit.sh   # Select option 3 for RHOAI 3.4

# Direct
./scripts/install-rhoai-34.sh

# With specific channel
./scripts/install-rhoai-34.sh --channel stable-3.4

# With vLLM on MaaS (TP)
./scripts/install-rhoai-34.sh --enable-vllm-maas

# Makefile
make setup-rhoai-34
```
