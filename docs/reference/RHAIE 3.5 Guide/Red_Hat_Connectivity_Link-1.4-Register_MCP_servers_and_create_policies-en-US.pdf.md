# Red_Hat_Connectivity_Link-1.4-Register_MCP_servers_and_create_policies-en-US.pdf

- Red Hat Connectivity Link 1.4

# Register MCP servers and create policies

Register MCP servers and configure auth policies 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 Register MCP servers and create policies

Register MCP servers and configure auth policies

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

To connect backend servers to your gateway, register them and configure access permissions

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. REGISTER ON-PREMISE MCP SERVERS 1.1. UNDERSTAND MCP SERVER REGISTRATION 1.2. REGISTER AN MCP SERVER FOR USE WITH THE MCP GATEWAY 

1.2.1. Understand the MCPServerRegistration custom resource 1.3. VERIFY AN MCP SERVER REGISTRATION 

CHAPTER 2 REGISTER EXTERNAL MCP SERVERS 2.1. CREATE A SERVICEENTRY FOR AN EXTERNAL MCP SERVER 2.2. CREATE TLS SETTINGS FOR AN EXTERNAL MCP SERVER 2.3. CREATE AN HTTPROUTE FOR AN EXTERNAL MCP SERVER 2.4. CREATE A SECRET FOR AN EXTERNAL MCP SERVER 2.5. CREATE AN AUTHPOLICY FOR AN EXTERNAL MCP SERVER 2.6. CREATE AN MCPSERVERREGISTRATION FOR AN EXTERNAL MCP SERVER 2.7. VERIFY THAT YOUR EXTERNAL MCP SERVER IS READY TO USE 

CHAPTER 3 CREATE VIRTUAL MCP SERVERS 3.1. VIRTUAL MCP SERVERS FOR CURATING TOOLS AND PROMPTS 3.2. VIRTUAL MCP SERVER AUTHORIZATION AND FILTERING 3.3. CREATE VIRTUAL MCP SERVERS 3.4. VERIFY VIRTUAL MCP SERVERS 3.5. DELETE VIRTUAL MCP SERVERS 

CHAPTER 4 USE AUTHENTICATION WITH MCP GATEWAY 4.1. UNDERSTAND MCP GATEWAY AUTHENTICATION 4.2. CONFIGURE MCP GATEWAY AUTHENTICATION WITH AN AUTHPOLICY 

CHAPTER 5 USE AUTHORIZATION WITH MCP GATEWAY 5.1. UNDERSTAND AUTHORIZATION IN MCP GATEWAY 5.2. CONFIGURE MCP GATEWAY AUTHORIZATION WITH AN AUTHPOLICY 

CHAPTER 6 REVOKE MCP SERVER TOOL ACCESS 6.1. UNDERSTAND TOOL ACCESS REVOCATION 6.2. REVOKE TOOL AND PROMPT CALL REQUESTS 6.3. FILTER REVOKED TOOLS AND PROMPTS FROM DISPLAY 

CHAPTER 7 USE CREDENTIALS TO ACCESS EXTERNAL APIS WITH VAULT 7.1. VAULT WITH THE MCP GATEWAY 7.2. SET UP A TRUST RELATIONSHIP BETWEEN VAULT AND AUTHORINO 7.3. CREATE A SINGLE-SERVER-SCOPED AUTHPOLICY CR FOR VAULT 

7.3.1. Parameter values for a single-server-scoped AuthPolicy CR 7.3.2. Test your MCP gateway and Vault integration 

7.4. USE A VAULT ROOT TOKEN 7.5. ADDITIONAL RESOURCES 

3 3 3 7 9 

11 11 

12 13 14 15 16 18 

19 19 19 19 21 

24 

25 25 25 

30 30 31 

36 36 36 37 

42 42 42 43 46 47 48 50 

### CHAPTER 1. REGISTER ON-PREMISE MCP SERVERS

To begin using Model Context Protocol (MCP) servers with your MCP gateway, you must register each **server by creating an HTTPRoute custom resource (CR) and a corresponding MCPServerRegistration **CR that references the route. 

1.1. UNDERSTAND MCP SERVER REGISTRATION 

You must register your Model Context Protocol (MCP) servers so that each server can be discovered and routed to by the MCP gateway. 

**When you register a backend MCP server, you must define a prefix in the MCPServerRegistration **custom resource (CR) for each tool and prompt name. Prefixing each MCP server’s listed capabilities avoids name collisions with other MCP servers. 

The MCP gateway then automatically federates the MCP server’s tools and prompts. 

**To connect an MCP server to the MCP gateway, you must first create an HTTPRoute CR, and then create an MCPServerRegistration CR for the server that references the route. **

When a client calls a tool or requests a prompt, the MCP gateway identifies the target upstream server **by the prefix, strips the prefix, then routes the request to the correct MCP server with authentication and authorization through an AuthPolicy CR. **

1.2. REGISTER AN MCP SERVER FOR USE WITH THE MCP GATEWAY 

Direct your MCP gateway to discover and route to your Model Context Protocol (MCP) servers by registering them. To connect each MCP server to the MCP gateway, you must first create an **HTTPRoute custom resource (CR) that routes to the server. Then, you must create an MCPServerRegistration custom resource (CR) that references the HTTPRoute CR. **

Prerequisites 

You installed the MCP gateway. 

**You have a Gateway object configured with your requirements. **

You configured a listener for the MCP gateway. 

**You created an HTTPRoute CR for the MCP gateway. **

**You created and applied an MCPGatewayExtension CR. **

If you are using a gateway in a namespace that is different from the one where the **MCPGatewayExtension CR was applied, you created a ReferenceGrant object. **

**You are logged into an OpenShift Container Platform cluster with an admin role. **

Procedure 

**1. Create an HTTPRoute CR that routes to your MCP server by using the following template: **

**Example HTTPRoute CR **

***For the metadata.name: parameter value, replace <mcp_api_key_server_route> with the ***name of the http route. 

***For the metadata.namespace: parameter value, replace <mcp_test> with the namespace *****you need to use. The HTTPRoute CR must be in the same namespace as the MCPServerRegistration CR unless targetRef.namespace is set in the MCPServerRegistration CR. **

**For the spec.parentRefs.name: and spec.parentRefs.namespace: parameter values, use the values from the Gateway CR that you are targeting. **

**For the spec.hostnames: parameter value, replace the list with your required internal **routing hostname. 

***For the spec.rules.backendRefs.name: parameter value, replace <mcp_api_key_server> ***with your MCP gateway service name. 

**For the spec.rules.backendRefs.port: parameter value, replace 9090 with your MCP **server port. 

2. Apply the CR by running the following command: 

***Replace <mcp_api_key_server_route.yaml> with the name of the http route you created. ***

**3. Create an MCPServerRegistration CR that references your HTTPRoute CR by using the **following template: 

**Example MCPServerRegistration CR **

apiVersion: gateway.networking.k8s.io/v1 kind: HTTPRoute metadata: *  name: <mcp_api_key_server_route>   namespace: <mcp_test> *  labels:     mcp-server: 'true' spec:   parentRefs: *    - name: <mcp_gateway>       namespace: <gateway_system> *  hostnames:     - 'api-key-server.mcp.local'   rules:     - matches:         - path:             type: PathPrefix             value: /       backendRefs: *        - name: <mcp_api_key_server> *          port: 9090 

*$ oc apply -f <mcp_api_key_server_route.yaml> *

apiVersion: mcp.kuadrant.io/v1alpha1 kind: MCPServerRegistration 

**Replace the metadata.name: and metadata.namespace: field values with the ones you want to use. If you did not use a ReferenceGrant CR, the value of metadata.namespace: must be the same as specified in the HTTPRoute object. **

**Replace the spec.prefix: field with the value that you want to prefix the tools available with **this MCP server. 

**Replace the spec.targetRef.name field value with the name of the HTTPRoute CR you *****applied. In this example, <mcp_api_key_server_route> is used. ***

**Replace the spec.targetRef.namespace: field value with the namespace where your *****HTTPRoute CR is applied. In this example, <mcp_test> is used. ***

**Replace the credentialRef.name: field value with the name of your Secret CR. In this *****example, <mcp_server_one_secret> is used. You can omit this parameter if your MCP ***server does not require authentication or authorization. 

For more information about these parameters, see "Understanding the **MCPServerRegistration custom resource." **

IMPORTANT 

**The prefix field only accepts lowercase letters ( a-z), digits (0-9), and underscores (_). The value must start with a letter or digit. This is enforced at **the CRD schema level. 

**Existing MCPServerRegistration CRs with non-conforming prefixes **continue to function but cannot be updated. To update such resources, delete and re-create them with a conforming prefix. 

4. Apply the CR by running the following command: 

***Replace <mcp_server_one.yaml> with your MCPServerRegistration CR. ***

**5. Check the status of your current MCPServerRegistration CR by running the following **command: 

metadata: *  name: <mcp_server_one>   namespace: <mcp_test> *spec: *  prefix: <serverone>_ *  targetRef:     group: "gateway.networking.k8s.io"     kind: "HTTPRoute" *    name: "<mcp_api_key_server_route>"     namespace: "<mcp_test>" *  credentialRef: *    name: <mcp_server_one_secret> *    key: api-key 

*$ oc apply -f <mcp_server_one.yaml> *

*$ oc get mcpsr -n <mcp_server_one> *

***Replace <mcp_server_one> with the name of your MCPServerRegistration CR. ***

Example output 

**6. Check the status of all MCPServerRegistration CRs in the cluster by running the following **command: 

Example output 

7. Check on tool discovery status by running the following command: 

Example output 

NAMESPACE   NAME            PREFIX      TARGET                     PATH   READY   TOOLS   CREDENTIALS   AGE mcp-test    my-mcp-server   myserver_   mcp-api-key-server-route   /mcp   True    4                     30s 

$ oc get mcpsr -A 

NAMESPACE   NAME              PREFIX      TARGET                  PATH   READY   TOOLS   CREDENTIALS   AGE mcp-test    mcp-server-one    serverone   mcp-api-key-server      /mcp   True    4                     14m mcp-test    mcp-server-two    servertwo   mcp-generic-route       /mcp   True    7                     2d mcp-prod    analytics-tools   stats       analytics-route         /mcp   True    3                     5h 

$ oc get mcpsr -A -o yaml 

apiVersion: v1 items: - apiVersion: mcp.kuadrant.io/v1alpha1   kind: MCPServerRegistration   metadata:     annotations:       kubectl.kubernetes.io/last-applied-configuration: |         {"apiVersion":"mcp.kuadrant.io/v1alpha1","kind":"MCPServerRegistration","metadata": {"annotations":{},"labels":{"mcp.kuadrant.io/managed":"true"},"name":"test-server1","namespace":"mcp-test"},"spec":{"targetRef": {"group":"gateway.networking.k8s.io","kind":"HTTPRoute","name":"mcp-server1-route"},"prefix":"test1_"}}     creationTimestamp: "2026-03-31T09:50:26Z"     finalizers:     - mcp.kuadrant.io/finalizer     generation: 1     labels:       mcp.kuadrant.io/managed: "true"     name: test-server1     namespace: mcp-test     resourceVersion: "302234"     uid: d9603011-2e0f-4f3f-88d6-eda986f365d1   spec:     path: /mcp 

**When you examine the status block for discoveredTools, you can see that the status.conditions: fields show that an MCP server is present and that tools are available and **ready. 

1.2.1. Understand the MCPServerRegistration custom resource 

**You can explore the required parts and values for an MCPServerRegistration custom resource (CR) by **studying the references contained here. 

Table 1.1. MCPServerRegistration 

Field Type Required Description 

**spec **MCPServerRegist rationSpec 

Yes The specification for the **MCPServerRegistration CR **

**status **MCPServerRegist rationStatus 

No The status for the CR 

Table 1.2. MCPServerRegistrationSpec 

Field Type Required Description 

**targetRef **TargetReference Yes **An HTTPRoute object that **points to a backend MCP server. The controller discovers the backend service from this **HTTPRoute CR and configures **the broker to consolidate the MCP server’s tools. 

    targetRef:       group: gateway.networking.k8s.io       kind: HTTPRoute       name: mcp-server1-route     prefix: test1_   status:     conditions:     - lastTransitionTime: "2026-04-07T08:49:53Z"       message: server added successfully. Total tools added 5       reason: Ready       status: "True"       type: Ready     discoveredTools: 5 kind: List metadata:   resourceVersion: " 

**prefix **String No The prefix added to all consolidated tools from referenced servers. Avoids naming conflicts when aggregating tools from multiple sources, such as **server1_search and server2_search. Immutable **setting. 

**path **String No The URL path where the MCP server endpoint is exposed. **Default value is /mcp. **

**credentialRef **SecretReference No **Reference to a Secret object **that contains authentication credentials. The secret must have the **mcp.kuadrant.io/secret=tru e label. The gateway makes the **credentials available to the broker automatically. 

Field Type Required Description 

Table 1.3. TargetReference 

Field Type Required Description 

**group **String No Group of the target resource. Default value is **gateway.networking.k8s.io. **

**kind **String No Kind of the target resource. **Default value is HTTPRoute. **

**name **String Yes Name of the target **HTTPRoute object. **

**namespace **String No Namespace of the target resource. Defaults to same namespace. 

Table 1.4. SecretReference 

Field Type Required Description 

**name **String Yes **Name of the Secret CR. **

**key **String No **Key within the Secret CR that **has the credential value. Default **value is token. **

Field Type Required Description 

Table 1.5. MCPServerRegistrationStatus 

Field Type Description 

**conditions **Kubernetes meta/v1.Condition 

List of conditions that define the status of the Kubernetes resource. 

**discoveredTools **Integer Number of tools discovered from this **MCPServerRegistration CR. **

1.3. VERIFY AN MCP SERVER REGISTRATION 

You can test that your Model Context Protocol (MCP) server tools are available through the MCP gateway by starting a session and listing available tools and prompts. 

Prerequisites 

You completed all MCP gateway installation and configuration steps. 

You registered the MCP server you want to verify. 

Procedure 

1. Connect to the MCP gateway and initialize a session to dump response headers to a file by running the following command: 

***Replace <example.com> with your URL and port. ***

2. Extract the MCP session ID from the dumped response headers by running the following command: 

3. List the tools using the session ID by running the following command: 

$ curl -s -D /tmp/mcp_headers -X POST http://_<example.com>_/mcp \   -H "Content-Type: application/json" \   -d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "test-client", "version": "1.0.0"}}}' 

$ SESSION_ID=$(grep -i "mcp-session-id:" /tmp/mcp_headers | cut -d' ' -f2 | tr -d '\r') \ echo "MCP Session ID: $SESSION_ID" 

*$ curl -X POST http://<example.com>/mcp \ *  -H "Content-Type: application/json" \   -H "mcp-session-id: $SESSION_ID" \ 

***Replace <example.com> with your URL and port. ***

**4. Expected output: Your MCP server tools are listed in the response, prefixed with the prefix value you configured in the MCPServerRegistration CR. **

5. Verify that your MCP server prompts are also available by running the following command: 

***Replace <example.com> with your URL and port. ***

6. Expected output: Your MCP server prompts are listed in the response and are prefixed with the **prefix value you configured in the MCPServerRegistration CR. **

**7. Retrieve a specific prompt by using the prompts/get method with the prefixed name as shown in **the following command: 

***Replace <example.com> with your URL and port. ***

8. Clean up by running the following command: 

  -d '{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}' 

# Use the same SESSION_ID from the previous step curl -X POST http://_<example.com>_/mcp \   -H "Content-Type: application/json" \   -H "mcp-session-id: $SESSION_ID" \   -d '{"jsonrpc": "2.0", "id": 3, "method": "prompts/list"}' 

$ curl -X POST http://_<example.com>_/mcp \   -H "Content-Type: application/json" \   -H "mcp-session-id: $SESSION_ID" \   -d '{     "jsonrpc": "2.0",     "id": 4,     "method": "prompts/get",     "params": {       "name": "myserver_gh_pr_review",       "arguments": {         "pr_number": "42"       }     }   }' 

$ rm -f /tmp/mcp_headers 

### CHAPTER 2. REGISTER EXTERNAL MCP SERVERS

To use external Model Context Protocol (MCP) servers with your MCP gateway, you must configure ingress, create routing resources, and register the server with the MCP gateway. As a best practice, you must also configure security rules. 

2.1. CREATE A SERVICEENTRY FOR AN EXTERNAL MCP SERVER 

To register an external Model Context Protocol (MCP) server, you must first make sure that it has an **ingress pathway by creating a ServiceEntry custom resource (CR) in your Istio deployment. OpenShift **Container Platform 4.19 and newer provides Istio through the Gateway API. 

Prerequisites 

You completed all of the installation and configuration steps for MCP gateway. 

You have the information for the external MCP server you want to connect to. 

**You installed the OpenShift CLI (oc). **

You are using Istio for ingress control. 

Procedure 

**1. Create a ServiceEntry CR that registers the external server in the Istio service registry by using **the following template: 

**Example ServiceEntry CR **

***Replace <mcp_external_server> with the name of your external MCP server. ***

***Replace <mcp_test> with the namespace that the MCP server is in. ***

***Replace <api.githubcopilot.com> with the host URL of the MCP server. ***

Replace any other values as required. 

2. Apply the CR by running the following command: 

apiVersion: networking.istio.io/v1beta1 kind: ServiceEntry metadata: *  name: <mcp_external_server>   namespace: <mcp_test> *spec:   hosts: *  - <api.githubcopilot.com> *  ports:   - number: 443     name: https     protocol: HTTPS   location: MESH_EXTERNAL   resolution: DNS 

***Replace <mcp_external_server_se.yaml> with the name of your CR. ***

2.2. CREATE TLS SETTINGS FOR AN EXTERNAL MCP SERVER 

**To register an external Model Context Protocol (MCP) server, after you create a ServiceEntry custom resource (CR) in your Istio deployment, you must configure your TLS settings with a DestinationRule **CR. 

Prerequisites 

You completed all of the installation and configuration steps for MCP gateway. 

You have the information for the external MCP server you want to connect to. 

**You installed the OpenShift CLI (oc). **

You are using Istio for ingress control. 

**You created a ServiceEntry object. **

Procedure 

**1. Create a DestinationRule CR that configure your TLS settings by using the following template: **

**Example DestinationRule CR **

***Replace <mcp_external_server> with the name of your external MCP server. ***

***Replace <mcp_test> with the namespace that the MCP server is in. ***

**The default TLS mode is SIMPLE. Change it to MUTUAL in high-security environments or use ISTIO_MUTUAL with OpenShift Service Mesh. A value of DISABLE means that TLS is **not used. 

***Replace <api.githubcopilot.com> with the host URL of the MCP server. ***

2. Apply the CR by running the following command: 

*$ oc apply -f <mcp_external_server_se.yaml> *

apiVersion: networking.istio.io/v1beta1 kind: DestinationRule metadata: *  name: <mcp_external_server>   namespace: <mcp_test> *spec: *  host: <api.githubcopilot.com> *  trafficPolicy:     tls:       mode: SIMPLE *      sni: <api.githubcopilot.com> *

*$ oc apply -f <mcp_external_server_dr.yaml> *

***Replace <mcp_external_server_dr.yaml> with the name of your CR. ***

2.3. CREATE AN HTTPROUTE FOR AN EXTERNAL MCP SERVER 

**To use an external Model Context Protocol (MCP) server, you must create an HTTPRoute custom **resource (CR) that matches your internal hostname and routes to the external service by using Istio. 

Prerequisites 

You completed all of the installation and configuration steps for MCP gateway. 

You have the information for the external MCP server you want to connect to. 

**You installed the OpenShift CLI (oc). **

You are using Istio for ingress control. 

**You created ServiceEntry and DestinationRule objects. **

Procedure 

**1. Create a HTTPRoute CR that routes to the external service by using the following example: **

**Example HTTPRoute CR **

**Replace the metadata.name: field value with the name of your external MCP server. **

apiVersion: gateway.networking.k8s.io/v1 kind: HTTPRoute metadata: *  name: <mcp_external_server>   namespace: <mcp_test> *spec:   parentRefs:   - group: gateway.networking.k8s.io     kind: Gateway *    name: <mcp_gateway>     namespace: <gateway_system> *  hostnames:   - example.mcp.local   rules:   - matches:     - path:         type: PathPrefix         value: /mcp     filters:     - type: URLRewrite       urlRewrite: *        hostname: <api.externalhostname.com> *    backendRefs: *    - name: <api.example.com> *      kind: Hostname       group: networking.istio.io       port: 443 

**Replace the metadata.namespace: field value with the namespace that the MCP server is **in. 

**Set the spec.parentRefs: fields to match your MCP Gateway object. **

**The spec.hostnames: field value is your internal hostname. It must match your *.mcp.local Gateway CR value. **

**The spec.rules.matches.path.value: field value is your MCP gateway endpoint. In this example, /mcp is used. **

**Replace the value of spec.rules.filters.urlRewrite.hostname: with your external hostname. **

**Replace the spec.rules.backendRefs.name: field value with the host URL of the MCP **server. 

2. Apply the CR by running the following command: 

***Replace <mcp_external_server_httproute.yaml> with the name of your CR. ***

2.4. CREATE A SECRET FOR AN EXTERNAL MCP SERVER 

**To use an external Model Context Protocol (MCP) server, you must create a Secret custom resource **(CR) that stores backend API key credentials. 

**This Secret CR is referenced in your MCPServerRegistration CR in the credentialRef parameter. These resources are for backend API key authentication. The api-key is stored in the config secret and **used by the MCP broker component for upstream connections. 

Prerequisites 

You completed all of the installation and configuration steps for MCP gateway. 

You have the information for the external MCP server you want to connect to. 

**You installed the OpenShift CLI (oc). **

You are using Istio for ingress control. 

**You created ServiceEntry, DestinationRule, and HTTPRoute objects. **

Procedure 

**1. Create a Secret CR that stores backend API key credentials by using the following example: **

**Example Secret CR **

*$ oc apply -f <mcp_external_server_httproute.yaml> *

apiVersion: v1 kind: Secret metadata: *  name: <mcp_backend_auth>   namespace: <mcp_test> *

**Replace the metadata.name: field value with the name you want to use. Service naming is **used in this example. 

**Replace the metadata.namespace: field value with the namespace you used in your ServiceEntry object. **

**You must use the metadata.labels.mcp.kuadrant.io/secret: "true" field and value. If you do not use this value, the MCP gateway controller cannot see the Secret object. **

**The metadata.labels.app.kubernetes.io/part-of: mcp-gateway field and value are **optional. 

**Replace your stringData.api-key: value with the one you need to use. **

2. Apply the CR by running the following command: 

***Replace <mcp_external_server_secret.yaml> with the name of your CR. ***

2.5. CREATE AN AUTHPOLICY FOR AN EXTERNAL MCP SERVER 

**To secure your use of an external Model Context Protocol (MCP) server, creating an AuthPolicy custom **resource (CR) to authenticate your sessions is a best practice. The following example uses **Kuadrant/Authorino for OAuth authentication and creates an AuthPolicy CR to handle authorization **headers. 

NOTE 

This step is required if you are using OAuth authentication for your external MCP server. If **your external MCP server uses a simple API key, you can use a credentialRef in your MCPServerRegistration CR instead, and an AuthPolicy object is not needed. **

Prerequisites 

You completed all of the installation and configuration steps for MCP gateway. 

You have the information for the external MCP server you want to connect to. 

**You installed the OpenShift CLI (oc). **

You are using Istio for ingress control. 

**You created ServiceEntry, DestinationRule, and HTTPRoute objects. **

Procedure 

  labels:     mcp.kuadrant.io/secret: "true"     app.kubernetes.io/part-of: mcp-gateway     env: production type: Opaque stringData: *  api-key: <"mcp_prod_12abC34..."> *

*$ oc apply -f <mcp_external_server_secret.yaml> *

**1. Create an AuthPolicy CR that handles authorization headers by using the following example: **

**Example AuthPolicy CR **

**Replace the metadata.name: field value with the name you want to use. This approach uses **service naming. 

**Replace the metadata.namespace: field value with the namespace you used in your ServiceEntry object. **

**Replace the spec.name: value with the name of your external MCP server route. **

**This AuthPolicy CR passes through the Authorization header from the original request. **

2. Apply the CR by running the following command: 

***Replace <mcp_external_server_authpolicy.yaml> with the name of your CR. ***

2.6. CREATE AN MCPSERVERREGISTRATION FOR AN EXTERNAL MCP SERVER 

**To use an external Model Context Protocol (MCP) server, you must create an MCPServerRegistration **custom resource (CR) that registers your external MCP server with the MCP gateway. 

Prerequisites 

You completed all of the installation and configuration steps for MCP gateway. 

You have the information for the external MCP server you want to connect to. 

**You installed the OpenShift CLI (oc). **

You are using Istio for ingress control. 

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <mcps_auth_policy>   namespace: <mcp_test> *spec:   targetRef:     group: gateway.networking.k8s.io     kind: HTTPRoute *    name: <mcp_external_server> *  rules:     response:       success:         headers:           authorization:             plain:               expression: 'request.headers["authorization"]' 

*$ oc apply -f <mcp_external_server_authpolicy.yaml> *

**You created ServiceEntry, DestinationRule, HTTPRoute, and Secret objects. **

**Recommended: You created an AuthPolicy CR. **

Procedure 

**1. Create a MCPServerRegistration CR that registers the external MCP server with the MCP **gateway by using the following example: 

**Example MCPServerRegistration CR **

**Replace the metadata.name: field value with the name you want to use. **

**Replace the metadata.namespace: field value with the namespace you need to use. If you did not use a ReferenceGrant CR, the value of metadata.namespace: must be the same as the namespace specified in the HTTPRoute object. **

**Replace the spec.prefix: field with the value that you want to use to prefix the tools **available with this MCP server. 

**Replace the spec.targetRef.name: field value with the name of the HTTPRoute CR you **applied. 

**Replace the value of spec.targetRef.namespace: with the namespace where your HTTPRoute CR is applied. **

**The spec.credentialRef: field points to the Secret CR that has credentials for the external **MCP server. 

IMPORTANT 

**A prefix value cannot include spaces or special characters. **

2. Apply the CR by running the following command: 

***Replace <mcp_external_server_mcpsr.yaml> with the name of your CR. ***

apiVersion: mcp.kuadrant.io/v1alpha1 kind: MCPServerRegistration metadata: *  name: <external_mcp_server>   namespace: <mcp_test> *spec: *  prefix: <"extserver">_ *  targetRef:     group: "gateway.networking.k8s.io"     kind: "HTTPRoute" *    name: "<mcp_api_key_server_route>"     namespace: "<mcp_test>" *  credentialRef: *    name: <mcp_backend_secret> *    key: api-key 

*$ oc apply -f <mcp_external_server_mcpsr.yaml> *

2.7. VERIFY THAT YOUR EXTERNAL MCP SERVER IS READY TO USE 

To verify that an external Model Context Protocol (MCP) server is ready to use, check the status of your **MCPServerRegistration custom resource (CR). **

Prerequisites 

You completed all of the installation and configuration steps for MCP gateway. 

You have the information for the external MCP server you want to connect to. 

**You installed the OpenShift CLI (oc). **

You are using Istio for ingress control. 

You completed the previous steps to register your MCP server with the MCP gateway. 

Procedure 

**Check the status of all MCPServerRegistration CRs in the cluster by running the following **command: 

Example output 

$ oc get mcpsr -A 

NAMESPACE   NAME              PREFIX      TARGET                  PATH   READY   TOOLS   CREDENTIALS          AGE mcp-test    mcp-server-ext    extserver   external-mcp-server     /mcp   True    5       ext-server-secret    14m mcp-test    mcp-server-one    serverone   mcp-api-key-server      /mcp   True    4                            1d mcp-test    mcp-server-two    servertwo   mcp-generic-route       /mcp   True    7                            2d mcp-prod    analytics-tools   stats       analytics-route         /mcp   True    3       analytics-secret     5h 

### CHAPTER 3. CREATE VIRTUAL MCP SERVERS

Create focused, curated tool and prompt collections from your aggregated internal and external Model Context Protocol (MCP) servers by creating virtual MCP servers from any of your registered MCP servers. 

3.1. VIRTUAL MCP SERVERS FOR CURATING TOOLS AND PROMPTS 

When you aggregate all your model context (MCP) servers centrally, you solve for authentication, authorization, and configuration management. At the same time, this aggregation can overwhelm largelanguage models (LLMs) and AI agents with too many tool and prompt choices. You can create virtual MCP servers to curate tools and prompts for each situation. 

You can narrow the scope for your agentic services and applications by creating virtual MCP servers. These virtual servers filter the complete capabilities based on a curated selection and access only the relevant capabilities with HTTP headers. You can use virtual MCP servers to do the following: 

Create specialized collections of tools for specific use cases. 

Reduce the load on LLMs by presenting fewer, more relevant tools and prompts. 

Group tools and prompts by function, for example, development tools, data analysis tools, and so on. 

Make it easier for users and agents to find the right tools and prompts. 

Combine with authorization policies for fine-grained access management. 

**Virtual MCP servers only filter those tools and prompts that a client can discover by using the tools/list and prompts/list concepts. Virtual MCP servers do not change call routing or authorization. **

3.2. VIRTUAL MCP SERVER AUTHORIZATION AND FILTERING 

When you create virtual Model Context Protocol (MCP) servers, the capabilities list is the intersection of the authentication and user-based tool or prompt filtering that already exists. 

**Each registered MCP server retains its AuthPolicy custom resources (CR) and role configurations. **

**When requests with a virtual MCP server header tools/list and prompts/list come in, the MCP gateway **broker component applies filters sequentially. The following are the applied filters in order: 

**1. Identity-based filtering: The x-mcp-authorized header, injected by the AuthPolicy CR, reduces the tools and prompts list to only the capabilities that the user has resource_access roles **configured for. 

**2. Virtual MCP server filtering: The X-Mcp-Virtualserver header further reduces the availablecapabilities list to only those that you defined in the MCPVirtualServer CR. **

**For example, if the accounting virtual server lists test1_greet and test3_add, but the user only has the greet role on mcp-test/test-server1, that user only sees the tool, test1_greet. **

3.3. CREATE VIRTUAL MCP SERVERS 

To create virtual Model Context Protocol (MCP) servers for different use cases, you must define the 

**virtual server with an MCPVirtualServer custom resource (CR) that specifies required fields. When a **client includes the virtual MCP server header, the MCP gateway filters responses to only include the specified tools. 

**An MCPVirtualServer CR must contain the following information: **

Tool selection: Which tools from the aggregated pool to expose. 

Description: A human-readable description of the virtual MCP server’s purpose. 

**Access method: Tools are accessed by the X-Mcp-Virtualserver header with the namespace/name format. **

NOTE 

Prompt selection is optional. Specify which prompts from the aggregated pool to expose. **Prompts are accessed by the X-Mcp-Virtualserver header with the namespace/name **format. 

Prerequisites 

You completed all of the installation and configuration steps for MCP gateway. 

You registered your MCP servers. 

**You installed the OpenShift CLI (oc). **

Procedure 

**1. Create an MCPVirtualServer CR for a virtual MCP server that curates development tools by **using the following example: 

**Example developer tools MCPVirtualServer CR **

**Replace the metadata.name: value with the name you want to use. **

**Replace the metadata.namespace: value with the name you want to use. **

**Replace the list values in the spec.tools: parameter with the names of the tools you want to **curate to this CR. 

2. Apply the CR by running the following command: 

apiVersion: mcp.kuadrant.io/v1alpha1 kind: MCPVirtualServer metadata: *  name: <dev_tools>   namespace: <mcp_system> *spec:   description: "Development and debugging tools"   tools:   - mcpserver1_devtool1   - mcpserver2_headers1   - mcpserver3_debug1 

***Replace <mcpvs_devtools.yaml> with the name of your CR. ***

**3. Create an MCPVirtualServer CR for a virtual server that curates data analysis tools and **prompts by using the following example: 

**Example data analysis tools MCPVirtualServer CR **

**Replace the metadata.name: value with the name you want to use. **

**Replace the metadata.namespace: value with the namespace you want to use. The metadata.namespace: value can be any namespace where you have permission to create **resources. 

**Replace the list values in spec.tools: with the names of the tools you want to curate to this **CR. 

**Replace the list values in spec.prompts: with the names of the prompts you want to curate **to this CR. 

4. Apply the CR by running the following command: 

***Replace <mcpvs_datatools.yaml> with the name of your CR. ***

Next step 

Verify that your virtual MCP servers are returning the tools and prompts that you expect to see by following the instructions in "Verifying virtual MCP servers". 

3.4. VERIFY VIRTUAL MCP SERVERS 

After you create your virtual Model Context Protocol (MCP) servers, you can check that they are returning the tool and prompt lists that you want. 

Prerequisites 

You completed all of the installation and configuration steps for MCP gateway. 

*$ oc apply -f <mcpvs_devtools.yaml> *

apiVersion: mcp.kuadrant.io/v1alpha1 kind: MCPVirtualServer metadata: *  name: <data_tools>   namespace: <mcp_system> *spec:   description: "Data analysis and reporting tools"   tools:   - mcpserver2_time   - mcpserver2_dozen   - mcpserver1_get_stats   prompts:   - test2_data_summary 

*$ oc apply -f <mcpvs_datatools.yaml> *

You registered your MCP servers. 

**You installed the OpenShift CLI (oc). **

**You installed the jq command-line JSON processor. **

**You applied MCPVirtualServer custom resource (CRs) for your virtual servers. **

Procedure 

1. List all of your virtual MCP servers by running the following command: 

The expected output is a list of all of the virtual MCP servers that you created. 

**2. Performs a connectivity and handshake test of your virtual dev_tools MCP server by running the following curl command with the relevant URL and header: **

***Replace <http:example.com:port/mcp> with the target URL and MCP gateway endpoint. ***

Example output 

3. Extract the MCP session ID from response headers by running the following command: 

Verify that the session ID was extracted by running the following command: 

**4. Request the tools from the dev_tools virtual MCP server by running the following command: **

$ oc get mcpvirtualserver -A 

*$ curl -s -D /tmp/mcp_headers -X POST <http:example.com:port/mcp> \ *  -H "Content-Type: application/json" \   -d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "test-client", "version": "1.0.0"}}}' 

{   "jsonrpc": "2.0",   "id": 1,   "result": {     "protocolVersion": "2025-11-25",     "capabilities": {       "tools": {         "listChanged": true       }     },     "serverInfo": {       "name": "Kuadrant MCP Gateway",       "version": "0.0.1"     }   } } 

$ SESSION_ID=$(grep -i "mcp-session-id:" /tmp/mcp_headers | cut -d' ' -f2 | tr -d '\r') 

$ echo "MCP Session ID: $SESSION_ID" 

***Replace <http:example.com:port/mcp> with the target URL and MCP gateway endpoint. ***

***Replace <mcp_system> with the namespace of the MCP gateway. ***

***Replace <dev_tools> with the tool headers that you want to request. ***

**The expected response is a list of only the tools you specified in the dev_tools virtual MCP **server specification. 

**5. Request the tools from the data_tools virtual MCP server by running the following command: **

***Replace <http:example.com:port/mcp> with the target URL and MCP gateway endpoint. ***

***Replace <mcp_system> with the namespace of the MCP gateway. ***

***Replace <data_tools> with the tool headers that you want to request. ***

**The expected response is a list of only the tools you specified in the data_tools virtual MCP **server specification. 

6. Request all available tools from your MCP servers by running the following command: 

***Replace <http:example.com:port/mcp> with the target URL and MCP gateway endpoint. ***

The expected response is a list of all tools from all registered MCP servers. 

**7. Request prompts from the data_tools MCP virtual server by running the following command: **

***Replace <http:example.com:port/mcp> with the target URL and MCP gateway endpoint. ***

***Replace <mcp_system> with the namespace of the MCP gateway. ***

*$ curl -X POST <http:example.com:port/mcp> \ *  -H "Content-Type: application/json" \   -H "mcp-session-id: $SESSION_ID" \ *  -H "X-Mcp-Virtualserver: <mcp_system>/<dev_tools>" \ *  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | jq '.result.tools[].name' 

*$ curl -X POST <http:example.com:port/mcp> \ *  -H "Content-Type: application/json" \   -H "mcp-session-id: $SESSION_ID" \ *  -H "X-Mcp-Virtualserver: <mcp_system>/<data_tools>" \ *  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | jq '.result.tools[].name' 

*$ curl -X POST <http:example.com:port/mcp> \ *  -H "mcp-session-id: $SESSION_ID" \   -H "Content-Type: application/json" \   -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | jq '.result.tools[].name' 

*$ curl -X POST <http:example.com:port/mcp> \ *  -H "Content-Type: application/json" \   -H "mcp-session-id: $SESSION_ID" \ *  -H "X-Mcp-Virtualserver: <mcp_system/data_tools>" \ *  -d '{"jsonrpc": "2.0", "id": 1, "method": "prompts/list"}' | jq '.result.prompts[].name' 

***Replace <data_tools> with the tool headers that you want to request. ***

**The expected response is a list of only those prompts specified in the data_tools virtual **server. 

3.5. DELETE VIRTUAL MCP SERVERS 

You can delete a virtual Model Context Protocol (MCP) server when you no longer need it or when your MCP servers change. 

Prerequisites 

You completed all of the installation and configuration steps for MCP gateway. 

You registered your MCP servers. 

**You installed the OpenShift CLI (oc). **

You created a virtual MCP server. 

Procedure 

Delete a virtual MCP server by running the following command: 

***Replace <dev_tools> with the name of the MCPVirtualServer custom resource you want ***to remove. 

***Replace <mcp_system> with the namespace where the CR is applied. ***

*$ oc delete mcpvirtualserver <dev_tools> -n <mcp_system> *

### CHAPTER 4. USE AUTHENTICATION WITH MCP GATEWAY

**You can configure authentication for MCP gateway by using an AuthPolicy custom resource (CR) with **an identity provider, or any Istio or Gateway API compatible mechanism. 

4.1. UNDERSTAND MCP GATEWAY AUTHENTICATION 

When you enable authentication, the Model Context Protocol (MCP) clients can discover your authorization server and complete the authentication flow. The MCP gateway broker component makes OAuth 2.0 Protected Resource Metadata accessible. 

You can implement the following actions by using authentication: 

Set up the MCP gateway to validate access tokens issued by your identity provider. 

**Return a 401 error message with authorization server discovery information. **

**Expose OAuth configuration at /.well-known/oauth-protected-resource. **

Enable MCP clients to discover and use your identity provider’s client registration. 

**The following example uses a Connectivity Link AuthPolicy with Red Hat build of Keycloak as an identity **provider. The MCP gateway supports any Istio or Gateway API compatible authentication mechanism. 

Additional resources 

MCP Authorization specification 

4.2. CONFIGURE MCP GATEWAY AUTHENTICATION WITH AN AUTHPOLICY 

**Configure authentication for your MCP gateway by using a Connectivity Link AuthPolicy custom **resource (CR) and an identity provider such as Red Hat build of Keycloak. 

NOTE 

The MCP gateway supports Istio or Gateway API compatible authorization and authenticatio mechanisms. Use the best solution for your OpenShift Container Platform clusters. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You configured a Gateway object with an mcp listener. **

You installed and have ready an identity provider supporting OAuth 2.0 or 2.1, for example, Red Hat build of Keycloak. 

Procedure 

**1. Add a listener to the Gateway object for your identity provider by using the following command **as an example: 

***Replace <mcp_gateway> with the name of your MCP gateway instance. ***

***Replace <gateway_system> with the namespace of your Gateway object. ***

***Replace the Red Hat build of Keycloak <name>, <hostname>, and <kubernetes.io/metadata.name> with your identity provider information. ***

2. Configure the MCP gateway broker component to respond with OAuth discovery information by setting the following environment variables: 

***Replace <mcp_gateway> with the name of your MCP gateway instance. ***

***Replace <mcp_system> with the namespace where your MCP gateway instance is ***deployed. 

**OAUTH_RESOURCE_NAME: Human-readable name for the Model Context Protocol **(MCP) server. 

**OAUTH_RESOURCE: Canonical URI of the MCP server that is used for token audience **validation. 

**OAUTH_AUTHORIZATION_SERVERS: Authorization server URL for client discovery. **

*$ oc patch gateway <mcp_gateway> -n <gateway_system> --type json -p '[ *  {     "op": "add",     "path": "/spec/listeners/-",     "value": {       "name": "keycloak",       "hostname": "keycloak.example.com",       "port": 8002,       "protocol": "HTTP",       "allowedRoutes": {         "namespaces": {           "from": "Selector",           "selector": {             "matchLabels": {               "kubernetes.io/metadata.name": "keycloak"             }           }         }       }     }   } ]' 

*$ oc set env deployment/<mcp_gateway> \ *  OAUTH_RESOURCE_NAME="MCP Server" \   OAUTH_RESOURCE="http://mcp.example.com:8001/mcp" \   OAUTH_AUTHORIZATION_SERVERS="http://keycloak.example.com:8002/realms/mcp" \   OAUTH_BEARER_METHODS_SUPPORTED="header" \   OAUTH_SCOPES_SUPPORTED="basic,groups,roles,profile" \ *  -n <mcp_system> *

**OAUTH_BEARER_METHODS_SUPPORTED: Supported bearer token methods. Valid values are usually header, body, or query. **

**OAUTH_SCOPES_SUPPORTED: The OAuth scopes this MCP server supports. **

**3. Create an AuthPolicy CR that validates JWT tokens: **

**Example AuthPolicy CR **

**The metadata.name: parameter value is the name of the AuthPolicy CR. Replace *****<mcp_jwt_auth_policy> as needed. ***

**The metadata.namespace: parameter value is the gateway namespace. Replace *****<gateway_system> with the namespace where you created your Gateway object to apply *****the AuthPolicy CR to the namespace. **

**The spec.targetRef.name: parameter value is the name of your MCP gateway. Replace *****<mcp_gateway> as needed. ***

**The spec.targetRef.sectionName: parameter value is the target gateway listener. In this example, mcp is used. **

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <mcp_jwt_auth_policy>   namespace: <gateway_system> *spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway *    name: <mcp_gateway>     sectionName: <mcp> *  defaults:     when:       - predicate: "!request.path.contains('/.well-known')"     rules:       authentication:         'keycloak':           jwt:             issuerUrl: http://keycloak.example.com:8002/realms/mcp       response:         unauthenticated:           code: 401           headers:             'WWW-Authenticate':               value: Bearer resource_metadata=http://mcp.example.com:8001/.well-known/oauth-protected-resource           body:             value: |               {                 "error": "Unauthorized",                 "message": "Authentication required."               } 

**The spec.defaults.when parameter value in this example allows unauthenticated access to /.well-known endpoints. **

**The spec.defaults.rules.authentication: parameter defines which tokens to validate and **how. In this case, JWT validation validates tokens against the Keycloak OIDC issuer. 

**The spec.defaults.rules.response.unauthenticated.headers.'WWW-Authenticate': parameter points clients to OAuth discovery metadata. Replace the resource_metadata= **information as required. 

**The spec.defaults.rules.response.unauthenticated.body.value: parameter is set with a standard response. This configuration returns a 401 error in an OAuth error format. **

**4. Apply the AuthPolicy CR by running the following command: **

***Replace <mcp_jwt_auth_policy.yaml> with the name of your CR. ***

Verification 

1. Test that the broker now serves OAuth discovery information by checking the protected resource metadata endpoint with the following command: 

Replace the URL with your protected resource information. 

Example output 

2. Test that protected endpoints now require authentication by running the following command: 

***Replace <mcp.example.com:8001/mcp> with your endpoint. ***

*$ oc apply -f <mcp_jwt_auth_policy.yaml> *

*$ curl http://<mcp.example.com:8001>/.well-known/oauth-protected-resource *

{   "resource_name": "MCP Server",   "resource": "http://example.com:8001/mcp",   "authorization_servers": [     "http://keycloak.example.com:8002/realms/mcp"   ],   "bearer_methods_supported": [     "header"   ],   "scopes_supported": [     "basic",     "groups",     "roles",     "profile"   ] } 

*$ curl -v http://<mcp.example.com:8001/mcp> \ *  -H "Content-Type: application/json" \   -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' 

Example output 

**A 401 error with WWW-Authenticate header is expected. **

Next steps 

Control which users can access specific tools by configuring authorization policies. 

Connect authenticated external MCP services. 

{   "error": "Unauthorized",   "message": "Authentication required." } 

### CHAPTER 5. USE AUTHORIZATION WITH MCP GATEWAY

**You can configure authorization for the MCP gateway by using an additional AuthPolicy custom **resource (CR) that adds access control for servers, data, tools, and prompts. 

5.1. UNDERSTAND AUTHORIZATION IN MCP GATEWAY 

Control which authenticated users can access specific Model Context Protocol (MCP) server tools and prompts by setting up authorization in the MCP gateway. The MCP gateway supports authorization approaches including Gateway API policy extensions and other policy engines. 

Authorization evaluation process 

The following steps represent what happens during an authorization evaluation: 

Authentication: A user authenticates and receives a JSON Web Token (JWT) with permissions. 

**Tool request: The client makes an MCP tool call, such as tools/call. **

**Request identity check: An AuthPolicy object verifies the JWT and extracts authorization **claims. 

Authorization check: A Common Expression Language (CEL) expression evaluates the requested tool against the user permissions extracted from the JWT. 

**Access decision: The final step is to allow or deny based on the authorization check result. **

Workflow for setting up authorization evaluation 

To create an authorization evaluation, you must complete the following steps: 

Set up authentication 

Define permissions 

Specify access-control roles 

Red Hat build of Keycloak workflow example 

Take the following steps if using Red Hat build of Keycloak: 

Define your permissions and user claims. Add groups or attributes to the default JWT. 

Define role-based access by using Red Hat build of Keycloak client roles and group bindings for permission decisions. 

Give authorization to certain users to control access to individual MCP tools and prompts. 

Configure your identity provider to include Access Control List (ACL) claims in the tokens it issues. 

Define complex authorization logic using CEL expressions that evaluate the claims and decide whether to let them through. 

5.2. CONFIGURE MCP GATEWAY AUTHORIZATION WITH AN AUTHPOLICY 

**The following example demonstrates using a Connectivity Link AuthPolicy custom resource (CR) with **Common Expression Language (CEL) to implement role-based access control. You can use the following general pattern for applying the authorization specific to your use case. 

NOTE 

The MCP gateway supports Istio or Gateway API compatible authorization and authenticatio mechanisms. Use the best solution for your OpenShift Container Platform clusters. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You configured a Gateway object with an mcp listener and an mcps listener. The mcps listener is required for internal tools/call routing and authorization. **

**You completed authentication procedures, including creating an AuthPolicy CR on the mcp **listener. 

**You configured your identity provider to include group and role claims in JSON Web Tokens **(JWT). 

**The identity provider client IDs match the namespaced MCPServerRegistration CR name in *****the format <namespace>/<mcpserverregistration_name>. ***

Procedure 

**1. Ensure that your identity provider includes the required group and role claims in the issued **JWTs. In the following example, Red Hat build of Keycloak is used: 

Example issued OAuth token claims: 

**The "mcp-ns/arithmetic-mcp-server" specification must match the namespaced name of the MCPServerRegistration CR in the format {namespace}/{name}. For example, if your MCPServerRegistration CR is named arithmetic-mcp-server and is applied in the mcp-ns namespace, the Red Hat build of Keycloak client ID must be mcp-ns/arithmetic-mcp-server. **

{   "resource_access": {     "mcp-ns/arithmetic-mcp-server": {       "roles": ["add", "sum", "multiply", "divide", "prompt:math_tutor"]     },     "mcp-ns/geometry-mcp-server": {       "roles": ["area", "distance", "volume", "prompt:calculate_area"]     }   } } 

**The "roles": ["add", "sum", "multiply", "divide", "prompt:<value>"] parameter and **values specify the roles representing the allowed tools and prompts. 

**2. Configure authorization by creating an AuthPolicy CR that enforces access control on the mcps listener, as shown in the following example: **

IMPORTANT 

**The authorization AuthPolicy CR must target the mcps listener, not the mcp listener. The mcp listener only handles public traffic and has an authenticationonly AuthPolicy CR. **

**Example tool and prompt access control AuthPolicy CR **

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <mcp_tool_auth_policy>   namespace: <gateway_system> *spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway *    name: <mcp_gateway>     sectionName: <mcps> *  rules:     authentication:       'sso-server':         jwt: *          issuerUrl: https://<keycloak.example.com>/realms/mcp *    authorization:       'tool-access-check':         when:           - predicate: "request.headers.exists(h, h == 'x-mcp-toolname')"         patternMatching:           patterns:             - predicate: |                 ('tool:' + request.headers['x-mcp-toolname']) in (has(auth.identity.resource_access) && auth.identity.resource_access.exists(p, p == request.headers['x-mcp-servername']) ? auth.identity.resource_access[request.headers['x-mcp-servername']].roles : [])       'prompt-access-check':         when:           - predicate: "request.headers.exists(h, h == 'x-mcp-promptname')"         patternMatching:           patterns:             - predicate: |                 ('prompt:' + request.headers['x-mcp-promptname']) in (has(auth.identity.resource_access) && auth.identity.resource_access.exists(p, p == request.headers['x-mcp-servername']) ? auth.identity.resource_access[request.headers['x-mcp-servername']].roles : [])     response:       unauthenticated:         headers:           'WWW-Authenticate': *            value: Bearer resource_metadata=http://<mcp.example.com:8001>/.well-*

**Replace metadata.name: with the name of the AuthPolicy. **

**Replace metadata.namespace: with the namespace where the AuthPolicy CR is applied. **

**Replace spec.targetRef.name: with the name of the Gateway CR. **

**The spec.targetRef.sectionName: value must be mcps, which is the internal listener for tool/call authorization. This listener must exist on your Gateway object. **

Authentication: Validates the JWT token using the configured issuer URL. Replace ***<keycloak.example.com> with your identity provider hostname. ***

Authorization Logic: CEL expressions check if the user role allows access to the requested **tool or prompt. The appropriate check is triggered based on the presence of the x-mcp-toolname or x-mcp-promptname header. **

CEL Breakdown: 

**request.headers['x-mcp-toolname']: The name of the requested Model Context **Protocol (MCP) tool. 

**request.headers['x-mcp-servername']: The namespaced name of the MCP server matching the MCPServerRegistration CR. **

**request.headers['x-mcp-promptname']: The name of the requested MCP prompt. **

**auth.identity.resource_access: The JWT claim containing all roles representing each **allowed capability, tool or prompt, that the user can access, grouped by MCP server. 

**Response handling: Custom 401 and 403 responses for unauthenticated and unauthorized **access attempts. 

**3. Apply the AuthPolicy CR by running the following command: **

***Replace <mcp_tool_auth_policy.yaml> with the name of the AuthPolicy YAML filename. ***

**4. Optional. Configure authorization by creating an AuthPolicy CR using an Open Policy Agent **(OPA) rule, as shown in the following example: 

known/oauth-protected-resource         body:           value: |             {               "error": "Unauthorized",               "message": "MCP Access denied: Authentication required."             }       unauthorized:         body:           value: |             {               "error": "Forbidden",               "message": "MCP Access denied: Insufficient permissions."             } 

*$ oc apply -f <mcp_tool_auth_policy.yaml> *

**Example AuthPolicy CR with an OPA rule **

**5. Apply the OPA AuthPolicy CR by running the following command: **

***Replace <mcp_tool_auth_policy.yaml> with the name of the AuthPolicy YAML filename. ***

Verification 

**1. Monitor authorization decisions by checking the AuthPolicy CR status with the following **command: 

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <mcp_tool_auth_policy>   namespace: <gateway_system> *spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway *    name: <mcp_gateway>     sectionName: <mcps> *  rules:     authentication:       'sso-server':         jwt: *          issuerUrl: https://<keycloak.example.com>/realms/mcp *    authorization:       'authorized-capabilities':         opa:           rego: |             allow = true             capabilities = {               "tools": { server: tools | *                server := object.keys(input.auth.identity.resource_access)[] tools := [substring(r, count("tool:"), -1) | r := input.auth.identity.resource_access[server].roles[] *                  startswith(r, "tool:")                 ]               },               "prompts": { server: prompts | *                server := object.keys(input.auth.identity.resource_access)[] prompts := [substring(r, count("prompt:"), -1) | r := input.auth.identity.resource_access[server].roles[] *                  startswith(r, "prompt:")                 ]               }             }           allValues: true *#... *

*$ oc apply -f <mcp_tool_auth_policy.yaml> *

*$ oc get authpolicy <mcp_tool_auth_policy> -n <gateway_system> -o *jsonpath='{.status.conditions[?(@.type=="Enforced")].status}' 

Example output 

2. Check the authorization logs by running the following command: 

True 

$ oc logs -n mcp-system -l app.kubernetes.io/name=mcp-gateway 

### CHAPTER 6. REVOKE MCP SERVER TOOL ACCESS

You can revoke tool access for users and groups. Tool revocation prevents a user or group from calling specific model content protocol (MCP) tools. 

6.1. UNDERSTAND TOOL ACCESS REVOCATION 

Tool revocation uses the authorization setup where tool access is controlled by roles in identity provider JWT tokens. Revoking a tool means removing the corresponding role from a user or group, so their next token no longer grants access. 

TIP 

You cannot revoke a specific in-flight token or revoke access instantly. JWT tokens govern access, and these tokens are valid until they expire. Revocation relies on the token expiring and being reissued with changed permissions. To force faster revocation, reduce the access-token lifespan in your identity provider. 

The following two enforcement points apply: 

**tools/call: The AuthPolicy custom resource (CR) CEL expression checks the x-mcp-toolname header against the user’s resource_access roles. A revoked tool returns a failed to create session for mcp server: failed to create client: transport error: server returned 4xx for initialize POST, likely a legacy SSE server error. **

**tools/list: The broker filters the tools list by using the signed x-mcp-authorized header. A **revoked tool is no longer displayed in the list. 

The timing of tool revocation depends on the following session events: 

New sessions: Users who authenticate after revocation receive a token without the revoked tool. Denial is immediate. 

Existing sessions: Users with an active token keep access until the token expires. You configure token lifetime in your identity provider, for example, the Access Token Lifespan setting in Red Hat build of Keycloak. Shorter token lifetimes mean that tokens are refreshed more often, picking up role changes sooner. You must decide on the balance between revocation latency and token-refresh resource use. 

**In-flight requests: A tools/call request that is already being processed completes normally. The **authorization check occurs before the request reaches the backend MCP server. Only new requests are denied. 

6.2. REVOKE TOOL AND PROMPT CALL REQUESTS 

Use your existing authorization setup to revoke tool and prompt requests for individual users and groups by removing either role from the user or group in your identity provider. 

In this example, Red Hat build of Keycloak is used. Remove the client-role mapping. The client name **corresponds to the namespaced MCPServerRegistration custom resource (CR), such as mcp-test/test-server1. Each role represents a tool name, such as greet, or headers. Use the same process for **prompts. 

Prerequisites 

You installed MCP gateway. 

**You configured a Gateway object. **

**You are logged into a running OpenShift Container Platform cluster with an admin role. **

**You configured an HTTPRoute object for the gateway. **

You registered a Model Context Protocol (MCP) server. 

**You created a Secret CR for authentication. **

**You configured authorization with a tool-level AuthPolicy CR. **

Procedure 

1. Revoke a tool for a group by using the Red Hat build of Keycloak interface: 

**a. Go to Groups > select the group, such as accounting. **

b. Go to Role mapping > remove the tool role from the relevant client. 

2. Revoke a tool for a single user by using the interface: 

a. Go to Users > select the user. 

b. Go to Role mapping > remove the tool role from the relevant client. 

Verification 

After revoking a tool, verify that the user can no longer call it by using MCP Inspector. 

Log out of any existing MCP Inspector session and log back in as the affected user to get a fresh token. 

**Open MCP Inspector and connect to your gateway’s /mcp endpoint. Authenticate through **the OAuth flow. 

Under Tools > List Tools, the revoked tool is displayed. Try calling the revoked tool. The **request should return 500. **

6.3. FILTER REVOKED TOOLS AND PROMPTS FROM DISPLAY 

After you revoke a tool or prompt by using your identity provider, requests are blocked. However, the revoked capability is still displayed in responses. To filter revoked tools and prompts from the displayed list, you must give the Model Context Protocol (MCP) broker component a signed header that carries the user’s authorized capabilities. 

You can remove blocked tools from responses by configuring the Authorino Operator to generate the header by using a wristband JSON web token (JWT) signed with an Elliptic Curve Digital Signature Algorithm (ECDSA) key pair. 

Prerequisites 

You installed MCP gateway. 

**You configured a Gateway object with both mcp and mcps listeners. **

**You are logged into a running OpenShift Container Platform cluster with an admin role. **

**You configured an HTTPRoute object for the gateway. **

You registered an MCP server. 

**You configured authentication with an AuthPolicy CR on the mcp listener. **

**You configured authorization with a tool-level AuthPolicy CR on the mcps listener. **

Procedure 

1. Generate an ECDSA key pair by running the following commands: 

a. Generate the private key and save it to a file by running the following command: 

b. Generate the public key and save it to a file by running the following command: 

**2. Create a Kubernetes Secret object in the Authorino Operator namespace by adding the private **key with the following command: 

***Replace <kuadrant_system> with the namespace where you installed Connectivity Link. ***

**3. Create a Kubernetes Secret object in the MCP broker component namespace by adding the **public key with the following command: 

***Replace <mcp_system> with the namespace where MCP gateway is installed. ***

**4. Delete only the existing AuthPolicy CR on the mcp listener by running the following command: **

***Replace <mcp_authn_policy> with the name of your AuthPolicy CR. ***

***Replace <authn_namespace> with the namespace where your AuthPolicy CR is applied. ***

$ openssl ecparam -name prime256v1 -genkey -noout -out private-key.pem 

$ openssl ec -in private-key.pem -pubout -out public-key.pem 

$ oc create secret generic trusted-headers-private-key \   --from-file=key.pem=private-key.pem \ *  -n <kuadrant_system> \ *  --dry-run=client -o yaml | oc apply -f -

$ oc create secret generic trusted-headers-public-key \   --from-file=key=public-key.pem \ *  -n <mcp_system> \ *  --dry-run=client -o yaml | oc apply -f -

*$ oc delete authpolicy <mcp_authn_policy> -n <authn_namespace> --ignore-not-found *

IMPORTANT 

**You must delete the AuthPolicy CR and create a new one. Using $ oc apply **merges both the new and old policies. 

**5. Generate a new x-mcp-authorized header by creating and applying a new AuthPolicy CR. Use **the following example: 

**Example AuthPolicy CR **

$ oc create -f - <<EOF apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata:   name: _<mcp_auth_policy>_   namespace: _<authn_namespace>_ spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway     name: _<mcp_gateway>_     sectionName: mcp   when:     - predicate: "!request.path.contains('/.well-known')"   rules:     authentication:       'keycloak':         jwt:           issuerUrl: https://keycloak.example.com:port/realms/mcp     authorization:       'allow-mcp-method':         patternMatching:           patterns:           - predicate: |               !request.headers.exists(h, h == 'x-mcp-method') || (request.headers['x-mcp-method'] in ["tools/list","prompts/list","initialize","notifications/initialized"])       'authorized-capabilities':         opa:           rego: |             allow = true             capabilities = {               "tools": { server: tools |                 server := object.keys(input.auth.identity.resource_access)[_]                 tools := [substring(r, count("tool:"), -1) |                   r := input.auth.identity.resource_access[server].roles[_]                   startswith(r, "tool:")                 ]               },               "prompts": { server: prompts |                 server := object.keys(input.auth.identity.resource_access)[_]                 prompts := [substring(r, count("prompt:"), -1) |                   r := input.auth.identity.resource_access[server].roles[_]                   startswith(r, "prompt:")                 ]               } 

***Replace <mcp_auth_policy> with the name of your new AuthPolicy CR. ***

***Replace <authn_namespace> with the namespace where you removed the AuthPolicy CR *****that was on the mcp listener. **

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

6. Configure the MCP broker component to validate the signed header by running the following command: 

***Replace <mcp_gateway_extension> with the name of your MCPGatewayExtension CR. ***

            }           allValues: true     response:       success:         headers:           x-mcp-authorized:             wristband:               issuer: 'authorino'               customClaims:                 'allowed-capabilities':                   selector: auth.authorization.authorized-capabilities.capabilities.@tostr               tokenDuration: 300               signingKeyRefs:                 - name: trusted-headers-private-key                   algorithm: ES256       unauthenticated:         headers:           'WWW-Authenticate':             value: Bearer resource_metadata=https://mcp.example.com:port/.well-known/oauth-protected-resource         body:           value: |             {               "error": "Unauthorized",               "message": "Access denied: Authentication required."             }       unauthorized:         code: 401         headers:           'WWW-Authenticate':             value: Bearer resource_metadata=https://mcp.example.com:port/.well-known/oauth-protected-resource         body:           value: |             {               "error": "Forbidden",               "message": "Access denied: Unsupported method. New authentication required (401)."             } EOF 

*$ oc patch mcpgatewayextension <mcp_gateway_extension> -n <mcp_system> --*type='merge' \   -p='{"spec":{"trustedHeadersKey":{"secretName":"trusted-headers-public-key"}}}' 

***Replace <mcp_system> with the namespace where MCP gateway is installed. ***

7. Wait for the automatic MCP broker component redeployment to load the public key from the **Secret CR created in the earlier step by running the following command: **

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

***Replace <mcp_system> with the namespace where your MCP gateway deployment is ***applied. 

8. If the redeployment does not start, force it by running the following command: 

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

***Replace <mcp_system> with the namespace where your MCP gateway deployment is ***applied. 

Verification 

**1. Verify that the new AuthPolicy CR is enforced by running the following command: **

***Replace <mcp_auth_policy> with the name of your new AuthPolicy CR. ***

***Replace <authn_namespace> with the namespace where your AuthPolicy CR is applied. ***

Example output 

2. Log out and log back in with the user credentials that you changed access for to get a fresh token. 

3. Request all available tools from your MCP servers for the user or group whose access you revoked. The expected response is a list of all tools that the user or group can access from all registered MCP servers. 

*$ oc rollout status deployment/<mcp_gateway> -n <mcp_system> --timeout=60s *

*$ oc rollout restart deployment/<mcp_gateway> -n <mcp_system> *

*$ oc get authpolicy <mcp_auth_policy> -n <authn_namespace> -o *jsonpath='{.status.conditions[?(@.type=="Enforced")].status}' 

True 

### CHAPTER 7. USE CREDENTIALS TO ACCESS EXTERNAL APIS WITH VAULT

You can connect AI agents to tools with the Model Context Protocol (MCP) by integrating HashiCorp Vault (Vault) with the MCP gateway. By using Vault, you can store sensitive credentials such as API keys or long-term Personal Access Tokens (PATs) to access external APIs. 

7.1. VAULT WITH THE MCP GATEWAY 

**You can use HashiCorp Vault (Vault) to both securely store credentials and apply an AuthPolicy custom resource (CR). The AuthPolicy CR retrieves and inject those credentials into your MCP server request **flow. 

The essentials of the workflow include the following elements: 

MCP gateway: Acts as the entry point for AI clients that are accessing backend MCP servers. 

Vault: The source of truth for secrets. 

**AuthPolicy CR: The Connectivity Link resource that defines how to authenticate the user and **retrieve their specific secret from Vault. 

**Authorino: Triggered by AuthPolicy CRs, Authorino is the external authorization service used by **Connectivity Link to validate identities and retrieve external metadata. Authorino adds authorization and authentication to APIs that do not have credential checks built-in. In this **specific Vault workflow, Authorino uses the instructions from the AuthPolicy CR to connect to **Vault by using JSON web token (JWT) authentication. After it connects to Vault, Authorino **retrieves the stored secret, then gives an allow or deny decision for the traffic. **

7.2. SET UP A TRUST RELATIONSHIP BETWEEN VAULT AND AUTHORINO 

**To ensure that the Authorino service can act on an AuthPolicy custom resource (CR), you must set up a **secure, identity-based trust relationship between the Authorino service and your HashiCorp Vault (Vault) database. Your goal is to allow the Authorino service to dynamically retrieve sensitive credentials from Vault. 

NOTE 

In production environments, using a tool such as Terraform or GitOps to manage policies is a best practice. Automation ensures that if a cluster is deleted, then your security policies are automatically recreated. 

Prerequisites 

You completed the installation for MCP gateway. 

**You created a Gateway object. **

You have a Vault database. 

You created a namespace for your MCP server secrets. 

Procedure 

1. Enable JSON-web-token (JWT) authentication in your Vault server by following the instructions in the Vault documentation. 

**2. Create a Vault policy that saves the Access Control List (ACL) that defines the read and list **capabilities for Authorino by running the following command: 

***Replace <"secret/data/mcp_gateway/*\"> with the path to the namespace for your MCP ***server secrets. 

***Replace <vault_service_hostname:port> with the Vault service address. ***

3. Create a Vault role that stores a set of rules for Authorino by running the following command: 

***Replace <vault_service_url:port> with the Vault service address. ***

7.3. CREATE A SINGLE-SERVER-SCOPED AUTHPOLICY CR FOR VAULT 

**Create an AuthPolicy custom resource (CR) to connect an external OIDC Identity Provider (IdP) with HashiCorp Vault (Vault). The AuthPolicy CR enables getting a Vault token on behalf of the user or **service that needs access to the MCP server data. 

**The following example AuthPolicy CR is scoped to a single MCP server. Single-server scoping creates **granular security. For example, you can configure the Authorino service to examine individual secretcontaining paths for each MCP server in your backend. You can also specify customized role-based logic for each MCP server. 

Prerequisites 

**You installed the OpenShift CLI (oc). **

You are logged into an OpenShift Container Platform cluster as an administrator. 

You have a central authorization tool that uses standard protocols such as OpenID Connect or OAuth 2.0. 

$ curl -H "X-Vault-Token: $VAULT_TOKEN" -H 'Content-Type: application/json' -X POST \   --data '{     "policy": "path _<"secret/data/mcp_gateway/*\">_ {\n  capabilities = [\"read\", \"list\"]\n}"   }' \ *  <vault_service_hostname:port>/v1/sys/policies/acl/authorino *

$ curl -H "X-Vault-Token: $VAULT_TOKEN" \   -H 'Content-Type: application/json' \   -X POST \   --data '{     "role_type": "jwt",     "bound_audiences": ["authorino"],     "user_claim": "sub",     "policies": ["authorino"],     "ttl": "1h"   }' \ *  <vault_service_url:port>/v1/auth/jwt/role/authorino-role *

You have an MCP server ready to connect. 

You set up a trust relationship between the Authorino service and HashiCorp Vault. 

Procedure 

**1. Create an AuthPolicy CR targeting a single MCP server by using the following example: **

**Example single MCP server AuthPolicy CR **

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <vault_policy_mcpserver1>   namespace: <mcpserver1> *spec:   targetRef:     group: gateway.networking.k8s.io     kind: HTTPRoute *    name: <mcp_server_route> *  rules:     authentication:       "mcp-clients":         jwt: *          issuerUrl: <issuer_URL> *    metadata:       "oauth-token":         priority: 0         http: *          url: <oauth_token_issuer_endpoint> *          method: POST           credentials:             authorizationHeader:               prefix: Basic           sharedSecretRef:             name: authorino-oauth-client             key: client_secret           bodyParameters:             grant_type:               value: client_credentials             scope:               value: openid         cache:           key:             value: 'singleton'           ttl: 1800       "vault-login":         priority: 1         when:         - predicate: auth.metadata.exists(p, p == "oauth-token") && has(auth.metadata["oauth-token"].access_token)         http:           url: https://vault.vault.svc.cluster.local:8200/v1/auth/jwt/login           method: POST           body:             expression: | 

**See the "Parameter values for a single-server-scoped AuthPolicy CR" reference for **information about user-replaceable values. 

**The authorino-oauth-client Secret must be applied in the namespace of your Connectivity *****Link deployment for the AuthPolicy CR to work. Replace <kuadrant_system> with the ***namespace of your Connectivity Link deployment. 

**2. Apply the AuthPolicy CR by running the following command: **

***Replace <auth_policy_vault.yaml> with the name of your AuthPolicy YAML. ***

              "{\"role\": \"authorino\", \"jwt\": \"" + auth.metadata["oauth-token"].access_token + "\"}"         cache:           key:             value: 'singleton'           ttl: 3600       "vault":         priority: 2         when:         - predicate: auth.metadata.exists(p, p == "vault-login") && has(auth.metadata["vault-login"].auth ) && has(auth.metadata["vault-login"].auth.client_token)         http:           urlExpression: |             "https://vault.vault.svc.cluster.local:8200/v1/secret/data/mcp-gateway/" + auth.identity.sub           method: GET           headers:             "X-Vault-Token":               expression: auth.metadata["vault-login"].auth.client_token     authorization:       "found-vault-secret":         patternMatching:           patterns:           - predicate: |               has(auth.metadata.vault.data) && has(auth.metadata.vault.data.data) && has(auth.metadata.vault.data.data.test_server2_pat) && type(auth.metadata.vault.data.data.test_server2_pat) == string     response:       success:         headers:           "Authorization":             plain:               expression: |                 "Bearer " + auth.metadata.vault.data.data.test_server2_pat ---apiVersion: v1 kind: Secret metadata:   name: authorino-oauth-client *  namespace: <kuadrant_system> *stringData: *  client_secret: <secret_value> *type: Opaque 

*$ oc apply -f <auth_policy_vault.yaml> *

7.3.1. Parameter values for a single-server-scoped AuthPolicy CR 

**When you create an AuthPolicy custom resource (CR) to connect an external OIDC Identity Provider **(IdP) with HashiCorp Vault (Vault), you must use custom values in many fields. Use the following reference information to create your CR. 

Table 7.1. Parameters for a single-server-scoped AuthPolicy CR 

Parameter Definition 

**metadata.name A unique name for this AuthPolicy CR. **

**metadata.namespace **The namespace of your MCP server. 

**spec.targetRef.name The name of the HTTPRoute CR of your MCP server. **

**rules.authentication"mcp-clients".jwt.issuerUrl **

The issuer URL of your OpenId Connect SSO provider. You can also use **.jwksUrl instead of .issuerUrl: for authentication servers that do not **implement OIDC. This is the primary authentication step that validates who the user is. 

**spec.metadata."oauth-token".https.url **

The token endpoint of the OAuth provider used to authenticate to Vault. **Typically, this URL ends with /token. **

**spec.rules.metadata.cach e.ttl **

Time in seconds that Authorino caches the specific metadata source within the rules list. The example value is 30 minutes. This value overrides the **global spec.metadata.cache.ttl. When user permissions from Vault rarely **change, the value is longer. When user quota or usage changes often, you can set a short time or disable it entirely for the specific rule. 

**spec.metadata."vault-login".https.url **

The Vault JWT login endpoint. This value typically ends in **/v1/auth/jwt/login. This step performs the JWT authentication against **Vault. 

**spec.metadata.cache.ttl **Time in seconds that Authorino caches and reuses the metadata after it is returned by the external service, such as OAuth token or Vault client token. The example value is 60 minutes. 

**spec.metadata."vault" **These parameter values specify the secret retrieval from Vault. 

**spec.rules.metadata."vaul t-login".https.urlExpressio n **

Your Vault service name, namespace, and port. Replace as required if TLS is disabled at the vault service, or if the other values do not match your scenario. 

**spec.rules.metadata."vaul t".https.urlExpression **

**Your Vault server URL and secret path. Replace the auth.identity.sub **variable according to how your claims uniquely identify an MCP gateway user if needed. The Vault path in the expression must match the KV Secrets Engine version. 

**spec.rules.authorization." found-vault-secret" **

A safety check to ensure that the Secret has the expected key before **allowing the request. In this example, test_server2_pat is the expected **key. 

**spec.rules.authorization." found-vault-secret".patternMatching.p atterns.- predicate **

**In the example, test_server2_pat is hard-coded as the entry inside of the **Vault secret that contains the user’s PAT to authenticate with the targeted MCP server. If you change the key name in Vault, you must update both the **authorization predicate and the response.headers expression, or the **PAT does not get injected into the header. 

Parameter Definition 

7.3.2. Test your MCP gateway and Vault integration 

You can test your Model Context Protocol (MCP) gateway and HashiCorp Vault (Vault) integration by using the general steps that follow. Tailor your testing for your use case. 

Prerequisites 

**You installed the OpenShift CLI (oc). **

You are logged into an OpenShift Container Platform cluster as an administrator. 

You set up a trust relationship between Authorino and HashiCorp Vault. 

**You created an AuthPolicy custom resource. **

Procedure 

1. Store a secret in Vault by running a command specific to your environment. 

Example curl command to store a vault token 

***Replace <vault_service_url:port>/v1/secret/data/mcp_gateway/<sub> with your secret endpoint. Be sure to either replace <sub> with your specific sub-path or remove the trailing ***forward slash. 

2. Get an access token by running a command specific to your environment. 

Example access token request 

***Replace <issuer_url> with your issuer URL. ***

$ curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H 'Content-Type: application/json' -X POST \   --data '{"data":{"test_server2_pat":"s3cr3t"}}' \ *  <vault_service_url:port>/v1/secret/data/mcp_gateway/<sub> *

*$ ACCESS_TOKEN=$(curl <issuer_url> -s -d 'grant_type=client_credentials' -d 'client_id=<mcp_client_id>' -d 'client_secret=<mcp_client_secret>' -d 'scope=openid profile *groups roles' | jq -r .access_token) 

***Replace <mcp_client_id> with your MCP client ID. ***

***Replace <mcp_client_secret> with your MCP client secret. ***

3. Start a session with the MCP gateway by running a command specific to your environment. 

Example curl command to start a session with the MCP gateway 

***Replace <https://mcp-gateway-mcp-system.apps.onecluster.example.com> with your ***OpenShift Container Platform route URL for the MCP gateway. 

4. Send a request to the MCP server route that requires fetching credentials from Vault by running a command specific to your environment. 

Example output 

**The output shows that the request was successful and that the Authorization header was set with the Secret information retrieved from Vault. **

7.4. USE A VAULT ROOT TOKEN 

You can use a HashiCorp Vault (Vault) root token for a limited time and purpose. Using the Vault root token for the Authorino service to authenticate to Vault gives Authorino full access to read and write any secret stored in Vault. 

Use the root token only in the following scenarios: 

**When you first deploy Vault on OpenShift Container Platform. The Vault Operator init **command generates the initial root token. 

When you need to bootstrap Auth. You can use a root token once to set up your Kubernetes and JWT Auth methods. After the Authorino service and your other services can log in using their own identities, the root token is no longer needed. 

$ curl -N -s -H "Authorization: Bearer $ACCESS_TOKEN" \   -H "Content-Type: application/json" \   -X POST \   -d '{"capabilities": {}}' \ *  <\https://mcp-gateway-mcp-system.apps.onecluster.example.com/v1/mcp/initialize> *

{   "jsonrpc": "2.0",   "id": 1,   "result": {     "content": [       {         "type": "text",         "text": "Authorization: [Bearer s3cr3t]"       },       …     ],     …   } } 

**For disaster recovery. If all other admin-level accounts are locked out or the configuration is **corrupted, you can generate a new root token to fix the system by using recovery keys. 

WARNING 

Using a root token is not intended for production environments. Root tokens are much less secure than using tokens configured with policies. 

Prerequisites 

**You installed the OpenShift CLI (oc). **

You are logged into an OpenShift Container Platform cluster as an administrator. 

You are in a non-production environment. 

You have an MCP server ready to connect. 

You set up a trust relationship between Authorino and HashiCorp Vault. 

Procedure 

**1. Create the Vault root-token AuthPolicy CR by using the following example: **

**Example Vault root-token AuthPolicy CR **

- 

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <vault_root_token_policy>   namespace: <root_token_test> *spec:   targetRef:     group: gateway.networking.k8s.io     kind: HTTPRoute *    name: <mcp_server2_route> *  rules:     authentication:       "mcp-clients":         jwt: *          issuerUrl: <issuer_url_endpoint> *    metadata:       "vault":         http:           urlExpression: |             "http://vault.vault.svc.cluster.local:8200/v1/secret/data/mcp-gateway/" + auth.identity.sub           method: GET           credentials:             customHeader:               name: X-Vault-Token 

**See the "Parameter values for a single-server-scoped AuthPolicy CR" reference for **information about the user-replaceable values used in this root-token policy. 

***Replace <kuadrant_system> in the Secret with the namespace where you deployed ***Connectivity Link. 

**2. Apply the AuthPolicy CR by running the following command: **

***Replace <vault_root_auth_policy.yaml> with the name of your root-level Vault AuthPolicy ***CR. 

7.5. ADDITIONAL RESOURCES 

Vault documentation 

          sharedSecretRef:             name: vault-secret             key: root-token     authorization:       "found-vault-secret":         patternMatching:           patterns:           - predicate: |               has(auth.metadata.vault.data) && has(auth.metadata.vault.data.data) && has(auth.metadata.vault.data.data.test_server2_pat) && type(auth.metadata.vault.data.data.test_server2_pat) == string     response:       success:         headers:           "Authorization":             plain:               expression: |                 "Bearer " + auth.metadata.vault.data.data.test_server2_pat ---apiVersion: v1 kind: Secret metadata:   name: vault-secret *  namespace: <kuadrant_system> *stringData:   root-token: root type: Opaque 

*$ oc apply -f <vault_root_auth_policy.yaml> *