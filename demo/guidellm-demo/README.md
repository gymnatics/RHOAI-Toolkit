# GuideLLM Demo - LLM Benchmarking Tool

GuideLLM is a benchmarking tool for measuring LLM inference performance on OpenShift AI.

## What This Demo Shows

GuideLLM measures key performance metrics:
- **TTFT** (Time to First Token) - How quickly the model starts responding
- **ITL** (Inter-Token Latency) - Time between tokens during generation
- **Request Latency** - Total time for complete response
- **Throughput** - Tokens per second capacity

---

## Quick Start

### Option 1: Deploy via Toolkit (Recommended)

```bash
./rhoai-toolkit.sh
# Navigate to: RHOAI Management → Demos → Deploy GuideLLM
```

### Option 2: Deploy via Manifest

```bash
# Apply the deployment
oc apply -f lib/manifests/demo/guidellm.yaml -n demo

# Wait for pod
oc wait --for=condition=Ready pod -l app=guidellm -n demo --timeout=120s
```

---

## Running Benchmarks

### Step 1: Connect to GuideLLM Pod

```bash
# Get pod name
GUIDELLM=$(oc get pod -l app=guidellm -n demo -o name)

# Shell into the pod
oc rsh -n demo $GUIDELLM
```

### Step 2: Set Environment Variables

```bash
# Set target model endpoint
export TARGET=http://my-model-predictor.demo.svc.cluster.local:8080
export MODEL=my-model
```

### Step 3: Run Benchmark

```bash
# Basic throughput benchmark
guidellm benchmark run \
  --target $TARGET \
  --model $MODEL \
  --rate-type throughput \
  --max-requests 100 \
  --data "prompt_tokens=768,output_tokens=768"
```

---

## Benchmark Options

### Rate Types

| Type | Description | Use Case |
|------|-------------|----------|
| `throughput` | Maximum throughput test | Capacity planning |
| `constant` | Fixed request rate | SLA testing |
| `poisson` | Random arrival rate | Realistic load simulation |

### Common Parameters

```bash
# Throughput test (max capacity)
guidellm benchmark run \
  --target $TARGET \
  --model $MODEL \
  --rate-type throughput \
  --max-requests 100

# Constant rate test (e.g., 10 req/sec)
guidellm benchmark run \
  --target $TARGET \
  --model $MODEL \
  --rate-type constant \
  --rate 10 \
  --max-requests 100

# Custom prompt/output sizes
guidellm benchmark run \
  --target $TARGET \
  --model $MODEL \
  --rate-type throughput \
  --data "prompt_tokens=512,output_tokens=256"

# Longer test duration
guidellm benchmark run \
  --target $TARGET \
  --model $MODEL \
  --rate-type throughput \
  --max-seconds 300
```

---

## Manual Implementation

### Deployment YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: guidellm
  labels:
    app: guidellm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: guidellm
  template:
    metadata:
      labels:
        app: guidellm
    spec:
      containers:
        - name: guidellm
          image: quay.io/ltsai/guidellm:0.3.0
          imagePullPolicy: IfNotPresent
          command:
            - tail
          args:
            - '-f'
            - /dev/null
          env:
            - name: TARGET
              value: "http://model-predictor.demo.svc.cluster.local:8080"
            - name: MODEL
              value: "model-name"
          resources:
            requests:
              cpu: 100m
              memory: 512Mi
            limits:
              cpu: 1
              memory: 2Gi
```

### Apply and Run

```bash
# Apply deployment
oc apply -f guidellm-deployment.yaml -n demo

# Wait for ready
oc wait --for=condition=Ready pod -l app=guidellm -n demo --timeout=120s

# Run benchmark
oc exec -n demo deployment/guidellm -- \
  guidellm benchmark run \
    --target http://my-model-predictor.demo.svc.cluster.local:8080 \
    --model my-model \
    --rate-type throughput \
    --max-requests 50
```

---

## Understanding Results

### Sample Output

```
Benchmark Results:
==================
Total Requests:     100
Successful:         100
Failed:             0

Latency (ms):
  TTFT p50:         45.2
  TTFT p95:         78.4
  TTFT p99:         112.3
  ITL p50:          12.1
  ITL p95:          18.7
  Request p50:      1245.6
  Request p95:      1567.8

Throughput:
  Requests/sec:     8.2
  Tokens/sec:       6234.5
```

### Key Metrics Explained

| Metric | Good Value | What It Means |
|--------|------------|---------------|
| TTFT p50 | < 100ms | Fast initial response |
| TTFT p95 | < 200ms | Consistent under load |
| ITL p50 | < 20ms | Smooth streaming |
| Throughput | Depends on GPU | Higher = more capacity |

---

## Prerequisites

- Model deployed and serving (vLLM, llm-d, etc.)
- Model must support OpenAI-compatible API
- Network access from GuideLLM pod to model service

---

## Troubleshooting

### Cannot connect to model

```bash
# Test connectivity from GuideLLM pod
oc exec -n demo deployment/guidellm -- \
  curl -s http://my-model-predictor.demo.svc.cluster.local:8080/v1/models

# Check model service exists
oc get svc -n demo | grep predictor
```

### Benchmark fails immediately

```bash
# Check model is healthy
oc get isvc -n demo

# Check GuideLLM logs
oc logs -n demo deployment/guidellm
```

### Low throughput results

- Check GPU utilization: `nvidia-smi` on GPU node
- Check model resources (memory, GPU)
- Try smaller prompt/output sizes
- Check for network bottlenecks

---

## Files

| File | Location | Description |
|------|----------|-------------|
| Manifest | `lib/manifests/demo/guidellm.yaml` | Deployment YAML |
| Function | `rhoai-toolkit.sh` | `deploy_guidellm()` function |

---

## Learn More

- [GuideLLM GitHub](https://github.com/neuralmagic/guidellm)
- [vLLM Benchmarking Guide](https://docs.vllm.ai/en/latest/serving/benchmarking.html)
