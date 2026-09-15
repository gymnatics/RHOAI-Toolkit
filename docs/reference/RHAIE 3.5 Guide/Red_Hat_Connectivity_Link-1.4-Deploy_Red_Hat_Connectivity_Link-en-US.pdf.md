# Red_Hat_Connectivity_Link-1.4-Deploy_Red_Hat_Connectivity_Link-en-US.pdf

- Red Hat Connectivity Link 1.4

# Deploy Red Hat Connectivity Link

Secure, protect, and connect APIs on OpenShift 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 Deploy Red Hat Connectivity Link

Secure, protect, and connect APIs on OpenShift

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

This guide explains how to use Connectivity Link policies on OpenShift to secure, protect, and connect an application API exposed by a Gateway based on Kubernetes Gateway API. This includes Gateways deployed on a single OpenShift cluster or distributed across multiple clusters.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. CONFIGURE AND DEPLOY GATEWAY POLICIES 1.1. WORKFLOW FOR PROVIDING A PLATFORM 

1.1.1. Set up your environment 1.1.2. Set up a DNS provider secret 1.1.3. Create your Gateway object 

1.2. ADD A TLS CERTIFICATE ISSUER 1.2.1. Set a TLS policy 

1.3. SET THE DNS POLICY 1.4. SET THE DEFAULT AUTHPOLICY CUSTOM RESOURCE 1.5. SET A DEFAULT RATE-LIMIT POLICY 1.6. ADD RATE-LIMIT HEADERS TO AN API RESPONSE 1.7. ABOUT TOKEN-BASED RATE LIMITING WITH TOKENRATELIMITPOLICY 

1.7.1. How token rate limiting works 1.7.2. Key features and use cases 1.7.3. Integrating with AuthPolicy 1.7.4. Configure token-based rate limiting for LLM APIs 

1.8. ADDITIONAL RESOURCES 

CHAPTER 2 CONNECT AND SECURE APIS AND SERVICES 2.1. APPLICATION DEVELOPMENT WORKFLOW 2.2. ALLOW API ACCESS 

2.2.1. About Service and Deployment objects 2.2.2. Create an HTTP route for an application 2.2.3. Override the low-limit RateLimitPolicy for specific users 

2.3. ABOUT CONFIGURING YOUR GATEWAY, ROUTES, AND POLICY RESOURCES 2.4. ABOUT GRPCROUTE POLICY ATTACHMENT 

2.4.1. Create a GRPCRoute custom resource 2.4.2. GRPCRoute custom resource parameters 2.4.3. Migrate policies to GRPCRoute support 

2.5. ADDITIONAL RESOURCES 

CHAPTER 3 USE ON-PREMISE DNS WITH COREDNS 3.1. ABOUT ON-PREMISE DNS WITH COREDNS 3.2. COREDNS INTEGRATION ARCHITECTURE 

3.2.1. Technical workflow 3.3. COREDNS DNS RECORDS SECURITY CONSIDERATIONS 3.4. USE COREDNS WITH A SINGLE CLUSTER 

3.4.1. Troubleshoot CoreDNS with a single cluster 3.5. USE COREDNS WITH PRIMARY AND SECONDARY CLUSTERS 

3.5.1. CoreDNS Corefile configuration reference 3.5.2. Default enabled plugins in CoreDNS 

3.6. TROUBLESHOOT COREDNS 3.7. COREDNS REMOVAL OR MIGRATION 3.8. ADDITIONAL RESOURCES 

CHAPTER 4 USE X.509 CRYPTOGRAPHIC IDENTITY VERIFICATION 4.1. ABOUT X.509 AUTHENTICATION IN CONNECTIVITY LINK 4.2. PREPARE CERTIFICATE AUTHORITIES AND CLIENT CERTIFICATES 4.3. CREATE A GATEWAY OBJECT FOR USE WITH THE X.509 FORMAT 4.4. INSTALL A SAMPLE APPLICATION FOR X.509 TESTING 4.5. CREATE AN HTTPROUTE CUSTOM RESOURCE FOR X.509 CERTIFICATES 4.6. CREATE AN AUTHPOLICY CUSTOM RESOURCE FOR X.509 CERTIFICATES 

4 4 4 6 6 8 9 11 

12 14 16 17 17 17 18 18 

20 

21 21 21 23 24 26 28 29 30 31 32 33 

34 34 34 35 36 37 40 41 

45 46 48 49 49 

50 50 51 52 56 57 59 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

4.7. VERIFY X.509 LAYER 1 AUTHENTICATION 4.8. VERIFY X.509 LAYER 2 AUTHENTICATION 4.9. TROUBLESHOOT X.509 AUTHENTICATION 4.10. ADDITIONAL RESOURCES 

CHAPTER 5 OPENID CONNECT AUTHENTICATION 5.1. SET THE OIDC AUTHPOLICY CUSTOM RESOURCE 

5.1.1. Verify the OIDC AuthPolicy custom resource 5.2. GET A TOKEN TO USE WITH AN OIDC AUTHPOLICY CUSTOM RESOURCE 5.3. USE RBAC WITH AN OIDC AUTHPOLICY CUSTOM RESOURCE 

5.3.1. Verify RBAC with OIDC 

CHAPTER 6 CONFIGURE AND DEPLOY THE PLANPOLICY EXTENSION 6.1. PLANPOLICY FOR TIERED SERVICE OFFERINGS 

6.1.1. Create an AuthPolicy with API key authentication 6.1.2. Verify the acceptance of the AuthPolicy CR 6.1.3. Create API key Secret objects 6.1.4. Verify the presence of the API key secrets 6.1.5. Deploy plan-based rate limiting with a PlanPolicy 6.1.6. Verify the acceptance of the PlanPolicy CR 6.1.7. Verify the PlanPolicy enforcement of ratelimiting 

6.2. PLANPOLICY CUSTOM RESOURCE PARAMETERS 6.2.1. Target an HTTPRoute in a PlanPolicy 6.2.2. Target a GRPCRoute in a PlanPolicy 6.2.3. Target a Gateway in a PlanPolicy 6.2.4. Plan predicates in PlanPolicies 6.2.5. Plan limits for PlanPolicies 

6.3. ADDITIONAL RESOURCES 

60 62 63 65 

66 66 67 68 69 70 

73 73 73 75 75 77 77 79 80 81 81 

82 83 83 84 85 

### CHAPTER 1. CONFIGURE AND DEPLOY GATEWAY POLICIES

**Set up DNS access, create a Gateway object, and set default policies to complete your Connectivity **Link deployment. Follow these steps on each cluster where you want to deploy Connectivity Link. 

1.1. WORKFLOW FOR PROVIDING A PLATFORM 

**You can use Connectivity Link to set up ingress Gateway objects on OpenShift Container Platform clusters in specific regions. You can configure all policies identically on all Gateway objects for **consistency. 

For example, configure DNS policies to ensure that customers in Brazil are routed to the South American data center and so on. You can also configure TLS, authentication and authorization, and ratelimiting policies to ensure that gateway security, performance, and monitoring all conform to your standards. 

Connect gateways and load balance 

**You must start by creating at least one Gateway object. If Gateway objects exist, you can move on to configuring access policies for those Gateway objects. You can connect Gateway objects by creating a DNS policy and configuring a global load balancing **strategy. DNS records are reconciled with your cloud DNS provider automatically, whether in a single-cluster or multicluster environment. You can use the following tools: 

Automatic DNS configuration 

Multiple DNS providers 

DNS-based load balancing, such as round-robin, weighted, and geo-based 

Single or multicluster ready 

Secure Gateways 

**After you create your Gateway objects, secure them. You can secure Gateway objects by using a **TLS policy that automatically generates certificate requests for the host names specified in your gateway. You can also set up application security defaults and overrides by using authentication and authorization policies and rate-limiting policies. You can use the following tools: 

TLS: Automatic certificate requests and ACME providers 

Auth policies 

Rate-limiting: Global rate-limiting, external IDPs, default and overrides 

Observe Gateways 

**After you create and secure your Gateway objects, you can configure your observability stack. **Observe your connectivity and runtime metrics by using dashboards and alerts. For example, configure metrics for policy compliance and governance, resource consumption, error rates, request latency and throughput. 

1.1.1. Set up your environment 

You can set up your environment variables and deploy a sample application on your OpenShift Container Platform cluster. In this example, a demonstration application is used. 

NOTE 

The Toystore application is an example only and is not intended for production use. 

Prerequisites 

You installed Connectivity Link on at least one OpenShift Container Platform cluster. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

You know the name and namespace of the gateway you want to connect your application to. 

Procedure 

1. Set the following environment variable by running the following command: 

**KUADRANT_GATEWAY_NS: Namespace for your gateway in OpenShift Container **Platform. 

**KUADRANT_GATEWAY_NAME: Name of your gateway in OpenShift Container Platform. **

**KUADRANT_DEVELOPER_NS: Namespace for the example Toystore app in OpenShift **Container Platform. You can replace this value with the name of the application you want to use. 

**KUADRANT_AWS_ACCESS_KEY_ID: DNS provider access key ID. In this example, AWS **is used. You can replace this value with your DNS provider information. 

**KUADRANT_AWS_SECRET_ACCESS_KEY: DNS provider secret access key with **permissions to manage your DNS zone. In this example, AWS is used. You can replace this value with your DNS provider information. 

**KUADRANT_ZONE_ROOT_DOMAIN: The root domain associated with your DNS zone ID. **In this example, the OpenShift Container Platform secret containing the credentials for the DNS provider is AWS Route53. You can replace this value with your DNS provider information. 

**KUADRANT_CLUSTER_ISSUER_NAME: Name of the certificate authority or the issuer **for TLS certificates. 

2. Create the namespace for the application by running the following command: 

$ export KUADRANT_GATEWAY_NS=api-gateway \   export KUADRANT_GATEWAY_NAME=ingress-gateway \   export KUADRANT_DEVELOPER_NS=toystore \   export KUADRANT_AWS_ACCESS_KEY_ID=xxxx \   export KUADRANT_AWS_SECRET_ACCESS_KEY=xxxx \   export KUADRANT_ZONE_ROOT_DOMAIN=example.com \   export KUADRANT_CLUSTER_ISSUER_NAME=self-signed 

$ oc create ns ${KUADRANT_DEVELOPER_NS} 

3. Deploy your application to the namespace you specified by running the following command: 

You can replace the Toystore application with the path to the one you want to use. 

1.1.2. Set up a DNS provider secret 

You can create access to the DNS zones that Connectivity Link can use by configuring your external **DNS provider credentials. After you set up your Secret resource, create your Gateway CR and secure it. **You can then restrict access to only the DNS zones that you want Connectivity Link to manage by **setting a DNSPolicy CR. **

IMPORTANT 

**You must apply the following Secret to each cluster. **

Prerequisites 

You installed Connectivity Link on one or more clusters. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

Procedure 

**1. Create the namespace where you want your Gateway CR applied in by running the following **command: 

**2. Create the Secret credentials in the same namespace as the Gateway CR namespace by **running the following command: 

***Replace <aws_credentials> with the secret you want to use. ***

Next step 

Configure your TLS issuer and policy. 

1.1.3. Create your Gateway object 

**You must deploy a Gateway object in your OpenShift Container Platform cluster to begin setting up the **

$ oc apply -f https://raw.githubusercontent.com/Kuadrant/Kuadrant-operator/main/examples/toystore/toystore.yaml -n ${KUADRANT_DEVELOPER_NS} 

$ oc create ns ${KUADRANT_GATEWAY_NS} 

*$ oc -n ${KUADRANT_GATEWAY_NS} create secret generic <aws_credentials> \ *  --type=kuadrant.io/aws \   --from-literal=AWS_ACCESS_KEY_ID=$KUADRANT_AWS_ACCESS_KEY_ID \   --from-literal=AWS_SECRET_ACCESS_KEY=$KUADRANT_AWS_SECRET_ACCESS_KEY 

**infrastructure used by application developers. The Gateway object is the instantiation of your entry point. The Gateway object causes the controller to provision a load balancer with specific ports and **security credentials. 

IMPORTANT 

For Connectivity Link to balance traffic by using DNS across clusters, you must define **your Gateway object with a shared hostname. You can define the shared hostname by **using an HTTPS listener with a wildcard hostname based on the root domain. You must apply these resources to each cluster that you want to use them. 

Prerequisites 

You installed Connectivity Link on one or more clusters. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

Procedure 

**1. Create a Gateway custom resource (CR), such as {KUADRANT_GATEWAY_NAME}.yaml, **that has the following information: 

**Example Gateway CR **

apiVersion: gateway.networking.k8s.io/v1 kind: Gateway metadata:   name: ${KUADRANT_GATEWAY_NAME}   namespace: ${KUADRANT_GATEWAY_NS}   labels:     kuadrant.io/gateway: "true" spec:     gatewayClassName: openshift-default     listeners:     - allowedRoutes:         namespaces:           from: All       hostname: "api.${KUADRANT_ZONE_ROOT_DOMAIN}"       name: api       port: 443       protocol: HTTPS       tls:         certificateRefs:         - group: ""           kind: Secret           name: api-${KUADRANT_GATEWAY_NAME}-tls         mode: Terminate 

IMPORTANT 

If you require cryptographic identity verification, see "Create a Gateway object **for use with the X.509 format" for a Gateway object example to use instead of **this default. 

**2. Apply the Gateway CR by running the following command: **

Verification 

**1. Check the status of your Gateway object by running the following command: **

Example output 

2. Check the status of your HTTPS listener by running the following command: 

The HTTPS listener exists, but is not programmed or ready to accept traffic because you do not have valid certificates available. 

Next step 

**Create a TLSPolicy CR to program your HTTPS listener to accept traffic. **

1.2. ADD A TLS CERTIFICATE ISSUER 

**To secure communication to your Gateway object, you must define a certificate authority (CA) as an issuer for TLS certificates. Configure a TLSPolicy custom resource (CR) to automatically provision TLS certificates based on Gateway object listener hosts by using integration with cert-manager Operator for **Red Hat OpenShift and ACME providers. 

NOTE 

**You can use any certificate issuer supported by cert-manager. In multicluster **environments, you must add your TLS issuer in each OpenShift Container Platform cluster. 

**If you set up your Gateway CR to use HTTP instead of than HTTPS, setting up TLS and a TLSPolicy CR **are not required. 

$ oc apply -f {KUADRANT_GATEWAY_NAME}.yaml 

$ oc get gateway ${KUADRANT_GATEWAY_NAME} -n ${KUADRANT_GATEWAY_NS} -o=jsonpath='{.status.conditions[?(@.type=="Accepted")].message}{"\n"}{.status.conditions[? (@.type=="Programmed")].message}' 

Resource accepted Resource programmed, assigned to service(s) ${KUADRANT_GATEWAY_NAME}.${KUADRANT_GATEWAY_NS}.svc.cluster.local:443 

$ oc get gateway ${KUADRANT_GATEWAY_NAME} -n ${KUADRANT_GATEWAY_NS} -o=jsonpath='{.status.listeners[0].conditions[?(@.type=="Programmed")].message}' 

Prerequisites 

You installed Connectivity Link on one or more clusters. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

**You created and applied a Gateway object. **

**You created and applied an HTTPRoute object. **

Procedure 

**1. Before adding a TLS certificate issuer, create the secret credentials in the cert-manager **namespace by running the following command: 

***Replace <dns_provider_credentials> with the secret you want to use. This example uses ***Amazon Web Services (AWS). 

2. Create a TLS certificate issuer resource, such as **{KUADRANT_CLUSTER_ISSUER_NAME}.yaml, that has the following information: **

**3. Apply the ClusterIssuer CR by running the following command: **

Verification 

**Verify that the ClusterIssuer object is ready by running the following command: **

1.2.1. Set a TLS policy 

**Create a TLSPolicy custom resource (CR) for your gateway to regulate the ciphers a client can use **when connecting to the server. This ensures that Connectivity Link components use cryptographic libraries that do not allow known insecure protocols, ciphers, or algorithms. 

*$ oc -n cert-manager create secret generic <dns_provider_credentials> \ *  --type=kuadrant.io/aws \   --from-literal=AWS_ACCESS_KEY_ID=$KUADRANT_AWS_ACCESS_KEY_ID \   --from-literal=AWS_SECRET_ACCESS_KEY=$KUADRANT_AWS_SECRET_ACCESS_KEY 

apiVersion: cert-manager.io/v1 kind: ClusterIssuer metadata:   name: ${KUADRANT_CLUSTER_ISSUER_NAME} spec:   selfSigned: {} 

$ oc apply -f {KUADRANT_CLUSTER_ISSUER_NAME}.yaml 

$ oc wait clusterissuer/${KUADRANT_CLUSTER_ISSUER_NAME} --for=condition=ready=true 

**If you set up your Gateway CR to use HTTP instead of than HTTPS, setting up TLS and a TLSPolicy CR **are not required. 

Prerequisites 

You installed Connectivity Link on one or more clusters. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

**You created and applied a Gateway object. **

Procedure 

***1. Create a TLSPolicy custom resource (CR) such as <toystore_tls.yaml>, that has the following ***information: 

**Example TLSPolicy CR **

**2. Apply your TLSPolicy CR by running the following command: **

***Replace <toystore> with the name of your TLSPolicy object. ***

Verification 

**Verify that your TLSPolicy object has an Accepted and Enforced status by running the **following command: 

This might take a few minutes. 

apiVersion: kuadrant.io/v1 kind: TLSPolicy metadata:   name: ${KUADRANT_GATEWAY_NAME}-tls   namespace: ${KUADRANT_GATEWAY_NS} spec:   targetRef:     name: ${KUADRANT_GATEWAY_NAME}     group: gateway.networking.k8s.io     kind: Gateway   issuerRef:     group: cert-manager.io     kind: ClusterIssuer     name: ${KUADRANT_CLUSTER_ISSUER_NAME} 

*$ oc apply -f <toystore_tls.yaml> *

$ oc get tlspolicy ${KUADRANT_GATEWAY_NAME}-tls -n ${KUADRANT_GATEWAY_NS} -o=jsonpath='{.status.conditions[?(@.type=="Accepted")].message}{"\n"}{.status.conditions[? (@.type=="Enforced")].message}' 

Example output 

1.3. SET THE DNS POLICY 

**Control multicluster ingress by using DNS to bring traffic to your gateways with DNSPolicy custom resources (CRs). Setting a DNS policy automates the link between your Gateway IP address and a **human-readable hostname. 

**Create and apply a default DNSPolicy custom resource (CR) to ensure consistency and cleanup. You **can standardized naming by creating a pattern for developers who need URLs, manage time-to-live values, and set up automatic cleanup of unused DNS records. 

Prerequisites 

You installed Connectivity Link on at least one OpenShift Container Platform cluster. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

**You created a DNS-provider Secret object. **

**You created a Gateway object. **

Procedure 

**1. Create a DNSPolicy custom resource (CR), for example, {KUADRANT_GATEWAY_NAME}-dnspolicy.yaml, that includes the following information: **

TLSPolicy has been accepted TLSPolicy has been successfully enforced 

apiVersion: kuadrant.io/v1 kind: DNSPolicy metadata: *  name: <${KUADRANT_GATEWAY_NAME}-dnspolicy>   namespace: <${KUADRANT_GATEWAY_NS}> *spec:   healthCheck:     failureThreshold: 3     interval: 1m     path: /health   loadBalancing:     defaultGeo: true     geo: GEO-NA     weight: 120   targetRef: *    name: <${KUADRANT_GATEWAY_NAME}> *    group: gateway.networking.k8s.io     kind: Gateway   providerRefs: *  - name: <dns_provider_credentials> *

***Replace <{KUADRANT_GATEWAY_NAME}-dnspolicy.yaml> with the environment ***variable you defined. 

***Replace <{KUADRANT_GATEWAY_NS}> with the environment variable you defined. ***

**spec.loadBalancing.geo: Defines a geographically relevant load balancer. In this example, GEO-NA is used. Change this to match your requirements. **

***spec.providerRefs: Replace <dns_provider_credentials> with a reference to the ***OpenShift Container Platform secret containing the credentials for your DNS provider. 

**2. Apply the DNSPolicy CR by running the following command: **

***Replace <{KUADRANT_GATEWAY_NAME}_dnspolicy.yaml> with the filename you used. ***

***Replace <gateway_namespace> with name of the OpenShift Container Platform *****namespace where the Gateway object is applied. **

Verification 

**1. Verify that your DNSPolicy object has a status of Accepted and Enforced by running the **following command: 

***Replace <{KUADRANT_GATEWAY_NAME}_dnspolicy.yaml> with the filename you used. ***

***Replace <{KUADRANT_GATEWAY_NS}> with the environment variable you used. ***

This process might take a few minutes. 

2. Check the status of the DNS health checks that are enabled on your DNS policy by running the following command: 

***Replace <{KUADRANT_GATEWAY_NAME}_dnspolicy.yaml> with the filename you used. ***

***Replace <{KUADRANT_GATEWAY_NS}> with the environment variable you used. ***

These health checks flag a published endpoint as healthy or unhealthy based on the defined configuration. When unhealthy, an endpoint is not published if it has not already been **published to the DNS provider. An endpoint is only unpublished if it is part of an A record **that has more than one value. You can see the endpoint status for all cases in the **DNSPolicy object status. **

1.4. SET THE DEFAULT AUTHPOLICY CUSTOM RESOURCE 

*$ oc apply -f <{KUADRANT_GATEWAY_NAME}_dnspolicy.yaml> -n <gateway_namespace> *

*$ oc get dnspolicy <${KUADRANT_GATEWAY_NAME}-dnspolicy> -n <${KUADRANT_GATEWAY_NS}> -o=jsonpath='{.status.conditions[? *(@.type=="SubResourcesHealthy")].message}' 

*$ oc get dnspolicy <${KUADRANT_GATEWAY_NAME}_dnspolicy> -n <${KUADRANT_GATEWAY_NS}> -o=jsonpath='{.status.conditions[? *(@.type=="SubResourcesHealthy")].message}' 

**You can use Auth policy objects to define who you allow to connect to your services. Configure a Connectivity Link AuthPolicy custom resource (CR) to use external auth providers. You can ensure that **different clusters exposing the same API can authenticate with the same permissions. 

TIP 

**Apply an AuthPolicy custom resource (CR) with a deny-all policy to create a zero-trust environment. Using a zero-trust AuthPolicy object means that no traffic flows unless a specific allow rule is set. Every **connection request must be authenticated. You can prevent the accidental exposing of services by **using a deny-all policy. **

**In a zero-trust environment, every application with an HTTPRoute or GRPCRoute CR exposed by an application developer must also have an attached route-level AuthPolicy CR. You can attach multiple AuthPolicy objects to your Gateway, HTTPRoute, and GRPCRoute CRs. **

Prerequisites 

You installed Connectivity Link on one or more clusters. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

**You created a Gateway object. **

**You created an HTTPRoute or GRPCRoute object. **

Procedure 

**1. Create a default AuthPolicy CR, such as gateway_name-auth.yaml, with a deny-all setting for your Gateway object: **

Example AuthPolicy CR 

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata:   name: ${KUADRANT_GATEWAY_NAME}-auth   namespace: ${KUADRANT_GATEWAY_NS} spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway     name: ${KUADRANT_GATEWAY_NAME}   defaults:    when:      - predicate: "request.path != '/health'"    rules:     authorization:       deny-all:         opa:           rego: "allow = false" 

**2. Apply your AuthPolicy CR by running the following command: **

***Replace <gateway_name_auth.yaml> with the name of your AuthPolicy CR. ***

Verification 

**1. Check that your AuthPolicy has Accepted and Enforced status by running the following **command: 

Example output 

**2. Test your AuthPolicy CR by running the following curl command: **

Example output 

1.5. SET A DEFAULT RATE-LIMIT POLICY 

As a platform engineer, set up rate limiting to ensure that you are defining how much any one service **can use the Gateway object’s connection resources. Rate limits also protect backend services from excessive requests. You can attach multiple RateLimitPolicy objects to your Gateway and HTTPRoute **CRs. 

Prerequisites 

You installed Connectivity Link on one or more clusters. 

    response:       unauthorized:         headers:           "content-type":             value: application/json         body:           value: |             {               "error": "Forbidden",               "message": "Access denied by default by the gateway operator. If you are the administrator of the service, create a specific auth policy for the route."             } 

*$ oc apply -f <gateway_name_auth.yaml> *

$ oc get authpolicy ${KUADRANT_GATEWAY_NAME}-auth -n ${KUADRANT_GATEWAY_NS} -o=jsonpath='{.status.conditions[? (@.type=="Accepted")].message}{"\n"}{.status.conditions[?(@.type=="Enforced")].message}' 

AuthPolicy has been accepted AuthPolicy has been successfully enforced 

$ curl -H 'Authorization: APIKEY ndyBzreUzF4zqDQsqSPMHkRhriEOtcRx' http://api.example.com:8000/hello 

HTTP/1.1 200 OK 

You have a shared Redis-based datastore. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

**You created a Gateway object. **

**You created an HTTPRoute object. **

Procedure 

**1. Create a default RateLimitPolicy custom resource (CR), for example, gateway_name-rlp.yaml, that has the following information: **

**Example RateLimitPolicy CR **

**A low-limit value is used in this example for the ease of testing the CR. Configure the spec.defaults.limits: values that makes in your use case. **

**2. Apply your RateLimitPolicy CR by running the following command: **

***Replace <gateway_name-rlp.yaml> with the name of your RateLimitPolicy YAML. ***

Verification 

**1. Check that your RateLimitPolicy has Accepted and Enforced status by running the following **command: 

apiVersion: kuadrant.io/v1 kind: RateLimitPolicy metadata:   name: ${KUADRANT_GATEWAY_NAME}-rlp   namespace: ${KUADRANT_GATEWAY_NS} spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway     name: ${KUADRANT_GATEWAY_NAME}   defaults:     limits:       "low-limit":         rates:         - limit: 1           window: 10s 

*$ oc apply -f <gateway_name-rlp.yaml> *

$ oc get ratelimitpolicy ${KUADRANT_GATEWAY_NAME}-rlp -n ${KUADRANT_GATEWAY_NS} -o=jsonpath='{.status.conditions[? (@.type=="Accepted")].message}{"\n"}{.status.conditions[?(@.type=="Enforced")].message}' 

Example output 

**2. Test your rate-limiting by running the following curl command: **

**HTTP 403 responses are expected. **

1.6. ADD RATE-LIMIT HEADERS TO AN API RESPONSE 

When you need to ensure that your traffic remains stable under heavy load, you can add rate-limit headers to your API responses. 

**By adding x-ratelimit-* headers, you can turn your APIs into self-documenting systems that can **proactively throttle their own request frequency and time their retries. You can simplify debugging for developers and reduce unnecessary traffic spikes. 

Prerequisites 

You installed Connectivity Link on one or more clusters. 

If you plan to use rate-limiting in a multicluster environment, you have a shared Redis-based datastore. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

**You created a Gateway object. **

**You configured your gateway policies and HTTP routes. **

**You applied a default RateLimitPolicy CR to your deployment. **

You have write access to the namespace where Connectivity Link is installed. 

Procedure 

**1. Find the name of the Limitador CR in your cluster by running the following command: **

2. Apply a patch to add headers to the CR by running the following command: 

RateLimitPolicy has been accepted RateLimitPolicy has been successfully enforced 

$ while :; do curl -k --write-out '%{http_code}\n' --silent --output /dev/null  "https://api.$KUADRANT_ZONE_ROOT_DOMAIN/cars" | grep -E --color "\b(429)\b|$"; sleep 1; done 

$ oc get limitador -A 

$ oc patch limitador limitador -n KUADRANT-NAMESPACE --type=merge -p '{"spec": {"rateLimitHeaders": "DRAFT_VERSION_03"}}' 

Verification 

Test for the presence of headers by running the following command: 

***Replace <gateway_url> with the URL of your Gateway object. ***

Example output 

1.7. ABOUT TOKEN-BASED RATE LIMITING WITH TOKENRATELIMITPOLICY 

**As an application developer, you can use a TokenRateLimitPolicy custom resource (CR) to enforce rate **limits based on token consumption rather than the number of requests. 

This policy extends the Envoy Rate Limit Service (RLS) protocol with automatic token usage extraction. It is particularly useful for protecting Large Language Model (LLM) APIs, where the cost and resource usage correlate more closely with the number of tokens processed. 

**TokenRateLimitPolicy counts tokens by extracting usage metrics in the body of the artificial **intelligence (AI) inference API call, allowing for finer-grained control over API usage based on actual workload. 

1.7.1. How token rate limiting works 

**The TokenRateLimitPolicy object tracks cumulative token usage per client. Before forwarding a **request, it checks whether the client has already exceeded their limit. After the upstream responds, the policy extracts the actual token cost and updates the client’s counter. 

For example: 

1. On an incoming request, the gateway evaluates the matching rules and predicates from the **TokenRateLimitPolicy resources. **

2. If the request matches, the gateway prepares the necessary rate limit descriptors and monitors the response. 

**3. After receiving the response, the gateway extracts the usage.total_tokens field from the **JSON response body. 

**4. The gateway then sends a RateLimitRequest to the Limitador Operator (Limitador), including the actual token count as a hits_addend. **

**5. Limitador tracks the cumulative token usage and responds to the gateway with OK or OVER_LIMIT. **

1.7.2. Key features and use cases 

*$ curl -i -X GET http://<gateway_url>/path *

HTTP/1.1 200 OK x-ratelimit-limit: 5, 5;w=60 x-ratelimit-remaining: 4 x-ratelimit-reset: 58 

**Enforces limits based on token usage by extracting the usage.total_tokens field from an **OpenAI-style inference JSON response body. 

Suitable for consumption-based APIs such as LLMs where the cost is based on token counts. 

Allows defining different limits based on criteria such as user identity, API endpoints, or HTTP methods. 

**Works with AuthPolicy CRs to apply specific limits to authenticated users or groups. **

**Inherits functionalities from RateLimitPolicy CRs, including defining multiple limits with **different durations and using Redis for shared counters in multicluster environments. 

1.7.3. Integrating with AuthPolicy 

**You can combine TokenRateLimitPolicy CRs with AuthPolicy CRs to apply token limits based on authenticated user identity. When an AuthPolicy CR successfully authenticates a request, it injects identity information that is used by the TokenRateLimitPolicy CR to select the appropriate limit. **

For example, you can define different token limits for users belonging to differently tiered groups, **identified using claims in a JWT-validated by the AuthPolicy CR. **

1.7.4. Configure token-based rate limiting for LLM APIs 

You can protect Large Language Model (LLM) APIs deployed on OpenShift Container Platform by **configuring a TokenRateLimitPolicy custom resource (CR) that you integrate with an AuthPolicy **object for user-specific limits. 

Prerequisites 

You installed Connectivity Link on the OpenShift Container Platform cluster you are working with. 

**Gateway and HTTPRoute objects are both configured to expose your service. **

**You created and applied an AuthPolicy custom resource (CR) that overrides the default denyall setting. **

If you are running in a multicluster setup, or requiring persistent counters, Redis is configured for the Limitador Operator component. 

Your configured your upstream service to return an OpenAI-compatible JSON response **containing a usage.total_tokens field in the response body. **

Procedure 

**1. Create a TokenRateLimitPolicy YAML, for example, tokenratelimitpolicy.yaml that includes **the following information: 

Example TokenRateLimitPolicy YAML 

apiVersion: kuadrant.io/v1alpha1 kind: TokenRateLimitPolicy metadata:   name: llm-protection 

Choose a filename for the policy that makes sense in your environment. 

**The spec.limits.free-users.rates.limit parameter is set for 10,000 tokens per day for free **tier. 

**The spec.limits.free-users.when.predicate parameter is set to inference traffic only. **

**The spec.limits.pro-users.rates.limit parameter is set for 100,000 per day for the pro **user. 

**The spec.limits.pro-users.when.predicate parameter is set to inference traffic only. **

The predicates must match each other in each section. 

**2. Apply the TokenRateLimitPolicy policy by running the following command: **

***Replace <tokenratelimitpolicy.yaml> with the filename you used. ***

***Replace <gateway_namespace> with your gateway namespace. ***

**3. Check the status of the policy to ensure it was accepted and enforced on the target Gateway object. Look for conditions with type: Accepted and type: Enforced with status: "True". **

spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway     name: ai-gateway   limits:     free-users:       rates:         - limit: 10000           window: 24h       when:         - predicate: request.path == "/v1/chat/completions"         - predicate: |             auth.identity.groups.split(",").exists(g, g == "free")       counters:         - expression: auth.identity.userid     pro-users:       rates:         - limit: 100000           window: 24h       when:         - predicate: request.path == "/v1/chat/completions"         - predicate: |             auth.identity.groups.split(",").exists(g, g == "pro")       counters:         - expression: auth.identity.userid 

*$ oc apply -f <tokenratelimitpolicy.yaml> -n <gateway_namespace> *

*$ oc get <tokenratelimitpolicy.yaml> llm-protection -n <gateway_namespace> -o *jsonpath='{.status.conditions}' 

***Replace <tokenratelimitpolicy.yaml> with the filename you used. Replace <gateway_namespace> with your Gateway object namespace. ***

4. Send requests to your API endpoint, including the required authentication details, by running the following command: 

***Replace <auth_policy> and <api_endpoint> with your values. ***

Verification 

Ensure that your upstream service responds with an OpenAI-compatible JSON body containing **the usage.total_tokens field. **

**Requests made when the client is within their token limits should receive a 200 OK response or **other success status and their token counter is updated. 

**Requests made when the client has already exceeded their token limits should receive a 429 Too Many Requests response. **

1.8. ADDITIONAL RESOURCES 

Load balancing with MetalLB 

Connect and secure APIs and services 

Create, share, and consume APIs across teams 

*$ curl -H "Authorization: <auth_policy>" \ *     -d '{"model": "gpt-4", "messages": [{"role": "user", "content": "Hello"}]}' \ *     <api_endpoint> *

### CHAPTER 2. CONNECT AND SECURE APIS AND SERVICES

After you install and deploy Connectivity Link, you can configure access and security for your APIs, services, and applications. 

2.1. APPLICATION DEVELOPMENT WORKFLOW 

You can use Connectivity Link to protect applications and APIs on existing OpenShift Container **Platform clusters and Gateway objects. You can also monitor workloads and the status of OpenShift **Container Platform resource metrics and tracing by using observability dashboards and alerts. 

Example tasks 

Configure routes 

Set up application routes and API definitions and publish them to the cluster. 

Protect applications with Auth policies and allow API access 

OAuth 2 

JWT authorization policies 

API keys 

Kubernetes tokens 

Role-based access (RBAC) 

Relationship-based access control (ReBAC) 

Open Policy Agent (OPA) 

Observe application and API performance 

Monitor workloads and the status of OpenShift Container Platform resource metrics and tracing by using observability dashboards and alerts. 

Ensure that APIs meet performance and availability benchmarks achieved by other data centers by viewing API metrics, such as uptime, requests per second, latency, and errors per minute. 

2.2. ALLOW API ACCESS 

**You can allow users access to your APIs by overriding existing deny-all gateway-level policies. You must also attach application-level AuthPolicy objects and rate-limiting CRs to your HTTPRoute objects. **

IMPORTANT 

The following example allows two users access to the Toystore API by using API keys to authenticate the requests. Other options, such as OpenID Connect, are more appropriate for production use. Use the "least-access" approach that is best for your use case. 

Prerequisites 

Connectivity Link is installed. 

You configured Connectivity Link policies. 

**You installed the OpenShift CLI (oc). **

You are logged into OpenShift Container Platform as a cluster administrator. 

Procedure 

**1. Set the KUADRANT_SYSTEM_NS environment variable based on where you created the Kuadrant custom resource (CR) by running the following command: **

**2. Create the Secret custom resources (CRs), or API keys, for bob and alice users that contain **the following information: 

Example user Secret CRs 

3. Apply the API keys by running the following commands: 

***Replace <bob_key.yaml> with the filename you used. ***

$ export KUADRANT_SYSTEM_NS=$(oc get kuadrant -A -o jsonpath=" {.items[0].metadata.namespace}") 

apiVersion: v1 kind: Secret metadata:   name: bob-key   namespace: ${KUADRANT_SYSTEM_NS}   labels:     authorino.kuadrant.io/managed-by: authorino     app: toystore   annotations:     secret.kuadrant.io/user-id: bob stringData:   api_key: IAMBOB type: Opaque ---apiVersion: v1 kind: Secret metadata:   name: alice-key   namespace: ${KUADRANT_SYSTEM_NS}   labels:     authorino.kuadrant.io/managed-by: authorino     app: toystore   annotations:     secret.kuadrant.io/user-id: alice stringData:   api_key: IAMALICE type: Opaque EOF 

*$ oc apply -f <bob_key.yaml> *

***Replace <alice_key.yaml> with the filename you used. ***

**4. Create a new AuthPolicy in a different namespace that overrides the deny-all policy and accepts the API keys. For example, the following toystore-auth.yaml: **

**Example user AuthPolicy **

**5. Apply the AuthPolicy CR by running the following commands: **

***Replace <bob_key.yaml> with the filename you used. ***

2.2.1. About Service and Deployment objects 

**Before you can create a route to host your application at a public URL, you must create a Service custom resource (CR) as a routing rule. As a best practice, you must also create a Deployment object **that is the application pod. 

*$ oc apply -f <alice_key.yaml> *

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata:   name: toystore-auth   namespace: ${KUADRANT_DEVELOPER_NS} spec:   targetRef:     group: gateway.networking.k8s.io     kind: HTTPRoute     name: toystore   defaults:    when:      - predicate: "request.path != '/health'"    rules:     authentication:       "api-key-users":         apiKey:           selector:             matchLabels:               app: toystore         credentials:           authorizationHeader:             prefix: APIKEY     response:       success:         filters:           "identity":             json:               properties:                 "userid":                   selector: auth.identity.metadata.annotations.secret\.kuadrant\.io/user-id 

*$ oc apply -f <bob_key.yaml> *

**The following is an example of both Deployment and Service CRs for the Toystore example application **that you can use as reference in creating your own. 

Example application Deployment and Service CRs 

2.2.2. Create an HTTP route for an application 

As an application developer, you can create a route to host your application at a public URL. In Gateway **API, use the HTTPRoute custom resource (CR) to specify the routing behavior of HTTP requests from your Gateway object to your application. An HTTPRoute CR is especially useful for multiplexing HTTP **or terminated HTTPS connections. 

Prerequisites 

apiVersion: apps/v1 kind: Deployment metadata:   name: toystore   labels:     app: toystore spec:   selector:     matchLabels:       app: toystore   template:     metadata:       labels:         app: toystore     spec:       containers:         - name: toystore           image: quay.io/kuadrant/authorino-examples:api           env:             - name: LOG_LEVEL               value: "debug"             - name: PORT               value: "3000"           ports:             - containerPort: 3000               name: http   replicas: 1 ---apiVersion: v1 kind: Service metadata:   name: toystore spec:   selector:     app: toystore   ports:     - name: http       port: 80       protocol: TCP       targetPort: 3000 

You installed Connectivity Link on one or more clusters. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

**You created and applied a Gateway object. **

You have a web application that exposes a port and a TCP endpoint listening for traffic on the port. 

**You created a Service object for your application. **

You have a local Certificate Authority (CA) bundle. 

Procedure 

***1. Create an HTTPRoute custom resource (CR), such as <toystore>-route.yaml, that has the ***following information: 

**Example HTTPRoute CR **

***Replace <toystore> with the name of your application. ***

apiVersion: gateway.networking.k8s.io/v1 kind: HTTPRoute metadata: *  name: <toystore>   namespace: <${KUADRANT_DEVELOPER_NS}> *  labels: *    deployment: <toystore>     service: <toystore> *spec:   parentRefs: *    - name: <${KUADRANT_GATEWAY_NAME}>       namespace: <${KUADRANT_GATEWAY_NS}> *  hostnames:     - api.${KUADRANT_ZONE_ROOT_DOMAIN}   rules:     - matches:         - method: GET           path:             type: PathPrefix             value: /cars         - method: GET           path:             type: PathPrefix             value: /health       backendRefs: *        - name: <toystore> *          port: 80 

**metadata.namespace: The namespace in which you are deploying your application. Replace ***<${KUADRANT_DEVELOPER_NS}> with the environment variable you used during *installation. 

**spec.parentRefs.name and spec.parentRefs.namespace: The values must match the Gateway object. **

**spec.hostnames: The hostname must match the one specified in the Gateway object. **

**hostname.rules.matches.backendRefs.name: The name of the Service for your **application. 

**2. Apply your HTTPRoute CR by running the following command: **

***Replace <toystore> with the name of your application. ***

Example output 

The output indicates that the route to the application exists. 

Verification 

**1. Verify that the HTTPRoute is created by running the following command: **

***Replace <toystore> with the name of your application. ***

Example output 

**2. If you have DNSPolicy and TLSPolicy objects applied, you can validate that your backend is **reachable by running the following command: 

**Note that the example TLSPolicy CR uses a self-signed ClusterIssuer object. **

2.2.3. Override the low-limit RateLimitPolicy for specific users 

When you want to only allow a certain number of requests for specific users to an API that you are **developing, and a general limit for all other users, you can override the default low-limit RateLimitPolicy custom resource (CR). **

*$ oc apply -f <toystore>-route.yaml *

httproute.gateway.networking.k8s.io/toystore-route created 

***$ oc get httproute <toystore> -n kuadrant -o=jsonpath='{.status.parents[].conditions[? *****(@.type=="Accepted")].message}{"\n"}{.status.parents[].conditions[? **(@.type=="ResolvedRefs")].message}' 

Route was valid 

$ curl -k  https://api.${KUADRANT_ZONE_ROOT_DOMAIN}:443/cars 

IMPORTANT 

**An existing Gateway-level policy affects new HTTPRoute objects. Because you want users to now access this API, you must override that Gateway policy. For simplicity, you **can use API keys to authenticate the requests, but other options such as OpenID Connect are also available. 

Prerequisites 

You installed Connectivity Link on one or more clusters. 

If you plan to use rate-limiting in a multicluster environment, you have a shared Redis-based datastore. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

**You created a Gateway object. **

**You configured your gateway policies and HTTP routes. **

Procedure 

**1. Create a new RateLimitPolicy custom resource (CR) in a different namespace to override the default low-limit policy and set rate limits for specific users by using the following example: **

Example RateLimitPolicy CR for specific users 

apiVersion: kuadrant.io/v1 kind: RateLimitPolicy metadata:   name: toystore-rlp   namespace: ${KUADRANT_DEVELOPER_NS} spec:   targetRef:     group: gateway.networking.k8s.io     kind: HTTPRoute     name: toystore   limits:     "general-user":       rates:       - limit: 5         window: 10s       counters:       - expression: auth.identity.userid       when:       - predicate: "auth.identity.userid != 'bob'"     "bob-limit":       rates:       - limit: 2         window: 10s       when:       - predicate: "auth.identity.userid == 'bob'" 

2. Apply the CR by running the following command: 

***Replace <toystore-rlp> with the name of your YAML. ***

**Wait a few minutes for the RateLimitPolicy CR to be applied. **

**3. Check that the RateLimitPolicy has a status of Accepted and Enforced by running the **following command: 

**4. Check that the status of the HTTPRoute is now affected by the RateLimitPolicy CR in the **same namespace: 

Verification 

1. Send requests as user alice by running the following command: 

**The expected outcome is an HTTP status 200 every second for 5 seconds, followed by HTTP status 429 every second for 5 seconds. **

2. Send requests as user bob by running the following command: 

**The expected outcome is an HTTP status 200 every second for 2 seconds, followed by HTTP status 429 every second for 8 seconds. **

2.3. ABOUT CONFIGURING YOUR GATEWAY, ROUTES, AND POLICY RESOURCES 

**After you deploy your Gateway object, you must expose endpoints, program your HTTP listener, and **secure your connections with policies. You can also apply rate-limiting to ensure performance. 

*$ oc apply -f <toystore-rlp> *

$ oc get ratelimitpolicy -n ${KUADRANT_DEVELOPER_NS} toystore-rlp -o=jsonpath='{.status.conditions[?(@.type=="Accepted")].message}{"\n"}{.status.conditions[? (@.type=="Enforced")].message}' 

$ oc get httproute toystore -n ${KUADRANT_DEVELOPER_NS} -o=jsonpath='{.status.parents[0].conditions[? (@.type=="kuadrant.io/RateLimitPolicyAffected")].message}' 

$ while :; do curl -k --write-out '%{http_code}\n' --silent --output /dev/null -H 'Authorization: APIKEY IAMALICE' "https://api.$KUADRANT_ZONE_ROOT_DOMAIN/cars" | grep -E --color "\b(429)\b|$"; sleep 1; done 

$ while :; do curl -k --write-out '%{http_code}\n' --silent --output /dev/null -H 'Authorization: APIKEY IAMBOB' "https://api.$KUADRANT_ZONE_ROOT_DOMAIN/cars" | grep -E --color "\b(429)\b|$"; sleep 1; done 

IMPORTANT 

In multicluster environments, you must perform all of the steps in each cluster individually, unless specifically excluded. 

To complete your deployment, take the following steps: 

**Create and apply a TLSPolicy custom resource (CR) that uses your CertificateIssuer object to **set up your HTTPS listener certificates. 

**Create and apply an HTTPRoute or GRPCRoute CR for your Gateway object to communicate **with your backend application API. 

**Create and apply an AuthPolicy CR to set up a default HTTP 403 response for any unprotected **endpoints. 

TIP 

**Use the oc explain authpolicies command to understand which authentication methods are **supported when you use Connectivity Link on OpenShift Container Platform. The in-cluster API documentation lists all supported authentication mechanisms. 

**Create and apply a RateLimitPolicy CR to set up a default artificially low global limit to further protect any endpoints exposed by the Gateway object. **

**Create and apply a DNSPolicy CR with a load balancing strategy for your Gateway object. **

2.4. ABOUT GRPCROUTE POLICY ATTACHMENT 

**Beginning with Connectivity Link 1.4.0, GRPCRoute policy attachment is supported. You can now use GRPCRoute custom resources (CRs) for your Remote Procedure Call (gRPC)-native applications and services in all of your Connectivity Link policies except TokenRateLimitPolicy CRs. You can migrate existing policies after you create your GRPCRoute CRs. **

IMPORTANT 

**GRPCRoute policy attachment is a Technology Preview feature only. Technology **Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features offer early access to upcoming product features, enabling customers to test functionality and give feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

**Connectivity Link policies can now target GRPCRoute resources with the targetRef parameter. Specifically, AuthPolicy and RateLimitPolicy accept GRPCRoute as a valid target kind. The following **well-known attributes are also available for Common Expression Language (CEL) expressions: 

**request.grpc.service: Represents the exact service being called. **

**request.grpc.method: Represents the exact function being executed. **

**Using a GRPCRoute CR instead of an HTTPRoute CR when you already have a gRPC service can be an **advantage in the following scenarios: 

**Native service or method matching in routing rules instead of raw path patterns. **

Clearer intent. The route type declares that this is a gRPC service, making the topology more readable. 

**Gateway API validation. GRPCMethodMatch enforces valid service or method structure rather **than free-form path strings. 

**The following CRs support GRPCRoute CRs in their targetRef fields: **

AuthPolicy CRs 

RateLimitPolicy CRs 

**DNSPolicy and TLSPolicy policies cover attached GRPCRoute CRs automatically. **

**Telemetry works with GRPCRoute CRs with no updates required. Although telemetry objects target the Gateway object, telemetry captures and reports on gRPC traffic matched by attached GRPCRoute **CRs. You have the same level of observability for gRPC traffic as you currently do for traffic routed **through HTTPRoute CRs. **

2.4.1. Create a GRPCRoute custom resource 

You can implement policy attachments based on qualified service and method names by using **GRPCRoute policy attachment support. First, you must create a GRPCRoute custom resource (CR). **

IMPORTANT 

**GRPCRoute policy attachment support is a Technology Preview feature only. **Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features offer early access to upcoming product features, enabling customers to test functionality and give feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Prerequisites 

You installed OpenShift Container Platform. 

**You installed OpenShift CLI (oc). **

You installed the MCP gateway Operator. 

**You created a Gateway object. **

Procedure 

**1. Create a GRPCRoute YAML by using the following example: **

Example GRPCRoute CR 

See the "GRPCRoute custom resource parameters" reference information for details about parameters. 

IMPORTANT 

**If you include a spec.rules.matches.method block, you must specify a service name, a method name, or both. Omitting the method block entirely matches all **gRPC traffic. 

**2. Apply your GRPCRoute CR by running the following command: **

***Replace <grpcstore_route.yaml> with the name of your gRPC YAML. ***

Example output 

The output indicates that the route to the object exists. 

Next steps 

**Create your policies with targetRef values that reference your GRPCRoute CR. **

**If you are migrating HTTPRoute CRs to GRPCRoute CRs, update existing policies to reference your GRPCRoute CR. **

2.4.2. GRPCRoute custom resource parameters 

**You can use the following information about parameters and their values to create a GRPCRoute **custom resource (CR) for Connectivity Link. 

apiVersion: gateway.networking.k8s.io/v1 kind: GRPCRoute metadata: *  name: <grpcstore> *spec:   parentRefs: *    - name: <kuadrant_ingressgateway>       namespace: <gateway_system>   hostnames: [<"grpc.example.com">] *  rules:     - matches:         - method: *            service: <"talker.TalkerService">             method: <"Echo"> *      backendRefs:         - name: grpcstore           port: 9000 

*$ oc apply -f <grpcstore_route.yaml> *

grpcroute.gateway.networking.k8s.io/grpcstore-route created 

Table 2.1. GRPCRoute custom resource parameter reference table 

Parameter Definition and Details 

**metadata.name **The gRPC route name. Replaceable value. 

**spec.parentRefs.name The name of the Gateway object to attach this policy to. Replaceable **value. 

**spec.hostnames **List of your public DNS entries. Define this to match the DNS records pointing to your cluster. 

**spec.parentRefs.namespa ce **

**Use this parameter value if your Gateway object is in a different namespace than the route. Use the Gateway object namespace. **

**spec.rules.matches.meth od.service **

**The fully qualified name of the gRPC service from your .proto file. Copy the **value exactly from your application code definitions. If you specify a **service, but leave the spec.rules.matches.method.method **unspecified, the rule applies to all of the functions within this specific gRPC service. You must specify at least one value for the **spec.rules.matches.method parameter. Valid values are service or method. **

**spec.rules.matches.meth od.method **

Use if you want a highly precise filter to isolate a specific function. You **must specify at least one value for the spec.rules.matches.method parameter. Valid values are service or method. **

**spec.rules.backendRefs.n ame and .port **

Point to your application pod. Replace the example values with the name of the service that is running your gRPC application and the port that your application service is listening on. 

2.4.3. Migrate policies to GRPCRoute support 

IMPORTANT 

**GRPCRoute policy attachment support is a Technology Preview feature only. **Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features offer early access to upcoming product features, enabling customers to test functionality and give feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

**When you want to replace your HTTPRoute custom resources (CRs) with GRPCRoute CRs, you must update your policies to reference a GRPCRoute CR. You must also configure other parameters in those **policies as required for your use case. 

IMPORTANT 

**A GRPCRoute CR cannot coexist with an HTTPRoute CR on the same hostname. If both gRPC and HTTP traffic must share a hostname, use an HTTPRoute CR. Otherwise, use **separate hostnames for HTTP and gRPC traffic. 

Prerequisites 

You installed OpenShift Container Platform. 

**You installed OpenShift CLI (oc). **

You installed the MCP gateway Operator. 

You created a Gateway object. 

**You have an existing HTTPRoute CR routing traffic to a gRPC service. **

Procedure 

**1. Delete your HTTPRoute CRs. You must remove the HTTPRoute CR must before you can use the GRPCRoute CR on the same hostname. **

**2. Update the spec.targetRef.kind parameter value in your AuthPolicy and RateLimitPolicy CRs to GRPCRoute by using the following example: **

**Example AuthPolicy CR updated to gRPC **

2.5. ADDITIONAL RESOURCES 

Create, share, and consume APIs across teams 

*#... *spec:   targetRef:     group: gateway.networking.k8s.io     kind: GRPCRoute     name: grpcstore *#... *

### CHAPTER 3. USE ON-PREMISE DNS WITH COREDNS

You can secure, protect, and connect an API exposed by a gateway that uses Gateway API by using Connectivity Link. 

3.1. ABOUT ON-PREMISE DNS WITH COREDNS 

You can self-manage your on-premise DNS by integrating CoreDNS with your DNS infrastructure through access control and zone delegation. Connectivity Link combines the DNS Operator with CoreDNS to simplify your management and security for on-premise DNS servers. You can use CoreDNS in both single-cluster and multicluster scenarios. 

CoreDNS is best used in environments that change often, where using a DNS-as-code approach makes sense. The following situations are example use cases for integrating with CoreDNS: 

You need to avoid dependency on external cloud DNS services. 

You have regulatory or compliance requirements mandating self-hosted infrastructure. 

You need to keep full control over DNS records. 

You want to delegate specific DNS zones from existing DNS servers to Kubernetes-managed CoreDNS. 

You require consistent DNS management across hybrid or multicloud environments. 

You need to reduce DNS operational costs by eliminating per-query charges. 

You do not want to directly manage DNS records on the on-premise DNS server. 

You need to keep authoritative control on edge DNS servers. 

For example: 

Configure your authoritative on-premise DNS server to delegate a specific subdomain, such as **deployment.example.local, to CoreDNS instances managed by Connectivity Link. **

**Any pod-level dnsPolicy CR can then interact with the CoreDNS provider within the OpenShift **Container Platform cluster. You can specify the DNS provider that handles the records for the **targeted gateways in the delegate field of the DNS policy. **

The CoreDNS instance becomes authoritative for the delegated subdomain and manages the necessary DNS records for gateways within that subdomain. 

3.2. COREDNS INTEGRATION ARCHITECTURE 

CoreDNS is a DNS server that consists of default plugins that do several tasks, for example: 

Automatically detects when you add new services to your cluster and adds them to directories. 

Caches recent addresses to avoid the latency of repeated lookups. 

Runs health checks and skips over services that are down. 

Provides dynamic redirects by rewriting queries as they come in. 

You can add plugins for observability and other services that you require by updating the CoreDNS with the DNS Operator. 

With the DNS Operator, DNS is the first layer of traffic management. You can deploy the DNS Operator to multiple clusters and coordinate them all on a given zone. This means that you can use a shared domain name across clusters to balance traffic based on your requirements. 

3.2.1. Technical workflow 

**To give you integration with CoreDNS, Connectivity Link extends the DNS Operator with the kuadrant CoreDNS plugin that sources records from the kuadrant.io/v1alpha1/DNSRecord custom resource **(CR) and applies location-based and weighted response capabilities. 

You can create DNS records that point to the CoreDNS secret in one of the three following ways: 

Create it manually. 

**Use a non-delegating DNS policy at a gateway with routes attached. The kuadrant-operator CR creates DNSRecord CRs with the secret. **

Use a delegating DNS policy at a gateway. The delegating policy results in the creation of a **delegating DNSRecord CR without a secret reference. All delegating DNS Records are combined into a single authoritative DNS Record. The authoritative DNSRecord uses a default **provider secret. 

The DNS Operator reconciles authoritative records that have the CoreDNS secret referenced and applies labels only to those CRs. CoreDNS watches those records and matches the labels with zones **configured in the Corefile. If there is a match, the authoritative DNSRecord CR is used to serve a DNS **response. 

**There are no changes to the dnsPolicy API and no required changes to the policy controllers. This **integration is isolated to the DNS Operator and the CoreDNS plugin. 

The CoreDNS integration supports both single-cluster and multicluster deployments. 

Single cluster 

Organizations that want to self-host their DNS infrastructure without the complexity of multicluster coordination can use single-cluster CoreDNS integration. Using delegation is not required. A single cluster runs both DNS Operator and CoreDNS with the plugin. CoreDNS only serves **DNSRecord CRs that point to a CoreDNS provider secret. The CoreDNS plugin watches for DNS **records labeled with the appropriate zone name and serves them directly. Any authoritative **DNSRecord CR has endpoints from the single cluster. **

Multi-cluster delegation 

Multiple clusters can participate in serving a single DNS zone through Kubernetes role-based delegation that enables geographic distribution of DNS services and high availability. This implementation enables workloads across multiple clusters to contribute DNS endpoints to a unified zone, with primary clusters maintaining the authoritative view. The role of a cluster is determined by the DNS Operator. **Multi-cluster delegation uses kubeconfig-based interconnection secrets that grant read access to DNSRecord resources across clusters. This approach reuses Kubernetes role-based access (RBAC). **

Primary clusters: Run both the DNS Operator and CoreDNS and serve the DNS records that are local. The DNS Operator running on primary clusters that delegate reconciles 

**DNSRecord CRs by reading and merging them. Primary clusters then serve these authoritative DNSRecord CRs. Each CoreDNS instance serves the relevant authoritative DNSRecord for the configured zone. Each primary cluster can independently serve the **complete record set. 

Secondary clusters: Only run the DNS Operator. These clusters create delegating **DNSRecord CRs but do not interact with DNS providers directly. If the secret and **subdomain are properly configured, these DNS records are automatically reconciled in the primary cluster. 

Zone labeling 

CoreDNS integration uses a label-based filtering mechanism. The DNS Operator applies a zone-**specific label to DNSRecord CRs when the CRs are reconciled. The CoreDNS plugin only watches for DNSRecord CRs with labels that match configured zones. This method reduces resource use **and provides clear zone boundaries. 

GEO and weighted routing 

GEO and weighted routing use the same algorithmic approach as cloud providers. By using CoreDNS, you can have parity with cloud DNS provider capabilities and maintain full control over your DNS infrastructure. 

**GEO routing: The CoreDNS geoip plugin uses geographical-database integration to return **region-specific endpoints. 

Weighted routing: Applies probabilistic selection based on endpoint weights. 

Combined routing: First applies GEO filtering, then weighted selection within the matched region. 

3.3. COREDNS DNS RECORDS SECURITY CONSIDERATIONS 

As an infrastructure engineer or business lead, you can implement several security best practices when using CoreDNS with Connectivity Link. 

**Zone configuration DNSRecord custom resources (CRs) have full control over a Zone’s name server (NS) records. Anyone who can create or change a DNSRecord that targets the root of the main domain **name with NS records can decide where the all Zone traffic goes. Consider this as you plan your access controls. 

For example, use the following access-control best practices: 

**Separate namespaces: Keep zone configuration DNSRecord CRs in a dedicated, restricted **namespace 

Use least-privilege policies: 

**Strict RBAC: Only grant DNSRecord creation permissions to trusted infrastructure **engineers and cluster administrators. 

**Namespace isolation: Grant application developers DNSRecord permissions only in their **own namespaces. 

**Audit logging: Enable Kubernetes audit logging to track all DNSRecord changes. CoreDNS audit **logging is enabled by default for network troubleshooting and traffic pattern observability. 

**Version control: Use a DNS-as-code approach. Store zone configuration DNSRecord CRs in Git **and use standardized review processes. 

You can use the following RBAC configuration example to get you started with defining access: 

3.4. USE COREDNS WITH A SINGLE CLUSTER 

You can use CoreDNS as a DNS provider for Connectivity Link in a single-cluster, on-premise environment. This integration allows Connectivity Link to manage DNS entries within your internal network infrastructure. 

IMPORTANT 

**In a single-cluster setup, ensure that the endpoints IP address value you use is reachable from the kuadrant-system namespace. The default IP address, 10.96.0.10, is the internal **cluster-wide DNS address. 

Prerequisites 

Connectivity Link is installed on the OpenShift Container Platform cluster. 

**The OpenShift CLI (oc) is installed. **

You have administrator privileges on the OpenShift Container Platform cluster. 

You are logged in to the cluster you want to configure. 

**Your OpenShift Container Platform clusters have support for the loadbalanced service type **that allows UDP and TCP traffic on port 53, such as MetalLB. 

apiVersion: rbac.authorization.k8s.io/v1 kind: Role metadata:   name: dns-zone-config-admin   namespace: kuadrant-coredns rules: - apiGroups: ["kuadrant.io"]   resources: ["dnsrecords"]   verbs: ["create", "update", "patch", "delete"] ---apiVersion: rbac.authorization.k8s.io/v1 kind: RoleBinding metadata:   name: dns-zone-config-admin-binding   namespace: kuadrant-coredns subjects: - kind: User *  name: dns-admin@example.com  # Only trusted administrators *  apiGroup: rbac.authorization.k8s.io roleRef:   kind: Role   name: dns-zone-config-admin   apiGroup: rbac.authorization.k8s.io 

You have access to configure your authoritative on-premise DNS server. 

Podman is installed. 

Procedure 

1. Set up your cluster. Set the following environment variables for your cluster context: 

**For the ONPREM_DOMAIN variable value, use your actual root domain. **

**For the KUADRANT_SUBDOMAIN variable value, valid values are empty or kuadrant. **

**2. Extract the CoreDNS manifests from the dns-operator bundle by running the following **commands: 

a. Create a writable container layer from your DNS Operator bundle image by running the following command: 

***Optional. Replace <bundle> with the name you want to use. ***

***Replace <1.3.0> with your Connectivity Link version. ***

b. Copy the CoreDNS manifest file out of the stopped container and onto your local host machine by running the following command: 

***Optional. Replace <bundle> with the name you want to use. ***

***c. Delete the stopped container named <bundle> that you created in the first step since you ***no longer need it by running the following command: 

***Optional. Replace <bundle> with the name you want to use. ***

3. Apply the manifests to the cluster by running the following command: 

**4. Create a ConfigMap object to define the authoritative zone for CoreDNS by using the following example. This minimal configuration enables the kuadrant plugin and GeoIP features. **

$ export CTX_PRIMARY=$(oc config current-context) \   export KUBECONFIG=~/.kube/config \   export PRIMARY_CLUSTER_NAME=local-cluster \ *  export ONPREM_DOMAIN=<onprem_domain> \ *  export KUADRANT_SUBDOMAIN="" 

*$ podman create --name <bundle> registry.redhat.io/rhcl-1/dns-operator-bundle:rhcl-<1.3.0> *

*$ podman cp <bundle>:/coredns/manifests.yaml ./coredns-manifests.yaml *

*$ podman rm <bundle> *

$ oc apply -f ./coredns-manifests.yaml 

apiVersion: v1 kind: ConfigMap 

NOTE 

For production or exact GeoIP routing, mount your licensed MaxMind GeoIP database into the CoreDNS pod and update the filename in the **data.Corefile.geoip parameter. **

**5. Apply the ConfigMap object by running the following command: **

6. Update the CoreDNS deployment to use the new configuration by running the following command: 

7. Set a watch-and-wait command for the deployment rollout to complete by running the following command: 

Example output 

**8. Create the Kubernetes Secret that Connectivity Link uses to interact with CoreDNS. This **secret specifies the zones this provider instance is authoritative for. To create the secret, run the following command: 

metadata:   name: coredns-kuadrant-config   namespace: kuadrant-coredns data:   Corefile: |     ${KUADRANT_SUBDOMAIN}.${ONPREM_DOMAIN}:53 {         debug         errors         health {             lameduck 5s         }         ready         log         geoip <GeoIP-database-name>.mmdb {             edns-subnet         }         metadata         kuadrant     } 

$ oc apply -f --context $CTX_PRIMARY coredns-kuadrant-config.yaml 

$ oc --context $CTX_PRIMARY -n kuadrant-system patch deployment kuadrant-coredns --patch '{"spec":{"template":{"spec":{"volumes":[{"name":"config-volume","configMap": {"name":"coredns-kuadrant-config","items":[{"key":"Corefile","path":"Corefile"}]}}]}}}}' 

$ oc --context $CTX_PRIMARY -n kuadrant-system rollout status deployment/kuadrant-coredns 

kuadrant-coredns successfully rolled out 

$ oc create secret generic coredns-credentials \ *  --namespace=<kuadrant_system> \ *

***Replace <kuadrant_system> with the namespace of your Connectivity Link deployment. ***

Verification 

**Check the status of the DNSRecord CR by running the following commands: **

***Replace <name> with the name of your DNSRecord CR. ***

***Replace <namespace> with the namespace where you applied your DNSRecord CR. ***

**Expect the Ready condition to be True. **

Next steps 

**Create dnsPolicy custom resources in your OpenShift Container Platform pods, referencing the coredns-credentials secret as the provider. Connectivity Link manages DNS records within the delegated ${KUADRANT_SUBDOMAIN}.${ONPREM_DOMAIN} zone through CoreDNS. **

3.4.1. Troubleshoot CoreDNS with a single cluster 

After you set it up, you can troubleshoot CoreDNS as a DNS provider for Connectivity Link in a singlecluster, on-premise environment. 

IMPORTANT 

**In a single-cluster setup, ensure that the endpoints IP address value you use is reachable from the kuadrant-system namespace. The default IP address, 10.96.0.10, is the internal **cluster-wide DNS address. 

Prerequisites 

Connectivity Link is installed on the OpenShift Container Platform cluster. 

**The OpenShift CLI (oc) is installed. **

You have administrator privileges on the OpenShift Container Platform cluster. 

You are logged in to the cluster you want to configure. 

**Your OpenShift Container Platform clusters have support for the loadbalanced service type **that allows UDP and TCP traffic on port 53, such as MetalLB. 

  --type=kuadrant.io/coredns \   --from-literal=ZONES="${KUADRANT_SUBDOMAIN}.${ONPREM_DOMAIN}" \   --context ${CTX_PRIMARY} 

*$ oc get dnsrecord <name> -n <namespace> -o jsonpath='{.status.conditions[? *(@.type=="Ready")]}' 

$ NS1=$(oc get svc kuadrant-coredns -n kuadrant-coredns -o jsonpath='{.status.loadBalancer.ingress[0].ip}') *  ROOT_HOST=$(oc get dnsrecord <name> -n <namespace> -o jsonpath='{.spec.rootHost}') *  dig @${NS1} ${ROOT_HOST} 

You have access to configure your authoritative on-premise DNS server. 

Podman is installed. 

Procedure 

1. If you are having undetermined trouble, view the logs for all CoreDNS pods by running the following command: 

**2. If the DNSRecord is not appearing in the zone, verify that the record has the zone label by **running the following command: 

**The output should include the zone name, for example kuadrant.io/coredns-zone-name: k.example.com. **

a. If the output does not show the zone name, check that the DNS Operator is running by using the following command: 

b. You can also check the DNS Operator logs by running the following command: 

3. A couple of common issues can be missing RBAC and GeoIP database, as shown in the following output examples: 

**a. RBAC permissions missing.: Check your ClusterRole and ClusterRoleBinding **configurations. 

**b. GeoIP database file not found.: Ensure that your database is accessible. **

3.5. USE COREDNS WITH PRIMARY AND SECONDARY CLUSTERS 

You can use CoreDNS as a DNS provider for Connectivity Link in an existing multicluster, on-premise environment. This integration allows Connectivity Link to manage DNS entries within your internal network infrastructure. 

Prerequisites 

Connectivity Link is installed on two separate OpenShift Container Platform clusters (primary and secondary). 

**OpenShift CLI (oc) is installed and configured for access to both clusters. **

You have administrator privileges on both OpenShift Container Platform clusters. 

**Your OpenShift Container Platform clusters have support for the loadbalanced service type **that allows UDP and TCP traffic on port 53, such as MetalLB. 

$ oc logs -n kuadrant-coredns deployment/kuadrant-coredns 

$ oc get dnsrecords.kuadrant.io -n dnstest -o jsonpath='{.items[*].metadata.labels}' | grep kuadrant.io/coredns-zone-name 

$ oc get pods -n dns-operator-system 

$ oc logs -n dns-operator-system deployment/dns-operator-controller-manager 

You have access to configure your authoritative on-premise DNS server to delegate a subdomain. 

Podman is installed. 

**jq is installed. **

Procedure 

1. Set up the primary cluster. Set the following environment variables for your primary cluster context: 

***CTX_PRIMARY: Replace <primary_cluster_context_name> with the namespace of the ***cluster that you are specifying as primary. 

**KUBECONFIG: Adjust the path to your config directy as needed. **

***PRIMARY_CLUSTER_NAME: Replace <primary_cluster_name> with the name of the ***cluster that you are specifying as primary. 

***ONPREM_DOMAIN: Replace <onprem_domain> with your actual root domain. ***

**KUADRANT_SUBDOMAIN: List the subdomain to delegate. **

**2. Extract the CoreDNS manifests from the dns-operator bundle by running the following **commands: 

***Replace <1.3.0> with your Connectivity Link version. ***

3. Apply the manifests to the cluster by running the following command: 

4. Wait for the CoreDNS service to get an external IP address. You need the IP address to configure delegation on your authoritative on-premise DNS server. Retrieve and store the IP address by running the following command: 

*$ export CTX_PRIMARY=<primary_cluster_context_name> \ *  export KUBECONFIG=~/.kube/config \ *  export PRIMARY_CLUSTER_NAME=<primary_cluster_name> \   export ONPREM_DOMAIN=<onprem_domain> \   export KUADRANT_SUBDOMAIN=<kuadrant> *

*$ podman create --name bundle registry.redhat.io/rhcl-1/dns-operator-bundle:rhcl-<1.3.0> *

$ podman cp bundle:/coredns/manifests.yaml ./coredns-manifests.yaml 

$ podman rm bundle 

$ oc apply -f ./coredns-manifests.yaml 

$ export COREDNS_IP_PRIMARY=$(oc --context $CTX_PRIMARY -n kuadrant-system get service kuadrant-coredns -o jsonpath='{.status.loadBalancer.ingress[0].ip}') echo "CoreDNS Primary IP: ${COREDNS_IP_PRIMARY}" 

**5. Create a ConfigMap object to define the authoritative zone for CoreDNS on the primary cluster. The following minimal example configuration enables the kuadrant plugin and GeoIP **features: 

NOTE 

For production or exact GeoIP routing, mount your licensed MaxMind GeoIP database into the CoreDNS pod and update the filename in the **data.Corefile.geoip parameter. **

**6. Apply the ConfigMap object by running the following command: **

7. Update the CoreDNS deployment to use the new configuration by running the following command: 

8. Set a watch-and-wait command for the deployment rollout to complete by running the following command: 

Example output 

apiVersion: v1 kind: ConfigMap metadata:   name: coredns-kuadrant-config   namespace: kuadrant-coredns data:   Corefile: |     ${KUADRANT_SUBDOMAIN}.${ONPREM_DOMAIN}:53 {         debug         errors         health {             lameduck 5s         }         ready         log         geoip <GeoIP-database-name>.mmdb {             edns-subnet         }         metadata         kuadrant     } 

$ oc apply -f --context $CTX_PRIMARY coredns-kuadrant-config.yaml 

$ oc --context $CTX_PRIMARY -n kuadrant-system patch deployment kuadrant-coredns --patch '{"spec":{"template":{"spec":{"volumes":[{"name":"config-volume","configMap": {"name":"coredns-kuadrant-config","items":[{"key":"Corefile","path":"Corefile"}]}}]}}}}' 

$ oc --context $CTX_PRIMARY -n kuadrant-system rollout status deployment/kuadrant-coredns 

kuadrant-coredns successfully rolled out 

**9. Create the Kubernetes Secret that Connectivity Link uses to interact with CoreDNS. This **secret specifies the zones this provider instance is authoritative for. 

10. On your authoritative on-premise DNS server, configure delegation for the **${KUADRANT_SUBDOMAIN}.${ONPREM_DOMAIN} subdomain to the external IP addresses **of the CoreDNS services running on your primary and secondary clusters, **$COREDNS_IP_PRIMARY and $COREDNS_IP_SECONDARY. The specific steps depend on **your DNS server software, for example, BIND, Windows DNS Server. You typically need to add Name Server (NS) records pointing the subdomain to the CoreDNS IP addresses. 

Example delegation 

11. Restart CoreDNS by running the following command: 

NOTE 

After configuring delegation, you can test that the DNS resolution for the delegated subdomain works correctly by querying your authoritative DNS server **for a record within the kuadrant subdomain. One of the CoreDNS instances is **expected to refer to and answer the query. 

Verification 

1. Launch a temporary pod for testing by running the following command: 

***Replace <node_name> with the node you are testing on. ***

**2. Add transfer to your Corefile by running the following command: **

$ oc create secret generic coredns-credentials \   --namespace=kuadrant-system \   --type=kuadrant.io/coredns \   --from-literal=ZONES="${KUADRANT_SUBDOMAIN}.${ONPREM_DOMAIN}" \   --context ${CTX_PRIMARY} 

; Delegate kuadrant.example.local to CoreDNS instances $ORIGIN ${KUADRANT_SUBDOMAIN}.${ONPREM_DOMAIN}. @       IN      SOA     ns1.${ONPREM_DOMAIN}. hostmaster.${ONPREM_DOMAIN}. (                         2023102601 ; serial                         7200       ; refresh (2 hours)                         3600       ; retry (1 hour)                         1209600    ; expire (2 weeks)                         3600       ; minimum (1 hour)                         )         IN      NS      coredns-primary.${KUADRANT_SUBDOMAIN}.${ONPREM_DOMAIN}. 

coredns-primary   IN A ${COREDNS_IP_PRIMARY} 

$ oc -n kuadrant-coredns rollout restart deployment kuadrant-coredns 

*$ oc debug node/<node_name> *

$ oc patch cm kuadrant-coredns -n kuadrant-coredns --type merge \ 

3. Verify zone delegation by running the following command: 

Example output 

**In this example, k.example is the delegated zone and ns1.k.example is the primary zone. **

**4. Optional. Remove the transfer from your Corefile by running the following command: **

5. Verify the start of authority (SOA) record for the delegated zone by running the following command: 

Example output 

The SOA record is expected to show the primary name server (NS) as confirmation that **CoreDNS is responding authoritatively. In this example the primary NS is ns1.k.example.com. **

Next steps 

**Create DNSPolicy resources in your OpenShift Container Platform clusters, referencing the coredns-credentials secret as the provider. Connectivity Link manages DNS records within the delegated ${KUADRANT_SUBDOMAIN}.${ONPREM_DOMAIN} zone through CoreDNS. **

3.5.1. CoreDNS Corefile configuration reference 

A Corefile is organized into server blocks that define how DNS queries are handled based on the port and zone. Plugin execution order is determined at build time, not by Corefile order, so you can list plugins in any order. When making configurations by using the DNS Operator, you can check the **ConfigMap for the resulting server block. **

   -p "$(oc get cm kuadrant-coredns -n kuadrant-coredns -o jsonpath='{.data.Corefile}' | \    sed 's/kuadrant/transfer {\n        to *\n    }\n    kuadrant/' | \    jq -Rs '{data: {Corefile: .}}')" 

$ dig @${EDGE_NS} -k config/bind9/ddns.key -t AXFR example.com 

example.com.            30      IN      SOA     example.com. root.example.com. 17 30 30 30 30 example.com.            30      IN      NS      ns.example.com. k.example.com.          300     IN      NS      ns1.k.example.com. ns1.k.example.com.      300     IN      A       172.18.0.16 ns.example.com.         30      IN      A       127.0.0.1 example.com.            30      IN      SOA     example.com. root.example.com. 17 30 30 30 30 

$ oc patch cm kuadrant-coredns -n kuadrant-coredns --type merge \    -p "$(oc get cm kuadrant-coredns -n kuadrant-coredns -o jsonpath='{.data.Corefile}' | \    sed '/transfer {/,/}/d' | \    jq -Rs '{data: {Corefile: .}}')" 

$ dig @${EDGE_NS} soa k.example.com 

;; ANSWER SECTION: k.example.com.          60      IN      SOA     ns1.k.example.com. hostmaster.k.example.com. 12345 7200 1800 86400 60 

Connectivity Link includes the following minimal Corefile that you can update: 

Minimal Corefile 

For a Corefile with configurations added, see the following example: 

Example configured Corefile 

Zone coordination 

**Each zone in the Corefile must match a zone listed in your CoreDNS provider secret’s ZONES field. **

Required plugins 

**The geoip and metadata plugins are included by default with the Connectivity Link implementation **of the CoreDNS Corefile. 

Corefile updates 

After any updates to your Corefile, you must always restart your pods for the CoreDNS deployment. You can use the following command: 

You can check the status of the rollout by running the following command: 

3.5.2. Default enabled plugins in CoreDNS 

Corefile: |     . {         health         ready     } 

k.example.com {     debug     errors     log     health {         lameduck 5s     }     ready     geoip GeoLite2-City-demo.mmdb {         edns-subnet     }     metadata     transfer {         to *     }     kuadrant     prometheus 0.0.0.0:9153 } 

$ oc rollout restart deployment/coredns -n kuadrant-system 

$ oc rollout status deployment/coredns -n kuadrant-system --watch 

The following plugins are enabled by default in the Connectivity Link CoreDNS plugin. You must ensure CoreDNS compatibility and enable any other plugins that you want to add. 

Plugin Function 

acl Enforces access control policies on source IP addresses and prevents unauthorized access to DNS servers. 

cache Enables a front-end cache. 

cancel Cancels a request’s context after 5001 milliseconds. 

debug Disables the automatic recovery when a crash happens so that a stack trace is generated. 

errors Enables error logging. 

file **Enables serving zone data from an RFC 1035-style master file. **

forward Enables IP forwarding. Facilitates proxying DNS messages to upstream resolvers. 

geoip **Lookup .mmdb (MaxMind db file format) databases using the client IP, then adds associated geoip data to the context request. **

header Modifies the header for queries and responses. 

health Enables a health check endpoint. 

hosts **Enables serving zone data from an /etc/hosts style file. **

kuadrant **Enables serving zone data from kuadrant DNSRecord custom resources. Uses logic ***from the CoreDNS file plugin to create a functioning DNS server. *

local **Responds with a basic reply to a local names in the following zones, localhost, 0.in-addr.arpa, 127.in-addr.arpa, 255.in-addr.arpa and any query asking for localhost.<domain>. **

log Enables query logging to standard output. Logs are structured for aggregation by cluster logging solutions. 

loop Detects simple forwarding loops and halts the server. 

metadata Enables a metadata collector. 

minimal Minimizes size of the DNS response message whenever possible. 

nsid Adds an identifier of this server to each reply. 

prometheus **Enables Prometheus metrics. The default listens on localhost:9153. The metrics path is to /metrics. **

ready Enables a readiness check HTTP endpoint. 

reload Allows automatic reload of a changed Corefile. 

rewrite Rewrites queries for automatic port forwarding. 

root Simply specifies the root of where to find files. 

secondary Enables serving a zone retrieved from a primary server. 

timeouts Means that you can configure the server read, write and idle timeouts for the TCP, TLS, DoH and DoQ (idle only) servers. 

tls Means that you can configure the server certificates for the TLS, gRPC, and DoH servers. 

transfer Perform (outgoing) zone transfers for other plugins. 

view Defines the conditions that must be met for a DNS request to be routed to the server block. 

whoami Returns your resolver’s local IP address, port and transport. 

Plugin Function 

TIP 

**When using CoreDNS, if you do not need to keep all logs, you can set up the logs directive to only report errors and use the prometheus plugin to gather primary metrics instead. Prometheus metrics give you **trends, for example, how many queries failed, without storing every single piece of traffic. 

3.6. TROUBLESHOOT COREDNS 

You can troubleshoot your CoreDNS deployment by restarting the service and by checking the logs. Use the following commands as needed to investigate your specific errors: 

Restart CoreDNS by using the following command: 

You can view CoreDNS logs by running the following command: 

You can get recent logs by running the following command: 

$ oc -n kuadrant-coredns rollout restart deployment kuadrant-coredns 

$ oc logs -f deployments/kuadrant-coredns -n kuadrant-coredns 

3.7. COREDNS REMOVAL OR MIGRATION 

You can remove your CoreDNS integration by deleting the CoreDNS deployment and deleting your **DNS policies. To migrate to a different provider, delete existing dnsPolicy CRs and re-create them with **the new provider secret reference. No data is permanently locked into CoreDNS. 

3.8. ADDITIONAL RESOURCES 

Audit logging for network security 

$ oc logs --tail=100 deployments/kuadrant-coredns -n kuadrant-coredns 

### CHAPTER 4. USE X.509 CRYPTOGRAPHIC IDENTITY VERIFICATION

When you require strong cryptographic identity verification, you can use X.509 client certificate authentication with Connectivity Link to perform two-layer validation. 

4.1. ABOUT X.509 AUTHENTICATION IN CONNECTIVITY LINK 

You can use the X.509 format for your certificates in many scenarios, including high-security environments. 

See the following examples: 

Zero-trust architecture: You need cryptographic proof of identity for every request. 

Compliance requirements: Security standards, such as PCI DSS, HIPAA, and FedRAMP, mandate mutual TLS (mTLS). 

Machine-to-machine communication: Services authenticate with long-lived certificates from your Public Key Infrastructure (PKI). If you are using mTLS, you are using PKI. PKI issues, distributes, and renews your root certificate authorities (CAs). 

Multi-CA trust: You have different clients that are issued certificates by different CAs and you need fine-grained control over which CAs are trusted for which routes. 

No shared secrets: You want to avoid rotating and distributing API keys or tokens. 

When you use X.509 authentication in Connectivity Link, you implement the following two-step validation model: 

Step 1. Cryptographic proof: 

**During the initial TLS handshake, the client presents a certificate that the Gateway object **validates against your trusted CA certificates. This cryptographically verifies that the client is who they say they are because they have the private key and your certificate is trusted. 

Invalid, expired, or untrusted certificates are rejected at the TLS layer before reaching the application. 

**The Gateway object sets the x-forwarded-client-cert (XFCC) header with the certificate **details so that incoming XFCC headers from clients are sanitized. 

Step 2. Context-aware validation: 

**Authorino validates certificates extracted from the XFCC header. This means that you can **apply fine-grained rules and manage trust across multiple CAs by using simple label selectors. 

Certificate attributes extract identity details directly from client certificates. You can use these details to create precise access rules, or pass them along to your backend services as custom headers, ensuring that your applications always know exactly who is calling them. 

Both layers must succeed for a request to authenticate. 

4.2. PREPARE CERTIFICATE AUTHORITIES AND CLIENT CERTIFICATES 

To set up authentication for clients with provider-specific TLS validation, you must first have certificate authorities (CAs) and client certificates. 

You can use the following procedure to manually generate resources, or you can provision certificates by using an existing certificate manager or other automated process. Whichever method you select, you must complete the following tasks to use X.509 validation with Connectivity Link: 

**Include the extendedKeyUsage=clientAuth parameter in your client certificates. **

**Mount the root CA certificate into the Gateway object pods. This enables network-level verification. The Gateway object requires the CA bundle to allow the TLS connection to **establish. 

Store the CA used to sign the client certificate in a Secret and label the Secret for discovery by Authorino. This enables policy-level verification. Authorino requires the CA bundle to perform deep packet inspection of the identity. Then Authorino can grant or deny the specific client’s access a specific API. 

Prerequisites 

You are logged into OpenShift Container Platform as a cluster administrator. 

You installed Connectivity Link. 

Procedure 

1. On your local host, generate your certificate authority (CA) by running the following command: 

2. On your local host, create X.509 v3 extensions for your client certificate by running the following command: 

3. Generate the client certificate on your local host by running the following commands: 

a. Generate your Private Key. This is the secret file that stays on the client. Run the following command: 

$ openssl req -x509 -sha512 -nodes \   -days 365 \   -newkey rsa:4096 \   -subj "/CN=Test CA/O=Example Org/C=US" \   -addext basicConstraints=CA:TRUE \   -addext keyUsage=digitalSignature,keyCertSign \   -keyout /tmp/ca.key \   -out /tmp/ca.crt 

$ cat > /tmp/x509v3.ext << EOF authorityKeyIdentifier=keyid,issuer basicConstraints=CA:FALSE keyUsage=digitalSignature,nonRepudiation,keyEncipherment,dataEncipherment extendedKeyUsage=clientAuth EOF 

b. Create a Certificate Signing Request (CSR). The following command uses your private key and identity information to create a request for a certificate: 

c. Sign the certificate. This command takes your request, looks at your internal CA, and issues **the final Public Certificate, the client.crt: **

4. If you do not have a CA that you use to issue and sign client certificates, create the self-signed CA certificate in your cluster by running the following commands: 

**a. Create the ConfigMap for Gateway TLS validation by running the following command: **

***Replace <gateway_system> with the namespace where your Gateway object is ***applied. 

**The ConfigMap must be in the same namespace as the Gateway object. **

**b. Create the Authorino validation Secret by running the following command: **

**The Secret must be in the same namespace as Authorino. **

c. Label the Secret so that Authorino can find its trusted anchors by running the following command: 

4.3. CREATE A GATEWAY OBJECT FOR USE WITH THE X.509 FORMAT 

$ openssl genrsa -out /tmp/client.key 4096 

$ openssl req -new \   -subj "/CN=test-client/O=Example Org/C=US" \   -key /tmp/client.key \   -out /tmp/client.csr 

$ openssl x509 -req -sha512 \   -days 365 \   -CA /tmp/ca.crt \   -CAkey /tmp/ca.key \   -CAcreateserial \   -extfile /tmp/x509v3.ext \   -in /tmp/client.csr \   -out /tmp/client.crt 

$ oc create configmap gateway-client-ca \ *  -n <gateway_system> \ *  --from-file=ca.crt=/tmp/ca.crt 

$ oc create secret generic authorino-ca-validation \   -n kuadrant-system \   --from-file=ca.crt=/tmp/ca.crt 

$ oc label secret authorino-ca-validation \   -n kuadrant-system \   authorino.kuadrant.io/managed-by=authorino \   app.kubernetes.io/name=trusted-client 

To use the X.509 format for certificates, after you have your certificate authorities (CAs) and client **certificates set up, you must create a Gateway object without front-end TLS validation and associated **required resources. Not configuring front-end TLS in your Gateway passes authentication to your twostep X.509-based validation. 

You create the following custom resources by using the following procedure: 

A Gateway object configured for use with the X.509 certificate format. 

**A cert-manager Issuer: Self-signed certificate issuer for the Gateway object’s server **certificate. 

**A TLSPolicy CR: Kuadrant policy to manage the Gateway object’s server TLS certificate. **

Prerequisites 

You are logged into OpenShift Container Platform as a cluster administrator. 

**You installed Connectivity Link using Istio as your Gateway object controller. **

You created your CAs and X.509-formatted certificates. 

Procedure 

**1. Create the cert-manager Issuer custom resource (CR) by using the following example: **

***Replace <gateway_system> with the namespace of your Gateway object. ***

**2. Apply the cert-manager Issuer object by running the following command: **

**3. Create the TLSPolicy object by using the following example: **

apiVersion: cert-manager.io/v1 kind: Issuer metadata:   name: gateway-cert-issuer *  namespace: <gateway_system> *spec:   selfSigned: {} 

$ oc apply - f gateway-cert-issuer.yaml 

apiVersion: kuadrant.io/v1 kind: TLSPolicy metadata:   name: mtls-gateway-tls *  namespace: <gateway_system> *spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway     name: mtls-gateway     sectionName: https   issuerRef: 

**Replace the value of the metadata.namespace parameter with the namespace where your Gateway object is applied. **

**4. Apply the TLSPolicy object by running the following command: **

**5. On your local host, create an infrastructure customization ConfigMap CR to inject the client CA **volume mounts into the managed Istio proxy pods by using the following example: 

**Example ConfigMap CR for use with an X.509 Gateway object **

**Replace the value of the metadata.namespace parameter with the namespace where your Gateway object is applied. **

**6. Apply the infrastructure customization ConfigMap CR by running the following command: **

**7. Create the mTLS Gateway object by using the following example: **

    group: cert-manager.io     kind: Issuer     name: gateway-cert-issuer 

$ oc apply -f mtls-gateway-tls.yaml 

apiVersion: v1 kind: ConfigMap metadata:   name: mtls-gateway-config *  namespace: <gateway_system> *data:   deployment: |     spec:       template:         spec:           volumes:           - name: client-ca             configMap:               name: gateway-client-ca           containers:           - name: istio-proxy             volumeMounts:             - name: client-ca               mountPath: /etc/certs               readOnly: true 

$ oc apply -f mtls-gateway-config.yaml 

apiVersion: gateway.networking.k8s.io/v1 kind: Gateway metadata:   name: mtls-gateway *  namespace: <gateway_system> *spec:   gatewayClassName: openshift-default   infrastructure: 

**Replace the value of the metadata.namespace parameter with the namespace where your Gateway object is applied. **

**Replace the value of the spec.listeners.hostname parameter with the name of your Gateway object hostname. **

**Replace spec.listeners.tls.certificateRefs.name with the name of your Gateway object *****and the name of your mTLS listener in the <gateway_name>-<listener_name>-tls format. ***

**8. Apply the mTLS Gateway CR by running the following command: **

**9. Create an EnvoyFilter CR to configure mutual TLS validation by using the following example: **

**Example mutual TLS EnvoyFilter CR **

    parametersRef:       group: ""       kind: ConfigMap       name: mtls-gateway-config   listeners:   - name: https     protocol: HTTPS     port: 443 *    hostname: "<gateway_hostname>" *    allowedRoutes:       namespaces:         from: All     tls:       mode: Terminate       certificateRefs: *      - name: <gateway_name>-<listener_name>-tls *        kind: Secret 

$ oc apply -f mtls-gateway.yaml 

apiVersion: networking.istio.io/v1alpha3 kind: EnvoyFilter metadata:   name: mtls-validation *  namespace: <gateway_system> *spec:   targetRefs:   - group: gateway.networking.k8s.io     kind: Gateway     name: mtls-gateway   configPatches:   - applyTo: FILTER_CHAIN     match:       context: GATEWAY       listener:         portNumber: 443     patch:       operation: MERGE       value:         transport_socket: 

**Replace the value of the metadata.namespace parameter with the namespace where your Gateway object is applied. **

**10. Apply the EnvoyFilter CR by running the following command: **

4.4. INSTALL A SAMPLE APPLICATION FOR X.509 TESTING 

You can test your end-to-end flow of authenticating requests by X.509 client certificates by deploying a sample application before you roll out X.509 to a production environment. 

Prerequisites 

You are logged into OpenShift Container Platform as a cluster administrator. 

You installed Connectivity Link. 

You created your CAs and X.509-formatted certificates. 

**You created Gateway, TLSPolicy, and cert-manager Issuer objects. **

Procedure 

1. Deploy the sample application by using the following resources: 

Example httpbin application 

          name: envoy.transport_sockets.tls           typed_config:             "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext             commonTlsContext:               validationContext:                 trustedCa:                   filename: /etc/certs/ca.crt             requireClientCertificate: true 

$ oc apply -f mtls-envoyfilter.yaml 

apiVersion: v1 kind: ServiceAccount metadata:   name: httpbin ---apiVersion: v1 kind: Service metadata:   name: httpbin   labels:     app: httpbin     service: httpbin spec:   ports:   - name: http     port: 80 

2. Apply the application objects by running the following command: 

4.5. CREATE AN HTTPROUTE CUSTOM RESOURCE FOR X.509 CERTIFICATES 

  selector:     app: httpbin ---apiVersion: apps/v1 kind: Deployment metadata:   name: httpbin spec:   replicas: 1   selector:     matchLabels:       app: httpbin       version: v1   template:     metadata:       labels:         app: httpbin         version: v1     spec:       serviceAccountName: httpbin       securityContext:         runAsNonRoot: true         seccompProfile:           type: RuntimeDefault       containers:       - name: httpbin         image: quay.io/kuadrant/httpbin@sha256:2865a9ac6596340135fc3cd82cbc543c4050124afb10361e3 6f727abe4f71900         imagePullPolicy: IfNotPresent         securityContext:           runAsUser: 1000           allowPrivilegeEscalation: false           readOnlyRootFilesystem: true           capabilities:             drop:             - ALL         ports:         - containerPort: 80         volumeMounts:         - name: tmp           mountPath: /tmp       volumes:       - name: tmp         emptyDir: {} 

$ oc apply -f httpbin.yaml 

**To use the X.509 format for certificate, you must create an HTTPRoute custom resource (CR) that references your Gateway object. **

NOTE 

**If you require a GRPCRoute CR for your use-case, see "Creating a GRPCRoute custom **resource" for an example object and current support status. 

Prerequisites 

You are logged into OpenShift Container Platform as a cluster administrator. 

**You installed Connectivity Link using Istio as your Gateway object controller. **

You created your CAs and X.509-formatted certificates. 

**You created your Gateway object. **

Procedure 

**1. Create your HTTPRoute CR by using the following example: **

**Replace the metadata.name parameter value with the name of your application route. **

**Replace the metadata.namespace parameter with the namespace where your Gateway **object is applied. 

**Replace the metadata.labels.app value with the name of the application. **

**Replace the spec.parentRefs.namespace value with the namespace where your Gateway **object is applied. 

**2. Apply your HTTPRoute custom resource by running the following command: **

apiVersion: gateway.networking.k8s.io/v1 kind: HTTPRoute metadata: *  name: <httpbin_route>   namespace: <default> *  labels: *    app: <httpbin> *spec:   parentRefs:   - name: mtls-gateway *    namespace: <gateway_system> *  rules:   - matches:     - path:         type: PathPrefix         value: /     backendRefs:     - name: httpbin       port: 80 

*$ oc apply -f <app_http_route.yaml> *

***Replace <app_http_route.yaml> with the name of your HTTPRoute YAML. ***

4.6. CREATE AN AUTHPOLICY CUSTOM RESOURCE FOR X.509 CERTIFICATES 

**To use the X.509 format for certificate, you must create an AuthPolicy custom resource (CR) that **completes critical functions of your two-step validation. 

**When you use the following procedure, you create an AuthPolicy CR that implements the following **steps: 

**Extracts the certificate from the x-forwarded-client-cert header. **

**Validates the certificate chain against CA certificates labeled app.kubernetes.io/name: trusted-client. **

Enforces authorization based on a certificate organization attribute. 

Injects certificate attributes into request headers for fine-grained access control. 

Prerequisites 

You are logged into OpenShift Container Platform as a cluster administrator. 

**You installed Connectivity Link using Istio as your Gateway object controller. **

You created your CAs and X.509-formatted certificates. 

**You created your Gateway object. **

You created your route. 

Procedure 

**1. Create your X.509 AuthPolicy CR by using the following example: **

**Example X.509 AuthPolicy CR **

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata:   name: x509-auth-policy   namespace: default spec:   targetRef:     group: gateway.networking.k8s.io     kind: HTTPRoute     name: httpbin-route   rules:     authentication:       "x509-client-cert":         x509:           source:             xfccHeader: "x-forwarded-client-cert" 

**The spec.rules.authentication."x509-client-cert".x509 parameter causes the policy to **extract the certificate from the X-Forwarded-Client-Cert standard (XFCC) header. The **Gateway object populates this header after validating the client certificate. **

**The spec.rules.authentication."x509-client-cert".x509.source.xfccHeader parameter **value is the name of the XFCC header. This is the default header name. 

**Set the spec.rules.response.success.headers."x-client-common-name".plain.expression parameter value to ensure that the policy extracts the common **name (CN) from the certificate. 

**Set the spec.rules.response.success.headers"x-client-org".plain.expression **parameter value to ensure that the policy extracts the organization (O) from the certificate. 

**2. Apply your AuthPolicy custom resource by running the following command: **

***Replace <app_authpolicy.yaml> with the name of your AuthPolicy YAML. ***

4.7. VERIFY X.509 LAYER 1 AUTHENTICATION 

To test your layer 1 X.509 authentication, you can run test scenarios to check that connections are rejected. 

Prerequisites 

You are logged into OpenShift Container Platform as a cluster administrator. 

**You installed Connectivity Link using Istio as your Gateway object controller. **

You created your CAs and X.509-formatted certificates. 

**You created your Gateway object. **

You created your route. 

          selector:             matchLabels:               app.kubernetes.io/name: trusted-client     authorization:       "certificate-attributes":         patternMatching:           patterns:           - predicate: "size(auth.identity.Organization) > 0 && auth.identity.Organization[0] == 'Example Org'"     response:       success:         headers:           "x-client-common-name":             plain:               expression: auth.identity.CommonName           "x-client-org":             plain:               expression: auth.identity.Organization[0] 

*$ oc apply -f <app_authpolicy.yaml> *

**You installed the httpbin sample application. **

Procedure 

**1. Retrieve the Gateway object hostname by running the following command: **

***Replace <gateway_system> with the namespace where your Gateway object is applied. ***

2. Test with a valid certificate by running the following command: 

Example output 

3. Verify that the TLS handshake fails when there is no certificate by running the following command: 

Example output 

4. Verify that the TLS handshake fails when there is an untrusted certificate by running the following commands: 

a. Generate an untrusted certificate by running the following command: 

b. Generate an untrusted private key by running the following command: 

c. Create a Certificate Signing Request (CSR) for the untrusted client by running the following command: 

*$ export GATEWAY_HOSTNAME=$(oc get gateway mtls-gateway -n <gateway_system> -o *jsonpath='{.status.addresses[0].value}') 

$ curl -ik https://httpbin.${GATEWAY_HOSTNAME}/get \   --cert /tmp/client.crt \   --key /tmp/client.key 

HTTP 200 

$ curl -ik https://httpbin.${GATEWAY_HOSTNAME}/get 

curl: (56) OpenSSL SSL_read: OpenSSL/3.6.2: error:0A00045C:SSL routines::tlsv13 alert certificate required, errno 0 

$ openssl req -x509 -sha512 -nodes \   -days 365 \   -newkey rsa:4096 \   -subj "/CN=Untrusted CA/O=Untrusted Org/C=US" \   -keyout /tmp/untrusted-ca.key \   -out /tmp/untrusted-ca.crt 

$ openssl genrsa -out /tmp/untrusted-client.key 4096 

$ openssl req -new \   -subj "/CN=untrusted-client/O=Untrusted Org/C=US" \   -key /tmp/untrusted-client.key \ 

d. Sign the request using your untrusted authority to issue the client certificate by running the following command: 

e. Test the untrusted certificate by running the following command: 

Example output 

4.8. VERIFY X.509 LAYER 2 AUTHENTICATION 

To test that your X.509 authentication is working as intended, you can run a test scenario and check that your layer 2 policies reject connections. In this test, the client uses a certificate signed by your trusted certificate authority (CA), so the network handshake succeeds. However, because the client certificate has the wrong attributes, it fails at the policy layer through the Authorino Operator. 

With the final command of this test, you take the following actions: 

**The handshake, layer 1: Use curl to present the certificate. Envoy checks its mounted /etc/certs directory, sees that this certificate was signed by your legitimate ca.crt, and allows the TLS **connection to establish. 

**The policy evaluation, layer 2 processing: Envoy routes the HTTP request metadata and the **client certificate details to the Authorino Operator. 

The rejection, layer 2 failure: The Authorino Operator evaluates the request against your **configured AuthPolicy custom resource (CR), which does not allow O=Unauthorized Org and **the authentication fails. 

Prerequisites 

You are logged into OpenShift Container Platform as a cluster administrator. 

**You installed Connectivity Link using Istio as your Gateway object controller. **

You created your CAs and X.509-formatted certificates. 

**You created your Gateway object. **

  -out /tmp/untrusted-client.csr 

$ openssl x509 -req -sha512 \   -days 365 \   -CA /tmp/untrusted-ca.crt \   -CAkey /tmp/untrusted-ca.key \   -CAcreateserial \   -extfile /tmp/x509v3.ext \   -in /tmp/untrusted-client.csr \   -out /tmp/untrusted-client.crt 

$ curl -ik https://httpbin.${GATEWAY_HOSTNAME}/get \   --cert /tmp/untrusted-client.crt \   --key /tmp/untrusted-client.key 

curl: (56) OpenSSL SSL_read: OpenSSL/3.6.2: error:0A000418:SSL routines::tlsv1 alert unknown ca, errno 0 

You created your route. 

**You installed the httpbin sample application. **

Procedure 

1. Retrieve the gateway hostname by running the following command: 

***Replace <gateway_system> with the namespace where your Gateway object is applied. ***

2. Verify a connection failure when there is a valid certificate, but wrong attributes by running the following commands: 

a. Generate a certificate with a different organization by running the following command: 

b. Create a Certificate Signing Request (CSR) with unauthorized attributes by running the following command: 

c. Sign the request using your trusted certificate authority by running the following command: 

d. Test the unauthorized certificate by running the following command: 

Example output 

4.9. TROUBLESHOOT X.509 AUTHENTICATION 

If requests are either bypassing your X.509 authentication, or not accessing your backend as expected, you can diagnose the cause by taking steps that are based on the feedback being displayed. 

*$ export GATEWAY_HOSTNAME=$(oc get gateway mtls-gateway -n <gateway_system> -o *jsonpath='{.status.addresses[0].value}') 

$ openssl genrsa -out /tmp/unauthorized-client.key 4096 

$ openssl req -new \   -subj "/CN=unauthorized-client/O=Unauthorized Org/C=US" \   -key /tmp/unauthorized-client.key \   -out /tmp/unauthorized-client.csr 

$ openssl x509 -req -sha512 \   -days 365 \   -CA /tmp/ca.crt \   -CAkey /tmp/ca.key \   -CAcreateserial \   -extfile /tmp/x509v3.ext \   -in /tmp/unauthorized-client.csr \   -out /tmp/unauthorized-client.crt 

$ curl -ik https://httpbin.${GATEWAY_HOSTNAME}/get \   --cert /tmp/unauthorized-client.crt \   --key /tmp/unauthorized-client.key 

HTTP 403 

Prerequisites 

You are logged into OpenShift Container Platform as a cluster administrator. 

You installed Connectivity Link. 

You created your CAs and X.509-formatted certificates. 

**You created your Gateway object. **

You created your route. 

Procedure 

1. If the TLS handshake succeeds without client certificate, the Envoy filter might not be properly applied. Troubleshoot this situation by taking the following steps: 

**a. Verify that the EnvoyFilter exists by running the following command: **

***Replace <gateway_system> with the namespace where your Gateway object is applied. ***

**b. Check that the targetRef in the Envoy filter points to the Gateway object by running the **following command: 

***Replace <gateway_system> with the namespace where your Gateway object is applied. ***

c. Check that the Envoy configuration has the correct configuration by running the following command: 

***Replace <gateway_system> with the namespace where your Gateway object is applied. ***

**2. If the Gateway object logs show failed to load trusted CA, the certificate authority (CA) might **not be mounted. Use the following steps to check the CA: 

a. Verify that the ConfigMap exists by running the following command: 

***Replace <gateway_system> with the namespace where your Gateway object is applied. ***

**b. Check that the volume mount in the Gateway pod by running the following command: **

***Replace <gateway_system> with the namespace where your Gateway object is applied. ***

*$ oc get envoyfilter mtls-validation -n <gateway_system> *

*$ oc get envoyfilter mtls-validation -n <gateway_system> -o yaml | grep -A 3 targetRefs *

*$ oc exec -n <gateway_system> \   $(oc get pod -n <gateway_system> -l gateway.networking.k8s.io/gateway-name=mtls-*gateway -o jsonpath='{.items[0].metadata.name}') \   -- curl -s localhost:15000/config_dump?include_eds | grep -A 20 validation_context 

*$ oc get configmap gateway-client-ca -n <gateway_system> *

*$ oc describe pod -n <gateway_system> -l gateway.networking.k8s.io/gateway-*name=mtls-gateway | grep -A 5 Mounts 

**c. Verify that the CA file exists in the Gateway pod by running the following command: **

***Replace <gateway_system> with the namespace where your Gateway object is applied. ***

**3. If Authorino rejects requests with a certificate not found error, the XFCC header might not be **set correctly. Check the configuration and logs to help resolve this issue as follows: 

**a. Verify the forward_client_cert_details configuration by running the following command: **

***Replace <gateway_system> with the namespace where your Gateway object is applied. ***

b. Check the Envoy access logs for the XFCC header by running the following command: 

***Replace <gateway_system> with the namespace where your Gateway object is applied. ***

4.10. ADDITIONAL RESOURCES 

About GRPCRoute policy attachment 

*$ oc exec -n <gateway_system> \   $(oc get pod -n <gateway_system> -l gateway.networking.k8s.io/gateway-name=mtls-*gateway -o jsonpath='{.items[0].metadata.name}') \   -- cat /etc/certs/ca.crt 

*$ oc exec -n <gateway_system> \   $(oc get pod -n <gateway_system> -l gateway.networking.k8s.io/gateway-name=mtls-*gateway -o jsonpath='{.items[0].metadata.name}') \   -- curl -s localhost:15000/config_dump?include_eds | grep -i forward_client_cert 

*$ oc logs -n <gateway_system> -l gateway.networking.k8s.io/gateway-name=mtls-*gateway | grep XFCC 

### CHAPTER 5. OPENID CONNECT AUTHENTICATION

You can use OpenID Connect (OIDC) authentication with Connectivity Link to connect and secure an **API exposed by a Gateway object. **

5.1. SET THE OIDC AUTHPOLICY CUSTOM RESOURCE 

**You can configure a Connectivity Link AuthPolicy custom resource (CR) to use an OIDC provider. The **same API deployed to multiple clusters can authenticate with the same identity provider. 

**In a zero-trust environment, every application with an HTTPRoute or GRPCRoute CR exposed by an application developer must also have an attached route-level AuthPolicy CR. You can target either a Gateway or a route object with an AuthPolicy CR. **

Prerequisites 

You installed Connectivity Link on one or more clusters. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

**You created a Gateway object. **

**You created an HTTPRoute or GRPCRoute object. **

You have a trusted OIDC provider configured to issue tokens for your API clients. 

If your OIDC server is using a self-signed or internal cluster certificate, you injected the trusted CA bundle into your Connectivity Link installation. 

Procedure 

**1. Create an AuthPolicy CR that targets an HTTPRoute CR and configures OIDC authentication **by using the following example: 

**Example AuthPolicy CR **

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <api_oidc_auth>   namespace: <user_apps> *spec:   targetRef:     group: gateway.networking.k8s.io     kind: HTTPRoute *    name: <api_route> *  rules:     authentication:       "oidc-idp-auth":         jwt:           issuerUrl: "https://rhbk.apps.cluster.example.com/realms/realm" 

**The AuthPolicy CR must exist in the same namespace where the HTTPRoute object is **applied. 

**Replace the spec.metadata.name parameter value with the name you want to use for your AuthPolicy CR. **

**Replace the spec.metadata.namespace parameter value with the namespace where you want your AuthPolicy CR applied. **

**The value of the spec.targetRef.name parameter must match the name of your HTTPRoute object. **

**The URL, "https://rhbk.apps.cluster.example.com/realms/realm", is the base URL of your **OIDC issuer, for example, Red Hat build of Keycloak. 

**2. Apply your AuthPolicy CR by running the following command: **

***Replace <api_oidc_auth.yaml> with your AuthPolicy YAML filename. ***

5.1.1. Verify the OIDC AuthPolicy custom resource 

**You can verify a Connectivity Link AuthPolicy custom resource (CR) after you applied the policy to **ensure that it is working as intended. 

Prerequisites 

You completed the "Setting the OIDC AuthPolicy custom resource" procedure. 

Procedure 

**1. Check that your AuthPolicy has Accepted and Enforced status by running the following **command: 

***Replace <api_oidc_auth> with the name of your AuthPolicy CR. ***

***Replace <user_apps> with the namespace where your AuthPolicy CR is applied. ***

Example output 

*$ oc apply -f <api_oidc_auth.yaml> *

*$ oc describe authpolicy <api_oidc_auth> -n <user_apps> *

Status:   Conditions:     Last Transition Time:  2026-06-12T12:00:00Z     Message:               AuthPolicy has been accepted     Reason:                Accepted     Status:                True     Type:                  Accepted     Last Transition Time:  2026-06-12T12:00:01Z     Message:               AuthPolicy has been enforced 

2. Send an unauthenticated request to your route to verify that it is blocked by running the following command: 

***Replace <route_hostname> with the exposed hostname of your application route. ***

Example output 

3. Send an authenticated request containing a valid OIDC access token to verify that access is granted by running the following command: 

***Replace <access_token> with a valid JWT string issued by your OIDC provider. ***

***Replace <route_hostname> with the exposed hostname of your application route. ***

Example output 

5.2. GET A TOKEN TO USE WITH AN OIDC AUTHPOLICY CUSTOM RESOURCE 

**After you configured a Connectivity Link AuthPolicy custom resource (CR) to use an OIDC provider, **you must get a token. 

The following example assumes the following facts: 

**You have a Red Hat build of Keycloak instance running in the keycloak namespace that is listening at port 8080. **

**You have a kuadrant Keycloak realm. **

You have a demonstration OAuth2 client with a Direct Access grant enabled. 

**You have a user john with the password p. **

Prerequisites 

You installed Connectivity Link on one or more clusters. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

    Reason:                Enforced     Status:                True     Type:                  Enforced 

*$ curl -v -s -o /dev/null -w "%{http_code}\n" http://<route_hostname> *

HTTP/1.1 401 Unauthorized 

*$ curl -H "Authorization: Bearer <access_token>" -v -s -o /dev/null -w "%{http_code}\n" http://<route_hostname> *

HTTP/1.1 200 OK 

**You created a Gateway object. **

**You created an HTTPRoute or GRPCRoute object. **

**You created an AuthPolicy CR. **

Procedure 

**Get an access token from within the cluster for the user John, who is assigned to the member **role, by running the following command: 

NOTE 

If your Red Hat build of Keycloak server is reachable from outside the cluster, you **can get the token directly. Make sure that the hostname set in the OIDC issuer endpoint configured in the AuthPolicy CR matches the one used to get the **token and is reachable from within the cluster. 

5.3. USE RBAC WITH AN OIDC AUTHPOLICY CUSTOM RESOURCE 

You can configure role-based-access to use with your OpenID Connect (OIDC) authentication by **adding the roles to your AuthPolicy custom resource (CR). **

Prerequisites 

You installed Connectivity Link on one or more clusters. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

**You created a Gateway object. **

**You created an HTTPRoute or GRPCRoute object. **

**You created an AuthPolicy CR. **

You got a token from your OIDC provider. 

Procedure 

**Add the following roles to your AuthPolicy CR by using the following example: **

Example AuthPolicy with RBAC definitions 

$ ACCESS_TOKEN=$(oc run token --attach --rm --restart=Never -q --image=curlimages/curl -- http://keycloak.keycloak.svc.cluster.local:8080/realms/kuadrant/protocol/openid-connect/token -s -d 'grant_type=password' -d 'client_id=demo' -d 'username=john' -d 'password=p' -d 'scope=openid' | jq -r .access_token) 

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <api_oidc_rbac_auth> *

**Replace the spec.metadata.name parameter value with the name you want to use for your AuthPolicy CR. **

**Replace the spec.metadata.namespace parameter value with the namespace where you want your AuthPolicy CR applied. **

**Requests to /resources[/*] require the member role. **

**DELETE requests to ^/resources/\\\\d+$ require the admin role. **

**Requests to ^/admin(/.*)?$ require the admin role. **

5.3.1. Verify RBAC with OIDC 

You can verify that the role-based-access you configured is working your OpenID Connect (OIDC) authentication by conducting tests with different user roles. 

The following example assumes the following setup: 

A Red Hat build of Keycloak instance running in the keycloak namespace listening at port 8080. 

**A kuadrant Red Hat build of Keycloak realm. **

An OAuth2 client with Direct Access grant enabled. 

**A user john who is assigned the member role and has the password p. **

**A user jane who is assigned the member and admin roles and has the password p. **

Prerequisites 

*  namespace: <user_apps> *spec: *#... *  patterns:     "member-role":     - selector: auth.identity.realm_access.roles       operator: incl       value: member     "admin-role":     - selector: auth.identity.realm_access.roles       operator: incl       value: admin   authorization:     "rbac-resources-api":       when: **      - cel: "http.path.matches('^/resources(/.)?$')" patternMatching: patterns: - patternRef: member-role "rbac-delete-resource": when: - cel: "http.path.matches('^/resources/\\\\d+$') && http.method == 'DELETE'" patternMatching: patterns: - patternRef: admin-role "rbac-admin-api": when: - cel: "http.path.matches('^/admin(/.)?$')" **      patternMatching:         patterns:         - patternRef: admin-role 

You installed Connectivity Link on one or more clusters. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

**You created a Gateway object. **

**You created an HTTPRoute or GRPCRoute object. **

**You configured an AuthPolicy CR with role-based-access. **

Procedure 

**1. Get an access token from within the cluster for the user John, who is assigned to the member **role, by running the following command: 

NOTE 

If your Red Hat build of Keycloak server is reachable from outside the cluster, you **can get the token directly. Make sure that the hostname set in the OIDC issuer endpoint configured in the AuthPolicy CR matches the one used to get the **token and is reachable from within the cluster. 

2. Retrieve your cluster base domain and assign it to an environment variable by running the following command: 

**3. As John, send a GET request to /resources by running the following command: **

Example output 

**4. As John, send a DELETE request to /resources/123 by running the following command: **

Example output 

$ ACCESS_TOKEN=$(oc run token --attach --rm --restart=Never -q --image=curlimages/curl -- https://keycloak.keycloak.svc.cluster.local:8080/realms/kuadrant/protocol/openid-connect/token -s -d 'grant_type=password' -d 'client_id=demo' -d 'username=john' -d 'password=p' -d 'scope=openid' | jq -r .access_token) 

$ export CLUSTER_DOMAIN=$(oc get ingress.config/cluster -o jsonpath='{.spec.domain}') 

$ curl -H "Authorization: Bearer $ACCESS_TOKEN" https://api.$CLUSTER_DOMAIN/resources -i 

HTTP/1.1 200 OK 

$ curl -H "Authorization: Bearer $ACCESS_TOKEN" -X DELETE https://api.$CLUSTER_DOMAIN/resources/123 -i 

HTTP/1.1 403 Forbidden 

**5. As John, send a GET request to /admin/settings by running the following command: **

Example output 

**6. Get an access token from within the cluster for the user Jane, who is assigned to the member and admin roles by running the following command: **

**7. As Jane, send a GET request to /resources by running the following command: **

Example output 

**8. As Jane, send a DELETE request to /resources/123 by running the following command: **

Example output 

**9. As Jane, send a GET request to /admin/settings by running the following command: **

Example output 

$ curl -H "Authorization: Bearer $ACCESS_TOKEN" https://api.$CLUSTER_DOMAIN/admin/settings -i 

HTTP/1.1 403 Forbidden 

$ ACCESS_TOKEN=$(oc run token --attach --rm --restart=Never -q --image=curlimages/curl -- http://keycloak.keycloak.svc.cluster.local:8080/realms/kuadrant/protocol/openid-connect/token -s -d 'grant_type=password' -d 'client_id=demo' -d 'username=jane' -d 'password=p' -d 'scope=openid' | jq -r .access_token) 

$ curl -H "Authorization: Bearer $ACCESS_TOKEN" https://api.$CLUSTER_DOMAIN/resources -i 

HTTP/1.1 200 OK 

$ curl -H "Authorization: Bearer $ACCESS_TOKEN" -X DELETE https://api.$CLUSTER_DOMAIN/resources/123 -i 

HTTP/1.1 200 OK 

$ curl -H "Authorization: Bearer $ACCESS_TOKEN" https://api.$CLUSTER_DOMAIN/admin/settings -i 

HTTP/1.1 200 OK 

### CHAPTER 6. CONFIGURE AND DEPLOY THE PLANPOLICY EXTENSION

**With a PlanPolicy extension, you can define different service tiers, or plans, with their associated rate **limits and automatically categorize authenticated users into these plans. 

IMPORTANT 

The PlanPolicy extension for Connectivity Link is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features offer early access to upcoming product features, enabling customers to test functionality and give feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

6.1. PLANPOLICY FOR TIERED SERVICE OFFERINGS 

**You can use a PlanPolicy object to implement tiered service offerings where different users receive **different rate limits based on their subscription plan or other attributes. 

NOTE 

**The PlanPolicy object uses the spec.plans.limits parameter to enforce rate limits at **the plan tier level instead of the individual subscriber level. 

**A PlanPolicy works in conjunction with AuthPolicy and RateLimitPolicy custom resources (CRs) in the **following sequence: 

**1. An AuthPolicy CR authenticates a user request with stored identity metadata, including their **plan information. 

**2. The PlanPolicy object evaluates CEL predicate expressions against the authenticated identity **to determine the user’s plan tier. 

3. Connectivity Link then enforces the rate limits defined for the user-matched plan tier. 

**The PlanPolicy object has the following known limitations: **

**A PlanPolicy object can only target HTTPRoute, GRPCRoute, and Gateway custom resources defined in the same namespace as the PlanPolicy object. **

Plan predicates are evaluated in order. More specific predicates must appear before more general ones to ensure correct plan assignment. 

Plan identification requires authentication to be configured through an AuthPolicy. 

6.1.1. Create an AuthPolicy with API key authentication 

**You can configure API key authentication on an HTTPRoute object by deploying an AuthPolicy custom **resource (CR) and creating per-plan API key secrets, so that Connectivity Link can identify which ratelimiting plan applies to each request. 

Prerequisites 

You installed Connectivity Link. 

**You installed OpenShift CLI (oc). **

You are logged in to your cluster. 

**You created the HTTPRoute object for your deployment. **

NOTE 

**A PlanPolicy can target an HTTPRoute, GRPCRoute, or Gateway custom resource **(CR). 

Procedure 

**1. Create an AuthPolicy CR that targets the HTTPRoute object and enables API key **authentication by using the following example: 

**Example API key AuthPolicy CR **

***Replace <sample_app> with the name of your application. ***

**Replace $KUADRANT_DEVELOPER_NS with the namespace for the object. **

**The spec.rules.authentication."api-key-plan".apiKey.selector.matchLabels field value *****points to the API key Secrets objects that carry the app: <sample_app> label. ***

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <sample_app> *  namespace: ${KUADRANT_DEVELOPER_NS} spec:   targetRef:     group: gateway.networking.k8s.io     kind: HTTPRoute *    name: <sample_app> *  rules:     authentication:       "api-key-plan":         apiKey:           selector:             matchLabels: *              app: <sample_app> *          allNamespaces: true         credentials:           authorizationHeader:             prefix: APIKEY 

**Setting spec.rules.rules.authentication."api-key-plan".apiKey.selector.allNamespaces: true allows secrets from any namespace to be matched. **

2. Apply the policy by running the following command: 

***Replace <authpolicy.yaml> with the name of your YAML. ***

6.1.2. Verify the acceptance of the AuthPolicy CR 

**You can confirm the acceptance of the AuthPolicy custom resource (CR) by running a command. **

Procedure 

**1. Confirm that the AuthPolicy CR was accepted by checking its status by running the following **command: 

***Replace <sample_app> with the name of your application. ***

**Replace $(KUADRANT_DEVELOPER_NS) with the namespace for the object. **

Example output 

6.1.3. Create API key Secret objects 

You can create API key 'Secret` objects for each plan tier. 

IMPORTANT 

**The following example creates API key Secret objects for each plan tier that you want to **use. The following example uses API keys to authenticate the requests. Other options, such as OpenID Connect, might be more appropriate for production use. Use the "leastaccess" approach that is best for your use case. 

Procedure 

**1. Create API key Secret objects for each plan tier that you want to use. Each Secret must carry the authorino.kuadrant.io/managed-by: authorino label and a secret.kuadrant.io/plan-id **annotation that identifies the plan tier as shown in the following example: 

**Example Secret object for plan tiers **

*$ oc apply -f <authpolicy.yaml> *

*$ oc get authpolicy <sample_app> -n $(KUADRANT_DEVELOPER_NS) -o *jsonpath='{.status.conditions[?(@.type=="Accepted")].message}{"\n"}{.status.conditions[? (@.type=="Enforced")].message}' 

AuthPolicy has been accepted AuthPolicy has been successfully enforced 

apiVersion: v1 kind: Secret metadata: 

Replace 'KUADRANT_DEVELOPER_NS' with the namespace for the object. 

***Replace <sample_app> with the name of your application. ***

***Replace <gold_key>, <silver_key>, and <bronze_key> with the actual API keys for each ***tier. 

***Replace <gold_api_key_value>, <silver_api_key_value>, and <bronze_api_key_value> ***with the actual API key strings you want to assign to each tier. 

**2. Apply the Secret objects by running the following command: **

***Replace <secrets.yaml> with the name of your YAML. ***

*  name: <gold_key> *  namespace: ${KUADRANT_DEVELOPER_NS}   labels:     authorino.kuadrant.io/managed-by: authorino *    app: <sample_app> *  annotations:     secret.kuadrant.io/plan-id: gold stringData: *  api_key: <gold_api_key_value> *type: Opaque ---apiVersion: v1 kind: Secret metadata: *  name: <silver_key> *  namespace: ${KUADRANT_DEVELOPER_NS}   labels:     authorino.kuadrant.io/managed-by: authorino *    app: <sample_app> *  annotations:     secret.kuadrant.io/plan-id: silver stringData: *  api_key: <silver_api_key_value> *type: Opaque ---apiVersion: v1 kind: Secret metadata: *  name: <bronze_key> *  namespace: ${KUADRANT_DEVELOPER_NS}   labels:     authorino.kuadrant.io/managed-by: authorino *    app: <sample_app> *  annotations:     secret.kuadrant.io/plan-id: bronze stringData: *  api_key: <bronze_api_key_value> *type: Opaque 

*$ oc apply -f <secrets.yaml> *

6.1.4. Verify the presence of the API key secrets 

You can confirm the presence of the API key secrets by running a few commands. 

Procedure 

1. Confirm that all three API key secrets are present in the gateway namespace by running the following command: 

**Replace ${KUADRANT_DEVELOPER_NS} with the developer namespace for **Connectivity Link. 

***Replace <sample_app> with the name of your application. ***

Example output 

bronze_key   Opaque   1      2 mins gold_key     Opaque   1      2 mins silver_key   Opaque   1      2 mins 

2. Send a request without an API key and confirm that it is rejected by running the following command: 

***Replace <gateway_hostname> with the hostname for your API. ***

Example output 

3. Send a request with a valid API key and confirm that it succeeds by running the following command: 

***Replace <gold_api_key_value> with the actual API key string. ***

***Replace <gateway_hostname> with the hostname for your API. ***

Example output 

6.1.5. Deploy plan-based rate limiting with a PlanPolicy 

**After you create your AuthPolicy and Secret objects, you can create a PlanPolicy object to enforce **tiered rate limits on specific authenticated users. 

*$ oc get secrets -n ${KUADRANT_DEVELOPER_NS} -l app=<sample_app> *

*$ curl http://<gateway_hostname>/toy -i *

HTTP/1.1 401 Unauthorized 

*$ curl -H "Authorization: <gold_api_key_value>" http://<gateway_hostname>/toy -i *

HTTP/1.1 200 OK 

NOTE 

**You can create a PlanPolicy object by using the Connectivity Link web console plugin. **

Prerequisites 

You installed Connectivity Link 

**You installed OpenShift CLI (oc). **

You are logged in to your cluster. 

**You created the HTTPRoute object for your deployment. **

You configured API key-based authentication. 

NOTE 

**A PlanPolicy can target an HTTPRoute, GRPCRoute, or Gateway custom resource **(CR). 

Procedure 

**1. Create a PlanPolicy object to enforce plan-based rate limits on the HTTPRoute object by **using the following example: 

**Example PlanPolicy object **

apiVersion: extensions.kuadrant.io/v1alpha1 kind: PlanPolicy metadata: *  name: <sample_app> *  namespace: ${KUADRANT_DEVELOPER_NS} spec:   targetRef:     group: gateway.networking.k8s.io     kind: HTTPRoute *    name: <sample_app> *  plans:     - tier: gold       predicate: |         has(auth.identity) && auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "gold"       limits:         daily: 5     - tier: silver       predicate: |         has(auth.identity) && auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "silver"       limits:         daily: 2     - tier: bronze       predicate: |         has(auth.identity) && auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == 

NOTE 

**The PlanPolicy object uses the spec.plans.limits parameter to enforce rate **limits at the plan tier level instead of the individual subscriber level. 

***Replace <sample_app> with the name of your application. ***

Replace 'KUADRANT_DEVELOPER_NS' with the namespace for your object. 

**Each spec.plans.predicate is a CEL expression. The predicates are evaluated in order, and **the first matching plan is applied to the authenticated user. 

NOTE 

The Common Expression Language (CEL) expressions can be anything that applies to your use case. You can use an expression different from the **secret.kuadrant.io/plan-id expression. **

**The limits field supports the following windows: daily, weekly, monthly, yearly, and custom. Custom limits take a limit value and a window duration string, for example: **

**2. Apply the PlanPolicy object by running the following command: **

***Replace <planpolicy.yaml> with the name of your YAML. ***

6.1.6. Verify the acceptance of the PlanPolicy CR 

**You can confirm the acceptance of the PlanPolicy custom resource (CR) by running a command. **

Procedure 

**1. Confirm that the PlanPolicy CR is accepted by running the following command: **

***Replace <sample_app> with the name of your application. ***

"bronze"       limits:         daily: 1 

limits:   daily: 100   weekly: 500   monthly: 2000   custom:     - limit: 10       window: "1m" 

*$ oc apply -f  <planpolicy.yaml> *

*$ oc get planpolicy <sample_app> -n ${KUADRANT_DEVELOPER_NS} -o *jsonpath='{.status.conditions[?(@.type=="Accepted")].message}{"\n"}{.status.conditions[? (@.type=="Enforced")].message}' 

**Replace ${KUADRANT_DEVELOPER_NS} with the namespace for your object. **

Example output 

6.1.7. Verify the PlanPolicy enforcement of ratelimiting 

**You can verify that rate limiting is enforced by the PlanPolicy object by running several commands. **

Procedure 

**1. Confirm that the AuthConfig object was updated with plan data from the PlanPolicy object by **running the following command: 

***Replace <kuadrant_system> with the namespace where your Connectivity Link instance is ***deployed. 

The output is expected to include plan information in the response section of the **AuthConfig object. **

2. Send a request without an API key and confirm that it is rejected by running the following command: 

***Replace <gateway_hostname> with the hostname for your API. ***

Example output 

**3. Send a request using the bronze-tier API key and confirm that it succeeds by running the **following command: 

***Replace <bronze_api_key_value> with the actual API key string. ***

***Replace <gateway_hostname> with the hostname for your API. ***

Example output 

**4. Send a second request using the bronze-tier API key and confirm that it is rate limited by **running the following command: 

PlanPolicy has been accepted PlanPolicy has been successfully enforced 

*$ oc get authconfig -n <kuadrant_system> -o yaml *

*$ curl <gateway_hostname>/toy -i *

HTTP/1.1 401 Unauthorized 

*$ curl -H 'Authorization: <bronze_api_key_value>' <gateway_hostname>/toy -i *

HTTP/1.1 200 OK 

*$ curl -H 'Authorization: <bronze_api_key_value>' <gateway_hostname>/toy -i *

***Replace <bronze_api_key_value> with the actual API key string. ***

***Replace <gateway_hostname> with the hostname for your API. ***

Example output 

**5. Confirm that the gold-tier key allows up to 5 requests per day before the limit is enforced. **

6.2. PLANPOLICY CUSTOM RESOURCE PARAMETERS 

**Understand the configuration parameters available for the PlanPolicy custom resource so that you can **use the object effectively. 

Table 6.1. PlanPolicy custom resource configuration fields definitions table 

Parameter Description 

**spec.targetRef A reference to an existing Gateway API resource. A PlanPolicy object **can target a Gateway, HTTPRoute, or GRPCRoute. The target resource **must be in the same namespace as the PlanPolicy object. **

**spec.plans **An ordered list of plan definitions. Plans are evaluated in sequence and **the first plan whose predicate evaluates to true is applied. More specific **predicates must appear before more general ones. 

**spec.plans.tier A unique string identifier for the plan tier, for example gold, silver, or bronze. **

**spec.plans.predicate **Specifies a Common Expression Language (CEL) expression evaluated against the authenticated request context. 

**spec.plans.limits **Specifies the rate limiting configuration for the tier. 

6.2.1. Target an HTTPRoute in a PlanPolicy 

**When a PlanPolicy object targets an HTTPRoute custom resource (CR), you can use the following **example to enforce the plan-based rate limits on all traffic flowing through that specific route. 

**Example enforcement of plan-based rate limits on HTTPRoute CR traffic **

HTTP/1.1 429 Too Many Requests 

apiVersion: extensions.kuadrant.io/v1alpha1 kind: PlanPolicy metadata: *  name: <sample_app> *  namespace: ${KUADRANT_DEVELOPER_NS} spec:   targetRef:     group: gateway.networking.k8s.io     kind: HTTPRoute 

***Replace <sample_app> with the name of your application. ***

**Replace ${KUADRANT_DEVELOPER_NS} with the namespace for your object. **

NOTE 

The Common Expression Language (CEL) expressions can be anything that applies to your use case. You can use an expression different from the **secret.kuadrant.io/plan-id expression. **

6.2.2. Target a GRPCRoute in a PlanPolicy 

**When a PlanPolicy object targets a GRPCRoute custom resource (CR), you can use the following **example to enforce the plan-based rate limits on all traffic flowing through that specific route: 

**Example enforcement of plan-based rate limits on GRPCRoute CR traffic **

*    name: <sample_app> *  plans:     - tier: gold       predicate: |         has(auth.identity) && auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "gold"       limits:         daily: 1000         weekly: 5000     - tier: silver       predicate: |         has(auth.identity) && auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "silver"       limits:         daily: 500         weekly: 2000     - tier: bronze       predicate: |         has(auth.identity) && auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "bronze"       limits:         daily: 100         weekly: 500 

apiVersion: extensions.kuadrant.io/v1alpha1 kind: PlanPolicy metadata: *  name: <sample_app> *  namespace: ${KUADRANT_DEVELOPER_NS} spec:   targetRef:     group: gateway.networking.k8s.io     kind: GRPCRoute *    name: <sample_app> *  plans:     - tier: gold       predicate: |         has(auth.identity) && auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "gold"       limits:         daily: 1000 

***Replace <sample_app> with the name of your application. ***

**Replace {KUADRANT_DEVELOPER_NS} with the namespace for your object. **

NOTE 

The Common Expression Language (CEL) expressions can be anything that applies to **your use case. You can use an expression different from the secret.kuadrant.io/plan-id **expression. 

6.2.3. Target a Gateway in a PlanPolicy 

**When a PlanPolicy object targets a Gateway custom resource (CR), Connectivity Link enforces the plan-based rate limits on all routes attached to that Gateway CR, as shown in the following example. **

Example enforcement of plan-based rate limits on a Gateway 

***Replace <sample_app> with the name of the application. ***

**Replace ${KUADRANT_GATEWAY_NS} with the namespace for the Gateway object **

6.2.4. Plan predicates in PlanPolicies 

Plan predicates are CEL expressions that determine which plan tier applies to a request. Connectivity **Link evaluates predicates in the order they appear in spec.plans and selects the first plan whose predicate returns true. **

        weekly: 5000     - tier: silver       predicate: |         has(auth.identity) && auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "silver"       limits:         daily: 500         weekly: 2000     - tier: bronze       predicate: |         has(auth.identity) && auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "bronze"       limits:         daily: 100         weekly: 500 

apiVersion: extensions.kuadrant.io/v1alpha1 kind: PlanPolicy metadata: *  name: <sample_app> *  namespace: ${KUADRANT_GATEWAY_NS} spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway     name: _<sample_app>   plans: *    # ... *

The following patterns are supported: 

Plan identified by an annotation on the API key Secret 

Plan identified by a JWT claim 

Plan identified by multiple conditions 

**The has(auth.identity) check at the start of each predicate confirms that the request is authenticated **before evaluating plan-specific conditions. 

6.2.5. Plan limits for PlanPolicies 

**The limits field in each plan definition sets the maximum number of requests allowed within each time **window. All fields are optional. Specify only the windows relevant to your use case. 

Field Description 

**daily **Maximum requests per calendar day. 

**weekly **Maximum requests per calendar week. 

**monthly **Maximum requests per calendar month. 

**yearly **Maximum requests per calendar year. 

**custom One or more custom windows. Each entry requires a limit (integer) and a window (duration string, for example "1h" or "1m"). **

The following example shows a plan snippet using all available limit types: 

predicate: |   has(auth.identity) && auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "gold" 

predicate: |   has(auth.identity) && auth.identity.sub == "premium-user" 

predicate: |   has(auth.identity) &&   auth.identity.metadata.annotations["secret.kuadrant.io/plan-id"] == "gold" &&   auth.identity.metadata.labels["app"] == "my-app" 

*#... *limits:   daily: 1000   weekly: 5000   monthly: 20000   yearly: 200000   custom: 

6.3. ADDITIONAL RESOURCES 

Using the Red Hat Connectivity Link web console 

    - limit: 100       window: "1h" *#... *