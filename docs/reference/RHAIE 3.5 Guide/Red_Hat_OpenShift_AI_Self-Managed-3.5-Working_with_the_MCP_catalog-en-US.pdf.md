# Red_Hat_OpenShift_AI_Self-Managed-3.5-Working_with_the_MCP_catalog-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Working with the MCP catalog

Work with the MCP catalog in Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-26

### Red Hat OpenShift AI Self-Managed  3.5 Working with the MCP catalog

Work with the MCP catalog in Red Hat OpenShift AI Self-Managed

Legal Notice 

Copyright © Red Hat. 

Except as otherwise noted below, the text of and illustrations in this documentation are licensed by Red Hat under the Creative Commons Attribution–Share Alike 3.0 Unported license . If you distribute this document or an adaptation of it, you must provide the URL for the original version. 

Red Hat, as the licensor of this document, waives the right to enforce, and agrees not to assert, Section 4d of CC-BY-SA to the fullest extent permitted by applicable law. 

Red Hat, the Red Hat logo, JBoss, Hibernate, and RHCE are trademarks or registered trademarks of Red Hat, LLC. or its subsidiaries in the United States and other countries. 

Linux ® is the registered trademark of Linus Torvalds in the United States and other countries. 

XFS is a trademark or registered trademark of Hewlett Packard Enterprise Development LP or its subsidiaries in the United States and other countries. 

The OpenStack ® Word Mark and OpenStack logo are trademarks or registered trademarks of the Linux Foundation, used under license. 

All other trademarks are the property of their respective owners. 

Abstract 

Enable the AI Hub MCP Catalog and use it to deploy and manage Model Context Protocol (MCP) servers on your Red Hat OpenShift AI Self-Managed cluster.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

PREFACE 

CHAPTER 1. SET UP THE MCP GATEWAY OPERATOR AS A PREREQUISITE FOR MCP MANAGEMENT 1.1. MCP GATEWAY OPERATOR OVERVIEW 

1.1.1. OpenShift AI components that require the MCP gateway 1.1.2. Gateways comparison 1.1.3. Lifecycle responsibility 

1.2. INSTALL THE MCP GATEWAY OPERATOR 

CHAPTER 2 ENABLE MCP SERVER LIFECYCLE MANAGEMENT 2.1. MCP LIFECYCLE OPERATOR 

2.1.1. Component controller pattern 2.1.2. Relationship to the AI Hub MCP Catalog 2.1.3. Relationship to the MCP Gateway Operator 2.1.4. Distinction from the RHOAI MCP server 

2.2. MCP LIFECYCLE OPERATOR TECHNOLOGY PREVIEW LIMITATIONS 2.3. ENABLE THE MCP LIFECYCLE OPERATOR 2.4. DISABLE THE MCP LIFECYCLE OPERATOR 

CHAPTER 3 DEPLOY AND MANAGE MCP SERVERS 3.1. DEPLOY MCP SERVERS FROM THE MCP CATALOG 3.2. UPGRADE AN MCP SERVER 3.3. SCALE AN MCP SERVER 3.4. REMOVE AN MCP SERVER 3.5. MONITOR MCP SERVER HEALTH 

3 

4 4 4 5 5 5 

7 7 7 8 8 8 8 9 11 

13 13 15 15 17 17 

### PREFACE

As a cluster administrator or developer in Red Hat OpenShift AI, you can enable the AI Hub MCP Catalog and use it to deploy and manage Model Context Protocol (MCP) servers on your cluster. 

### CHAPTER 1. SET UP THE MCP GATEWAY OPERATOR AS A PREREQUISITE FOR MCP MANAGEMENT

Before you can use MCP management workflows in Red Hat OpenShift AI, a cluster administrator must install and configure the MCP gateway Operator as an external dependency. 

IMPORTANT 

MCP gateway Operator is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

1.1. MCP GATEWAY OPERATOR OVERVIEW 

The MCP gateway Operator is an optional external component that provides a governed entry point for Model Context Protocol (MCP) traffic between AI agents and backend tool servers in OpenShift AI agentic workflows. 

Multiple MCP servers can be registered behind a single governance boundary by using **MCPServerRegistration resources, which enables agents to discover and access tools from multiple **servers through a single gateway endpoint. 

A cluster administrator must install and manage this operator independently from the OpenShift AI operator lifecycle. 

IMPORTANT 

MCP gateway Operator integration is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

The MCP gateway Operator is part of Red Hat Connectivity Link (RHCL). OpenShift AI does not autoinstall or manage the MCP gateway Operator. Cluster administrators are responsible for installing, configuring, and upgrading the operator as part of their cluster infrastructure. 

1.1.1. OpenShift AI components that require the MCP gateway 

The following OpenShift AI components interact with the MCP gateway and require the operator to be installed: 

**NeMo Guardrails MCP gateway integration: When you configure the NemoGuardrails custom resource with an mcpGateway field, the TrustyAI operator discovers the gateway by **

**searching for MCPGatewayExtension resources and auto-provisions an mcp-sse-strip **EnvoyFilter for server-sent events (SSE) to JSON conversion. 

Agentic Starter Kits with MCP gateway routing: Agentic Starter Kits that are configured to route agent MCP traffic through the gateway rather than using ConfigMap-based MCP server configuration. 

1.1.2. Gateways comparison 

The MCP gateway is a distinct component from the OpenShift AI-managed model inference gateways. Use the following table to identify which gateway serves each traffic type. 

Table 1.1. Gateway types in OpenShift AI 

Gateway Purpose CRD or resource 

MCP gateway Routes MCP protocol traffic from AI agents to MCP tool servers and enforces authentication and authorization 

**MCPGatewayExtension, MCPServerRegistration, MCPVirtualServer (apiVersion: mcp.kuadrant.io/v1alpha1) **

data-science-gateway 

Routes HTTP and gRPC inference requests to model serving endpoints 

Gateway API resource, managed by the OpenShift AI operator 

maas-default-gateway 

Routes inference requests through the Models as a Service component 

Gateway API resource, managed by the OpenShift AI operator 

1.1.3. Lifecycle responsibility 

Your lifecycle responsibilities include: 

Installing the MCP gateway Operator from the OpenShift software catalog. 

Configuring authentication policies and Kubernetes Secrets required by the integration. 

Upgrading the MCP gateway Operator independently from the OpenShift AI upgrade cycle. 

Additional resources 

Install the MCP gateway Operator 

Connectivity for agentic AI applications with the Model Context Protocol gateway 

1.2. INSTALL THE MCP GATEWAY OPERATOR 

The MCP gateway Operator is available in the OpenShift software catalog. When you install the MCP gateway Operator, the required Red Hat Connectivity Link (RHCL) version is installed automatically as a dependency. OpenShift AI does not autoinstall this operator, and you must complete this installation independently from the OpenShift AI operator lifecycle. 

IMPORTANT 

MCP gateway Operator installation is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Prerequisites 

You have cluster administrator access to your OpenShift cluster. 

Your cluster is running OpenShift 4.19 to 4.22. 

**You installed OpenShift CLI (oc). **

You have OpenShift AI 3.5 installed on your cluster. 

Procedure 

Install the MCP gateway Operator from the OpenShift software catalog. The required RHCL version is installed automatically as a dependency. For installation instructions, see Install the MCP gateway . 

Verification 

Verify that the MCP gateway Operator custom resource definitions (CRDs) are registered on your cluster: 

The output lists the following CRDs: 

**Verify that the operator CSV shows the Succeeded phase in the namespace where you **installed it: 

**The output shows the operator CSV with a Succeeded phase. **

Additional resources 

MCP gateway Operator overview 

Install the MCP gateway 

Connectivity for agentic AI applications with the Model Context Protocol gateway 

$ oc get crd | grep mcp.kuadrant.io 

mcpgatewayextensions.mcp.kuadrant.io    <timestamp> mcpserverregistrations.mcp.kuadrant.io  <timestamp> 

$ oc get csv -A | grep mcp-gateway 

### CHAPTER 2. ENABLE MCP SERVER LIFECYCLE MANAGEMENT

As a cluster administrator, you can enable the MCP Lifecycle Operator to make MCP server deployment **available to your team. After you enable the operator and the mcpCatalog dashboard feature flag, **developers can deploy and manage MCP servers directly from the AI Hub MCP Catalog. 

IMPORTANT 

MCP Lifecycle Operator is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

2.1. MCP LIFECYCLE OPERATOR 

IMPORTANT 

MCP Lifecycle Operator is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

The MCP Lifecycle Operator is a component in Red Hat OpenShift AI that manages the deployment and lifecycle of Model Context Protocol (MCP) servers. When enabled, it provides the runtime backend so that developers can deploy MCP servers directly from the AI Hub MCP Catalog without writing Kubernetes manifests or sourcing container images manually. 

The MCP Lifecycle Operator is the cluster-level controller managed by the Red Hat OpenShift AI **Operator through the DataScienceCluster custom resource. It watches for MCPServer custom **resources and coordinates the overall deployment lifecycle by automatically provisioning the required Deployments, Services, NetworkPolicies, and cluster-internal URLs for service discovery. 

2.1.1. Component controller pattern 

The MCP Lifecycle Operator follows the same component controller pattern as other optional Red Hat **OpenShift AI components such as MLflowOperator, FeastOperator, and Open GenAI Stack (OGX). You manage the operator by setting the managementState field in the DataScienceCluster custom **resource. 

**The mcplifecycleoperator component defaults to Removed in the DataScienceCluster for Red Hat OpenShift AI 3.5. You must explicitly set managementState to Managed to enable MCP server **deployment on your cluster. 

2.1.2. Relationship to the AI Hub MCP Catalog 

The AI Hub MCP Catalog provides the discovery and deployment interface for MCP servers. The catalog UI is a federated plugin in the Red Hat OpenShift AI dashboard and is pre-loaded with MCP servers from Red Hat, technology partners, and the open source community. 

The MCP Lifecycle Operator provides the deployment runtime backend for the catalog. Without the operator enabled, the deploy action in the catalog UI is unavailable. After you enable the operator, developers in your team can browse the catalog and deploy MCP servers to their namespaces without additional configuration. 

**A separate model-metadata-collection data container provides the catalog metadata for MCP server **discovery. 

2.1.3. Relationship to the MCP Gateway Operator 

The MCP Gateway Operator is a separate component that provides routing and security for MCP servers at the gateway layer. It is not part of the Red Hat OpenShift AI Operator distribution and is not automatically installed when you enable the MCP Lifecycle Operator. 

If your MCP server deployment scenarios require centralized routing or access control through the MCP Gateway, install the MCP Gateway Operator separately before enabling MCP server deployments. 

NOTE 

Not all MCP server deployment scenarios require the MCP Gateway Operator. 

2.1.4. Distinction from the RHOAI MCP server 

The MCP Lifecycle Operator is a Kubernetes operator for running MCP servers as native workloads on OpenShift. It is not itself an MCP server. 

**rhoai-mcp **

An MCP server that enables MCP-compatible AI coding agents, such as Claude Code, to interact with Red Hat OpenShift AI itself. It provides tools for model recommendation, project management, and Kubernetes manifest generation. 

MCP Lifecycle Operator 

A Kubernetes operator that deploys and manages MCP servers as native workloads on OpenShift. 

2.2. MCP LIFECYCLE OPERATOR TECHNOLOGY PREVIEW LIMITATIONS 

IMPORTANT 

MCP Lifecycle Operator is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

The MCP Lifecycle Operator in Red Hat OpenShift AI 3.5 has the following limitations. 

Limitation Details 

No backward compatibility for the Custom Resource Definition (CRD) API 

**The MCPServer custom resource API version is v1alpha1. Red Hat **makes no backwards compatibility commitment for this release. CRD types and fields can change in a future release without a migration path. 

Single-cluster deployment only The operator manages MCP servers within a single Red Hat OpenShift AI cluster. Multi-cluster MCP server management is not validated. 

No governance or policy enforcement 

Rate limiting, access control, and policy enforcement for MCP servers are not included. 

Dashboard UI requires feature flag 

MCP lifecycle features in the Red Hat OpenShift AI dashboard are gated **by the mcpCatalog feature flag in the OdhDashboardConfig **custom resource. A cluster administrator must enable the flag before the MCP Catalog deploy action is available to users. 

MCP Gateway Operator is a separate installation 

The MCP Gateway Operator, which provides centralized routing and access control for MCP servers, is not automatically installed when you enable the MCP Lifecycle Operator. If your deployment requires MCP server routing through the gateway, you must install the MCP Gateway Operator separately. 

Disconnected environment image mirroring 

The MCP Lifecycle Operator image is included in the Red Hat OpenShift **AI operator catalog relatedImages for OLM-based air-gapped **mirroring and requires no extra mirroring steps. However, individual MCP server images available in the catalog might require additional mirroring steps in disconnected environments. Consult each server’s metadata for image references. 

2.3. ENABLE THE MCP LIFECYCLE OPERATOR 

IMPORTANT 

MCP Lifecycle Operator is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Enable the MCP Lifecycle Operator so that developers on your team can deploy MCP servers from the AI Hub MCP Catalog. When enabled, the operator manages the full lifecycle of MCP server deployments in your cluster. 

Prerequisites 

Red Hat OpenShift AI 3.5 is installed on an OpenShift 4.22 or later cluster. 

You have cluster administrator privileges. 

**You have installed the OpenShift CLI (oc). **

Procedure 

**1. Identify the name of your DataScienceCluster object: **

**2. Enable the MCP Lifecycle Operator by patching the DataScienceCluster object: **

**Replace default-dsc with the name of your DataScienceCluster object if different. **

NOTE 

You can also enable the MCP Lifecycle Operator by using the OpenShift web console. For more information, see Installing and uninstalling OpenShift AI . 

**3. Enable the MCP lifecycle feature in the dashboard by patching the OdhDashboardConfig **custom resource: 

Verification 

Confirm that the MCP Lifecycle Operator pod is running: 

**The output shows at least one pod in Running status, for example: **

**Confirm that the mcplifecycleoperator component is reported as Managed in the DataScienceCluster object: **

**The expected output is true. **

Next steps 

Deploy MCP servers from the MCP Catalog 

$ oc get datasciencecluster 

$ oc patch datasciencecluster default-dsc --type=merge \   -p '{"spec":{"components":{"mcplifecycleoperator":{"managementState":"Managed"}}}}' 

$ oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \   --type=merge -p '{"spec":{"dashboardConfig":{"mcpCatalog":true}}}' 

$ oc get pods -n redhat-ods-applications -l app.kubernetes.io/name=mcp-lifecycle-operator 

NAME                                    READY   STATUS    RESTARTS   AGE mcp-lifecycle-operator-<id>            1/1     Running   0          2m 

$ oc get datasciencecluster default-dsc \   -o jsonpath='{.status.installedComponents.mcplifecycleoperator}' 

MCP Lifecycle Operator Technology Preview limitations 

2.4. DISABLE THE MCP LIFECYCLE OPERATOR 

IMPORTANT 

MCP Lifecycle Operator is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Disable the MCP Lifecycle Operator when you no longer need MCP server lifecycle management on your cluster, or when you need to reclaim resources. 

IMPORTANT 

Disabling the MCP Lifecycle Operator removes the operator and all resources it **manages. MCP servers and their associated MCPServer custom resources might be cleaned up automatically. To confirm cleanup, verify that no MCPServer resources **remain in user namespaces after disabling the operator. Developers can no longer deploy MCP servers from the AI Hub MCP Catalog until you re-enable the operator. The Deploy button in the MCP server details page is also disabled. 

Prerequisites 

You have cluster administrator privileges. 

**You have installed the OpenShift CLI (oc). **

The MCP Lifecycle Operator is currently enabled. 

Procedure 

**1. Disable the MCP Lifecycle Operator by patching the DataScienceCluster object: **

**Replace default-dsc with the name of your DataScienceCluster object if different. **

2. Optional: Disable the MCP lifecycle dashboard feature flag to hide the MCP catalog UI from developers: 

Verification 

Confirm that no MCP Lifecycle Operator pods are running: 

$ oc patch datasciencecluster default-dsc --type=merge \   -p '{"spec":{"components":{"mcplifecycleoperator":{"managementState":"Removed"}}}}' 

$ oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \   --type=merge -p '{"spec":{"dashboardConfig":{"mcpCatalog":false}}}' 

The command returns no output when the operator has been successfully removed. 

**Confirm that the mcplifecycleoperator component is reported as Removed in the DataScienceCluster object: **

**The expected output is false. If the field is missing from the output, the component is not **installed. 

**Confirm that no MCPServer resources remain in user namespaces: **

**The expected output is No resources found or an empty list. **

$ oc get pods -n redhat-ods-applications -l app.kubernetes.io/name=mcp-lifecycle-operator 

$ oc get datasciencecluster default-dsc \   -o jsonpath='{.status.installedComponents.mcplifecycleoperator}' 

$ oc get mcpservers --all-namespaces 

### CHAPTER 3. DEPLOY AND MANAGE MCP SERVERS

After a cluster administrator enables the MCP Lifecycle Operator, you can deploy MCP servers from the AI Hub MCP Catalog and manage their lifecycle. MCP servers expose tools and capabilities that your AI agents and applications can use through the Model Context Protocol. 

IMPORTANT 

MCP Catalog is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

NOTE 

Deploying MCP servers from the MCP Catalog requires a cluster administrator to enable the MCP Lifecycle Operator. 

3.1. DEPLOY MCP SERVERS FROM THE MCP CATALOG 

IMPORTANT 

MCP Lifecycle Operator is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Deploy an MCP server from the AI Hub MCP Catalog to make it available for use in AI applications and agents in your namespace. The MCP Catalog provides pre-curated MCP servers from Red Hat, technology partners, and the open source community that you can deploy without sourcing container images or writing Kubernetes manifests. 

Prerequisites 

A cluster administrator has enabled the MCP Lifecycle Operator on the cluster. For more information, see Enable the MCP Lifecycle Operator . 

You have access to a Red Hat OpenShift AI project with at least the standard user role. 

You have access to the Red Hat OpenShift AI dashboard. 

**If the MCP server you are deploying requires a service account, a ServiceAccount resource **exists in your namespace. 

Procedure 

1. In the Red Hat OpenShift AI dashboard, navigate to AI hub → MCP servers. 

2. Browse available MCP servers. Each server card displays the server name, a description, supported tools, and the support tier. The support tiers are: 

Support tier Description 

Red Hat Fully supported by Red Hat. 

Partner Supported by the technology partner who maintains the server. 

Community Best-effort support from the open source community. 

3. Filter the catalog by deployment mode or supported transport protocols to find the server that meets your requirements. 

4. Click the MCP server you want to deploy to open its details page. Review the server metadata, including the list of tools it exposes, supported capabilities, and whether the server requires a service account. 

5. Click Deploy MCP server. 

NOTE 

The Deploy MCP server button is disabled if the MCP Lifecycle Operator is not enabled on the cluster. For more information, see Enable the MCP Lifecycle Operator. 

6. In the deployment dialog, review the YAML configuration field. **If the MCP server requires a service account, set the serviceAccountName: field under runtime: and security: in the YAML: **

where: 

**<service_account_name> **

**Specifies the name of the ServiceAccount resource in your namespace. **

7. Confirm the deployment by clicking Deploy in the dialog. The MCP Catalog submits the deployment request to the MCP Lifecycle Operator. The **operator creates an MCPServer custom resource in your namespace and provisions the **required Deployment and Service. 

Verification 

**1. Confirm that the MCPServer custom resource shows a READY status of True: **

spec:   runtime:     security:       serviceAccountName: <service_account_name> 

**Replace <namespace> with your project namespace. **

**The output shows the MCP server with READY status as True, for example: **

2. In the Red Hat OpenShift AI dashboard, navigate to AI hub → MCP servers and verify that the MCP server is displayed on the Deployments tab. 

Next steps 

Upgrade an MCP server 

Scale an MCP server 

Remove an MCP server 

Monitor MCP server health 

3.2. UPGRADE AN MCP SERVER 

Upgrade a deployed MCP server to a newer version by using the Red Hat OpenShift AI dashboard or by **editing the MCPServer custom resource directly. **

Prerequisites 

The MCP Lifecycle Operator is enabled on the cluster. 

You have an MCP server deployed in your namespace. 

**You have access to the Red Hat OpenShift AI dashboard or the OpenShift CLI (oc). **

Procedure 

1. In the Red Hat OpenShift AI dashboard, navigate to AI hub → MCP servers and open the Deployments tab. 

2. Locate the deployed server and click its name. 

3. Click Edit to open the server configuration. Select the new version and save the changes. 

Verification 

**Confirm the MCPServer status is Ready: **

**The output shows READY as True when the server is running. **

3.3. SCALE AN MCP SERVER 

$ oc get mcpservers -n <namespace> 

NAME                 READY   ACCEPTED   IMAGE   PORT   ADDRESS   AGE <mcp_server_name>   True    True       ...     ...    ...       2m 

$ oc get mcpservers <mcp_server_name> -n <namespace> 

**Scale the number of replicas for a deployed MCP server by patching the spec.runtime.replicas field in its MCPServer custom resource. **

Prerequisites 

The MCP Lifecycle Operator is enabled on the cluster. 

You have an MCP server deployed in your namespace. 

**You have access to the Red Hat OpenShift AI dashboard or the OpenShift CLI (oc). **

Procedure 

**1. Edit the MCPServer custom resource to update the replica count: **

where: 

**<mcp_server_name> **

**Specifies the name of the MCPServer custom resource. **

**<namespace> **

Specifies the namespace where the MCP server is deployed. 

**<replica_count> **

**Specifies the number of replicas to run. Set to 0 to scale to zero. You can run oc explain mcpserver.spec.runtime to view all available runtime configuration **fields for the installed CRD version. 

IMPORTANT 

By default, the MCP Lifecycle Operator treats MCP servers as stateful and **configures SessionAffinity: ClientIP on the Kubernetes Service. This pins **each client to a single pod, which means scaling to additional replicas does not distribute existing client connections across those replicas. 

If the MCP server you are scaling is stateless, which means it does not **maintain per-client session data, set spec.mcp.stateless: true in the MCPServer custom resource so that the operator configures SessionAffinity: None and load-balances traffic across all replicas: **

**Only set stateless: true if the MCP server itself declares that it is stateless. **

The MCP Lifecycle Operator runs MCP servers as Kubernetes-native workloads on OpenShift but does not manage session state within those servers. If the server maintains session state, managing that state across replicas is the server’s own responsibility. 

$ oc patch mcpserver <mcp_server_name> -n <namespace> \   --type=merge -p '{"spec":{"runtime":{"replicas":<replica_count>}}}' 

$ oc patch mcpserver <mcp_server_name> -n <namespace> \   --type=merge -p '{"spec":{"mcp":{"stateless":true},"runtime":{"replicas": <replica_count>}}}' 

Verification 

**Confirm the configured replica count on the MCPServer custom resource: **

The output shows the replica count you set. 

**Confirm the MCPServer status is Ready: **

**The output shows READY as True when the server is running with the updated replica count. **

3.4. REMOVE AN MCP SERVER 

Remove a deployed MCP server from your namespace by using the Red Hat OpenShift AI dashboard or **by deleting the MCPServer custom resource directly. **

Prerequisites 

The MCP Lifecycle Operator is enabled on the cluster. 

You have an MCP server deployed in your namespace. 

**You have access to the Red Hat OpenShift AI dashboard or the OpenShift CLI (oc). **

Procedure 

1. In the Red Hat OpenShift AI dashboard, navigate to AI hub → MCP servers and open the Deployments tab. 

2. Locate the MCP server and select Delete from the action menu. Confirm the deletion. **Alternatively, delete the MCPServer custom resource directly: **

The MCP Lifecycle Operator automatically cleans up the associated Deployment, Service, and other managed resources. 

Verification 

**Confirm no MCPServer resources remain for the deleted server: **

3.5. MONITOR MCP SERVER HEALTH 

Check the status and health of deployed MCP servers in your namespace by using the OpenShift CLI **(oc). **

$ oc get mcpservers <mcp_server_name> -n <namespace> \   -o jsonpath='{.spec.runtime.replicas}{"\n"}' 

$ oc get mcpservers <mcp_server_name> -n <namespace> 

$ oc delete mcpserver <mcp_server_name> -n <namespace> 

$ oc get mcpservers -n <namespace> 

Prerequisites 

The MCP Lifecycle Operator is enabled on the cluster. 

You have an MCP server deployed in your namespace. 

**You have access to the Red Hat OpenShift AI dashboard or the OpenShift CLI (oc). **

Procedure 

1. Check the status of all MCP servers in your namespace: 

2. Review the status conditions for a specific MCP server: 

**Look for a condition with type: Ready and status: True to confirm the server is running and **ready to accept connections. 

$ oc get mcpservers -n <namespace> 

$ oc describe mcpserver <mcp_server_name> -n <namespace> 