# YAML Templates

This directory contains reusable YAML templates for common resources. Templates use shell variable substitution via `envsubst`.

## Usage

### Basic Usage with envsubst

```bash
# Set required variables
export NAME="qwen3-8b"
export MODEL_PATH="Qwen/Qwen3-8B"

# Apply template
envsubst < inferenceservice-s3.yaml.tmpl | oc apply -f -
```

### Using with yq (more powerful)

```bash
# Using yq for dynamic substitution
yq eval '
  .metadata.name = env(NAME) |
  .spec.predictor.model.storage.path = env(MODEL_PATH)
' inferenceservice-s3.yaml.tmpl | oc apply -f -
```

## Available Templates

### InferenceService Templates

| Template | Storage Type | Description |
|----------|--------------|-------------|
| `inferenceservice-s3.yaml.tmpl` | S3 | Model stored in S3-compatible storage |
| `inferenceservice-pvc.yaml.tmpl` | PVC | Model stored in PersistentVolumeClaim |
| `inferenceservice-oci.yaml.tmpl` | OCI | Model from OCI registry (ModelCar) |

### ServingRuntime Templates

| Template | Description |
|----------|-------------|
| `servingruntime-vllm.yaml.tmpl` | vLLM runtime with NVIDIA GPU support |

## Variables Reference

### Common Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NAME` | Yes | - | Resource name (k8s-safe, lowercase) |
| `MODEL_PATH` | Yes | - | Path to model |
| `NAMESPACE` | No | current | Target namespace |

### Resource Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CPU_LIMIT` | 4 | CPU limit |
| `CPU_REQUEST` | 2 | CPU request |
| `MEMORY_LIMIT` | 32Gi | Memory limit |
| `MEMORY_REQUEST` | 8Gi | Memory request |
| `GPU_COUNT` | 1 | Number of GPUs |
| `MAX_MODEL_LEN` | 4096 | vLLM max model length |

### Storage-Specific Variables

| Variable | Template | Default | Description |
|----------|----------|---------|-------------|
| `PVC_NAME` | pvc | models-pvc | PVC name for model storage |

## Examples

### Deploy model from S3

```bash
export NAME="llama-3-8b"
export MODEL_PATH="meta-llama/Llama-3-8B-Instruct"
export GPU_COUNT="1"
export MAX_MODEL_LEN="8192"

# Create ServingRuntime
envsubst < servingruntime-vllm.yaml.tmpl | oc apply -n demo -f -

# Create InferenceService
envsubst < inferenceservice-s3.yaml.tmpl | oc apply -n demo -f -
```

### Deploy model from OCI (ModelCar)

```bash
export NAME="qwen3-8b-fp8"
export MODEL_PATH="oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-instruct-fp8:1.5"

envsubst < servingruntime-vllm.yaml.tmpl | oc apply -n demo -f -
envsubst < inferenceservice-oci.yaml.tmpl | oc apply -n demo -f -
```

### Deploy model from PVC

```bash
export NAME="mistral-7b"
export MODEL_PATH="mistralai/Mistral-7B-Instruct-v0.3"
export PVC_NAME="models-pvc"

envsubst < servingruntime-vllm.yaml.tmpl | oc apply -n demo -f -
envsubst < inferenceservice-pvc.yaml.tmpl | oc apply -n demo -f -
```

## Helper Function

Add this to your scripts for easy template usage:

```bash
apply_template() {
    local template="$1"
    local namespace="${2:-$(oc project -q)}"
    
    if [ ! -f "$template" ]; then
        echo "Error: Template not found: $template"
        return 1
    fi
    
    envsubst < "$template" | oc apply -n "$namespace" -f -
}

# Usage:
export NAME="my-model"
export MODEL_PATH="org/model-name"
apply_template "inferenceservice-s3.yaml.tmpl" "demo"
```
