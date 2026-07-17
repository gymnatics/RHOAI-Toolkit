# OpenShift Lightspeed Troubleshooting Demo

Demonstrates how OpenShift Lightspeed uses MCP (Model Context Protocol) servers to troubleshoot and fix a broken deployment — including applying fixes directly with human-in-the-loop approval.

## What This Demo Shows

1. A deployment with an **intentional image typo** (`hello-world-nginxx` instead of `hello-world-nginx`)
2. Lightspeed **diagnoses** the issue using MCP tools (pod inspection, event reading)
3. Lightspeed **applies the fix** directly via `resources_create_or_update` with user approval (HITL)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  OpenShift Console                                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Lightspeed Chat (spark icon)                         │  │
│  │  "Why are my pods failing?" → diagnose → fix          │  │
│  └────────────────────────┬──────────────────────────────┘  │
│                           │                                  │
│  ┌────────────────────────▼──────────────────────────────┐  │
│  │  Lightspeed API Server                                │  │
│  │  ├── Built-in MCP (read-only: pods, events, metrics)  │  │
│  │  └── Custom MCP (read/write: create, update, delete)  │  │
│  └────────────────────────┬──────────────────────────────┘  │
│                           │                                  │
│  ┌────────────────────────▼──────────────────────────────┐  │
│  │  oc-mcp-server (read_only=false)                      │  │
│  │  Tools: resources_create_or_update, pods_delete, etc.  │  │
│  └────────────────────────┬──────────────────────────────┘  │
│                           │                                  │
│  ┌────────────────────────▼──────────────────────────────┐  │
│  │  Kubernetes API → customer-portal deployment (broken)  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- OpenShift 4.x cluster with cluster-admin access
- Lightspeed Operator installed (v1.1+)
- At least one vLLM/InferenceService model deployed (for the LLM backend)
- (Optional) MCP server deployed via MCP Catalog for write operations

## Quick Start

```bash
# Full deployment (configures Lightspeed + MCP + deploys broken app)
./deploy.sh deploy

# Or just deploy the broken app (if Lightspeed already configured)
./deploy.sh broken-app

# Apply the fix manually
./deploy.sh fix

# Cleanup
./deploy.sh cleanup
```

## Demo Flow

### Step 1: Deploy Broken App
```bash
./deploy.sh deploy
```

This will:
- Auto-detect your model (InferenceService)
- Configure OLSConfig with the model + MCP server
- Enable the `MCPServer` feature gate for custom MCP support
- Deploy a broken `customer-portal` app with an image typo

### Step 2: Observe Failure
Open the console → Workloads → Deployments → `lightspeed-demo`:
- Pods are in `ImagePullBackOff`
- Events show: `Failed to pull image "quay.io/redhattraining/hello-world-nginxx:latest"`

### Step 3: Ask Lightspeed
Click the Lightspeed spark icon and ask:
> "Why are the pods in lightspeed-demo namespace failing?"

Lightspeed will:
1. Use `pods_list_in_namespace` to see pod status
2. Use `events_list` to read error events
3. Identify the image typo

### Step 4: Ask Lightspeed to Fix
> "Fix the image name — it should be hello-world-nginx not hello-world-nginxx"

Lightspeed will:
1. Use `resources_get` to fetch the deployment spec
2. Propose a `resources_create_or_update` with the corrected image
3. Show an **approval prompt** (human-in-the-loop)
4. You click approve → deployment updated → pods start

## Key Configuration

### OLSConfig Fields

| Field | Purpose |
|-------|---------|
| `spec.featureGates: [MCPServer]` | Enables custom MCP server support |
| `spec.mcpServers[]` | Registers external MCP servers |
| `spec.ols.introspectionEnabled` | Enables built-in MCP (read-only) |
| `spec.ols.maxIterations` | Max tool-calling loops (default 5) |

### MCP Server Config (config.toml)

| Field | Demo Value | Purpose |
|-------|-----------|---------|
| `read_only` | `false` | Exposes write tools |
| `disable_destructive` | `false` | Allows update/delete operations |
| `toolsets` | `["core", "config", "openshift"]` | Available tool groups |

### Tools Approval (HITL)

The `toolsApprovalConfig` controls write operation safety:

| Mode | Behavior |
|------|----------|
| `tool_annotations` (default) | Reads auto-approve, writes need approval |
| `always` | Every tool call needs approval |
| `never` | No approval needed (dangerous) |

## Troubleshooting

### "Tool 'resources_edit' call skipped: tool is unavailable"
The MCP server is in read-only mode. Fix:
```bash
# Patch the MCP server config to enable writes
oc patch configmap openshift-mcp-server-config -n <mcp-namespace> \
  --type='merge' -p '{"data":{"config.toml":"read_only = false\ndisable_destructive = false\nstateless = true\ntoolsets = [\"core\", \"config\", \"openshift\"]\n"}}'
# Restart the MCP server
oc rollout restart deployment/<mcp-server-name> -n <mcp-namespace>
```

### "resource not allowed: /v1, Kind=Secret"
The built-in MCP server blocks Secret access by design (security guardrail). Avoid asking questions that require reading secrets. Instead, ask about pods, events, and deployments.

### Lightspeed loops without fixing
The model may be too small (8B parameters) to handle complex multi-step troubleshooting. Try:
- Being more explicit in your prompt: "The image has a typo, change nginxx to nginx"
- Using a larger model as the LLM backend
- Starting a new chat session if the model gets stuck

## Files

```
demo/lightspeed-demo/
├── deploy.sh                          # Main orchestration script
├── README.md                          # This file
└── manifests/
    ├── olsconfig.yaml                 # OLSConfig template (envsubst)
    ├── broken-app.yaml                # Broken deployment (image typo)
    ├── fixed-app.yaml                 # Correct deployment (reference)
    └── mcp-server-config.yaml         # MCP server config with write access
```

## References

- [Red Hat OpenShift Lightspeed Configure Guide](https://docs.redhat.com/en/documentation/red_hat_openshift_lightspeed/1.0/html/configure/ols-configuring-openshift-lightspeed)
- [OLSConfig API Reference](https://docs.redhat.com/en/documentation/red_hat_openshift_lightspeed/1.0/html/configure/olsconfig-api)
- [OpenShift MCP Server Configuration](https://github.com/openshift/openshift-mcp-server/blob/main/docs/configuration.md)
- [MCP Catalog Setup](../../docs/guides/MCP-CATALOG-SETUP.md)
