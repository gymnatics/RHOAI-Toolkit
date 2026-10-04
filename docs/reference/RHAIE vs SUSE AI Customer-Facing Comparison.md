# Red Hat AI Enterprise and SUSE AI: A Platform Capability Comparison

**Prepared**: September 2026. **Purpose**: This document compares Red Hat AI Enterprise (RHAIE) — built on Red Hat OpenShift AI (RHOAI) 3.5 and Red Hat AI Inference 3.5 — with SUSE AI 1.0 and SUSE AI Factory 2.2.0, based on each vendor's current official documentation. It is intended to help technical evaluators understand how the two platforms differ in scope, architecture, and capability so they can assess fit against their own requirements.

**A note on sourcing and currency**: Every claim below is sourced from the vendor documentation and public project repositories cited at the end of this document. Both platforms release new versions frequently; readers should confirm current status directly with each vendor before making a purchasing decision, particularly for any capability marked **Technology Preview** or **Developer Preview**, which is pre-GA and not covered by production support commitments from either vendor.

**A note on open source**: Both platforms are built substantially on open-source software. Red Hat's OpenShift AI dashboard, operator, and most of its AI-specific components (KServe, TrustyAI, the Model Registry, the Models-as-a-Service controller, and others) are published under the `opendatahub-io` GitHub organization, Apache License 2.0, as part of the Open Data Hub community project. SUSE AI is built on a set of independently governed open-source projects (Ollama, vLLM, Milvus, Kubeflow, MLflow, and others) packaged as Helm charts. This document is not a comparison of open versus proprietary software — it is a comparison of which specific capabilities each vendor has integrated, tested, documented, and covers under a support agreement as part of its product, and which open-source projects each vendor originates or holds maintainer/governance roles in.

---

## 1. Product overview

| | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Product structure | A subscription combining OpenShift Container Platform (restricted-use entitlement), Red Hat OpenShift AI, and Red Hat AI Accelerator entitlements, alongside standalone Red Hat Enterprise Linux AI (RHEL AI) and Red Hat AI Inference Server. | A set of Helm charts ("AI Library" — Ollama, Open WebUI, vLLM, Milvus, Qdrant, OpenSearch, LiteLLM, MLflow, Kubeflow, PyTorch, mcpo) layered on SLES/SLE Micro and Rancher Prime (RKE2). SUSE AI Factory adds a Rancher UI extension and operator for managing these charts as "blueprints." |
| Underlying Kubernetes distribution | OpenShift Container Platform | Rancher Prime: RKE2 |
| First GA date | RHOAI: 2021. Red Hat AI Enterprise as a unified subscription: RHOAI 3.3 (2026). | SUSE AI 1.0: 2024–2025. SUSE AI Factory: first GA (2.0.0) in 2026. |
| Primary dashboard | OpenShift AI dashboard (open source: `opendatahub-io/odh-dashboard`) | Rancher Prime UI extension ("SUSE AI Factory") |

---

## 2. Platform foundation and architecture

| Capability | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Base operating system | RHEL / RHEL CoreOS (immutable) | SLES or SLE Micro (immutable) |
| Multi-cluster management | OpenShift with Advanced Cluster Management | Rancher Prime multi-cluster management and Fleet (GitOps) |
| Intra-cluster multi-tenancy | Namespaces/Projects, RBAC, ResourceQuotas, and Kueue `LocalQueue` for GPU fair-share | Rancher Projects — groups namespaces, propagates resource quotas, and enforces RBAC via `ProjectRoleTemplateBinding`. Both approaches provide comparable namespace/RBAC/quota-based tenancy. |
| AI-specific dashboard scope | The OpenShift AI dashboard provides a unified interface for model catalog, model registry, workbenches, pipelines, distributed workloads, MaaS administration, and Guardrails configuration. | The Rancher Prime UI extension provides discovery, installation, and lifecycle management of AI Library Helm charts and pre-defined blueprints. Per-application configuration (model selection, safety settings, deployment topology) is done through Helm values rather than a unified dashboard workflow. |
| GPU operator support | NVIDIA GPU Operator, AMD GPU Operator, Intel Gaudi driver plugin, plus OpenShift hardware profiles with scheduling and tolerations | NVIDIA GPU Operator (primary, most mature path); AMD GPU Operator documented at the RKE2/SLES layer, with a 2026 joint validation between AMD, SUSE, and Rancher Government Solutions |

---

## 3. Model catalog and governance

| Capability | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Curated model catalog | The OpenShift AI dashboard includes a model catalog with categories for Red Hat AI models and third-party models that Red Hat has benchmarked for performance and quality ("Red Hat AI validated models"), using GuideLLM and the Language Model Evaluation Harness. Benchmark data and model cards are published on Hugging Face and the Red Hat AI Ecosystem Catalog. | SUSE AI Factory with NVIDIA includes an application catalog derived from the NVIDIA GPU Cloud (NGC) catalog, gated on "NVIDIA AI Enterprise Supported" status. This catalogs software components and NVIDIA NIM microservices rather than a benchmarked set of LLM weights. Model selection for Ollama and vLLM blueprints is left to the user. |
| Per-model performance data | The catalog displays cold-start load time, minimum vRAM, container size, tensor-type variants (FP8/INT4/INT8/NVFP4/BF16), and hardware/latency/throughput filtering for validated models. | Not present as a catalog feature in the reviewed documentation. |
| Model registry | Kubeflow Model Registry, integrated into the OpenShift AI dashboard for register/version/promote/deploy workflows. | MLflow (an AI Library Helm chart) provides experiment and model tracking. Kubeflow Model Registry — the same upstream project RHOAI uses — is documented as standalone-installable on any conformant Kubernetes distribution, but is not included in the SUSE AI Library catalog or wired into the AI Factory dashboard. |
| Model support tiers | Published "Validated" and "Enabled" support levels with a version compatibility matrix (vLLM version, minimum platform version, container image path) per model. | No published support-tier matrix for model weights was found in SUSE's documentation. |

---

## 4. Inference serving and distributed inference

| Capability | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Core serving engine | vLLM, distributed as Red Hat AI Inference Server, plus KServe-based `InferenceService`/`LLMInferenceService` custom resources | vLLM (via Helm chart) and Ollama |
| Distributed / disaggregated inference | Distributed Inference with llm-d reached general availability in RHOAI/Red Hat AI Inference 3.5 (August 2026), offering four deployment topologies (single-node, multi-node data-parallel, single-node and multi-node prefill/decode disaggregation) with a dashboard-based topology selector, prefix-cache-aware routing, and KV-cache-aware scheduling. | SUSE's vLLM blueprint is documented as a single-instance, single-node deployment. **llm-d itself is a CNCF Sandbox, vendor-neutral open-source project** (not exclusive to OpenShift) with public Helm charts that run on Kubernetes 1.30+ with a Gateway API implementation — technically installable on RKE2 by a customer with the engineering resources to do so. SUSE does not currently package, test, or document llm-d as part of any SUSE AI product. |
| Single-server appliance option | RHEL AI provides an immutable, bootable image bundling Granite models, InstructLab tooling, and vLLM/llm-d-based inference for single-server deployment. | No directly comparable bootable single-server AI appliance is documented; SUSE AI deployments assume a Kubernetes (RKE2) substrate. |
| Standalone (non-Kubernetes) inference server | Red Hat AI Inference Server can run standalone on RHEL via Podman. | Not offered; SUSE AI's serving path requires Kubernetes. |

---

## 5. Hardware and accelerator support

| Accelerator | Red Hat AI Enterprise (Red Hat AI Inference 3.5) | SUSE AI |
|---|---|---|
| NVIDIA GPU | General availability, with LLM Compressor optimization support | General availability — the primary, most mature path for SUSE AI |
| AMD GPU (ROCm) | General availability (MI210/MI300X/MI325X), with documented optimization paths for KV-cache offload and inference scheduling | Validation announced in 2026 (AMD Instinct MI350P, with Rancher Government Solutions); AMD GPU Operator support documented at the RKE2/SLES layer |
| Intel Gaudi 3 | Technology Preview | Supported at the SLES operating-system driver level (per Intel's own support matrix); no SUSE AI Factory blueprint identified |
| Google TPU | Technology Preview (v4/v5e/v5p/v6e) | Not documented |
| IBM Spyre | General availability on Power/Z, Technology Preview on x86 | Not documented |
| CPU-only inference | General availability | Available via the Ollama CPU blueprint |
| Summary | Red Hat AI Inference 3.5 ships first-party container images for six accelerator families across x86_64, s390x, and ppc64le. | SUSE AI's product-level hardware validation currently centers on NVIDIA, with AMD support recently announced. |

---

## 6. Model customization: fine-tuning and alignment

| Capability | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Distributed training | Kubeflow Training Operator (general availability) with a Training SDK, documented examples for NCCL/DDP/FSDP, and KubeRay for Ray-based distributed compute. | Kubeflow and PyTorch, delivered as AI Library Helm charts, using the same underlying `kubeflow.org` training APIs. |
| Fair-share GPU queuing | Kueue, integrated with RHOAI's distributed-workload tooling. | Not packaged as part of any SUSE AI product; GPU allocation is handled through Kubernetes-native node scheduling. Kueue itself is a Kubernetes SIG Scheduling community project (not Red Hat-originated) designed to run on any conformant Kubernetes cluster, including RKE2. |
| Model alignment / synthetic data generation | InstructLab, originally developed by IBM Research, provides a taxonomy-driven synthetic data generation methodology for teaching models new skills without full retraining. Red Hat AI 3 decomposes this into modular Python libraries (Docling for document ingestion, an SDG framework, a training hub, and an evaluation hub), integrated into the RHOAI dashboard. | No directly comparable packaged methodology was found in SUSE's documentation. The InstructLab CLI itself is open source and installable via `pip install instructlab` on standard Linux systems, independent of RHEL or OpenShift. |
| Automated model selection (AutoML) | Technology Preview: trains and evaluates multiple models from CSV input, ranks results, and generates notebooks. | Not offered. |
| Automated RAG configuration (AutoRAG) | Technology Preview: tests multiple RAG configurations against provided documents, ranks by evaluation metric, and generates notebooks. | Not offered. |

---

## 7. Retrieval-augmented generation, agentic AI, and tool calling

| Capability | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| RAG components | vLLM/llm-d combined with a vector database and orchestration via OGX (Red Hat's productized distribution built on the open-source Llama Stack project, formerly branded "Llama Stack" in RHOAI). | Ollama or vLLM combined with Milvus, Qdrant, OpenSearch, or ChromaDB, and Open WebUI, connected through Helm chart configuration. |
| Agent framework | OGX's Responses API reached general availability in RHOAI 3.5, providing RAG and agentic tool-orchestration with usage telemetry, integrated into the OpenShift AI dashboard. | No dedicated agent framework is packaged; SUSE documentation references Open WebUI's "Pipelines" plugin mechanism and, in the NVIDIA-partnered edition, the NVIDIA NeMo Agent Toolkit. Llama Stack — the open-source project underlying OGX — has its own maintained Kubernetes operator, installable on any conformant Kubernetes cluster, but is not packaged by SUSE. |
| Model Context Protocol (MCP) support | A dashboard-integrated MCP catalog, pre-loaded with servers from Red Hat, partners, and the community, backed by an MCP Lifecycle Operator (Technology Preview) that automates MCP server deployment. | `mcpo`, a Helm-chart-deployed proxy that lets Open WebUI call MCP tools over an OpenAPI interface. No catalog or lifecycle-management UI is documented. |
| Automated agent evaluation | RHOAI 3.5 can automatically generate tool-calling evaluation data from custom MCP servers to validate agent reliability before production. | Not documented. |
| Agent-layer security testing | MiDojo (Developer Preview) intercepts tool-layer communications to test whether agents can be manipulated through compromised tool responses. | Not documented. |

---

## 8. Evaluation, safety guardrails, and red-teaming

| Capability | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Evaluation orchestration | EvalHub (part of TrustyAI) provides a REST/SDK/CLI service for running evaluation jobs across pluggable providers — `lm-evaluation-harness` for accuracy, `guidellm` for performance, and `garak` for security — with results loggable to MLflow. | No dedicated evaluation-orchestration service is documented. The underlying open-source tools (`garak`, `lm-evaluation-harness`, `guidellm`) are freely installable and could be run directly by a customer against their own model endpoint; what EvalHub adds is job scheduling, multi-tenancy, and dashboard/MLflow integration around those same tools. |
| Automated red-teaming | Garak, integrated into EvalHub, reached general availability in RHOAI 3.5 for OWASP LLM Top 10 / AVID / CWE-mapped vulnerability scanning. A Technology Preview "Automated Risk Assessment" pipeline additionally uses synthetic data generation to create adversarial test prompts. | SUSE's documentation references community integration patterns (a Guardrails AI "GreenDoc" pattern for Open WebUI) and a partnership with Infosys ("Responsible AI Suite"). Garak itself is a free, open-source Python package (`pip install garak`) that a customer could run directly. |
| Input/output guardrails | NeMo Guardrails, configured through the OpenShift AI dashboard, with built-in detectors for PII/sensitive data (Presidio), regex patterns, and prompt injection (Hugging Face model, IBM FMS guardrails-detectors). | Achieved through community integration patterns or the Infosys partnership rather than a packaged, first-party component. The core NeMo Guardrails **library** is Apache-2.0 licensed and self-hostable by any customer; NVIDIA's production-grade Guardrails **microservice** (closer to what RHOAI packages) requires an NVIDIA AI Enterprise license, which customers using SUSE AI Factory with NVIDIA may already hold. |
| Prompt-injection protection at the gateway | Available through NeMo Guardrails rails and the MaaS/Connectivity Link policy layer. | SUSE AI Factory's "Simple inference endpoint" blueprint includes optional prompt-injection guardrails alongside authentication and role-based access control, scoped to that specific blueprint. |

---

## 9. Multi-tenant model access and API governance

| Capability | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Multi-tenant model gateway | Models-as-a-Service (MaaS) reached general availability with subscription-based Kubernetes custom resources (`MaaSSubscription`, `MaaSModelRef`, `MaaSAuthPolicy`), enforcement at the network/gateway layer through Red Hat Connectivity Link (built on the open-source Kuadrant project), external OIDC authentication, and both per-model and OpenAI-compatible routing. The underlying controller and CRDs are themselves published as an open-source project, `opendatahub-io/models-as-a-service`. External-model egress to third-party providers (OpenAI, Anthropic, AWS Bedrock, Azure OpenAI, Google Vertex AI) is available as a Technology Preview. | SUSE AI Library includes LiteLLM, an open-source LLM proxy providing Teams, Virtual Keys, per-key and per-team budgets, and rate limits, with database-backed enforcement and native support for both internally hosted models and 100+ external providers. A separate "Simple inference endpoint" AI Factory blueprint provides a more basic gateway with authentication and role-based access control. LiteLLM's tenancy configuration is managed through its own application and database rather than through Kubernetes custom resources, and its multi-organization hierarchy and pre-built rate-limit tiers require a separately licensed LiteLLM Enterprise tier. |
| API gateway / connectivity layer | Red Hat Connectivity Link, a distinct product with its own release notes and support lifecycle, built on Kuadrant. | LiteLLM (see above), primarily oriented around model routing, budgets, and provider abstraction rather than Kubernetes-native policy enforcement. |

---

## 10. MLOps: pipelines, notebooks, registries, and experiment tracking

| Capability | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Managed notebooks | Workbenches with curated container images (PyTorch, CUDA, TrustyAI, and others), integrated storage and data connections. | Kubeflow Notebooks, deployed via Helm chart, with documented hardening and upgrade procedures for production use. |
| Managed pipelines | Data Science Pipelines (built on Kubeflow Pipelines), integrated into the dashboard with versioning and scheduling. | Kubeflow Pipelines, deployed via Helm chart, using the same underlying engine. |
| Experiment tracking | MLflow, deployed via an open-source operator (`opendatahub-io/mlflow-operator`) and a cluster-scoped `MLflow` custom resource. Documented platform integration includes an experiment-tracking view embedded directly in the OpenShift AI dashboard, automatic tracking-URI and RBAC configuration for dashboard-created workbenches (via an `opendatahub.io/mlflow-instance` annotation), the MLflow SDK pre-installed in the workbench image, and a project-scoped `MLflowConfig` resource for per-project artifact-storage overrides. A Red Hat engineer is also documented as an MLflow project maintainer (see Section 15). | MLflow, deployed via a standalone Helm chart with either a Docker or PostgreSQL-backed installation, running its own native MLflow UI. The SUSE documentation reviewed does not describe an embedded dashboard view, automatic workbench credential/RBAC configuration, or project-scoped configuration overrides comparable to the above. |
| Distributed data processing | Kubeflow Spark Operator, with a dedicated integration guide. | Not identified as a distinct AI Library component in SUSE's documentation. |

---

## 11. Observability and monitoring

| Capability | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| AI-specific observability | OpenShift Observe dashboards (including DCGM and vLLM metrics), TrustyAI-based model monitoring, and MaaS usage dashboards. | SUSE Observability is an OpenTelemetry-native platform with more than 40 prebuilt dashboards, a dedicated "GenAI Observability" view tracking token usage, GPU utilization, and prompt/response pairs for drift detection, and AI-assisted root-cause analysis tooling. Independent of the AI-specific comparison, SUSE Observability is a mature, actively developed product in its own right. |

---

## 12. Security, compliance, and supply chain

| Capability | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Runtime security and vulnerability scanning | OpenShift's built-in security controls (Security Context Constraints, image scanning) and Red Hat's CVE/errata advisory process. | SUSE Security (based on NeuVector) provides vulnerability scanning, runtime protection, CIS/compliance reporting, and integrations with SIEM and identity systems (LDAP, SAML, OIDC). |
| FIPS support | Available across the RHEL/OpenShift FIPS mode. | A documented FIPS-compatible path exists for the cert-manager dependency (`cert-manager-fips` chart); broader FIPS compliance across the full SUSE AI stack was not independently verified in the documentation reviewed. |
| Software supply chain transparency | Red Hat errata/CVE advisories and signed container images. | Every component in SUSE AI Factory's NVIDIA edition ships with a Software Bill of Materials (SBOM); the "SUSE Registry" mirrors upstream projects with attached supply-chain provenance artifacts. |
| Data sovereignty positioning | Red Hat AI Enterprise is marketed around a hybrid-cloud, "any hardware, any model, deploy anywhere" model. | SUSE explicitly positions SUSE AI for EU AI Act and data-residency requirements, and partners with Rancher Government Solutions for sovereign and defense deployments. |

---

## 13. Deployment topology: hybrid cloud, disconnected, and edge

| Capability | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Disconnected / air-gapped deployment | A dedicated installation guide for disconnected environments, with mirrored registries and disconnected support for EvalHub/Garak. | A dedicated air-gapped deployment guide for SUSE AI Factory, using an operator-served static catalog and git-backed Fleet bundles so that downstream clusters do not require live access to chart repositories or APIs. Both vendors document mature air-gapped deployment paths. |
| Edge computing | OpenShift supports edge topologies including single-node OpenShift deployments. | SUSE maintains a distinct, longer-established Edge product line (SLE Micro plus Kubernetes for edge use cases) that is broader than AI-specific use cases. |
| Node bring-up automation | OpenShift's installer tooling, including Assisted Installer and IPI/UPI methods; Red Hat also documents Ansible-based automation options for OpenShift and OpenShift AI. | The SUSE AI Node Installer is an Ansible-based, idempotent automation toolkit for bringing up RKE2, Rancher, and NVIDIA GPU drivers/operators across bare metal, virtual machines, and cloud. Both vendors support Ansible-based automation for cluster bring-up. |

---

## 14. Licensing, packaging, and lifecycle support

| Aspect | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Packaging | A single Red Hat AI Enterprise subscription bundles OpenShift Container Platform (restricted-use), OpenShift AI, and AI Accelerator entitlements. | Consumption-based licensing (cores/vCPUs for virtualized deployments, sockets/cores for bare metal), with SUSE AI-specific supplemental terms on top of the base subscription agreement. |
| Cloud marketplace availability | Available on Azure, Google Cloud, and AWS marketplaces, with enterprise discount program credit applicability. | Not detailed for SUSE AI specifically in the documentation reviewed; SUSE's general cloud pay-as-you-go model applies to SLES/Rancher. |
| Support tiers | Red Hat provides production SLA coverage for generally available features; Technology Preview and Developer Preview features are explicitly excluded from production support commitments and are clearly labeled throughout RHOAI documentation. | SUSE offers Standard (12×5) and Priority (24×7) support tiers, plus optional Premium and Sovereign Premium Support. SUSE's lifecycle policy issues service packs every 12–18 months with a 6-month overlap window, and offers optional Long Term Service Pack Support extending coverage 3–5 years. |
| Pre-GA feature labeling | Every non-GA capability in RHOAI documentation (MaaS external models, AutoML, AutoRAG, the MCP Lifecycle Operator, MiDojo, and others) is explicitly flagged as Technology Preview or Developer Preview. | SUSE's documentation does not appear to use an equivalently explicit, product-wide labeling convention distinguishing GA from earlier-stage capabilities across its AI Library Helm charts. |

---

## 15. Open-source project involvement

Both companies build their AI platforms substantially on open-source software, and both contribute to open-source projects. The table below summarizes publicly documented roles (maintainer status, governance seats, or original authorship) in specific projects relevant to each platform, based on each project's own public governance documentation as of September 2026.

| Project | Role documented for Red Hat | Role documented for SUSE |
|---|---|---|
| vLLM (inference engine used by both platforms) | Described by the vLLM project and Red Hat as the leading commercial contributor; multiple Red Hat engineers hold committer/maintainer status with merge rights. vLLM's July 2026 contributor list names more Red Hat engineers (15) than any other single company. | No maintainer or committer role identified in vLLM's public governance documentation. |
| llm-d (distributed inference framework) | Founded by Red Hat, with Google and NVIDIA as founding contributors; now a CNCF Sandbox project. | No contributor or governance role identified. |
| KServe (model-serving framework) | A Red Hat engineer holds one of two Project Lead seats; Red Hat holds 6 of approximately 15 active maintainer/approver/reviewer seats — more than any other single company represented in the project. | No maintainer or contributor role identified. |
| Kubeflow (training, pipelines, notebooks, model registry) | Red Hat holds two seats on the Kubeflow Steering Committee and maintains Kubeflow Pipelines. | SUSE packages Kubeflow as a Helm chart but does not hold a maintainer or governance role identified in Kubeflow's public documentation. |
| MLflow (experiment tracking, used by both platforms — see Section 10) | A Red Hat engineer (Matthew Prahl) is documented as an MLflow maintainer, according to his public GitHub and LinkedIn profiles. | SUSE packages MLflow as a Helm chart but does not hold a maintainer role identified in MLflow's public project documentation. |
| Kuadrant / Authorino (API gateway policy engine underlying Red Hat Connectivity Link and MaaS) | Originally created by Red Hat in 2020; now a CNCF Sandbox project. | Not used or referenced in SUSE AI's documented architecture. |
| TrustyAI (responsible-AI toolkit underlying Guardrails and EvalHub) | Originally authored by Red Hat (open-sourced in 2021, developed jointly with IBM since). | Not used or referenced in SUSE AI's documented architecture. |
| Kueue (GPU fair-share queuing) | Not originated by Red Hat — this is a Kubernetes SIG Scheduling / WG-Batch community project founded primarily by Google engineers. Red Hat is an active contributor and distributes a supported build for OpenShift. | No packaged or documented use identified, though the project is designed to run on any conformant Kubernetes cluster. |
| Kubernetes (container orchestration underlying both platforms) | Red Hat and Google are documented as the two largest all-time contributors to Kubernetes, together accounting for roughly 46% of contributions per the CNCF's Kubernetes Project Journey Report. | No comparably documented contribution volume identified; SUSE consumes and redistributes Kubernetes via RKE2 and Rancher. |
| Rancher / RKE2 (Kubernetes distribution used by SUSE AI) | Not applicable. | SUSE develops and maintains RKE2 and Rancher Prime directly. |
| SUSE Observability | Not applicable. | Developed and maintained directly by SUSE. |

**Why this matters for evaluators**: a company's maintainer or governance role in a given open-source project generally correlates with its ability to influence that project's roadmap or prioritize a specific feature request. This is one input among several (alongside product roadmap commitments, support terms, and reference customers) that an evaluator may want to weigh when assessing which vendor is best positioned to address a specific future requirement.

---

## 16. Summary of capability status by area

This table summarizes each capability area's status for each vendor using consistent terminology, without ranking the platforms overall. **GA** = generally available with production support. **TP/DP** = Technology Preview or Developer Preview (pre-GA, not covered by production support). **Not packaged** = not included as a supported capability in the vendor's product, though the underlying open-source technology may be independently self-installable (see relevant section above for detail). **Comparable** = both vendors offer materially similar capabilities.

| Capability area | Red Hat AI Enterprise | SUSE AI |
|---|---|---|
| Validated, benchmarked model catalog | GA | Not packaged |
| Distributed / disaggregated inference (llm-d) | GA | Not packaged (underlying project is open source and self-installable) |
| Accelerator hardware breadth | GA across 6 families | GA on NVIDIA; AMD support recently announced; others not documented |
| Model alignment / SDG methodology (InstructLab) | GA, dashboard-integrated | Not packaged (underlying CLI is open source) |
| Automated ML / RAG configuration tooling | TP | Not offered |
| Native agentic framework + MCP catalog | GA (agent framework), TP (MCP lifecycle operator) | Not packaged (underlying Llama Stack project is open source) |
| Evaluation orchestration and automated red-teaming | GA orchestration layer; underlying tools also independently open source | Not packaged as a platform service (underlying tools independently open source) |
| Native guardrails framework | GA | Not packaged (underlying library independently open source; production microservice requires separate NVIDIA licensing) |
| Multi-tenant model gateway | GA, Kubernetes-native | Available via LiteLLM (GA, application-layer) and a basic AI Factory blueprint; underlying MaaS project is also open source and self-installable |
| Model registry | GA, dashboard-integrated | Available via MLflow; underlying Kubeflow Model Registry project is independently self-installable |
| AI-specific observability | GA | GA — **Comparable**, and by some measures more extensively developed |
| Air-gapped / disconnected deployment | GA | GA — **Comparable** |
| Edge computing (broader portfolio) | Available | GA — SUSE's Edge portfolio is more established outside the AI-specific product line |
| Ansible-based deployment automation | Available | GA — **Comparable** |
| Company-documented roles in shared upstream projects (vLLM, Kubernetes) | Documented leadership/maintainer roles | No comparably documented roles identified |

---

## Sources

**Red Hat AI Enterprise / RHOAI:**
- [Red Hat AI Enterprise — product page](https://www.redhat.com/en/products/ai/enterprise) · [Introduction to Red Hat AI Enterprise](https://docs.redhat.com/en/documentation/red_hat_ai_enterprise/3/html-single/introduction_to_red_hat_ai_enterprise/introduction_to_red_hat_ai_enterprise)
- [Red Hat AI 3 press release](https://www.redhat.com/en/about/press-releases/red-hat-brings-distributed-ai-inference-production-ai-workloads-red-hat-ai-3) · [Red Hat Enterprise Linux AI](https://www.redhat.com/en/products/ai/enterprise-linux-ai) · [Red Hat OpenShift AI](https://www.redhat.com/en/products/ai/openshift-ai)
- [Validated models by Red Hat AI](https://www.redhat.com/en/products/ai/validated-models) · [Red Hat AI 3 Validated model support matrix](https://docs.redhat.com/en/documentation/red_hat_ai/3/html/validated_models/model-support-matrix_validated-models)
- [Red Hat AI Inference supported accelerators](https://docs.redhat.com/en/documentation/red_hat_ai/3/html/supported_product_and_hardware_configurations/rhaiis-supported-ai-accelerators_supported-configurations) · [llm-d release components](https://access.redhat.com/articles/llm-d_components)
- [MCP catalog documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5/html/working_with_the_mcp_catalog/index) · [RHOAI 3.5 release notes](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5/html/release_notes/new-features-and-enhancements_relnotes)
- [`opendatahub-io/odh-dashboard`](https://github.com/opendatahub-io/odh-dashboard) · [`opendatahub-io/opendatahub-operator`](https://github.com/opendatahub-io/opendatahub-operator) · [`opendatahub-io/models-as-a-service`](https://github.com/opendatahub-io/models-as-a-service)
- Locally mirrored official documentation: `docs/reference/RHAIE 3.5 Guide/` in this repository

**SUSE AI:**
- [SUSE AI 1.0 documentation](https://documentation.suse.com/suse-ai/1.0/) · [SUSE AI architecture](https://documentation.suse.com/suse-ai/1.0/html/AI-intro/ai-intro-how-works.html) · [Deploying and Installing SUSE AI](https://documentation.suse.com/suse-ai/1.0/html/AI-deployment/index.html)
- [SUSE AI Factory documentation](https://documentation.suse.com/suse-ai-factory/latest/html/AI-Factory-introduction/aif-building-blocks.html) · [SUSE AI Factory with NVIDIA](https://www.suse.com/products/ai/factory-with-nvidia/)
- [SUSE Observability](https://www.suse.com/products/rancher/observability/) · [SUSE Security](https://documentation.suse.com/cloudnative/security/5.3/en/integration.html)
- [SUSE subscription terms](https://www.suse.com/products/subscription_terms.pdf) · [SUSE product lifecycle policy](https://www.suse.com/support/policy-products/)

**Third-party open-source project governance and neutral sources:**
- [vLLM committers governance](https://docs.vllm.ai/en/stable/governance/committers/) · [vLLM contributor acknowledgments, July 2026](https://github.com/vllm-project/vllm-project.github.io/blob/main/_posts/2026-07-16-keeping-vllm-production-quality.md)
- [KServe MAINTAINERS.md](https://github.com/kserve/community/blob/main/MAINTAINERS.md) · [Kubeflow community / Steering Committee](https://www.redhat.com/en/blog/open-source-ai-red-hat-our-journey-kubeflow-community) · [Matthew Prahl (Red Hat) — GitHub profile listing MLflow Maintainer](https://github.com/mprahl)
- [Working with MLflow (RHOAI 3.5)](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5/html/working_with_mlflow/installing-mlflow_mlflow) · [Track and compare MLflow experiments in the dashboard (RHOAI 3.5)](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5/html/working_with_mlflow/track-and-compare-mlflow-experiments_mlflow) · [`opendatahub-io/mlflow-operator`](https://github.com/opendatahub-io/mlflow-operator)
- [Kuadrant CNCF Sandbox](https://developers.redhat.com/articles/2024/09/11/kuadrant-joins-cncf-sandbox-project) · [TrustyAI documentation](https://trustyai.org/docs/main/main)
- [Kueue project](https://kueue.sigs.k8s.io/) · [CNCF Kubernetes Project Journey Report](https://www.cncf.io/reports/kubernetes-project-journey-report/)
- [llm-d getting started](https://llm-d.ai/docs/0.7/infrastructure) · [Llama Stack Kubernetes Operator](https://github.com/llamastack/llama-stack-k8s-operator/blob/main/README.md) · [Kubeflow Model Registry standalone install](https://www.kubeflow.org/docs/components/hub/installation/)
- [NVIDIA NeMo Guardrails (Apache-2.0 library)](https://github.com/NVIDIA/NeMo-Guardrails) · [NVIDIA Garak](https://github.com/nvidia/garak) · [LiteLLM multi-tenant architecture](https://docs.litellm.ai/docs/proxy/multi_tenant_architecture) · [InstructLab](https://pypi.org/project/instructlab/)

---

*This document is intended for informational and evaluation purposes. It reflects publicly available vendor documentation as of September 2026 and does not constitute a warranty or guarantee of current feature availability from either vendor. Readers evaluating either platform for a purchasing decision should confirm current specifications, pricing, and support terms directly with Red Hat and SUSE.*
