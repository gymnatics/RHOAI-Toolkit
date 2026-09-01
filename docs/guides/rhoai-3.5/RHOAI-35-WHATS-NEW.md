# What's New in RHOAI 3.5 — Deployment-Relevant Changes

This document covers every change between RHOAI 3.4 and 3.5 that affects installation,
deployment, or day-2 operations. It is organized by severity — read the HIGH items first
if you are upgrading an existing 3.4 deployment or writing automation.

> **Automated install:** `scripts/install-rhoai-35.sh` handles all of these changes.
> **Manual install:** See [RHOAI-35-MANUAL-INSTALLATION-GUIDE.md](RHOAI-35-MANUAL-INSTALLATION-GUIDE.md).
> **Reference docs:** `docs/reference/RHAIE 3.5 Guide/`

---

## Table of Contents

- [HIGH: MaaS Moved to aigateway DSC Component](#high-maas-moved-to-aigateway-dsc-component)
- [HIGH: Infrastructure Namespace Change](#high-infrastructure-namespace-change)
- [HIGH: OGX Replaces Llama Stack Operator](#high-ogx-replaces-llama-stack-operator)
- [HIGH: New DSC Readiness Conditions](#high-new-dsc-readiness-conditions)
- [HIGH: RHCL 1.4.1+ Required](#high-rhcl-141-required)
- [HIGH: Auto-Created Gateway Policies](#high-auto-created-gateway-policies)
- [HIGH: llm-d Flow Control Breaking Changes](#high-llm-d-flow-control-breaking-changes)
- [MEDIUM: New DSC Components](#medium-new-dsc-components)
- [MEDIUM: OCP Support Range](#medium-ocp-support-range)
- [MEDIUM: Operator Version Requirements](#medium-operator-version-requirements)
- [MEDIUM: Dashboard Feature Flags](#medium-dashboard-feature-flags)
- [MEDIUM: Metrics Prefix Change](#medium-metrics-prefix-change)
- [MEDIUM: EPP Scheduler Defaults](#medium-epp-scheduler-defaults)
- [MEDIUM: WVA ConfigMap Rename](#medium-wva-configmap-rename)
- [LOW: New Features (GA)](#low-new-features-ga)
- [LOW: New Technology Preview Features](#low-new-technology-preview-features)
- [LOW: Deprecated Features](#low-deprecated-features)
- [LOW: Removed Features](#low-removed-features)

---

## HIGH: MaaS Moved to aigateway DSC Component

**Impact:** Using the old field produces a deprecation warning and will stop working after 3.6.

> **Verified on live RHOAI 3.5.0 cluster.** Applying a DSC with `kserve.modelsAsService`
> produces: *"Warning: spec.components.kserve.modelsAsService is deprecated; use
> spec.components.aigateway.modelsAsAService instead."*

In RHOAI 3.4, MaaS was configured under `kserve`:

```yaml
# 3.4 (DEPRECATED in 3.5)
spec:
  components:
    kserve:
      modelsAsService:
        managementState: Managed
```

In RHOAI 3.5, MaaS has moved to a new top-level `aigateway` component:

```yaml
# 3.5 (CORRECT)
spec:
  components:
    aigateway:
      managementState: Managed
      modelsAsAService:          # Note: "AsA" not "As"
        managementState: Managed
```

**Key details:**
- The field name is `modelsAsAService` (with an extra "A") — this matches the
  `ai-gateway-operator` CRD field name
- The deprecated `kserve.modelsAsService` field is still respected through 3.6 but
  re-enabling it after clearing to Removed is blocked
- The `aigateway` component also has a `batchGateway` sub-component (defaults to Removed)
- New deployments created: `ai-gateway-operator` and `maas-ui` in `redhat-ods-applications`

### Dashboard Flag Change

The `maasAuthPolicies` dashboard flag has a **CEL validation rule** in 3.5 that blocks
setting it. Attempting to include it in a patch will fail:

```
The OdhDashboardConfig "odh-dashboard-config" is invalid:
spec.dashboardConfig: Invalid value: "object": no such key: maasAuthPolicies
evaluating rule: DEPRECATED: spec.dashboardConfig.maasAuthPolicies must be removed
or left unchanged.
```

This flag's functionality is baked into MaaS GA — no dashboard flag is needed. Remove
`maasAuthPolicies` from any automation or patch scripts.

---

## HIGH: Infrastructure Namespace Change

**Impact:** MaaS will not start if the `maas-db-config` secret is created in the wrong namespace.

In RHOAI 3.4, MaaS workloads (`maas-api`, PostgreSQL, `maas-db-config` secret) lived in
`redhat-ods-applications`. In RHOAI 3.5, they move to a dedicated **infrastructure namespace**:

| Resource | 3.4 Namespace | 3.5 Namespace |
|----------|---------------|---------------|
| `maas-db-config` secret | `redhat-ods-applications` | `redhat-ai-gateway-infra` |
| `maas-api` deployment | `redhat-ods-applications` | `redhat-ai-gateway-infra` |
| POC PostgreSQL | `redhat-ods-applications` | `redhat-ai-gateway-infra` |
| `maas-controller` deployment | `redhat-ods-applications` | `redhat-ods-applications` (unchanged) |
| `ai-gateway-operator` deployment | N/A (new) | `redhat-ods-applications` |
| `maas-ui` deployment | N/A (new) | `redhat-ods-applications` |

> **Verified on live cluster (RHOAI 3.5.0):** Only `maas-api` and the PostgreSQL/DB
> secret move to the infrastructure namespace. The `maas-controller`, `ai-gateway-operator`,
> and `maas-ui` remain in `redhat-ods-applications` alongside the RHOAI operator components.

To discover the actual infrastructure namespace for your deployment:

```bash
oc get maastenantconfig default-tenant -n models-as-a-service \
  -o jsonpath='{.status.infraNamespace}'
# Expected: redhat-ai-gateway-infra
```

After creating or updating `maas-db-config`, restart `maas-api` in the infra namespace:

```bash
oc rollout restart deployment/maas-api -n redhat-ai-gateway-infra
```

---

## HIGH: OGX Replaces Llama Stack Operator

The Llama Stack Operator has been renamed to the **OGX Operator**. This affects the DSC
component field name and the CRD API group.

| Aspect | 3.4 | 3.5 |
|--------|-----|-----|
| DSC field | `llamastackoperator` | `ogx` |
| CRD API group | `llamastack.io/v1alpha1` | `ogx.io/v1alpha1` (to confirm) |
| Custom resource | `LlamaStackDistribution` | `OGXServer` |
| Container image | `odh-llama-stack-core-rhel9` | OGX equivalent |
| Readiness check | N/A | `oc wait --for=jsonpath='{.status.phase}'=Ready ogxserver/<name>` |

A DSC that sets `spec.components.llamastackoperator` will fail validation on RHOAI 3.5.

OGX component requirements (install these before setting `ogx: Managed`):
- Red Hat OpenShift Service Mesh Operator 3.x
- cert-manager Operator
- GPU-enabled nodes with NFD + NVIDIA GPU Operator
- S3-compatible object storage

---

## HIGH: New DSC Readiness Conditions

RHOAI 3.5 adds new status conditions on the `DataScienceCluster` object that must be
checked during installation.

> **Live cluster verified (RHOAI 3.5.0):** The condition names below are confirmed from
> a production RHOAI 3.5.0 deployment. Some reference scripts from upstream/community
> repos may use different names (e.g. `ModelControllerReady`) — those do NOT exist on
> the GA release.

### AIGatewayReady

Indicates the AI Gateway operator and MaaS controller are deployed and healthy. Must be
True before MaaS subscriptions and API keys work.

```bash
oc wait --for=jsonpath='{.status.conditions[?(@.type=="AIGatewayReady")].status}'=True \
  datasciencecluster/default-dsc --timeout=300s
```

### ModelsAsAServiceReady

**Note the spelling: "AsA" (not "As").** Indicates the full MaaS platform is operational.
Stays `False` until all three prerequisites are met:
1. `maas-default-gateway` exists and is Programmed
2. `maas-db-config` secret exists in the infrastructure namespace
3. Authorino TLS is configured

The condition **message** tells you exactly what is missing:

```bash
oc get datasciencecluster default-dsc \
  -o jsonpath='{.status.conditions[?(@.type=="ModelsAsAServiceReady")].message}'
```

### Full Condition List (RHOAI 3.5.0)

Verified on live cluster:

| Condition | What it tracks |
|-----------|---------------|
| `Ready` | Overall DSC readiness |
| `AIGatewayReady` | AI Gateway operator + MaaS controller |
| `ModelsAsAServiceReady` | Full MaaS platform (gateway + DB + TLS) |
| `DashboardReady` | Dashboard |
| `KserveReady` | KServe controller + webhook |
| `KueueReady` | Kueue |
| `AIPipelinesReady` | AI Pipelines |
| `RayReady` | KubeRay |
| `OGXReady` | OGX Operator |
| `MCPLifecycleOperatorReady` | MCP Lifecycle Operator |
| `MLflowOperatorReady` | MLflow Operator |
| `ModelRegistryReady` | Model Registry |
| `TrustyAIReady` | TrustyAI / EvalHub |
| `FeastOperatorReady` | Feast Feature Store |
| `WorkbenchesReady` | Workbenches |
| `KserveLLMInferenceServiceDependencies` | llm-d dependency check |
| `KserveLLMInferenceServiceWideEPDependencies` | llm-d WideEP dependency check |
| `BatchGatewayReady` | Batch Gateway (Removed unless enabled) |
| `SparkOperatorReady` | Spark Operator (Removed unless enabled) |
| `TrainerReady` | Trainer (Removed unless enabled) |
| `TrainingOperatorReady` | Training Operator (Removed unless enabled) |

---

## HIGH: RHCL 1.4.1+ Required

**RHCL 1.4.0 is deprecated.** Clusters running 1.4.0 may experience:
- Authentication failures
- API key management errors
- Gateway instability
- Gateway pod memory pressure (WASM plugin loading issues)

Always use RHCL **1.4.1 or later**. The `stable` OLM channel now serves 1.4.1+.

| Aspect | 3.4 (RHCL 1.2+) | 3.5 (RHCL 1.4.1+) |
|--------|-----------------|-------------------|
| Install plan approval | Manual (pinned to avoid 1.4.0) | Automatic (1.4.0 bug fixed) |
| Service Mesh required | 3.2+ | **3.4** |
| cert-manager required | 1.18+ | **1.19 or 1.20** |
| OCP support | 4.17+ | **4.19–4.22** |
| Multi-tenancy | N/A | Requires Kuadrant **v1.4.2+** |

### Improved Wait Patterns (RHCL 1.4)

RHCL 1.4 docs recommend these `oc wait` patterns instead of polling:

```bash
# Wait for InstallPlan
oc wait --for=jsonpath={.status.installPlanRef.name} \
  subscription rhcl-operator --timeout=10s
ip=$(oc get subscription rhcl-operator -o=jsonpath={.status.installPlanRef.name})
oc wait --for=condition=Installed installplan ${ip} --timeout=60s

# Wait for Kuadrant
oc wait --for=condition=Ready kuadrant/kuadrant -n kuadrant-system --timeout=120s

# Wait for GatewayClass
oc wait --for=condition=Accepted gatewayclass/openshift-default --timeout=120s

# Wait for Gateway
oc wait --for=condition=Programmed gateway/maas-default-gateway \
  -n openshift-ingress --timeout=120s

# Wait for Authorino after TLS config
oc wait --for=condition=Available deployment/authorino \
  -n kuadrant-system --timeout=300s
```

---

## HIGH: Auto-Created Gateway Policies

In RHOAI 3.5, the `maas-controller` (deployed via the DSC `aigateway.modelsAsAService: Managed`
component) automatically creates several gateway-level resources:

| Resource | Kind | Namespace | Purpose |
|----------|------|-----------|---------|
| `maas-gateway-auth` | AuthPolicy | `openshift-ingress` | Denies unauthenticated traffic |
| `openshift-ai-inference-authn` | AuthPolicy | `openshift-ingress` | Inference gateway auth |
| `gateway-default-deny` | TokenRateLimitPolicy | `openshift-ingress` | Denies unsubscribed traffic |

> **Live cluster verified:** The AuthPolicy names are `maas-gateway-auth` and
> `openshift-ai-inference-authn` (not `gateway-default-auth` as some upstream docs suggest).

**Impact:** Manual Redis/Limitador/EnvoyFilter rate-limit configuration from 3.4 scripts
may **conflict** with these auto-created policies. Review and simplify the rate-limiting
setup for 3.5.

Verify auto-created policies:

```bash
oc get authpolicy -n openshift-ingress
oc get tokenratelimitpolicy -n openshift-ingress
```

### New CRDs

| CRD | Purpose |
|-----|---------|
| `aitenants.maas.opendatahub.io` | Multi-tenancy (TP) — bootstraps isolated tenants |
| `maastenantconfigs.maas.opendatahub.io` | Default tenant config — auto-created by `maas-controller` |
| `tokenratelimitpolicies.kuadrant.io` | Replaces `RateLimitPolicy` for token-based limits |

> **Live cluster verified:** The `maas-controller` creates a `MaasTenantConfig/default-tenant`
> in `models-as-a-service` (not a `Tenant` CR as in 3.4). Check its status:
> ```bash
> oc get maastenantconfig default-tenant -n models-as-a-service
> # Expected: READY=True, REASON=Reconciled
> ```

### MaasTenantConfig Ordering Dependency

The admission webhook requires a `MaasTenantConfig` CR to exist before
`MaaSSubscription` or `MaaSAuthPolicy` resources can be created. The controller
auto-creates this, but if you create subscriptions/policies before the controller
has finished bootstrapping, they will be rejected.

---

## HIGH: llm-d Flow Control Breaking Changes

If you configured flow control during the 3.4 Technology Preview, you must update:

| Aspect | 3.4 (TP) | 3.5 (GA) |
|--------|----------|----------|
| API group | `inference.networking.x-k8s.io` | `llm-d.ai` |
| Metrics prefix | `inference_extension_` | `llm_d_epp_` |
| Saturation detector | Top-level `saturationDetector` | `flowControl.saturationDetector` |
| InferenceObjective API | `inference.networking.x-k8s.io/v1alpha1` | `llm-d.ai/v1alpha2` |

Update all `InferenceObjective` and `EndpointPickerConfig` resources to use the new
API group and field locations.

---

## MEDIUM: New DSC Components

### `mcplifecycleoperator` (Technology Preview)

The MCP Lifecycle Operator is now a first-class DSC component. In 3.4 it required
manual installation from a GitHub URL. In 3.5, setting `mcplifecycleoperator: Managed`
in the DSC makes the RHOAI operator deploy and manage it automatically.

### `mlflowoperator`

Already existed in 3.4 but is now more prominently listed in the official DSC examples.
Setting `mlflowoperator: Managed` deploys the MLflow Operator for experiment tracking.

### `ogx`

Replaces `llamastackoperator`. See [OGX section above](#high-ogx-replaces-llama-stack-operator).

---

## MEDIUM: OCP Support Range

| RHOAI Version | Supported OCP |
|---------------|---------------|
| 3.4 | 4.19, 4.20, 4.21 |
| 3.5 | 4.19, 4.20, 4.21, **4.22** |

llm-d (Distributed Inference) still requires OCP 4.20 or later.

---

## MEDIUM: Operator Version Requirements

| Operator | 3.4 Requirement | 3.5 Requirement |
|----------|----------------|----------------|
| RHCL | v1.2+ | **v1.4.1+** |
| Service Mesh (Sail) | 3.2+ | **3.4** |
| cert-manager | 1.18+ | **1.19 or 1.20** |
| KubeRay | 1.4.2 | **1.6.x** |

---

## MEDIUM: Dashboard Feature Flags

New or changed flags in `OdhDashboardConfig`:

| Flag | 3.4 | 3.5 |
|------|-----|-----|
| `roleManagement` | Not present | **Enabled by default** — custom RBAC role creation UI |
| `maasAuthPolicies` | Required for MaaS admin | **REMOVED** — CEL validation rejects setting it; baked into MaaS GA |
| `mcpCatalog` | Developer Preview | Technology Preview |
| `llmdTemplates` | N/A | New TP — topology selector wizard for LLMInferenceService |
| `externalModels` | N/A | New TP — external model endpoint configuration |

Flags that remain valid and unchanged: `modelAsService`, `genAiStudio`,
`vLLMDeploymentOnMaaS`, `observabilityDashboard`.

> **Live cluster verified:** Attempting to set `maasAuthPolicies` in a patch will fail
> with a CEL validation error. Remove it from all automation scripts.

---

## MEDIUM: Metrics Prefix Change

Distributed Inference with llm-d metrics now use the `llm_d_epp_` prefix. The old
`inference_extension_`, `inference_objective_`, and `inference_pool_` prefixes are
deprecated but remain available for backward compatibility.

Key new metric names:
- `llm_d_epp_request_total`
- `llm_d_epp_request_duration_seconds`
- `llm_d_epp_request_ttft_seconds`
- `llm_d_epp_scheduler_e2e_duration_seconds`
- `llm_d_epp_average_kv_cache_utilization`
- `llm_d_epp_flow_control_queue_size`

**Action:** Update any Prometheus dashboards, alerts, or Grafana panels that reference
the old metric names.

---

## MEDIUM: EPP Scheduler Defaults

The default EndPoint Picker (EPP) scheduler configuration changed:

| Version | Scorers | Weights |
|---------|---------|---------|
| 3.4 | `queue-scorer`, `prefix-cache-scorer` | 2:3 |
| 3.5 | `queue-scorer`, `kv-cache-utilization-scorer`, `prefix-cache-scorer`, `no-hit-lru-scorer` | 2:2:3:2 |

Services **without** custom scheduler config automatically adopt the 3.5 defaults.
Services **with** custom config are preserved.

---

## MEDIUM: WVA ConfigMap Rename

After upgrading from 3.4 to 3.5, the Workload Variant Autoscaler ConfigMap is renamed:

| 3.4 Name | 3.5 Name |
|----------|----------|
| `workload-variant-autoscaler-wva-variantautoscaling-config` | `workload-variant-autoscaler-manager-config` |

**Your customized values are NOT preserved.** Back up before upgrading:

```bash
oc get configmap workload-variant-autoscaler-wva-variantautoscaling-config \
  -n redhat-ods-applications -o yaml > wva-config-backup.yaml

oc get configmap workload-variant-autoscaler-saturation-scaling-config \
  -n redhat-ods-applications -o yaml > wva-saturation-backup.yaml
```

After upgrade, reapply your values to the new ConfigMap name.

---

## LOW: New Features (GA)

- **External OIDC authentication for MaaS** — enterprise IdP integration without requiring
  OpenShift accounts for every user
- **EvalHub** — unified evaluation platform (replaces standalone LM-Eval)
- **Flow control for llm-d** — priority tiers, saturation detection, queuing policies
- **Controlled (canary) deployment for llm-d** — weight-based traffic splitting
- **Responses API on OGX** — OpenAI-compatible API
- **Automated Red Teaming** — vulnerability scanning via Garak
- **GPU-accelerated MLServer** — `mlserver-onnx-gpu` serving runtime
- **DiffusionGemma (dLLM) model support** — first discrete diffusion LLM on KServe
- **Inference-aware pod lifecycle for llm-d** — graceful scaling without dropping requests
- **MaaS body-based model routing** — OpenAI-compatible `/v1/chat/completions` with model in body

---

## LOW: New Technology Preview Features

- MCP gateway Operator (external prerequisite for MCP management workflows)
- Unified dashboard for generative AI model deployment
- DP-aware load balancing for WideEP deployments
- MaaS multi-tenancy with per-tenant gateway and identity isolation
- AutoGluon serving runtime
- Multi-provider API passthrough for external models
- Autoscaling for llm-d based on request volume
- Gateway discovery in model serving UI
- vLLM on MaaS
- MaaS observability dashboard
- External model egress

---

## LOW: Deprecated Features

| Feature | Status | Replacement |
|---------|--------|-------------|
| FMS Guardrails Orchestrator | Deprecated | NeMo Guardrails |
| LM-Eval (LMEvalJob CRD) | Deprecated | EvalHub |
| Kubeflow Training Operator v1 | Deprecated | Kubeflow Trainer v2 |
| Accelerator Profiles / Container Size selector | Deprecated (since 3.0) | Hardware Profiles |
| CUDA plugin for OpenVINO Model Server | Deprecated | N/A |
| `opendatahub.io/connection-type-ref` annotation | Deprecated (since 3.0) | `opendatahub.io/connection-type-protocol` |

---

## LOW: Removed Features

| Feature | Notes |
|---------|-------|
| RStudio Server workbench images | Licensing compliance. Running workbenches still work but no new creation. |
| CUDA - RStudio Server workbench images | Same as above |
| Kubeflow Training Operator v1 training images | `odh-training-cuda121-torch24-py311-rhel9` and `odh-training-cuda124-torch25-py311-rhel9` removed |
| `FIPSEnabled` DSPO field | FIPS mode is always enabled via Go native FIPS module |
| `tf2onnx` package | Removed from TensorFlow images (incompatible with Keras 3) |
| Caikit-NLP component | Formally removed |
| TGIS component | Formally removed |

---

## Quick Reference: Version Comparison

```
                          RHOAI 3.4              RHOAI 3.5
                          ─────────              ─────────
OCP Support              4.19–4.21              4.19–4.22
RHCL Version             1.2+ (Manual pin)      1.4.1+ (Automatic)
Service Mesh             3.2+                   3.4
cert-manager             1.18+                  1.19/1.20
KubeRay                  1.4.2                  1.6.x
MaaS DSC field           kserve.modelsAsService aigateway.modelsAsAService
MaaS Infra NS            redhat-ods-applications redhat-ai-gateway-infra
DSC GenAI field          llamastackoperator     ogx
MCP Lifecycle            Manual GitHub install  DSC component (mcplifecycleoperator)
MaaS External OIDC       TP                     GA
EvalHub                  TP                     GA
llm-d Flow Control       TP                     GA (breaking API change)
llm-d Metrics Prefix     inference_extension_   llm_d_epp_
Gateway Policies         Manual                 Auto-created by maas-controller
Rate Limit CRD           RateLimitPolicy        TokenRateLimitPolicy
maasAuthPolicies flag    Required               REMOVED (CEL rejects)
DSC Condition (MaaS)     N/A                    AIGatewayReady + ModelsAsAServiceReady
Tenant CRD               Tenant                 MaasTenantConfig
Auth Policy Name         N/A                    maas-gateway-auth
```
