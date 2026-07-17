# Adding Custom Dashboards to OpenShift Observe Tab

**Applies to:** OpenShift Container Platform 4.10+ (tested on 4.20+)
**Last Updated:** May 8, 2026

---

## Overview

OpenShift's built-in **Observe > Dashboards** page supports custom Grafana dashboards loaded via ConfigMaps. This guide covers how to add NVIDIA DCGM, vLLM, and other custom dashboards without installing a separate Grafana instance.

### How It Works

1. You create a **ConfigMap** in the `openshift-config-managed` namespace containing a Grafana dashboard JSON
2. You label the ConfigMap with `console.openshift.io/dashboard=true`
3. OpenShift's console picks it up and renders it under **Observe > Dashboards**

### Console Perspective Changes (OCP 4.19+)

Starting with **OCP 4.19**, the separate Administrator and Developer perspectives were **unified into a single console view**. There is no longer a perspective toggle in the sidebar.

| OCP Version | Console Layout |
|---|---|
| 4.18 and earlier | Two perspectives: Administrator / Developer (toggle in sidebar) |
| 4.19+ | Unified single view (no toggle) |
| 4.21+ | "Administrator" renamed to "Core platform" |

### Project Scoping

In the unified view, the **Project dropdown** at the top controls metric scope:

| Project Selection | Metric Scope | Requirements |
|---|---|---|
| Specific project (e.g., `my-ai-project`) | Only metrics from pods in that namespace | Project access |
| **All Projects** | Aggregated metrics across all namespaces | `cluster-admin` or `cluster-monitoring-view` role |

**Note:** Platform-level metrics (e.g., NVIDIA DCGM GPU metrics) are cluster-scoped regardless of project selection, since they come from platform Prometheus rather than User Workload Monitoring.

For cross-project dashboarding with full Grafana features, deploy standalone Grafana via the Grafana Operator (see the Alternative section at the end of this guide).

### Important Constraints

OpenShift's dashboard viewer uses a **legacy Grafana renderer** (not full Grafana). This means:

| Feature | Supported | Not Supported |
|---|---|---|
| Panel type `graph` | Yes | `timeseries`, `bargauge`, `table` (newer types) |
| Panel type `gauge` | Yes | `stat` (use `singlestat` instead) |
| `schemaVersion` 22 | Yes | `schemaVersion` 36+ may not render |
| Datasource as string (`"$datasource"`) | Yes | Datasource as object (`{"type":"prometheus","uid":"..."}`) |
| Template variables | Yes | Some advanced variable features |
| `renderer: "flot"` | Yes | `renderer: "canvas"` |

> **Rule of thumb:** If a Grafana dashboard JSON was built for Grafana 7+ or 8+, it will likely need to be adapted. Dashboards built for Grafana 6.x work out of the box.

---

## Prerequisites

- `cluster-admin` access to the OpenShift cluster
- `oc` CLI logged in
- For GPU metrics: NVIDIA GPU Operator installed
- For vLLM metrics: vLLM serving runtime deployed + metrics being scraped

---

## 1. NVIDIA DCGM Exporter Dashboard

This is officially documented by NVIDIA and works out of the box.

### Steps

```bash
# Download the DCGM dashboard JSON
curl -LfO https://github.com/NVIDIA/dcgm-exporter/raw/main/grafana/dcgm-exporter-dashboard.json

# Create ConfigMap
oc create configmap nvidia-dcgm-exporter-dashboard \
  -n openshift-config-managed \
  --from-file=dcgm-exporter-dashboard.json

# Label for Administrator perspective
oc label configmap nvidia-dcgm-exporter-dashboard \
  -n openshift-config-managed \
  "console.openshift.io/dashboard=true"

# (Optional) Label for Developer perspective
oc label configmap nvidia-dcgm-exporter-dashboard \
  -n openshift-config-managed \
  "console.openshift.io/odc-dashboard=true"

# Verify
oc -n openshift-config-managed get cm nvidia-dcgm-exporter-dashboard --show-labels
```

### Result

Navigate to **Observe > Dashboards** and select **"NVIDIA DCGM Exporter Dashboard"** from the dropdown.

### Panels Included

| Panel | Description |
|---|---|
| GPU Temperature | Per-GPU temperature in Celsius |
| GPU Avg. Temp | Average GPU temperature (gauge) |
| GPU Power Usage | Power consumption in watts per GPU |
| GPU Power Total | Aggregate power consumption (gauge) |
| GPU SM Clocks | Streaming multiprocessor clock frequency |
| GPU Utilization | GPU utilization percentage |
| GPU Framebuffer Mem Used | VRAM usage in MB |
| Tensor Core Utilization | Tensor/HMMA pipe activity percentage |

### Prerequisite: GPU Operator + DCGM Exporter

The NVIDIA GPU Operator automatically deploys the DCGM Exporter, which exposes metrics to OpenShift's Prometheus. Verify metrics are flowing:

```bash
# Check DCGM pods are running
oc get pods -n nvidia-gpu-operator | grep dcgm

# Query a DCGM metric via Prometheus
oc exec -n openshift-monitoring prometheus-k8s-0 -c prometheus -- \
  curl -s 'http://localhost:9090/api/v1/query?query=DCGM_FI_DEV_GPU_UTIL' | python3 -m json.tool
```

### Reference

- [NVIDIA GPU Operator Docs: Enabling the GPU Monitoring Dashboard](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/enable-gpu-monitoring-dashboard.html)

---

## 2. vLLM Performance Dashboard

There is no official OpenShift-ready vLLM dashboard. The official vLLM project provides Grafana 8+ dashboards that need adaptation for OpenShift's viewer.

An adapted dashboard is provided in this directory: `vllm-performance-ocp.json`

### Steps

```bash
# Using the pre-adapted dashboard from this repo
oc create configmap vllm-performance-dashboard \
  -n openshift-config-managed \
  --from-file=vllm-performance-ocp.json

# Label for Observe > Dashboards
oc label configmap vllm-performance-dashboard \
  -n openshift-config-managed \
  "console.openshift.io/dashboard=true"

# (Optional) Label for Developer perspective
oc label configmap vllm-performance-dashboard \
  -n openshift-config-managed \
  "console.openshift.io/odc-dashboard=true"
```

### Panels Included

| Panel | Metrics Used |
|---|---|
| E2E Request Latency (P50/P90/P99) | `vllm:e2e_request_latency_seconds_bucket` |
| Time to First Token (P50/P95/P99) | `vllm:time_to_first_token_seconds_bucket` |
| Inter-Token Latency (P50/P95) | `vllm:inter_token_latency_seconds_bucket` |
| Request Throughput | `vllm:request_success_total` |
| Token Processing Rate | `vllm:prompt_tokens_total`, `vllm:generation_tokens_total` |
| Request Queue Status | `vllm:num_requests_running`, `vllm:num_requests_waiting` |
| KV Cache Usage | `vllm:gpu_cache_usage_perc`, `vllm:cpu_cache_usage_perc` |
| Preemption Rate | `vllm:num_preemptions_total` |

### Template Variables

The dashboard includes three filter dropdowns:

| Dropdown | Label | Behavior |
|---|---|---|
| **datasource** | Prometheus | Selects the Prometheus datasource |
| **namespace** | Project | Multi-select. Auto-discovers all projects with vLLM workloads. Select one, several, or "All". |
| **model** | Model | Multi-select. Auto-discovers models, **filtered by selected project(s)**. Updates dynamically when project selection changes. |

The **Model** dropdown is chained to **Project** -- selecting specific projects will only show models deployed in those projects.

### RBAC and Security

The dashboard ConfigMap is cluster-wide (visible to all users), but the **metrics data** is protected by OpenShift's monitoring RBAC at the Prometheus/Thanos Querier layer.

**How access control works:**

```
Dashboard dropdown query → Thanos Querier → prom-label-proxy (RBAC check) → Prometheus
```

The `prom-label-proxy` component filters query results before they reach the dashboard, only returning data from namespaces the user has `view` access to.

| User Access Level | What They See |
|---|---|
| `view` role on `project-a` only | Project dropdown shows only `project-a`. Only `project-a` metrics displayed. |
| `view` role on `project-a` + `project-b` | Both projects appear. Can filter to one or both. |
| `cluster-monitoring-view` role | All projects with vLLM metrics appear. Full cluster-wide view. |
| No `view` role on any vLLM project | Empty dropdowns, no data. |

**Key point:** Unauthorized projects don't appear in the dropdown at all -- they are invisible, not just blocked. There is no way for a non-admin user to view metrics from projects they don't have access to, even if they manipulate the query.

Relevant RBAC roles:

| Role | Scope | Grants |
|---|---|---|
| `view` | Namespace | Can view metrics from that namespace |
| `monitoring-rules-view` | Namespace | Can view PrometheusRules/alerts |
| `monitoring-edit` | Namespace | Can manage ServiceMonitors and alerts |
| `cluster-monitoring-view` | Cluster | Can view all metrics cluster-wide |
| `cluster-admin` | Cluster | Full access to everything |

### Prerequisite: vLLM Metrics Scraping

vLLM must be deployed and its metrics endpoint scraped by Prometheus.

**Option A: RHOAI KServe deployment** — If using RHOAI's KServe with vLLM ServingRuntime, metrics may already be scraped via the existing `modelmesh-metrics-monitor` or `odh-model-controller-metrics-monitor` ServiceMonitors.

**Option B: Manual ServiceMonitor** — If metrics aren't being scraped:

```bash
# 1. Ensure User Workload Monitoring is enabled
oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
EOF

# 2. Create a ServiceMonitor for vLLM
oc apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vllm-monitor
  namespace: <your-vllm-namespace>
spec:
  selector:
    matchLabels:
      app: vllm
  endpoints:
  - port: metrics
    interval: 30s
EOF
```

### Reference

- [vLLM Observability Docs](https://docs.vllm.ai/en/stable/examples/observability/dashboards/)
- [Official vLLM Grafana JSONs (Grafana 8+ format)](https://github.com/vllm-project/vllm/tree/main/examples/observability/dashboards/grafana)

---

## 3. Adding Any Custom Dashboard

### Step-by-Step Process

#### Step 1: Get or Create the Dashboard JSON

Sources for dashboard JSONs:
- [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/) (search by ID)
- GitHub repos for your specific tool/operator
- Export from an existing Grafana instance

#### Step 2: Adapt for OpenShift (if needed)

If the dashboard was built for Grafana 7+, you need to convert it:

**a) Change panel types:**

```
"timeseries" → "graph"
"stat" → "singlestat"
```

**b) Change datasource format:**

```json
// BEFORE (Grafana 8+ object format — won't work)
"datasource": {
  "type": "prometheus",
  "uid": "prometheus"
}

// AFTER (string format — works in OpenShift)
"datasource": "$datasource"
```

**c) Lower the schema version:**

```json
// BEFORE
"schemaVersion": 39

// AFTER
"schemaVersion": 22
```

**d) Add the `$datasource` template variable:**

```json
"templating": {
  "list": [
    {
      "current": { "selected": true, "text": "Prometheus", "value": "Prometheus" },
      "hide": 0,
      "includeAll": false,
      "multi": false,
      "name": "datasource",
      "options": [],
      "query": "prometheus",
      "refresh": 1,
      "type": "datasource"
    }
  ]
}
```

**e) Use the legacy `graph` panel structure:**

```json
{
  "aliasColors": {},
  "bars": false,
  "dashLength": 10,
  "dashes": false,
  "datasource": "$datasource",
  "fill": 1,
  "fillGradient": 0,
  "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 },
  "id": 1,
  "legend": {
    "alignAsTable": true,
    "avg": true,
    "current": true,
    "max": true,
    "min": false,
    "rightSide": false,
    "show": true,
    "total": false,
    "values": true
  },
  "lines": true,
  "linewidth": 2,
  "nullPointMode": "null",
  "percentage": false,
  "pointradius": 2,
  "points": false,
  "renderer": "flot",
  "seriesOverrides": [],
  "spaceLength": 10,
  "stack": false,
  "steppedLine": false,
  "targets": [
    {
      "expr": "your_prometheus_query_here",
      "legendFormat": "{{label}}",
      "refId": "A"
    }
  ],
  "thresholds": [],
  "title": "Panel Title",
  "tooltip": { "shared": true, "sort": 0, "value_type": "individual" },
  "type": "graph",
  "xaxis": { "mode": "time", "show": true },
  "yaxes": [
    { "format": "short", "label": "", "logBase": 1, "show": true },
    { "format": "short", "logBase": 1, "show": false }
  ],
  "yaxis": { "align": false }
}
```

#### Step 3: Validate the JSON

Always validate before deploying:

```bash
python3 -c "import json; json.load(open('your-dashboard.json')); print('Valid JSON')"
```

#### Step 4: Deploy

```bash
# Create ConfigMap
oc create configmap <dashboard-name> \
  -n openshift-config-managed \
  --from-file=<your-dashboard-file>.json

# Label for Observe > Dashboards
oc label configmap <dashboard-name> \
  -n openshift-config-managed \
  "console.openshift.io/dashboard=true"

# (Optional) Developer perspective
oc label configmap <dashboard-name> \
  -n openshift-config-managed \
  "console.openshift.io/odc-dashboard=true"
```

#### Step 5: Verify

```bash
oc -n openshift-config-managed get cm <dashboard-name> --show-labels
```

Then navigate to **Observe > Dashboards** and select your dashboard from the dropdown.

---

## Managing Dashboards

### List all dashboards

```bash
oc -n openshift-config-managed get cm -l "console.openshift.io/dashboard=true"
```

### Update a dashboard

```bash
oc delete configmap <dashboard-name> -n openshift-config-managed
oc create configmap <dashboard-name> -n openshift-config-managed --from-file=<file>.json
oc label configmap <dashboard-name> -n openshift-config-managed "console.openshift.io/dashboard=true"
```

### Remove a dashboard

```bash
oc delete configmap <dashboard-name> -n openshift-config-managed
```

---

## Common Unit Formats

Use these in the `yaxes.format` field:

| Format | Description |
|---|---|
| `s` | Seconds |
| `ms` | Milliseconds |
| `percent` | Percentage (0-100) |
| `percentunit` | Percentage (0-1) |
| `bytes` | Bytes (auto-scales to KB/MB/GB) |
| `short` | Plain number |
| `reqps` | Requests per second |
| `celsius` | Temperature in Celsius |
| `watt` | Power in Watts |
| `hertz` | Frequency |
| `decbytes` | Decimal bytes |

---

## Troubleshooting

### Panels don't render (blank dashboard)

1. **Check JSON validity:** `python3 -c "import json; json.load(open('file.json'))"`
2. **Check panel type:** Must be `graph` or `gauge`, not `timeseries` or `stat`
3. **Check datasource format:** Must be a string (`"$datasource"`), not an object
4. **Check schemaVersion:** Use `22`, not `36`+

### Panels render but show "No data"

1. **Check if metrics exist:**
   ```bash
   # Via Observe > Metrics in the console, or:
   oc exec -n openshift-monitoring prometheus-k8s-0 -c prometheus -- \
     curl -s 'http://localhost:9090/api/v1/query?query=<metric_name>' | python3 -m json.tool
   ```
2. **Check ServiceMonitor exists** for your workload
3. **Check User Workload Monitoring** is enabled (for user namespace metrics)

### Template variable dropdown is empty

The variable's label query returned no results. This usually means the underlying metric doesn't exist yet (e.g., no vLLM pods running).

---

## Other Useful Dashboards

| Dashboard | Source | Notes |
|---|---|---|
| NVIDIA DCGM | [GitHub](https://github.com/NVIDIA/dcgm-exporter/raw/main/grafana/dcgm-exporter-dashboard.json) | Works out of the box |
| Knative Serving | Installed automatically with OpenShift Serverless | Already in `openshift-config-managed` |
| etcd | Installed automatically | Already in `openshift-config-managed` |
| Node/Cluster Resources | Installed automatically | Already in `openshift-config-managed` |
| GitOps/ArgoCD | Installed with OpenShift GitOps | Already in `openshift-config-managed` |
| vLLM | `vllm-performance-ocp.json` (this repo) | Pre-adapted for OpenShift |

---

## Alternative: Full Grafana via Grafana Operator

If you need the full Grafana experience (newer panel types, alerting, annotations, external datasources), install the **Grafana Operator** from OperatorHub. This deploys a standalone Grafana instance (separate UI, not embedded in Observe tab) that connects to OpenShift's Thanos Querier:

```
Thanos Querier endpoint: https://thanos-querier.openshift-monitoring.svc.cluster.local:9091
```

This approach supports any Grafana dashboard JSON without adaptation, but requires managing a separate Grafana deployment.
