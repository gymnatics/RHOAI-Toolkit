# Model Serving on OpenShift AI

## Serving Runtimes

### vLLM
vLLM is the primary runtime for serving large language models. It supports continuous batching, PagedAttention for efficient memory management, and tensor parallelism for multi-GPU deployment. vLLM provides an OpenAI-compatible API endpoint.

Key features:
- Continuous batching for high throughput
- PagedAttention for efficient KV cache management
- Tensor parallelism across multiple GPUs
- Tool calling support with parsers for Hermes (Qwen), Llama3, and Mistral formats
- Speculative decoding for reduced latency

### OpenVINO Model Server
OpenVINO provides optimized inference for traditional ML models and smaller neural networks. It excels on CPU-only deployments and supports models in ONNX, TensorFlow, and PyTorch formats.

### AutoGluon
AutoGluon ServingRuntime enables deployment of models trained through AutoML. It supports the models trained by AutoGluon's tabular and time series predictors with v1 and v2 protocol versions.

### MLServer
MLServer provides a standardized serving runtime supporting scikit-learn, XGBoost, LightGBM, and ONNX models. It implements the KServe V2 inference protocol.

## Deployment Modes

### KServe Serverless
Models are deployed with Knative for automatic scaling including scale-to-zero. Best for variable workloads where you want to minimize idle resource consumption.

### KServe RawDeployment
Models are deployed as standard Kubernetes Deployments. Recommended for production workloads requiring predictable performance and consistent availability. Required for TrustyAI integration and NeMo Guardrails.

## Hardware Profiles

Hardware Profiles define GPU resource allocation for model serving. A profile specifies:
- Resource requests and limits (GPU count, memory)
- Node selectors (e.g., nvidia.com/gpu.present: 'true')
- Tolerations for GPU-tainted nodes

Models must reference a Hardware Profile that matches available cluster GPU resources.

## Models as a Service (MaaS)

MaaS extends model serving with enterprise governance features:
- Subscription-based access control
- API key authentication and rate limiting
- Centralized model catalog via MaaSModelRef
- Tenant isolation and authorization policies
- Usage monitoring and observability

MaaS uses llm-d as its primary serving runtime and requires Red Hat Connectivity Link for gateway functionality.
