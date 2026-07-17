# What's New in Red Hat OpenShift AI 3.3

**Last Updated:** March 2026

This document summarizes the new features, enhancements, technology preview features, deprecations, and important changes in Red Hat OpenShift AI (RHOAI) 3.3.

## Table of Contents

- [Installation and Upgrade Path](#installation-and-upgrade-path)
- [New Features (GA)](#new-features-ga)
- [Enhancements](#enhancements)
- [Technology Preview Features](#technology-preview-features)
- [Deprecations](#deprecations)
- [Removed Functionality](#removed-functionality)
- [Key Resolved Issues](#key-resolved-issues)
- [Known Issues](#known-issues)
- [Breaking Changes](#breaking-changes)

---

## Installation and Upgrade Path

| Scenario | Guidance |
|----------|----------|
| **New Installations** | Install on OpenShift 4.19+ and select the `fast-3.x` channel |
| **Upgrading from 3.2** | Fully supported upgrade path |
| **Migrating from 2.x** | Direct upgrades from 2.25 or earlier to 3.3 are **not supported** due to architectural changes. Migration support planned for future release. |

---

## New Features (GA)

### 1. Kubeflow Trainer v2 (Generally Available)

Kubeflow Trainer v2 is now GA in RHOAI 3.3, **replacing** the Kubeflow Training Operator v1 (KFTOv1).

**What Changed:**
| Aspect | Training Operator v1 (Old) | Trainer v2 (New) |
|--------|---------------------------|------------------|
| API | PyTorchJob, TFJob, etc. | Unified **TrainJob** API |
| Runtimes | Custom per-framework | Pre-built **ClusterTrainingRuntimes** |
| SDK | Training Operator SDK | **Kubeflow Python SDK** |
| Status | **Deprecated** | **GA in 3.3** |

**Key Benefits:**
- Kubernetes-native solution for distributed training
- Unified `TrainJob` API for simplified job management
- Pre-built `ClusterTrainingRuntimes` for common use cases
- Kubeflow Python SDK integration
- Simplified PyTorch training workloads at scale

**Migration Note:** 
- Kubeflow Training Operator v1 is deprecated (since 2.25)
- Training images and ClusterTrainingRuntimes for v1 will be deprecated in **RHOAI 3.4**
- New runtimes and images for Trainer v2 will be provided in 3.4 with migration guidance

### 2. IBM Spyre AI Accelerator Support (GA)

Model serving with IBM Spyre AI accelerators is now Generally Available on IBM Power platform.

**Features:**
- Automated installation via IBM Spyre Operator
- Device plugin integration
- Secondary scheduler support
- Built-in monitoring tools

### 3. Model Catalog Allow/Disallow Lists

New administrative capability to control model visibility in the catalog.

**Capabilities:**
- Selectively hide specific models
- Create disallow lists for compliance
- Remove models from visible catalog
- Enforce internal security and regulatory restrictions

### 4. SDG Hub (Synthetic Data Generation Hub)

A modular Python framework for building synthetic data generation pipelines.

**Key Features:**
- **Composable blocks and flows** - Each block performs specific tasks (LLM chat, parse text, evaluate, transform)
- **YAML-based pipeline definitions** - Declarative specification for data generation algorithms
- **RAG evaluation flow** - Generate question-answer pairs with ground truth for RAGAS framework
- **Kubeflow Pipeline integration** - Run SDG pipelines at scale on OpenShift AI
- **Extensible architecture** - Add custom blocks for domain-specific needs

**Use Cases:**
- Knowledge tuning data generation
- RAG system evaluation data
- Domain-specific model customization

**Repository:** `https://github.com/Red-Hat-AI-Innovation-Team/sdg_hub.git`

### 5. Training Hub

An algorithm-focused interface for LLM training, fine-tuning, and continual learning.

**Supported Algorithms:**
| Algorithm | Description |
|-----------|-------------|
| **SFT** | Supervised Fine-Tuning |
| **OSFT** | Orthogonal Subspace Fine-Tuning (Red Hat's continual learning algorithm) |
| **LoRA** | Low-Rank Adaptation |
| **QLoRA** | Quantized Low-Rank Adaptation |

**Key Features:**
- **Unified API** - Single interface across multiple training backends
- **Memory estimation** - Tools to estimate GPU memory requirements
- **Distributed training** - Integration with **Kubeflow Trainer v2** (the new GA replacement for Training Operator v1)
- **Pre-built runtimes** - ClusterTrainingRuntimes for common scenarios
- **Cookbooks** - Example notebooks for each algorithm

**Architecture:**
```
┌─────────────────────────────────────────┐
│       Training Hub (Python API)          │  ← User-facing library
├─────────────────────────────────────────┤
│         Kubeflow Trainer v2              │  ← Orchestration (GA in 3.3)
│    (TrainJob, ClusterTrainingRuntimes)   │
├─────────────────────────────────────────┤
│              Kubernetes                  │  ← Infrastructure
└─────────────────────────────────────────┘
```

**OSFT Benefits:**
- Continually post-train fine-tuned models
- Expand model knowledge on new data without catastrophic forgetting

**Repository:** `https://github.com/Red-Hat-AI-Innovation-Team/training_hub.git`

---

### Model Customization Workflow

RHOAI 3.3 introduces a comprehensive end-to-end model customization workflow with integrated toolkits:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Model Customization Workflow                      │
├─────────────────────────────────────────────────────────────────────┤
│  1. Data Processing    →  Docling (unstructured → structured)       │
│  2. Synthetic Data     →  SDG Hub (generate training data)          │
│  3. Model Training     →  Training Hub + KFTO (distributed)         │
│  4. Model Serving      →  KServe / llm-d (deploy as API)            │
└─────────────────────────────────────────────────────────────────────┘
```

**Red Hat Python Index:**
- Secure, maintained Python package index
- Full support for disconnected environments
- Pre-configured base images for CPU, CUDA 12.9/13.0, and ROCm 6.4

**Knowledge Tuning Tutorial:**
A curated collection of Jupyter notebooks demonstrating the complete workflow:
- Docling for data processing
- Training Hub for fine-tuning
- KServe for model deployment
- Question and Answer application example

**Repository:** `https://github.com/red-hat-data-services/red-hat-ai-examples.git` (branch: `main`, directory: `knowledge-tuning`)

---

## Enhancements

### Resource Naming Convention Update

All resources now use a consistent `data-science-` prefix for better organization and identification.

**Impact:** Dashboard URL changed from `rhods-dashboard-redhat-ods-applications.apps.<cluster>` to `data-science-gateway.apps.<cluster>`

### vLLM-Gaudi 1.23 Support

Enhanced performance and stability for vLLM applications with vllm-gaudi version 1.23.

### Model Catalog Performance Data

**New Capabilities:**
- Comprehensive model validation data
- Performance benchmarks for validated models
- Hardware compatibility metrics
- Advanced search and filtering by:
  - Throughput
  - Latency
  - Hardware profiles
- Unified discovery experience in the Red Hat OpenShift AI hub

### AuthN/AuthZ Documentation for llm-d

New documentation guide for configuring Authentication and Authorization for Distributed Inference with llm-d, protecting workloads against unauthorized access and lateral movement.

### High-Performance Networking Guide (RoCE)

Comprehensive documentation for establishing production-grade Distributed Inference with llm-d using RDMA over Converged Ethernet (RoCE):
- Multi-GPU fabric configuration
- Lossless networking setup
- TFLOPS efficiency optimization
- Tail-latency minimization at scale

### OpenShift Console Navigation Changes

In OpenShift 4.20+, Red Hat Operator catalogs moved from OperatorHub to the unified software catalog:
- **Access:** Ecosystem → Software Catalog
- **Manage:** Ecosystem → Installed Operators

---

## Technology Preview Features

> **Note:** Technology Preview features are not supported with Red Hat production SLAs and might not be functionally complete.

### 1. Models-as-a-Service (MaaS)

Centralized governance for LLM serving with tier-based access control.

**Capabilities:**
- **Tier-based access control:** Define service tiers (free, premium, enterprise) with different limits
- **Policy and quota management:** Enforce rate limiting and quotas
- **API key authentication:** Control access through tier-based resource allocation
- **Usage tracking:** Track consumption for cost allocation
- **Zero-Touch setup:** Simplified configuration via RHOAI operator

**Key Components:**
- Kuadrant (Authorino + Limitador) for policy enforcement
- Gateway API for traffic routing
- KServe for model serving infrastructure

**Important:** Only `llm-d` runtime supports MaaS integration via the dashboard UI.

### 2. OpenAI-Compatible Annotations for Llama Stack

RAG applications can now trace generated responses back to source documents using OpenAI-compatible annotation schemas.

**Features:**
- Document source attribution
- Citation metadata preservation in API responses
- Compatible with existing OpenAI client applications
- Foundation for future tracing and observability features

### 3. Llama Stack Operator Multi-Architecture Support

The Llama Stack Operator is now deployable on multi-architecture clusters.

**Version Info:**
- Open Data Hub Llama Stack: 0.4.2.1+rhai0
- Based on upstream Llama Stack: 0.4.2

### 4. Llama Stack ConfigMap-Driven Image Updates

Patch security or bug fixes without new operator versions:

```yaml
image-overrides: |
  starter-gpu: registry.redhat.io/rhoai/odh-llama-stack-core-rhel9:v3.3
  starter: registry.redhat.io/rhoai/odh-llama-stack-core-rhel9:v3.3
```

### 5. MLServer ServingRuntime for KServe

Deploy classical ML models without ONNX conversion.

**Supported Frameworks:**
- scikit-learn
- XGBoost
- LightGBM

### 6. Gen AI Playground

Interactive environment for prototyping and evaluating models.

**Core Capabilities:**
- Chat with foundation and custom models
- Test RAG with document uploads
- Integrate MCP (Model Context Protocol) servers
- Export configurations as Python templates

**Requirements:**
- Models must support tool calling
- vLLM with `--enable-auto-tool-choice` and `--tool-call-parser` arguments
- Llama Stack Operator enabled

---

## Deprecations

### Scheduled for Deprecation in 3.4

| Component | Replacement |
|-----------|-------------|
| Ray-based multi-node vLLM template | Native vLLM multiprocessing support |
| Training images for KFTOv1 | New images for Kubeflow Trainer v2 |
| ClusterTrainingRuntimes for KFTOv1 | New runtimes for Kubeflow Trainer v2 |

### Currently Deprecated

| Component | Status | Replacement |
|-----------|--------|-------------|
| Kubeflow Training Operator v1 | Deprecated since 2.25 | Kubeflow Trainer v2 |
| SQLite for Llama Stack production | Deprecated since 3.2 | PostgreSQL |
| `opendatahub.io/connection-type-ref` annotation | Deprecated since 3.0 | `opendatahub.io/connection-type-protocol` |
| TrustyAI service CRD v1alpha1 | Deprecated since 2.25 | v1 |
| KServe Serverless deployment mode | Deprecated since 2.25 | KServe RawDeployment |
| Model registry API v1alpha1 | Deprecated since 2.24 | v1beta1 |
| Multi-model serving (ModelMesh) | Deprecated since 2.19 | Single-model serving |
| Accelerator Profiles | Deprecated since 3.0 | Hardware Profiles |
| Container Size selector | Deprecated since 3.0 | Hardware Profiles |
| OVMS CUDA plugin | Deprecated | N/A |
| OdhDashboardConfig user management | Deprecated since 2.17 | Auth resource |

### Deprecated CodeFlare SDK Parameters

| Deprecated | Replacement |
|------------|-------------|
| `head_cpus` | `head_cpu_requests`, `head_cpu_limits` |
| `head_memory` | `head_memory_requests`, `head_memory_limits` |
| `min_cpus` | `worker_cpu_requests` |
| `max_cpus` | `worker_cpu_limits` |
| `min_memory` | `worker_memory_requests` |
| `max_memory` | `worker_memory_limits` |
| `head_gpus` | `head_extended_resource_requests` |
| `num_gpus` | `worker_extended_resource_requests` |

---

## Removed Functionality

| Component | Version Removed | Notes |
|-----------|-----------------|-------|
| CodeFlare Operator | 3.0 | Functionality moved to KubeRay Operator |
| AppWrapper Controller | 3.0 | Part of CodeFlare removal |
| Caikit-NLP runtime | 3.0 | Migrate to supported runtimes |
| TGIS component | 3.0 | Migrate to Caikit or Caikit-TGIS |
| LAB-tuning feature | 3.0 | Use alternative fine-tuning methods |
| Embedded Kueue | 3.0 | Use Red Hat Build of Kueue Operator |
| DSPA v1alpha1 API | 3.0 | Use v1 API |
| MS SQL Server CLI tools | 2.24 | N/A |
| MLMD server (model registry) | 2.23 | Direct database access |
| Anaconda | 2.18 | N/A |
| HabanaAI workbench image | 2.14+ | Existing images continue to work |

---

## Key Resolved Issues

### RHOAI 3.3

| Issue | Description |
|-------|-------------|
| RHOAIENG-24545 | Runtime images now properly populated for first workbench instance |

### RHOAI 3.2 (Included in 3.3)

| Issue | Description |
|-------|-------------|
| RHOAIENG-38579 | Can now stop models served with llm-d runtime from dashboard |
| RHOAIENG-38180 | Fixed Feast SDK requests from workbench |
| RHOAIENG-41588 | Gateway API now supports Cluster IP mode and standard routes |
| RHOAIENG-37686 | Metrics now display correctly with digest-based image names |
| RHOAIENG-35532 | Fixed GPU model deployment with HardwareProfiles |
| RHOAIENG-4570 | Resolved Argo Workflows installation conflicts |
| RHOAIENG-9418 | Elyra now supports uppercase parameters |

---

## Known Issues

### Critical Issues

#### RHOAIENG-45142: Dashboard URL 404 Errors After Upgrade

After upgrading from 2.x to 3.x, existing bookmarks return 404 errors.

**Cause:** URL changed from `rhods-dashboard-redhat-ods-applications.apps.<cluster>` to `data-science-gateway.apps.<cluster>`

**Workaround:** Deploy nginx-based redirect solution or update bookmarks.

#### RHOAIENG-43686: Kueue 1.2 Installation Fails

Installation fails if legacy Kueue CRDs remain from RHOAI 2.x.

**Workaround:** Delete legacy CRDs: `cohorts.kueue.x-k8s.io/v1alpha1` and `topologies.kueue.x-k8s.io/v1alpha1`

#### RHOAIENG-48867: TrainJob Resume Fails After Upgrade

Suspended TrainJobs cannot resume after upgrade due to immutable JobSet spec.

**Workaround:** Delete and recreate affected TrainJobs after upgrade.

### Other Notable Issues

| Issue | Description | Workaround |
|-------|-------------|------------|
| RHOAIENG-50523 | RAG document upload fails on disconnected clusters | Patch LlamaStackDistribution with offline environment variables |
| RHOAIENG-49389 | Cannot create tiers after deleting all tiers | Create tier via CLI, then configure in dashboard |
| RHOAIENG-47589 | Missing Kueue validation for TrainJob | None |
| RHOAIENG-44516 | MLflow doesn't accept K8s service account tokens | Create OpenShift Route directly to MLflow service |
| RHAIENG-2827 | Unsecured routes from older CodeFlare SDK | Update workbench to latest 3.x image |

---

## Breaking Changes

### Dashboard URL Change

**Old:** `rhods-dashboard-redhat-ods-applications.apps.<cluster>`
**New:** `data-science-gateway.apps.<cluster>`

Update all bookmarks, documentation, and automation scripts.

### Resource Naming Convention

Resources now use `data-science-` prefix. Update any scripts or automation that reference old resource names.

### Auth Resource Migration

User management moved from `OdhDashboardConfig` to `Auth` resource:

| Field | Old Location | New Location |
|-------|--------------|--------------|
| Admin groups | `spec.groupsConfig.adminGroups` | `spec.adminGroups` |
| User groups | `spec.groupsConfig.allowedGroups` | `spec.allowedGroups` |
| API Version | `opendatahub.io/v1alpha` | `services.platform.opendatahub.io/v1alpha1` |
| Kind | `OdhDashboardConfig` | `Auth` |

---

## Quick Reference: Version Compatibility

| Component | Version in RHOAI 3.3 |
|-----------|---------------------|
| OpenShift | 4.19+ required |
| Llama Stack | 0.4.2 |
| vLLM-Gaudi | 1.23 |
| Kubeflow Trainer | v2 (GA) |
| Model Registry API | v1beta1 |

---

## Additional Resources

- [RHOAI 3.3 Installation Guide](./RHOAI-33-INSTALLATION.md)
- [Supported Configurations for 3.x](https://access.redhat.com/articles/rhoai-supported-configs)
- [RHOAI Life Cycle](https://access.redhat.com/support/policy/updates/rhoai)
- [Migration from 2.x Knowledge Base](https://access.redhat.com/articles/rhoai-upgrade-3x)
