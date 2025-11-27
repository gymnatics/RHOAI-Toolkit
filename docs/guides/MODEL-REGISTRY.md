# Model Registry in RHOAI 3.0

## Overview

The Model Registry in RHOAI 3.0 provides centralized management, versioning, and metadata tracking for deployed models. It enables teams to:
- Track model versions and lineage
- Store model metadata and artifacts
- Manage model lifecycle (development → staging → production)
- Share models across teams and projects
- Maintain audit trails

## Prerequisites

- RHOAI 3.0 installed
- Model Registry component enabled in DataScienceCluster
- Cluster admin access for configuration

## Enabling Model Registry

### Method 1: During RHOAI Installation (DataScienceCluster)

The Model Registry is enabled by default in RHOAI 3.0:

```yaml
kind: DataScienceCluster
apiVersion: datasciencecluster.opendatahub.io/v2
metadata:
  name: default-dsc
spec:
  components:
    modelregistry:
      managementState: Managed
      registriesNamespace: rhoai-model-registries  # Namespace for registry instances
```

### Method 2: Enable in Dashboard Configuration

Update the `OdhDashboardConfig` to show Model Registry in the UI:

```bash
oc patch odhdashboardconfig odh-dashboard-config \
  -n redhat-ods-applications \
  --type merge \
  -p '{"spec":{"dashboardConfig":{"disableModelRegistry":false}}}'
```

Or apply the complete configuration:

```yaml
apiVersion: opendatahub.io/v1alpha
kind: OdhDashboardConfig
metadata:
  name: odh-dashboard-config
  namespace: redhat-ods-applications
spec:
  dashboardConfig:
    disableModelRegistry: false  # Enable Model Registry
    disableModelCatalog: false   # Enable Model Catalog
    disableKServeMetrics: false  # Enable KServe Metrics
    genAiStudio: true            # Enable GenAI Studio
    modelAsService: true         # Enable MaaS
    disableLMEval: false         # Enable LM Eval
```

## Creating a Model Registry

### Option 1: Via Dashboard (UI)

1. Navigate to **Settings → Model Registry**
2. Click **Create Model Registry**
3. Enter:
   - **Name**: e.g., `my-model-registry`
   - **Namespace**: e.g., `rhoai-model-registries` (default) or custom
4. Click **Create**

### Option 2: Via CLI

```bash
# Create a ModelRegistry custom resource
cat <<EOF | oc apply -f -
apiVersion: modelregistry.opendatahub.io/v1alpha1
kind: ModelRegistry
metadata:
  name: my-model-registry
  namespace: rhoai-model-registries
spec:
  grpc:
    port: 9090
  rest:
    port: 8080
    serviceRoute: enabled
  postgres:
    database: mlmddb
EOF
```

### Verify Model Registry

```bash
# Check ModelRegistry resource
oc get modelregistry -n rhoai-model-registries

# Check Model Registry pods
oc get pods -n rhoai-model-registries

# Get Model Registry service URL
oc get route -n rhoai-model-registries
```

Expected output:
```
NAME                 AGE
my-model-registry    2m

NAME                                          READY   STATUS    RESTARTS   AGE
my-model-registry-db-6f5b8c9d7f-xyz12        1/1     Running   0          2m
my-model-registry-rest-7d8b9c4f5d-abc34      1/1     Running   0          2m
```

## Registering a Model

### 1. Via Python SDK (Model Registry Client)

```python
from model_registry import ModelRegistry

# Initialize client
registry = ModelRegistry(
    server_address="http://my-model-registry-rest-route-url",
    author="data-scientist@example.com"
)

# Register a model version
registered_model = registry.register_model(
    name="llama-3.2-3b-instruct",
    uri="oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct",
    version="v1.0",
    model_format_name="vLLM",
    model_format_version="0.9.1",
    description="Llama 3.2 3B Instruct model for text generation",
    metadata={
        "framework": "PyTorch",
        "task": "text-generation",
        "license": "Llama-3.2-License"
    }
)

print(f"Registered model: {registered_model.id}")
```

### 2. Via Dashboard (UI)

1. Navigate to **Model Registry** in the dashboard
2. Select your registry
3. Click **Register Model**
4. Fill in model details:
   - **Model Name**: `llama-3.2-3b-instruct`
   - **Model Version**: `v1.0`
   - **Model URI**: Storage location (S3, OCI, etc.)
   - **Format**: `vLLM`, `ONNX`, `TensorFlow`, etc.
   - **Description**: Model description
   - **Metadata**: Custom key-value pairs
5. Click **Register**

### 3. Via REST API

```bash
# Get the Model Registry REST API URL
REGISTRY_URL=$(oc get route my-model-registry-rest -n rhoai-model-registries -o jsonpath='{.spec.host}')

# Register a model
curl -X POST "https://$REGISTRY_URL/api/model_registry/v1alpha3/registered_models" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "llama-3.2-3b-instruct",
    "description": "Llama 3.2 3B Instruct model",
    "customProperties": {
      "task": {"string_value": "text-generation"},
      "framework": {"string_value": "PyTorch"}
    }
  }'
```

## Integrating with InferenceService

Link a deployed InferenceService to the Model Registry:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llama-32-3b-instruct
  namespace: ai-bu-shared
  annotations:
    # Link to Model Registry
    modelregistry.opendatahub.io/registered-model-id: "<model-id>"
    modelregistry.opendatahub.io/model-version-id: "<version-id>"
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      storageUri: 'oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct'
```

## Model Lifecycle Management

### Promoting Models Between Environments

```python
# List model versions
versions = registry.get_model_versions("llama-3.2-3b-instruct")

# Update model version stage
registry.update_model_version(
    model_name="llama-3.2-3b-instruct",
    version="v1.0",
    stage="Production"  # Stages: Development, Staging, Production, Archived
)
```

### Adding Model Artifacts

```python
# Add model artifact (weights, configs, etc.)
registry.log_model_artifact(
    model_name="llama-3.2-3b-instruct",
    version="v1.0",
    artifact_uri="s3://my-bucket/models/llama-3.2-3b/weights.bin",
    artifact_type="model_weights"
)
```

## Best Practices

1. **Naming Convention**
   - Use descriptive names: `{model-family}-{size}-{variant}`
   - Example: `llama-3.2-3b-instruct`, `mistral-7b-v0.3`

2. **Versioning Strategy**
   - Semantic versioning: `v{major}.{minor}.{patch}`
   - Tag releases: `v1.0`, `v1.1`, `v2.0`
   - Track training runs

3. **Metadata**
   - Store training metrics (accuracy, loss, etc.)
   - Record hyperparameters
   - Document data sources and preprocessing

4. **Lifecycle Management**
   - Development → Staging → Production
   - Archive old versions
   - Maintain lineage

5. **Access Control**
   - Use RBAC for registry access
   - Separate registries for different teams
   - Audit access logs

## Troubleshooting

### Model Registry Pod Not Ready

```bash
# Check pod status
oc get pods -n rhoai-model-registries

# Check pod logs
oc logs -n rhoai-model-registries deployment/my-model-registry-rest

# Check database connection
oc logs -n rhoai-model-registries deployment/my-model-registry-db
```

### Cannot Access Model Registry UI

```bash
# Verify route
oc get route -n rhoai-model-registries

# Check dashboard config
oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o yaml | grep disableModelRegistry
```

### Model Registration Fails

```bash
# Check Model Registry service
oc get svc -n rhoai-model-registries

# Test connectivity
MODEL_REGISTRY_URL=$(oc get route my-model-registry-rest -n rhoai-model-registries -o jsonpath='{.spec.host}')
curl -k "https://$MODEL_REGISTRY_URL/api/model_registry/v1alpha3/registered_models"
```

## Related Documentation

- [RHOAI Model Registry Docs](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0/html/managing_models/index)
- [Model Registry API Reference](https://github.com/opendatahub-io/model-registry)
- [Python SDK](https://pypi.org/project/model-registry/)

## CLI Quick Reference

```bash
# Enable Model Registry in dashboard
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
  --type merge -p '{"spec":{"dashboardConfig":{"disableModelRegistry":false}}}'

# Create Model Registry
oc apply -f <model-registry-cr.yaml>

# List Model Registries
oc get modelregistry -A

# Get Model Registry route
oc get route -n rhoai-model-registries

# View Model Registry logs
oc logs -n rhoai-model-registries deployment/my-model-registry-rest

# Delete Model Registry
oc delete modelregistry my-model-registry -n rhoai-model-registries
```

## Status

✅ **Available in RHOAI 3.0**  
📚 Based on CAI Guide Section 10 and RHOAI 3.0 documentation

