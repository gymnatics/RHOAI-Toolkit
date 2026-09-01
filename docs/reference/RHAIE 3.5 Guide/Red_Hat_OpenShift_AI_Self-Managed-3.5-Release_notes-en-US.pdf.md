# Red_Hat_OpenShift_AI_Self-Managed-3.5-Release_notes-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Release notes

Features, enhancements, resolved issues, and known issues associated with this release 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Release notes

Features, enhancements, resolved issues, and known issues associated with this release

Legal Notice 

Copyright © Red Hat. 

Except as otherwise noted below, the text of and illustrations in this documentation are licensed by Red Hat under the Creative Commons Attribution–Share Alike 3.0 Unported license . If you distribute this document or an adaptation of it, you must provide the URL for the original version. 

Red Hat, as the licensor of this document, waives the right to enforce, and agrees not to assert, Section 4d of CC-BY-SA to the fullest extent permitted by applicable law. 

Red Hat, the Red Hat logo, JBoss, Hibernate, and RHCE are trademarks or registered trademarks of Red Hat, LLC. or its subsidiaries in the United States and other countries. 

Linux ® is the registered trademark of Linus Torvalds in the United States and other countries. 

XFS is a trademark or registered trademark of Hewlett Packard Enterprise Development LP or its subsidiaries in the United States and other countries. 

The OpenStack ® Word Mark and OpenStack logo are trademarks or registered trademarks of the Linux Foundation, used under license. 

All other trademarks are the property of their respective owners. 

Abstract 

These release notes provide an overview of new features, enhancements, resolved issues, and known issues in version 3.5 of Red Hat OpenShift AI.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

PREFACE 

CHAPTER 1. OPENSHIFT AI 

CHAPTER 2 NEW FEATURES AND ENHANCEMENTS 2.1. NEW FEATURES 2.2. ENHANCEMENTS 

CHAPTER 3 TECHNOLOGY PREVIEW FEATURES 3.1. 3.5 GA TECHNOLOGY PREVIEW FEATURES 3.2. 3.5 EA2 TECHNOLOGY PREVIEW FEATURES 3.3. 3.5 EA1 TECHNOLOGY PREVIEW FEATURES 3.4. 3.4 GA TECHNOLOGY PREVIEW FEATURES 3.5. 3.4 EA2 TECHNOLOGY PREVIEW FEATURES 3.6. 3.4 EA1 TECHNOLOGY PREVIEW FEATURES 

CHAPTER 4 DEVELOPER PREVIEW FEATURES 4.1. 3.5 GA DEVELOPER PREVIEW FEATURES 4.2. 3.5 EA2 DEVELOPER PREVIEW FEATURES 4.3. 3.4 GA DEVELOPER PREVIEW FEATURES 4.4. 3.4 EA2 DEVELOPER PREVIEW FEATURES 4.5. 3.4 EA1 DEVELOPER PREVIEW FEATURES 

CHAPTER 5 SUPPORT REMOVALS 5.1. DEPRECATED 5.2. REMOVED FUNCTIONALITY 

CHAPTER 6 RESOLVED ISSUES 6.1. ISSUES RESOLVED IN RED HAT OPENSHIFT AI 3.5 GA 6.2. ISSUES RESOLVED IN RED HAT OPENSHIFT AI 3.5 EA2 6.3. ISSUES RESOLVED IN RED HAT OPENSHIFT AI 3.5 EA1 

CHAPTER 7 KNOWN ISSUES 7.1. ISSUES DISCOVERED AT VERSION 3.5 GA 7.2. ISSUES DISCOVERED AT VERSION 3.5 EA2 7.3. ISSUES DISCOVERED AT VERSION 3.5 EA1 7.4. ISSUES DISCOVERED AT VERSION 3.4 GA 7.5. ISSUES DISCOVERED AT VERSION 3.4 EA2 7.6. ISSUES DISCOVERED AT VERSION 3.4 EA1 

CHAPTER 8 PRODUCT FEATURES 

3 

4 

5 5 

13 

18 18 

24 27 27 32 33 

41 41 

43 46 48 48 

52 52 55 

60 60 61 61 

63 63 64 67 67 70 71 

73 

### PREFACE

The release notes describe new features and enhancements, Technology Preview and Developer Preview features, support removals, known issues, and resolved issues in Red Hat OpenShift AI. 

### CHAPTER 1. OPENSHIFT AI

Red Hat OpenShift AI is a platform for data scientists and developers of artificial intelligence and machine learning (AI/ML) applications. 

OpenShift AI provides an environment to develop, train, serve, test, and monitor AI/ML models and applications on-premise or in the cloud. 

For data scientists, OpenShift AI includes Jupyter and a collection of default workbench images optimized with the tools and libraries required for model development, and the TensorFlow and PyTorch frameworks. Deploy and host your models, integrate models into external applications, and export models to host them in any hybrid cloud environment. You can enhance your projects on OpenShift AI by building portable machine learning (ML) workflows with AI pipelines by using Docker containers. You can also accelerate your data science experiments through the use of graphics processing units (GPUs) and Intel Gaudi AI accelerators. 

For administrators, OpenShift AI enables data science workloads in an existing Red Hat OpenShift or ROSA environment. Manage users with your existing OpenShift identity provider, and manage the resources available to workbenches to ensure data scientists have what they require to create, train, and host models. Use accelerators to reduce costs and allow your data scientists to enhance the performance of their end-to-end data science workflows using graphics processing units (GPUs) and Intel Gaudi AI accelerators. 

OpenShift AI has a Self-managed software deployment option that you can install on-premise or in the cloud. You can install OpenShift AI Self-Managed in a self-managed environment such as OpenShift Container Platform, or in Red Hat-managed cloud environments such as Red Hat OpenShift Dedicated (with a Customer Cloud Subscription for AWS or GCP), Red Hat OpenShift Service on Amazon Web Services (ROSA classic or ROSA HCP), or Microsoft Azure Red Hat OpenShift. 

For information about OpenShift AI supported software platforms, components, and dependencies, see the Supported Configurations for 3.x  Knowledgebase article. 

For a detailed view of the 3.5 release lifecycle, including the full support phase window, see the Red Hat OpenShift AI Self-Managed Life Cycle Knowledgebase article. 

### CHAPTER 2. NEW FEATURES AND ENHANCEMENTS

Red Hat OpenShift AI 3.5 GA, 3.5 EA2, and 3.5 EA1 include the following new features and enhancements. 

2.1. NEW FEATURES 

3.5 GA new features 

**Migration guide using rhai-cli for upgrading from OpenShift AI 2.25.9 and later to 3.5 **

*A new migration guide, Assess and plan for migration from Red Hat OpenShift AI 2.25.9 (and later) to 3.5, is now available. This guide walks administrators through the pre-upgrade migration assessment ***process by using the rhai-cli command-line tool, including guidance for side-by-side and in-place migration approaches, Kueue management-state prerequisites, and component-specific rhai-cli migrate actions for Kueue/RHBOK, AI Pipelines, Model Serving, Workbenches, TrustyAI, Training, **Llama Stack/OGX, and Ray. The existing 3.3 migration guide remains published for customers migrating to 3.3. This new guide is a parallel edition for customers migrating to OpenShift AI 3.5. 

**After upgrading to 3.5, move away from the support-required-upgrade-3.5 update channel that was **used to trigger the migration. Select an appropriate supported update channel for your environment, **such as stable-3.5, stable-3.x, or eus-3.5, according to your update and lifecycle requirements. **

For information about available update channels and their lifecycle, see Red Hat OpenShift AI Self-Managed Life Cycle. 

External OIDC authentication for Models-as-a-Service 

You can configure Models-as-a-Service to authenticate users with an external OpenID Connect (OIDC) identity provider. This feature enables enterprise-wide access to large language models without requiring OpenShift accounts for every user. Key capabilities include: 

External identity provider integration: As a cluster administrator, you can integrate MaaS with existing identity providers, leveraging your organization’s existing authentication infrastructure. 

OIDC group mapping: As a cluster administrator, you can map external user groups from OIDC group claims to MaaS subscriptions, enabling centralized access control and quota enforcement based on your organization’s existing group structure. 

Seamless user experience: As a user, you authenticate using your existing enterprise credentials and receive API keys scoped to your OIDC group memberships, providing consistent access across your organization’s AI platform. 

Multiple authentication methods: MaaS supports authentication through OpenShift groups and OIDC token claims, allowing you to choose the authentication method that best fits your deployment model. External OIDC authentication enables organizations to integrate MaaS into existing identity and access management workflows while maintaining self-service access for data scientists and developers. 

For more information, see Governing LLM access with Models-as-a-Service . 

EvalHub general availability for the Red Hat AI evaluation stack 

EvalHub is generally available (GA). EvalHub provides an enterprise-ready evaluation orchestration service for AI systems, including models, AI applications, agents, tools, and AI vulnerability assessment and scanning. This release includes a documented API versioning scheme, an established breaking change policy, and full Red Hat support, enabling you to use EvalHub in regulated or production environments. This release also includes must-gather tooling for troubleshooting. 

EvalHub client SDK and CLI 

OpenShift AI includes the EvalHub client SDK and command-line interface (CLI). The EvalHub SDK provides a Python client library and CLI for integrating evaluation workflows into development environments, automation pipelines, and notebook-based experimentation. This introduces the following capabilities: 

Python client library (eval-hub-sdk) for programmatic interaction with the EvalHub REST API, including job submission, provider discovery, and result retrieval 

CLI utilities through the evalhub command for submitting evaluation jobs, checking job status, retrieving results, and managing evaluation collections from the terminal 

Support for both synchronous and asynchronous evaluation workflows 

Authentication support for API keys and service accounts 

Adapter SDK for writing custom evaluation framework adapters **Install the client library with the pip install "eval-hub-sdk[client]" command, to include CLI support run pip install "eval-hub-sdk[cli]" and run pip install eval-hub-sdk to install only **the minimum required for writing an EvalHub adapter using the Adapter SDK. 

Support for deploying Red Hat AI Inference fast release container images as a custom serving runtime 

You can deploy Red Hat AI Inference fast release container images as custom serving runtimes on your existing Red Hat OpenShift AI installation without upgrading Red Hat OpenShift AI. This enables access to the latest vLLM versions and new model support between Red Hat OpenShift AI **stable releases. To deploy a fast release image, create a ServingRuntime resource and an LLMInferenceServiceConfig manifest that reference the Red Hat AI Inference fast container **image. Red Hat AI Inference fast images from the next version cycle are validated against the current Red Hat OpenShift AI stable release. For more information about the Red Hat AI Inference fast and stable release cadence, see the Red Hat AI Inference release notes. 

Adversarial vulnerability scanning for Red Hat-validated models 

New models added to the Red Hat AI validated models catalog now undergo automated adversarial vulnerability scanning as part of the validation process. This extends the existing validation pipeline with a behavioral security assessment of each model. The scans use garak, an open-source LLM vulnerability scanner, to probe each model’s responses against a broad range of adversarial attack patterns. 

Scans are run by the Red Hat model validation team by using Red Hat EvalHub. EvalHub provides a consistent, repeatable validation methodology across newly validated models. The resulting quantitative vulnerability scores are published with each model entry in the Hugging Face catalog, alongside existing accuracy and performance data. 

Vulnerability scores provide quantitative insight into a model’s security posture, supporting model selection and providing input to internal model risk management and AI security review processes. 

EvalCard generation for evaluation runs 

In OpenShift AI, you can generate standardized Evaluation Cards (EvalCards) for every evaluation run in EvalHub. When you specify an MLflow experiment or OCI export configuration in the evaluation job request, a post-processing step in the EvalHub runtime automatically generates a schema-validated JSON card that captures metadata, results, provenance, and pass/fail outcomes. This card is stored as an MLflow run artifact or OCI artifact, depending on the request. EvalCard generation optionally integrates with OCI Model Cards to provide comprehensive AI system documentation. 

**SparkApplication batch engine for Feast Feature Store **

**Feast Feature Store supports a SparkApplication batch engine. You can run feature **transformations on your own Apache Spark clusters managed by the Kubeflow Spark Operator. You **can configure batch_engine.type: spark_application in your featurestore.yaml to submit materialization jobs as SparkApplication custom resources for distributed batch materialization and **Spark user-defined function (UDF) execution in feature views. This capability supports enterprise retrieval-augmented generation (RAG) pipelines by providing batch document embedding at scale through Spark, with materialization to both offline and online feature stores including vector-enabled stores such as Milvus. **For more information, see SparkApplication batch engine in Feature Store **. 

EvalHub server local development mode 

You can run the EvalHub Server in a local development mode on macOS, Linux, and Windows **workstations. By installing the server as a cross-platform Python wheel (pip install "eval-hub-sdk[server]"), you can complete the full Evaluation-Driven Development (EDD) loop locally without **requiring a Kubernetes or OpenShift cluster. This capability enables you to submit evaluation jobs, monitor progress, retrieve structured results, and generate evaluation reports directly on your laptop. Evaluation results, reports, and Environment Cards are managed locally across your workstation services, allowing you to iterate quickly and securely before moving your configurations to production infrastructure. 

DiffusionGemma (dLLM) model support 

You can deploy DiffusionGemma models for inference. DiffusionGemma is a 26B discrete diffusion large language model (dLLM) based on the Gemma 4 backbone. It is the first discrete diffusion LLM supported for model serving with KServe in OpenShift AI. 

GPU-accelerated runtime for predictive machine learning 

**A new MLServer GPU container image and corresponding cluster serving runtime (mlserver-onnx-gpu) are available to support NVIDIA GPU-accelerated inference for predictive machine learning **workloads. By utilizing a dedicated GPU runtime, you can achieve predictable, low-latency inference under high concurrency with improved scalability for multi-stream or batched workloads. GPU allocation is managed through hardware profiles. This dedicated image ensures that heavy CUDA payloads are not unnecessarily downloaded on CPU-only clusters and prevents unexpected fallbacks to CPU inference. The existing CPU MLServer runtime remains unchanged and available for CPU-based deployments. 

Automated Red Teaming 

Automated Red Teaming is generally available (GA). Automated Red Teaming (powered by Garak) helps you proactively discover model vulnerabilities and safety risks. This release introduces support for OpenAI Responses API endpoints, multilingual red teaming with LLM-based translations, multiclass judge safety evaluation, and parallelized execution across generators, detectors, and translators for faster scans. Additionally, Automated Red Teaming is supported in disconnected (airgapped) environments and runs directly through EvalHub or standalone Kubeflow Pipelines (KFP). 

Kueue workload scheduling visibility in the workbenches overview 

When Kueue manages workload scheduling in a project, the workbenches overview page displays Kueue-derived scheduling states for each workbench. You can view states such as Queued, Starting, Preempted, Evicted, and Requeued, with human-readable messages that explain the current scheduling status. If you have RBAC access to the Kueue Visibility API, you can see your queue position for pending workloads. The startup progress modal uses a tree-based view that shows per-container startup steps and a Kueue admission sub-step. 

This release includes the following capabilities: 

Kueue scheduling states displayed in the Status column on the Workbenches tab 

Queue position display for pending workloads 

Redesigned startup progress modal with per-container startup detail 

Project-level indicator confirming when a project uses queue-based scheduling 

Anomaly warning for workbenches that bypass Kueue in a Kueue-managed namespace 

**Hardware profile LocalQueue name validation and Kueue-aware hardware profile drop-**down list filtering For more information, see View workbench scheduling status . 

Custom role creation UI for data science projects 

Project administrators can create, edit, and duplicate custom RBAC roles for workbenches directly from the Roles tab in data science projects, without requiring CLI access or YAML expertise. The OpenShift AI dashboard provides a form-based interface for selecting API groups, resource types, and verbs, along with built-in role templates for common workbench access patterns: Workbench maintainer, Workbench reader, and Workbench updater. You can preview the resulting Kubernetes **Role YAML before submitting by using the Form/YAML toggle. Roles created through the dashboard automatically receive the opendatahub.io/dashboard: 'true' label. The roleManagement flag is enabled by default in OpenShift AI 3.5. For more information, see Create a **custom role in the dashboard. 

MLflow integration for AI Pipelines and training environments 

MLflow is fully integrated to provide centralized machine learning (ML) lifecycle management. You can track experiments, parameters, metrics, and artifacts directly within your primary workspace, reducing context switching. This feature embeds MLflow tracking capabilities into AI Pipelines, workbenches, the Kubeflow SDK, Kubeflow Trainer, and AI Hub components. When you run a training job, whether through a pipeline or directly using the SDK in a workbench, your experiment runs are automatically tracked and logged by a dedicated MLflow server instance accessible within your project. This centralized visibility allows you to easily compare different runs and make informed decisions about model performance. 

Inference-aware pod lifecycle for Distributed Inference with llm-d 

You can perform routine deployment operations, such as rolling updates, scale-downs, and node maintenance, without dropping active inference requests. With inference-aware pod lifecycle management, the system safely transitions pods and prevents routing traffic to instances that are still loading model weights. This ensures uninterrupted service during scaling and maintenance activities. 

Distributed Inference with llm-d on cross-Kubernetes platforms 

Distributed Inference with llm-d is generally available on Azure Kubernetes Service (AKS), CoreWeave Kubernetes Service (CKS), and OpenShift. This release supports multi-model serving, intelligent inference scheduling, and disaggregated serving to improve GPU utilization for generative AI models. Additionally, Distributed Inference with llm-d includes Istio as the supported gateway implementation and features the Gateway API Inference Extension (GAIE). Both of these components are fully supported as part of the solution. 

Priority-based flow control for mixed Distributed Inference with llm-d workloads 

Flow control for Distributed Inference with llm-d is generally available. Platform Operators can define **priority tiers using InferenceObjective resources, configure saturation detection, and apply per-**band queuing policies to ensure that latency-sensitive interactive requests are served ahead of throughput-oriented batch traffic. Multiple workload profiles can share a single Distributed Inference with llm-d deployment without requiring dedicated GPU pools per priority level. Additionally, flow control features starvation protection through holdback policies, per-band capacity limits, and sheddable request eviction. If you configured flow control during the Technology Preview in Red Hat OpenShift AI 3.4, note the following breaking changes: 

**The API group has changed from inference.networking.x-k8s.io to llm-d.ai. You must update all InferenceObjective and EndpointPickerConfig resources. **

**The metrics prefix has changed from inference_extension_ to llm_d_epp_. You must **update any applicable Prometheus dashboards, alerts, or Grafana panels. 

**The saturation detector configuration has moved from a top-level saturationDetector field to flowControl.saturationDetector, and it now uses a plugin-reference pattern. **

Controlled deployment for Distributed Inference with llm-d 

With this update, you can use controlled deployment with Distributed Inference with llm-d to validate engine upgrades, model version rotations, and configuration changes on a fraction of production traffic before a full promotion. You can deploy two or more versions of an inference workload side-by-side on the same model endpoint, control the traffic distribution using declarative, weight-based traffic splitting, and compare per-version Prometheus metrics in real time. Active requests complete without disruption during promotions and rollbacks. For more information, see Validate inference workload changes with controlled deployment . 

Observability reference dashboards for Distributed Inference with llm-d using Perses 

You can monitor Distributed Inference with llm-d deployments by using reference dashboards delivered through Perses and the Cluster Observability Operator. These dashboards provide a health overview and a structured drill-down path from cluster-level signals to specific models, phases, or underlying failures. 

Multimodal input support for Distributed Inference with llm-d 

Platform Operators serving multimodal models benefit from prefix cache-aware routing that accounts for image, audio, and video content. The scheduler routes multimodal requests to pods that already hold relevant KV cache entries, reducing redundant prefill computation and improving time to first token. 

End-to-end distributed tracing for Distributed Inference with llm-d 

Distributed Inference with llm-d supports end-to-end distributed tracing across the full inference request path. Platform Operators can correlate latency and identify errors across service boundaries using OpenTelemetry-compatible traces. 

User-request header routing for external OGX providers 

You can pass specific user-request headers to external OGX (formerly Llama Stack) providers. Previously, only built-in providers could access these headers, which prevented external providers from receiving dynamic, per-user tokens. With this update, you can configure a declarative mapping that assigns specific headers to specific providers. This feature ensures that providers receive necessary information, such as dynamic tokens for guardrails or model-as-a-service (MaaS) integrations, while restricting access to unmapped headers to prevent data contamination and token leakage. 

Existing Kubernetes Secrets as workbench environment variables 

You can reference pre-existing Kubernetes Secrets as environment variables when creating or editing a workbench. In the Environment variables section of the workbench form, select Existing secret as the variable type to reference a secret that is already present in the project namespace. The Existing secret option targets secrets managed outside Red Hat OpenShift AI by platform teams or external tools such as External Secrets Operator, HashiCorp Vault, or ArgoCD. You can select one or more secrets from a searchable dropdown, then choose to inject all keys or specific keys from each secret. Secret values are never displayed in the dashboard. The workbench form detects and warns about duplicate environment variable key names across secrets and connections, helping you identify potential conflicts before starting the workbench. Only Kubernetes Secrets of **type Opaque that are not managed by the connections framework appear in the dropdown. **Referencing existing ConfigMaps is not supported in this release. For more information, see Environment variable types for workbenches. 

GPU topology and utilization dashboard 

In OpenShift AI, a new Infrastructure page provides platform administrators with an integrated view of accelerator cluster health. The page displays summary cards for total accelerator count, compute utilization, and memory utilization. It also includes a Kueue cohort overview showing GPU usage versus effective pool and workload counts, a hardware inventory chart grouped by accelerator model, and borrowing and lending trends across cluster queues. The page is available to cluster administrators when Kueue is enabled and uses NVIDIA DCGM metrics for utilization data. 

Automated generation of tool-calling evaluation data for custom MCP servers 

You can automatically generate tool-calling evaluation benchmark data from custom Model Context Protocol (MCP) servers. This feature introduces an automated pipeline that actively explores MCP servers to discover real data and behaviors, rather than just reading schemas. It generates question-answer-tool-call triplets with verified ground truth, supporting both single tool calls and complex, multi-step tool chaining. The output is compatible with standard evaluation frameworks, allowing you to validate the accuracy of fine-tuned models and the reliability of agentic systems on your proprietary tool ecosystems before production deployment. This automation eliminates the need to manually create evaluation data and provides objective metrics for model validation. 

KubeRay operator upgraded to version 1.6.x 

The KubeRay operator is upgraded to version 1.6.x. This update aligns OpenShift AI with upstream **KubeRay capabilities and includes various stability improvements. Your existing RayCluster and RayJob workloads remain fully supported and will continue to function normally after the upgrade **without requiring changes. 

Support for Hosted Control Planes on OpenShift Virtualization 

You can deploy OpenShift AI on Hosted Control Planes (HCP) running on OpenShift Virtualization. This officially supported configuration enables a multi-tenant architecture, allowing you to efficiently 

share resources across different tenants or customers. For more information, see Supported configurations. 

Automated prompt optimization for agentic systems 

You can automate the optimization of prompts for your agentic systems by using Training Hub. By providing a seed prompt and an evaluation dataset, the automated workflow systematically evolves and optimizes prompts using evolutionary search and LLM-driven reflection. This capability replaces manual, trial-and-error prompt engineering, allowing you to achieve production-quality agent performance without modifying model weights. The optimization process provides visibility into how specific prompt elements affect performance across iterations, and it is compatible with both hosted and self-hosted models. For more information about Training Hub, see Train the model by using your prepared data . 

Per-tenant EvalHub deployment 

Namespace administrators can deploy a dedicated EvalHub instance in their own namespace without **cluster administrator or OpenShift AI administrator involvement. Set spec.tenancy: single in the **EvalHub custom resource to deploy a per-tenant instance. The TrustyAI Operator automatically provisions all required RBAC resources, including Roles, ServiceAccounts, and RoleBindings. Namespace administrators can also define tenant-scoped evaluation providers and collections by **creating labeled ConfigMap resources in the instance namespace. Tenant-scoped configurations **appear alongside system configurations and do not affect other tenants or the shared system configuration. 

NOTE 

The shared multi-tenant deployment mode remains the recommended approach for most organizations. Existing shared and per-tenant EvalHub deployments continue to function without disruption after an Operator upgrade. 

Integration of Training Hub in Ray for distributed fine-tuning 

**You can use Training Hub fine-tuning algorithms on Ray clusters. The training-hub Python package **and its supporting dependencies are pre-installed in the Ray CUDA Training Hub runtime image, so you can run algorithms such as Supervised Fine-Tuning (SFT), Orthogonal Subspace Fine-Tuning (OSFT), LoRA, and Group Relative Policy Optimization (GRPO) on Ray without installing dependencies at runtime. You create and manage Ray clusters with the CodeFlare SDK and submit Training Hub jobs as Ray jobs. Pre-installation of the Training Hub package in the runtime image also enables use in disconnected (air-gapped) environments. 

Automatic Prometheus monitoring integration for EvalHub on OpenShift 

**The TrustyAI Service Operator automatically creates a ServiceMonitor resource when EvalHub is deployed with metrics enabled. Previously, the EvalHub /metrics endpoint was not scraped by the OpenShift platform Prometheus instance because a ServiceMonitor was not created. With this **release, EvalHub metrics are discovered and scraped by the OpenShift platform monitoring stack **without manual configuration, and the ServiceMonitor lifecycle is fully managed alongside the **EvalHub deployment. 

NeMo Guardrails support on IBM Z 

NeMo Guardrails is supported on IBM Z (s390x). With this enhancement, you can deploy and use NeMo Guardrails to add safety controls and conversation policies to models running on IBM Z platforms in Red Hat OpenShift AI. 

3.5 EA2 new features 

Responses API on OGX 

The Responses API is generally available on OGX. The Responses API is OpenAI-compatible, which allows you to reuse existing OpenAI SDKs, tools, and workflows directly in your cluster environment **without changing the client. The providers are enabled by default in the runtime config.yaml file. **You can view examples of Responses API usage in the "OpenAI-compatible APIs in OGX" documentation. 

Support for customizing OAuth proxy sidecar resource allocation via the DataScienceCluster API 

Administrators can configure OAuth proxy sidecar resource requests and limits directly in the **DataScienceCluster CR under spec.components.kserve.oauthProxy.resources, without changing any component state from Managed to Unmanaged. You can explicitly set the fields to override the **defaults. The default value persists when you omit the field. Before this update, adjusting OAuth proxy sidecar CPU and memory for KServe InferenceServices **required manually editing the inferenceservice-config ConfigMap and setting opendatahub.io/managed: "false" to prevent the Operator from overwriting the changes. This **unmanaged state meant configuration mistakes were not corrected by reconciliation, risking production stability, and required manual intervention during upgrades. 

Safety and Security Insights tab in the Red Hat AI Model Catalog 

The Red Hat AI Model Catalog includes a new Safety and Security Insights tab that displays AI security evaluation results for each model. The tab shows security scan results organized by category, including safety testing and security testing. These results cover risk vectors such as prompt injection, jailbreak resistance, and harmful content generation. As a result, you can evaluate a model’s security posture directly from the catalog without conducting independent security evaluations. To access the Safety and Security Insights tab, open the Red Hat AI Model Catalog, select a model, and click the Safety and security insights tab on the model detail page. 

Cold-start load time and vRAM metrics in the model catalog 

The model catalog displays operational metrics for validated models, including cold-start load time, minimum vRAM requirements, and the runtime command used for benchmarking. Cold-start load time and runtime commands are shown per GPU configuration in the Performance Insights tab, while minimum vRAM and container size are displayed in the Model Details section. You can filter and sort models by cold-start load time to identify models that meet specific startup latency requirements, and filter by minimum vRAM and container size. The cold-start load time metric measures only the vLLM model load phase after weights are downloaded and copied into the container, not the full end-to-end startup time. 

Self-service Subscriptions tab for Models-as-a-Service users 

With this update, you can view your Models-as-a-Service subscription assignments, browse associated models, and check token rate limits from the Subscriptions tab on the API keys page in Gen AI studio. You can toggle between a subscription-grouped view and a model-grouped view, expand rows to see details, search by name, and sort alphabetically. You can also click an individual subscription to view its details, including the models available, their token rate limits, and any API keys you have for that subscription. 

For more information, see View your Models-as-a-Service subscriptions . 

MLflow, AutoML, AutoRAG, and OGX enhancements on IBM Power 

Red Hat OpenShift AI extends support for MLflow, AutoML, AutoRAG, the GenAI playground, **milvus-lite, and the OGX ecosystem to the IBM Power architecture. **

3.5 EA1 new features 

Support for OGX and KubeRay on IBM Power 

Red Hat OpenShift AI 3.5 EA1 introduces official support for both OGX (which replaces Llama Stack) and KubeRay on the IBM Power architecture. 

Task Shortcuts section added to the dashboard homepage 

The Red Hat OpenShift AI dashboard homepage includes a Task Shortcuts section. This enhancement provides direct entry points to key platform workflows. Tasks are organized by capability groups, such as AI Hub, Gen AI Studio, and Develop & Train. From these groups, you can directly access common tasks, such as deploying models, managing API keys, or launching workbenches. 

ROCm TensorFlow workbench image defaults to Red Hat Python index 

Workbench and runtime images default to the Red Hat Python index. In addition to the existing packages, the ROCm TensorFlow notebook image is pulled from the Red Hat Python index rather than PyPI when you install or update Python packages. 

2.2. ENHANCEMENTS 

3.5 GA enhancements 

Canary rollout support for KServe RawDeployment mode 

**In OpenShift AI, you can perform canary rollouts for KServe InferenceService deployments in RawDeployment mode. This feature enables progressive model version rollouts by splitting traffic between the primary deployment and a canary deployment within the same InferenceService resource. Traffic routing is managed via OpenShift Route alternateBackends or Gateway API **HTTPRoute weighted backends, reducing production risk and eliminating the need to manually manage parallel services. Note that canary deployments run with a fixed number of replicas and do not support autoscaling (HPA/KEDA). 

Observability dashboards installed by default for Distributed Inference with llm-d 

Distributed Inference with llm-d includes observability dashboards installed by default in the **OpenShift web console. When Distributed Inference with llm-d is deployed, dashboard ConfigMap **objects are automatically created in the cluster, providing Platform Operators with out-of-the-box visibility into model server metrics such as KV-cache utilization, request queue depth, time to first token (TTFT), and throughput. Endpoint Picker (EPP) scheduler metrics and workload variant autoscaler (WVA) metrics are also included. The dashboards require User Workload Monitoring to be enabled. 

Non-cluster administrator access and embeddable Perses-based dashboards 

In OpenShift AI, non-cluster administrators, such as data scientists, can access Perses-based metrics dashboards scoped to their authorized namespaces. Previously, these dashboards were restricted to cluster administrators. In addition, this update refines the dashboard contribution pattern into a production-ready workflow, allowing component teams to safely contribute Perses dashboards and embed these metrics directly within their feature pages. 

View the vLLM version for distributed inference deployments 

When using distributed inference with Distributed Inference with llm-d, platform administrators can 

view the version of vLLM that is running directly from the OpenShift AI dashboard. This information helps administrators quickly assess model compatibility, determine which vLLM features are available, and identify potential exposure to known Common Vulnerabilities and Exposures (CVEs). 

Option to disable TLS within Distributed Inference with llm-d deployments 

**Platform Operators can disable built-in TLS on LLMInferenceService workload pods by setting spec.tls.enabled: false in the LLMInferenceServiceConfig custom resource. This allows **environments that use a service mesh, such as Istio, for mutual TLS (mTLS) to avoid redundant double encryption across router, prefill, and decode hops. TLS remains enabled by default. Disabling built-in TLS requires an alternative transport encryption mechanism to be in place. 

2025.2 workbench and pipeline runtime images retained for transition 

Red Hat OpenShift AI 3.5 retains the 2025.2 workbench and pipeline runtime images alongside the new images that default to the Red Hat Python index. In the dashboard workbench creation flow, 2025.2 workbench images remain selectable but are marked as outdated and not recommended. In JupyterLab, the corresponding 2025.2 pipeline runtime images for Data Science, Minimal, PyTorch, PyTorch LLM Compressor, TensorFlow, and ROCm variants are still available for pipeline nodes. The 2025.2 images are supported on both fresh 3.5 installations and upgrades from 3.4, including disconnected environments. This transition period allows you to validate your existing workflows against the new images before you migrate. 

Enhancements to Distributed Inference with llm-d EndPoint Picker scheduler configuration 

**The OpenShift AI 3.4 default scheduler configuration used two scorer plugins, queue-scorer (weight: 2) and prefix-cache-scorer (weight: 3). OpenShift AI 3.5 adds two additional scorers ( kv-cache-utilization-scorer and no-hit-lru-scorer) to improve performance by optimizing KV cache **reuse across replicas and ensuring more balanced usage patterns when prefix cache hits are not available. 

Service-level SLI metrics for Distributed Inference with llm-d 

You can monitor end-to-end inference performance from the user’s perspective by using servicelevel Prometheus histogram metrics exposed by the Endpoint Picker in Distributed Inference with llm-d deployments. Unlike pod-level vLLM metrics, these metrics include scheduler queue wait time and network latency. The metrics include time to first token (TTFT), time per output token (TPOT), and inter-token latency (ITL) for streaming requests, and support P90 and P99 percentile calculations for SLO compliance dashboards and alerting. 

Targeted vLLM access-log filtering for LLMInferenceService 

**The default LLMInferenceServiceConfig templates switch from the blanket --disable-uvicorn-access-log to vLLM 0.16’s --disable-access-log-for-endpoints /health,/metrics,/ping with a **runtime fallback to the old flag on vLLM below 0.16. The blanket flag added in OpenShift AI 3.4 to stop the EPP scheduler’s 200 ms /metrics scrape from flooding pod logs also silenced access logs for legitimate inference traffic, so operators lost visibility into real API usage. The targeted flag suppresses only the noisy health, metrics, and ping endpoints while keeping inference logging. In **OpenShift AI 3.5, vLLM access logs show inference requests, such as /v1/completions and /v1/chat/completions, by default again, while /health, /metrics, and /ping stay quiet. Pre-0.16 vLLM **images keep the old blanket behavior via the version fallback, so existing deployments need no action. The filtered endpoint list is customizable. 

Feature store and workbench bidirectional visibility 

You can view connections between feature stores and workbenches directly in the OpenShift AI web console. Previously, verifying these connections required running notebook code or manually inspecting Kubernetes resources. The dashboard shows connected workbenches on the feature 

store details page and displays feature store connections on the workbench details page. Additionally, the workbench creation dialog includes permission-filtered feature store discovery. This UI-driven feature enables self-service connection verification and simplifies troubleshooting. 

Hiding default workbench images 

Administrators can hide out-of-the-box workbench images from the image selection drop-down list. By navigating to the Settings → Notebook images page in the OpenShift AI web console, you can use a toggle to show or hide these default images. This feature prevents users from selecting images that are incompatible with the cluster’s hardware, such as selecting a ROCm image on an NVIDIA-only cluster or a CUDA image on a CPU-only cluster. Hiding incompatible images reduces the risk of failed workbench launches and simplifies the user experience. 

Telemetry collection for OGX API adoption metrics 

Telemetry data collection is introduced for OGX (formerly Llama Stack) API usage. This feature collects aggregated, quantitative metrics about API, Retrieval-Augmented Generation (RAG), and agentic activity to help Red Hat guide future product improvements. This telemetry data is collected through the standard OpenShift cluster telemetry system and is enabled by default. You can opt out of this data collection by using the standard cluster-level telemetry configuration or by disabling the **OGX_TELEMETRY_ENABLED variable. Disconnected (air-gapped) clusters do not participate in **this telemetry collection. 

PVC as a storage source for EvalHub evaluation test data 

**You can use a PersistentVolumeClaim (PVC) as a storage source for custom test data in EvalHub evaluation jobs. When you specify a PVC in the test_data_ref field of a benchmark configuration, EvalHub mounts the PVC read-only at /test_data inside the evaluation job pod. The adapter reads **the data directly from that path without an init container or S3 credentials. **You can specify a sub_path to mount a specific subdirectory within the PVC, for example, when a **single PVC contains data for multiple benchmarks. 

For more information, see Provide evaluation test data from a PVC . 

MLflow-compatible agent connectors for Synthetic Data Generation (SDG) Hub 

The Synthetic Data Generation (SDG) Hub features MLflow-compatible agent connectors. This update standardizes the SDG Hub programmatic interface within pipeline components to use **MLflow’s ChatAgentRequest and ChatAgentResponse types as the canonical input and output **formats. As a result, you can connect SDG Hub workflows to any MLflow-compatible agent framework, observability tooling, or evaluation platform in the AgentOps ecosystem without creating custom translation layers. Existing SDG Hub flow configurations maintain backward compatibility and continue to function without modification. 

CPU-only support for AutoRAG deployments 

AutoRAG optimization supports CPU-only infrastructure, enabling you to evaluate Retrieval-Augmented Generation (RAG) pipelines without requiring GPU resources. This capability relies on lightweight foundation and embedding models optimized for CPU inference. Supported embedding **models include nomic-embed-text-v1.5 and BAAI/bge-m3. Supported foundation models include Phi-4-mini-instruct, Qwen3.5-4B-Instruct, Qwen2.5-3B-Instruct, and Llama-3.2-3B-Instruct. **

Training Hub RLVR and GRPO dependencies in universal workbench images 

The universal workbench image includes all dependencies required for Reinforcement Learning from Verifiable Rewards (RLVR) and Group Relative Policy Optimization (GRPO) training workflows. These dependencies, provided by Training Hub, ensure out-of-the-box compatibility on CUDA 

backends, with ROCm and CPU image variants also available. With this update, you can immediately begin developing and experimenting with single-GPU GRPO (using Kubeflow TrainJob) without manual dependency installation or environment setup. Multi-GPU distributed GRPO (using KubeRay RayJob) can also be achieved with the new Training Hub Ray runtime image, allowing you to immediately begin developing without manual dependency installation or environment setup. 

For more information, see the guided examples for GRPO with Trainer and GRPO with Ray. 

Trace archival support for MLflow at scale 

You can use age-based trace archival for MLflow to manage large volumes of trace data. A background archival process automatically migrates trace payloads from the PostgreSQL tracking database to S3-compatible object storage after a configurable retention period. Trace metadata remains in PostgreSQL to ensure searchability, while archived traces are retrieved transparently through the existing MLflow API and user interface. This tiered storage approach allows you to control storage costs and maintain database performance without deleting historical data. 

Guided tours for the OpenShift AI dashboard 

A new guided tour system is available in the dashboard. A "Welcome to OpenShift AI 3.5" tour automatically launches on your first visit after an upgrade. This tour dynamically adapts its steps based on the features enabled or disabled on your cluster, and it provides role-aware messaging tailored to administrative or non-administrative users. You can manually relaunch this tour at any time from the dashboard masthead. 

Ability to self-manage ClusterQueues and LocalQueues 

**In OpenShift AI, you can self-manage ClusterQueue and LocalQueue resources for your data **science projects. A new boolean flag in the Kueue component specification of the **DataScienceCluster custom resource (CR) controls whether the Operator automatically creates **default queue resources. This flag is disabled by default, meaning the operator skips all automatic queue resource creation. This allows administrators to manage queues entirely through OpenShift GitOps or other external tooling without interference from the operator. Additionally, you can still **associate HardwareProfile resources of type Queue with these externally managed LocalQueue **resources. 

OpenAI-compatible body-based model routing for Models-as-a-Service 

**You can send inference requests to the standard OpenAI /v1/chat/completions endpoint with the **model name in the request body, and MaaS applies subscription, rate-limiting, and authorization policies automatically. This enables drop-in compatibility with OpenAI-compatible SDKs and clients **such as the Python openai library, LangChain, LlamaIndex, and OpenWebUI without requiring **custom URL paths or non-standard headers. Legacy path-based routing remains supported for backward compatibility. For more information, see Models-as-a-Service API overview . 

Unified MaaS governance page for subscriptions and authorization policies 

This enhancement combines the Subscriptions and Authorization policies pages in Settings into a single MaaS governance page, accessible from Settings → MaaS governance. The unified page uses a tabbed layout with Subscriptions and Authorization policies tabs, allowing administrators to manage both resources from one location. The subscription and authorization policy tables include expandable rows for the Groups and Models columns. You can click these columns to view group names, model names, and token limits inline. For more information, see View subscriptions and View authorization policies. 

Code Interpreter flow for synthetic Python code generation 

In OpenShift AI, SDG Hub includes a Code Interpreter flow for synthetic Python code generation. You can automatically validate whether generated Python code runs successfully, ensuring that training data sets do not contain broken code samples. By automating the verification of synthetic code, you can generate high-quality, validated data sets for fine-tuning small language models (SLMs) and building domain-specific coding assistants without relying on manual review. 

Distributed Inference with llm-d tokenizer runs as a dedicated external service 

The Distributed Inference with llm-d tokenizer runs as a dedicated external service, which requires it to run on an amd64 node. The previous Distributed Inference with llm-d tokenizer, which ran with the EndpointPicker, could run on either an amd64 node or an ARM node. Running the tokenizer requires more resources now than in previous versions. 

Inference scheduler routing logic and scorer weight configuration 

Platform operators can configure the routing logic used by the inference scheduler and tune scorer weights to optimize for specific workloads. This enhancement provides greater control over how inference requests are evaluated and routed to available model server replicas. 

### CHAPTER 3. TECHNOLOGY PREVIEW FEATURES

IMPORTANT 

This section describes Technology Preview features in Red Hat OpenShift AI 3.5 GA, 3.5 EA2, and 3.5 EA1. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

3.1. 3.5 GA TECHNOLOGY PREVIEW FEATURES 

MCP gateway Operator as an external dependency for MCP management workflows 

The MCP gateway Operator is an optional external prerequisite for OpenShift AI MCP management workflows, including agentic AI workflows, that route agent tool calls through a governed protocol gateway layer. The MCP gateway Operator must be installed, configured, and upgraded independently from the OpenShift AI operator lifecycle. Cluster administrators are responsible for its full lifecycle management. 

Unified dashboard experience for generative AI model deployment workflows 

Generative AI model deployment workflows are in a unified dashboard experience, replacing separate entry points for different model serving runtimes with a single guided wizard. Previous versions of OpenShift AI required users to choose between separate UI workflows for different model serving runtimes: Legacy single-model serving, LLM-D distributed inference, and vLLM on Models-as-a-Service. This separation created confusion about which workflow to use for specific model types and required users to understand the underlying runtime differences before deploying models. There is a single Deploy model entry point for all generative AI models. When you select Generative AI or Distributed inference with llm-d from the model framework list, the wizard guides you through the following: 

Selecting a deployment topology appropriate for your model size and hardware constraints 

Configuring hardware profiles and accelerator resources (for single-node deployments) 

Optionally applying advanced routing configurations for production workloads 

Deploying the model with validated configuration templates This approach replaces manual YAML editing with template-based deployment, reducing errors and enabling self-service deployment for data scientists who do not have deep Kubernetes expertise. 

Default vector store for GenAI Studio 

**GenAI Studio includes a default PostgreSQL vector store with the pgvector extension enabled for **playground Retrieval-Augmented Generation (RAG) workflows. This enhancement provides an out-of-the-box vector storage solution for development and experimentation, replacing the previous inline vector store provider. You can test and experiment with RAG workflows directly in the GenAI Studio playground without needing to manually provision or configure an external vector database. 

Enhanced trained model insights for AutoML 

AutoML tabular and time-series pipelines generate and persist detailed evaluation artifacts to S3-compatible object storage. Additionally, the AutoML dashboard plugin includes new visualizations for these artifacts, such as receiver operating characteristic (ROC) curves, precision-recall curves, and time-series backtesting results (predictions versus actuals). This enables you to evaluate threshold trade-offs, compare experiments, and validate model performance characteristics beyond basic aggregate metrics. 

Model Context Protocol (MCP) Lifecycle Operator 

The Model Context Protocol (MCP) Lifecycle Operator is available as a Technology Preview feature. This Kubernetes-native operator provides the runtime infrastructure necessary to deploy, configure, and manage MCP servers. It is automatically deployed during a standard OpenShift AI installation, enabling the MCP Catalog to deploy and serve MCP servers end-to-end. The MCP Lifecycle Operator forms the foundation of the platform’s agentic AI capabilities by allowing organizations to safely connect AI agents to external tools and data. 

MCP Catalog support tier labeling 

The Model Context Protocol (MCP) Catalog in Red Hat OpenShift AI displays explicit support tier labels for server entries, allowing you to easily identify official support commitments before deployment. Support tiers are rendered directly in the MCP dashboard using accessible, visually distinct badges for the following categories: 

Red Hat Supported: Indicates the MCP server is fully validated and backed by Red Hat support commitments. 

Partner Supported: Indicates the MCP server is provided and supported by an Independent Software Vendor (ISV) partner, offering clear attribution while distinguishing it from native Red Hat support obligations. 

Community Supported: Indicates the MCP server is a community-contributed entry with no official Red Hat support commitment. 

Ray 2.55.1 runtime images for distributed workloads 

New Ray 2.55.1 runtime images are included in Distributed Workloads. These images serve as the **default runtime images for RayCluster resources created using the CodeFlare SDK. **

DP-aware load balancing for Distributed Inference with llm-d WideEP deployments 

**You can run WideEP multi-rank inference with a single vllm serve command, enabling the **Distributed Inference with llm-d Endpoint Picker to route requests to individual data-parallel (DP) ranks for prefix-cache-aware scheduling. The external multi-port DP mode provides one serving port per local rank for this routing. Additionally, the DP Supervisor starts these local ranks and exposes **aggregated /health and /readyz endpoints on a separate admin port for Kubernetes probes, **eliminating the need for custom shell wrappers. This routing method can deliver up to 26-30% higher throughput compared to hybrid load balancing. Known limitations in this Technology Preview feature include: no partial-rank degradation if a single DP rank fails, no elastic EP scaling at runtime, and no support for gRPC transport. 

For more information, see Launch a WideEP inference service with rank-aware routing . 

API surface full-stack passthrough for tool calling in Distributed Inference with llm-d 

Tool calling parameters pass through the full Distributed Inference with llm-d serving stack without modification. Tool definitions, tool choice settings, structured output schemas, and **parallel_tool_calls in the request reach the model server unaltered through all layers of the serving **

stack, including the Gateway, Endpoint Picker, and the routing sidecar for disaggregated deployments. Additionally, tool call response objects and streaming tool call deltas are preserved on the return path. This passthrough behavior applies to all Distributed Inference with llm-d deployment configurations, whether disaggregated or non-disaggregated. Non-tool-calling requests experience no impact on latency or throughput. 

Multimodal support in the Gen AI Studio playground 

The Gen AI Studio playground supports multimodal interactions, allowing you to experiment with models that process text, images, and audio. You can upload images for visual analysis, capture audio using your microphone, upload audio files, and play back speech generated by models directly in the playground. This feature enables you to mix text, images, and audio within a single conversational flow or provide multiple images in sequence for iterative reasoning. With multimodal support, you can explore complex workflows like document analysis and object recognition, and even combine multimodal inputs when comparing different models. 

Inference-aware scheduling for Distributed Inference with llm-d on Amazon EKS 

Platform Operators can deploy Distributed Inference with llm-d on Amazon Elastic Kubernetes Service (EKS) with inference-aware scheduling as a Technology Preview. Requests are routed based on real-time pod state and cache availability, matching the scheduling behavior available on OpenShift and AKS. 

EKS platform support for Distributed Inference with llm-d 

Platform Operators can deploy and operate Distributed Inference with llm-d on Amazon EKS as a Technology Preview, using the same installation paths, observability, and tooling as on other validated Kubernetes platforms. 

MaaS multi-tenancy with per-tenant gateway and identity isolation 

Platform administrators can provision isolated tenants for Models-as-a-Service by using a single custom resource. The controller automatically creates the tenant namespace, deploys the pertenant API service, and configures authentication and rate-limit policies. The gateway and identity provider are external prerequisites that must exist before tenant creation. All controller-managed resources are cleaned up on deletion, with the namespace preserved to protect user data. Tenant users cannot discover or access models, API keys, or usage data belonging to other tenants. Multi-tenancy supports long-lived API keys scoped to tenant identity, Bring Your Own Identity Provider configuration, per-tenant rate limits and quotas via subscriptions, and an access grant mechanism for exposing shared foundation models to specific tenants. 

AutoGluon serving runtime 

Red Hat OpenShift AI includes AutoGluon as a pre-configured serving runtime for deploying **AutoML models as a Technology Preview. You can deploy AutoGluon TabularPredictor models for **regression, classification, and time series forecasting by selecting AutoGluon from the runtime dropdown in the dashboard, eliminating the need for manual YAML configuration. The runtime supports standard KServe inference protocols with REST API access and can load models from S3, Google Cloud Storage, or Azure Blob Storage. 

Multi-provider API passthrough for Models-as-a-Service external models 

You can route inference requests through the Models-as-a-Service (MaaS) gateway using native **provider API formats—such as the Anthropic Messages API at /v1/messages or the OpenAI Responses API at /v1/responses—without format translation. When the client API format matches the external model’s configured apiFormat, the gateway forwards the requests unchanged. This **preserves provider-specific features, such as prompt caching and extended thinking. For direct 

Anthropic providers, beta flags are also preserved; however, for Vertex AI providers, beta headers and unsupported body fields are stripped. Additionally, AI coding tools can connect to a single MaaS gateway URL and switch between models mid-session using body-based model routing. For more information, see Multi-provider API passthrough for external models . 

Autoscaling support for Ray distributed workloads 

You can enable cluster autoscaling for your Ray distributed workloads. Previously, network connectivity issues prevented the autoscaler sidecar from communicating with the Ray head pod due to missing TLS certificates. This update automatically injects the necessary client certificates into the sidecar container, allowing the underlying OpenShift worker pods in the Ray cluster to dynamically scale up or down based on workload demand. This eliminates the need for manual configuration edits and ensures efficient resource utilization. This feature supports standard Ray cluster autoscaling; autoscaling with the Red Hat build of Kueue is not currently supported. 

Chat metrics and observability tracing in Gen AI Studio 

You can view real-time chat-level metrics and execution traces directly within the Gen AI Studio Playground. This Technology Preview feature introduces an inline metrics panel that displays key performance indicators for each chat instance, including time to first token (TTFT), tokens per second, total token usage, payload sizes, and estimated costs. Additionally, the update embeds the MLflow trace UI within Gen AI Studio to provide a call-tree visualization. This allows you to deeply trace interactions across models, Model Context Protocol (MCP) servers, knowledge sources (RAG), and guardrails, making it easier to identify performance bottlenecks and evaluate the efficiency of different AI workflow configurations. 

Global prompt registry namespaces in Gen AI Studio playground 

You can browse, load, and iterate on organization-curated prompts from global registry namespaces in the Gen AI Studio playground. Platform administrators choose shared MLflow prompt registry **namespaces in the OdhDashboardConfig custom resource. Users with access can browse global **prompts alongside their project prompts, with scope indicators showing each prompt’s source namespace. When you change a global prompt, you can use Save As to create a personal copy in your local project namespace. 

For more information about configuring global prompt registry namespaces, see Configure global prompt registry namespaces. For more information about using global prompts in the playground, see Reusable system instructions. 

Interactive Spark job management in workbenches 

You can interactively manage and execute PySpark workloads directly from your workbenches using the Kube-native Spark Operator (KSO). This integration enables you to run PySpark code inline within a notebook, providing instant outputs for interactive development. You can submit, run, analyze job logs, and clean up KSO-managed jobs entirely from within your IDE environment. Additionally, this update allows you to connect multiple workbenches or users to the same active Spark cluster, streamlining collaborative data processing and model training workflows. 

Kueue support for the Kubeflow Spark Operator 

**SparkApplication workloads managed by the Kubeflow Spark Operator (KSO) can be admitted and **scheduled through Kueue. You can apply cluster and local queue quotas so that driver and executor pods respect fair sharing, gang scheduling, and multi-tenant resource limits. 

Monitoring Spark jobs with the Spark Application UI and History Server 

You can monitor Spark jobs submitted with the Kubeflow Spark Operator by using the Spark Application UI through OpenShift routes or port forwarding. For completed jobs, you can configure the Spark History Server with S3-compatible storage or persistent volumes to access execution history, logs, and performance metrics for troubleshooting and analysis. 

OpenCode coding agent deployment and operation 

You can deploy and operate OpenCode, an open-source, terminal-based coding agent. OpenCode is the first coding agent validated to follow the onboarding pattern established by OpenClaw. This update confirms that agent platform operators, vLLM and OGX (formerly Llama Stack) inference backends, and MLflow tracing integration successfully generalize to coding-specific workloads. This validation provides supported container images, operator-managed deployment manifests, verified inference backend interoperability, and MLflow tracing integration for running OpenCode on your OpenShift AI deployments. 

AutoML experimentation visibility and transparency 

You can view detailed AutoML experimentation data directly in the dashboard. This update surfaces the exploration process, allowing you to see which algorithms were tried, their associated hyperparameters, performance metrics, and the reasons specific configurations were eliminated. By providing a comprehensive experiment history view, this feature enables you to understand the decision-making process, learn from the experiments, and effectively debug unexpected results, rather than only seeing the final model recommendation. 

AutoRAG visual pipeline representation for experimentation 

The AutoRAG user interface includes a visual pipeline representation of the experimentation process. You can view each evaluated Retrieval-Augmented Generation (RAG) pattern as an interactive directed graph that displays pipeline stages, such as chunking, embedding, retrieval, reranking, and generation. This visualization enables you to drill down into node-level parameters and intermediate results, compare multiple pipeline architectures side-by-side, and better understand why specific configurations were selected or rejected. 

OpenTelemetry metrics export for EvalHub 

You can export EvalHub operational metrics to OpenTelemetry Protocol (OTLP)-compatible observability backends using gRPC or HTTP transport. OTLP metrics export is available as a Technology Preview feature. To enable metrics export, set enableMetrics to true in the otel section of the EvalHub custom resource. Metrics are exported at a configurable interval that you set in OTEL_METRIC_EXPORT_INTERVAL environment variable in the EvalHub custom resource spec.env field. Default value is 60 seconds. 

If you enable both OTLP and Prometheus, EvalHub sends metrics to the configured OTLP backend and the Prometheus /metrics endpoint simultaneously. 

You can export the following HTTP metrics in EvalHub: 

**http_requests_total **

**http_request_duration_seconds **

**http_requests_in_flight **

Each metric includes Kubernetes resource attributes (service.name, k8s.namespace.name, k8s.pod.name, and k8s.node.name) to support multi-tenant filtering in your observability backend. When OTEL metrics export is not configured, only the existing Prometheus metrics are available, with no change to current behavior. 

+ NOTE: You must deploy an OTLP-compatible collector, such as the OpenTelemetry Collector, in your cluster. EvalHub does not include a collector. The collector endpoint is shared between traces **and metrics through the existing exporterEndpoint field in the otel configuration. **

Verify connection credentials before saving 

You can verify that connection credentials are valid and the endpoint is reachable before saving a connection. When adding or editing a connection in a project, click Verify connection to check the configuration. The Connections tab also displays a Status column showing the verification result for each connection. Connection verification supports S3-compatible object storage, URI, and OCI-compliant registry connection types. This feature is available as a Technology Preview. 

View external model endpoints in the dashboard 

You can view registered external model endpoints and their associated provider details from the OpenShift AI dashboard. Navigate to AI hub → Models and select the External models tab on the **Model deployments page to see all ExternalModel resources in the selected project, including **name, provider, and reconciliation status. You can expand each row to view associated **ExternalProvider resources with connection details such as provider URL, authentication method, **API format, and routing weight. **To enable this feature, set spec.dashboardConfig.externalModels to true in the OdhDashboardConfig custom resource. For more information, see About external models for **Models-as-a-Service. 

AWS Security Token Service (STS) authentication for AWS Bedrock 

You can use AWS Security Token Service (STS) authentication with the AWS Bedrock inference provider. This enhancement allows you to authenticate by using temporary security credentials rather than relying on long-lived API keys, enabling organizations to comply with enterprise security policies. 

Multi-lingual support for AutoRAG 

AutoRAG includes multi-lingual capabilities, allowing you to discover optimal Retrieval-Augmented Generation (RAG) patterns for non-English and mixed-language document corpora. This enhancement introduces language detection and configuration within AutoRAG experiments, language-aware chunking strategies for non-English scripts, such as CJK, Cyrillic, and Latin, and multi-lingual embedding models in the optimization search space. These capabilities enable you to support global enterprise use cases that operate across language boundaries. 

EvalHub job execution log access via HTTP API and CLI 

In OpenShift AI, you can access evaluation job execution logs directly through the EvalHub HTTP **API and the evalhub CLI. This feature is available as a Technology Preview. By using the evalhub eval logs <job_id> command, you can inspect logs for jobs in any state, including running, **completed, failed, or canceled, without requiring direct Kubernetes cluster access or tooling. The API and EvalHub CLI support full log retrieval, log streaming for in-progress jobs, tailing the last specified number of lines, and formatted JSON output. This simplifies troubleshooting and enables automated CI/CD pipelines to retrieve failure details directly. 

NOTE 

You cannot retrieve logs if the pod has been deleted. 

Cross-namespace shared workspace access for curated resources 

You can access curated resources, starting with prompts in GenAI Studio, from a designated global 

workspace. This capability allows organizations to distribute standard, vetted prompt templates across teams without duplicating them in individual namespaces. Administrators can designate a **global shared namespace by configuring the spec.globalMLflowNamespace field in the OdhDashboardConfig custom resource. Access is managed through standard Kubernetes role-**based access control (RBAC), providing a centralized, shared prompt library experience across the platform. 

Structural contextualization support for AutoRAG 

In OpenShift AI, AutoRAG supports structural contextualization (LLM contextual enrichment) during document chunking. When enabled in your AutoRAG pipeline, chunks are automatically prepended with model-generated contextual descriptions grounded in the full source document before embedding and indexing. AutoRAG evaluates these enriched configurations alongside existing chunking and retrieval strategies to select the optimal pattern, improving retrieval precision and answer relevance without requiring custom external preprocessing pipelines. 

Loki-based showback and user-scoped dashboards for Models-as-a-Service 

Models-as-a-Service (MaaS) includes a Loki-based structured log pipeline for showback data in addition to the existing metrics-based dashboard. The Loki-based pipeline provides 30-day retention on object storage to better support monthly billing cycles. This enhancement also provides user-scoped, read-only dashboards with data isolation. Users, including administrators, can view only their own MaaS usage data, while administrators can continue to use the existing platform-wide dashboard for broader usage monitoring. 

3.2. 3.5 EA2 TECHNOLOGY PREVIEW FEATURES 

Side-by-side evaluation run comparison in EvalHub 

You can compare two or more completed evaluation runs side by side in the OpenShift AI dashboard. This Technology Preview feature enables you to select runs from the evaluations list, initiate a comparison, and view metrics and parameters for all selected runs in an embedded MLflow comparison view. The comparison workflow supports the following capabilities: 

Select any two or more completed evaluation runs from the Evaluations page, regardless of the benchmarks used. 

For runs that used benchmark suites, choose specific benchmarks to include in the comparison. 

View side-by-side parameters and metrics in the MLflow comparison view, including visualizations such as parallel coordinates and contour plots. 

Share comparison results with team members by using the comparison view URL. Comparison is artifact-agnostic: you can compare runs that evaluated models, RAG pipeline configurations, agentic AI systems, prompt templates, or any other AI artifact that EvalHub supports. 

For more information, see Compare evaluation runs in the OpenShift AI dashboard . 

**OGX Server custom resource definition (CRD) runtime updates **

**OpenShift AI 3.5EA2 introduces enhancements to the OGX Server CRD by natively exposing runtime configuration fields. Previously, users had to manually manage config.yaml templates with **custom ConfigMaps. Users can optionally add their custom config through CRD. The users still have 

an option to use their custom configmap. 

NeMo Guardrails integration with MCP Gateway for agent tool-call enforcement 

You can integrate NeMo Guardrails with the MCP Gateway to enforce guardrails on agent tool calls at the gateway layer. This integration protects against PII leakage, prompt injection, and content safety violations for traffic that flows through the MCP Gateway, without requiring you to implement guardrails individually in each agent application. You can deploy NeMo Guardrails in a standalone server for MCP Gateway integration, without the full TrustyAI observability and explainability stack. **To configure the integration, add the mcpGateway field to the NemoGuardrails custom resource with the name and namespace of the target MCPGatewayExtension resource. The TrustyAI operator automatically discovers the MCP Gateway and BBR plugin, then provisions an EnvoyFilter **for server-sent events (SSE) to JSON conversion to enable guardrail processing. For more information, see NeMo Guardrails integration with MCP Gateway for agent tool-call enforcement . 

Validated tool-calling configuration for models in the model catalog 

The model catalog displays validated vLLM deployment arguments for models with confirmed toolcalling support. Models that have been validated for tool calling display a Validated Arguments section on the Model Details page, where you can expand the Tool Calling panel to view and copy the **exact vllm serve CLI arguments required for tool calling, including --tool-call-parser, --reasoning-parser, --chat-template, and --enable-auto-tool-choice. You can also use the Validated Arguments **filter to narrow the catalog to models with confirmed tool-calling support. **To enable this feature, set spec.dashboardConfig.toolCalling to true in the OdhDashboardConfig custom resource. **

Multi-tenancy support in OGX 

OGX supports multi-tenancy, allowing teams to share infrastructure while isolating data and access. You can configure a single-server or multi-server environment based on your team’s resource needs. For more information, see the "Deploying OGX for multi-tenancy" documentation in the "Building Agentic/AI applications with OGX" section. 

GPU-accelerated Docling SDK container image for batch document processing 

**Red Hat OpenShift AI provides the docling-sdk-cuda-ubi9 container image for GPU-accelerated **document conversion using the Docling SDK 2.88.0 with NVIDIA CUDA 13.0 support. The image includes all required dependencies for fully disconnected operation: PyTorch 2.12, Tesseract OCR, and pre-bundled machine learning models. The following models are pre-bundled: 

Heron: Layout detection 

TableFormer: Table structure recognition 

Picture classification model 

GraniteDocling: GPU-accelerated VLM conversion 

Granite Vision 4.0 3B: Chart extraction 

RapidOCR: Optical character recognition The image does not include a predefined entry point, allowing Kubeflow Pipelines to provide its own command when using it as a base image. This design supports flexible integration with batch document processing workflows in air-gapped environments. 

Docling Serve API container image for on-demand document conversion 

**Red Hat OpenShift AI provides the docling-serve-cuda-ubi9 container image, which offers a REST **API for on-demand document conversion, chunking, and GPU-accelerated parsing. The image is **built as a thin layer on top of docling-sdk-cuda-ubi9, inheriting all machine learning models, **dependencies, and CUDA GPU acceleration capabilities. When you run the container, the docling-serve API server starts on port 5001. You can submit documents through HTTP requests and receive converted output in formats like Markdown or Docling Doc JSON. This image enables real-time document processing workflows with GPU acceleration for applications that require on-demand conversion rather than batch processing. 

Batch inference with the OpenAI-compatible Batches API in llm-d 

Distributed Inference with llm-d supports batch inference through the OpenAI-compatible **/v1/batches API. You can submit large volumes of requests asynchronously and retrieve results on **your own schedule without maintaining an active connection. The scheduler runs batch workloads during periods of low cluster activity at a lower priority than real-time traffic, so that real-time requests retain scheduling priority. 

Prompt management with template variables in Gen AI Studio 

You can save, version, and reuse system instructions as named prompts in Gen AI Studio. Prompts are stored in the MLflow prompt registry and scoped to your project, so any team member can browse and load them. **Prompts can have {{variable}} placeholders that are filled with specific values before inference. **When you load a prompt that has placeholders, the playground displays an input panel where you enter values. 

Kueue support in EvalHub for evaluation job scheduling 

You can route EvalHub evaluation jobs through Red Hat build of Kueue LocalQueues by specifying a queue name when creating an evaluation job. This integration provides fair resource sharing, quota management, priority-based scheduling, and queue-based admission control across evaluation workloads. If Red Hat build of Kueue is not installed on your cluster, evaluation jobs use the default Kubernetes scheduler without requiring changes to your job submission logic. 

For more information, see EvalHub Kueue integration overview . 

EvalHub MCP server for AI coding agents 

The EvalHub Model Context Protocol (MCP) server is available as a Technology Preview. It enables compatible AI coding agents to discover benchmarks, submit evaluations, and monitor evaluation jobs in EvalHub. 

The MCP server includes tools for discovering evaluation providers and for submitting, monitoring, and canceling evaluation jobs. It also includes guided prompts for model evaluation, evaluation-run comparison, and evaluation-driven development workflows. 

**You can deploy the MCP server by adding an mcp configuration to the EvalHub custom resource that **the TrustyAI Operator manages. For more information, see Deploy the EvalHub MCP server . 

Thresholds support in evaluation runs in the OpenShift AI dashboard 

EvalHub introduces threshold configuration in evaluation runs as a Technology Preview. You can set pass or fail thresholds when submitting evaluation jobs through the OpenShift AI dashboard. You can define minimum acceptable performance scores for your model evaluations, making it easier to validate whether your models meet quality requirements before deployment. 

You can set thresholds for both individual benchmarks and benchmark suites by using an intuitive slider **control or by entering a numeric value between 0 and 100. This value is equivalent to the 0.0-1.0 **threshold used in the API. 

Depending on benchmarks, the default threshold values differ. 

For instructions on how to set thresholds when submitting evaluation jobs, see Submit an evaluation job using the OpenShift AI dashboard. 

3.3. 3.5 EA1 TECHNOLOGY PREVIEW FEATURES 

NeMo Guardrails in Gen AI Studio 

Red Hat OpenShift AI 3.5 EA1 updates the guardrails experience in the Gen AI Studio playground. Guardrails are powered by NeMo Guardrails, providing more reliable and consistent safety checks for model interactions. You can independently control guardrails for user input and model output directly from the playground settings: 

User input guardrails: Protects against jailbreak and prompt attacks, PII in user messages, and harmful content including toxicity, hate speech, and harassment. 

Model output guardrails: Filters model responses for PII, harmful content, and hallucinations before delivery to the user. 

Renaming of Llama Stack to OGX 

Starting in OpenShift AI 3.5 EA1, Llama Stack and its associated variables and configurations are renamed to OGX. All existing configuration examples have been updated to reflect this change. Manual migration is required to use OpenShift AI 3.5 EA1 with the OGX Operator. For more information, see the "Llama Stack to OGX migration" documentation. 

Conversations API on OGX 

The OpenAI Conversations API is available on OGX. This development tool allows you to build context-aware, multi-turn AI applications. Key capabilities of the Conversations API include: 

Session memory: Maintains chat history to support multi-turn interactions. 

State management: Handles conversation states and context. 

3.4. 3.4 GA TECHNOLOGY PREVIEW FEATURES 

Workload variant autoscaler for Distributed Inference with llm-d model deployments 

Platform Operators can enable autoscaling for Distributed Inference with llm-d model deployments based on incoming request volume as a Technology Preview. Scaling decisions use inference request metrics as the signal, so replicas respond to actual demand. 

Model Cache for faster inference startup 

You can pre-download and cache large language model (LLM) artifacts on node-local Non-Volatile **Memory Express (NVMe) storage to reduce InferenceService cold-start latency. When a model **serving pod starts on a node with a cached model copy, the pod mounts the local copy instead of downloading from remote storage, which makes autoscaling practical for latency-sensitive workloads. 

**A cluster administrator enables model caching through the DataScienceCluster custom resource **and configures target nodes and storage capacity. Model Cache supports both cluster-scoped **caching, where any InferenceService in any namespace can use the cached model, and namespace-**scoped caching for namespace-level isolation. For more information, see Model cache for faster inference startup. 

Gateway discovery for llm-d deployments 

You can discover and select an existing Kubernetes Gateway resource from the model serving UI when deploying LLMInferenceService models. This Technology Preview feature enables self-service Gateway management, supports multitenant namespace-scoped network isolation, and provides programmatic access through the Gateway discovery REST API. Gateway discovery and creation is disabled by default and must be explicitly enabled by a cluster administrator through the dashboard configuration. 

vLLM runtime support for Models-as-a-Service 

You can deploy models using the vLLM runtime through Models-as-a-Service (MaaS). This Technology Preview feature enables you to serve large language models with vLLM’s highperformance inference capabilities while benefiting from MaaS governance and subscription-based controls. Key capabilities include: 

vLLM deployment from the dashboard: As a cluster administrator, you can enable vLLM **runtime support for MaaS by setting the vLLMDeploymentOnMaaS feature flag in the OdhDashboardConfig custom resource. Once enabled, you can deploy models using vLLM **runtime directly from the Models-as-a-Service interface. 

Performance optimization: vLLM provides optimized inference performance for large language models through features such as continuous batching, PagedAttention, and efficient memory management, improving throughput and reducing latency for model serving workloads. 

Subscription-based governance: As a cluster administrator, you can apply the same subscription-based access controls, token quotas, and authorization policies to vLLMserved models as you do for other MaaS models, maintaining consistent governance across different serving runtimes. 

Unified user experience: As a user, you access vLLM-served models through the same OpenAI-compatible API endpoints and authentication methods as other MaaS models, providing a seamless experience regardless of the underlying serving runtime. vLLM runtime support for Models-as-a-Service enables organizations to use highperformance inference capabilities while maintaining centralized governance and cost control. 

For more information, see Governing LLM access with Models-as-a-Service . 

Models-as-a-Service observability dashboard 

As a cluster administrator, you can monitor platform-wide Models-as-a-Service (MaaS) usage through a dedicated observability dashboard embedded in the OpenShift AI console. This Technology Preview feature provides comprehensive usage metrics for cost attribution and showback reporting to finance teams. Key capabilities include: 

Subscription-level metrics: View total tokens consumed, total requests, error counts, and success rates across all subscriptions, or drill down to specific subscriptions for detailed analysis 

Token consumption tracking: Track token usage by user, subscription, and model, with detailed tables showing request counts and rate limit violations for cost allocation and capacity planning 

Filtering and time ranges: Filter metrics by user, subscription, and model to analyze specific usage patterns. View metrics for configurable time periods ranging from the last 5 minutes to the last 14 days, or specify custom date ranges 

CSV export: Export usage data in CSV format for integration with external metering, billing, and financial reporting systems 

Prometheus metrics integration: The dashboard queries Prometheus metrics collected from Kuadrant and MaaS components, providing real-time visibility into platform health and resource consumption 

For more information, see Governing LLM access with Models-as-a-Service . 

External model egress via inference gateway 

You can route model inference requests to external model providers through the Models-as-a-Service (MaaS) inference gateway. This Technology Preview feature enables you to apply MaaS governance policies, token tracking, and rate limiting to third-party LLM services such as OpenAI, Anthropic, or other external providers. Key capabilities include: 

External model configuration: As a cluster administrator, you can define external LLM provider configurations using the ExternalModel custom resource, specifying the provider endpoint, authentication method, and model identifiers. 

Unified governance: As a cluster administrator, you can apply the same subscription-based access controls, authorization policies, and token quotas to external models as you do for models served within the cluster. 

Centralized usage tracking: As a cluster administrator, you can monitor token consumption and request metrics for external models alongside internally-served models in the observability dashboard, providing a unified view of LLM usage across your organization. 

Consistent API interface: As a user, you access external models through the same OpenAI-compatible API endpoints and authentication methods as internally-served models, providing a seamless experience regardless of where models are hosted. External model egress enables organizations to maintain centralized governance and cost visibility when using external LLM providers while preserving flexibility for teams to leverage best-in-class models from multiple sources. 

For more information, see Governing LLM access with Models-as-a-Service . 

Automate machine learning model training with AutoML 

AutoML is available as a Technology Preview feature in Red Hat OpenShift AI 3.5. You can use AutoML to train and compare machine learning models for your data. AutoML provides a dashboard UI to configure optimization runs, compare models on a leaderboard, generate notebooks for 

running models, and register a model for deployment. For more information, see Working with AutoML. 

Automate RAG optimization with AutoRAG 

AutoRAG is available as a Technology Preview feature in Red Hat OpenShift AI 3.4. You can use AutoRAG to find the best retrieval-augmented generation (RAG) configuration for your documents and use case. AutoRAG provides a dashboard UI to configure optimization runs, evaluate RAG patterns on a leaderboard, and generate notebooks to run patterns. For more information, see Working with AutoRAG. 

Recommended vLLM runtime configurations in model catalog 

Red Hat OpenShift AI provides recommended vLLM runtime configurations for select high-demand models. These configurations are designed to help users achieve maximum performance on specific hardware profiles, matching or exceeding industry benchmarks for low-latency and high-throughput serving. Previously, users had to manually tune vLLM arguments to find the sweet spot for performance. Validated YAML templates are embedded directly in the model card Readme section as markdown, serving as a reference for manual configuration. 

Key features of this update include: 

Optimal performance recipes: Validated configurations optimized for specific hardware (initially NVIDIA H200) and workload profiles (8K prefill / 1K generation). 

Structured YAML metadata: Recommended settings include specific environment variables and CLI arguments verified by the Red Hat Performance and Scale (PSAP) team. 

Model card integration: No UI changes are required. Optimized recipes are appended to the model’s Readme field for easy discovery. 

Performance parity: These configurations ensure OpenShift AI performance remains competitive with alternative serving stacks by leveraging the latest vLLM optimizations. Initial targeted models: 

GPT-OSS 120B: Optimized for major enterprise usage. 

Llama 3-70B: Validated for standard high-performance deployments. 

DeepSeek R1: Provided as a showcase for advanced reasoning and Red Hat Summit demonstrations. To find the optimal runtime settings for a supported model: 

1. In the OpenShift AI dashboard, navigate to AI hub → Catalog. 

2. Select one of the supported models, for example, GPT-OSS 120B. 

3. On the model card, scroll to the readme section. 

4. Locate the Recommended Configurations YAML block. During this Technology Preview phase, you can manually apply these recommendations during the model deployment workflow: 

5. Copy the CLI arguments and environment variables from the model card YAML template. 

6. Initiate the Deploy workflow for the model. 

7. In the Serving Runtime configuration, add the copied CLI arguments to the Additional Service Arguments field. 

8. Add the recommended environment variables to the deployment configuration. 

Technical details and scope: 

Hardware profile: The initial set of recipes is specifically tuned for NVIDIA H200 GPUs. 

Workload profile: Configurations are optimized for Online Serving (balancing latency and throughput) with a single profile of 8K prefill / 1K generation. 

Validation: Every configuration has undergone accuracy and performance testing by the Red Hat Model Validation and PSAP teams. 

NOTE 

This Technology Preview feature is intended for feedback collection. Future releases will include UI enhancements such as one-click application of these presets and automated hardware detection. 

Artifact signing and verification for model registry 

Model registry provides cryptographic signing and verification of AI artifacts by using the Python client API. This Technology Preview feature enables you to sign artifacts to establish authenticity and verify signatures to confirm integrity. Artifact signing provides foundational capabilities for model serving verification and AI asset provenance tracking in future releases. For more information, see the Kubeflow Model Registry Python client documentation  and Kubeflow async upload job documentation. 

Evaluation Stack user interface 

Red Hat OpenShift AI includes a Technology Preview of the Evaluation Stack user interface. The Evaluation Stack UI provides a guided workflow in the OpenShift AI dashboard for running model evaluations without requiring command-line tools or notebook workflows. This Technology Preview introduces the following capabilities: 

Browse and select evaluation tasks from registered providers, including LM Evaluation Harness, RAGAS, Garak, and GuideLLM 

Run built-in evaluation collections that group benchmarks across providers into reusable suites 

Configure evaluation parameters such as sample count and maximum tokens per response 

Evaluate models or AI applications against standardized benchmarks or custom evaluation datasets 

Monitor evaluation progress in real time and cancel running evaluations 

View summarized evaluation scores and metrics The Evaluation Stack UI requires EvalHub to be deployed on the cluster. For information about deploying and configuring EvalHub, see Evaluate LLMs with EvalHub . 

3.5. 3.4 EA2 TECHNOLOGY PREVIEW FEATURES 

Create ability to sign and verify AI Artifacts in Registry 

For more information about signing and verifying models in the Model Registry see https://github.com/kubeflow/model-registry/tree/main/clients/python#signing-and-verifying-models. For async upload job documentation, see https://github.com/kubeflow/model-registry/tree/main/jobs/async-upload#signing 

TLS and proxy configuration for all OGX remote inference providers 

Red Hat OpenShift AI 3.4 EA2 introduces a standardized network configuration block for all OGX remote inference providers. This generalizes TLS and proxy settings, previously exclusive to the **remote::vllm provider, to ensure compatibility across private network architectures. **

OGX versions in Red Hat OpenShift AI 3.4 EA2 

Red Hat OpenShift AI 3.4 EA2 includes Open Data Hub OGX version 0.6.0.1+rhai0, which is based on upstream OGX version 0.6.0. 

MLflow integration 

MLflow is no longer a Technology Preview feature. Starting with Red Hat OpenShift AI 3.4, the **MLflow Operator is a managed component in the DataScienceCluster. For more information, see **Track experiments with MLflow SDK . 

Support for text embedding models in the Model Catalog 

Red Hat OpenShift AI includes a dedicated suite of text embedding models within the Model Catalog that can be deployed on vLLM. This Technology Preview feature allows data scientists and AI engineers to discover and deploy models designed specifically for vector generation, a critical component for Retrieval-Augmented Generation (RAG) and semantic search workflows. By separating these models from standard generative large language models (LLMs), OpenShift AI provides a streamlined experience for users building vector-generation engines. Key features of this update include: 

Categorized discovery: Embedding models are available under the Other Models category in the Model Catalog. 

**Distinct labeling: Each model card is labeled with a text-embedding tag to clarify the **model’s function (outputting numerical vectors) compared to text-generation models. 

Ready-to-deploy images: The models are provided as OCI-compliant ModelCar images, ensuring they are ready for immediate instantiation as running services on an OpenShift cluster. Supported models include: 

Granite Embedding English R2 

Embedding Gemma 300M 

Nomic Embed Text v1.5 

Qwen3 Embedding 8B 

All-MiniLM-L6-v2 

To view embedding models in the Catalog, navigate to AI hub → Models → Catalog in the OpenShift **AI dashboard, select the Other models category, and look for the text-embedding tag on model **cards. You can deploy a model directly from its card by following the deployment wizard to configure 

the serving runtime and hardware profile. Once deployed, the model provides an API endpoint that generates numerical embeddings for text inputs for use in downstream vector databases or RAG pipelines. 

+ NOTE: Some models, such as Nomic Embed Text v1.5, require extra vLLM parameters to be set, **such as --trust-remote-code. Refer to upstream Hugging Face model cards for specific details. **

Workbench and runtime images default to the Red Hat Python index 

Access and use Red Hat built and supported Python packages. Installing or updating Python packages will pull from the Red Hat Python index rather than PyPI. 

YAML viewer for Distributed Inference with llm-d model deployments 

The model deployment wizard includes a YAML viewer that provides real-time YAML preview and manual editing capabilities for LLMInferenceService deployments. You can toggle between Form and YAML views to see the generated LLMInferenceService YAML as you fill out the deployment form. The preview updates automatically as form fields change, enabling you to verify configuration before deployment. You can also enter Manual Edit Mode to edit YAML directly for advanced Distributed Inference with llm-d parameters not exposed in the form, such as autoscaling, disaggregated serving, LoRA adapters, and custom runtime configurations. This Technology Preview feature introduces the following capabilities: 

Real-time YAML preview with automatic form-to-YAML synchronization 

Copy to clipboard and download functionality 

Manual Edit Mode for direct YAML editing of advanced configurations 

Automatic fallback to YAML editing when the wizard cannot parse deployment configurations (for example, deployments created via CLI or GitOps) 

Client-side YAML syntax validation before deployment 

NOTE 

Manual Edit Mode is a one-way operation. Once you enter manual YAML editing mode, you cannot return to the guided form view for that deployment session. Changes made in YAML edit mode bypass form validation. 

3.6. 3.4 EA1 TECHNOLOGY PREVIEW FEATURES 

OGX versions in OpenShift AI 3.4 EA1 

OpenShift AI 3.4 EA1 includes Open Data Hub OGX version 0.5.0+rhai0, which is based on upstream OGX version 0.5.0. 

Gen AI Playground interface redesign 

The Gen AI Playground interface provides a prompt-lab-style experience with improved prompt-driven experimentation, rapid iteration capabilities, and clear visual feedback. This redesign aligns the Playground experience with industry-standard patterns for GenAI tools. 

Multi-instance chat comparison in Playground 

You can compare results across multiple configurations in the Playground by using multiple chat panes side-by-side. Each pane supports unique configurations for models, prompts, MCP servers, 

guardrails, and knowledge sources. You can run synchronized prompts across all panes or use independent prompts for each pane. Key capabilities include: 

Side-by-side output comparison 

Toggle individual chat panes for A/B-style testing 

Runtime information display including latency and token counts 

Basic guardrails available in Gen AI Playground 

The Gen AI Playground provides access to basic safety guardrails from OGX. You can enable or disable guardrails in the playground interface to filter unsafe content and detect prompt injection attempts. The following guardrails are available: 

Content Safety (Llama Guard): Filters categories such as hate, violence, sexual content, self-harm, criminal activity, and privacy violations. 

Prompt Injection / Jailbreak Detection (Prompt Guard): Detects user attempts to override system or tool behavior. 

Privacy Awareness: Flags possible PII in inputs and outputs. 

NOTE 

**Guardrail enforcement applies to llm_input and llm_output touchpoints only. **Tool-level guardrails are not included in this release. 

OGX Connectors 

OGX Connectors provide a high-level abstraction for AI registries such as MCP. Platform Engineers **can register connectors by using a connector_id, and AI Engineers can consume pre-registered **connectors without managing complex configurations. This feature simplifies the workflow for AI engineers by abstracting away infrastructure concerns. 

Conversations API 

The Conversations API enables multi-turn, context-aware chats by managing message history, tool outputs, and conversation state. Developers can use this API to build AI applications with memory, moving beyond simple stateless requests to create persistent, intelligent interactions. 

OpenAI-compatible annotations for search and responses in OGX 

Starting with OpenShift AI 3.3, OGX provides OpenAI-compatible grounding and citation annotations for search-backed responses as a Technology Preview feature. This enhancement enables retrieval-augmented generation (RAG) applications to trace generated responses back to source documents by using the same annotation schemas returned by OpenAI Search and Responses APIs. The feature supports document source attribution and preserves citation metadata in API responses, allowing existing OpenAI client applications to consume citation information without code changes. 

This capability improves transparency, auditability, and explainability for enterprise RAG workloads, and serves as a foundation for future advanced tracing and observability features in OGX. For more information, see OpenAI-compatible file citation annotations . 

The OGX Operator available on multi-architecture clusters 

The OGX Operator is deployable on multi-architecture clusters in OpenShift AI version 3.3 and is available by default. 

OGX versions in OpenShift AI 3.3 

OpenShift AI 3.3.0 includes Open Data Hub OGX version 0.4.2.1+rhai0, which is based on upstream OGX version 0.4.2. 

The OGX Operator with ConfigMap driven image updates 

The OGX Operator in OpenShift AI 3.3 offers ConfigMap driven image updates for OGXServer resources. This allows you to patch security or bug fixes without new Operator versions. To enable this feature, update your ConfigMap with the following parameters: 

**Using the starter-gpu and starter distributions names as the key allows the operator to apply these **overrides automatically. 

**To update the OGX Distributions image for all starter distributions, run the following command: **

This allows the OGXServer resources to restart with the new image. 

pgvector support as a remote vector store provider in OGX 

Starting with OpenShift AI 3.2, you can use PostgreSQL with the pgvector extension as a remote **vector store provider for the OGX vector_store endpoint as a Technology Preview feature. **This enhancement enables vector storage backed by PostgreSQL, providing durable and transactional persistence for vector embeddings. For more information, see OGX API provider support and Deploying a PostgreSQL instance with pgvector . 

OGX versions in OpenShift AI 3.2 

OpenShift AI 3.2.0 uses the Open Data Hub OGX version 0.3.5+rhai0 in the OGX Distribution, which is based on the upstream OGX version 0.3.5. 

OGX servers require installation of the PostgreSQL Operator 

In OpenShift AI 3.2, the PostgreSQL Operator is required to deploy a OGX server. For more *information, see the Deploying a OGX server * documentation. 

Enabling high availability on OGX 

OGX servers can be configured to remain operational in the event of a single point of failure as a Technology Preview feature. You can enable PostgreSQL high-availability settings in your ***OGXServer custom resource. For more information, see the Enabling high availability on OGX ****(Optional) documentation. *

Custom embeddings on OGX 

OpenShift AI 3.2 allows you to customize your embedding models as a Technology Preview feature. In the version of OGX shipped in OpenShift AI 3.2, vLLM controls embeddings by default. You can 

 image-overrides: |     starter-gpu: registry.redhat.io/rhoai/odh-ogx-core-rhel9:v3.3     starter: registry.redhat.io/rhoai/odh-ogx-core-rhel9:v3.3 

$ kubectl patch configmap ogx-operator-config -n ogx-k8s-operator-system --type merge -p '{"data":{"image-overrides":"starter: quay.io/opendatahub/ogx:latest"}}' 

**update the VLLM_EMBEDDING_URL environment variable in your OGXServer custom resource to **enable embeddings, or you can use custom embeddings providers. For example: 

Stop button for chatbot in Generative AI Studio 

You can interrupt the chatbot as it is composing a response to a prompt. In the Playground, after you send a prompt, the Send button in the chat input field changes to a Stop button. Click it if you want to interrupt the model’s response, for example, when the response takes longer than you anticipated or if you notice that you made an error in your prompt. The chatbot posts "You stopped this message" to confirm your stop request. 

TrustyAI–OGX integration for safety, guardrails, and evaluation 

You can use the Guardrails Orchestrator from TrustyAI with OGX as a Technology Preview feature. This integration enables built-in detection and evaluation workflows to support AI safety and content moderation. When TrustyAI is enabled and the FMS Orchestrator and detectors are configured, no manual setup is required. 

**To activate this feature, set the following field in the DataScienceCluster custom resource for the OpenShift AI Operator: spec.ogx.managementState: Managed **

For more information, see the TrustyAI FMS Provider on GitHub: TrustyAI FMS Provider. 

AI Available Assets page for deployed models and MCP servers 

A new AI Available Assets page enables AI engineers and application developers to view and consume deployed AI resources within their projects. This enhancement introduces a filterable UI that lists available models and Model Context Protocol (MCP) servers in the selected project, allowing users with appropriate permissions to identify accessible endpoints and integrate them directly into the AI Playground or other applications. 

Generative AI Playground for model testing and evaluation 

The Generative AI (GenAI) Playground introduces a unified, interactive experience within the OpenShift AI dashboard for experimenting with foundation and custom models. Users can test prompts, compare models, and evaluate Retrieval-Augmented Generation (RAG) workflows by uploading documents and chatting with their content. The GenAI Playground also supports integration with approved Model Context Protocol (MCP) servers and enables export of prompts and agent configurations as runnable code for continued iteration in local IDEs. 

Chat context is preserved within each session, providing a suitable environment for prompt engineering and model experimentation. 

Support for air-gapped OGX deployments 

You can install and operate OGX and RAG/Agentic components in fully disconnected (air-gapped) OpenShift AI environments. This enhancement enables secure deployment of OGX features without internet access, allowing organizations to use AI capabilities while maintaining compliance with strict network security policies. 

  - name: ENABLE_SENTENCE_TRANSFORMERS     value: "true"   - name: EMBEDDING_PROVIDER     value: "sentence-transformers" 

Feature Store integration with Workbenches and new user access capabilities 

This feature is available as a Technology Preview. The Feature Store is integrated with OpenShift AI, data science projects, and workbenches. This integration also introduces centrally managed, role-based access control (RBAC) capabilities for improved governance. 

These enhancements provide two key capabilities: 

Feature development within the workbench environment. 

Administrator-controlled user access. This update simplifies and accelerates feature discovery and consumption for data scientists while allowing platform teams to maintain full control over infrastructure and feature access. 

Feature Store user interface 

The Feature Store component includes a web-based user interface (UI). You can use the UI to view registered Feature Store objects and their relationships, such as features, data sources, entities, and feature services. 

**To enable the UI, edit your FeatureStore custom resource (CR) instance. When you save the **change, the Feature Store Operator starts the UI container and creates an OpenShift route for access. 

*For more information, see Setting up the Feature Store user interface for initial use *. 

IBM Spyre AI Accelerator model serving support on x86 platforms 

Model serving with the IBM Spyre AI Accelerator is available as a Technology Preview feature for x86 platforms. The IBM Spyre Operator automates installation and integrates the device plugin, secondary scheduler, and monitoring. For more information, see the IBM Spyre Operator catalog entry. 

Build Generative AI Apps with OGX on OpenShift AI 

With this release, the OGX Technology Preview feature enables Retrieval-Augmented Generation (RAG) and agentic workflows for building next-generation generative AI applications. It supports remote inference, built-in embeddings, and vector database operations. It also integrates with providers like TrustyAI’s provider for safety and Trusty AI’s LM-Eval provider for evaluation. This preview includes tools, components, and guidance for enabling the OGX Operator, interacting with the RAG Tool, and automating PDF ingestion and keyword search capabilities to enhance document discovery. 

Centralized platform observability 

Centralized platform observability, including metrics, traces, and built-in alerts, is available as a Technology Preview feature. This solution introduces a dedicated, pre-configured observability stack for OpenShift AI that allows cluster administrators to perform the following actions: 

View platform metrics (Prometheus) and distributed traces (Tempo) for OpenShift AI components and workloads. 

Manage a set of built-in alerts (alertmanager) that cover critical component health and performance issues. 

Export platform and workload metrics to external 3rd party observability tools by editing the **DataScienceClusterInitialization (DSCI) custom resource. **You can enable this feature by integrating with the Cluster Observability Operator, Red Hat build of OpenTelemetry, and Tempo Operator. For more information, see Monitoring and observability. For more information, see Managing observability. 

Support for OGX Distribution version 0.3.0 

The OGX Distribution includes version 0.3.0 as a Technology Preview feature. This update introduces several enhancements, including expanded support for retrieval-augmented generation (RAG) pipelines, improved evaluation provider integration, and updated APIs for agent and vector store management. It also provides compatibility updates aligned with recent OpenAI API extensions and infrastructure optimizations for distributed inference. 

The previously supported version was 0.2.22. 

Support for Kubernetes Event-driven Autoscaling (KEDA) 

OpenShift AI supports Kubernetes Event-driven Autoscaling (KEDA) in its KServe RawDeployment mode. This Technology Preview feature enables metrics-based autoscaling for inference services, allowing for more efficient management of accelerator resources, reduced operational costs, and improved performance for your inference services. To set up autoscaling for your inference service in KServe RawDeployment mode, you need to install and configure the OpenShift Custom Metrics Autoscaler (CMA), which is based on KEDA. 

For more information about this feature, see: Configuring metrics-based autoscaling. 

LM-Eval model evaluation UI feature 

TrustyAI offers a user-friendly UI for LM-Eval model evaluations as Technology Preview. This feature allows you to input evaluation parameters for a given model and returns an evaluation-results page, all from the UI. 

Support for creating and managing Ray Jobs with the CodeFlare SDK 

You can create and manage Ray Jobs on Ray Clusters directly through the CodeFlare SDK. This enhancement aligns the CodeFlare SDK workflow with the KubernetesFlow Training Operator (KFTO) model, where a job is created, run, and completed automatically. This enhancement simplifies manual cluster management by preventing Ray Clusters from remaining active after job completion. 

Custom flow estimator for Synthetic Data Generation pipelines 

You can use a custom flow estimator for synthetic data generation (SDG) pipelines. For supported and compatible tagged SDG teacher models, the estimator helps you evaluate a chosen teacher model, custom flow, and supported hardware on a sample dataset before running full workloads. 

OGX support and optimization for single node OpenShift (SNO) 

OGX core can deploy and run efficiently on single node OpenShift (SNO). This enhancement optimizes component startup and resource usage so that OGX can operate reliably in single-node cluster environments. 

FAISS vector storage integration 

You can use the FAISS (Facebook AI Similarity Search) library as an inline vector store in OpenShift AI. FAISS is an open-source framework for high-performance vector search and clustering, optimized for dense numerical embeddings with both CPU and GPU support. When enabled with an embedded SQLite backend in the OGX Distribution, FAISS stores embeddings locally within the container, removing the need for an external vector database service. 

New Feature Store component 

You can install and manage Feature Store as a configurable component in OpenShift AI. Based on the open-source Feast project, Feature Store acts as a bridge between ML models and data, enabling consistent and scalable feature management across the ML lifecycle. This Technology Preview release introduces the following capabilities: 

Centralized feature repository for consistent feature reuse 

Python SDK and CLI for programmatic and command-line interactions to define, manage, and retrieve features for ML models 

Feature definition and management 

Support for a wide range of data sources 

Data ingestion via feature materialization 

Feature retrieval for both online model inference and offline model training 

Role-Based Access Control (RBAC) to protect sensitive features 

Extensibility and integration with third-party data and compute providers 

Scalability to meet enterprise ML needs 

Searchable feature catalog 

Data lineage tracking for enhanced observability For configuration details, see Configuring Feature Store. 

FIPS support for OGX and RAG deployments 

You can deploy OGX and RAG or agentic solutions in regulated environments that require FIPS compliance. This enhancement provides FIPS-certified and compatible deployment patterns to help organizations meet strict regulatory and certification requirements for AI workloads. 

Validated sdg-hub notebooks for Red Hat AI Platform 

**Validated sdg_hub example notebooks are available to provide a notebook-driven user experience **in OpenShift AI 3.0. These notebooks support multiple Red Hat platforms and enable customization through SDG pipelines. They include examples for the following use cases: 

Knowledge and skills tuning, including annotated examples for fine-tuning models. 

Synthetic data generation with reasoning traces to customize reasoning models. 

Custom SDG pipelines that demonstrate using default blocks and creating new blocks for specialized workflows. 

RAGAS evaluation provider for OGX (inline and remote) 

You can use the Retrieval-Augmented Generation Assessment (RAGAS) evaluation provider to measure the quality and reliability of RAG systems in OpenShift AI. RAGAS provides metrics for retrieval quality, answer relevance, and factual consistency, helping you identify issues and optimize RAG pipeline configurations. 

The integration with the OGX evaluation API supports two deployment modes: 

Inline provider: Runs RAGAS evaluation directly within the OGX server process. 

Remote provider: Runs RAGAS evaluation as distributed jobs using OpenShift AI pipelines. The RAGAS evaluation provider is included in the OGX distribution. 

Enable targeted deployment of workbenches to specific worker nodes in Red Hat OpenShift AI Dashboard using node selectors 

The hardware profiles feature enables users to target specific worker nodes for workbenches or model-serving workloads. It allows users to target specific accelerator types or CPU-only nodes. This feature replaces the current accelerator profiles feature and container size selector field, offering a broader set of capabilities for targeting different hardware configurations. While accelerator profiles, taints, and tolerations provide some capabilities for matching workloads to hardware, they do not ensure that workloads land on specific nodes, especially if some nodes lack the appropriate taints. 

The hardware profiles feature supports both accelerator and CPU-only configurations, along with node selectors, to enhance targeting capabilities for specific worker nodes. Administrators can configure hardware profiles in the settings menu. Users can select the enabled profiles using the UI for workbenches, model serving, and AI pipelines where applicable. 

Support for multinode deployment of very large models 

Serving models over multiple graphical processing unit (GPU) nodes when using a single-model serving runtime is available as a Technology Preview feature. Deploy your models across multiple GPU nodes to improve efficiency when deploying large models such as large language models (LLMs). For more information, see Deploying models by using multiple GPU nodes . 

### CHAPTER 4. DEVELOPER PREVIEW FEATURES

IMPORTANT 

This section describes Developer Preview features in Red Hat OpenShift AI 3.5. Developer Preview features are not supported by Red Hat in any way and are not functionally complete or production-ready. Do not use Developer Preview features for production or business-critical workloads. Developer Preview features provide early access to functionality in advance of possible inclusion in a Red Hat product offering. Customers can use these features to test functionality and provide feedback during the development process. Developer Preview features might not have any documentation, are subject to change or removal at any time, and have received limited testing. Red Hat might provide ways to submit feedback on Developer Preview features without an associated SLA. 

For more information about the support scope of Red Hat Developer Preview features, see Developer Preview Support Scope. 

4.1. 3.5 GA DEVELOPER PREVIEW FEATURES 

Secure agent sandboxing and policy enforcement using OpenShell 

A Developer Preview of OpenShell is available for secure agent onboarding on OpenShift. The included guide covers Helm deployment, mTLS, LLM provider setup, isolated sandboxes, and controlled network egress. This experimental preview uses upstream artifacts and is not supported for production environments. To try it out, follow the instructions in the agent-ops GitHub repository. 

Agent Catalog in AI Hub for agent starter kit discovery 

The Agent Catalog in AI Hub provides a centralized interface for discovering and exploring agent starter kits as a Developer Preview. You can browse available agents, view each agent’s description, and filter by framework or use text search to find agents for a specific use case. Each catalog entry **displays the agent’s description, framework, and a README file with additional information about **the agent. The catalog ships pre-loaded with agent starter kits built on LangGraph, CrewAI, LlamaIndex, and other agentic frameworks. 

**To enable this Developer Preview feature, set the agentsCatalog feature flag to true. **

To access the catalog, from the OpenShift AI dashboard, click AI hub → Agents. 

Configuration persistence for Gen AI Studio 

You can save your Gen AI Studio Playground configuration as a named, reusable agent scoped to your project namespace. A saved agent captures model selection, inference parameters, MLflow prompt references, retrieval augmented generation (RAG) knowledge sources, and Model Context Protocol (MCP) server connections. Agents are stored as Kubernetes resources in the project namespace and are visible to all project members. Key capabilities: 

Save a playground configuration with a name and description. 

Load a saved agent to restore all captured settings. 

Use Save as new agent to create variant copies for comparison experiments. 

Browse, rename, and delete saved agents from the Agents tab on the AI asset endpoints page. 

Validation on load detects and reports any referenced resources that have been deleted or become unavailable. **To enable this feature, set the agentConfigManagement dashboard configuration option to true. **

Hierarchical KV Cache Tiering 

Hierarchical KV cache tiering for GPU inference workloads allows platform operators to serve more concurrent users on the same GPU footprint, directly improving the cost-effectiveness of inference deployments. Cache entries are automatically placed on the tiers operators configure. This increases the effective cache size and prefix-cache reuse for multi-turn and long-context workloads. For more information, see KV Cache Offloading . 

LoRA-aware request routing for Distributed Inference with llm-d 

Platform operators can route requests to pods where the target LoRA adapter is already loaded, avoiding cold-load latency from on-demand adapter swaps. When no pod with the target adapter is available, requests automatically fall back to standard routing. 

Latency-aware routing for Distributed Inference with llm-d 

Platform operators can declare per-request latency targets for Time To First Token (TTFT) and Time Per Output Token (TPOT). The routing layer then places each request on a pod predicted to meet its specific target. This allows latency-sensitive traffic to be routed to pods with available capacity, while throughput-sensitive traffic fills pods that are already handling longer work. 

External metering for per-user token usage and cost tracking 

In OpenShift AI, an external metering IPP plugin and standalone metering service are available as a Developer Preview feature. This feature enables platform operators to track per-user and per-model token consumption, attribute costs, enforce quotas, and generate chargeback reports for inference requests passing through the AI Inference Gateway. **The external-metering plugin operates in the IPP plugin chain. It checks user balances before **processing requests and extracts token usage details, such as input, output, cached, cache write, and reasoning tokens, from OpenAI and Anthropic provider responses. The plugin then emits CloudEvents to a standalone metering service backed by PostgreSQL. The service aggregates usage, calculates cache-aware pricing, and provides an administrative dashboard and REST API for usage queries and balance checks. 

MCP Catalog administrative interface for managing entries 

In OpenShift AI, administrators can manage Model Context Protocol (MCP) Catalog source configurations directly from the Settings page of the dashboard. This new interface enables you to add, edit, and remove MCP server catalog entries using YAML-based creation, eliminating the need **to manually edit Kubernetes ConfigMap resources. The user experience aligns with the Model **Catalog administrative interface, and access to these catalog management operations is restricted strictly to OpenShift AI administrators. 

MiDojo adversarial testing execution engine 

In OpenShift AI, you can use MiDojo, a man-in-the-middle adversarial testing execution engine for AI agents, available as a Developer Preview feature. MiDojo intercepts communications at the tool layer, injecting attack payloads into tool responses while forwarding legitimate calls upstream. With MiDojo, you can test agents against realistic attack scenarios without rebuilding infrastructure or modifying the agent. Using a declarative YAML format, you can author scenarios that cover 

environment state, tasks, and injection vectors. MiDojo executes combinations of legitimate and injection tasks to grade task completion (utility) and attack resistance (security), recording the full tool trace. Payloads can be delivered in prompts, data sources, or tool responses. This MiDojo release supports custom external suites, pluggable backends, Kubernetes-native deployment, a reference MiniBank suite, and multiple agent protocols (such as A2A, OGX, PI, OpenAI Responses API, and Simple HTTP). 

External metering integration for Models-as-a-Service 

You can connect Models-as-a-Service (MaaS) inference traffic to an external metering or billing system by using Backend-Based Routing (BBR) plugins. This integration enables platform operators running MaaS as a commercial AI service to capture per-request token usage and enforce token budgets through an external metering system. The external metering integration includes two BBR plugins: 

Post-inference token usage webhook: A BBR response plugin that asynchronously emits a structured token usage event to a configured external metering endpoint after each inference request. The event payload includes requester identity, subscription, model, input and output token counts, request ID, and timestamp. Webhook delivery does not affect inference latency. 

Pre-inference credit check: A BBR request plugin that checks credit availability from the external metering system before allowing inference. If credit is exhausted, the next request is blocked. This design avoids adding metering system latency to the inference path. Both plugins are activated and deactivated per-gateway through configuration and work for both internal model inference and external model requests. Failed webhook delivery attempts are logged for alerting and recovery. 

NOTE 

This feature provides raw usage event emission to any HTTP endpoint. Invoice generation, cost attribution, and rate calculation are the responsibility of the external metering system. 

View running agent deployments in the dashboard 

In OpenShift AI, you can view a list of running agent deployments directly in the dashboard. This **feature enables you to see agents that were deployed manually as OpenShell-managed Sandbox **custom resources (CRs). The dashboard allows you to view the name and status of each deployed agent instance in each namespace, and includes filtering capabilities to help you manage your deployed agents. 

Text-mode training for multimodal models in Training Hub 

Training Hub supports text-only training ("text mode") for multimodal model architectures. This enhancement enables you to fine-tune Qwen 3.5, Qwen 3.6, Qwen 3.8, Gemma, Nemotron, and Mistral vision-language models (VLMs) by using text datasets. In this release, multimodal-capable models can be fine-tuned in text mode only. 

4.2. 3.5 EA2 DEVELOPER PREVIEW FEATURES 

**The remote::anthropic inference provider for OGX **

**The remote::anthropic inference provider is available on OGX. You can use this provider by enabling the ANTHROPIC_API_KEY environment variable in your config.yaml file. **

File Processors API on OGX 

The File Processors API is available on OGX. The File Processors API allows you to convert documents into vector-ready chunks using the following providers: 

**inline::auto **

**inline::docling **

**inline::markitdown **

**inline::pypdf **

**remote::docling-serve **

NOTE 

**Some listed providers are not included in the default runtime config.yaml file and must be enabled by passing a custom config.yaml file that includes the **provider definitions. For more information, see the "OGX API provider support" documentation. 

**The remote::gemini inference provider for OGX **

**The remote::gemini inference provider is available on OGX. You can use this provider by enabling the ENABLE_GEMINI environment variable in your config.yaml file. **

OpenClaw agent starter kit 

You can deploy and manage OpenClaw, an open-source general-purpose agent, on Red Hat OpenShift AI. The starter kit includes validated Kustomize manifests and an automated installer to manage runtime concerns and optimize workspace persistence. The starter kit includes the following capabilities: 

Deploy OpenClaw by using validated Kustomize manifests or the automated OpenClaw installer. 

Connect to self-hosted models through vLLM by using the OGX inference gateway with an OpenAI-compatible API. 

Capture model calls, tool executions, and context assembly spans in MLflow by using native **OpenTelemetry tracing through the diagnostics-otel plugin. **

Enforce browser-based access control backed by OpenShift role-based access control (RBAC) through OAuth proxy integration. 

Maintain workspace storage across pod restarts. 

Validate your environment by using an included model compatibility matrix and troubleshooting guide. 

**Run workloads securely under the OpenShift restricted-v2 security context constraint **(SCC). For more information, see OpenClaw Agentic Starter Kit. 

Claude Code agent starter kit 

You can deploy and configure the Anthropic Claude Code agent on Red Hat OpenShift AI by using a new agentic starter kit. The kit provides a Containerfile and Kustomize deployment manifests to streamline setup in a secure environment. The starter kit includes the following capabilities: 

Deploy Claude Code by using a pre-configured Containerfile and Kustomize deployment manifests. 

Choose from validated inference paths: direct Anthropic API, self-hosted models through vLLM, or vLLM through the OGX gateway, which allows you to use your own models without an Anthropic subscription. 

Observe and track tool calls, token usage, and agent execution traces by using built-in MLflow tracing integration. 

Inject modular skills and Model Context Protocol (MCP) server configurations at deploy time through a ConfigMap without rebuilding container images. 

Maintain workspace storage across pod restarts. 

**Run workloads under the OpenShift restricted-v2 security context constraint (SCC) with no **special security grants required. For more information, see Claude Code Agentic Starter Kit . 

Kale JupyterLab extension for notebook-to-pipeline conversion 

You can use the Kale (Kubeflow Automated pipeLines Engine) JupyterLab extension to convert annotated Jupyter notebooks into AI Pipelines without writing Kubeflow Pipelines SDK code. The Kale extension ships pre-installed but disabled by default in the following default data science Jupyter notebook images: Standard Data Science, PyTorch, TensorFlow, TrustyAI, ROCm-PyTorch, and ROCm-TensorFlow. 

NOTE 

Kale is not available in custom notebook images. 

**To enable the extension, run jupyter labextension enable jupyterlab-kubeflow-kale in your **workbench terminal and refresh your browser. A Data Science Pipelines Application must be deployed in the same namespace as the workbench. After enabling, a green connection status indicates that KFP is connected; a yellow warning indicates that it is disconnected. Open a Jupyter notebook to activate the Enable toggle, then switch it on to use the Kale metadata editor. 

For more information, see Kale documentation. 

CSV export for model catalog data 

You can export model catalog metadata to CSV format by using a standalone Python CLI script. The script queries the Model Catalog REST API, paginates through the full result set, and produces an RFC 4180-compliant CSV file that includes all model metadata and custom properties. The export script requires Python 3.10+ with no additional dependencies and supports options for **filtering by source with --source, limiting output count with --limit, and setting authorization headers with --header. The script writes atomically to prevent partial output on failure. **

For more information about installation, authentication, and usage, see CSV Exporter for Model Catalog. 

4.3. 3.4 GA DEVELOPER PREVIEW FEATURES 

AgentCard support for post-deployment agent discovery 

You can discover deployed agents and their capabilities through the AgentCard custom resource. **When you deploy an agent as a Kubernetes Deployment or StatefulSet with the kagenti.io/type: agent label and a protocol label such as protocol.kagenti.io/a2a, the platform automatically creates **an AgentCard that advertises the agent’s capabilities, endpoints, and supported protocols. This enables machine-readable agent-to-agent discovery for multi-agent workflows. For more information, see Kagenti Operator Repository. 

Agent deploy and runtime management 

You can manage the runtime concerns of deployed agents using the AgentRuntime custom resource. Create an AgentRuntime that references your agent’s Deployment or StatefulSet via **spec.targetRef, and the operator automatically injects authentication and identity sidecars into **agent pods. This includes an Envoy-based AuthBridge proxy for inbound JWT validation and outbound token exchange, SPIFFE-based workload identity via a spiffe-helper sidecar, and per-**agent OpenTelemetry trace configuration. Agents labeled with kagenti.io/type: agent are injected by default, but you can opt out with kagenti.io/inject: disabled. The AgentRuntime also supports **per-workload overrides for SPIFFE trust domains, OTEL collector endpoints, and trace sampling rates. For more information, see Kagenti Operator Repository. 

Existing vector stores available as RAG knowledge sources in Gen AI Studio Playground 

You can surface previously-created vector stores as retrieval-augmented generation (RAG) knowledge sources in the Gen AI Studio Playground. Platform engineers define vector stores through ConfigMaps, and AI engineers can select them as knowledge sources when chatting with models in the Playground. This enables rapid RAG experimentation without writing code or reingesting data. This release includes the following capabilities: 

Platform engineers can declare vector stores through ConfigMaps with connection details, collection names, and optional metadata 

Available vector stores appear under RAG / Knowledge Sources in the Playground 

Users can enable or disable a vector store per chat session 

Queries are routed through OGX RAG primitives 

NOTE 

This feature does not include document upload, ingestion, chunking, indexing, or vector store lifecycle management. Only read-only query and retrieval of pre-existing vector data is supported. 

Interact with Red Hat OpenShift AI using MCP clients 

Red Hat OpenShift AI provides an MCP (Model Context Protocol) server that enables MCP-compatible clients to interact with your environment through natural-language conversations. When you describe your goals, the MCP server recommends the optimal model from your model registry by matching your intent against benchmarks such as MMLU and HumanEval, with cost comparisons. You can also manage data science projects, create workbenches, and monitor pipeline runs. When you are ready to deploy, the MCP server generates three production-ready Kubernetes manifests for model serving, auto-scaling, and observability. The MCP server works with AI coding assistants such as Claude Code, OpenCode, and Gemini CLI. For more information, see RHOAI MCP 

server. 

MCP Catalog for enterprise management of MCP servers 

The MCP Catalog provides a centralized experience for discovering, deploying, and experimenting with Model Context Protocol (MCP) servers in Red Hat OpenShift AI. AI Operators and Platform Engineers can browse available MCP servers in a catalog UI, view descriptive metadata about each server’s capabilities and tools, and deploy MCP servers into their namespace directly from the catalog. After deployment, a platform engineer can register deployed MCP servers in the gen AI studio configuration, making them available in the playground for interactive experimentation. The MCP Catalog ships pre-loaded with MCP servers from Red Hat, technology partners, and the open source community. These servers can be deployed directly from the catalog without sourcing container images or configuring transport manually. Some additional prerequisite steps, such as mirroring images may be required for disconnected deployments or configuring server-specific credentials. 

Red Hat MCP servers: 

Red Hat OpenShift - Cluster management and troubleshooting 

Red Hat Ansible Automation Platform - Playbook execution and configuration orchestration 

Red Hat Insights - platform intelligence and remediation recommendations. 

Technology partner MCP servers: 

Confluent Cloud - Kafka and Flink streaming 

EDB Postgres AI - database queries and schema management 

HashiCorp Terraform - infrastructure as code 

Microsoft Azure - cloud resource management 

Dynatrace - performance monitoring and troubleshooting. 

Other MCP servers: MongoDB (document collections and RAG workflows) and MariaDB (relational database connectivity). 

The MCP Catalog relies on the following pre-requisite upstream community components: 

+ 

mcp-lifecycle-operator: A Kubernetes operator that provides a declarative API to deploy, manage, and roll out MCP servers. When an MCPServer custom resource is created, the operator automatically provisions the required Deployments, Services, and cluster-internal URLs for service discovery. The MCP lifecycle operator must be installed on the cluster before deploying MCP servers from the catalog. For more information, see kubernetes-sigs/mcp-lifecycle-operator on GitHub. 

mcp-gateway: A Kubernetes-native gateway that provides a unified runtime endpoint for accessing deployed MCP servers. The MCP Gateway aggregates tools from multiple registered MCP servers behind a single endpoint, enabling centralized access control and routing. For more information, see the mcp-gateway/docs/guides/quick-start.md on GitHub. 

The deploy action in the catalog UI is gated on the presence of the MCP lifecycle operator. If the operator is not installed, the deployment option is not available. 

4.4. 3.4 EA2 DEVELOPER PREVIEW FEATURES 

Core Evaluation Stack control plane 

The Evaluation Stack control plane provides an API REST routing and orchestration layer for AI evaluation, benchmarking, and profiling backends on OpenShift AI. AI engineers can deploy and manage a comprehensive evaluation platform that supports multiple frameworks and execution modes through a unified interface. The Evaluation Stack control plane includes the following capabilities: 

REST API endpoints for programmatic evaluation triggering from web UI interfaces and other components 

Built-in support for LM Evaluation Harness, RAGAS, Garak, and GuideLLM evaluation frameworks 

Custom framework integration by using container images or Python package specifications for Kubeflow Pipelines 

Evaluation results tracked in MLflow with a standardized schema 

Evaluation job monitoring and progress tracking through Kubernetes constructs 

Concurrent evaluation jobs with resource isolation 

Support for air-gapped and disconnected environments 

Installable Python package for local development 

4.5. 3.4 EA1 DEVELOPER PREVIEW FEATURES 

Automatic MLflow experiment creation in EvalHub 

The EvalHub service automatically creates an MLflow experiment when you specify **experiment.name in the evaluation job request. If the experiment creation fails due to missing **MLflow configuration, authentication issues, or other problems, the job request returns an error. 

Kubeflow Spark Operator for distributed data processing 

The Kubeflow Spark Operator is available in OpenShift AI as a Developer Preview. This feature provides Apache Spark integration with OpenShift AI, enabling the full lifecycle of Spark applications on Kubernetes. This enables unified orchestration and monitoring of large-scale data processing and preparation Spark jobs alongside ML training and inference workflows. **To enable the Kubeflow Spark Operator, navigate to your dsc.yaml CR and update the kubeflowsparkoperator parameter to the Managed state. **

This feature introduces the following capabilities: 

Integration with the OpenShift AI distributed workloads ecosystem. 

**SparkApplication custom resources (CRs) for defining Spark jobs. **

Automatic submission, monitoring and restart of Spark applications with configuration retry policies. 

Pod customization via mutating webhooks, supporting ConfigMaps, volumes, and affinity rules. 

Run evaluations for TrustyAI-OGX using LM-Eval 

You can run evaluations using LM-Eval on OGX with TrustyAI as a Developer Preview feature, using the built-in LM-Eval component and advanced content moderation tools. To use this feature, ensure TrustyAI is enabled, the FMS Orchestrator and detectors are set up, and KServe RawDeployment mode is in use for full compatibility if needed. There is no manual set up required. **Then, in the DataScienceCluster custom resource for the Red Hat OpenShift AI Operator, set the spec.components.ogx.managementState field to Managed. **

For more information, see the following resources on GitHub: 

Trusty AI Eval Provider 

OGX Operator 

LLM Compressor integration 

LLM Compressor capabilities are available in Red Hat OpenShift AI as a Developer Preview feature. **A new workbench image with the llm-compressor library and a corresponding data science pipelines **runtime image make it easier to compress and optimize your large language models (LLMs) for **efficient deployment with vLLM. For more information, see llm-compressor in GitHub. **You can use LLM Compressor capabilities in two ways: 

Use a Jupyter notebook with the workbench image available at Red Hat Quay.io: **opendatahub / llmcompressor-workbench. **For an example Jupyter notebook, see **examples/llmcompressor/workbench_example.ipynb in the red-hat-ai-examples **repository. 

Run a data science pipeline that executes model compression as a batch process with the **runtime image available at Red Hat Quay.io: opendatahub / llmcompressor-pipeline-runtime. For an example pipeline, see examples/llmcompressor/oneshot_pipeline.py in the red-hat-ai-examples repository. **

AI Available Assets integration with Model-as-a-Service (MaaS) 

This feature is available as a Developer Preview. You can access and consume Model-as-a-Service (MaaS) models directly from the AI Available Assets page in the GenAI Studio. 

Administrators can configure a MaaS by enabling the toggle in the Model Deployments page. When a model is marked as a service, it becomes global and visible across all projects in the cluster. 

Additional fields added to Model Deployments for AI Available Assets integration 

This feature is available as a Developer Preview. Administrators can add metadata to models during deployment so that they are automatically listed on the AI Available Assets page. 

The following table describes the new metadata fields that streamline the process of making models discoverable and consumable by other teams: 

Field name Field type Description 

Use Case Free-form text Describes the model’s primary purpose, for example, "Customer Churn Prediction" or "Image Classification for Product Catalog." 

Description Free-form text Provides more detailed context and functionality notes for the model. 

Add to AI Assets Checkbox When enabled, automatically publishes the model and its metadata to the AI Available Assets page. 

Compatibility of OGX remote providers and SDK with MCP HTTP streaming protocol 

This feature is available as a Developer Preview. OGX remote providers and the SDK are compatible with the Model Context Protocol (MCP) HTTP streaming protocol. 

This enhancement enables developers to build fully stateless MCP servers, simplify deployment on standard OGX infrastructure (including serverless environments), and improve scalability. It also prepares for future enhancements such as connection resumption and provides a smooth transition away from Server-Sent Events (SSE). 

Packaging of ITS Hub dependencies to the Red Hat–maintained Python index 

This feature is available as a Developer Preview. All Inference Time Scaling (ITS) runtime dependencies are packaged in the Red Hat-maintained **Python index, allowing Red Hat AI and OpenShift AI customers to install its_hub and its dependencies directly by using pip. **

This enhancement enables users to build custom inference images with ITS algorithms focused on improving model accuracy at inference time without requiring model retraining, such as: 

Particle filtering 

Best-of-N 

Beam search 

Self-consistency 

Verifier or PRM-guided search For more information, see the ITS Hub on GitHub. 

Dynamic hardware-aware continual training strategy 

Static hardware profile support is available to help users select training methods, models, and hyperparameters based on VRAM requirements and reference benchmarks. This approach ensures predictable and reliable training workflows without dynamic hardware discovery. The following components are included: 

API Memory Estimator: Accepts model, training method, dataset metadata, and assumed hyperparameters as input and returns an estimated VRAM requirement for the training job. Delivered as an API within Training Hub. 

Reference Profiles and Benchmarks: Provides end-to-end training time benchmarks for OpenShift AI Innovation (OSFT) and Performance Team (LAB SFT) baselines, delivered as static tables and documentation in Training Hub. 

Hyperparameter Guidance: Publishes safe starting ranges for key hyperparameters such as learning rate, batch size, epochs, and LoRA rank. Integrated into example notebooks maintained by the AI Innovation team. 

IMPORTANT 

Hardware discovery is not included in this release. Only static reference tables and guidance are provided; automated GPU or CPU detection is not yet supported. 

Human-in-the-Loop (HIL) functionality in the OGX agent 

Human-in-the-Loop (HIL) functionality has been added to the OGX agent to allow users to approve unread tool calls before execution. This enhancement includes the following capabilities: 

Users can approve or reject unread tool calls through the responses API. 

Configuration options specify which tool calls require HIL approval. 

Tool calls pause until user approval is received for HIL-enabled tools. 

Tool calls that do not require HIL continue to run without interruption. 

### CHAPTER 5. SUPPORT REMOVALS

This section describes major changes in support for user-facing features in Red Hat OpenShift AI. For information about OpenShift AI supported software platforms, components, and dependencies, see the Supported Configurations for 3.x  Knowledgebase article. 

5.1. DEPRECATED 

Deprecation of FMS Guardrails Orchestrator 

In OpenShift AI 3.5, the FMS Guardrails Orchestrator is deprecated and will be removed in a future release. NeMo Guardrails is now the single, recommended framework for all LLM safety guardrailing in OpenShift AI. While the FMS Guardrails Orchestrator remains functional in OpenShift AI 3.5, use NeMo Guardrails for all new deployments. If you have existing FMS Guardrails deployments, plan to migrate them to NeMo Guardrails before the FMS components are removed. 

Deprecated LM-Eval 

**The LM-Eval standalone evaluation service, including the LMEvalJob custom resource and the LM-**Eval model evaluation UI, is deprecated and will be removed in a future release. Migrate evaluation workflows to EvalHub, which provides a unified evaluation platform with support for multiple evaluation frameworks, including LM Evaluation Harness. 

RStudio Server and CUDA - RStudio Server workbench images removed 

Starting with OpenShift AI 3.5, the RStudio Server and CUDA - RStudio Server workbench images have been removed from Red Hat OpenShift AI due to licensing compliance requirements. The existing RStudio images contained packages with incorrect AGPL license declarations and proprietary binaries that do not meet Red Hat open source standards. Running RStudio workbenches continue to operate after the upgrade, but you cannot create new RStudio workbenches or restart stopped ones from the dashboard. 

RStudio remains available in OpenShift AI 2.25, with an end of life date of October 5, 2026, and OpenShift AI 3.3, with an end of life date of April 26, 2027. 

To continue using RStudio on OpenShift AI 3.5 or later, you can build your own unsupported RStudio images by using the self-build recipes. For more information, see Building unsupported RStudio Server workbench images. 

To migrate to a supported IDE for R workflows, see Alternative IDEs for R workflows  and Set up R development in code-server or JupyterLab. 

Deprecation of OGX Evaluation API 

In OpenShift AI 3.5 EA1, the Evaluation REST API and its associated providers are deprecated and removed from the OGX Operator. 

Deprecation of the Safety and Shields APIs from OGX 

The Safety and Shields APIs and their respective providers have been deprecated in OGX, previously known as Llama Stack, in OpenShift AI 3.5 EA1. 

Deprecated default group creation for model registry 

Starting with OpenShift AI 3.4, the default group creation performed by the OpenShift AI Operator when a model registry is created is deprecated. This default group will be removed in a future release of OpenShift AI. The OpenShift administrator will then be responsible for creating this group after the model registry is created, if needed in their workflow. 

Deprecated SQLite as a production metadata store for OGX 

Starting with OpenShift AI 3.2, SQLite is deprecated for use as a metadata store in production OGX deployments. PostgreSQL is required for production-grade environments to ensure adequate performance, concurrency, and scalability. SQLite remains available for local development and testing only and must be explicitly configured. This includes configurations that define SQLite **backends such as kv-sqlite or sql-sqlite in the OGX storage configuration. SQLite is not intended **for production workloads. 

Deprecated annotation format for Connection Secrets 

**Starting with OpenShift AI 3.0, the opendatahub.io/connection-type-ref annotation format for **creating Connection Secrets is deprecated. **For all new Connection Secrets, use the opendatahub.io/connection-type-protocol annotation instead. While both formats are currently supported, connection-type-protocol takes precedence **and should be used for future compatibility. 

Deprecated Kubeflow Training operator v1 

The Kubeflow Training Operator (v1) is deprecated starting OpenShift AI 2.25 and is planned to be removed in a future release. This deprecation is part of our transition to Kubeflow Trainer v2, which delivers enhanced capabilities and improved functionality. 

Deprecated TrustyAI service CRD v1alpha1 

**Starting with OpenShift AI 2.25, the v1alpha1 version is deprecated and planned for removal in an upcoming release. You must update the TrustyAI Operator to version v1 to receive future Operator **updates. 

Deprecated KServe Serverless deployment mode 

Starting with OpenShift AI 2.25, The KServe Serverless deployment mode is deprecated. You can continue to deploy models by migrating to the KServe RawDeployment mode. If you are upgrading to Red Hat OpenShift AI 3.0, all workloads that use the retired Serverless or ModelMesh modes must be migrated before upgrading. 

Deprecated model registry API v1alpha1 

**Starting with OpenShift AI 2.24, the model registry API version v1alpha1 is deprecated and will be removed in a future release of OpenShift AI. The latest model registry API version is v1beta1. **

Multi-model serving platform (ModelMesh) 

Starting with OpenShift AI version 2.19, the multi-model serving platform based on ModelMesh is deprecated. You can continue to deploy models on the multi-model serving platform, but it is recommended that you migrate to the single-model serving platform. 

For more information or for help on using the single-model serving platform, contact your account manager. 

Accelerator Profiles and legacy Container Size selector deprecated 

Starting with OpenShift AI 3.0, Accelerator Profiles and the Container Size selector for workbenches are deprecated. These features are replaced by the more flexible and unified Hardware Profiles capability. 

Deprecated OpenVINO Model Server (OVMS) plugin 

The CUDA plugin for the OpenVINO Model Server (OVMS) is now deprecated and will no longer be available in future releases of OpenShift AI. 

**OpenShift AI dashboard user management moved from OdhDashboardConfig to Auth resource **

**Previously, cluster administrators used the groupsConfig option in the OdhDashboardConfig **resource to manage the OpenShift groups (both administrators and non-administrators) that can access the OpenShift AI dashboard. Starting with OpenShift AI 2.17, this functionality has moved to **the Auth resource. If you have workflows (such as GitOps workflows) that interact with OdhDashboardConfig, you must update them to reference the Auth resource instead. **

Table 5.1. Updated configurations 

Resource 2.16 and earlier 2.17 and later versions 

**apiVersion opendatahub.io/v1alpha services.platform.opendatahub.io/ v1alpha1 **

**kind OdhDashboardConfig Auth **

**name odh-dashboard-config auth **

Admin groups **spec.groupsConfig.adminGroups spec.adminGroups **

User groups **spec.groupsConfig.allowedGroup s **

**spec.allowedGroups **

Deprecated cluster configuration parameters 

When using the CodeFlare SDK to run distributed workloads in Red Hat OpenShift AI, the following parameters in the Ray cluster configuration are now deprecated and should be replaced with the new parameters as indicated. 

Deprecated parameter Replaced by 

**head_cpus head_cpu_requests, head_cpu_limits **

**head_memory head_memory_requests, head_memory_limits **

**min_cpus worker_cpu_requests **

**max_cpus worker_cpu_limits **

**min_memory worker_memory_requests **

**max_memory worker_memory_limits **

**head_gpus head_extended_resource_requests **

**num_gpus worker_extended_resource_requests **

**You can also use the new extended_resource_mapping and overwrite_default_resource_mapping parameters, as appropriate. For more information about **these new parameters, see the CodeFlare SDK documentation  (external). 

5.2. REMOVED FUNCTIONALITY 

RStudio Server and CUDA - RStudio Server workbench images removed 

Starting with OpenShift AI 3.5, the RStudio Server and CUDA - RStudio Server workbench images have been removed from Red Hat OpenShift AI due to licensing compliance requirements. The existing RStudio images contained packages with incorrect AGPL license declarations and proprietary binaries that do not meet Red Hat open source standards. Running RStudio workbenches continue to operate after the upgrade, but you cannot create new RStudio workbenches or restart stopped ones from the dashboard. 

RStudio remains available in OpenShift AI 2.25, with an end of life date of October 5, 2026, and OpenShift AI 3.3, with an end of life date of April 26, 2027. 

To continue using RStudio on OpenShift AI 3.5 or later, you can build your own unsupported RStudio images by using the self-build recipes. For more information, see Building unsupported RStudio Server workbench images. 

To migrate to a supported IDE for R workflows, see Alternative IDEs for R workflows  and Set up R development in code-server or JupyterLab. 

Training images removed for Kubeflow Training Operator v1 

The following training runtime images for the Kubeflow Training Operator v1 (deprecated in OpenShift AI 3.4) have been removed: 

**registry.redhat.io/rhoai/odh-training-cuda121-torch24-py311-rhel9 **

**registry.redhat.io/rhoai/odh-training-cuda124-torch25-py311-rhel9 **

**registry.redhat.io/rhoai/odh-training-rocm62-torch24-py311-rhel9 **

**registry.redhat.io/rhoai/odh-training-rocm62-torch25-py311-rhel9 **If you currently use these images, update your job specifications to use the following replacement images: 

**registry.redhat.io/rhoai/odh-training-cuda128-torch29-py312-rhel9 **

**registry.redhat.io/rhoai/odh-training-rocm64-torch29-py312-rhel9 **

FIPSEnabled configuration field and separate FIPS binaries removed 

**The FIPSEnabled field in the DSPO configuration and the separate FIPS binaries launcher-v2-fips and argoexec-fips are removed. FIPS 140 mode is always enabled in Data Science Pipelines **component binaries through the Go native FIPS 140-3 module. All cryptographic operations in the API server, persistence agent, and launcher use FIPS 140-validated algorithms. External services that Data Science Pipelines connects to must support TLS 1.2 or later with standard cipher suites: AES-GCM, AES-CBC with SHA-256 or SHA-384, and ECDHE with P-256 or P-384. 

If you use external databases, object storage, or custom CA certificates, verify they meet the following requirements: 

External databases: Must support TLS 1.2 or later with FIPS-approved cipher suites. All modern MariaDB and MySQL versions and cloud-managed databases such as RDS, Cloud SQL, and Azure meet this requirement by default. 

External S3-compatible object storage: Must support TLS 1.2 or later. AWS S3, MinIO, Ceph, and GCS comply by default. 

Custom CA certificates: Certificates signed with MD5 or using RSA keys shorter than 2048 bits are rejected. Verify your certificate chain uses RSA 2048-bit keys or larger, or ECDSA P-256 or P-384, with SHA-256 or stronger signatures. FIPS enforcement applies only to Data Science Pipelines infrastructure components. User-authored pipeline steps and containers, operator-deployed MariaDB and MLMD instances, and Kubernetes API communication are not affected. If you previously configured **FIPSEnabled, remove this setting from your DSPO configuration. If you previously set FIPSEnabled to false to disable FIPS, note that FIPS is always enabled in this release; this is **not expected to cause issues for compliant external services. 

tf2onnx package removed from TensorFlow images 

**The tf2onnx package has been removed from TensorFlow workbench and runtime images. This **package, which converts TensorFlow models to ONNX format, was incompatible with Keras 3 (used **in TensorFlow 2.16+) and had irreconcilable dependency conflicts with protobuf versions required by onnx, tensorflow, and feast. The upstream project has been abandoned since January 2024. **If you require TensorFlow to ONNX conversion, see RHAIENG-1632 for alternative approaches. 

Caikit-NLP component removed 

**The caikit-nlp component has been formally deprecated and removed from OpenShift AI 3.0. **This runtime is no longer included or supported in OpenShift AI. Users should migrate any dependent workloads to supported model serving runtimes. 

TGIS component removed 

The TGIS component, which was deprecated in OpenShift AI 2.19, has been removed in OpenShift AI 3.0. TGIS continued to be supported through the OpenShift AI 2.16 Extended Update Support (EUS) lifecycle, which ended in June 2025. 

Starting with this release, TGIS is no longer available or supported. Users should migrate their model serving workloads to supported runtimes such as Caikit or Caikit-TGIS. 

AppWrapper Controller removed 

The AppWrapper controller has been removed from OpenShift AI as part of the broader CodeFlare Operator removal process. This change eliminates redundant functionality and reduces maintenance overhead and architectural complexity. 

CodeFlare Operator removed 

Starting with OpenShift AI 3.0, the CodeFlare Operator has been removed. 

The functionality previously provided by the CodeFlare Operator is now included in the KubeRay Operator, which provides equivalent capabilities such as mTLS, network isolation, and authentication. 

LAB-tuning feature removed 

Starting with OpenShift AI 3.0, the LAB-tuning feature has been removed. Users who previously relied on LAB-tuning for large language model customization should migrate to alternative fine-tuning or model customization methods. 

Embedded Kueue component removed 

The embedded Kueue component, which was deprecated in OpenShift AI 2.24, has been removed in OpenShift AI 3.0. OpenShift AI now uses the Red Hat Build of the Kueue Operator to provide enhanced workload scheduling across distributed training, workbench, and model serving workloads. 

The embedded Kueue component is not supported in any Extended Update Support (EUS) release. 

Removal of DataSciencePipelinesApplication v1alpha1 API version 

**The v1alpha1 API version of the DataSciencePipelinesApplication custom resource (datasciencepipelinesapplications.opendatahub.io/v1alpha1) has been removed. OpenShift AI now uses the stable v1 API version (datasciencepipelinesapplications.opendatahub.io/v1). **

**You must update any existing manifests or automation to reference the v1 API version to ensure **compatibility with OpenShift AI 3.0 and later. 

Microsoft SQL Server command-line tool removal 

Starting with OpenShift AI 2.24, the Microsoft SQL Server command-line tools (sqlcmd, bcp) have been removed from workbenches. You can no longer manage Microsoft SQL Server using the preinstalled command-line client. 

Model registry ML Metadata (MLMD) server removal 

Starting with OpenShift AI 2.23, the ML Metadata (MLMD) server has been removed from the model registry component. The model registry now interacts directly with the underlying database by using the existing model registry API and database schema. This change simplifies the overall architecture and ensures the long-term maintainability and efficiency of the model registry by transitioning from **the ml-metadata component to direct database access within the model registry itself. **If you see the following error for your model registry deployment, this means that your database schema migration has failed: 

error: error connecting to datastore: Dirty database version {version}. Fix and force version. 

You can fix this issue by manually changing the database from a dirty state to 0 before traffic can be routed to the pod. Perform the following steps: 

1. Find the name of your model registry database pod as follows: **kubectl get pods -n <your-namespace> | grep model-registry-db **

**Replace <your-namespace> with the namespace where your model registry is deployed. **

**2. Use kubectl exec to run the query on the model registry database pod as follows: **

**kubectl exec -n <your-namespace> <your-db-pod-name> -c mysql -- mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "USE <your-db-name>; UPDATE schema_migrations SET dirty = 0;" **

**Replace <your-namespace> with your model registry namespace and <your-db-pod-name> with the pod name that you found in the previous step. Replace <your-db-name> **with your model registry database name. 

This will reset the dirty state in the database, allowing the model registry to start correctly. 

Embedded subscription channel not used in some versions 

**For OpenShift AI 2.8 to 2.20 and 2.22 to 3.5, the embedded subscription channel is not used. You cannot select the embedded channel for a new installation of the Operator for those versions. For **more information about subscription channels, see Installing the Red Hat OpenShift AI Operator . 

Anaconda removal 

Anaconda is an open source distribution of the Python and R programming languages. Starting with OpenShift AI version 2.18, Anaconda is no longer included in OpenShift AI, and Anaconda resources are no longer supported or managed by OpenShift AI. If you previously installed Anaconda from OpenShift AI, a cluster administrator must complete the following steps from the OpenShift command-line interface to remove the Anaconda-related artifacts: 

1. Remove the secret that contains your Anaconda password: **oc delete secret -n redhat-ods-applications anaconda-ce-access **

**2. Remove the ConfigMap for the Anaconda validation cronjob: oc delete configmap -n redhat-ods-applications anaconda-ce-validation-result **

3. Remove the Anaconda image stream: **oc delete imagestream -n redhat-ods-applications s2i-minimal-notebook-anaconda **

4. Remove the Anaconda job that validated the downloading of images: **oc delete job -n redhat-ods-applications anaconda-ce-periodic-validator-job-custom-run **

5. Remove any pods related to Anaconda cronjob runs: **oc get pods n redhat-ods-applications --no-headers=true | awk '/anaconda-ce-periodic-validator-job-custom-run*/' **

Pipeline logs for Python scripts running in Elyra pipelines are no longer stored in S3 

Logs are no longer stored in S3-compatible storage for Python scripts which are running in Elyra pipelines. From OpenShift AI version 2.11, you can view these logs in the pipeline log viewer in the OpenShift AI dashboard. 

NOTE 

For this change to take effect, you must use the Elyra runtime images provided in workbench images at version 2024.1 or later. 

If you have an older workbench image version, update the Version selection field to a compatible workbench image version, for example, 2024.1, as described in Updating a project workbench . 

Updating your workbench image version will clear any existing runtime image selections for your pipeline. After you have updated your workbench version, open your workbench IDE and update the properties of your pipeline to select a runtime image. 

Beta subscription channel no longer used 

**Starting with OpenShift AI 2.5, the beta subscription channel is no longer used. You can no longer select the beta channel for a new installation of the Operator. For more information about **subscription channels, see Installing the Red Hat OpenShift AI Operator . 

HabanaAI workbench image removal 

Support for the HabanaAI 1.10 workbench image has been removed. New installations of OpenShift AI from version 2.14 do not include the HabanaAI workbench image. However, if you upgrade OpenShift AI from a previous version, the HabanaAI workbench image remains available, and existing HabanaAI workbench images continue to function. 

### CHAPTER 6. RESOLVED ISSUES

The following notable issues are resolved in Red Hat OpenShift AI 3.5 GA, 3.5 EA2, and 3.5 EA1. Security updates, bug fixes, and enhancements for Red Hat OpenShift AI 3.5 GA, 3.5 EA2, and 3.5 EA1 are released as asynchronous errata. 

All OpenShift AI errata advisories are published on the Red Hat Customer Portal . 

6.1. ISSUES RESOLVED IN RED HAT OPENSHIFT AI 3.5 GA 

RHOAIENG-70232 - vLLM CPU model serving fails on IBM Z (s390x) during model warmup 

Previously, on IBM Z, vLLM CPU model serving failed during model warmup due to a GCC version incompatibility. The vLLM container image included GCC 11.5.0, but PyTorch 2.11.0 required GCC 14 for JIT compilation features. As a consequence, the Torch Inductor C++ compilation step failed and the model did not load. 

This issue is now resolved. 

RHOAIENG-80354 - Perses observability dashboards fail to load in the OpenShift AI dashboard 

Previously, after deploying OpenShift AI 3.5 with Cluster Observability Operator (COO) monitoring configured, the Perses proxy was not automatically set up. The Operator did not project the **observability configuration from DataScienceClusterInitialization into the Dashboard custom resource **(CR). As a consequence, navigating to Observe & Monitor in the OpenShift AI dashboard showed the error "Unable to reach observability dashboards" because frontend requests to the Perses API returned HTML instead of JSON. 

This issue is now resolved. 

RHOAIENG-65203 - Model Car (OCI) deployment fails for ONNX models with external data 

Before this update, when you used the Model Car (OCI image) method to deploy an ONNX model split **into model.onnx and model.onnx.data files, the MLServer runtime container could not access the **external data file. The Model Car sidecar container exposed files by using cross-container symlinks instead of a shared volume, so the system could not load the model. Single-file model formats, such as SKLEARN, XGBoost, and LightGBM, were not affected. 

This issue is now resolved. 

RHOAIENG-62527 - RayJobs in the dashboard are missing a hyperlink to the Ray dashboard 

Previously, when you created a RayJob, the Ray cluster name displayed in the OpenShift AI dashboard was plain text and did not include a hyperlink to the Ray cluster dashboard. 

This issue is now resolved. The Ray cluster name under a RayJob is now a hyperlink to the Ray dashboard. 

RHOAIENG-65143 - Models-as-a-Service UI does not detect custom gateway hostname 

Previously, when the Models-as-a-Service (MaaS) gateway was configured with a custom hostname **instead of the default maas.apps.<cluster_domain> pattern, the MaaS UI Backend-for-Frontend **(BFF) service did not detect the custom hostname. The BFF service constructed the MaaS API URL by using the cluster’s external ingress domain, which failed when a custom gateway domain was in use or when the cluster was disconnected, making MaaS features unavailable in the OpenShift AI dashboard. 

This issue is now resolved. Through fixes implemented in RHOAIENG-69335 and RHOAIENG-78980, the MaaS UI BFF service now fetches the gateway domain directly from the MaaS API rather than cluster ingress, and no longer crashes at startup when the MaaS API is not installed. 

**+ NOTE: If an administrator changes the gateway URL after the maas-ui has discovered a previous URL, you must restart the maas-ui pods to detect the new gateway URL. **

RHOAIENG-74715 - DataScienceCluster status incorrectly reported aigateway module as not ready 

**Previously, when you enabled the aigateway component in the DataScienceCluster (DSC) custom resource, the DSC status might incorrectly report Ready: False with the message "Some modules are not ready: aigateway". This occurred because the status of the aigateway module did not propagate correctly, even when the AIGateway custom resource was fully provisioned and functional. **

**This issue is now resolved. The DSC status now correctly syncs with and reflects the Ready status of the aigateway component. **

RHOAIENG-60855 - Upgrade error: OGX Operator produces invalid Deployment when storage is configured 

Previously, when you upgraded OpenShift AI from 3.3 to 3.4, the Llama Stack Operator could fail to **reconcile an existing LlamaStackDistribution custom resource that included persistent storage, for example, spec.server.storage.size: 2Gi. After a change that set the Deployment strategy to Recreate for ReadWriteOnce storage, the Operator left the previous rollingUpdate fields in place. Kubernetes rejected the Deployment because spec.strategy.type: Recreate and spec.strategy.rollingUpdate **cannot be set together. 

**This issue no longer applies to the 3.3 to 3.4 LlamaStackDistribution upgrade path. OpenShift AI 3.5 uses the OGXServer custom resource, which creates a new Deployment instead of patching the LlamaStackDistribution Deployment that caused the conflict. **

**If you create an OGXServer without persistent storage and later add spec.workload.storage, the same **error can still occur. This remaining case is fixed in OpenShift AI 3.6 EA1. 

6.2. ISSUES RESOLVED IN RED HAT OPENSHIFT AI 3.5 EA2 

RHOAIENG-66859 - Evaluation jobs fail to complete with an MLflow experiment configured 

Before this update, when you submitted an evaluation job with a configured MLflow experiment, the evaluation adapter failed after the evaluation completed successfully while trying to save results to MLflow. As a consequence, the evaluation remained indefinitely in a running state and did not report completion. 

With this update, the issue is resolved. 

6.3. ISSUES RESOLVED IN RED HAT OPENSHIFT AI 3.5 EA1 

RHOAIENG-59801 - Inconsistent resource limits when creating workloads with hardware profiles via API or CLI 

Before this update, when you created a workbench or model deployment with a hardware profile using the API or CLI without pre-populating container resources, the operator webhook set the resource limit **to the maxCount value defined in the hardware profile instead of the defaultCount value. This caused **inconsistent resource allocation compared to workloads created through the dashboard. 

This issue is resolved. 

RHAIENG-3816 - Encrypted PDF uploads to Llama Stack vector stores fail on FIPS-enabled clusters 

Before this update, on FIPS-enabled clusters, registering certain encrypted PDF files into Llama Stack vector stores failed because the underlying PDF parsing library used an MD5-based digest that is not allowed in FIPS mode. 

This issue is resolved. 

RHOAIENG-50523 - Unable to upload RAG documents in Gen AI Playground on disconnected clusters 

Before this update, on disconnected clusters, uploading documents in the Gen AI Playground RAG **section failed because Llama Stack attempted to download the ibm-granite/granite-embedding-125m-english embedding model from HuggingFace, even though the model was already included in the **Llama Stack Distribution image. 

This issue is resolved. 

RHOAIENG-49017 - Upgrade RAGAS provider to Llama Stack 0.4.z / 0.5.z 

Before this update, using the RAGAS evaluation provider required manually updating the Llama Stack **distribution to use a specific workaround version of llama-stack-provider-ragas due to compatibility **issues with newer Llama Stack versions. 

This issue is resolved. 

AIPCC-13675 - Feast and other python packages fail to start in workbench notebooks on IBM Z (s390x) 

Before this update, when you start a workbench on IBM Z (s390x) systems, a segmentation fault (exit code 139) occurs during startup and the application stops. This issue occurs because the Protocol Buffers (protobuf) UPB C extension is not fully compatible with the s390x architecture. When you use this extension as the default protobuf implementation, the system crashes. 

This issue is resolved. 

### CHAPTER 7. KNOWN ISSUES

Understand how newly identified and previously known issues might affect your use of Red Hat OpenShift AI, and how to work around them. 

7.1. ISSUES DISCOVERED AT VERSION 3.5 GA 

RHOAIENG-87834 - Kueue-managed TrainJobs are not scheduled when using Red Hat Build of Kueue 1.4 or later 

**In OpenShift AI 3.5, TrainJob resources managed by Kueue are not scheduled when using Red Hat Build of Kueue (RHBoK) 1.4 or later with TrainJob support enabled. The affected TrainJob remains **suspended after being admitted by Kueue. 

This issue affects the integration between Kubeflow Trainer v2 and Kueue. 

Workaround 

Use RHBoK 1.3 with Kubeflow Trainer v2. 

RHOAIENG-87625 - Kubeflow Trainer v2 is not compatible with Red Hat Build of Kueue 1.4 or later 

The Kubeflow Trainer v2 component in OpenShift AI 3.5 is not compatible with Red Hat Build of Kueue (RHBoK) 1.4 or later. Kubeflow Trainer v2 continues to function, but the integration between Kubeflow Trainer v2 and Kueue is broken if RHBoK is upgraded to version 1.4 or later. 

Workaround 

If you use Kubeflow Trainer v2 with Kueue, keep RHBoK at version 1.3 or earlier and do not upgrade to RHBoK 1.4 or later. 

NOTE 

OpenShift AI 3.5 currently requires RHBoK 1.3 for Kubeflow Trainer v2 integration with Kueue, even though RHBoK 1.3 is no longer supported. In addition, RHBoK 1.3 is not available with OpenShift Container Platform 4.22. 

RHOAIENG-82694 - MCP Lifecycle Operator memory consumption might cause the operator to fail 

**The MCP Lifecycle Operator watches all ConfigMaps and Secrets cluster-wide by using full structured **informers, loading complete object data into the operator’s in-memory cache. As a consequence, **memory consumption grows proportionally to the number of cluster-wide Secrets and ConfigMaps, **causing the operator to fail with an out-of-memory error on large clusters even when no MCP servers are deployed. 

Workaround 

No known workaround exists. 

**RHOAIENG-85220 - “Legacy deployment” wording is misleading for generative InferenceService **deployments 

**In the OpenShift AI model deployment UI, generative model deployments that use an InferenceService with a ServingRuntime display a Legacy deployment label. This wording might incorrectly suggest that **this deployment method is being removed or is no longer supported. 

**Support for generative deployments that use an InferenceService with a ServingRuntime has not **changed. However, for generative workloads, the recommended approach is to use **LLMInferenceService, which provides additional capabilities and enables models to transition to the **Models-as-a-Service (MaaS) infrastructure. 

**Predictive workloads are not affected by this wording and continue to use InferenceService with ServingRuntime deployments. **

Workaround 

**No workaround is required. You can continue to use InferenceService with ServingRuntime **deployments. Improved wording in the model deployment UI is planned for a future release. 

RHOAIENG-66855 - Distributed Inference with llm-d deployment through the dashboard selects CUDA image instead of ROCm for AMD hardware profiles 

When you deploy a model through the OpenShift AI dashboard by using distributed inference with **Distributed Inference with llm-d with AMD hardware profiles, such as mi300x, the deployment incorrectly uses the CUDA runtime image instead of the ROCm image. The LLMInferenceService **controller does not detect AMD GPU resources and instead assigns the default template, which results in the CUDA image being used instead of the ROCm-specific image. 

As a consequence, the pod fails to start on AMD hardware. 

Workaround 

**Deploy the LLMInferenceService by using a YAML manifest with the ROCm image explicitly **specified in the container spec. Alternatively, for non-Distributed Inference with llm-d vLLM deployments, manually select the "vLLM AMD GPU ServingRuntime for KServe" option in the dashboard, which correctly uses the AMD-specific image. 

7.2. ISSUES DISCOVERED AT VERSION 3.5 EA2 

RHOAIENG-76586 - Rate limiting stops working with Red Hat Connectivity Link 1.4.x 

When you use Red Hat Connectivity Link (RHCL) 1.4.0 or 1.4.1 with batch gateway deployments, rate limiting silently stops functioning. RHCL 1.4 changed how the wasm plugin is injected, which breaks the automatic passing of authentication identity data into the wasm plugin context. As a result, rate limit **counters that use auth.identity.user.username fail silently, and requests are never rate limited. Additionally, gateway pods can crash with OOMKilled errors because the RHCL 1.4 wasm plugin requires **more memory to compile than the default 1Gi limit. 

Workaround 

Use RHCL 1.3.5 for batch gateway deployments. RHCL 1.3.5 works without additional configuration. If your cluster already has RHCL 1.4.x installed, apply both of the following workarounds: 

**1. Increase gateway pod memory to 2Gi. Create a ConfigMap with a memory override and link it to the gateway by using infrastructure.parametersRef: **

$ oc apply -f - <<EOF apiVersion: v1 kind: ConfigMap metadata:   name: <gateway-name>-proxy-config   namespace: openshift-ingress data: 

where: 

**<gateway-name> **

**Specifies the name of the gateway, for example openshift-ai-inference or batch-internal-gateway. **

**1. Add an identity filter to your AuthPolicy to populate the wasm plugin identity context. Add a response.success.filters.identity section to your AuthPolicy: **

**The filters.identity section tells Authorino to write the authenticated user identity into the wasm plugin context. Without it, rate limit counters that use auth.identity.user.username **fail and rate limiting is silently skipped. 

**2. If you have a batch-route AuthPolicy with a RateLimitPolicy counter that uses auth.identity.user.username, add the same identity filter to the batch-route AuthPolicy: **

  deployment: |     spec:       template:         spec:           containers:           - name: istio-proxy             resources:               limits:                 memory: 2Gi EOF 

$ oc patch gateway <gateway-name> -n openshift-ingress --type=merge \   -p '{"spec":{"infrastructure":{"parametersRef":{"group":"","kind":"ConfigMap","name":" <gateway-name>-proxy-config"}}}}' 

spec:   rules:     response:       success:         filters:           identity:             json:               properties:                 userid:                   expression: auth.identity.user.username                 user:                   expression: auth.identity.user             metrics: false             priority: 0 

$ BATCH_NS=batch-api $ oc apply -f - <<EOF apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata:   name: batch-route-auth   namespace: ${BATCH_NS} spec:   targetRef: 

After applying all steps, verify that rate limiting works: 

**If rate limiting is working, one of the requests returns a 429 status code. **

RHOAIENG-73389 - Prefix caching causes inference scheduler crash for models requiring transformers 5.x 

**The tokenizer sidecar odh-llm-d-kv-cache-rhel9 ships transformers 4.57.6, which does not recognize **model architecture types added in transformers 5.x. As a consequence, deploying these models with **precise-prefix-cache-scorer enabled causes the inference scheduler to crash. Affected models include **Gemma 4, GLM-5, Qwen3.5 MoE, and other models with architecture types added after the transformers 4.x series. 

Workaround 

    group: gateway.networking.k8s.io     kind: HTTPRoute     name: batch-route   rules:     authentication:       kubernetes-user:         kubernetesTokenReview:           audiences:           - https://kubernetes.default.svc         metrics: false         priority: 0     response:       success:         filters:           identity:             json:               properties:                 userid:                   expression: auth.identity.user.username                 user:                   expression: auth.identity.user             metrics: false             priority: 0 EOF 

$ GW_HOSTNAME=$(oc get gateway openshift-ai-inference -n openshift-ingress \     -o jsonpath='{.spec.listeners[0].hostname}') $ TOKEN=$(oc create token test-authorized-sa -n llm \     --audience=https://kubernetes.default.svc --duration=10m) $ for i in $(seq 1 20); do     code=$(curl -sk -o /dev/null -w '%{http_code}' \         "https://${GW_HOSTNAME}/llm/facebook-opt-125m/v1/chat/completions" \         -H "Content-Type: application/json" \         -H "Authorization: Bearer ${TOKEN}" \         -d '{"model":"facebook/opt-125m","messages": [{"role":"user","content":"Hi"}],"max_tokens":100}')     echo "Request $i: $code"     [ "$code" = "429" ] && echo "Rate limiting is working!" && break done 

**Disable precise-prefix-cache-scorer in the EndpointPickerConfig when using these models. **

7.3. ISSUES DISCOVERED AT VERSION 3.5 EA1 

**RHOAIENG-66068 - The OpenShift AI dashboard only supports an EvalHub instance in the redhat-ods-applications namespace **

The Backend-for-Frontend (BFF) service always looks for the MLflow multi-tenant instance in its own **redhat-ods-applications, regardless of where the cluster administrator has deployed it. As a **consequence, the OpenShift AI dashboard reports that evaluations are not enabled when the multitenant instance is hosted in a different namespace. 

Workaround 

**Deploy the MLflow multi-tenant instance in the redhat-ods-applications. As a result, the BFF **service correctly detects the instance and the evaluations feature is available in the dashboard. Note that others instances will work, but will not be discoverable from the OpenShift AI dashboard. 

RHOAIENG-67534 - A new evaluation run fails in the OpenShift AI dashboard 

**If the MLflow custom resource (CR) is created after the Evaluations CR, the workspaces_enabled setting is set to false. As a result, creating a new evaluation run in the OpenShift AI dashboard fails with an INVALID_PARAMETER_VALUE error: "Workspace context is required for this request." **

Workaround 

**Create the MLflow CR before the Evaluations CR is created. This ensures the workspaces_enabled setting is correctly set to true, and evaluation runs can be created successfully. **

AIPCC-18235 - Structured output (JSON Schema) generation fails on IBM Z (s390x) with llguidance backend 

When you use the llguidance structured decoding backend on IBM Z (s390x), JSON schemaconstrained generation may produce invalid output or become stuck generating whitespace indefinitely. 

Workaround 

A fix is available in llguidance version 1.7.0 and later. Update your wheel from version 1.3.0 to at least version 1.7.0 for this fix. 

AIPCC-17927 - vLLM crashes when multiple requests are inflight with structured outputs 

When you send multiple inference requests in parallel to a vLLM-based inference server and at least one request includes structured output, the service stops responding, causing the pod to fail. As a result, concurrent workloads that use structured outputs do not function as expected. 

Workaround 

To prevent the service from failing, apply one of the following workarounds: 

Process requests sequentially instead of sending multiple parallel requests that include structured output in the same batch. 

Exclude structured output requests when you run concurrent workloads. 

7.4. ISSUES DISCOVERED AT VERSION 3.4 GA 

**RHOAIENG-83207 - Secure Models-as-a-Service gateway requires namespace labeling for edhat-ods-applications **

When you deploy a secure Models-as-a-Service (MaaS) gateway that restricts route attachment by **namespace selector, you must also label the redhat-ods-applications namespace. OpenShift AI creates an internal HTTPRoute in that namespace to serve the MaaS API. Without the label, the gateway rejects **the route and the API Keys page in the dashboard displays "Error loading components." 

Workaround 

Label the namespace so that the gateway accepts the route: 

RHOAIENG-80360 - Insecure Models-as-a-Service gateway configuration can allow unauthorized route hijacking 

When creating the Gateway for Models-as-a-Service (MaaS) or Distributed Inference with llm-d, do not **use default settings such as allowedRoutes.namespaces.from: All. Such a configuration permits any namespace on the cluster to attach HTTPRoutes to the shared model-serving Gateway. Because the **Kubernetes Gateway API prioritizes exact path matches over the prefix matches used by MaaS, a user **with standard namespace-level permissions can create an HTTPRoute that silently intercepts and **hijacks traffic intended for a legitimate model endpoint. This allows unauthorized interception of sensitive data, such as API keys, user prompts, and model responses, without requiring elevated privileges. 

Workaround 

For details on how to detect unauthorized routes and apply a secure, label-based namespace configuration, see Insecure Models-as-a-Service gateway configuration can allow unauthorized route hijacking in Red Hat OpenShift AI. 

RHOAIENG-67403: Hardware profiles with Node selectors and tolerations are unavailable for workbenches after enabling Kueue 

**When the Kueue component is set to unmanaged in the DataScienceCluster custom resource, **hardware profiles configured with "Node selectors and tolerations" as their workload allocation strategy are not available for selection when you create a workbench. Currently, only hardware profiles configured to use a local queue are available. 

INFERENG-6962 - Distributed Inference with llm-d EndpointPicker is bypassed when multiple HTTPRoutes share the same gateway listener 

**When multiple HTTPRoutes are attached to the same wildcard Gateway listener, Istio aggregates them into a single autogenerated Gateway VirtualService and does not create the per-route ExtProcPerRoute override for the LLMInferenceService. This causes the EndpointPicker to be **bypassed entirely. Requests fall back to round-robin routing; prefix cache scoring, load-aware scoring, and all intelligent scheduling are silently disabled. 

**This behavior is not specific to multiple LLMInferenceServices and is triggered by any HTTPRoute on **the same wildcard Gateway listener, such as a token endpoint, echo service, or test route. 

**You can identify this issue by checking the EndpointPicker logs, which might show no per-request activity, even at verbosity level 6 or 7. Additionally, the gateway ext_proc filter shows cluster_name: "dummy" and request_header_mode: SKIP with no per-route override applied. **

$ oc label namespace redhat-ods-applications maas-gateway-access=true 

**This affects Istio 1.26, deployed by openshift-ingress in OSSM 3.3.x and 3.4. The upstream fix is in Istio **1.29. The following issue is related: OSSM-12585. 

Workaround 

**Remove or reassign any non-LLMInferenceService HTTPRoutes from the inference Gateway. Move them to a separate Gateway so the LLMInferenceService HTTPRoute is the only consumer **of the wildcard listener. 

RHOAIENG-71638 - Models-as-a-Service returns HTTP 500 errors under high concurrent request load 

Red Hat Connectivity Link (RHCL) configures the Kuadrant WASM plugin with a default authentication service timeout of 200 ms. Under high concurrent request load, Authorino authentication latency can **exceed this threshold when cache misses occur. Because the WASM plugin uses failureMode: deny, **timed-out authentication requests result in HTTP 500 or 503 responses to clients, even when model backends are healthy. 

This issue affects Red Hat OpenShift AI 3.4 and 3.5. 

Workaround 

**Set AUTH_SERVICE_TIMEOUT to 2s on the RHCL operator Subscription: **

**1. Set the Subscription name and namespace for your installation: **

**2. Patch the Subscription to set AUTH_SERVICE_TIMEOUT to 2s. Use the command that matches your Subscription configuration: **

**If spec.config.env already exists on the Subscription, append the timeout value: **

**If spec.config exists but spec.config.env does not, add the env array: **

**If the Subscription does not have a spec.config section, create it: **

**3. After patching the Subscription, wait for the operator to roll out: **

$ RHCL_NAMESPACE=rh-connectivity-link $ RHCL_SUBSCRIPTION=rhcl-operator 

$ oc patch subscription "${RHCL_SUBSCRIPTION}" -n "${RHCL_NAMESPACE}" \   --type='json' \   -p='[{"op":"add","path":"/spec/config/env/-","value": {"name":"AUTH_SERVICE_TIMEOUT","value":"2s"}}]' 

$ oc patch subscription "${RHCL_SUBSCRIPTION}" -n "${RHCL_NAMESPACE}" \   --type='json' \   -p='[{"op":"add","path":"/spec/config/env","value": [{"name":"AUTH_SERVICE_TIMEOUT","value":"2s"}]}]' 

$ oc patch subscription "${RHCL_SUBSCRIPTION}" -n "${RHCL_NAMESPACE}" \   --type='json' \   -p='[{"op":"add","path":"/spec/config","value":{"env": [{"name":"AUTH_SERVICE_TIMEOUT","value":"2s"}]}}]' 

$ oc wait --for=jsonpath='{.status.state}'=AtLatestKnown \ 

4. Retest the concurrent workload to verify that HTTP 500 or 503 errors no longer occur. 

7.5. ISSUES DISCOVERED AT VERSION 3.4 EA2 

RHOAIENG-58765 - Distributed Inference with llm-d prefill and decode disaggregation fails on FIPS-enabled clusters 

Using Distributed Inference with llm-d prefill and decode disaggregation for LLM deployments on FIPS-enabled clusters causes the routing sidecar pod to enter a crash loop, preventing the LLM deployment from functioning. This issue is caused by a runtime image introduced in the 3.4 EA2 release that is not FIPS-compatible. 

Workaround 

Do not use prefill and decode disaggregation with Distributed Inference with llm-d in Red Hat OpenShift AI 3.4 EA2 on FIPS-enabled clusters. Other features continue to work correctly on FIPS-enabled clusters. 

RHOAIENG-57224 - ROCm universal image training produces NaN on MI300X due to torch aotriton 0.11.1 regression 

ROCm universal training image (th06) produces NaN values on MI300X due to aotriton 0.11.1 regression in AIPCC-built PyTorch wheel. 

Workaround 

**Use th05 image or set attn_implementation="flash_attention_2". **

RHOAIENG-57427 - RAG in Gen AI Playground doesn’t work with default system prompt and model Qwen/Qwen3-14B-AWQ 

In Gen AI Playground RAG, the default system prompt might not reliably trigger the knowledge search/tool-calling behavior for some models, so document retrieval is not performed. Due to this, questions about uploaded documents can return answers without using the vector store, resulting in incomplete/incorrect responses unless the prompt is adjusted. 

Workaround 

Manually edit the system prompt to explicitly instruct the model to use the knowledge search tool first for document-based/factual questions (as documented in the Gen AI Playground RAG documentation). As a result, after updating the system prompt, RAG retrieval works and the model can answer based on the uploaded document content. 

RHOAIENG-54005 - Generate MaaS Token Endpoint Removed - breaks Gen AI Studio Playground 

**The /v1/token API was removed and this endpoint was merged in with the new post creation of /v1/api-keys. As a result, Gen AI Playground cannot generate a token on the fly for MaaS and cannot talk to **MaaS Models in 3.4 EA2. 

Workaround 

There is no existing workaround for this known issue. As a result, there is no access to MaaS and Playground in 3.4 EA2. 

  subscription/${RHCL_SUBSCRIPTION} -n ${RHCL_NAMESPACE} --timeout=300s $ oc wait --for=condition=Available --timeout=120s \   deployment/kuadrant-operator-controller-manager -n ${RHCL_NAMESPACE} 

RHOAIENG-48753 - Pipeline Name must be DNS-compliant to use "Store pipeline definitions in Kubernetes" 

Elyra does not convert the pipeline name to a DNS-compliant name when using the default Kubernetes storage. As a consequence, if you don’t use a DNS-compliant name when you start an Elyra pipeline, it *gives a cryptic error "[TIP: did you mean to set https://ds-pipeline-dspa-robert-tests.apps.test.rhoai.rh-aiservices-bu.com/pipeline as the endpoint, take care not to include s at end]". *

Workaround 

Use DNS-compliant naming when running Elyra pipelines. 

7.6. ISSUES DISCOVERED AT VERSION 3.4 EA1 

RHOAIENG-54101 - Deployments not listed in Model Registry on IBM Z 

When you deploy a model from the Model Registry on IBM Z, the deployment does not appear under the Deployments tab in the Model Registry. 

Workaround 

Access and manage the deployment from the global Deployments page in the OpenShift AI dashboard. 

**RHOAIENG-53206 - Spark driver pods fail to communicate due to RpcTimeoutException **

After installing the Spark Operator, Spark executor pods cannot communicate with the driver pod **because the redhat-ods-applications namespace defaults to a "deny-all" traffic rule. SparkApplication pods hang and fail with an RpcTimeoutException. **

Workaround 

**Create a NetworkPolicy in the redhat-ods-applications namespace to allow communication **between the pods created by the SparkApplication controller: 

apiVersion: networking.k8s.io/v1 kind: NetworkPolicy metadata:   name: spark-operator-allow-internal spec:   podSelector:     matchLabels:       sparkoperator.k8s.io/launched-by-spark-operator: "true"   policyTypes:     - Ingress   ingress:     - ports:         - port: 7078           protocol: TCP         - port: 7079           protocol: TCP         - port: 4040           protocol: TCP       from:         - podSelector: {}         - namespaceSelector:             matchLabels:               network.openshift.io/policy-group: ingress 

RHOAIENG-52130 - Workbenches with Feast integration fail to start due to missing ConfigMap 

Workbenches with Feast integration enabled fail to start in OpenShift AI 3.4 EA1. Pods remain stuck in **ContainerCreating state with the following error: **

[FailedMount] [Warning] MountVolume.SetUp failed for volume "odh-feast-config"   configmap "jupyter-nb-kube-3aadmin-feast-config" not found 

Workaround 

Restart the Feast Operator after DSC deployment completes: 

RHOAIENG-53239 - Custom ServingRuntime required for IBM Z (s390x) vLLM Spyre deployments 

When deploying models using the vLLM Spyre runtime on IBM Z (s390x) systems, the default ServingRuntime cannot be used directly for KServe-based deployments. Model deployment fails if the runtime is used without modification. 

Workaround 

**Create a custom ServingRuntime by duplicating the vllm-spyre-s390x-runtime ServingRuntime and removing the command section from the container specification. Keep all other configuration, **including environment variables, ports, and volume mounts, unchanged. The following example shows only the affected section. Your complete ServingRuntime must include all other fields from the original template: 

$ kubectl rollout restart deployment/feast-operator-controller-manager -n redhat-ods-applications 

apiVersion: serving.kserve.io/v1alpha1 kind: ServingRuntime metadata:   name: vllm-spyre-s390x-runtime-copy spec:   containers:     - name: kserve-container       image: <image>       # Remove the 'command' section that appears here in the original       args:         - --model=/mnt/models         - --port=8000         - --served-model-name={{.Name}} *      # ... keep all env, ports, volumeMounts from original ... *

### CHAPTER 8. PRODUCT FEATURES

Red Hat OpenShift AI provides a rich set of features for data scientists and cluster administrators. To learn more, see Introduction to Red Hat OpenShift AI . 