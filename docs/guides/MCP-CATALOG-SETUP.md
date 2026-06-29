# MCP Catalog Setup Guide

**RHOAI 3.4** | Last updated: June 2026

> **Developer Preview:** The MCP Catalog and MCP Lifecycle Operator are **Developer Preview** features in RHOAI 3.4. The MCP Gateway is **Tech Preview**. Developer Preview features are not supported by Red Hat production SLAs, may not be functionally complete, and are not recommended for production use. They are provided for testing and feedback only.
>
> | Component | Status |
> |---|---|
> | MCP Catalog (dashboard UI) | Developer Preview |
> | MCP Lifecycle Operator (`MCPServer` CRD) | Developer Preview |
> | MCP Gateway | Tech Preview |

The MCP Catalog allows users to discover and deploy Model Context Protocol (MCP) servers directly from the RHOAI dashboard's AI Hub. It is powered by the [MCP Lifecycle Operator](https://github.com/kubernetes-sigs/mcp-lifecycle-operator) from kubernetes-sigs.

## Prerequisites

- RHOAI 3.4 installed and running
- `oc` CLI with cluster-admin access
- DataScienceCluster in Ready state

## Step 1: Install MCP Lifecycle Operator

The MCP Lifecycle Operator manages `MCPServer` custom resources. It watches for MCPServer CRs and deploys the corresponding MCP server pods.

```bash
# Check if already installed
if oc get crd mcpservers.mcp.x-k8s.io &>/dev/null; then
    echo "MCP Lifecycle Operator already installed"
else
    echo "Installing MCP Lifecycle Operator..."
    kubectl apply -f "https://github.com/kubernetes-sigs/mcp-lifecycle-operator/releases/latest/download/install.yaml"
fi
```

Wait for the operator pod to be running:

```bash
oc get pods -n mcp-lifecycle-operator-system -w
# Wait for: mcp-lifecycle-operator-controller-manager  1/1  Running
```

## Step 2: Enable mcpCatalog Dashboard Flag

The `mcpCatalog` flag enables the MCP Servers page under AI Hub in the RHOAI dashboard.

```bash
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/dashboardConfig/mcpCatalog", "value": true}]'
```

Verify the flag is set:

```bash
oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
  -o jsonpath='{.spec.dashboardConfig.mcpCatalog}'
# Should return: true
```

## Step 3: Set Up Prerequisites for MCP Server Namespaces

When deploying MCP servers from the catalog, each namespace needs a ServiceAccount and config ConfigMap. The MCP Catalog does NOT auto-create these.

For each namespace where MCP servers will be deployed:

```bash
NAMESPACE="<your-namespace>"

# Create ServiceAccount with view permissions
oc create serviceaccount mcp-viewer -n "$NAMESPACE"
oc create clusterrolebinding "mcp-viewer-${NAMESPACE}" \
    --clusterrole=view \
    --serviceaccount="${NAMESPACE}:mcp-viewer"

# Create MCP server config
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: openshift-mcp-server-config
  namespace: $NAMESPACE
data:
  config.toml: |
    port = "8080"
    read_only = true
    stateless = true
    toolsets = ["core", "config", "openshift"]
EOF
```

## Step 4: Verify in Dashboard

1. Open the RHOAI dashboard at `https://rh-ai.apps.<cluster>`
2. Navigate to **AI Hub > MCP Servers**
3. The MCP Catalog should be visible, listing available MCP server types

## Deploying an MCP Server

### From the Dashboard

1. Go to **AI Hub > MCP Servers**
2. Select a server type from the catalog
3. Choose the target namespace
4. Click Deploy

### From CLI (MCPServer CR)

```yaml
apiVersion: mcp.x-k8s.io/v1alpha1
kind: MCPServer
metadata:
  name: openshift-mcp-server
  namespace: <namespace>
spec:
  transport: sse
  image: quay.io/openshift-mcp/openshift-mcp-server:latest
  serviceAccountName: mcp-viewer
  configMapRef:
    name: openshift-mcp-server-config
```

```bash
oc apply -f mcpserver.yaml
```

## MCP Gateway (Tech Preview)

The **MCP Gateway** is an Envoy-based reverse proxy (upstream: [Kuadrant/mcp-gateway](https://github.com/Kuadrant/mcp-gateway)) that aggregates multiple deployed MCP servers behind a **single managed endpoint** with enterprise traffic controls. It is part of **Red Hat Connectivity Link 1.4+** and integrates with RHOAI 3.4.

### What the MCP Gateway provides

| Capability | Detail |
|---|---|
| **Tool federation** | Aggregates tools from multiple MCP servers at one endpoint (`/mcp`) |
| **Transport** | Streamable HTTP (MCP spec 2025-06-18+) — NOT SSE |
| **Auth discovery** | OAuth 2.0 Protected Resource Metadata at `/.well-known/oauth-protected-resource` |
| **Auth enforcement** | JWT validation via Kuadrant `AuthPolicy` targeting the Gateway listener |
| **Rate limiting** | Kuadrant `RateLimitPolicy` on the same Gateway |
| **Per-tool metrics** | Identity-aware routing + per-tool Prometheus metrics |
| **Virtual servers** | Slice tool lists into focused subsets per team/agent |
| **Horizontal scaling** | Redis-backed session store for multi-replica deployments |

### Is the MCP Gateway a standards-based MCP registry?

**No** — the MCP Gateway is NOT the same as the [modelcontextprotocol/registry](https://modelcontextprotocol.io/registry/about) spec (`registry.modelcontextprotocol.io`). They are different layers:

| Layer | What it does | Standard |
|---|---|---|
| **MCP Registry** (`modelcontextprotocol.io/registry`) | Static metadata catalog — discovery of publicly listed server names/URLs | OpenAPI-based REST at `/v0.1/servers` |
| **MCP Gateway** (Red Hat / Kuadrant) | Runtime proxy — authenticates, federates, and rate-limits live agent→tool traffic | OAuth 2.1 + RFC 9728 (Protected Resource Metadata) |

The Gateway exposes the **runtime OAuth discovery** endpoints that MCP clients use to auto-configure auth, not a registry of available servers.

### OAuth discovery endpoint (RFC 9728)

When authentication is enabled, the Gateway broker serves:

```
GET /.well-known/oauth-protected-resource
```

Example response:
```json
{
  "resource_name": "MCP Server",
  "resource": "https://mcp.apps.<cluster>/mcp",
  "authorization_servers": [
    "https://keycloak.apps.<cluster>/realms/mcp"
  ],
  "bearer_methods_supported": ["header"],
  "scopes_supported": ["basic", "groups", "roles", "profile"]
}
```

This is the **MCP Authorization spec** (v2025-06-18) compliant discovery flow — clients that implement RFC 9728 (VS Code, Copilot, Claude Desktop, etc.) can auto-discover the identity provider from a `401 WWW-Authenticate` response.

### VS Code / GitHub Copilot Consumption

**Yes** — VS Code with GitHub Copilot can consume MCP servers from the gateway directly using streamable HTTP transport.

Add to `.vscode/mcp.json` or `settings.json`:

```json
{
  "mcp": {
    "servers": {
      "openshift-mcp-gateway": {
        "type": "http",
        "url": "https://mcp.apps.<cluster>/mcp",
        "headers": {
          "Authorization": "Bearer <your-token>"
        }
      }
    }
  }
}
```

Or without a pre-configured token (VS Code handles the OAuth flow automatically when the server returns a `401` with `WWW-Authenticate: Bearer resource_metadata=...`):

```json
{
  "mcp": {
    "servers": {
      "openshift-mcp-gateway": {
        "type": "http",
        "url": "https://mcp.apps.<cluster>/mcp"
      }
    }
  }
}
```

In Copilot Chat, switch to **Agent mode** (`⌃⌘I` → Agent dropdown) to access the tools registered on the gateway.

### Key CRDs (Red Hat Connectivity Link 1.4)

```yaml
# Extend an existing Gateway API gateway with MCP capabilities
apiVersion: mcp.kuadrant.io/v1alpha1
kind: MCPGatewayExtension
metadata:
  name: mcp-extension
  namespace: gateway-system
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: mcp-gateway
    namespace: gateway-system
  oauthProtectedResource:
    authorizationServers:
      - "https://keycloak.apps.<cluster>/realms/mcp"
    scopesSupported: ["basic", "groups", "roles", "profile"]
```

```yaml
# Register a deployed MCP server behind the gateway
apiVersion: mcp.kuadrant.io/v1alpha1
kind: MCPServerRegistration
metadata:
  name: openshift-mcp
  namespace: mcp-servers
spec:
  toolPrefix: "openshift_"
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: openshift-mcp-route
    namespace: mcp-servers
```

```yaml
# JWT auth policy (Kuadrant) attached to the Gateway MCP listener
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: mcp-jwt-auth
  namespace: gateway-system
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: mcp-gateway
    sectionName: mcp
  defaults:
    when:
      - predicate: "!request.path.contains('/.well-known')"
    rules:
      authentication:
        keycloak:
          jwt:
            issuerUrl: https://keycloak.apps.<cluster>/realms/mcp
      response:
        unauthenticated:
          code: 401
          headers:
            WWW-Authenticate:
              value: >
                Bearer resource_metadata=https://mcp.apps.<cluster>/.well-known/oauth-protected-resource/mcp
```

### Authentication methods supported

| Method | Support |
|---|---|
| **JWT / Bearer token** (OIDC/OAuth 2.1) | Native via `AuthPolicy` |
| **API Key** | Via Kuadrant `AuthPolicy` with header/query extraction |
| **mTLS** | Via Istio/Gateway API mechanisms |
| **OAuth Token Exchange** (RFC 8693) | Advanced — scopes down broad tokens per upstream MCP server |
| **Vault credential injection** | Advanced — fetches per-user credentials from HashiCorp Vault |
| **Any Istio/Gateway API mechanism** | Gateway itself is auth-agnostic; policy is pluggable |

> **Note**: The `/.well-known/oauth-protected-resource` endpoint is always open (bypassed by `when` predicate) so MCP clients can auto-discover auth without a token.

### Discoverable format summary

The gateway provides everything a compliant MCP client needs to bootstrap auth:

| Field | Where exposed |
|---|---|
| **Server URL** | `resource` in `/.well-known/oauth-protected-resource` |
| **Transport type** | Streamable HTTP at `/mcp` |
| **Auth method** | `bearer_methods_supported` in `/.well-known/oauth-protected-resource` |
| **Scopes** | `scopes_supported` in `/.well-known/oauth-protected-resource` |
| **Identity provider** | `authorization_servers` in `/.well-known/oauth-protected-resource` |
| **Tools list** | `tools/list` JSON-RPC method after auth |

## Connecting MCP Servers to GenAI Playground

Once deployed, MCP servers are accessible via the MCP Gateway endpoint and can be consumed in RHOAI's GenAI Studio (Agent Playground). The LlamaStack distribution in RHOAI 3.4 picks up tool registrations automatically when connected to the gateway.

```bash
# Get the MCP gateway external hostname
oc get gateway mcp-gateway -n gateway-system \
  -o jsonpath='{.status.addresses[0].value}'

# Test the OAuth discovery endpoint
curl https://mcp.apps.<cluster>/.well-known/oauth-protected-resource | jq .

# Test tools/list (requires valid Bearer token)
curl -X POST https://mcp.apps.<cluster>/mcp \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## Troubleshooting

### MCP Catalog Not Visible in Dashboard

1. Verify the `mcpCatalog` flag is enabled:
   ```bash
   oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
     -o jsonpath='{.spec.dashboardConfig.mcpCatalog}'
   ```

2. Verify the MCP Lifecycle Operator is running:
   ```bash
   oc get pods -n mcp-lifecycle-operator-system
   ```

3. Verify the `MCPServer` CRD exists:
   ```bash
   oc get crd mcpservers.mcp.x-k8s.io
   ```

### MCP Server Pod Not Starting

Check that the namespace has the required ServiceAccount and ConfigMap:
```bash
oc get sa mcp-viewer -n <namespace>
oc get configmap openshift-mcp-server-config -n <namespace>
```

## Automation

The toolkit provides automated setup:

```bash
# Via install script (included in full RHOAI 3.4 install)
./scripts/install-rhoai-34.sh

# Via Makefile
make setup-mcp-kubernetes NAMESPACE=<namespace>

# Via MCP server setup script
./scripts/setup-mcp-servers.sh
```

## References

- [MCP Lifecycle Operator (kubernetes-sigs)](https://github.com/kubernetes-sigs/mcp-lifecycle-operator)
- [Kuadrant MCP Gateway (upstream)](https://github.com/Kuadrant/mcp-gateway)
- [Red Hat Connectivity Link 1.4 — MCP Gateway Auth Docs](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.4/html/registering_mcp_servers_and_creating_policies/mcp-gateway-authentication)
- [Red Hat Blog: MCP Catalog in RHOAI 3.4](https://www.redhat.com/en/blog/mcp-catalog-here-discover-deploy-and-connect-red-hat-openshift-ai)
- [Red Hat Blog: MCP Gateway Tech Preview](https://www.redhat.com/en/blog/control-your-ai-agent-traffic-scale-model-context-protocol-gateway-red-hat-openshift-now-technology-preview)
- [Red Hat Developer: Advanced AuthN/AuthZ for MCP Gateway](https://developers.redhat.com/articles/2025/12/12/advanced-authentication-authorization-mcp-gateway)
- [Kuadrant MCP Gateway Docs](https://docs.kuadrant.io/latest/mcp-gateway/docs/guides/how-to-install-and-configure/)
- [Model Context Protocol — Authorization Spec (2025-06-18)](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization)
- [Model Context Protocol Registry](https://modelcontextprotocol.io/registry/about)
- [VS Code MCP Servers Guide](https://code.visualstudio.com/docs/copilot/chat/mcp-servers)
- [MCP Server Setup Guide](MCP-SERVER-SETUP.md)
