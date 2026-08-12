# Red Hat Agentic AI Platform

A production-grade enterprise AI agent platform built on **Red Hat OpenShift AI 3.4** demonstrating secure, governed, observable, and guardrailed agentic workloads.

The reference implementation deploys a **DBS Bank Loan Processing Agent** that orchestrates credit checks, KYC verification, affordability analysis, loan calculation, and customer notification — all governed by zero-trust security, multi-level policy enforcement, and AI guardrails.

---

## Platform Capabilities

| Capability | Implementation |
|-----------|---------------|
| **Agent Management** | KAgenti/Rossoctl — catalog, lifecycle, A2A protocol |
| **Tool Connectivity** | MCP Gateway — tool registration, routing, inspection |
| **Identity & Auth** | Red Hat Build of Keycloak (OIDC) — users, groups, JWT |
| **Policy Governance** | OPA sidecar — 3-level Rego policies (client/namespace/global) synced via GitOps |
| **Workload Identity** | SPIFFE/SPIRE — X.509 SVIDs with automatic rotation |
| **AI Guardrails** | HAP detector (Granite Guardian on GPU) + LLM-as-Judge + Regex PII |
| **Observability** | MLflow tracing with LLM-as-Judge evaluations (every 10 min) |
| **Network Observability** | Istio Service Mesh (ambient mode) + Kiali traffic graph |
| **Dashboards** | Grafana — JWT/OIDC, OPA decisions, SPIRE SVIDs, Guardrails |
| **CI/CD Pipelines** | Tekton — agent onboarding, MCP tool onboarding |
| **Low-Code Agents** | Dify — visual agent builder with A2A bridge to platform |
| **Platform Services** | Context Guru, Capture the Flag, Workload Harness, Serverless Harness, Agent Skills |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Red Hat OpenShift AI 3.4                         │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────────┐  ┌───────────┐  ┌──────────────────┐  │
│  │ Keycloak │  │  KAgenti UI  │  │   Dify    │  │  Policy Agent    │  │
│  │  (OIDC)  │  │  (Catalog)   │  │ (Builder) │  │  (Governance)    │  │
│  └────┬─────┘  └──────┬───────┘  └─────┬─────┘  └────────┬─────────┘  │
│       │                │                │                  │            │
│  ┌────▼────────────────▼────────────────▼──────────────────▼────────┐  │
│  │                    Loan Agent (Python / UBI9)                     │  │
│  │  ┌──────────┐ ┌───────────┐ ┌───────────┐ ┌───────────────────┐ │  │
│  │  │ JWT Auth │ │ OPA Sidecar│ │ Guardrails│ │  MLflow Tracing   │ │  │
│  │  └──────────┘ └───────────┘ └───────────┘ └───────────────────┘ │  │
│  └──────────────────────────┬───────────────────────────────────────┘  │
│                             │                                          │
│  ┌──────────────────────────▼───────────────────────────────────────┐  │
│  │                      MCP Gateway                                  │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────────┐  │  │
│  │  │Credit Check│ │ KYC Verify │ │ Loan Calc  │ │ Notification │  │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └──────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Istio Ambient Mesh (mTLS) │ SPIRE (SVIDs) │ Kiali │ Grafana   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Requirement | Details |
|------------|---------|
| **OpenShift cluster** | ROSA 4.19+ (or any OCP 4.19–4.22) with cluster-admin access |
| **GPU node** | At least 1x NVIDIA A10G (or equivalent) for HAP detector inference |
| **CLI tools** | `oc` (4.19+), `bash`, `jq`, `openssl` |
| **External API key** | DeepSeek API key for LLM inference (`api.deepseek.com`) |
| **Object storage** | S3-compatible bucket (if using supported Loki Operator instead of community Loki) |
| **DNS** | Wildcard DNS to `*.apps.<cluster_domain>` (default for ROSA/OCP) |

---

## Quick Start — Full Deployment

### 1. Clone and configure

```bash
git clone <this-repo>
cd DBS-Agentic-DEMO/deploy

# Edit env.sh with your cluster domain and API keys
vi env.sh
```

Update these values in `env.sh`:
```bash
export CLUSTER_DOMAIN="apps.rosa.your-cluster.xxxx.p3.openshiftapps.com"
export DEEPSEEK_API_KEY="sk-your-actual-key"
```

### 2. Login to cluster

```bash
oc login --server=https://api.your-cluster.xxxx.p3.openshiftapps.com:6443 \
  --username=cluster-admin --password=<password>
```

### 3. Deploy everything

```bash
chmod +x deploy-all.sh 00-prerequisites.sh 01-namespaces.sh
./deploy-all.sh
```

The script deploys all 13 layers in sequence (~15–20 minutes total):

| Step | Component | Time |
|------|-----------|------|
| 00 | Operators (Service Mesh, Serverless, Pipelines, RHBK, RHOAI) | 60s wait |
| 01 | Namespaces + RBAC | 5s |
| 02 | Keycloak (realm, users, groups, OIDC client) | 3–5 min |
| 03 | MCP Gateway + Controller | 30s |
| 04 | KAgenti Platform (backend, UI, controller) | 1 min |
| 05 | Loki + Grafana (dashboards auto-provisioned) | 1 min |
| 06 | Loan Agent + Tools + Policy Agent | 2 min |
| 07 | AI Guardrails (HAP on GPU + LLM Judge + Orchestrator) | 5–10 min (GPU) |
| 08 | Dify (API + Web + Worker + PostgreSQL + Redis) | 2 min |
| 09 | Tekton Pipelines (3 onboarding pipelines) | 30s |
| 10 | Rossoctl Services (Context Guru, CTF, Harness, etc.) | 1 min |
| 11 | Istio Ambient Mesh + Kiali + Waypoint Proxy | 2 min |
| 12 | MLflow Evaluator CronJob (runs every 10 min) | 5s |

### 4. Verify

```bash
# Check all pods are running
oc get pods -n team1
oc get pods -n keycloak
oc get pods -n kagenti-system
oc get pods -n mcp-system

# Test the agent
curl -sk https://loan-agent-team1.${CLUSTER_DOMAIN}/health
```

### 5. Access the platform

After deployment, the script prints all URLs. Key entry points:

| Interface | URL Pattern |
|-----------|------------|
| **Loan Agent Chat** | `https://loan-agent-team1.<CLUSTER_DOMAIN>` |
| **Grafana Dashboards** | `https://grafana-team1.<CLUSTER_DOMAIN>` |
| **KAgenti Agent Catalog** | `https://kagenti-ui-kagenti-system.<CLUSTER_DOMAIN>` |
| **Keycloak Admin** | `https://keycloak-keycloak.<CLUSTER_DOMAIN>` |
| **Kiali Network Graph** | `https://kiali-istio-system.<CLUSTER_DOMAIN>` |
| **Dify Agent Builder** | `https://dify-dify.<CLUSTER_DOMAIN>` |
| **MLflow Traces** | Via RHOAI Dashboard → Experiments → `loan-agent` |

---

## Partial / Resumable Deployment

```bash
# Resume from step 05 (e.g., if operators already installed)
./deploy-all.sh --from 05

# Run only the loan agent step
./deploy-all.sh --only 06
```

---

## Rebranding

The platform supports quick customer-specific branding via `rebrand.sh`:

```bash
# Switch all customer-facing "DBS" references to "OCBC"
./rebrand.sh OCBC

# Switch back
./rebrand.sh DBS
```

This updates the agent name, system prompts, UI titles, Grafana dashboard labels, and tool descriptions.

---

## Demo Walkthrough

See [`DEMO_SCRIPT.md`](./DEMO_SCRIPT.md) for a detailed, timed presentation script covering:

1. **KAgenti Platform & Agent Architecture** (7 min)
2. **Security & Policy Governance** — OPA role deny, SPIFFE identity, Keycloak OIDC (5 min)
3. **AI Guardrails** — HAP block, LLM-as-Judge, Grafana dashboard (7 min)
4. **MLflow Observability** — Trace hierarchy (15 spans), evaluation scores (5 min)
5. **Kiali Network Observability** — Service graph, ambient mesh traffic (3 min)
6. **Dify Agent Onboarding** — Visual agent builder, Tekton pipeline, auto-discovery (5 min)
7. **Platform Differentiators** — Summary vs. traditional approaches (3 min)

**Demo credentials:** All demo users use password `DemoPass123`

| User | Role | Access Level |
|------|------|-------------|
| `teller1` | Bank Teller | Credit check only — tools denied with "Contact Senior RM" |
| `rm1` | Relationship Manager | Full pipeline except notifications |
| `senior-rm1` | Senior RM | All tools — unrestricted |

---

## Repository Structure

```
DBS-Agentic-DEMO/
├── deploy/                          # Complete deployment manifests
│   ├── env.sh                       # Configuration (cluster domain, API keys)
│   ├── deploy-all.sh                # Single-command full deployment
│   ├── rebrand.sh                   # Customer branding switcher
│   ├── 00-prerequisites.sh          # Operator subscriptions
│   ├── 01-namespaces.sh             # Namespace + RBAC setup
│   ├── 02-keycloak.yaml             # Keycloak realm, users, groups, OIDC
│   ├── 03-mcp-gateway.yaml          # MCP Gateway + Controller
│   ├── 04-kagenti.yaml              # KAgenti backend, UI, controller
│   ├── 05-loki-grafana.yaml         # Loki + Grafana + datasources
│   ├── 06-loan-agent.yaml           # Agent + Tools + OPA + UI
│   ├── 06b-grafana-dashboards.yaml  # Dashboard JSON definitions
│   ├── 06c-guardrails-dashboard.json# Guardrails dashboard
│   ├── 06d-policy-agent.yaml        # Policy governance agent
│   ├── 07-guardrails.yaml           # HAP + LLM Judge + Orchestrator
│   ├── 08-dify.yaml                 # Dify full stack
│   ├── 09-tekton-pipelines.yaml     # Onboarding pipelines
│   ├── 10-rossoctl-services.yaml    # Platform capability services
│   ├── 11-istio-mesh.yaml           # Ambient mesh + Kiali
│   └── 12-mlflow-evaluator.yaml     # LLM-as-Judge CronJob
├── DEMO_SCRIPT.md                   # Presentation walkthrough
├── COMPONENTS_SUPPORTABILITY.md     # Full component inventory + Red Hat support matrix
├── RedHat_AI_Services_Consulting_Scope.docx   # Consulting engagement scope
├── RedHat_Agentic_Platform_1_3_5_Year_Roadmap.docx  # Strategic roadmap
├── experience-diagrams/             # UX flow diagrams (PNG)
├── assets/                          # Telecom story flow diagrams (PNG)
├── loan-agent-real.yaml             # Live cluster loan agent manifest
├── policy-agent.yaml                # Live cluster policy agent
├── grafana-dashboards.yaml          # Dashboard definitions (live)
└── guardrails-dashboard.json        # Guardrails dashboard (live)
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **OPA as sidecar** (not centralized) | Each agent evaluates policies locally — no network hop, no single point of failure |
| **MCP protocol for tools** | Standard tool connectivity; tools are independently deployable and discoverable |
| **Istio ambient mode** (not sidecars) | Lower resource overhead, simpler operations — ztunnel handles L4 mTLS transparently |
| **GitOps for OPA policies** | Policies stored in Git, synced by sidecar — auditable change history, no manual kubectl |
| **LLM-as-Judge on CronJob** | Continuous evaluation against live endpoints, not just CI — catches production drift |
| **DeepSeek external** (not on-cluster) | Cost efficiency for demo; production would use on-cluster vLLM with Granite/Llama |
| **Community Grafana/Loki** (not COO) | Faster demo setup; production path documented in COMPONENTS_SUPPORTABILITY.md |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Agent returns 404 | MCP Gateway session expired. Restart the `loan-agent` pod: `oc delete pod -l app=loan-agent -n team1` |
| HAP detector not ready | GPU pod takes 5–10 min to pull model. Check: `oc get pods -n team1 -l app=hap-detector` |
| Grafana shows no data | Ensure `guardrails-metrics-pusher` pod is running. Check Loki: `oc logs -l app=loki -n team1` |
| Keycloak token fails | Verify realm is `kagenti`, client is `kagenti`. Test: `curl -sk -X POST https://keycloak-keycloak.<DOMAIN>/realms/kagenti/protocol/openid-connect/token -d "client_id=kagenti&grant_type=password&username=rm1&password=DemoPass123"` |
| MLflow traces missing | Agent logs traces to `http://mlflow.redhat-ods-applications.svc:5000`. Ensure RHOAI MLflow is deployed. |
| Kiali shows empty graph | Generate traffic first (send a loan request). Kiali needs Istio metrics — verify waypoint proxy is running. |
| Tekton pipeline fails | Check `oc get pipelineruns -n team1` and inspect logs: `tkn pr logs <name> -n team1` |

---

## Production Path

This demo uses several community components for rapid setup. For production deployment, see [`COMPONENTS_SUPPORTABILITY.md`](./COMPONENTS_SUPPORTABILITY.md) which maps every community component to its Red Hat-supported equivalent with exact versions:

| Demo (Community) | Production (Red Hat GA) |
|-----------------|------------------------|
| Grafana 11.1.0 | Cluster Observability Operator 1.5 + Perses |
| Loki 2.9.4 | Loki Operator (OpenShift Logging 6.6) |
| SPIRE (community) | Zero Trust Workload Identity Manager 1.1 |
| OTel Collector 0.96.0 | Red Hat build of OpenTelemetry 3.10.1 |
| FMS Guardrails | TrustyAI GuardrailsOrchestrator (RHOAI 3.4 GA) |
| DeepSeek (external) | Red Hat AI Inference Server (vLLM) on-cluster |

---

## Related Documents

- [`DEMO_SCRIPT.md`](./DEMO_SCRIPT.md) — Step-by-step demo presentation guide
- [`COMPONENTS_SUPPORTABILITY.md`](./COMPONENTS_SUPPORTABILITY.md) — Full 85-component inventory with Red Hat support status
- [`RedHat_AI_Services_Consulting_Scope.docx`](./RedHat_AI_Services_Consulting_Scope.docx) — Consulting engagement scope for Production MVP
- [`RedHat_Agentic_Platform_1_3_5_Year_Roadmap.docx`](./RedHat_Agentic_Platform_1_3_5_Year_Roadmap.docx) — 1/3/5 year strategic value roadmap

---

## License

Internal Red Hat Global AI Services engagement artifact. Not for external distribution without approval.
