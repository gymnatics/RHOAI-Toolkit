# RHOAI MCP Catalog — Q&A

**RHOAI 3.4** | Last updated: June 2026 | Status: Developer Preview (Catalog + Lifecycle Operator), Tech Preview (Gateway)

Answers compiled from Red Hat official release notes, Red Hat engineering blogs (May–June 2026), the kubernetes-sigs/mcp-lifecycle-operator GitHub repo, the Kuadrant/mcp-gateway repo, and the MCP Registry v0.1 spec.

---

## 1. MCP Registry / Catalogue

**Is the MCP catalogue shown in the demo an actual MCP registry, or is it an OpenShift-specific catalogue experience?**

It is an OpenShift-specific catalogue experience, not a standards-based MCP registry. Concretely, it is a curated UI inside the RHOAI dashboard (AI Hub → MCP Servers) that lists validated MCP server container images — including metadata like version, transport type, provider, tools list, and README — and allows platform engineers to deploy them directly onto the cluster. When you click Deploy, the MCP Lifecycle Operator creates the pod, service, and config on your cluster. The catalogue does not expose the MCP Registry v0.1 REST API (`GET /v0.1/servers`), so it is not something VS Code or GitHub Copilot can point to as a registry source.

Your draft answer is correct in spirit: the catalogue does hold metadata about validated server images and points to the container registry where those images are stored.

---

**Does it expose a standards-based MCP registry endpoint that clients such as VS Code or GitHub Copilot can consume directly?**

No, the catalogue does not. However, the MCP Gateway (a separate Tech Preview component) does expose a runtime connection endpoint. Once an MCP server is deployed through the catalogue and routed through the Gateway, VS Code and GitHub Copilot can connect to it by specifying the Gateway URL. The Gateway implements RFC 9728 (OAuth 2.0 Protected Resource Metadata), so a compliant client like Copilot can auto-discover the server URL, transport type, auth method, and required scopes from a single `.well-known` endpoint. This is runtime connection, not registry discovery — VS Code still needs to be told the Gateway URL manually; it cannot browse or search for servers through a catalogue.

---

**Does the catalogue support approval workflows, ownership metadata, lifecycle state, versioning, tags, and environment separation?**

Only partially today. Versioning is basic — servers are pinned by OCI image tag, and the catalogue shows the version self-reported by the server after deployment. Lifecycle state is surfaced in the Deployments tab (Available, Pending, Failed). Metadata cards show provider, transport type, tools list, and README. What is currently missing: approval workflows before deployment, team or org ownership fields, standardised tagging or filtering beyond tier (Red Hat / Partner / Community), and any concept of environment separation (e.g., non-prod vs prod). These are reasonable roadmap items given the Developer Preview status, but none are confirmed on a public roadmap.

---

**Can it represent both remotely hosted MCP servers and locally deployed / stdio-style MCP servers?**

The primary deployment model is cluster-hosted. The catalogue deploys MCP servers as pods on your OpenShift cluster — that is the intended and supported path. There is one edge case: the Microsoft Azure MCP server appears in the catalogue as a remote server entry, but the Deploy button is disabled for it. It is listed for reference only. For stdio-style servers — which are common in the open-source ecosystem (GitHub, Slack, filesystem) — the MCP Lifecycle Operator does not support stdio transport directly. A stdio server must first be wrapped in a container with an HTTP proxy adapter (such as `supergateway` or `mcp-proxy`) that exposes it as streamable HTTP before it can be deployed through the catalogue.

Your draft answer ("Only represent MCP servers hosted within the cluster") is broadly correct. The stdio wrapping requirement is the one practical addition worth noting.

---

**How does it compare functionally with using Azure API Center as the MCP registry?**

They serve different layers and are complementary, not competing. Azure API Center is a governance and discovery registry: it implements the MCP Registry v0.1 spec, exposes a `GET /v0.1/servers` endpoint that GitHub Copilot and VS Code can point to, stores rich metadata including lifecycle state, ownership, auth scopes, and custom properties, and supports approval workflows. It went GA in June 2026. What it does not do is deploy or manage the runtime lifecycle of MCP servers.

The RHOAI MCP Catalogue does the opposite: it handles deployment, lifecycle management, health checks, RBAC, and runtime connectivity through the MCP Gateway — but it does not expose any discovery endpoint that external tools can query. The practical architecture for an enterprise environment that needs both is: Azure API Center as the registry that VS Code and Copilot browse, and RHOAI as the deployment and runtime governance layer that actually runs the servers on your cluster.

---

## 2. VS Code / GitHub Copilot Client Registration

**Can GitHub Copilot in VS Code discover MCP servers directly from the Red Hat MCP catalogue?**

No. The catalogue does not implement the MCP Registry v0.1 spec, so there is no URL you can give Copilot that will let it browse and discover servers. Copilot's enterprise registry integration works by pointing it at a v0.1-compliant endpoint (like Azure API Center) and letting it fetch the server list from there.

What you can do today is connect Copilot to a specific deployed MCP server via the MCP Gateway. Once a server is running and routed through the Gateway, you add the Gateway URL to VS Code's `mcp.json` configuration and Copilot handles the OAuth flow automatically. This is a manual, per-server configuration — not auto-discovery from a catalogue.

---

**Does the catalogue provide enough information for VS Code registration, such as server URL, transport type, auth method, scopes, and user-facing description?**

The catalogue metadata (version, transport type, tools, description) is sufficient for a human to understand what a server does, but it is not in a VS Code-consumable format. The MCP Gateway fills this gap at runtime. When a server is deployed and accessible through the Gateway, the Gateway's `.well-known/oauth-protected-resource` endpoint returns the server URL, transport (streamable HTTP), auth method, identity provider, and supported scopes — everything VS Code needs to establish a connection without out-of-band configuration. The only manual step is providing VS Code with the Gateway's base URL.

---

## 3. Deploying Custom MCP Servers on OpenShift

**Can we bring our own MCP server images, such as our Jira, Confluence, and Bitbucket images?**

Yes. The MCP Lifecycle Operator's `MCPServer` custom resource accepts any OCI container image reference. You point `spec.source.containerImage.ref` at your image in any accessible registry and the operator handles the rest — creating the deployment, service, health probes, and RBAC. One important check: your images need to speak streamable HTTP (or SSE), not stdio. If your current MCP servers launch as a stdio process, they need to be wrapped with an HTTP adapter container first. Custom images deployed this way will appear in the Deployments tab of the catalogue UI with their status and cluster-internal URL, but will not appear as browsable entries in the catalogue's card view — that is currently limited to Red Hat-curated servers.

Your draft answer is correct.

---

**Can we provide our own Helm charts into the catalogue to deploy our MCP servers?**

Yes, at the OpenShift platform level. OpenShift natively supports Helm via the Helm Operator and OpenShift Helm Repository, and since the `MCPServer` resource is a standard Kubernetes YAML, your Helm charts can template and deploy it just like any other resource. The Red Hat Developer Hub community also has a template (`rhdh-mcp-template`) that scaffolds MCP servers with full Tekton CI and ArgoCD CD on OpenShift.

The one distinction to be aware of: the MCP Catalogue's click-Deploy button is image-based only — it creates an MCPServer CR pointing at a container image. Helm is an alternative deployment path that achieves the same result on the cluster, not something the catalogue UI orchestrates directly.

Your draft answer is correct in the context of the OpenShift platform, which is what the question is asking about.

---

**Can the deploy flow support enterprise controls such as Vault integration, egress proxying, certificate management, image scanning, and approval gates?**

Most of these are available through OpenShift platform primitives rather than catalogue-native features. Vault integration works via the external-secrets operator or Vault CSI driver, injecting secrets into the MCPServer as volume mounts or environment variables. Certificate management is handled by OpenShift's service-ca or cert-manager. Egress proxying is handled through OpenShift network policies and the MCP Gateway. For image scanning, the pre-loaded catalogue images are scanned by Red Hat (UBI-based, vulnerability-checked) — but images you bring yourself are not auto-scanned by the catalogue; that needs to be wired into your own pipeline (e.g., via Red Hat Advanced Cluster Security).

Approval gates before deployment are not currently supported in the catalogue or operator. This is a confirmed roadmap intent (the MCP Gateway blog mentions "mandatory approvals for sensitive tool calls") but it is not yet available in the Developer Preview.

---

**Does the deployment model support multiple environments and clusters, for example non-prod and prod?**

Not natively in the catalogue. There is no built-in environment promotion or cross-cluster concept in the MCP Catalogue today. In practice, the recommended approach is GitOps: store your MCPServer YAMLs in Git, use ArgoCD ApplicationSets or separate ArgoCD Applications targeting different clusters, and use Kustomize overlays or Helm values files for environment-specific configuration. The MCP Lifecycle Operator needs to be installed on each cluster independently.

---

**Can deployment be integrated with GitOps or existing CI/CD pipelines, rather than only click-driven deployment?**

Yes, fully. The `MCPServer` resource is a standard Kubernetes CRD, so any tool that can apply Kubernetes manifests — ArgoCD, Tekton, GitHub Actions, Flux — can manage it. The catalogue's click-Deploy is a convenience for the curated servers; it is not the only deployment path. Red Hat Developer Hub's `rhdh-mcp-template` demonstrates the full GitOps pattern: Tekton builds and pushes the image, ArgoCD syncs the MCPServer CR to the cluster, and a Backstage catalog entry is created for developer discoverability.

---

**How does OpenShift track the relationship between a catalogue entry, the deployed MCP server instance, and the consuming agent/client?**

The catalogue UI provides a Deployments tab that shows all MCPServer resources across the cluster — their status (Available, Pending, Failed), their cluster-internal URL, and a link back to the catalogue entry they came from. This covers the catalogue-to-instance relationship and is working today.

The instance-to-agent relationship requires the MCP Gateway (Tech Preview). The Gateway provides identity-aware routing and per-tool call metrics, recording which agent or client called which tool on which server. MLflow integration is planned to extend this into end-to-end agent traceability across LLM calls and tool executions. This layer is in Tech Preview and not yet complete.

---

## 4. Intended Positioning

Red Hat positions the RHOAI MCP Catalogue as the deployment and runtime governance layer, explicitly not as an alternative to an external MCP registry. Their blog states: "Most MCP catalogues available today — including Smithery, Docker MCP Catalog, and the official MCP registry — focus solely on discovery. They help you find servers, but deployment, security, and lifecycle management are your responsibility. The MCP catalogue in OpenShift AI closes that gap."

The intended architecture is layered: an external registry such as Azure API Center for cross-tool discovery that VS Code and GitHub Copilot can browse, the RHOAI MCP Catalogue for cluster-native deployment with validated images and lifecycle management, the MCP Gateway for runtime governance including authentication and per-tool access control, and the Gen AI Studio for in-cluster agent consumption. These are complementary roles, not overlapping ones.

On the roadmap for user-contributed catalogue entries: the catalogue currently ships three tiers (Red Hat, Technology Partner, Community). Red Hat says the curation and validation pipeline is "built to scale" and they are "actively adding more" servers. Given the Developer Preview status and the explicit "bring your own" messaging, a partner or ISV submission path for browsable catalogue entries is a logical next step — similar to how OperatorHub works today. This is not confirmed on any public roadmap, but it is a reasonable expectation.

There is no public roadmap deck. For reference architecture detail, the MCP Gateway Tech Preview blog is the most current technical reference. Roadmap conversations should go through your Red Hat account team or the OpenShift AI PM team directly.
