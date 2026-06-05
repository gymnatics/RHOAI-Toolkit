# Red Hat OpenShift AI Overview

Red Hat OpenShift AI is a flexible, scalable MLOps platform with tools to build, deploy, and manage AI-enabled applications. Built using open source technologies, it provides trusted, operationally consistent capabilities for teams to experiment, serve models, and deliver innovative apps.

## Key Capabilities

### Model Development
OpenShift AI provides data scientists with self-service model development environments including Jupyter notebooks, VS Code, and RStudio. Integrated AI pipelines automate the entire machine learning lifecycle from data preparation through model deployment.

### Model Serving
Multiple serving runtimes are supported including vLLM for high-performance LLM inference, OpenVINO for optimized inference, and custom runtimes. Models can be served using KServe with support for both Serverless and RawDeployment modes.

### Models as a Service (MaaS)
MaaS provides a centralized model serving platform with subscription-based access, API key management, and rate limiting. It enables organizations to offer LLM inference as an internal service with proper governance and cost visibility.

### Feature Store (Feast)
The Feast operator enables feature store capabilities for managing and serving machine learning features. It supports online and offline stores with integration into the RHOAI dashboard.

### Model Registry
Model Registry provides a central repository for versioning and tracking ML models. It supports OCI-compliant storage, PostgreSQL backend, and artifact signing for model governance.

### Distributed Training
Support for distributed training workloads using Ray, Kubeflow Trainer v2, and PyTorch. GPU scheduling is handled by Kueue for efficient resource allocation.

## Architecture

OpenShift AI runs on Red Hat OpenShift Container Platform and integrates with:
- NVIDIA GPU Operator for GPU acceleration
- Node Feature Discovery for hardware detection
- cert-manager for certificate management
- Red Hat Connectivity Link for API gateway capabilities
- MLflow for experiment tracking

## Supported Hardware

OpenShift AI supports NVIDIA GPUs including:
- A100, H100, H200 for large-scale training and inference
- L40S for cost-effective inference
- T4 for development and small workloads

GPU resources are managed through Hardware Profiles which define resource requests, limits, tolerations, and node selectors for consistent GPU allocation across workloads.
