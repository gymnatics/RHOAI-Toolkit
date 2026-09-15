# Red_Hat_Connectivity_Link-1.4-Troubleshoot-en-US.pdf

- Red Hat Connectivity Link 1.4

# Troubleshoot

Troubleshoot common issues 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 Troubleshoot

Troubleshoot common issues

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

This document provides detailed troubleshooting steps for common issues you might encounter.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. TROUBLESHOOT THE MCP GATEWAY 1.1. MCP GATEWAY PODS NOT STARTING 1.2. GATEWAY AND ROUTING TROUBLESHOOTING 

1.2.1. Troubleshoot the gateway listener 1.2.2. Troubleshoot traffic not reaching the backend MCP server 1.2.3. Troubleshoot requests failing or bypassing the router 

1.3. TROUBLESHOOT AN MCPGATEWAYEXTENSION STATUS OF NOT READY 1.4. TROUBLESHOOT ON-PREMISE MCP SERVER REGISTRATION ISSUES 

1.4.1. Troubleshoot on-premise MCP server tools not displaying 1.4.2. Troubleshoot on-premise MCP server tools without prefixes 1.4.3. Restart the MCP gateway broker component 

1.5. TROUBLESHOOT EXTERNAL MCP SERVER CONNECTIVITY ISSUES 1.6. TROUBLESHOOT EXTERNAL MCP SERVER AUTHENTICATION ISSUES 1.7. TROUBLESHOOT MCP GATEWAY AUTHENTICATION ISSUES 

1.7.1. Troubleshoot MCP gateway empty 401 errors 1.7.2. Troubleshoot MCP gateway valid tokens rejected 

1.8. TROUBLESHOOT MCP GATEWAY AUTHORIZATION ISSUES 1.8.1. Troubleshoot MCP gateway CEL issues 1.8.2. Check the Kuadrant Operator status 

3 3 4 4 6 7 

10 11 

13 15 16 16 18 19 21 22 23 24 25 

### CHAPTER 1. TROUBLESHOOT THE MCP GATEWAY

You can troubleshoot common issues with solutions when working with the MCP gateway across installation, configuration, and operation. 

1.1. MCP GATEWAY PODS NOT STARTING 

After installation, if your MCP gateway pods are stuck in one of several states that indicate that they are not starting as expected, you can take several steps to diagnose the problem. 

Common causes include the following states and indicate an associated action: 

**ImagePullBackOff: Check image repository access and credentials. **

**CrashLoopBackOff: Check the logs for application errors. **

**Pending: Check resource availability and node capacity. **

**Init Container Failure: Check RBAC permissions. **

Prerequisites 

You installed MCP gateway. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

Procedure 

1. Check the pod status by running the following command: 

***Replace <mcp_system> with the name of the MCP gateway deployment that you are checking. ***

2. Describe problem pods by running the following command: 

***Replace <mcp_system> with the name of the MCP gateway deployment that you are ***checking. 

***Replace <pod_name> with the name of the pod that you are checking. ***

3. Check the pod logs by running the following command: 

***Replace <mcp_system> with the name of the MCP gateway deployment that you are ***checking. 

*$ oc get pods -n <mcp_system> *

*$ oc describe pod -n <mcp_system> <pod_name> *

*$ oc logs -n <mcp_system> <pod_name> *

***Replace <pod_name> with the name of the pod that you are checking. ***

1.2. GATEWAY AND ROUTING TROUBLESHOOTING 

When traffic is not flowing after you installed MCP gateway, you can investigate each component of the gateway routing to check system health. Depending on the errors you are receiving, you can troubleshoot at several layers. Breaks can occur at the gateway, route, or policy levels. 

**If you have a Connection Refused/Timeout error and your client cannot reach the IP address, the cause **might be the listener. In this case, one of the following situations likely applies: 

The port is not open. 

The load balancer has not assigned an IP address. 

The TLS handshake is failing. 

When you have this type of error, check the listener first. 

**If you can connect to the Gateway object, but you get an HTTP error, such as 404, the cause can be a problem with the HTTPRoute custom resource (CR). The route exists, but the Gateway object has rejected it or the connection has failed. When you get these types of codes, check the HTTPRoute CR **first. 

**If requests either fail with a 503 error or bypass the router, this means that the route is recognized, but **the connection to the backend failed or was not authorized properly. In this case, start with API-level checks and narrow your investigation to Envoy filters as needed. 

**If the EnvoyFilter CR is not present, it usually means one of the following situations has occurred: **

**The Gateway CR status is not Programmed. **

**There is a labels mismatch, and the EnvoyFilter CR is not injected into the pods. **

The MCP controller component is crashing or stuck. 

1.2.1. Troubleshoot the gateway listener 

**If your MCP gateway cannot reach an MCP endpoint at the configured hostname, the Listener custom **resource (CR) you configured might not be working. You can troubleshoot this situation by using a few commands and some insight. 

**Use the following concepts with the commands that follow to solve a non-functioning Listener CR: **

**Ensure that your Gateway object has Accepted and Programmed conditions set to True. **

**Verify that the hostname parameter value in the Listener CR matches your DNS or hosts **configuration. 

Prerequisites 

You installed MCP gateway. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

Procedure 

**1. Check the general Gateway object configuration by running the following command: **

**This command returns general information about all Gateway objects in the cluster. If the Gateway object you are troubleshooting exists, the command returns the following information: **

**The gatewayClassName is it using, whether or not it has an IP address or hostname **assigned 

**The status, such as Ready, Programmed, or Pending **

**2. Check the full metadata and status history for a specific Gateway object that is stuck in Pending by running the following command: **

***Replace <gateway_name> with the name of the Gateway object. ***

***Replace <gateway_system> with the namespace where the Gateway object is applied. ***

**3. Check for port conflicts and verify that the SSL/TLS certificates are correctly attached to Listener CRs. **

**4. Verify the Listener CR configuration by running the following command: **

***Replace <gateway_name> with the name of the Gateway object. ***

***Replace <gateway_system> with the namespace where the Gateway object is applied. ***

**5. Check all of your Listener CR configurations at the same time by running the following **command: 

***Replace <gateway_name> with the name of the Gateway object. ***

***Replace <gateway_system> with the namespace where the Gateway object is applied. ***

6. Check that the Istio gateway pod is running by using the following command: 

***Replace <gateway_system> with the name of your Gateway object deployment. ***

$ oc get gateway -A 

*$ oc describe gateway <gateway_name> -n <gateway_system> *

*$ oc get gateway <gateway_name> -n <gateway_system> -o yaml | grep -A 10 listeners *

*$ oc get gateway <gateway_name> -n <gateway_system> -o jsonpath='{range *.spec.listeners[*]}{.name}{"\t"}{.hostname}{"\t"}{.port}{"\n"}{end}' 

*$ oc get pods -n <gateway_system> -l gateway.istio.io/managed=istio.io-gateway-controller *

This command checks the status of Envoy-proxy pods and returns pod, traffic flow, and policy errors. 

7. Verify that the port you are trying to use is not already in use by running the following command: 

1.2.2. Troubleshoot traffic not reaching the backend MCP server 

**When you are certain that an HTTPRoute custom resource (CR) exists for your application, but traffic is **not reaching your backend MCP servers, you can take several steps to troubleshoot the problem. 

**On the client side, errors such as 401, 403, and 404 can indicate this situation. **

Prerequisites 

You installed MCP gateway. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

You registered an MCP server. 

Procedure 

**1. Check the HTTPRoute general custom resource (CR) status by running the following **command: 

**This command returns general information about all HTTPRoute objects in the cluster. **

**2. Check for the Accepted condition in the HTTPRoute CR status fields. **

**3. Check the full metadata and status history for one specific HTTPRoute object by running the **following command: 

***Replace <route_name> with the name of the HTTPRoute object. ***

***Replace <namespace> with the namespace where the HTTPRoute object is applied. ***

**4. Verify that the hostnames value in the HTTPRoute CR matches the gateway Listener CR hostname. **

**5. If the HTTPRoute status shows Accepted: False, then the Gateway object is not using the **route. 

**6. If the condition is ResolvedRefs: False:, the route is accepted through the Gateway object, **but it cannot find the backend MCP service. There might be either a mismatch in the CR 

$ oc get gateway -A -o yaml | grep "port:" 

$ oc get httproute -A 

*$ oc describe httproute <route_name> -n <namespace> *

**metadata.name: field, or the MCP service is in a namespace the Gateway object cannot **access. 

7. Verify the parent reference by running the following command: 

***Replace <route_name> with the name of the HTTPRoute object. ***

***Replace <namespace> with the namespace where the HTTPRoute object is applied. ***

**8. Ensure that the retrieved parentRefs value matches your Gateway CR name and namespace **exactly. 

**9. Check that the allowedRoutes.namespaces value in the Gateway CR allows the HTTPRoute **namespace by running the following command: 

***Replace <gateway_name> with the name of the Gateway object. ***

***Replace <gateway_namespace> with the namespace where the Gateway object is ***applied. 

1.2.3. Troubleshoot requests failing or bypassing the router 

**When you are certain that an MCPGatewayExtension custom resource (CR) exists for your MCP server, but requests either fail or bypass the router, it might mean that the EnvoyFilter CR is not **applied properly. You can take several steps to troubleshoot the problem. 

**The EnvoyFilter CR is automatically created in the Gateway CR namespace by the MCP gateway controller component when an MCPGatewayExtension CR is Ready. **

IMPORTANT 

**You can look closely at the EnvoyFilter CR during deep troubleshooting, but do not **manually edit or delete the CR. 

Prerequisites 

You installed MCP gateway. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

You registered an MCP server. 

Procedure 

*$ oc get httproute <route_name> -n <namespace> -o yaml | grep -A 5 parentRefs *

*$ oc get gateway <gateway_name> -n <gateway_namespace> -o jsonpath='{range *.spec.listeners[*]}{.name}{": "}{.allowedRoutes.namespaces.from}{"\n"}{end}' 

**1. Ensure that the Gateway object exists and is in the expected namespace by checking the general Gateway object configuration by running the following command: **

**This command returns general information about all Gateway objects in the cluster. If the Gateway object you are troubleshooting exists, the command returns the gatewayClassName is it using, whether or not it has an IP address or hostname assigned, and a status, such as Ready, Programmed, or Pending. **

**2. Verify that the MCPGatewayExtension CR is Ready by running the following command: **

**3. Verify that a ReferenceGrant CR exists if the MCPGatewayExtension CR is in a different namespace than the Gateway object by running the following command: **

***Replace <referencegrant_name> with the names of the ReferenceGrant CR. ***

***Replace <gateway_system> with the namespace where the Gateway object is applied. ***

**4. Check the HTTPRoute CR by running the following command: **

***Replace <httproute_namespace> with the namespace where the HTTPRoute CR is ***applied. 

***Replace <httproute_name> with the names of the HTTPRoute CR. ***

**If the HTTPRoute CR is not Accepted by the Gateway object, the route is not programmed into Envoy, causing a 404. **

**The conditions Status.Parents.Conditions: Accepted: True and Programmed: True show **that the route is correct. 

**5. If any of the CRs you just checked are not Ready, check the controller logs for EnvoyFilter **creation errors by running the following command: 

***Replace <mcp_system> with the name of your MCP gateway deployment. ***

This step verifies that the MCP controller is successfully generating the underlying Istio configurations. 

**6. Check that the EnvoyFilter exists in the Gateway namespace by running the following **command: 

$ oc get gateway -A 

$ oc get mcpgatewayextension -A 

*$ oc get referencegrant <referencegrant_name> -n <gateway_system> -o yaml *

*$ oc describe httproute <httproute_name> -n <httproute_namespace> *

*$ oc logs -n <mcp_system> deployment/mcp-gateway-controller *

*$ oc get envoyfilter -n <gateway_namespace> -l app.kubernetes.io/managed-by=mcp-*gateway-controller 

***Replace <gateway_namespace> with the namespace where the Gateway object is ***applied. 

**7. Verify the EnvoyFilter configuration by running the following command: **

***Replace <gateway_namespace> with the namespace where the Gateway object is ***applied. 

**The workloadSelector labels must match your Gateway pods, or your policies are **bypassed. 

**8. Compare the EnvoyFilter labels against your pod labels by running the following command: **

***Replace <gateway_namespace> with the namespace where the Gateway object is ***applied. 

**9. Identify the port that the Gateway object is configured to use by running the following **command: 

***Replace <gateway_name> with the name of the Gateway object. ***

***Replace <gateway_namespace> with the namespace where the Gateway object is ***applied. 

**10. Use the following commands to verify the EnvoyFilter chain binding: **

a. Create a secure tunnel between a port on your computer and a port on the pod by running the following command: 

***Replace <gateway_deployment_name> with the name of the Deployment related to the Gateway object. Typically this value is either <<gateway_name>-istio or <gateway_name>-openshift-default, depending on the ingress you used. ***

***Replace <gateway_system> with the namespace where the Gateway object is applied. ***

i. From a different terminal window, access localhost:15000 by running the following command: 

**If this command returns empty, the EnvoyFilter CR is not active on this pod. Traffic is **bypassing your policies. 

11. Restart the Istio gateway to force a configuration reload by running the following command: 

*$ oc describe envoyfilter -n <gateway_namespace> -l app.kubernetes.io/managed-by=mcp-*gateway-controller 

*$ oc get pods -n <gateway_namespace> --show-labels *

*$ oc get gateway <gateway_name> -n <gateway_namespace> -o jsonpath='{range *.spec.listeners[*]}{.name}{": "}{.port}{"\n"}{end}' 

*$ oc port-forward deploy/<gateway_deployment_name> -n <gateway_system> *15000:15000 

$ curl -s localhost:15000/listeners 

***Replace <gateway_namespace> with the namespace where the Gateway object is ***applied. 

***Replace <gateway_name> with the names of the Gateway object. ***

1.3. TROUBLESHOOT AN MCPGATEWAYEXTENSION STATUS OF NOT READY 

**You can troubleshoot when your MCPGatewayExtension custom resource (CR) shows a Ready: False **state by running a few commands. 

Common causes include the following errors and indicate an associated action: 

**InvalidMCPGatewayExtension: This often means that the targetRef points to a Gateway object that does not exist, or you have a typing error in the kind or group. **

**ReferenceGrantRequired: This occurs if your extension is in one namespace but is trying to target a Gateway object in another. To fix this, you must apply a ReferenceGrant in the Gateway object namespace. **

**Conflict: Only one MCPGatewayExtension can target a specific Gateway object. If another extension is already pointing to the Gateway object you configured with a new extension, the **new one fails. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

**You installed the OpenShift CLI (oc). **

You registered an MCP server. 

Procedure 

**1. Check the status of the specific MCPGatewayExtension CR by running the following **command: 

***Replace <namespace> with the namespace where your MCPGatewayExtension CR is applied. ***

**2. Check for conflicting MCPGatewayExtension CRs by running the following command: **

*$ oc rollout restart deployment/<gateway_name>-istio -n <gateway_namespace> *

*$ oc get mcpgatewayextension -n <namespace> *

$ oc get mcpgatewayextension -A 

There must be only one extension per namespace. 

3. Verify that the target Gateway object exists by running the following command: 

***Replace <gateway_namespace> with the namespace where your Gateway object is applied. ***

**4. Check the MCPServerRegistration CR namespace and route status by running the following **command: 

***Replace <mcpsr_name> with the name of your MCPServerRegistration CR. ***

***Replace <mcpsr_namespace> with the namespace where your MCPServerRegistration ***CR is applied. 

**5. Ensure that the MCPGatewayExtension CR targets the Gateway object that the HTTPRoute **CR is attached to. 

1.4. TROUBLESHOOT ON-PREMISE MCP SERVER REGISTRATION ISSUES 

When your on-premise MCP server is not discovered by your MCP gateway after you registered the server, or if you are having trouble with your tools, you can troubleshoot by checking for common problems. Basic steps include making sure that your backend server is available, that routing is applied correctly, and that tool prefix headers are labeled correctly. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

**You installed the OpenShift CLI (oc). **

You registered an MCP server. 

Procedure 

**1. If tools from your on-premise MCP server do not display in tools/list, check that the MCP server **is properly discovered by MCP gateway components by running the following commands: 

**List your MCPServerRegistration CRs by running the following command: **

**Get the detailed status and configuration of the MCPServerRegistration CR that has **missing tools by running the following command: 

*$ oc get gateway -n <gateway_namespace> *

*$ oc describe mcpsr <mcpsr_name> -n <mcpsr_namespace> *

$ oc get mcpsr -A 

***Replace <mcpsr_name> with the name of your MCP server. ***

***Replace <mcpsr_namespace> with the namespace where your *****MCPServerRegistration CR is applied. **

**2. Verify that the MCPServerRegistration CR targetRef points to correct HTTPRoute name and **namespace by running the following commands: 

**a. Get the name and namespace of the HTTPRoute CR that the MCPServerRegistration **CR is attempting to attach to by running the following command: 

***Replace <mcpsr_name> with the name of your MCP server. ***

***Replace <mcpsr_namespace> with the namespace where your *****MCPServerRegistration CR is applied. **

**b. If the MCPServerRegistration CR targets the HTTPRoute CR that is applied in the same namespace, the .spec.targetRef.namespace is not needed. No output is displayed. **

**c. Cross-reference the HTTPRoute details from of the previous command with your HTTPRoute CRs by verifying that a route actually exists with those exact details by running **the following command: 

***Replace <httproute_name> with the value from the output of the earlier step. ***

***Replace <httproute_namespace> with the value from the output of the earlier step. ***

**d. If you get a NotFound server Error from the earlier step, correct your MCPServerRegistration CR. **

3. Verify that the MCP gateway controller component successfully bound the **MCPGatewayExtension and HTTPRoute CR together by checking the status with the **following command: 

***Replace <mcpsr_name> with the name of your MCP server. ***

***Replace <mcpsr_namespace> with the namespace where your MCPServerRegistration ***CR is applied. 

**a. If you get a status: False output, the MCP gateway controller component found the route but could not use it. Check that you created a ReferenceGrant CR if the MCPGatewayExtension and HTTPRoute CRs are in different namespaces. **

4. Check that the backend MCP server is running by entering the following command: 

*$ oc describe mcpserverregistration <mcpsr_name> -n <mcpsr_namespace> *

*$ oc get mcpserverregistration <mcpsr_name> -n <mcpsr_namespace> -o *jsonpath='{.spec.targetRef.name}{"\n"}{.spec.targetRef.namespace}{"\n"}' 

*$ oc get httproute <httproute_name> -n <httproute_namespace> *

*$ oc get mcpserverregistration <mcpsr_name> -n <mcpsr_namespace> -o *jsonpath='{.status.conditions[?(@.type=="Accepted")]}' 

***Replace <mcpsr_namespace> with the namespace where your MCPServerRegistration CR is ***applied. 

5. If your MCP server pods are crashing, check for the following conditions: 

**CrashLoopBackOff: This generally means that your MCP server is starting but then **crashing. This problem can be caused by a missing environment variable or by permission issues. 

**Pending: This might mean that the pod has not started because of a resource issue in the **cluster. 

**ErrImagePull: Either the cluster cannot reach the registry, or you do not have permission to **pull the image. Check your OpenShift Container Platform settings and network configuration. 

**If your pod has a Running status with a high restart count, your MCP server might be **unstable because of memory constraints or connectivity issues. Check your OpenShift Container Platform settings and network configuration. 

**6. Verify that the targeted application of your MCPServerRegistration CR actually exists and has **a valid entry point by running the following command: 

***Replace <namespace> with the namespace where your application runs. ***

***Replace <service_name> with the name of your application. ***

**7. Check that your application has a standard ClusterIP assigned to handle load balancing across **pods. 

**8. Compare the ports to your MCPServerRegistration CR to make sure that they match and that either the TCP or SCTP protocol is used. **

**9. Check that the selectors on the Service CR for your application match the labels on your pods **by running the following command: 

***Replace <service_name> with the name of your application. ***

***Replace <namespace> with the namespace where your application runs. ***

**10. Check that the attached HTTPRoute CR has valid backend reference by running the following **command: 

1.4.1. Troubleshoot on-premise MCP server tools not displaying 

*$ oc get pods -n <mcpsr_namespace> *

*$ oc get svc -n <namespace> <service_name> *

*$ oc get endpoints <service_name> -n <namespace> *

*$ oc describe httproute <route_name> *

**When you have confirmed that your MCPServerRegistration CR is active, but your tools are not **displaying, you can take some diagnostics steps to find the problem. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

**You installed the OpenShift CLI (oc). **

You registered an MCP server. 

Procedure 

1. Check the MCP broker component router logs for errors by running the following command: 

***Replace <mcp_system> with the namespace of your MCP gateway deployment. ***

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

**2. If you see errors, check for typos in the targetRef parameter value and ensure that you are pointing to an existing Service CR. **

**3. Verify that the backend MCP server is implementing the tools/list method correctly. Using the **MCP Inspector is the easiest way to check. 

4. Check your backend MCP server logs for errors. 

5. Ensure that your backend MCP server is returning valid MCP protocol responses. Using the MCP Conformance Test Framework is the easiest way to catch protocol errors. 

**6. Verify that the prefix entry in the MCPServerRegistration CR is valid, meaning that there are **no spaces or special characters. 

7. Start a debug session based on your existing MCP server deployment to initiate a backend server test by running the following command: 

***Replace <mcpsr_name> with the name of your MCP server. ***

8. Test whether your backend MCP server is functional by running the following command: 

If the command returns a list of tools, your backend is healthy. 

*$ oc logs -n <mcp_system> -l app.kubernetes.io/name=<mcp_gateway> *

*$ oc debug deployment/<mcpsr_name> -it *

sh-4.4# curl -X POST https://localhost:<port>/mcp \   -H "Content-Type: application/json" \   -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' 

**9. If your backend is healthy but tools are missing in the Gateway CR, your MCPServerRegistration CR is not correctly mapping the service. Check the logs to see why **the backend rejected the request by running the following command: 

***Replace <mcp_server_label> with the application defined in the metadata.labels.app: section *****of your MCP server Pod or Deployment CR. **

1.4.2. Troubleshoot on-premise MCP server tools without prefixes 

When your MCP server tools are displayed without configured prefixes, you can troubleshoot by checking for common problems. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

**You installed the OpenShift CLI (oc). **

You registered an MCP server. 

Procedure 

**1. Check the MCPServerRegistration custom resource (CR) by running the following command: **

***Replace <mcpsr_name> with the name of your MCP server. ***

***Replace <mcpsr_namespace> with the namespace where your MCPServerRegistration ***CR is applied. 

**2. Verify that the prefix entry in the MCPServerRegistration CR is valid, meaning that there are **no spaces or special characters. 

3. Check the MCP gateway controller component logs for problems with your **MCPServerRegistration CR by running the following command: **

***Replace <mcp_system> with the namespace of your MCP gateway deployment. ***

**a. If you see failed to generate prefix, then there is an error in your MCPServerRegistration CR metadata or there is a conflict. **

b. If there is no output at all, then either the controller is not detecting your **MCPServerRegistration CR, or the request is failing before it gets to the routing stage. **

*$ oc logs -l app=<mcp_server_label> *

*$ oc get mcpsr <mcpsr_name> -n <mcpsr_namespace> -o yaml | grep prefix *

*$ oc logs -n <mcp_system> deployment/mcp-gateway-controller | grep prefix *

1.4.3. Restart the MCP gateway broker component 

While you are troubleshooting your on-premise MCP server, you might make changes to your **MCPServerRegistration custom resource (CR). To ensure that your changes are applied, you must **restart the MCP gateway broker component. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

**You installed the OpenShift CLI (oc). **

You registered an MCP server. 

Procedure 

**Restart the MCP gateway broker component after making MCPServerRegistration CR **changes by running the following command: 

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

***Replace <mcp_system> with the namespace of your MCP gateway deployment. ***

1.5. TROUBLESHOOT EXTERNAL MCP SERVER CONNECTIVITY ISSUES 

If your external MCP server cannot connect, or if tools are not displaying, you can troubleshoot by checking custom resources (CRs) and network settings. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

You registered an external MCP server. 

**You created a Secret CR for authentication. **

Procedure 

*$ oc rollout restart deployment/<mcp_gateway> -n <mcp_system> *

**1. If you are seeing errors such as 502 Bad Gateway and 403 Forbidden, check the ServiceEntry **CR by running the following command: 

***Replace with the <namespace> where the ServiceEntry CR is applied. ***

**a. If the command returns an empty list, create a ServiceEntry CR to allow egress. **

2. For detailed troubleshooting, such as to checks ports and the TLS setting, examine the **ServiceEntry CR activity by running the following command: **

***Replace with the <se_name> with the name the ServiceEntry CR. ***

***Replace with the <namespace> where the ServiceEntry CR is applied. ***

**3. Verify that ServiceEntry CR hosts values are exact matches external hostname values. **

**4. If you are seeing TLS errors, verify that a DestinationRule CR exists by running the following **command: 

***Replace with the <namespace> where the DestinationRule CR is applied. ***

**a. If the previous command returns No resources found in <namespace> namespace, create a DestinationRule CR. **

**b. Ensure that DestinationRule CR host values exactly match ServiceEntry CR host values. **

**c. Check the TLS configuration in DestinationRule CR. **

5. For detailed troubleshooting of actual connection details, such as encryption, load balancing, **and connection pooling, examine the DestinationRule CR by running the following command: **

***Replace with the <dr_name> with the name the DestinationRule CR. ***

***Replace with the <namespace> where the DestinationRule CR is applied. ***

a. Ensure that your network egress policies allow external traffic from the pod. 

6. Test the DNS resolution by running the following command: 

***Replace <image_path/name> with the path to your application image. ***

***Replace <external_hostname> with your external MCP server hostname parameter value. ***

7. Test the external connectivity by running the following command: 

*$ oc get serviceentry -n <namespace> *

*$ oc describe serviceentry <se_name> -n <namespace> *

*$ oc get destinationrule -n <namespace> *

*$ oc describe destinationrule <dr_name> -n <namespace> *

*$ oc run -it --rm debug --image=<image_path/name> --restart=Never -- \   nslookup <external_hostname> *

***Replace <image_path/name> with the path to your application image. ***

***Replace <external_hostname_url> with your external MCP server URL. ***

**8. Verify that the HTTPRoute CR backendRef value is configured with the correct external **hostname. 

**9. Ensure that the HTTPRoute CR has the URLRewrite filter applied to rewrite to the external **hostname. 

1.6. TROUBLESHOOT EXTERNAL MCP SERVER AUTHENTICATION ISSUES 

**If your registered external MCP server fails authentication and returns 401 or 403 errors, troubleshoot **by checking the credentials and the logs. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

You registered an external MCP server. 

**You created a Secret CR for authentication. **

Procedure 

**1. Check that a Secret custom resource (CR) exists and that it has the correct label by running the **following command: 

***Replace <secret_name> with the name of your Secret CR. ***

***Replace <namespace> with the namespace where your Secret CR is applied. ***

**2. Verify the Secret CR contents by running the following command: **

***Replace <secret_name> with the name of your Secret CR. ***

***Replace <namespace> with the namespace where your Secret CR is applied. ***

*$ oc run -it --rm debug --image=<image_path/name> --restart=Never -- \   curl -v https://<external_hostname_url> *

*$ oc get secret <secret_name> -n <namespace> --show-labels *

*$ oc get secret <secret_name> -n <namespace> -o yaml *

**3. Check the MCPServerRegistration CR credentialRef parameter value by running the following **command: 

***Replace <mcpsr_name> with the name of your MCPServerRegistration CR. ***

***Replace <namespace> with the namespace where your MCPServerRegistration CR is ***applied. 

**4. Ensure that the Secret CR has the label mcp.kuadrant.io/secret: "true". **

**5. Verify that the Secret CR data key matches the credentialRef.key in the MCPServerRegistration CR. **

6. Check the credential format. 

7. Verify that the credential you are using has the necessary permissions for the external service. 

8. Check the MCP gateway broker component logs for credential errors by running the following command: 

***Replace <mcp_system> with the name of your MCP gateway deployment. ***

1.7. TROUBLESHOOT MCP GATEWAY AUTHENTICATION ISSUES 

Authentication errors can happen in a variety of ways, including silent failures, broken sessions, and toolaccess denials, depending on your backend MCP server setup. You can troubleshoot common problems by checking your connections and custom resource (CR) configurations. 

When your clients cannot discover OAuth configuration, discovery is not working. Use the following steps to troubleshoot this situation. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

You registered an MCP server. 

**You created a Secret CR for authentication. **

Procedure 

1. Retrieve the JSON object that lists the security requirements for your backend MCP server by running the following command: 

*$ oc get mcpsr <mcpsr_name> -n <namespace> -o yaml | grep -A 3 credentialRef *

*$ oc logs -n <mcp_system> deployment/mcp-gateway | grep -i auth *

***Replace <mcp_hostname> with the name of the host for your MCP server. ***

Example output 

**2. Check that your associated HTTPRoute CR includes a path for /.well-known/oauth-protected-resource by running the following command: **

***Replace <route_name> with the associated HTTPRoute CR. ***

***Replace <mcp_system> with the name of your MCP gateway deployment. ***

**3. If there is no output, your HTTPRoute CR does not have a path for /.well-known/oauth-protected-resource. You must add one. **

**4. Check the specific AuthPolicy CR configuration by running the following command: **

***Replace <authn_name> with the name of your AuthPolicy CR. ***

***Replace <namespace> with the namespace where your AuthPolicy CR is applied. ***

**5. Check that you excluded all /.well-known/ paths from your AuthPolicy CR by trying to reach **the endpoint without any credentials by using the following command: 

***Replace <mcp_hostname> with the name of the host for your MCP server. ***

*$ curl https://<mcp_hostname>/.well-known/oauth-protected-resource *

{   "resource_name": "MCP Server",   "resource": "https://mcp.example.com/mcp",   "authorization_servers": [     "https://auth.provider.com/realms/mcp"   ],   "bearer_methods_supported": ["header"],   "scopes_supported": [     "basic",     "groups",     "roles",     "profile"   ] } 

*$ oc get httproute <route_name> -n <mcp_system> -o json | jq -r *'.spec.rules[].matches[].path.value | select(. == "/.well-known/oauth-protected-resource")' 

*$ oc describe authpolicy <authn_name> -n <namespace> *

*$ curl -o /dev/null -s -w "%{https_code}\n" https://<mcp_hostname>/.well-known/oauth-*protected-resource 

NOTE 

The following codes are examples of possible outputs: 

**200: Means that the exclusion exists and matches. **

**401: Means that your AuthPolicy CR is still demanding a token for this path. **The exclusion is either not present or not working. 

**404: The exclusion might be present and working, but the HTTPRoute CR **does not point to that path or to a valid backend. 

6. Optional. Check all MCP broker component environment variables by running the following command: 

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

***Replace <mcp_system> with the namespace where your MCP gateway deployment is ***applied. 

7. Verify that the MCP broker component pod restarted after any environment variable changes. 

1.7.1. Troubleshoot MCP gateway empty 401 errors 

**When your 401 Unauthorized responses do not include OAuth discovery information, the WWW-Authenticate header is missing. This usually means that your AuthPolicy CR is not properly configured. **Use the following steps to troubleshoot this situation. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

You registered an MCP server. 

**You created a Secret CR for authentication. **

Procedure 

1. Isolate the failure point by using verbose output which lists the TLS handshake, the HTTP headers, and the server response code by running the following command: 

*$ oc get deployment <mcp_gateway> -n <mcp_system> -o yaml | grep -A 10 env *

*$ curl -v https://<mcp_hostname>/mcp \ *  -H "Content-Type: application/json" \   -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' 

***Replace <mcp_hostname> with the hostname for your backend MCP server. ***

**2. Verify that your AuthPolicy CR spec.response.unauthenticated.headers: list includes response.unauthenticated.headers.WWW-Authenticate. **

**3. Check that your AuthPolicy CR response.unauthenticated.headers.WWW-Authenticate.value includes the correct metadata. **

**4. Ensure that your AuthPolicy CR is applied to the correct Gateway object and listener. **

1.7.2. Troubleshoot MCP gateway valid tokens rejected 

**When your valid tokens are rejected with 401 errors, that means your JWT token validation has failed. **Use the following steps to troubleshoot this situation. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

You registered an MCP server. 

**You created a Secret CR for authentication. **

Procedure 

**1. List the AuthPolicy CRs by running the following command: **

**2. Check the specific AuthPolicy CR configuration by running the following command: **

***Replace <authn_name> with the name of your AuthPolicy CR. ***

***Replace <namespace> with the namespace where your AuthPolicy CR is applied. ***

**3. Verify that the issuerUrl in the AuthPolicy CR matches your identity provider’s realm. **

4. Check the Authorino Operator logs by running the following command: 

***Replace <kuadrant_system> with the namespace where Connectivity Link is installed. ***

5. Decode JWT to verify claims by running the following command: 

$ oc get authpolicy -A 

*$ oc describe authpolicy <authn_name> -n <namespace> *

*$ oc logs -n <kuadrant_system> -l authorino-resource=authorino *

***Replace <example_token> with your token. ***

6. Ensure that your issuer URL is reachable from the cluster by running the following command: 

***Replace <kuadrant_system> with the name of your Connectivity Link deployment. ***

**7. Check the token expiration time by examining the exp claim. **

**8. Verify the audience, if required, by using an aud claim. **

**9. Ensure that the token includes all required claims such as groups, email, and so on. **

1.8. TROUBLESHOOT MCP GATEWAY AUTHORIZATION ISSUES 

**Authorization errors can happen in a variety of ways, including an authenticated user getting 403 errors for all tool calls, authorization checks not enforced, or authorization failing with CEL evaluation errors. You can troubleshoot these problems by checking your configurations and troubleshooting CEL. **

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

You registered an MCP server. 

Procedure 

**1. Check your AuthPolicy custom resource (CR) authorization rules by running the following **command: 

***Replace <policy_name> with the name of your AuthPolicy CR. ***

***Replace <namespace> `with the namespace where your `AuthPolicy CR is applied. ***

**2. When your authorization checks are not enforced, first check your AuthPolicy CR status by **running the following command: 

***Replace <policy_name> with the name of your AuthPolicy CR. ***

*$ echo "<example_token>" | cut -d. -f2 | base64 -d | jq *

*$ oc exec -n <kuadrant_system> deployment/authorino -- curl -s *https://auth.provider.com/realms/mcp/.well-known/openid-configuration 

*$ oc get authpolicy <policy_name> -n <namespace> -o yaml | grep -A 20 authorization *

*$ oc describe authpolicy <policy_name> -n <namespace> *

***Replace <namespace> `with the namespace where your `AuthPolicy CR is applied. ***

**3. Next, verify your AuthPolicy CR targets the correct resource by running the following **command: 

***Replace <policy_name> with the name of your AuthPolicy CR. ***

***Replace <namespace> `with the namespace where your `AuthPolicy CR is applied. ***

**4. Ensure that your AuthPolicy CR targetRef matches your Gateway object name and **namespace by running the following command: 

***Replace <mcp_system> with the name of your MCP gateway deployment. ***

**5. If your AuthPolicy CR and your Gateway object are in different namespaces, you must either move the AuthPolicy CR into the same namespace as the Gateway object, or target the HTTPRoute CR instead. **

**6. Check that your AuthPolicy CR sectionName matches your Gateway object listener name. **

***Replace <auth_policy_name> with the name of your AuthPolicy CR. ***

***Replace <mcp_system> with the name of your MCP gateway deployment. ***

**7. Examine the Status block for an entry about your listener. If the sectionName is wrong, the policy shows "Accepted", but the policy does not affect the intended traffic path. **

1.8.1. Troubleshoot MCP gateway CEL issues 

**When authorization fails with CEL evaluation errors, you can troubleshoot by checking logs, **communication, and other configuration. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

*$ oc get authpolicy <policy_name> -n <namespace> -o yaml | grep -A 5 targetRef *

$ echo "--- AuthPolicy Targets ---" && \ *oc get authpolicy -n <mcp_system> -o jsonpath='{range .items[*]}{.metadata.name}{"\t *targets -> \t"}{.spec.targetRef.kind}{"/"}{.spec.targetRef.name}{"\n"}{end}' && \ echo "--- Actual Gateways ---" && \ *oc get gateway -n <mcp_system> -o custom-columns=NAME:.metadata.name *

*$ oc describe authpolicy <auth_policy_name> -n <mcp_system> *

You registered an MCP server. 

Procedure 

1. Check the Authorino Operator logs for CEL evaluation by running the following command: 

***Replace <kuadrant_system> with the namespace where Connectivity Link is installed. ***

2. Ensure that the Authorino Operator can communicate with your identity server. 

**3. Verify that your JWT token includes resource_access[server-name].roles claims. **

**4. Verify the CEL syntax in your authorization rules. **

**5. Check that referenced fields exist, such as auth.identity.groups. **

6. Verify that the JSON or data object coming back from the source matches the exact fields you referenced in your Authorino configuration. 

**7. Test CEL expression syntax using online validation tools. **

**8. Add persistent logging to understand the CEL evaluation context. **

1.8.2. Check the Kuadrant Operator status 

When authorization errors happen because the Kuadrant Operator is not working, you can diagnose the situation by checking the Operator status. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You installed the OpenShift CLI (oc). **

**You configured a Gateway object. **

**You configured an HTTPRoute object for the gateway. **

You registered an MCP server. 

Procedure 

1. Check that the Kuadrant Operator is working by running the following command: 

***Replace <kuadrant_system> with the namespace where your Connectivity Link is installed. ***

Example output 

*$ oc logs -n <kuadrant_system> -l authorino-resource=authorino | grep -i authz *

*$ oc get pods -n <kuadrant_system> *

NAME                                                  READY   STATUS    RESTARTS   AGE 

**If the authorino-* pod shows CrashLoopBackOff, it either cannot reach your OIDC issuer **or has an invalid configuration. 

**If the kuadrant-operator-controller-manager-* pod is down, any changes you make to your AuthPolicy CR cannot be applied to the Gateway object because the controller pod does not reconcile your AuthPolicy CR. **

2. Remedy pod issues as required. 

authorino-78c5679f94-abc12                            1/1     Running   0          5d dns-operator-controller-manager-5d4789f6-x1y2z        1/1     Running   0          5d kuadrant-operator-controller-manager-8495bc4d-98765   1/1     Running   0          5d limitador-67f89bc5d4-z9w8v                            1/1     Running   0          5d 