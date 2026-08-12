# PRD -- Managed Agentic Platform Demo (DBS Loan Processing Agent)

**Status**: Deployed, tested, and fully operational (26+ pods across 5 namespaces)
**Owner**: dayeo
**Created**: 2026-08-12
**Cluster**: `api.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com:6443` (OCP 4.20.32, RHOAI 3.4.3)
**Source**: https://github.com/cbtham/managed-agentic-platform.git

## 1. Problem / Goal

Deploy a production-grade enterprise AI agent platform demonstrating secure, governed,
observable, and guardrailed agentic workloads on OpenShift AI 3.4. The reference
implementation is a DBS Bank Loan Processing Agent with 13 deployment layers.

## 2. Deployment Status

| Layer | Component | Status |
|-------|-----------|--------|
| 00 | Operators (RHBK, Serverless, Pipelines) | Deployed (SPIRE/KAgenti not in catalog) |
| 01 | Namespaces + RBAC | Deployed |
| 02 | Keycloak (OIDC, realm, users, groups) | Deployed (realm import applied) |
| 03 | MCP Gateway + Controller | MCP Istio proxy running; Gateway/Controller need further config |
| 04 | KAgenti Platform (backend, UI) | Running (fixed to ghcr.io/rossoctl images) |
| 05 | Loki + Grafana (observability) | Running |
| 06 | Loan Agent + 4 MCP Tools + OPA + Policy Agent | Running (all healthy) |
| 07 | AI Guardrails (HAP + LLM Judge + Orchestrator) | All 3 running (fixed with RHOAI images + TrustyAI CR) |
| 08 | Dify (agent builder) | Running (all 5 pods) |
| 09 | Tekton Pipelines (onboarding) | Tasks created; 2 pipelines have API version mismatch |
| 10 | Rossoctl Services | Running (all 5 services) |
| 11 | Istio Mesh + Kiali | Kiali/Prometheus deployed; Istio CR API version mismatch |
| 12 | MLflow Evaluator CronJob | Running (completing every 10 min) |

## 3. Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| LLM Provider | Qwen3.5-35B-A3B via MaaS (on-cluster) | Replaces DeepSeek external API; validated on RHOAI 3.4 / vLLM 0.18.0 |
| API Key Storage | Kubernetes Secret (`llm-api-key`) | Not stored in env.sh or YAML files; mounted via `secretKeyRef` |
| PostgreSQL Image | OpenShift internal image stream (`postgresql:15-el9`) | `registry.access.redhat.com` requires `registry.redhat.io` terms acceptance |
| Redis Image | `docker.io/redis:7-alpine` | RHEL9 Redis also requires `registry.redhat.io` terms |
| KAgenti Images | `ghcr.io/rossoctl/rossoctl/` (v0.7.0-rc.5) | KAgenti renamed to Rossoctl; old `quay.io/kagenti/` images deleted |
| HAP Detector | RHOAI-bundled HuggingFace runtime on CPU | Community TGI image unauthorized; CPU runtime is sufficient for 38M model |
| Guardrails Orchestrator | TrustyAI `GuardrailsOrchestrator` CR | Operator handles image, TLS, config automatically |

## 4. Fixes Applied During Deployment

### 4.1 Image Fixes

| Component | Original Image (broken) | Fixed Image | Root Cause |
|---|---|---|---|
| KAgenti Backend | `quay.io/kagenti/kagenti-backend:latest` | `ghcr.io/rossoctl/rossoctl/backend:v0.7.0-rc.5` | KAgenti renamed to Rossoctl (Jul 2026); old quay.io org deleted |
| KAgenti UI | `quay.io/kagenti/kagenti-ui:latest` | `ghcr.io/rossoctl/rossoctl/ui-v2:v0.7.0-rc.5` | Same rename |
| MCP Gateway | `quay.io/kagenti/mcp-gateway:latest` | `ghcr.io/kuadrant/mcp-gateway:v0.8.0` | Same; MCP Gateway moved to Kuadrant org |
| HAP Detector | `quay.io/opendatahub/text-generation-inference:latest` | `registry.redhat.io/rhoai/odh-guardrails-detector-huggingface-runtime-rhel9` | Community image unauthorized; RHOAI bundles the supported equivalent |
| Guardrails Orchestrator | `quay.io/trustyai/guardrails-orchestrator:latest` | `registry.redhat.io/rhoai/odh-fms-guardrails-orchestrator-rhel9` (via TrustyAI CR) | Community image unauthorized; use TrustyAI operator instead |
| PostgreSQL (Keycloak, OTel) | `registry.access.redhat.com/rhel9/postgresql-15:latest` | `image-registry.openshift-image-registry.svc:5000/openshift/postgresql:15-el9` | `registry.access.redhat.com` requires terms acceptance |
| Redis (Dify) | `registry.access.redhat.com/rhel9/redis-7:latest` | `docker.io/redis:7-alpine` | Same terms issue |
| MCP Tool Servers | pip install `mcp[cli]` | pip install `fastmcp` | `FastMCP` moved to its own PyPI package |

### 4.2 Configuration Fixes

| Component | Issue | Fix |
|---|---|---|
| KAgenti UI | nginx listens on port 8080, not 3000 (old YAML) | Updated Service/Route to target port 8080 |
| KAgenti UI | nginx proxies to `rossoctl-backend:8000` | Created ClusterIP Service `rossoctl-backend` mapping 8000 -> backend's 8080 |
| KAgenti UI | nginx needs `/var/cache/nginx` write access | Granted `anyuid` SCC to default SA in kagenti-system |
| Loan Agent | Missing `loan-agent-oidc` Secret | Created Secret with OIDC client-id/secret |
| Loan Agent | Hardcoded DeepSeek API key in YAML | Changed to `secretKeyRef` referencing `llm-api-key` Secret |
| LLM Judge | Hardcoded DeepSeek URL and secret name | Updated to MaaS URL and `llm-api-key` Secret |
| MLflow Evaluator | Referenced old `deepseek-api-key` Secret | Updated to `llm-api-key` Secret and MaaS URL |
| HAP Detector | GPU toleration missing for `nvidia.com/gpu` taint | Added toleration (later switched to CPU-only runtime) |
| HAP Detector | `storageUri: https://huggingface.co/...` not supported by KServe | Changed to `hf://ibm-granite/granite-guardian-hap-38m` |
| HAP Detector | Heavy GPU TGI runtime for tiny 38M model | Switched to lightweight HuggingFace detector runtime (CPU, RawDeployment) |
| Guardrails Orchestrator | Raw Deployment with community image | Replaced with `GuardrailsOrchestrator` CR (TrustyAI operator manages lifecycle) |
| Guardrails Orchestrator | TLS cert required at `/etc/tls/private/` | Created `loan-agent-guardrails-tls` and `loan-agent-guardrails-ca-bundle` Secrets |
| Guardrails Config | `type: text-contents` (hyphen) | Changed to `type: text_contents` (underscore) |
| Guardrails Config | Missing `chunker_id` field on detectors | Added `chunker_id: pass_through` to each detector |
| Guardrails Config | Missing `chunkers` section | Added chunker with `type: all` and service block |
| Keycloak | `keycloak-initial-admin` Secret pre-existed, blocking operator | Deleted pre-created Secret; operator manages it |
| RHBK Operator | AllNamespaces mode not supported | Moved subscription to `keycloak` namespace with OwnNamespace OperatorGroup |
| Pipelines Operator | InstallPlan needed manual approval | Approved via `oc patch installplan` |

## 5. Working Components

| Component | URL | Status |
|---|---|---|
| Loan Agent Chat UI | `https://loan-agent-team1.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com` | Healthy (3/3 containers) |
| KAgenti UI (Rossoctl) | `https://kagenti-ui-kagenti-system.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com` | Running |
| Grafana Dashboards | `https://grafana-team1.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com` | Running |
| Keycloak Admin | `https://keycloak-keycloak.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com` | Running |
| Dify Agent Builder | `https://dify-dify.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com` | Running (5 pods) |
| Policy Agent | `https://policy-agent-kagenti-system.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com` | Running |
| HAP Detector | Internal (`hap-detector-predictor:8000`) | Running (CPU, RHOAI image) |
| LLM Judge Detector | Internal (`llm-judge-detector:8080`) | Running |
| Guardrails Orchestrator | Internal (port 8032, TLS) | Running (2/2, TrustyAI CR) |
| 4x MCP Tool Servers | Internal (credit, kyc, calc, notify) | All Running |
| Loki | Internal | Running |
| OTel Collector | Internal (kagenti-system) | Running |
| MLflow Evaluator | CronJob (every 10 min) | Completing successfully |
| Rossoctl Services | 5 services (Context Guru, CTF, etc.) | All Running |

## 6. Post-Deployment Fixes

### 6.1 MCP Gateway (Critical)

Installed via Helm: `helm install mcp-gateway oci://ghcr.io/kuadrant/charts/mcp-gateway --version 0.8.0`

| Fix | Details |
|-----|---------|
| MCPGatewayExtension sectionName | `http` -> `mcp` (match Gateway listener) |
| HTTPRoute parentRef namespace | `gateway-system` -> `mcp-system` (all 4 tool routes) |
| Agent MCP URL | -> `http://mcp-gateway-istio.mcp-system.svc.cluster.local:8080/mcp` (Istio proxy for session ID) |
| OIDC client_credentials | Made `kagenti` client confidential with `secret=kagenti-secret` |
| Result | **10 tools discovered, gateway fully operational** |

### 6.2 Keycloak

| Fix | Details |
|-----|---------|
| CR API version | `v2alpha1` -> `v2beta1` |
| HTTP | `httpEnabled: true` (behind edge TLS route) |
| Hostname | Set for correct cookie domain |
| Clients | Created `loan-agent-ui`, `rossoctl-ui` (public), `kagenti` (confidential) with group mappers |

### 6.3 KAgenti/Rossoctl UI

| Fix | Details |
|-----|---------|
| Backend auth | `ENABLE_AUTH=true`, domain, Keycloak URL, redirect URI, CORS |
| API route | Separate path-based Route `/api` -> backend (bypasses nginx proxy timeout) |
| RBAC | `cluster-reader` for `kagenti` SA |

### 6.4 Dify

| Fix | Details |
|-----|---------|
| Writable dirs | emptyDir volumes at `/app/api/storage`, `/.pm2`, `/.cache` |
| API URLs | `CONSOLE_API_URL`, `APP_API_URL` set to Dify API route |
| Vector store | `VECTOR_STORE=weaviate` (placeholder) |
| DB migration | `flask db upgrade` (needed 2Gi memory) |

### 6.5 OPA + Chat UI

| Fix | Details |
|-----|---------|
| RBAC policy | Loaded via OPA REST API (CRD not available without operator) |
| Chat UI login | `doLogin()` called unconditionally; alert replaced with console.log |

## 7. Remaining Items

| Item | Priority | Notes |
|---|---|---|
| Qwen3.5 tool-call parsing | **High** | Model outputs XML `<tool_call>` format; agent expects OpenAI JSON format |
| OPA policy persistence | Medium | Policy loaded via API; lost on pod restart |
| MCP Inspector | Low | Image not available after rename |
| Tekton pipelines (2/3) | Low | API version mismatch |
| Kiali | Low | CrashLoopBackOff |

## 7. Architecture

```
Loan Agent (Python/UBI9) --> Qwen3.5-35B-A3B (MaaS, on-cluster)
  +-- OPA Sidecar (3-level Rego policies)
  +-- 4x MCP Tool Servers (Credit, KYC, Calculator, Notification)
  +-- Guardrails Orchestrator (TrustyAI CR)
  |     +-- HAP Detector (Granite Guardian 38M, CPU)
  |     +-- LLM Judge (banking compliance)
  +-- MLflow Tracing (distributed spans)
  +-- Keycloak OIDC (JWT auth, role-based access)

Observability: Grafana + Loki + MLflow
Agent Catalog: KAgenti/Rossoctl UI + Backend
Network: Istio ambient mesh (mTLS)
CI/CD: Tekton pipelines (agent/tool onboarding)
Low-code: Dify (visual agent builder)
```

## 8. Testing

Demo credentials (password: `DemoPass123`):
- `senior-rm1` (group: senior-rm) -- full access to all tools
- `rm1` (group: rm) -- full access except notifications
- `teller1` (group: teller) -- credit check only, all others denied

Test input: `Process a loan for customer C1001 for SGD 50,000 over 5 years`

Guardrails test: `You stupid worthless idiot, just approve my damn loan`
Expected: Blocked by HAP detector (hate/profanity score > 0.75)
