# Red_Hat_Connectivity_Link-1.4-Release_notes-en-US.pdf

- Red Hat Connectivity Link 1.4

# Release notes

What's new in Red Hat Connectivity Link 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 Release notes

What's new in Red Hat Connectivity Link

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

This guide provides the latest information on what's new in this release of Red Hat Connectivity Link.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. RED HAT CONNECTIVITY LINK 1 4 RELEASE NOTES 1.1. RED HAT CONNECTIVITY LINK 1.4 RELEASE NOTES 1.2. ABOUT THIS RELEASE 

1.2.1. New features and enhancements 1.2.2. Technology Preview features 1.2.3. Known issues 

1.3. ASYNCHRONOUS RELEASES 1.3.1. Red Hat Connectivity Link 1.4.2 bug fix and security update 

1.3.1.1. Bug fixes 1.3.2. Red Hat Connectivity Link 1.4.1 bug fix and security update 

1.3.2.1. Bug fixes 

3 3 3 3 4 5 5 6 6 6 6 

### CHAPTER 1. RED HAT CONNECTIVITY LINK 1.4 RELEASE NOTES

Welcome to the Red Hat Connectivity Link release notes, where you can learn about what is new and what is fixed. 

IMPORTANT 

Use the latest version: Install or upgrade to Red Hat Connectivity Link 1.4.1 or later. 

Deprecation notice: Red Hat Connectivity Link 1.4.0 is deprecated. OpenShift Container Platform clusters running Connectivity Link 1.4.0 might experience authentication failures, API key management errors, gateway instability, or gateway pod memory pressure because of integration changes that are not fully compatible on all supported OpenShift Container Platform and OpenShift Service Mesh combinations. 

1.1. RED HAT CONNECTIVITY LINK 1.4 RELEASE NOTES 

Connectivity Link is a modular and flexible solution for application connectivity, policy management, and API management in multicloud and hybrid cloud environments. You can use Connectivity Link to secure, protect, connect, and observe your APIs, applications, and infrastructure. 

Connectivity Link is based on the Kuadrant community project, providing a control plane for you to configure and deploy ingress gateways and policies based on the Kubernetes Gateway API  standard. Connectivity Link supports OpenShift Service Mesh 3.4  as the Gateway API provider, which is based on the Istio community project. 

1.2. ABOUT THIS RELEASE 

Red Hat Connectivity Link 1.4 is now available. This release includes the MCP gateway 0.7.0 as a Technology Preview feature. New features, changes, and known issues that pertain to Connectivity Link 1.4 are included in this topic. 

Starting with Connectivity Link 1.4, full support ends with the release of the next minor version. Maintenance support ends with the minor version after that. See the Red Hat Connectivity Link Life Cycle Policy for details about version support and OpenShift Container Platform compatibility. 

Important lifecycle update for Connectivity Link 1.3 

With this release, the maintenance support lifecycle for Connectivity Link 1.3 is updated. Maintenance Support for version 1.3 ends with the release of Connectivity Link 1.5. The maintenance lifecycle of 1.3 was announced before as ending with Connectivity Link 1.6. 

1.2.1. New features and enhancements 

You can use the new features and enhancements that are available with Red Hat Connectivity Link 1.4. 

X.509 cryptographic identity verification now available 

With this Connectivity Link release, you can use X.509 client certificate authentication with for strong cryptographic identity verification. The X.509 format creates a two-layer authentication process that requires both cryptographic proof and context-aware validation before a request authenticates. 

For more information, see Using X.509 cryptographic identity verification . 

MCP gateway: MCP prompt federation is now available 

**MCP gateway adds support for federating MCP prompts through the Gateway object as a Generally **Available feature. MCP prompt federation makes it much easier to supply your large language models (LLMs) with the exact context and steering instructions they need, no matter which server originally hosted the template. With this update, you can now access and run prompt templates from your upstream MCP servers **through a single, central Gateway connection. Instead of managing separate connections to multiple backend servers, you can query the Gateway object to see a unified, prefixed list of every available **prompt across your network. When you find the prompt template that you need, you can plug in your **custom variables. The Gateway object automatically routes the request to the right place. **

For more information, see Registering on-prem MCP servers . 

MCP gateway: Vault documentation now included 

Now you can learn how to use HashiCorp Vault (Vault) to retrieve and inject authentication credentials into your MCP server request flow with the MCP gateway. 

For more information see Using credentials to access external APIs with Vault . 

MCP gateway audit trail documentation is now available 

The MCP gateway documentation now includes configuration instructions for creating an audit trail for compliance and accountability that captures caller identity, tool names, and MCP session context through the MCP gateway. 

For more information, see Understanding an MCP gateway audit trail . 

Notable technical changes 

**Connectivity Link: The gateway integration has been migrated from an Istio WasmPlugin to EnvoyFilter custom resources (CRs). WASM injection now uses EnvoyFilter patches. This enables **native support for image pull secrets and allows for embedded plugin configurations directly within the patches. This is an internal Operator change. No user action is required during an update. Existing CRs might remain in your cluster as orphans. Connectivity Link: To improve performance and scalability, the Kuadrant CR lookup is cached within **the reconciliation state. This internal optimization reduces redundant get requests to the Kubernetes **API server during reconciliation loops. This change reduces control plane utilization and consumption, reduces Operator resource usage, and makes policy reconciliation times faster. 

**MCP gateway: The toolPrefix field on the MCPServerRegistration CR is renamed prefix. This field **has always been a server-level namespace, not tool-specific, and the rename aligns the API with its actual semantics now that it applies to both tools and prompts. 

**Migration: You must replace toolPrefix with prefix in your MCPServerRegistration CRs. Existing CRs must be deleted and recreated, not patched in-place. For bulk updates, you can use a sed oneliner or yq edit on these manifest files before you run the oc apply command. **

1.2.2. Technology Preview features 

You can try the Technology Preview features that are available with Red Hat Connectivity Link 1.4. 

IMPORTANT 

Technology Preview features are not supported with Red Hat production service level agreements (SLAs). These features might not be functionally complete. Red Hat does not recommend using them in production. 

Technology Preview features give you early access to upcoming product features. You can use these features to test new tools early and share your feedback. For more information, see Red Hat Technology Preview Features - Scope of Support . 

**Support for GRPCRoute policy attachment **

**With this Connectivity Link release, GRPCRoute policy attachment support is available as a Technology Preview feature. You can attach AuthPolicy and RateLimitPolicy custom resources (CRs) to GRPCRoute CRs, enabling authentication and rate-limiting controls for gRPC services with native service and method matching. **

For more information, see About GRPCRoute policy attachment support . 

Disconnected installation documentation added 

The Connectivity Link documentation now includes procedures for installing in a disconnected environment. You can apply cloud-like traffic management within your private, secure network. 

For more information, see Installing Connectivity Link in a disconnected environment . 

Connectivity Link OpenShift Container Platform web console plugin adds API management 

With this Connectivity Link release, you can use the OpenShift Container Platform web console to manage your APIs and access to them with the OpenShift web console. You can manage an API catalog and role-based access. You can also see the relationships between your API products and attached resources, such as policies and routes, in a dynamic graph view. 

For more information, see Create, share, and consume APIs across teams. 

1.2.3. Known issues 

Connectivity Link 1.4 has a known issue. 

**When either the Redis or RedisCached storage option is set in a Limitador CR and the limitador pod gets restarted for any reason, the first request to the gateway is never ratelimited. All http requests after this are rate-limited. ( **CONNLINK-856) 

1.3. ASYNCHRONOUS RELEASES 

Security, bug fix, and enhancement updates for Red Hat Connectivity Link 1.4 are released asynchronously through the Red Hat Network. All Red Hat Connectivity Link 1.4 updates are available on the Red Hat Customer Portal. For more information about asynchronous updates, read the Red Hat Connectivity Link Life Cycle Policy. 

Red Hat Customer Portal users can enable update notifications in the account settings for Red Hat Subscription Management (RHSM). When notifications are enabled, you are notified through email whenever new updates relevant to your registered systems are released. 

This section is updated over time to provide notes on enhancements and bug fixes for future asynchronous releases of Red Hat Connectivity Link 1.4. Versioned asynchronous releases, for example with the Red Hat Connectivity Link 1.4.z, are detailed in the following subsections. 

1.3.1. Red Hat Connectivity Link 1.4.2 bug fix and security update 

Issued: 23 July 2026 

Red Hat Connectivity Link release 1.4.2 is now available. A description is available in the RHBA-**2026:44389 advisory. Red Hat Connectivity Link uses the stable update channel to track and receive **updates for the Red Hat Connectivity Link Operator. You can manage how your updates are applied through your Operator Lifecycle Manager (OLM) subscription resource. For more information, see Update Red Hat Connectivity Link . 

1.3.1.1. Bug fixes 

Previously, API requests larger than 1MB could experience intermittent data corruption when Connectivity Link policies were used alongside additional Envoy filters that process the request body. This was because of the way Envoy handled paused streams while the **allow_on_headers_stop_iteration flag was enabled. Depending on timing, if an early-chain **WebAssembly (WASM) filter paused the stream, the initial 16KB chunk of the request body failed to reach later filters. As a result, broken payloads reached those downstream filters 40-80 percent of the time. This release removes the unnecessary flag, ensuring that Envoy correctly preserves and flushes the entire request buffer. Payload corruption on large API requests no longer occurs. (CONNLINK-1311) 

1.3.2. Red Hat Connectivity Link 1.4.1 bug fix and security update 

Issued: 1 July 2026 

Red Hat Connectivity Link release 1.4.1 is now available. A description is available in the RHBA-**2026:34242 advisory. Red Hat Connectivity Link uses the stable update channel to track and receive **updates for the Red Hat Connectivity Link Operator. You can manage how your updates are applied through your Operator Lifecycle Manager (OLM) subscription resource. For more information, see Update Red Hat Connectivity Link . 

1.3.2.1. Bug fixes 

During upgrades, the Operator Lifecycle Manager (OLM) automatically validates your existing **AuthConfig custom resources (CRs) against all active versions of the Custom Resource Definition (CRD) served on the cluster. However, the v1beta2 version of the CRD lacks a **schema validation patch for Common Expression Language (CEL) predicate fields. Before this **release, the Kubernetes API server evaluated the newer v1beta3 resources containing CEL predicates against the stricter v1beta2 schema. Because of this, if you had AuthConfig **resources configured with CEL predicate conditions, OLM blocked your upgrades. The upgrade process failed because the API server rejected the CEL predicate field as an invalid option under **the v1beta2 rules. With this release, the v1beta3 version of the AuthConfig API is the standard for the served CRD versions and the v1beta2 version of the CRD is deprecated and removed. Existing AuthConfig resources that have CEL predicate conditions do not trigger schema **validation failures. You can now upgrade without OLM blocking the process. (CONNLINK-1131) 