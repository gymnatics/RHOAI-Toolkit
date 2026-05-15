# Deploying the OpenShift Kubernetes MCP Server

A step-by-step guide for deploying the [openshift/openshift-mcp-server](https://github.com/openshift/openshift-mcp-server) on Red Hat OpenShift. This MCP server enables AI agents and LLMs to interact with Kubernetes/OpenShift clusters via the Model Context Protocol.

> **Source:** https://github.com/openshift/openshift-mcp-server (fork of containers/kubernetes-mcp-server)

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deployment Methods](#deployment-methods)
  - [Method 1: Helm Chart](#method-1-helm-chart)
  - [Method 2: OpenShift BuildConfig](#method-2-openshift-buildconfig-recommended)
  - [Method 3: Local Container Build](#method-3-local-container-build)
- [Configuration](#configuration)
  - [Toolsets](#toolsets)
  - [Read-Only Mode](#read-only-mode)
  - [TOML Configuration Files](#toml-configuration-files)
- [RBAC Setup](#rbac-setup)
- [Registering in RHOAI](#registering-in-rhoai)
  - [AI Asset Endpoints (Dashboard UI)](#ai-asset-endpoints-dashboard-ui)
  - [LlamaStack (Tool Calling)](#llamastack-tool-calling)
  - [GenAI Playground (MCP ConfigMap)](#genai-playground-mcp-configmap)
- [Verification and Testing](#verification-and-testing)
- [Troubleshooting](#troubleshooting)
- [Available Tools Reference](#available-tools-reference)

---

## Overview

The Kubernetes MCP Server is a **Go-based native implementation** that interacts directly with the Kubernetes API server. Unlike other implementations, it is NOT a wrapper around `kubectl` or `helm` CLI tools.

**Key capabilities:**
- Generic CRUD on any Kubernetes/OpenShift resource
- Pod operations: list, get, delete, logs, exec, top, run
- Namespace and OpenShift Project listing
- Kubernetes Events viewing
- Helm chart management (install, list, uninstall)
- Tekton pipeline/task operations
- OpenTelemetry observability support
- Multi-cluster support via kubeconfig

**Deployment characteristics:**
- Single binary, no external dependencies
- Runs in HTTP/SSE mode with `--port` flag
- In-cluster ServiceAccount authentication
- Configurable read-only mode for safety

---

## Prerequisites

- OpenShift 4.19+ cluster with `oc` CLI access
- Cluster admin (or permissions to create ClusterRoleBindings)
- One of:
  - `helm` CLI (Method 1)
  - `oc` CLI only (Method 2 — recommended)
  - `podman` or `docker` (Method 3)

---

## Deployment Methods

### Method 1: Helm Chart

Best when you have `helm` and `git` available locally.

```bash
NAMESPACE="my-ai-project"

# 1. Clone just the Helm chart (sparse checkout)
tmpdir=$(mktemp -d)
git clone --depth=1 --filter=blob:none --sparse \
    https://github.com/openshift/openshift-mcp-server.git "$tmpdir/repo"
cd "$tmpdir/repo" && git sparse-checkout set charts/kubernetes-mcp-server

# 2. Install with Helm
helm upgrade --install kubernetes-mcp-server \
    "$tmpdir/repo/charts/kubernetes-mcp-server" \
    --namespace $NAMESPACE \
    --set server.readOnly=true \
    --set server.port=8080 \
    --set server.stateless=true \
    --set "server.toolsets={core,events}" \
    --set ingress.enabled=false \
    --set route.enabled=false

# 3. Add cluster-wide RBAC (Helm chart only creates namespace-scoped)
SA_NAME=$(oc get sa -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    | grep -E "mcp|kubernetes-mcp" | head -1)
SA_NAME="${SA_NAME:-kubernetes-mcp-server}"

oc create clusterrolebinding kubernetes-mcp-server-$NAMESPACE \
    --clusterrole=view \
    --serviceaccount=$NAMESPACE:$SA_NAME

# 4. Cleanup
cd - && rm -rf "$tmpdir"

# 5. Verify
oc rollout status deployment/kubernetes-mcp-server -n $NAMESPACE
```

---

### Method 2: OpenShift BuildConfig (Recommended)

Most portable — only requires `oc` and network access to GitHub. The cluster does all the building.

#### Step 1: Create the BuildConfig

```bash
NAMESPACE="my-ai-project"

oc new-build --name=kubernetes-mcp-server --strategy=docker \
    --dockerfile='FROM registry.access.redhat.com/ubi9/go-toolset:latest AS builder
WORKDIR /opt/app-root/src
RUN git clone --depth=1 https://github.com/openshift/openshift-mcp-server.git . && \
    CGO_ENABLED=0 go build -o /opt/app-root/kubernetes-mcp-server ./cmd/kubernetes-mcp-server/
FROM registry.access.redhat.com/ubi9-micro:latest
COPY --from=builder /opt/app-root/kubernetes-mcp-server /usr/local/bin/kubernetes-mcp-server
USER 1001
ENTRYPOINT ["kubernetes-mcp-server"]' \
    -n $NAMESPACE
```

#### Step 2: Wait for build to complete

```bash
# Follow build logs (takes 2-3 minutes)
oc logs -f bc/kubernetes-mcp-server -n $NAMESPACE

# Verify image was built
oc get istag kubernetes-mcp-server:latest -n $NAMESPACE
```

#### Step 3: Create ServiceAccount and RBAC

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kubernetes-mcp-server
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-mcp-server-$NAMESPACE
subjects:
- kind: ServiceAccount
  name: kubernetes-mcp-server
  namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
EOF
```

> **Note:** Use `view` for read-only access (recommended). Use `edit` if you need write operations.

#### Step 4: Deploy

```bash
oc apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubernetes-mcp-server
  namespace: $NAMESPACE
  labels:
    app: kubernetes-mcp-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kubernetes-mcp-server
  template:
    metadata:
      labels:
        app: kubernetes-mcp-server
    spec:
      serviceAccountName: kubernetes-mcp-server
      containers:
      - name: server
        image: image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/kubernetes-mcp-server:latest
        args:
        - "--port=8080"
        - "--stateless"
        - "--read-only"
        - "--toolsets=core,events"
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          tcpSocket:
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          tcpSocket:
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: kubernetes-mcp-server
  namespace: $NAMESPACE
  labels:
    app: kubernetes-mcp-server
spec:
  selector:
    app: kubernetes-mcp-server
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  type: ClusterIP
EOF
```

#### Step 5: Verify

```bash
oc rollout status deployment/kubernetes-mcp-server -n $NAMESPACE

# Test the endpoint
oc exec deploy/kubernetes-mcp-server -n $NAMESPACE -- \
    wget -qO- http://localhost:8080/ 2>&1
# Should return: {"status":"alive"}
```

---

### Method 3: Local Container Build

For environments where you want to build locally with podman/docker.

```bash
NAMESPACE="my-ai-project"

# 1. Clone and build
tmpdir=$(mktemp -d)
git clone --depth=1 https://github.com/openshift/openshift-mcp-server.git "$tmpdir/repo"

# Use Dockerfile.ocp if available, otherwise Dockerfile
DOCKERFILE="Dockerfile.ocp"
[ ! -f "$tmpdir/repo/$DOCKERFILE" ] && DOCKERFILE="Dockerfile"

podman build -f "$tmpdir/repo/$DOCKERFILE" -t kubernetes-mcp-server:latest "$tmpdir/repo"

# 2. Push to cluster internal registry
# Ensure registry route is exposed
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge \
    -p '{"spec":{"defaultRoute":true}}' 2>/dev/null || true
sleep 5

REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')
podman login -u $(oc whoami) -p $(oc whoami -t) "$REGISTRY" --tls-verify=false
podman tag kubernetes-mcp-server:latest "$REGISTRY/$NAMESPACE/kubernetes-mcp-server:latest"
podman push "$REGISTRY/$NAMESPACE/kubernetes-mcp-server:latest" --tls-verify=false

# 3. Deploy using same RBAC and Deployment YAMLs from Method 2, Steps 3–4
# ...

# 4. Cleanup
rm -rf "$tmpdir"
```

---

## Configuration

### Toolsets

Control which capabilities are available via the `--toolsets` flag:

| Toolset | Description |
|---------|-------------|
| `core` | Pods, Deployments, Services, Namespaces, generic CRUD (default) |
| `config` | View/manage kubeconfig contexts |
| `events` | View Kubernetes events |
| `helm` | Install, list, uninstall Helm charts |
| `tekton` | Start pipelines/tasks, get logs, restart runs |
| `exec` | Exec into pods and run commands |

**Examples:**
```bash
# Minimal (read-only cluster inspection)
--toolsets=core

# Development (add events for debugging)
--toolsets=core,events

# Full (everything)
--toolsets=core,config,events,helm,tekton,exec
```

### Read-Only Mode

```bash
# Safe for shared/production clusters (recommended)
--read-only

# Write operations enabled (use with caution)
# (omit --read-only flag)
```

In read-only mode, create/update/delete operations are blocked. The ClusterRoleBinding should use the `view` ClusterRole. For write mode, use `edit`.

### TOML Configuration Files

For complex configurations, create a TOML config file and mount it as a ConfigMap:

```toml
log_level = 2
read_only = true
toolsets = ["core", "config", "events"]

# Deny access to sensitive resources
[[denied_resources]]
group = ""
version = "v1"
kind = "Secret"
```

```bash
# Create ConfigMap from TOML file
oc create configmap mcp-server-config \
    --from-file=config.toml=mcp_config.toml \
    -n $NAMESPACE

# Add to deployment spec:
#   volumeMounts:
#   - name: config
#     mountPath: /etc/kubernetes-mcp-server
#   volumes:
#   - name: config
#     configMap:
#       name: mcp-server-config
#
# And add arg: --config=/etc/kubernetes-mcp-server/config.toml
```

---

## RBAC Setup

The MCP server uses the pod's ServiceAccount to authenticate with the Kubernetes API. By default, it only has access within its own namespace. For cross-namespace access, a ClusterRoleBinding is required.

### Read-Only (Recommended)

```bash
oc create clusterrolebinding kubernetes-mcp-server-$NAMESPACE \
    --clusterrole=view \
    --serviceaccount=$NAMESPACE:kubernetes-mcp-server
```

### Read-Write (Use with caution)

```bash
oc create clusterrolebinding kubernetes-mcp-server-$NAMESPACE \
    --clusterrole=edit \
    --serviceaccount=$NAMESPACE:kubernetes-mcp-server
```

### Custom RBAC (Restrict to specific resources)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: mcp-server-custom
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "services", "events", "namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["serving.kserve.io"]
  resources: ["inferenceservices"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-mcp-server-custom
subjects:
- kind: ServiceAccount
  name: kubernetes-mcp-server
  namespace: <your-namespace>
roleRef:
  kind: ClusterRole
  name: mcp-server-custom
  apiGroup: rbac.authorization.k8s.io
```

---

## Registering in RHOAI

After deployment, the MCP endpoint is:

```
http://kubernetes-mcp-server.<namespace>.svc.cluster.local:8080/mcp
```

### AI Asset Endpoints (Dashboard UI)

1. Go to RHOAI Dashboard → **Settings** → **AI asset endpoints**
2. Click **Add endpoint**
3. Fill in:
   - **Name:** `Kubernetes-MCP-Server`
   - **URL:** `http://kubernetes-mcp-server.<namespace>.svc.cluster.local:8080/mcp`
   - **Type:** `streamable-http`
   - **Description:** `Kubernetes/OpenShift cluster operations`
4. Click **Save**

### LlamaStack (Tool Calling)

Add to your LlamaStack distribution config or ConfigMap:

```yaml
tool_groups:
- toolgroup_id: mcp::kubernetes
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://kubernetes-mcp-server.<namespace>.svc.cluster.local:8080/mcp
```

### GenAI Playground (MCP ConfigMap)

To make the MCP server available in the GenAI Playground, add it to the `gen-ai-aa-mcp-servers` ConfigMap:

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: redhat-ods-applications
data:
  Kubernetes-MCP-Server: |
    {
      "url": "http://kubernetes-mcp-server.<namespace>.svc.cluster.local:8080/mcp",
      "transport": "streamable-http",
      "description": "Kubernetes/OpenShift cluster operations - pods, deployments, services, logs"
    }
EOF
```

---

## Verification and Testing

### Check deployment status

```bash
NAMESPACE="my-ai-project"

# Pods
oc get pods -n $NAMESPACE -l app=kubernetes-mcp-server

# Service
oc get svc kubernetes-mcp-server -n $NAMESPACE

# Health check
oc exec deploy/kubernetes-mcp-server -n $NAMESPACE -- \
    wget -qO- http://localhost:8080/ 2>&1
# Expected: {"status":"alive"}
```

### Test MCP endpoint from another pod

```bash
# From any pod in the cluster
curl -s http://kubernetes-mcp-server.<namespace>.svc.cluster.local:8080/

# Test tool listing (SSE endpoint)
curl -s http://kubernetes-mcp-server.<namespace>.svc.cluster.local:8080/mcp \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

### Test from LlamaStack / GenAI Playground

1. Open GenAI Playground in the RHOAI dashboard
2. Select a model with tool calling enabled (e.g., Qwen3-4B with `--tool-call-parser=hermes`)
3. Ask: "List all pods in the default namespace"
4. The model should invoke the MCP server's `pods_list_in_namespace` tool

> **Tip:** Use temperature 0 for reliable tool-calling results. Non-zero temperatures can cause the model to hallucinate tool responses instead of reporting errors.

---

## Troubleshooting

### Pod not starting

```bash
# Check pod events
oc describe pod -n $NAMESPACE -l app=kubernetes-mcp-server

# Check logs
oc logs -n $NAMESPACE -l app=kubernetes-mcp-server
```

### 403 Forbidden / Permission denied

The ServiceAccount lacks RBAC access:

```bash
# Check existing ClusterRoleBindings
oc get clusterrolebinding | grep mcp

# Create/recreate the binding
oc create clusterrolebinding kubernetes-mcp-server-$NAMESPACE \
    --clusterrole=view \
    --serviceaccount=$NAMESPACE:kubernetes-mcp-server \
    --dry-run=client -o yaml | oc apply -f -
```

### "No response received from tool" in Playground

1. **Check MCP endpoint URL** — port should be `8080`, not `80`
2. **Check service exists:**
   ```bash
   oc get svc kubernetes-mcp-server -n $NAMESPACE
   ```
3. **Test connectivity from dashboard pod:**
   ```bash
   oc exec deploy/rhods-dashboard -n redhat-ods-applications -c rhods-dashboard -- \
       curl -s http://kubernetes-mcp-server.$NAMESPACE.svc.cluster.local:8080/
   ```

### Model hallucinating tool results

- The MCP server returns empty/error for non-existent namespaces — the model fills in fake data
- **Fix:** Use temperature 0 for tool-calling queries
- **Fix:** Ensure you're using the correct namespace name in prompts
- Smaller models (< 20B) are less reliable at following "don't fabricate" instructions

### BuildConfig fails (Method 2)

```bash
# Check build logs
oc logs -f bc/kubernetes-mcp-server -n $NAMESPACE

# Common issues:
# - Network access to GitHub blocked → check egress rules
# - Go build OOM → increase build resource limits
# - Registry push failed → check internal registry is running
oc get pods -n openshift-image-registry
```

### Helm install fails with "Ingress hostname must be specified"

The Helm chart requires ingress config by default. Disable it:

```bash
helm upgrade --install kubernetes-mcp-server ... \
    --set ingress.enabled=false \
    --set route.enabled=false
```

---

## Available Tools Reference

### Core Toolset (`core`)

| Tool | Description |
|------|-------------|
| `resources_list` | List any Kubernetes resource type in a namespace |
| `resources_get` | Get a specific resource by name |
| `resources_create_or_update` | Create or update a resource from YAML/JSON |
| `resources_delete` | Delete a resource |
| `pods_list_in_namespace` | List pods in a namespace |
| `pods_get` | Get pod details |
| `pods_delete` | Delete a pod |
| `pods_log` | Get pod container logs |
| `pods_exec` | Execute command in a pod (requires `exec` toolset) |
| `pods_run` | Run a container image as a pod |
| `pods_top` | Get pod resource usage metrics |
| `namespaces_list` | List all namespaces |
| `projects_list` | List OpenShift projects |

### Events Toolset (`events`)

| Tool | Description |
|------|-------------|
| `events_list` | List events in a namespace or cluster-wide |

### Helm Toolset (`helm`)

| Tool | Description |
|------|-------------|
| `helm_install` | Install a Helm chart |
| `helm_list` | List Helm releases |
| `helm_uninstall` | Uninstall a Helm release |

### Tekton Toolset (`tekton`)

| Tool | Description |
|------|-------------|
| `tekton_pipeline_start` | Start a Tekton Pipeline (create PipelineRun) |
| `tekton_pipelinerun_restart` | Restart a PipelineRun |
| `tekton_task_start` | Start a Tekton Task (create TaskRun) |
| `tekton_taskrun_restart` | Restart a TaskRun |
| `tekton_taskrun_log` | Get TaskRun logs |

---

## Quick Reference

```bash
# Deploy (BuildConfig method — one-liner)
NAMESPACE="my-ai-project"
oc new-build --name=kubernetes-mcp-server --strategy=docker -n $NAMESPACE \
    --dockerfile='FROM registry.access.redhat.com/ubi9/go-toolset:latest AS builder
WORKDIR /opt/app-root/src
RUN git clone --depth=1 https://github.com/openshift/openshift-mcp-server.git . && \
    CGO_ENABLED=0 go build -o /opt/app-root/kubernetes-mcp-server ./cmd/kubernetes-mcp-server/
FROM registry.access.redhat.com/ubi9-micro:latest
COPY --from=builder /opt/app-root/kubernetes-mcp-server /usr/local/bin/kubernetes-mcp-server
USER 1001
ENTRYPOINT ["kubernetes-mcp-server"]'

# MCP endpoint
echo "http://kubernetes-mcp-server.${NAMESPACE}.svc.cluster.local:8080/mcp"

# RBAC
oc create clusterrolebinding kubernetes-mcp-server-$NAMESPACE \
    --clusterrole=view --serviceaccount=$NAMESPACE:kubernetes-mcp-server

# Toolkit shortcut
./rhoai-toolkit.sh  # → RHOAI Management → AI Services → MCP Server Management
```

---

**Last Updated:** May 2026
**Source:** [openshift/openshift-mcp-server](https://github.com/openshift/openshift-mcp-server)
**RHOAI Version:** 3.3
**OpenShift Version:** 4.19–4.21
