# Open WebUI Demo

A user-friendly web interface for chatting with LLMs deployed on OpenShift AI.

## What This Demo Shows

Open WebUI provides:
- **Chat Interface** - Clean, modern UI for interacting with models
- **Multi-Model Support** - Connect to multiple models simultaneously
- **Conversation History** - Persistent chat sessions
- **OpenAI-Compatible** - Works with any OpenAI-compatible API (vLLM, llm-d, etc.)

---

## Quick Start

### Option 1: Deploy via Toolkit (Recommended)

```bash
./rhoai-toolkit.sh
# Navigate to: RHOAI Management → Demos → Deploy Open WebUI
```

### Option 2: Deploy via Script

```bash
# Set variables
export NAMESPACE=demo
export MODEL_URL="http://my-model-predictor.demo.svc.cluster.local:8080/v1"

# Apply manifest
envsubst < lib/manifests/demo/open-webui.yaml | oc apply -n $NAMESPACE -f -

# Wait for deployment
oc rollout status deployment/open-webui -n $NAMESPACE

# Get URL
oc get route open-webui -n $NAMESPACE -o jsonpath='https://{.spec.host}{"\n"}'
```

---

## Manual Implementation

### Step 1: Create ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: openwebui-config
data:
  ENABLE_OLLAMA_API: "False"
  OPENAI_API_BASE_URLS: "http://my-model-predictor.demo.svc.cluster.local:8080/v1"
  OPENAI_API_KEYS: ""
  WEBUI_AUTH: "False"
  WEBUI_SECRET_KEY: "your-secret-key"
```

### Step 2: Create PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: open-webui-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

### Step 3: Create Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: open-webui
  labels:
    app: open-webui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: open-webui
  template:
    metadata:
      labels:
        app: open-webui
    spec:
      containers:
        - name: open-webui
          image: ghcr.io/open-webui/open-webui:main
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: openwebui-config
          env:
            - name: ENABLE_PERSISTENT_CONFIG
              value: "False"
          volumeMounts:
            - name: data
              mountPath: /app/backend/data
          resources:
            requests:
              cpu: 100m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 2Gi
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: open-webui-data
```

### Step 4: Create Service and Route

```yaml
apiVersion: v1
kind: Service
metadata:
  name: open-webui
spec:
  selector:
    app: open-webui
  ports:
    - port: 8080
      targetPort: 8080
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: open-webui
spec:
  to:
    kind: Service
    name: open-webui
  port:
    targetPort: 8080
  tls:
    termination: edge
```

---

## Configuration

### Connect to Multiple Models

You can connect Open WebUI to multiple models by separating URLs with semicolons:

```bash
# Update ConfigMap
oc patch configmap openwebui-config -n demo --type merge \
  -p '{"data":{"OPENAI_API_BASE_URLS":"http://model1:8080/v1;http://model2:8080/v1"}}'

# Restart to apply
oc rollout restart deployment/open-webui -n demo
```

### Enable Authentication

For production use, enable authentication:

```bash
oc patch configmap openwebui-config -n demo --type merge \
  -p '{"data":{"WEBUI_AUTH":"True"}}'

oc rollout restart deployment/open-webui -n demo
```

### Finding Model URLs

```bash
# List InferenceServices
oc get isvc -n demo

# Get internal URL for a model
oc get isvc my-model -n demo -o jsonpath='{.status.address.url}'

# Typical format: http://<model>-predictor.<namespace>.svc.cluster.local:8080/v1
```

---

## Prerequisites

- OpenShift cluster with RHOAI installed
- At least one model deployed and serving (vLLM, llm-d, etc.)
- Model must expose OpenAI-compatible API (`/v1/chat/completions`)

---

## Troubleshooting

### Open WebUI not starting

```bash
# Check pod status
oc get pods -l app=open-webui -n demo

# Check logs
oc logs deployment/open-webui -n demo

# Check events
oc get events -n demo --sort-by='.lastTimestamp' | tail -20
```

### Cannot connect to model

```bash
# Verify model is running
oc get isvc -n demo

# Test model endpoint from within cluster
oc run curl --rm -it --image=curlimages/curl -- \
  curl -s http://my-model-predictor.demo.svc.cluster.local:8080/v1/models
```

### Chat not working

1. Check model URL is correct in ConfigMap
2. Ensure model supports OpenAI chat completions API
3. Check Open WebUI logs for errors

---

## Files

| File | Location | Description |
|------|----------|-------------|
| Manifest | `lib/manifests/demo/open-webui.yaml` | Complete deployment YAML |
| Function | `rhoai-toolkit.sh` | `deploy_open_webui()` function |

---

## Learn More

- [Open WebUI GitHub](https://github.com/open-webui/open-webui)
- [Open WebUI Documentation](https://docs.openwebui.com/)
