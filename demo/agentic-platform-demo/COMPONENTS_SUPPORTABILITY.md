# DBS Agentic AI Platform — Component Inventory & Red Hat Supportability Matrix

**Target Platform:** Red Hat OpenShift AI Self-Managed 3.4  
**Cluster:** ROSA (Red Hat OpenShift Service on AWS)  
**Architecture:** x86_64  
**OpenShift Version:** 4.19.9+ / 4.20 / 4.21 / 4.22  
**Date:** August 2026  
**Source:** [RHOAI Supported Configs 3.x](https://access.redhat.com/articles/rhoai-supported-configs-3.x)

---

## Support Status Definitions

| Status | Definition | SLA Coverage |
|--------|-----------|--------------|
| **GA** | General Availability — fully tested, verified, production-supported | Full Red Hat production SLA |
| **TP** | Technology Preview — functional, not for production use under SLA | No production SLA; best-effort support |
| **RH-Supported** | Supported via a separate Red Hat product subscription | Full SLA under that product's terms |
| **Community** | Upstream open-source project — no Red Hat production support | Customer self-supports; Red Hat may assist on best-effort |
| **Custom** | Customer-authored code running on supported infrastructure | Platform is supported; application logic is customer's responsibility |
| **ISV/External** | Third-party vendor product or service | Vendor provides support; Red Hat supports integration only |

---

## 1. Red Hat OpenShift AI 3.4 — Native Components (GA)

These components ship with the RHOAI 3.4 operator and are fully supported on x86_64.

| Component | Version in RHOAI 3.4 | Status | Used In Demo | Purpose |
|-----------|----------------------|--------|--------------|---------|
| RHOAI Operator | 3.4 | **GA** | ✅ | Core platform operator |
| RHOAI Dashboard | 2.0.0 | **GA** | ✅ | AI platform web console |
| KServe | 0.17.0 | **GA** | ✅ | Model serving (InferenceService for HAP detector) |
| Red Hat AI Inference Server (vLLM) | 3.4.0 (vLLM v0.18.0) | **GA** | ✅ | High-performance LLM inference runtime |
| LLM Compressor | v0.10.0.1 | **GA** | — | Model quantization (available but not used in demo) |
| MLflow | 3.10.1 | **GA** | ✅ | Experiment tracking, LLM tracing, evaluations |
| TrustyAI | 1.37.0 | **GA** | ✅ | AI governance, explainability |
| Data Science Pipelines | 2.16.0 | **GA** | — | ML pipeline orchestration (available) |
| Argo Workflows | v3.7.3 | **GA** | — | Pipeline workflow engine |
| KubeRay | 1.4.2 | **GA** | — | Distributed computing (available) |
| Kubeflow Trainer v2 | 2.1.0 | **GA** | — | Distributed training |
| LMEval | 0.4.8 | **GA** | — | Model evaluation framework |
| Feature Store | 0.62.0 | **GA** | — | Feature management |
| AI Hub | 0.3.9 | **GA** | — | Model catalog and hub |
| Workbenches | 1.10.0 | **GA** | — | Jupyter notebooks |
| MaaS (Models-as-a-Service) | 0.1.1 | **GA** | — | Centralized model governance |
| Distributed Inference (llm-d) | 0.7.1 | **GA** | — | Distributed inference |

---

## 2. Red Hat OpenShift AI 3.4 — Technology Preview Components

| Component | Version in RHOAI 3.4 | Status | Used In Demo | Purpose |
|-----------|----------------------|--------|--------------|---------|
| Llama Stack Operator | 0.9.0 | **TP** | ✅ | Unified API layer for agents/inference/tools |
| Authorino (via Connectivity Link) | Included with MaaS | **TP** | — | OIDC-compatible authorization for model endpoints |

---

## 3. Red Hat OpenShift Container Platform (OCP) — Core

| Component | Version | Status | Used In Demo | Purpose |
|-----------|---------|--------|--------------|---------|
| Red Hat OpenShift Container Platform | 4.19.9+ / 4.20 / 4.21 / 4.22 | **RH-Supported** | ✅ | Enterprise Kubernetes |
| ROSA (Red Hat OpenShift Service on AWS) | Managed service | **RH-Supported** | ✅ | Managed OCP on AWS |
| OpenShift Internal Image Registry | OCP built-in | **RH-Supported** | ✅ | Container image storage |
| OpenShift Console | OCP built-in | **RH-Supported** | ✅ | Cluster web console |
| OpenShift Monitoring (Prometheus) | OCP built-in | **RH-Supported** | ✅ | Cluster metrics |
| OpenShift Logging (optional) | OCP add-on | **RH-Supported** | — | Alternative to Loki (not used; Loki used instead) |

---

## 4. Red Hat OpenShift Service Mesh (Istio)

| Component | Version | Status | Used In Demo | Purpose |
|-----------|---------|--------|--------------|---------|
| OpenShift Service Mesh Operator | 3.3.5 | **RH-Supported** | ✅ | Istio lifecycle management |
| Istio Control Plane | 1.28.8 | **RH-Supported** | ✅ | Service mesh control plane (ambient mode) |
| Envoy Proxy | 1.36.8 | **RH-Supported** | ✅ | L4/L7 proxy sidecar |
| IstioCNI | 1.28.8 | **RH-Supported** | ✅ | CNI plugin for ambient mesh |
| Ztunnel | 1.28.8 | **RH-Supported** | ✅ | Zero-trust tunnel (ambient mode L4 proxy) |
| Kiali Operator | 2.22.6 | **RH-Supported** | ✅ | Service mesh visualization operator |
| Kiali Server | 2.22.6 | **RH-Supported** | ✅ | Network topology and traffic graph UI |
| Waypoint Proxy (Gateway API) | Istio 1.28.8 | **RH-Supported** | ✅ | L7 observability for ambient mesh |
| PeerAuthentication (STRICT mTLS) | Istio CRD | **RH-Supported** | ✅ | Enforces mutual TLS on all pod traffic |

**Supported OCP versions:** 4.18–4.22  
**Source:** [OSSM 3.3 Release Notes](https://docs.redhat.com/en/documentation/red_hat_openshift_service_mesh/3.3/html/release_notes/ossm-release-notes-version-support-tables)

---

## 5. Red Hat Build of Keycloak (RHBK)

| Component | Version | Status | Used In Demo | Purpose |
|-----------|---------|--------|--------------|---------|
| RHBK Operator | stable-v26 channel | **RH-Supported** | ✅ | Keycloak lifecycle management |
| RHBK Server | 26.6.x | **RH-Supported** | ✅ | OIDC/SAML identity provider |
| Keycloak Realm (`kagenti`) | — | **RH-Supported** | ✅ | Tenant configuration |
| Keycloak Client (`kagenti`) | — | **RH-Supported** | ✅ | OIDC client for agent UI |
| Keycloak Users (9 demo users) | — | **RH-Supported** | ✅ | teller1, rm1, senior-rm1, alice, bob, admin, etc. |
| Keycloak Groups (teller/rm/senior-rm) | — | **RH-Supported** | ✅ | Role-based access control |
| Keycloak Group Membership Mapper | — | **RH-Supported** | ✅ | Injects groups into JWT tokens |
| PostgreSQL (Keycloak backend) | RHEL9 PostgreSQL 15 | **RH-Supported** | ✅ | Keycloak persistence |
| keycloak-js (browser adapter) | 25.x (CDN) | **RH-Supported** | ✅ | Client-side OIDC |

**Supported OCP versions:** 4.12–4.21  
**Supported architectures:** x86_64, s390x, ppc64le, aarch64  
**Source:** [RHBK Supported Configurations](https://access.redhat.com/articles/7033107)

---

## 6. Red Hat OpenShift Pipelines (Tekton)

| Component | Version | Status | Used In Demo | Purpose |
|-----------|---------|--------|--------------|---------|
| OpenShift Pipelines Operator | 1.20.x | **RH-Supported** | ✅ | CI/CD pipeline engine |
| Tekton Pipelines | 0.68.x | **GA** | ✅ | Core pipeline engine |
| Tekton Triggers | 0.31.x | **GA** | — | Event-driven pipeline execution |
| Tekton Chains | 0.24.x | **GA** | — | Supply chain security |
| Pipelines as Code | 0.33.x | **GA** | — | Git-triggered pipelines |
| Tekton Results | 0.14.x | **GA** | — | Pipeline result storage |
| Pipeline: `onboard-dify-agent` | Custom | **Custom** | ✅ | Dify agent → KAgenti deployment |
| Pipeline: `onboard-agent-examples` | Custom | **Custom** | ✅ | Git repo agent → KAgenti deployment |
| Pipeline: `onboard-mcp-tool` | Custom | **Custom** | ✅ | Git repo MCP tool → cluster deployment |
| Task: `buildah-build` | Custom (uses Buildah) | **RH-Supported** (Buildah) | ✅ | Container image build |
| Task: `deploy-agent` | Custom | **Custom** | ✅ | Agent Deployment + Service + Route creation |
| Task: `deploy-mcp-server` | Custom | **Custom** | ✅ | MCP tool Deployment + Service creation |

**Supported OCP versions:** 4.15+  
**Source:** [OpenShift Pipelines 1.20 Release Notes](https://docs.redhat.com/en/documentation/red_hat_openshift_pipelines/1.20/html-single/release_notes/index)

---

## 7. Red Hat OpenShift Serverless

| Component | Version | Status | Used In Demo | Purpose |
|-----------|---------|--------|--------------|---------|
| OpenShift Serverless Operator | 1.36.x | **RH-Supported** | ✅ | Knative lifecycle management |
| Knative Serving | 1.16 | **RH-Supported** | ✅ | Serverless model serving (KServe dependency) |
| Knative Eventing | 1.16 | **RH-Supported** | — | Event-driven architecture |
| Kourier | 1.16 | **RH-Supported** | ✅ | Ingress for Knative services |

**Source:** [OpenShift Serverless 1.36 Release Notes](https://docs.redhat.com/en/documentation/red_hat_openshift_serverless/1.36/html/about_openshift_serverless/serverless-release-notes)

---

## 8. NVIDIA GPU Stack

| Component | Version | Status | Used In Demo | Purpose |
|-----------|---------|--------|--------------|---------|
| NVIDIA GPU Operator | 24.3 | **ISV** (NVIDIA) | ✅ | GPU device plugin, driver management |
| NVIDIA A10G (Ampere) | Hardware | **Supported accelerator** | ✅ | Inference compute for HAP model |
| CUDA Toolkit | 13.0 | **ISV** (NVIDIA) | ✅ | GPU compute library |
| NVIDIA Container Toolkit | 1.14 | **ISV** (NVIDIA) | ✅ | GPU container runtime |

**Source:** [Red Hat AI Supported Hardware](https://docs.redhat.com/en/documentation/red_hat_ai/3/html-single/supported_product_and_hardware_configurations/index)

---

## 9. Community Components (No Red Hat Production SLA)

| Component | Version Used | Source | Used In Demo | Purpose |
|-----------|-------------|--------|--------------|---------|
| Grafana | 11.1.0 | Grafana Labs | ✅ | Dashboards & visualization |
| Loki | 2.9.4 | Grafana Labs | ✅ | Log aggregation |
| OPA (Open Policy Agent) | latest (sidecar) | CNCF | ✅ | Policy enforcement (Rego) |
| SPIFFE/SPIRE Operator | community | CNCF | ✅ | Workload identity (X.509 SVIDs) |
| SPIRE Server | latest | CNCF | ✅ | SVID CA and issuance |
| SPIRE Agent (DaemonSet) | latest | CNCF | ✅ | Node attestation |
| SPIFFE CSI Driver | latest | CNCF | ✅ | Mount SVID sockets |
| OpenTelemetry Collector | 0.96.0 | CNCF | ✅ | Trace/metric collection |
| FMS Guardrails Orchestrator | latest | IBM/TrustyAI upstream | ✅ | Content safety pipeline |
| Prometheus (Istio-dedicated) | v2.51.0 | CNCF | ✅ | Metrics for Kiali |
| FastMCP (Python SDK) | latest | PyPI | ✅ | MCP server framework |
| Kubernetes Gateway API CRDs | v1.1.0 | K8s SIG | ✅ | Gateway/HTTPRoute |

### Red Hat Supported Equivalents for Production

| Community Component | Red Hat Supported Product | Version | Status | Notes |
|--------------------|-----------------------------|---------|--------|-------|
| **Grafana 11.1.0** | **Cluster Observability Operator (COO) + Red Hat build of Perses** | COO 1.5 / Perses (latest) | **GA** | Kubernetes-native dashboards with built-in RBAC. Grafana JSON import supported via `percli --online`. Replaces external Grafana entirely. OCP 4.15+ required. |
| **Loki 2.9.4** | **Loki Operator (Red Hat OpenShift Logging)** | 6.6.x (stable-6.6 channel) | **GA** | Fully supported Loki with S3-compatible backends (AWS S3, ODF, MinIO). Install via OperatorHub → `openshift-operators-redhat` namespace. Must match Red Hat OpenShift Logging Operator version (e.g. both on stable-6.6). |
| | **Red Hat OpenShift Logging Operator** | 6.6.x (stable-6.6 channel) | **GA** | Log collection and forwarding via `ClusterLogForwarder` CRD. Supports OTLP output (GA since 6.5). |
| **OPA (sidecar)** | **Authorino (via Red Hat Connectivity Link)** | Included with RHOAI 3.4 MaaS | **GA** | OIDC/API-key authorization for model endpoints. For broader policy use: no direct OPA GA product exists; consider Kyverno or use OPA community on supported infra. |
| **SPIFFE/SPIRE (community)** | **Zero Trust Workload Identity Manager** | 1.1 (Operator 0.2.0+) | **GA** | Red Hat's production-supported SPIFFE/SPIRE operator. Manages SpireServer, SpireAgent, SPIFFE CSI Driver, OIDC Discovery Provider via CRDs. Supports SPIRE federation, PostgreSQL persistence, cert-manager integration. OCP 4.19+ required. Included with OpenShift Platform Plus OR standard OCP entitlement. |
| | **cert-manager Operator for Red Hat OpenShift** | 1.18.0+ (stable-v1 channel) | **GA** | X.509 certificate lifecycle management. Integrates with Zero Trust Workload Identity Manager as UpstreamAuthority plugin. |
| **OpenTelemetry Collector 0.96.0** | **Red Hat build of OpenTelemetry** | 3.10.1 (Operator 0.152.0) | **GA** | Production-supported OTel Collector with `OpenTelemetryCollector` CRD. Auto-instrumentation for Java, Node.js, Python, Go, .NET (TP). Install via OperatorHub → `openshift-opentelemetry-operator` namespace. |
| **FMS Guardrails Orchestrator** | **TrustyAI Guardrails Orchestrator (RHOAI 3.4)** | Included with RHOAI 3.4 (TrustyAI Operator) | **GA** | Exact same codebase — FMS Guardrails Orchestrator IS the upstream for TrustyAI GuardrailsOrchestrator CRD. Deploy via `GuardrailsOrchestrator` CR. Supports AutoConfig (auto-discovers detectors in namespace), Guardrails Gateway sidecar, regex detectors, OTel export. Llama Stack integration (TP). |
| **Prometheus v2.51.0 (standalone)** | **OpenShift built-in Monitoring Stack** | OCP built-in (Prometheus Operator) | **GA** | Cluster-scoped Prometheus managed by OCP. For user-workload monitoring, enable `user-workload-monitoring` in `cluster-monitoring-config`. For custom stacks: COO 1.5 `MonitoringStack` CRD (GA). |
| **FastMCP (Python SDK)** | *No Red Hat equivalent* | — | — | Community Python library. Runs on supported UBI9/Python-311 base image. Application logic is customer responsibility. |
| **Gateway API CRDs v1.1.0** | **Included with OpenShift Service Mesh 3.x** | v1.1.0 (bundled) | **GA** | Gateway, HTTPRoute, GRPCRoute CRDs ship with Service Mesh 3.3 Operator. No separate install needed. |

**Key References:**
- [Zero Trust Workload Identity Manager 1.1 GA Blog](https://www.redhat.com/en/blog/zero-trust-workload-identity-manager-11-generally-available-red-hat-openshift)
- [COO 1.5 + Red Hat build of Perses GA](https://www.redhat.com/en/blog/new-observability-features-red-hat-openshift-422)
- [TrustyAI Guardrails in RHOAI 3.4](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/enabling_ai_safety_with_guardrails/using-guardrails-for-ai-safety_safety)
- [Red Hat build of OpenTelemetry 3.10](https://docs.redhat.com/en/documentation/red_hat_build_of_opentelemetry/3.10/html/release_notes_for_the_red_hat_build_of_opentelemetry/otel_rn)
- [OpenShift Logging 6.6](https://docs.redhat.com/en/documentation/red_hat_openshift_logging/6.6/html/installing_logging/overview-of-openshift-logging-installation)
- [cert-manager Operator for Red Hat OpenShift](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/security_and_compliance/cert-manager-operator-for-red-hat-openshift)

---

## 10. KAgenti / Rossoctl Platform (Community)

| Component | Version | Source | Used In Demo | Purpose |
|-----------|---------|--------|--------------|---------|
| KAgenti Operator | alpha | github.com/rossoctl | ✅ | Agent lifecycle CRDs |
| KAgenti Backend | latest | github.com/rossoctl | ✅ | Agent catalog API |
| KAgenti Controller Manager | latest | github.com/rossoctl | ✅ | AgentRuntime reconciler |
| KAgenti UI | latest | github.com/rossoctl | ✅ | Web console (branded "Red Hat OpenShift AI") |
| MCP Gateway | latest | github.com/rossoctl | ✅ | MCP protocol routing |
| MCP Gateway Controller | latest | github.com/rossoctl | ✅ | MCPServerRegistration watcher |
| MCP Inspector | latest | github.com/rossoctl | ✅ | MCP debugging tool |

**Support Status:** All community. No Red Hat production SLA.  
**Production path:** Evaluate if RHOAI AI Hub (GA, v0.3.9) covers catalog requirements.

---

## 11. Dify Stack (Community)

| Component | Version | Source | Used In Demo | Purpose |
|-----------|---------|--------|--------------|---------|
| Dify API Server | 0.6.16 | LangGenius (langgenius/dify-api) | ✅ | Low-code agent builder backend |
| Dify Web Frontend | 0.6.16 | LangGenius (langgenius/dify-web) | ✅ | Agent builder UI |
| Dify Worker | 0.6.16 | LangGenius | ✅ | Async task execution |
| PostgreSQL (Dify) | RHEL9 PostgreSQL 15 | **RH-Supported** (image) | ✅ | Dify persistence |
| Redis (Dify) | RHEL9 Redis 7 | **RH-Supported** (image) | ✅ | Dify cache/broker |
| Dify A2A Bridge | Custom Python | **Custom** | ✅ | Agent-to-Agent protocol adapter |

---

## 12. Custom Application Workloads

These run on Red Hat-supported infrastructure (UBI9, OCP) but the application logic is customer responsibility.

| Component | Base Image | Used In Demo | Purpose |
|-----------|-----------|--------------|---------|
| DBS Loan Processing Agent | ubi9/python-311 | ✅ | Core agent (DeepSeek + MCP + OPA + MLflow) |
| Agent Chat UI (HTML/JS) | Served by agent pod | ✅ | Browser UI with Keycloak OIDC login |
| LLM-as-Judge Detector | ubi9/python-311 | ✅ | Custom content safety judge (uses DeepSeek) |
| Guardrails Metrics Pusher | ubi9/python-311 | ✅ | Simulated log data generator for Grafana |
| Policy Governance Agent | ubi9/python-311 | ✅ | Policy management UI + audit trail |
| OPA Policy Sync Sidecar | ubi9/python-311 | ✅ | GitOps sync from GitHub → OPA |
| MLflow Evaluator (CronJob) | ubi9/python-311 | ✅ | LLM-as-Judge eval every 10 min |
| Loan Tools: Credit Check | ubi9/python-311 | ✅ | FastMCP credit bureau tool |
| Loan Tools: KYC Verify | ubi9/python-311 | ✅ | FastMCP KYC verification tool |
| Loan Tools: Calculator | ubi9/python-311 | ✅ | FastMCP loan calculation tool |
| Loan Tools: Notification | ubi9/python-311 | ✅ | FastMCP SMS/email notification tool |
| Context Guru | ubi9/python-311 | ✅ | Token compaction proxy (Rossoctl) |
| Capture the Flag | ubi9/python-311 | ✅ | Security scenario runner (Rossoctl) |
| Workload Harness | ubi9/python-311 | ✅ | Load generation benchmarks (Rossoctl) |
| Serverless Harness | ubi9/python-311 | ✅ | Scale-to-zero fleet simulation (Rossoctl) |
| Agent Skills | ubi9/python-311 | ✅ | Self-maintenance agent runner (Rossoctl) |

---

## 13. Container Base Images — Registry & Support

| Image | Registry | Red Hat Supported | Used For |
|-------|----------|-------------------|----------|
| `registry.access.redhat.com/ubi9/python-311:latest` | Red Hat Registry | **Yes** (RHEL 9 UBI) | All custom Python services |
| `registry.access.redhat.com/rhel9/postgresql-15:latest` | Red Hat Registry | **Yes** (RHEL 9) | Keycloak DB, Dify DB, OTel DB |
| `registry.access.redhat.com/rhel9/redis-7:latest` | Red Hat Registry | **Yes** (RHEL 9) | Dify Redis, Serverless Redis |
| `registry.redhat.io/rhoai/odh-llama-stack-core-rhel9` | Red Hat Registry | **Yes** (RHOAI) | Llama Stack runtime |
| `quay.io/buildah/stable:latest` | Quay.io | **Yes** (part of OCP) | Tekton build tasks |
| `docker.io/grafana/grafana:11.1.0` | Docker Hub | **No** (community) | Grafana dashboards |
| `docker.io/grafana/loki:2.9.4` | Docker Hub | **No** (community) | Log aggregation |
| `prom/prometheus:v2.51.0` | Docker Hub | **No** (community) | Istio metrics |
| `ghcr.io/open-telemetry/opentelemetry-collector-contrib:0.96.0` | GitHub | **No** (community) | OTel collector |
| `quay.io/kagenti/mcp-gateway:latest` | Quay.io | **No** (community) | MCP Gateway |
| `quay.io/kagenti/kagenti-backend:latest` | Quay.io | **No** (community) | Agent catalog |
| `quay.io/kagenti/kagenti-controller:latest` | Quay.io | **No** (community) | Agent controller |
| `quay.io/kagenti/kagenti-ui:latest` | Quay.io | **No** (community) | Agent UI |
| `quay.io/kagenti/mcp-inspector:latest` | Quay.io | **No** (community) | MCP inspector |
| `quay.io/trustyai/guardrails-orchestrator:latest` | Quay.io | **No** (community) | FMS Guardrails |
| `quay.io/kiali/kiali:v1.86` | Quay.io | **Yes** (Service Mesh) | Kiali |
| `langgenius/dify-api:0.6.16` | Docker Hub | **No** (community) | Dify API |
| `langgenius/dify-web:0.6.16` | Docker Hub | **No** (community) | Dify frontend |

---

## 14. External Dependencies

| Dependency | Type | Provider | Support | Used For |
|------------|------|----------|---------|----------|
| DeepSeek API (`api.deepseek.com/v1`) | External LLM | DeepSeek | Vendor SLA | Agent inference + LLM-Judge |
| GitHub (`github.com/avijra/kagenti-opa-policies`) | Git hosting | GitHub/Microsoft | GitHub SLA | OPA policy-as-code GitOps |
| GitHub (`github.com/kagenti/agent-examples`) | Git hosting | GitHub/Microsoft | GitHub SLA | Agent/MCP templates for Tekton pipelines |
| CDN (`cdn.jsdelivr.net/npm/keycloak-js@25`) | JS library CDN | jsDelivr | Best-effort | Browser Keycloak adapter |
| Granite Guardian HAP model (`ibm-granite/granite-guardian-hap-38m`) | ML model weights | IBM (Hugging Face) | Community | Content safety HAP detection |

---

## 15. Python Packages (Runtime Dependencies)

| Package | Version | Source | Supported | Purpose |
|---------|---------|--------|-----------|---------|
| `urllib.request` | stdlib | Python 3.11 | **Yes** (UBI9) | HTTP client for all API calls |
| `json` | stdlib | Python 3.11 | **Yes** (UBI9) | JSON serialization |
| `ssl` | stdlib | Python 3.11 | **Yes** (UBI9) | TLS context management |
| `hashlib` | stdlib | Python 3.11 | **Yes** (UBI9) | Hashing |
| `uuid` | stdlib | Python 3.11 | **Yes** (UBI9) | Request ID generation |
| `time`, `os`, `random` | stdlib | Python 3.11 | **Yes** (UBI9) | Utilities |
| `http.server` | stdlib | Python 3.11 | **Yes** (UBI9) | Lightweight HTTP server |
| `mcp` (FastMCP) | latest | PyPI (community) | **No** | MCP server framework |
| `mlflow` | 3.10.1 | PyPI / RHOAI | **Yes** (RHOAI 3.4 GA) | Experiment tracking client |
| `python-docx` | latest | PyPI (community) | **No** | DOCX document generation |

---

## Summary: Complete Count

| Support Category | Component Count | Percentage |
|-----------------|----------------|------------|
| **RHOAI 3.4 GA** (full production SLA) | 17 | 20% |
| **RHOAI 3.4 TP** (tech preview, no prod SLA) | 2 | 2% |
| **RH-Supported** (other Red Hat product with SLA) | 25 | 30% |
| **Community** (no Red Hat SLA) | 22 | 26% |
| **Custom workloads** (customer code on supported infra) | 16 | 19% |
| **ISV/External** (third-party vendor) | 3 | 3% |
| **TOTAL** | **85** | 100% |

---

## Production Readiness Recommendations

| # | Gap | Recommendation | Effort |
|---|-----|---------------|--------|
| 1 | Grafana/Loki (community) | Replace with **OpenShift Logging** (Loki Operator, supported) + **OpenShift Console Observe** tab | Medium |
| 2 | OPA (community) | Replace with **Authorino** (included with RHOAI 3.4 MaaS) or **Red Hat Connectivity Link** | Medium |
| 3 | SPIFFE/SPIRE (community) | Already covered by **Istio mTLS** (Service Mesh STRICT mode provides equivalent zero-trust) | Low — remove SPIRE, rely on mesh |
| 4 | DeepSeek (external) | Replace with **on-cluster vLLM** serving Granite/Llama/Mistral via **Red Hat AI Inference Server** (GA) | High (needs GPU for large model) |
| 5 | KAgenti (community) | Accept community posture OR use **RHOAI AI Hub** (GA v0.3.9) for catalog + **Tekton** for lifecycle | Medium |
| 6 | Dify (community) | Accept community posture OR build agents directly on **Llama Stack** (TP) or custom vLLM agents | Low (Dify optional) |
| 7 | FMS Guardrails (community) | Evaluate migration to **TrustyAI** (GA 1.37.0) which is production-supported | Medium |
| 8 | OpenTelemetry Collector (community) | Replace with **Red Hat build of OpenTelemetry** (supported product) | Low |

---

## References

- [RHOAI 3.4 Supported Configurations](https://access.redhat.com/articles/rhoai-supported-configs-3.x)
- [Red Hat AI Supported Hardware](https://docs.redhat.com/en/documentation/red_hat_ai/3/html-single/supported_product_and_hardware_configurations/index)
- [OpenShift Service Mesh 3.3 Version Support](https://docs.redhat.com/en/documentation/red_hat_openshift_service_mesh/3.3/html/release_notes/ossm-release-notes-version-support-tables)
- [RHBK Supported Configurations](https://access.redhat.com/articles/7033107)
- [OpenShift Pipelines 1.20 Release Notes](https://docs.redhat.com/en/documentation/red_hat_openshift_pipelines/1.20/html-single/release_notes/index)
- [OpenShift Serverless 1.36](https://docs.redhat.com/en/documentation/red_hat_openshift_serverless/1.36/html/about_openshift_serverless/serverless-release-notes)
- [RHOAI 3.4 Blog — MaaS](https://www.redhat.com/en/blog/scaling-enterprise-ai-delivering-models-service-openshift-ai-34)
