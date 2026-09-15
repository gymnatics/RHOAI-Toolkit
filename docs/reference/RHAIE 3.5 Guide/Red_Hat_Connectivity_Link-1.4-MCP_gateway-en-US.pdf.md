# Red_Hat_Connectivity_Link-1.4-MCP_gateway-en-US.pdf

- Red Hat Connectivity Link 1.4

# MCP gateway

Connectivity for agentic AI applications with the Model Context Protocol gateway 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 MCP gateway

Connectivity for agentic AI applications with the Model Context Protocol gateway

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

Connect and secure your backend MCP servers to your frontend services

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. INTRODUCTION TO THE MCP GATEWAY 1.1. ABOUT THE MCP GATEWAY 1.2. MCP GATEWAY ARCHITECTURE 

1.2.1. MCP gateway architectural components 1.3. ADDITIONAL RESOURCES 

3 3 3 4 5 

### CHAPTER 1. INTRODUCTION TO THE MCP GATEWAY

You can centralize and manage the connectivity for your agentic AI applications that access your Model Context Protocol (MCP) servers by using the MCP gateway. 

IMPORTANT 

MCP gateway is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features offer early access to upcoming product features, enabling customers to test functionality and give feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

1.1. ABOUT THE MCP GATEWAY 

You can focus on your AI agent systems without building networking into your application code by using the Model Context Protocol (MCP) gateway. Application teams and platform engineers can expose MCP servers with the MCP gateway. These MCP servers can be as secure and protected as RESTFul APIs. 

For example, you can achieve the following goals by using the MCP gateway to connect your MCP servers: 

Gather MCP servers behind a single endpoint. 

Grow your agentic AI applications at scale without building in connectivity. 

Manage access to and the security of AI tools and MCP servers. 

The Connectivity Link implementation of the MCP gateway extends the capabilities of the Envoy proxy server. The Envoy proxy server handles traffic from agentic AI clients to your backend MCP servers at the gateway ingress. Envoy is a conformance-tested implementation of the Kubernetes Gateway API. 

1.2. MCP GATEWAY ARCHITECTURE 

The architecture of the Model Context Protocol (MCP) gateway builds on the routing capabilities of the Envoy proxy, adding the capabilities to handle the MCP. Because the MCP gateway using the Envoy proxy, you can use Connectivity Link for policies and avoid complex configuration. 

The design includes the following high-level goals: 

The MCP gateway works with the Gateway API as a routing configuration. 

The Envoy proxy controls routing and traffic as the implementation of the Gateway API. 

The MCP gateway focuses on the MCP Protocol. 

Uses Istio as the gateway control plane in OpenShift Container Platform with the Gateway API. 

**Uses Connectivity Link for policies, such as AuthPolicy and rate-limiting custom resources. **

1.2.1. MCP gateway architectural components 

The Model Content Protocol (MCP) gateway architecture consists of three components that manage connectivity: the router, broker, and controller. 

MCP router 

**The MCP router is an Envoy-focused ext_proc component that is capable of parsing the MCP protocol. When ext_proc parses the MCP Protocol, the router uses the protocol to set headers to **force the correct routing of the request to the correct MCP server. The MCP router component is responsible for the following activities: 

**Parsing and validating the JSON-RPC request object, which is the MCP message body **

**Setting the key request headers, :authority, :path, x-mcp-method, x-mcp-servername, x-mcp-toolname, and mcp-session-id **

**Watching for 404 responses from MCP servers and invalidating the session store **

Handling session initialization and storage on behalf of a requesting MCP client during a tools call request 

MCP broker 

The MCP broker manages the complexity of connecting to multiple AI services simultaneously for you. The broker component aggregates backend MCP servers and presents them as a unified MCP server to clients. This means that your MCP clients or applications do not have to manage a large set of MCP servers and configurations for each server. The MCP broker component is a backend service that acts as a default MCP server backend for the **/mcp endpoint. For example, the broker does the following activities: **

**Handles the handshake, init. **

Discovers tools from connected MCP servers and adds them to a unified list. Validates that discovered MCP servers meet minimum protocol version and capabilities before including their tools in the list. 

Listens for updates and can change its state so that the agentic AI always has the latest information. 

Handles notifications sent through whichever backend MCP server it is connected to, for **example, notifications/tools/list_changed. **

Handles notification requests from clients and MCP servers by proxying from the MCP server notification to registered clients. 

MCP discovery controller 

The MCP discovery controller is a Kubernetes-based controller that watches for changes to custom resources (CRs). The MCP discovery controller uses CRs to configure the MCP gateway and register MCP servers. The CRs are then turned into a configuration that is consumed by the MCP gateway so that it can route and present the tools from the registered MCP server to the client. The MCP discovery controller component is responsible for the following activities: 

**Watching MCPServerRegistration CRs **

**Maintaining a configuration from both HTTPRoute and MCPServerRegistration CRs **

Updating the MCP broker and MCP router config secret based on discovered **MCPServerRegistration CRs and the HTTPRoutes they target **

**Reporting the status of MCPServerRegistrations CRs **

1.3. ADDITIONAL RESOURCES 

About Red Hat Connectivity Link 