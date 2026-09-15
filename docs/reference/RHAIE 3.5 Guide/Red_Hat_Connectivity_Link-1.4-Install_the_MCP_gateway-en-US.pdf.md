# Red_Hat_Connectivity_Link-1.4-Install_the_MCP_gateway-en-US.pdf

- Red Hat Connectivity Link 1.4

# Install the MCP gateway

Installing MCP gateway on single and multiple clusters 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 Install the MCP gateway

Installing MCP gateway on single and multiple clusters

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

To connect your backend MCP servers to your frontend services, install the MCP gateway

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. INSTALL AND CONFIGURE MCP GATEWAY 1.1. INSTALL THE MCP GATEWAY WITH OLM 1.2. CREATE A GATEWAY OBJECT FOR YOUR MCP GATEWAY 1.3. CONFIGURE MCP GATEWAY LISTENERS 1.4. UNDERSTAND THE MCPGATEWAYEXTENSION CUSTOM RESOURCE 1.5. APPLY THE MCPGATEWAYEXTENSION CUSTOM RESOURCE 

1.5.1. The MCPGatewayExtension custom resource API reference 1.5.2. Automatically created HTTPRoute example 

1.6. APPLY A REFERENCEGRANT CUSTOM RESOURCE 1.7. DNS MANAGEMENT WITH THE MCP GATEWAY 1.8. APPLY A CUSTOMIZED HTTPROUTE OBJECT 1.9. VERIFY THAT AN MCP ENDPOINT IS ACCESSIBLE THROUGH YOUR MCP GATEWAY 

3 3 5 6 

10 11 

13 16 17 18 18 

20 

### CHAPTER 1. INSTALL AND CONFIGURE MCP GATEWAY

You can get started with the MCP gateway by using Operator Lifecycle Manager (OLM). After you install the Operator, set up connections by applying the custom resources that you require. 

IMPORTANT 

Use the latest version: Install or upgrade to Red Hat Connectivity Link 1.4.1 or later. 

Deprecation notice: Red Hat Connectivity Link 1.4.0 is deprecated. OpenShift Container Platform clusters running Connectivity Link 1.4.0 might experience authentication failures, API key management errors, gateway instability, or gateway pod memory pressure because of integration changes that are not fully compatible on all supported OpenShift Container Platform and OpenShift Service Mesh combinations. 

IMPORTANT 

MCP gateway is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features offer early access to upcoming product features, enabling customers to test functionality and give feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

1.1. INSTALL THE MCP GATEWAY WITH OLM 

You can install the MCP gateway deployment Operator by using Operator Lifecycle Manager (OLM) **with the CLI. When choosing this path, you must create a MCPGatewayExtension custom resources **(CR) manually and apply it to complete your initial setup. 

Prerequisites 

You installed OpenShift Container Platform. 

**You installed OpenShift CLI (oc). **

Procedure 

1. Create the namespace where you want to install MCP gateway by running the following command: 

***Replace the default <mcp_system> with the namespace you want to use. ***

**2. Create and the MCP gateway Subscription and OperatorGroup custom resources (CRs) by **using the following example: 

*$ oc create ns <mcp_system> *

apiVersion: operators.coreos.com/v1alpha1 kind: Subscription metadata:   name: mcp-gateway 

***Replace <mcp_system> with the namespace you used in the earlier step. ***

3. Apply the resources by running the following command: 

***Replace <mcp_system> with the namespace you used in the earlier step. ***

***Replace <mcp_gateway.yaml> with the name you used for your configuration file. ***

4. Confirm that the MCP gateway installation has finished by running the following commands: 

***Replace <mcp_system> with the namespace you used in the earlier step. ***

***Replace <mcp_system> with the namespace you used in the earlier step. ***

**Expect the status of installplan.operators.coreos.com/install-<suffix> when MCP gateway is ready. The name of the install plan has a random suffix, for example, 4rql7. **

Verification 

Wait for the controller to be ready by running the following command: 

***Replace <mcp_system> with the namespace you used. ***

Next steps 

**Configure a listener for your Gateway object. **

**Create a ReferenceGrant CR if you require cross-namespace referencing. **

spec:   source: redhat-operators   sourceNamespace: openshift-marketplace   name: mcp-gateway   channel: preview ---apiVersion: operators.coreos.com/v1 kind: OperatorGroup metadata:   name: mcp-gateway spec:   targetNamespaces: *  - <mcp_system> *

*$ oc apply -n <mcp_system> -f <mcp_gateway.yaml> *

$ oc wait --for=jsonpath={.status.installPlanRef.name} subscription mcp-gateway -n *<mcp_system> --timeout=10s ip=$(oc get subscription mcp-gateway -n <mcp_system> -o=jsonpath= *{.status.installPlanRef.name}) 

*$ oc wait --for=condition=Installed installplan -n <mcp_system> ${ip} --timeout=60s *

*$ oc wait csv -n <mcp_system> -l operators.coreos.com/mcp-gateway.<mcp_system>="" --*for=jsonpath='{.status.phase}'=Succeeded --timeout=5m 

**Deploy the MCP gateway by creating an MCPGatewayExtension CR. **

Configure authentication and authorization for your connections. 

**Create MCPServerRegistration CRs to register your MCP servers. **

1.2. CREATE A GATEWAY OBJECT FOR YOUR MCP GATEWAY 

**You must make a Gateway object and configure listeners to create pods that handle your traffic, assign **IP addresses, and give HTTP routes a place to connect. 

TIP 

**You can attach your Red Hat Connectivity Link DNSPolicy CR to your Gateway object to automatically map your hostnames to your Gateway object’s IP address. Point your DNSPolicy CR to your Gateway object by name in the targetRef: section. The DNSPolicy CR must reside in the same namespace as the Gateway object. **

Prerequisites 

You installed OpenShift Container Platform. 

**You installed OpenShift CLI (oc). **

You installed the MCP gateway Operator. 

Procedure 

**1. Create a Gateway object by using the following example as a template: **

Example Gateway CR with listeners 

apiVersion: gateway.networking.k8s.io/v1 kind: Gateway metadata:   name: mcp-gateway   namespace: gateway-namespace spec:   gatewayClassName: openshift-default   listeners:     - name: http       port: 80       protocol: HTTP       allowedRoutes:         namespaces:           from: All     - name: mcps       hostname: mcp.example.com       port: 8080       protocol: HTTP       allowedRoutes:         namespaces:           from: All     - name: https 

**The custom resource (CR) is a Gateway named mcp-gateway that exists in the gatewaynamespace namespace and has three listeners configured. **

**On OpenShift Container Platform, the spec.listeners.tls.certificateRefs: value can specify the Secret CR containing the default wildcard certificate for the OpenShift Ingress **controller. 

IMPORTANT 

**You must use the spec.listeners[].name value in the corresponding MCPGatewayExtension CR spec.targetRef.sectionName: field. **

**2. Optional. Verify the Connectivity Link DNSPolicy CR attachment by checking its status with **the following command: 

***Replace <mcp_dns_policy> with the name of your Connectivity Link DNSPolicy CR. ***

***Replace <gateway_namespace> with the Gateway object namespace. ***

Example output 

1.3. CONFIGURE MCP GATEWAY LISTENERS 

**Connect your MCP gateway to your agentic AI systems by appending your Gateway custom resource **(CR) with your MCP listener information. The MCP listener handles the transport protocol, opens an MCP session on the port, and establishes a security perimeter. You can also add listeners for unencrypted web traffic and secured traffic. 

Prerequisites 

You are logged in to your OpenShift Container Platform cluster. 

You created a gateway custom resource (CR). 

You installed MCP gateway. 

      hostname: mcp.apps.openshift.example.com       port: 443       protocol: HTTPS       allowedRoutes:         namespaces:           from: All       tls:         certificateRefs:           - group: ''             kind: Secret             name: default-ingress-cert         mode: Terminate 

*$ oc get dnspolicy <mcp_dns_policy> -n <gateway_namespace> -o wide *

ACCEPTED: True 

You configured a gateway API provider. 

Optional. If you are adding a secure listener, you have a TLS certificate to reference. The **certificate must be in the same namespace as the Gateway CR. **

Procedure 

**1. Add an MCP gateway listener to your Gateway CR by appending it with the following command: **

***Replace <mcp_gateway> with the name of your MCP gateway. ***

***Replace <gateway_namespace> with the namespace where your Gateway object is ***applied. 

***Replace <mcp.example.com> with the hostname you want to use. ***

2. Verify that your listener is working by running the following command: 

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

***Replace <gateway_namespace> with the namespace where your Gateway object is ***applied. 

**The conditions Accepted: True and Programmed: True are expected in the status of the **output. 

**3. Add a standard web traffic listener to your Gateway CR by appending it with the following **command: 

*$ $ oc patch gateway <mcp_gateway> -n <gateway_namespace> --type='json' -p='[ *  {     "op": "add",     "path": "/spec/listeners/-",     "value": {       "name": "mcps", *      "hostname": "<mcp.example.com>", *      "port": 8080,       "protocol": "HTTP",       "allowedRoutes": {         "namespaces": {           "from": "All"         }       }     }   } ]' 

*$ oc get gateway <mcp_gateway> -n <gateway_namespace> -o yaml *

*$ oc patch gateway <mcp_gateway> -n <gateway_namespace> --type='json' -p='[ *  {     "op": "add",     "path": "/spec/listeners/-",     "value": {       "name": "http-web", 

***Replace <mcp_gateway> with the name of your MCP gateway. ***

***Replace <gateway_namespace> with the namespace where your Gateway object is ***applied. 

**The listener.name value must be a unique name within the Gateway object. In this example, http-web is used. **

**The listener.port: 80, is the standard port for unencrypted web traffic. **

**You can add a hostname if you want to limit incoming domain names. **

**4. Add a secure listener to your Gateway CR by appending it with the following command: **

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

***Replace <gateway_namespace> with the namespace where your Gateway object is ***applied. 

      "port": 80,       "protocol": "HTTP",       "allowedRoutes": {         "namespaces": {           "from": "All"         }       }     }   } ]' 

*$ oc patch gateway <mcp_gateway> -n <gateway_namespace> --type='json' -p='[ *  {     "op": "add",     "path": "/spec/listeners/-",     "value": {       "name": "https", *      "hostname": "<mcp.example.com>", *      "port": 443,       "protocol": "HTTPS",       "tls": {         "mode": "Terminate",         "certificateRefs": [           {             "name": "mcp-tls-secret",             "kind": "Secret"           }         ]       },       "allowedRoutes": {         "namespaces": {           "from": "All"         }       }     }   } ]' 

***Replace <mcp.example.com> with the hostname you are targeting. ***

**The spec.listeners.tls.certificateRefs.name: parameter specifies the name of your secret. This example uses mcp-tls-secret. **

**The spec.listeners.tls.mode: Terminate value means that the gateway decrypts the **traffic and sends it as plain text to your MCP server. You can specify the mode that you require. 

**You must set a spec.listeners.hostname so that the relevant certificate is presented to **the correct client. 

5. Check that your certificates are properly linked by running the following command: 

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

***Replace <gateway_namespace> with the namespace where your Gateway object is ***applied. 

**The status message outputs any errors. **

Verification 

Check the status your listeners and related objects by running the following command: 

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

***Replace <gateway_namespace> with the namespace where your Gateway object is ***applied. 

Example output 

*$ oc get gateway <mcp_gateway> -n <gateway_namespace> -o *jsonpath='{.status.listeners[?(@.name=="https")]}' 

*$ oc describe gateway <mcp_gateway> -n <gateway_namespace> *

*# ... *Status:   Listeners:     - Name: http-web       Supported Kinds:         Group: gateway.networking.k8s.io         Kind:  HTTPRoute       Conditions:         Last Transition Time:  2026-04-01T...         Message:               None         Reason:                Programmed         Status:                True         Type:                  Programmed     - Name: https       Conditions:         Reason:                ResolvedRefs         Status:                True         Type:                  ResolvedRefs 

**The Events section of the output can also show port conflicts, problems with your gatewayClassName: value, missing routes, and a lack of permissions to read secrets. **

1.4. UNDERSTAND THE MCPGATEWAYEXTENSION CUSTOM RESOURCE 

You can deploy more than one MCP gateway instance within a single cluster by using more than one **Gateway custom resource (CR). You muse use an MCPGatewayExtension CR for each Gateway CR. **Each deployment of the MCP gateway manages its associated MCP servers by using the **MCPGatewayExtension controller in the following ways: **

**Defines which Gateway object the MCP gateway instance is responsible for. **

**Determines where configuration Secret objects are created. **

Enables isolation by allowing multiple MCP gateway instances in different namespaces to target **different Gateway objects. **

IMPORTANT 

**Each namespace can only have one MCPGatewayExtension CR. Each Gateway object can have only one MCPGatewayExtension CR. If more than one MCPGatewayExtension CR targets the same Gateway object, the controller marks newer ones as conflicted. The oldest MCPGatewayExtension CR wins. **

Automatic route creation 

**The MCPGatewayExtension controller automatically creates an HTTPRoute CR named mcp-gateway-route. The automatically created HTTPRoute CR has the following characteristics: **

**Routes /mcp traffic to the mcp-gateway broker service on port 8080 **

**Uses the hostname from the Gateway listener. Wildcards such as *.example.com become mcp.example.com **

**References the target gateway with the correct sectionName **

**Is owned by the MCPGatewayExtension controller and is cleaned up automatically if the **controller is deleted 

Custom route creation 

*# ... *Events:   Type    Reason            Age   From                       Message   Normal  Synced            12m   gateway-api-controller     Successfully synced Gateway configuration   Normal  IPAllocated       11m   mcp-operator               Assigned IP 192.168.1.100 to Gateway   Normal  ListenerAccepted  10m   gateway-api-controller     Listener "http-web" accepted   Normal  Programmed        10m   gateway-api-controller     Gateway has been successfully programmed *# ... *

**If you require custom route, you can disable automatic HTTPRoute CR creation by setting the spec.httpRouteManagement: parameter to Disabled in your MCPGatewayExtension CR. After you create the MCPGatewayExtension CR, you can create a custom HTTPRoute CR. **

1.5. APPLY THE MCPGATEWAYEXTENSION CUSTOM RESOURCE 

To finish your installation of the MCP gateway deployment Operator by using Operator Lifecycle **Manager (OLM), create a MCPGatewayExtension custom resources (CR) manually and apply it to complete your initial setup. After the extension is ready, both an HTTPRoute object and an Envoy filter **are automatically created. 

IMPORTANT 

**Each namespace can only have one MCPGatewayExtension CR. Each Gateway object can have only one MCPGatewayExtension CR. **

Prerequisites 

You installed OpenShift Container Platform. 

**You installed OpenShift CLI (oc). **

You installed the MCP gateway Operator. 

You configured at least one listener. 

**If you are creating your MCPGatewayExtension CR in a different namespace than your Gateway object, you have created a ReferenceGrant CR. **

Procedure 

**1. Create an MCPGatewayExtension CR by using the following example as a template: **

Example MCPGatewayExtension CR 

**Replace the metadata.name: parameter value with the name you want to use. **

**Replace the metadata.namespace: parameter value with the namespace you want to use. **

apiVersion: mcp.kuadrant.io/v1alpha1 kind: MCPGatewayExtension metadata: *  name: <mcp_gateway_one>   namespace: <mcp_system> *spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway *    name: <mcp_gateway>     namespace: <gateway_system> *    sectionName: mcp   httpRouteManagement: Enabled 

**The spec.targetRef.sectionName: parameter value must be the same as name of the listener on the gateway. In this example, mcp is used. **

**The spec.targetRef.namespace: value must be the namespace of the Gateway object *****where you created your listener. In this example, <gateway_system> is used. ***

**The value of the sectionName: parameter must match the listener name: value defined on *****your Gateway object in the <gateway_system> namespace. In this example, mcp is used. ***

**The default setting of spec.httpRouteManagement: Enabled means automatically maintained HTTPRoute objects to ensure that traffic for discovered MCP tools is correctly routed through the Gateway object. **

**If you require a customized HTTPRoute CR, set the spec.httpRouteManagement: field value to Disabled. **

**2. Apply the MCPGatewayExtension CR by running the following command: **

***Replace <mcp_gateway_one> with name you used. ***

**3. Wait for the MCPGatewayExtension controller to be ready by running the following command: **

***Replace <mcp_gateway_one> with name you used. ***

***Replace <mcp_system> with name of your MCP gateway deployment. ***

Example successful output 

Example failure output 

Verification 

**1. Verify that the automatic HTTProute object is created by running the following command: **

Example output 

**2. Verify that the Envoy filter exists in the same namespace as the Gateway object by running the **following command: 

*$ oc apply -f <mcp_gateway_one> *

*$ oc wait --for=condition=Ready mcpgatewayextension/<mcp_gateway_one> -n <mcp_system> *

mcpgatewayextension.mcp.kuadrant.io/mcp-gateway-one condition met 

error: timed out waiting for the condition on mcpgatewayextensions/mcp-gateway-one 

$ oc get httproute mcp-gateway-route -n mcp-system 

NAME HOSTNAMES AGE mcp-gateway-route ["mcp.example.com"] 5m 

***Replace <gateway_namespace> with the name of your Gateway CR namespace. ***

1.5.1. The MCPGatewayExtension custom resource API reference 

**You can use the following API reference information for each MCP gateway MCPGatewayExtension **custom resource (CR). 

Table 1.1. MCPGatewayExtension 

Field Type Required Description 

**spec **MCPGatewayExte nsionSpec 

Yes The specification for MCPGatewayExtension custom resource 

**status **MCPGatewayExte nsionStatus 

No The status for the custom resource 

Table 1.2. MCPGatewayExtensionSpec 

Field Type Required Description 

**targetRef **MCPGatewayExte nsionTargetRefere nce 

Yes The Gateway listener to extend with MCP protocol support 

**publicHost **String No Overrides the public host derived from the listener hostname. Use when the listener has a wildcard and you need a specific host 

**privateHost **String No Overrides the internal host used for hairpinning requests back through the **gateway. Defaults to <gateway>-istio. <ns>.svc.cluster.local:<port>, with an https:// scheme prefix when the **targeted Gateway listener uses the HTTPS protocol. The supplied value is honoured verbatim, so an operator can include a scheme, for example, **https://my-gw:443, or pin to a different **port. 

**backendPingInt ervalSeconds **

Integer No How often (in seconds) the broker pings upstream MCP servers. Min: 10, Max: 7200, Default: 60 

*$ oc get envoyfilter -n <gateway_namespace> -l app.kubernetes.io/managed-by=mcp-*gateway-controller 

**trustedHeaders Key **

TrustedHeadersKe y 

No Configures trusted-header key pair for JWT-based tool filtering. When set, the public key secret is injected into the broker deployment with the **TRUSTED_HEADER_PUBLIC_KEY **environment variable. 

**httpRouteMana gement **

String No Controls whether the operator manages **the gateway HTTPRoute CR. The default value is Enabled: creates and manages the HTTPRoute CR. Disabled: does not create an HTTPRoute CR. Disabling does not **delete a route that was created before. 

**sessionStore **SessionStore No References a secret for Redis-based session storage. When not set, inmemory session storage is used. 

**urlElicitation **String No Controls URL-based token elicitation. **Enabled: creates a separate /tokens HTTPRoute and passes --enable-url-elicitation to the broker. Disabled (default): no /tokens route is created. **

Field Type Required Description 

Table 1.3. MCPGatewayExtensionTargetReference 

Field Type Required Description 

**group **String Yes Group of the target resource. Default: **gateway.networking.k8s.io **

**kind **String Yes Kind of the target resource. Default: **Gateway **

**name **String Yes Name of the target Gateway 

**namespace **String No Namespace of the target Gateway. Defaults to the MCPGatewayExtension namespace. Cross-namespace references require a ReferenceGrant 

**sectionName **String Yes Name of a listener on the target Gateway. The controller reads the listener’s port and hostname to configure the MCP Gateway instance 

Table 1.4. TrustedHeadersKey 

Field Type Required Description 

**secretName **String Yes Name of the secret containing the PEM-encoded public key used by the broker to verify trusted-header JWTs. The secret **must have a data entry with key key. When generate is Enabled, the **operator creates this secret 

**generate **String No Controls whether the operator generates **an ECDSA P-256 key pair. Enabled: creates <secretName> (public key) and <secretName>-private (private key) with owner references. Disabled **(default): the secret must already exist. Changing this field requires deleting the existing secrets first to ensure the keys are a matching pair 

Table 1.5. SessionStore 

Field Type Required Description 

**secretName **String Yes Name of the secret containing a **CACHE_CONNECTION_STRING **data entry. The value should be a Redis connection string such as **redis://<user>:<pass>@<host>: <port>/<db>. The secret must exist in **the same namespace as the **MCPGatewayExtension CR and must **have the label **mcp.kuadrant.io/secret: "true". **Injected as **CACHE_CONNECTION_STRING **environment variable into the MCP broker-router component deployment. 

Table 1.6. MCPGatewayExtensionStatus 

Field Type Required Description 

**conditions **Kubernetes meta/v1.Condition 

Yes List of conditions that define the status of the resource 

Table 1.7. Conditions 

Type Description 

**Ready Indicates whether the MCPGatewayExtension is fully configured as **follows: the broker-router deployment is running, the EnvoyFilter is applied, and trusted headers, if configured, are valid. 

Table 1.8. Condition reasons 

Reason Description 

**ValidMCPGatewayExtension The MCPGatewayExtension is valid and ready. **

**InvalidMCPGatewayExtensio n **

Invalid configuration detected. 

**ReferenceGrantRequired A ReferenceGrant is missing for a cross-namespace Gateway **reference. 

**DeploymentNotReady **The broker-router deployment is not ready. 

**SecretNotFound **A referenced secret is missing, specifically the trusted headers or session store. 

**SecretInvalid A referenced secret lacks the required data entry: key for trusted headers, CACHE_CONNECTION_STRING for session store. **

1.5.2. Automatically created HTTPRoute example 

**Applying the MCPGatewayExtension custom resources (CR) generates an automatic HTTPRoute CR. **The following is an example of the route. 

**Example automatically generated HTTPRoute CR **

apiVersion: gateway.networking.k8s.io/v1 kind: HTTPRoute metadata:   name: mcp-gateway-route   namespace: mcp-gateway-namespace spec:   parentRefs:   - name: mcp-gateway     namespace: gateway-namespace     sectionName: mcp   rules:   - matches:     - path:         type: PathPrefix         value: /mcp 

**The value of the spec.parentRefs.name: parameter matches your Gateway CR name. **

**The value of the spec.parentRefs.namespace: parameter matches your Gateway namespace. **

**The value of the spec.parentRefs.sectionName: parameter matches the spec.listeners[*].name value of your Gateway object listener. **

**The value of the spec.rules.backendRefs.name: is the Kubernetes service for your MCP **gateway. 

**The value of the spec.rules.backendRefs.port: is the port that the MCP gateway is listening **on. 

1.6. APPLY A REFERENCEGRANT CUSTOM RESOURCE 

**You can isolate teams within a single cluster by applying team-specific MCPGatewayExtension custom resources (CRs) in individual namespaces that all target a shared Gateway object. When you apply an MCPGatewayExtension CR in a different namespace than the Gateway CR, you must then create a ReferenceGrant in the namespace of the gateway to give access. **

Prerequisites 

You installed OpenShift Container Platform. 

**You installed OpenShift CLI (oc). **

You installed the MCP gateway Operator. 

You configured at least one listener. 

Procedure 

**1. Create a ReferenceGrant CR by using the following example as a template: **

**Example ReferenceGrant CR **

    backendRefs:     - name: mcp-gateway       port: 8080 

apiVersion: gateway.networking.k8s.io/v1beta1 kind: ReferenceGrant metadata: *  name: <allow_team_a> *  namespace: gateway-system spec:   from:     - group: mcp.kuadrant.io       kind: MCPGatewayExtension *      namespace: <team_a> *  to:     - group: gateway.networking.k8s.io       kind: Gateway 

**Replace the metadata.name: value with the name that you want to use. **

**Replace the spec.from.namespace: value with the namespace where the MCPGatewayExtension CR is applied. **

2. Apply the CR by running the following command: 

***Replace <allow_team_a> with name you used. ***

1.7. DNS MANAGEMENT WITH THE MCP GATEWAY 

**You can use a variety of options to enable the resolution of hostnames associated within your Gateway **object listeners, depending on the operating environment and targeted hostname. 

**For example, if the hostname is within the DNS zone defined by a dns.config.openshift.io/cluster resource, you can use the OpenShift Cluster Ingress Operator to register the IP address of the Gateway object in the associated cloud DNS provider. You must create the Gateway object in the namespace where the IngressController object is applied. **

In environments where OpenShift Container Platform is not connected to a cloud provider, you must **take additional steps to manage how the Gateway object is exposed outside the cluster and how traffic is resolved. You can use MetalLB to advertise IP addresses associated with the Gateway object. You **can then either perform DNS registration manually, or use automation, such as the ExternalDNS Operator. 

**When Gateway and MCPGatewayExtension objects are applied in different namespaces, such as openshift-ingress and mcp-system, you must create a ReferenceGrant custom resource for cross-**namespace communication. 

1.8. APPLY A CUSTOMIZED HTTPROUTE OBJECT 

**In many production environments, you are likely to require a custom HTTPRoute object for your MCP **gateway. 

For example, if any of the following situations apply, use a custom HTTP route: 

An identity provider protects your MCP gateway. 

You have a web-based AI chat interface that requires cross-origin resource sharing (CORS) headers so that one domain can talk to the other. 

You need additional path rules for things such as version switching, health check services, and tool dashboards. 

Prerequisites 

You installed OpenShift Container Platform. 

**You installed OpenShift CLI (oc). **

You installed the MCP gateway Operator. 

*$ oc apply -f <allow_team_a> *

You configured at least one listener. 

**You created a MCPGatewayExtension custom resource (CR). **

Procedure 

1. If you have not already done so, disable automatic route creation on your corresponding **MCPGatewayExtension object by running the following command: **

***Replace <mcp_system> with the namespace where MCP gateway is installed. ***

***Replace <extension_name> with the name of your MCPGatewayExtension CR. ***

**2. Create your customized HTTPRoute CR by using the following template: **

**Example customized HTTPRoute CR **

*$ oc patch mcpgatewayextension -n <mcp_system> <extension_name> \ *  --type merge -p '{"spec":{"httpRouteManagement":"Disabled"}}' 

apiVersion: gateway.networking.k8s.io/v1 kind: HTTPRoute metadata: *  name: <mcp_route_custom>   namespace: <mcp_system> *spec:   parentRefs: *    - name: <gateway_name>       namespace: <gateway_namespace>       sectionName: <mcp_gateway_listener> *  hostnames: *    - <'mcp.example.com'> *  rules:     - matches:         - path:             type: PathPrefix             value: /mcp       filters:         - type: ResponseHeaderModifier           responseHeaderModifier:             add:               - name: Access-Control-Allow-Origin                 value: "*"               - name: Access-Control-Allow-Methods                 value: "GET, POST, PUT, DELETE, OPTIONS, HEAD"               - name: Access-Control-Allow-Headers                 value: "Content-Type, Authorization, Accept, Origin, X-Requested-With"               - name: Access-Control-Max-Age                 value: "3600"               - name: Access-Control-Allow-Credentials                 value: "true"       backendRefs: *        - name: <mcp_gateway> *          port: 8080     - matches: 

**Replace the metadata.name: value with the name that you want to use. **

**Replace the metadata.namespace: value with the namespace that you want to use. **

**Replace the spec.targetRef.sectionName: parameter value with the MCP Gateway object **listener. 

**Replace the spec.parentRefs.name: value the name that you want to use. **

**Replace spec.parentRefs.namespace: value with the namespace that you want to use. **

**Replace the spec.hostnames: value or list with the values you want to use. **

**Replace the spec.rules.matches.path.value: value with the URL path where you want to have your Gateway object available. **

**Replace the spec.rules.backend.Refs.name: value with the name of your MCP **gatewayoyment. 

3. Apply the CR by running the following command: 

***Replace <mcp_route_custom> with the name that you used for your HTTPRoute CR. ***

**4. Delete the automatically created HTTPRoute CRs by running the following command: **

IMPORTANT 

**If you do not delete existing HTTPRoute CRs, the Gateway API chooses one based on a spec-defined precedence chain used when multiple HTTPRoute CRs **match the same request. 

1.9. VERIFY THAT AN MCP ENDPOINT IS ACCESSIBLE THROUGH YOUR MCP GATEWAY 

You can verify that your MCP gateway is reaching your Model Context Protocol (MCP) endpoint by running a curl command to check for communication. 

Prerequisites 

You completed all of the installation steps. 

Procedure 

        - path:             type: PathPrefix *            value: </.well_known/oauth_protected_resource> *      backendRefs: *        - name: <mcp_gateway> *          port: 8080 

*$ oc apply -f <mcp_route_custom> *

$ oc delete httproute mcp-gateway-route  -n mcp-system --ignore-not-found 

Verify that the MCP endpoint is accessible through your MCP gateway instance by running the following command: 

***Replace <mcp.example.com:port/mcp> with your <hostname_value/endpoint_name>. ***

Example output 

*$ curl -X POST http://<mcp.example.com:port/mcp> \ *  -H "Content-Type: application/json" \   -H "Accept: application/json, text/event-stream" \   -d '{"jsonrpc": "2.0", "id": 1, "method": "initialize"}' 

{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-11-25","capabilities":{"tools": {"listChanged":true}},"serverInfo":{"name":"Kuadrant MCP Gateway","version":"0.6.0"}}} 