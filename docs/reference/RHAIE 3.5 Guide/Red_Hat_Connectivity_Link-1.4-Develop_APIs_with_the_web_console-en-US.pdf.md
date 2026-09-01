# Red_Hat_Connectivity_Link-1.4-Develop_APIs_with_the_web_console-en-US.pdf

- Red Hat Connectivity Link 1.4

# Develop APIs with the web console

Developing APIs with the OpenShift web console 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 Develop APIs with the web console

Developing APIs with the OpenShift web console

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

This document gives you the instructions how to use the OpenShift web console with your Connectivity Link deployments.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. USE THE OPENSHIFT CONTAINER PLATFORM WEB CONSOLE 1.1. ABOUT USING THE OPENSHIFT WEB CONSOLE 1.2. ENABLE THE CONNECTIVITY LINK OPENSHIFT CONTAINER PLATFORM CONSOLE PLUGIN 1.3. ENABLE THE CONNECTIVITY LINK RED HAT DEVELOPER HUB CONSOLE PLUGIN 

CHAPTER 2 CREATE, SHARE, AND CONSUME APIS ACROSS TEAMS 2.1. API MANAGEMENT PAGES IN THE WEB CONSOLE 

2.1.1. API management custom resource definitions 2.2. API MANAGEMENT AUTHENTICATION METHODS 

2.2.1. API key authentication 2.2.2. OIDC and JWT authentication 

2.3. PUBLISH AN API FOR OTHER TEAMS TO DISCOVER AND CONSUME 2.4. INTEGRATE WITH AN API PUBLISHED BY ANOTHER TEAM 2.5. CONTROL WHO CAN ACCESS YOUR PUBLISHED API 2.6. API MANAGEMENT ROLE-BASED-ACCESS REFERENCE 

2.6.1. Cluster roles 2.6.2. Role binding requirements 2.6.3. Verify the API consumer access role 2.6.4. Verify the API owner access role 2.6.5. Verify the API administrator access role 

CHAPTER 3 USE THE RED HAT DEVELOPER HUB PLUGIN 3.1. MANAGE APIS THROUGH RED HAT DEVELOPER HUB 

3.1.1. API catalog integration in Red Hat Developer Hub 3.1.2. Enable API catalog integration in Red Hat Developer Hub 

3.1.2.1. Configure the application settings 3.1.2.2. Create role-based access for Red Hat Developer Hub 3.1.2.3. Configure the Backstage custom resource 

3.1.3. Confirm that developers can discover and access APIs 3.1.4. Customize RBAC policies 

3.1.4.1. Red Hat Developer Hub plugin RBAC policy reference 3.1.4.1.1. Default roles 3.1.4.1.2. RBAC policy format 

3.1.5. Additional resources 

3 3 4 4 

7 7 8 9 9 9 

10 12 14 16 17 19 21 22 23 

24 24 24 24 28 30 32 33 34 34 34 35 36 

### CHAPTER 1. USE THE OPENSHIFT CONTAINER PLATFORM WEB CONSOLE

You can manage Connectivity Link resources and develop API products by using the OpenShift Container Platform web console. 

1.1. ABOUT USING THE OPENSHIFT WEB CONSOLE 

The OpenShift Container Platform web console is available after your Connectivity Link installation on OpenShift Container Platform 4.19 and newer is complete, but you must enable the plugin. 

OpenShift Container Platform 4.20 and newer 

**After you enable the web console, you can use it to see the status of your Gateway and route **objects, create and manage policies, and create and manage APIs. 

OpenShift Container Platform 4.19 

**You can use the web console to see the status of your Gateway, route objects, and policies. You can create Gateway objects, routes, and policies, but you cannot manage APIs. **

IMPORTANT 

UI elements are either displayed or hidden, and either active or disabled, based on your Kubernetes role-based-access (RBAC) permissions. For example: 

Cluster administrators are cluster-scoped and can see all of the features in the web console. 

Developers and API owners are namespace-scoped. Developers and API owners must configure roles to grant access to specific workflows, such as browsing the API catalog, requesting API keys, or approving access requests. 

In the navigation menu, use the Connectivity Link section to select one of the following pages as available for your role: 

**Overview: A dashboard showing Gateway objects, policies and their status, and HTTPRoute and GRPCRoutes across the cluster. If you have permissions, you can also create, edit, and delete custom resources (CRs), including Gateway CRs. **

**Policies: A tabbed list of all Connectivity Link policy types, such as AuthPolicy, RateLimitPolicy, DNSPolicy, and TLSPolicy CRs. If you have permissions, you can also create, edit, and delete policy **CRs. 

API Products: You can search for, create, and edit API products according to your permissions. 

**Policy Topology: A visual graph of the relationships between Gateway and HTTPRoute objects and the **policies attached to them. 

If you are on OpenShift Container Platform 4.20 or newer, on the navigation menu, use the Connectivity Link API Catalog section to select one of the following pages as available for your role: 

API Key Approvals: A list of API key requests and their status. 

My API Keys: A list of your approved API keys. 

1.2. ENABLE THE CONNECTIVITY LINK OPENSHIFT CONTAINER PLATFORM CONSOLE PLUGIN 

If you did not enable the Connectivity Link OpenShift Container Platform web console plugin for installation, you can enable it to access API management features later. You can skip this procedure if you enabled the OpenShift web console during Connectivity Link installation. 

Prerequisites 

You have installed Connectivity Link. 

**You have access to your OpenShift Container Platform cluster as a user with the cluster-admin **role. 

Procedure 

1. In the OpenShift Container Platform web console, navigate to Administration → Cluster Settings. 

2. Click the Configuration tab. 

3. In the Configuration resource list, click Console operator.config.openshift.io. 

4. Click the Console plugins tab. 

**5. In the Console plugins section, locate the kuadrant-console-plugin entry. **

6. Click the toggle to enable the plugin. The console reloads automatically. 

Verification 

1. In the OpenShift Container Platform web console navigation menu, verify that the Connectivity Link section is displayed. 

2. Click Connectivity Link and verify that the following pages are available: 

API Products 

Connectivity Link API Catalog section containing: 

API Key Approvals 

My API Keys 

1.3. ENABLE THE CONNECTIVITY LINK RED HAT DEVELOPER HUB CONSOLE PLUGIN 

If you have a subscription to Red Hat Developer Hub, you can use the web console as your internal **developer portal. You must enable the Connectivity Link Red Hat Developer Hub plugin in the Kuadrant **custom resource (CR) you created during installation before you can use Red Hat Developer Hub. 

You can skip this procedure if you enabled the Red Hat Developer Hub plugin during Connectivity Link installation. 

Prerequisites 

You installed Connectivity Link. 

You have a Red Hat Developer Hub subscription. 

You are logged into OpenShift Container Platform as a cluster administrator. 

You are using a supported configuration of OpenShift Container Platform and required components. 

**You installed the OpenShift CLI (oc). **

Procedure 

1. If you have a Red Hat Developer Hub subscription, update your Connectivity Link CR with the Red Hat Developer Hub plugin enabled by using the following example: 

2. Apply the CR by running the following command: 

***Replace <kuadrant.yaml> with the name of your Connectivity Link deployment YAML. ***

Verification 

1. Check the status of the Connectivity Link CR generation by running the following command: 

***Replace <kuadrant_system> with the namespace you used. ***

Example output 

2. Check that the Red Hat Developer Hub pod is ready by running the following command: 

***Replace <kuadrant_system> with the namespace you used. ***

apiVersion: kuadrant.io/v1beta1 kind: Kuadrant metadata: *#... *spec:   components:     developerPortal:       enabled: true *#... *

*$ oc apply -f <kuadrant.yaml> *

*$ oc wait kuadrant/kuadrant --for="condition=Ready=true" -n <kuadrant_system> --*timeout=300s 

kuadrant.kuadrant.io/kuadrant Ready 

*$ oc wait pod -n <kuadrant_system> -l app=developer-portal-controller --*for=condition=Ready --timeout=120s 

Example output 

The exact random string at the end of the pod name varies based on your deployment replica set. 

pod/developer-portal-controller-7f8d69bc7b-x4z2q condition met 

### CHAPTER 2. CREATE, SHARE, AND CONSUME APIS ACROSS TEAMS

When you need to make internal APIs discoverable and control who can access them, you can publish API products in a self-service catalog where developers request access and receive credentials. API management is available when you are using the Connectivity Link OpenShift Container Platform web console plugin on OpenShift Container Platform 4.20 or newer. 

IMPORTANT 

API management with the OpenShift web console is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features offer early access to upcoming product features, enabling customers to test functionality and give feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

2.1. API MANAGEMENT PAGES IN THE WEB CONSOLE 

By using the OpenShift Container Platform web console with Connectivity Link, different users conduct various API-management tasks, depending on each user’s role-based access and requirements. 

The following examples show how you can interact with the Connectivity Link API management section of the web console: 

Everyone can explore available APIs without requesting access to them by browsing the API catalog to discover what services are available. Use the API Products page in the main Connectivity Link section **to see all of the APIProduct resources in the cluster or current namespace. **

API consumers 

Developers who need to integrate with services provided by other teams are API consumers. You can use the My API Keys page in the Connectivity Link API Catalog section to see your API key requests. Use the My API Keys page to complete the following tasks: 

Browse your requested API keys 

Retrieve your approved credentials 

View authentication requirements and service tiers 

Request access to APIs 

API owner 

You are responsible for specific services. Control how your APIs are presented and accessed through the API Products and API Key Approvals pages. You can create new API products, view and edit existing products, configure approval modes, and access detailed product information. **The API Products page is in the main Connectivity Link section and lists all of the APIProduct **resources in the cluster or current namespace. Use the API Products page to complete the following tasks: 

**Define how the API is displayed in the catalog through APIProduct resource metadata **

Choose between automatic and manual approval for access requests 

Approve or reject requests 

Set documentation links so that API consumers can self-serve 

The API Key Approvals page is in the Connectivity Link API Catalog section of the web console. Use the API Key Approvals page to complete the following tasks: 

**Review pending APIKey requests **

Approve or reject requests 

Add optional comments 

View request details 

Filter requests by status and API product 

Bulk approve or reject requests 

Revoke granted access 

API administrator 

You give cross-team oversight and governance. Use the API Key Approvals page with elevated permissions. The API Key Approvals page is in the Connectivity Link API Catalog section of the web console. Use the API Key Approvals page to complete the following tasks: 

**View and manage all of the APIProduct resources across the organization **

Approve or reject any API key request 

Ensure consistency across API products 

2.1.1. API management custom resource definitions 

You can use custom resource definitions (CRDs) to request, grant or remove access to APIs with the Connectivity Link OpenShift Container Platform web console plugin. The following list details available CRDs. 

**APIProduct **

**The APIProduct custom resource definition (CRD) wraps an existing HTTPRoute custom resource **(CR) with the business context needed for consumption, including a human-readable name, documentation links, contact information, and access policies. When an API owner creates an **APIProduct resource and sets the publishStatus field to Published, the API becomes discoverable **in the catalog. 

**APIKey **

**The APIKey CRD represents the actual API access credentials in the API consumer’s namespace. **The controller creates the CRD when an API owner approves an access request. 

**APIKeyRequest **

**An APIKeyRequest CRD is a shadow resource in the API owner namespace that enables discovery **without exposing API key values. These resources are managed by the Connectivity Link controller and you must not create or modify them manually. 

**APIKeyApproval **

**An APIKeyApproval CRD represents an approval or rejection action on an APIKeyRequest resource. API owners and administrators create APIKeyApproval resources to approve or reject **pending requests. 

2.2. API MANAGEMENT AUTHENTICATION METHODS 

You can use one of two authentication methods for protecting APIs with the Connectivity Link OpenShift Container Platform web console plugin. Configure your chosen method at the platform level **through AuthPolicy custom resources (CRs). The Connectivity Link controller automatically discovers **AuthPolicy CRs. 

2.2.1. API key authentication 

API key authentication uses Kubernetes secrets to store credentials. This method is suitable for internal APIs, development environments, or scenarios that require fine-grained control over API access. 

The following list is an example workflow: 

**1. An API consumer creates an APIKey resource requesting access to an APIProduct resource. **

**2. Depending on the APIProduct resource approvalMode field, one of the following events **happens: 

Automatic: The controller immediately approves the request. 

**Manual: The request enters Pending state, awaiting API owner approval. **

3. For manual approval, the API owner or administrator clicks Approve in the web console. 

4. After approval, credentials become available to the API consumer. 

5. The API consumer retrieves the key from the console and uses it in API requests. 

**6. The AuthPolicy CR validates incoming requests against the credentials. **

2.2.2. OIDC and JWT authentication 

OpenID Connect (OIDC) authentication delegates credential management to an external identity provider. This method is suitable for APIs with the following characteristics: 

Integrate with existing identity providers 

Require stronger authentication 

Need integration with enterprise single sign-on (SSO) systems 

**No APIKey resources are created. Access control happens at the identity provider level. **

There is no request or approval workflow in the OpenShift Container Platform web console for this authentication method, but certain parts of the authentication process are visible. The following list is an example workflow: 

**1. A cluster administrator configures an AuthPolicy resource with JWT validation pointing to an **OIDC issuer. 

2. The Connectivity Link controller discovers the JSON web token (JWT) authentication scheme and performs OIDC discovery to find the token endpoint. 

**3. Discovered authentication details are surfaced in the APIProduct resource status. **

4. An API consumer views the identity provider URL and token endpoint in the web console. 

5. The API consumer obtains a JWT token directly from the identity provider. For example, by using client credentials flow or any other available flow. 

6. The consumer uses the JWT token in API requests. 

**7. The AuthPolicy CR validates the token signature and claims against the OIDC issuer. **

IMPORTANT 

**You can create an OIDCPolicy object in the web console, but this policy is experimental **and not supported. If you want to use OIDC authentication in your Connectivity Link **deployment, use it with an AuthPolicy object. **

2.3. PUBLISH AN API FOR OTHER TEAMS TO DISCOVER AND CONSUME 

When you have an internal API that other teams need to integrate with, you can publish it in a self-service catalog. Then developers can discover it, understand how to use it, and request access with the appropriate credentials. This process is highly visible with the Connectivity Link OpenShift Container Platform web console plugin. 

Prerequisites 

You enabled the Connectivity Link OpenShift Container Platform web console plugin. 

**You created an HTTPRoute custom resource (CR) routing traffic to your API service. **

**You configured an AuthPolicy CR to protect your API. **

**You have the api-owner role bound in your namespace. **

Procedure 

1. In the OpenShift Container Platform web console, navigate to Connectivity Link → API Products. 

2. Click Create API Product. 

3. Describe your API for consumers by filling in the fields or selecting available options in the following main sections: 

API Product Info: Enter the API product’s name, version, and a description that can help other teams understand what your API does and who might want to integrate with it. 

**Add API and Associate route: Enter the URL to your API spec file, a link to your API documentation, and select an HTTPRoute object. **

TIP 

Include the following documentation types so that API consumers can self-serve: 

API reference documentation 

Getting started guides 

Code examples or client SDKs 

Support or contact information 

Lifecycle and Visibility: Choose how you want to publish your API. Published makes the API product available for discovery by API consumers. Draft keeps the API product hidden. 

API Key Approval: Choose how to manage API key requests. 

Automatic: Grant API keys immediately when requested. Use this for internal APIs where you trust all consumers. 

Manual: Review each request before approval. Use this when you need to verify use cases or limit access to specific teams. 

NOTE 

The system automatically discovers your authentication method from **the AuthPolicy CR: **

+ * For API key authentication, API consumers request API keys through the web console. * For OpenID Connect (OIDC) or JWT authentication, API consumers can look up your identity provider details and token endpoint. 

4. Click Create. 

5. Optional. After you publish your API product, click your API product from the Name tab, select the Overview tab, then scroll to the end of the page and add your contact information by selecting the pencil icon in each field. 

Verification 

1. Confirm that consumers can discover and understand your API by using the web console: 

a. Navigate to Connectivity Link → API Products and verify that your API product shows the Published status. 

b. Ask a developer from another team to browse the catalog and verify the following information: 

Your API is displayed in the catalog. 

The description clearly explains what the API does. 

Documentation links work. 

Authentication requirements are visible. 

Next steps 

Developers can now discover your API in the catalog, request access, and receive credentials. 

If you configured manual approval, you can review and approve access requests on the API Key Approvals page. 

2.4. INTEGRATE WITH AN API PUBLISHED BY ANOTHER TEAM 

**When you need to call an API owned by another team that is protected with the APIKey authentication **method, you can use the OpenShift Container Platform web console. Browse the internal API catalog and discover available services, then request access. When you are given access, you can receive the credentials in the web console that are required to authenticate your application. 

**You can select only the API products that use the APIKey authentication method. APIs that use OpenID **Connect (OIDC) authentication are available for access depending on your role defined in the **AuthPolicy custom resource. **

Prerequisites 

You enabled the Connectivity Link OpenShift Container Platform web console plugin. 

**You have the api-consumer role bound in your namespace. **

You verified that the API you need is published in the catalog. 

You are in your own namespace. 

Procedure 

1. Browse the catalog to find an API that solves your problem by using the web console: 

a. In the OpenShift Container Platform web console, navigate to Connectivity Link. 

b. Select the API Products page. 

c. Look for APIs that match your use case based on their display name and description. 

2. Request access to the API by using the web console: 

a. In the OpenShift Container Platform web console, navigate to Connectivity Link API Catalog. 

b. Select the My API Keys page. 

c. Search for and select the API Product you want in the API Product field. 

d. If the API offers multiple service tiers, for example, different rate limits, select the tier in the Tier field that matches your traffic requirements. 

e. Enter a unique name for your API key resource in the API Key Name field. 

f. Describe your use case in the Use Case field so that the API owner understands how you plan to use their service. 

g. Click Request. 

3. Wait for approval: 

If the API uses automatic approval, your request is approved immediately and credentials are available. 

**If the API requires manual approval, your request enters the Pending state. The API owner **reviews your use case and approves or rejects the request. 

4. If you are using the API key authentication method, retrieve the credentials after approval by using the web console: 

a. On the My API Keys page, click your approved API key request. 

b. In the Credentials section, click Show API Key. 

c. The credentials are accessible if the API key is approved. Accessible credentials are labeled with the Active status. 

5. Verify that your API key request is displayed in the My API Keys page with Active status. 

6. Verify that you can call the API by running the following command in your terminal window: 

***Replace the <api_key>, <api_hostname> and <api_path> API values with the ones required ***for your use case. 

7. If you are using either the OpenID Connect (OIDC) or JWT authentication method, you can use the web console to get the information needed to request a token and consume the API with the token: 

a. In the web console, navigate to the Connectivity Link → APIProducts page. 

b. Find the API product that you want. 

c. Click the option icons on the API tabs. 

d. Select Edit. 

e. On the Edit API Product page, navigate to the YAML View. 

f. Save the information that you need to request a token. 

Example identity provider URL and credentials YAML snippet 

*$ curl -H "Authorization: Bearer <api_key>" \   https://<api_hostname>/<api_path> *

status:   discoveredAuthScheme:     authentication:       <name>:         jwt:           issuerUrl: https://keycloak.example.com/realms/myrealm 

Example token endpoint URL YAML snippet 

g. Configure your application to obtain JWT tokens from the identity provider by using your credentials. For example, client credentials flow or user login flow. An API key is not required when your application uses JWT tokens to authenticate. 

8. Verify that you can call the API by running the following command in your terminal window: 

Next steps 

Integrate the API into your application. If you get errors or need help, see the API’s documentation links or contact the API owner by using the information in the API product details. 

2.5. CONTROL WHO CAN ACCESS YOUR PUBLISHED API 

You can review access requests to verify that consumers have legitimate use cases before granting credentials when you publish an API with manual approval. This helps you know who is using your API so that you can prevent unauthorized or inappropriate usage. 

Prerequisites 

You enabled the Connectivity Link OpenShift Container Platform web console plugin. 

**You have either the api-owner role bound in your namespace, or the api-admin role bound **cluster-wide. 

You published an API product with manual approval mode enabled. 

Developers have submitted access requests for your API. 

Procedure 

1. Review pending requests in the web console to understand who wants to use your API: 

a. In the OpenShift Container Platform web console, navigate to Connectivity Link API Catalog → API Key Approvals. 

b. Review the pending API key requests: 

Requester: Who submitted the request. 

        credentials:           authorizationHeader:             prefix: Bearer 

status:   oidcDiscovery:     tokenEndpoint: https://keycloak.example.com/realms/myrealm/protocol/openid-connect/token 

*$ curl -H "Authorization: Bearer <jwt_token>" \   https://<api_hostname>/<api_path> *

API Product: Which of your APIs they want to access. 

Use Case: How they plan to use the API. 

Tier: If you offer tiers, which service tier they selected. 

2. Decide whether to approve or reject based on the use case: Approve requests when: 

The use case is legitimate and appropriate for your API. 

The requester team has a valid business need. 

The selected service tier matches their usage requirements. Reject requests when: 

The use case is unclear or does not match the purpose of your API. 

The requester should use a different API or approach. 

You need more information before approving. 

3. For a single request, take action: To approve: 

a. Click the request. 

b. Review the details to confirm the use case makes sense. 

c. Click Approve. 

d. Optional: Add a comment welcoming the consumer or providing guidance. 

e. Click Confirm. To reject: 

f. Click the request. 

g. Click Deny. 

h. Add a comment explaining why the request was rejected and what the consumer should do instead (for example, "This API is for payment processing. For order status, use the Orders API"). 

i. Click Confirm. 

4. For many similar requests, use bulk actions: To bulk approve requests: 

a. Select the checkboxes for requests with similar use cases. 

b. Click Bulk Approve. 

c. Optional: Add a comment that applies to all selected requests. 

d. Click Confirm. To bulk reject requests: 

e. Select the checkboxes for requests that share the same issue. 

f. Click Bulk Deny. 

g. Add a comment explaining the rejection reason. 

h. Click Confirm. 

Verification 

1. Navigate to Connectivity Link API Catalog → API Key Approvals. 

**2. Verify that approved requests show Approved status and rejected requests show Denied **status. 

3. For approved requests, confirm that consumers can retrieve credential by asking an approved API consumer to check their My API Keys page and verify that they can view and copy their API key. 

Next steps 

Approved consumers can now call your API by using their credentials. 

Rejected consumers receive your feedback comment explaining why their request was denied and what alternative actions they should take. 

2.6. API MANAGEMENT ROLE-BASED-ACCESS REFERENCE 

Use the following references and concepts to configure role-based access control (RBAC) for API users by using predefined cluster roles and role bindings. 

API management enforces strict namespace boundaries: 

Consumer namespaces 

**Consumers manage APIKey and secret resources in their assigned namespaces only. **

Owner namespaces 

**Owners manage APIProduct and APIKeyApproval resources in their team namespaces. **

Cross-namespace references 

**APIKey resources can reference APIProduct resources in other namespaces, but consumers can create APIKey resources only in namespaces where they have role bindings. **

API key values are protected through architectural isolation by the following workflow: 

**1. The API consumer creates a Secret containing the API key value, then creates an APIKey **resource referencing that Secret. 

**2. The controller creates an APIKeyRequest shadow resource in the owner namespace and does **not contain the API key value. 

**3. The API owner creates an APIKeyApproval resource in their namespace. **

4. The controller creates an enforcement Secret in the Connectivity Link namespace, which the API consumer cannot access. 

5. API owners do not see API consumer key values. Even administrators do not have Secret-read permissions in consumer namespaces. 

2.6.1. Cluster roles 

Connectivity Link provides four predefined cluster roles for API management. When you configure **ClusterRole objects, include all of the information you need in a single role. Do not name two roles identically to add or change permissions. ClusterRole objects with the same metadata.name **parameter value conflict. 

**The api-catalog-browser role provides cluster-wide read access to API catalog resources for **discovery. This role is used by API browsers and permissions are also included in the API owner and API administrator roles. 

Example api-catalog-browser permissions 

IMPORTANT 

**The api-catalog-browser cluster role binding grants cluster-wide read access. There is **no way to limit catalog browsing to specific namespaces. All catalog browsers see all published products. 

**The api-consumer role enables API consumers to create and manage API keys in assigned namespaces. Bind this role in API consumer namespaces by using a RoleBinding resource. **

Example api-consumer permissions 

apiVersion: rbac.authorization.k8s.io/v1 kind: ClusterRole metadata:   name: api-catalog-browser rules:   - apiGroups: ["devportal.kuadrant.io"]     resources: ["apiproducts"]     verbs: ["get", "list", "watch"]   - apiGroups: ["extensions.kuadrant.io"]     resources: ["planpolicies"]     verbs: ["get", "list", "watch"]   - apiGroups: ["kuadrant.io"]     resources: ["authpolicies", "ratelimitpolicies"]     verbs: ["get", "list", "watch"]   - apiGroups: ["gateway.networking.k8s.io"]     resources: ["httproutes", "gateways"]     verbs: ["get", "list", "watch"] 

apiVersion: rbac.authorization.k8s.io/v1 kind: ClusterRole metadata:   name: api-consumer rules:   - apiGroups: ["devportal.kuadrant.io"]     resources: ["apikeys"]     verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] 

**With the api-owner role, you can publish APIs and manage consumer access requests. This role has the **following characteristics: 

Includes cluster-wide read access for catalog browsing. 

**Namespace-scoped write access for APIProduct and APIKeyApproval custom definition **resources (CRDs). 

**Owners can view APIKeyRequest custom resources (CRs), but not API consumer APIKey or **Secret resources. 

Example api-owner role permissions 

**The api-admin role gives cluster administrators cluster-wide access for management and **troubleshooting. This role has the following characteristics: 

**Same core permissions as api-owner role. but cluster-wide **

**Additional APIKey write access for troubleshooting **

Intentional limitation: No secret read permissions in consumer namespaces 

Example api-admin namespace-scoped role permissions 

  - apiGroups: [""]     resources: ["secrets"]     verbs: ["get", "list", "watch", "create", "update", "delete"] 

apiVersion: rbac.authorization.k8s.io/v1 kind: ClusterRole metadata:   name: api-owner rules:   - apiGroups: ["devportal.kuadrant.io"]     resources: ["apiproducts"]     verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]   - apiGroups: ["devportal.kuadrant.io"]     resources: ["apikeyapprovals"]     verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]   - apiGroups: ["devportal.kuadrant.io"]     resources: ["apikeyrequests"]     verbs: ["get", "list", "watch"]   - apiGroups: ["extensions.kuadrant.io"]     resources: ["planpolicies"]     verbs: ["get", "list", "watch"]   - apiGroups: ["kuadrant.io"]     resources: ["authpolicies", "ratelimitpolicies"]     verbs: ["get", "list", "watch"]   - apiGroups: ["gateway.networking.k8s.io"]     resources: ["httproutes", "gateways"]     verbs: ["get", "list", "watch"] 

apiVersion: rbac.authorization.k8s.io/v1 kind: ClusterRole metadata: 

**With api-owner permissions, you have cluster-wide permissions. You can have the apiGroups "devportal.kuadrant.io" value and the "apiproducts", "apikeyapprovals", "apikeyrequests", resources and can conduct all available actions. **

**With the apiGroups "devportal.kuadrant.io" value and the "apikeys" resources, you can complete additional troubleshooting tasks with full APIKey access and take all available actions. **

**Catalog resources are granted with all apiGroups assigned, such as "devportal.kuadrant.io", "kuadrant.io", and "gateway.networking.k8s.io", but you are limited to the "get", "list", and "watch" actions. **

2.6.2. Role binding requirements 

After you decide who can access what, you must create a role binding that assigns that list of permissions to those users. 

API consumer binding 

**API consumers require two bindings, both the ClusterRoleBinding object for api-catalog-browser-all-users permissions and a RoleBinding object for api-consumer permissions in their namespace. The RoleBinding object is required for APIKey and Secret management. Catalog browsing is cluster-wide to discover all published APIs, while APIKey and secret management is namespace-**scoped and creates team isolation. 

Example API consumer ClusterRoleBinding CR 

  name: api-admin rules:   - apiGroups: ["devportal.kuadrant.io"]     resources: ["apiproducts"]     verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]   - apiGroups: ["devportal.kuadrant.io"]     resources: ["apikeyapprovals"]     verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]   - apiGroups: ["devportal.kuadrant.io"]     resources: ["apikeyrequests"]     verbs: ["get", "list", "watch"]   - apiGroups: ["devportal.kuadrant.io"]     resources: ["apikeys"]     verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]   - apiGroups: ["devportal.kuadrant.io"]     verbs: ["get", "list", "watch"]   - apiGroups: ["kuadrant.io"]     resources: ["authpolicies", "ratelimitpolicies"]     verbs: ["get", "list", "watch"]   - apiGroups: ["gateway.networking.k8s.io"]     resources: ["httproutes", "gateways"]     verbs: ["get", "list", "watch"] 

apiVersion: rbac.authorization.k8s.io/v1 kind: ClusterRoleBinding metadata:   name: api-catalog-browser-mobile-devs roleRef:   apiGroup: rbac.authorization.k8s.io 

API owner binding 

**API owners require one role binding for api-owner in their team namespace. Owners can publish APIs in their namespace and browse the catalog cluster-wide. The api-owner cluster role includes both **namespace-scoped management and cluster-wide catalog read access. When bound through a **RoleBinding resource, write operations are namespace-scoped, while read operations are cluster-**wide. 

Example API owner RoleBinding CR 

API administrator binding 

**API administrators require one cluster role binding for api-admin. This role grants access to the API **Policies page but not the Overview page. 

Example API administrator ClusterRoleBinding CR 

  kind: ClusterRole   name: api-catalog-browser subjects: - kind: Group   name: mobile-app-developers   apiGroup: rbac.authorization.k8s.io ---apiVersion: rbac.authorization.k8s.io/v1 kind: RoleBinding metadata:   name: api-consumer-mobile-devs   namespace: consumer-team-mobile roleRef:   apiGroup: rbac.authorization.k8s.io   kind: ClusterRole   name: api-consumer subjects: - kind: Group   name: mobile-app-developers   apiGroup: rbac.authorization.k8s.io 

apiVersion: rbac.authorization.k8s.io/v1 kind: RoleBinding metadata:   name: api-owner-payments-team   namespace: api-team-payments roleRef:   apiGroup: rbac.authorization.k8s.io   kind: ClusterRole   name: api-owner subjects: - kind: Group   name: team-payments   apiGroup: rbac.authorization.k8s.io 

apiVersion: rbac.authorization.k8s.io/v1 kind: ClusterRoleBinding metadata:   name: api-admin-platform-team 

2.6.3. Verify the API consumer access role 

You can verify that your role-based-access controls are configured the way you intend by using the CLI. 

NOTE 

***You can replace --as-group with --as=<username> or --*****as=system:serviceaccount:_<namespace>_:_<name>_ as needed. **

Prerequisites 

You enabled the Connectivity Link OpenShift Container Platform web console plugin. 

**You have either the api-owner role bound in your namespace, or the api-admin role bound **cluster-wide. 

You configured other role bindings as required for your use case. 

Procedure 

1. Verify API consumer catalog browsing permissions by running the following command: 

***Replace <consumer_group> with the name of the API consumer group. ***

Example output 

**2. Verify API consumer APIKey management permissions in their namespace by running the **following command: 

***Replace <consumer_group> with the name of the API consumer group. ***

***Replace <consumer_namespace> with a the API consumer namespace. ***

Example output 

roleRef:   apiGroup: rbac.authorization.k8s.io   kind: ClusterRole   name: api-admin subjects: - kind: Group   name: platform-team   apiGroup: rbac.authorization.k8s.io 

$ oc auth can-i list apiproducts \ *  --as-group=<consumer_group> \ *  --all-namespaces 

yes 

$ oc auth can-i create apikeys \ *  --as-group=<consumer_group> \   -n <consumer_namespace> *

**3. Verify that API consumers cannot create APIKey resources in other namespaces by running the **following command: 

***Replace <consumer_group> with the name of the API consumer group. ***

***Replace <other_namespace> with a namespace that is not theirs. ***

Example output 

2.6.4. Verify the API owner access role 

You can verify that your role-based-access controls are configured the way you intend by using the CLI. 

NOTE 

***You can replace --as-group with --as=<username> or --*****as=system:serviceaccount:_<namespace>_:_<name>_ as needed. **

Prerequisites 

You enabled the Connectivity Link OpenShift Container Platform web console plugin. 

**You have the api-admin role bound cluster-wide. **

You configured other role bindings as required for your use case. 

Procedure 

**1. Verify API owner APIProduct creation permissions in their namespace by running the following **command: 

***Replace <owner_group> with the name of the API owner group. ***

***Replace <owner_namespace> with the API owner namespace. ***

Example output 

yes 

$ oc auth can-i create apikeys \ *  --as-group=<consumer_group> \   -n <other_namespace> *

no 

$ oc auth can-i create apiproducts \ *  --as-group=<owner_group> \   -n <owner_namespace> *

yes 

**2. Verify that API owners cannot access consumer APIKey resources by running the following **command: 

***Replace <owner_group> with the name of the API owner group. ***

***Replace <consumer_namespace> with the API consumer namespace. ***

Example output 

2.6.5. Verify the API administrator access role 

You can verify that your role-based-access controls are configured the way you intend by using the CLI. 

NOTE 

***You can replace --as-group with --as=<username> or --*****as=system:serviceaccount:_<namespace>_:_<name>_ as needed. **

Prerequisites 

You enabled the Connectivity Link OpenShift Container Platform web console plugin. 

**You have the api-admin role bound cluster-wide. **

You configured other role bindings as required for your use case. 

Procedure 

Verify API administrator cluster-wide access by running the following command: 

***Replace <admin_group> with the name of the API administrator group. ***

Example output 

$ oc auth can-i get apikeys \ *  --as-group=<owner_group> \   -n <consumer_namespace> *

no 

$ oc auth can-i list apikeys \ *  --as-group=<admin_group> \ *  --all-namespaces 

yes 

### CHAPTER 3. USE THE RED HAT DEVELOPER HUB PLUGIN

3.1. MANAGE APIS THROUGH RED HAT DEVELOPER HUB 

When you need to centralize API discovery and use, you can add a Connectivity Link plugin into Red Hat Developer Hub. Developers can then browse, request access to, and manage API keys for internal APIs in a single interface. 

IMPORTANT 

Red Hat Developer Hub plugin is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features offer early access to upcoming product features, enabling customers to test functionality and give feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

3.1.1. API catalog integration in Red Hat Developer Hub 

By integrating Connectivity Link with Red Hat Developer Hub, you can create a self-service API catalog that makes API use easier. When API use is easier, teams can work together more effectively. 

You can create a centralized portal where development teams can discover available APIs and understand their capabilities. Developers can request access to the APIs they want and get credentials without leaving their development workflow. You can centrally manage APIs spread across many teams and namespaces. 

To achieve these goals, you must add the Connectivity Link plugin to a Red Hat Developer Hub deployment in an OpenShift Container Platform cluster. You must then inject your Red Hat Developer **Hub configurations into your OpenShift Container Platform ConfigMap object. **

3.1.2. Enable API catalog integration in Red Hat Developer Hub 

When you want developers to discover and request access to Connectivity Link-protected APIs directly from Red Hat Developer Hub, integrate the Connectivity Link plugin. The plugin synchronizes API products into the Red Hat Developer Hub catalog and enables self-service API key management. 

**Red Hat Developer Hub pulls the plugin directly from registry.redhat.io as OCI artifacts. This method **requires a registry authentication secret in the same OpenShift Container Platform project as your Red Hat Developer Hub deployment. 

IMPORTANT 

Replace API Key features in the example dynamic plugin configuration YAML and enforce security, such as OpenID Connect (OIDC) or JSON web token (JWT) **AuthPolicy objects, for production environments. **

Prerequisites 

You installed Connectivity Link 1.4 or later on an OpenShift Container Platform cluster. 

You installed Red Hat Developer Hub on the same OpenShift Container Platform cluster. 

**You have a Red Hat account with access to registry.redhat.io. **

You have a registry service account token from the Red Hat Customer Portal. 

You have cluster privileges to configure role-based-access (RBAC) policies and service accounts. 

**You installed the OpenShift CLI (oc). **

Your organization has APIs published through Connectivity Link gateways that you want to make discoverable to development teams. 

Procedure 

**1. Create an auth.json file on your local machine with your registry.redhat.io credentials by using **the following example: 

**To generate the base64-encoded value, use the printf '%s' '<username>:<password>' | base64 command. **

2. Set the environment variable for your Red Hat Developer Hub namespace by running the following command: 

**3. Create the authentication Secret named dynamic-plugins-registry-auth in the OpenShift **Container Platform project where you installed Red Hat Developer Hub. Use one of the two following methods: 

**a. For a default Operator installation with name developer-hub, run the following command: **

IMPORTANT 

The Red Hat Developer Hub Operator specifically looks for a secret named **dynamic-plugins-registry-auth to authenticate against registry.redhat.io. **Do not change or prefix this secret name. 

b. If you already have Podman credentials configured locally, run the following command: 

{   "auths": {     "registry.redhat.io": {       "auth": "<base64-encoded-username:password>"     }   } } 

$ export RHDH_NS=rhdh 

$ oc create secret generic dynamic-plugins-registry-auth \   --from-file=auth.json=./auth.json \   -n $RHDH_NS 

IMPORTANT 

You must create the Secret before you configure your plugin. 

4. Verify that the Secret exists in your OpenShift Container Platform project by running the following command: 

5. Set the environment variable for your cluster base hostname by running the following command: 

**6. Save your full ConfigMap file as configmap.yaml by using the following example: **

Example dynamic plugin config map 

$ oc create secret generic dynamic-plugins-registry-auth \   --from-file=auth.json=${XDG_RUNTIME_DIR}/containers/auth.json \   -n $RHDH_NS 

$ oc get secret dynamic-plugins-registry-auth -n $RHDH_NS 

$ export CLUSTER_HOSTNAME=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}') 

apiVersion: v1 kind: ConfigMap metadata:   name: dynamic-plugins-rhdh   namespace: $RHDH_NS data:   dynamic-plugins.yaml: |     includes:       - dynamic-plugins.default.yaml     plugins:       - package: oci://registry.redhat.io/rhdh/kuadrant-backstage-plugin-backend-dynamic-*rhel9:bs_1.4v0.2.1!kuadrant-backstage-plugin-backend-dynamic disabled: false - package: oci://registry.redhat.io/rhdh/kuadrant-backstage-plugin-frontend-dynamic-rhel9:bs_1.4v0.2.1!kuadrant-backstage-plugin-frontend-dynamic *        disabled: false         pluginConfig:           dynamicPlugins:             frontend:               kuadrant.kuadrant-backstage-plugin-frontend:                 apiFactories:                   - importName: kuadrantApiFactory                 appIcons:                   - name: kuadrantIcon                     importName: KuadrantIcon                   - name: apiIcon                     importName: ApiIcon                   - name: keyIcon                     importName: KeyIcon                   - name: approvalIcon                     importName: ApprovalIcon                 menuItems: 

                  kuadrant.api-products:                     parent: kuadrant                   kuadrant.my-api-keys:                     parent: kuadrant                   kuadrant.api-key-approval:                     parent: kuadrant                 dynamicRoutes:                   - path: /kuadrant                     importName: KuadrantPage                     menuItem:                       icon: kuadrantIcon                       text: Kuadrant                   - path: /kuadrant/api-products                     importName: ApiProductsPage                     menuItem:                       icon: apiIcon                       text: API Products                   - path: /kuadrant/my-api-keys                     importName: MyApiKeysPage                     menuItem:                       icon: keyIcon                       text: My API Keys                   - path: /kuadrant/api-key-approval                     importName: ApiKeyApprovalPage                     menuItem:                       icon: approvalIcon                       text: API Key Approval                   - path: /kuadrant/api-products/:namespace/:name                     importName: ApiProductDetailPage                   - path: /kuadrant/api-keys/:namespace/:name                     importName: ApiKeyDetailPage                 entityTabs:                   - mountPoint: entity.page.api-keys                     path: /api-keys                     title: API Keys                   - mountPoint: entity.page.api-product-info                     path: /api-product-info                     title: API Product Info                 mountPoints:                   - mountPoint: entity.page.api-keys/cards                     importName: EntityKuadrantApiKeyManagementTab                     config:                       layout:                         gridColumn: "1 / -1"                       if:                         allOf:                           - isKind: api                   - mountPoint: entity.page.api-product-info/cards                     importName: EntityKuadrantApiProductInfoContent                     config:                       layout:                         gridColumn: "1 / -1"                       if:                         allOf:                           - isKind: api 

IMPORTANT 

Enter your Red Hat Developer Hub version of Backstage and the plugin version, **in the format bs_<backstage_version>__<plugin_version>; use the double **underscore delimiter. 

Find your Backstage version in the Red Hat Developer Hub release notes preface. 

Locate the plugin version in the Dynamic Plugins Reference . 

**7. Create the ConfigMap CR by running the following command: **

3.1.2.1. Configure the application settings 

Configure specific application settings to give access to the Connectivity Link Red Hat Developer Hub plugin. 

Prerequisites 

You enabled API catalog integration in Red Hat Developer Hub. 

You provisioned your custom Red Hat Developer Hub configuration. 

**You have auth set up in your existing app-config YAML. **

You are logged into an OpenShift Container Platform cluster with administrator privileges. 

**You installed the OpenShift CLI (oc). **

Procedure 

**1. Create a role-based access (RBAC) file, such as rbac-policy.csv, to define user roles and **permissions by using the following example: 

$ oc apply -f configmap.yaml 

p, role:default/api-consumer, kuadrant.apiproduct.read.all, read, allow p, role:default/api-consumer, kuadrant.apiproduct.list, read, allow p, role:default/api-consumer, kuadrant.apikey.create, create, allow, apiproduct:*/* p, role:default/api-consumer, kuadrant.apikey.read.own, read, allow p, role:default/api-consumer, kuadrant.apikey.update.own, update, allow p, role:default/api-consumer, kuadrant.apikey.delete.own, delete, allow p, role:default/api-consumer, catalog.entity.read, read, allow p, role:default/api-consumer, kuadrant.planpolicy.list, read, allow p, role:default/api-consumer, kuadrant.authpolicy.list, read, allow p, role:default/api-consumer, kuadrant.ratelimitpolicy.list, read, allow p, role:default/api-consumer, kuadrant.httproute.list, read, allow 

p, role:default/api-owner, kuadrant.httproute.list, read, allow p, role:default/api-owner, kuadrant.ratelimitpolicy.list, read, allow p, role:default/api-owner, kuadrant.authpolicy.list, read, allow p, role:default/api-owner, kuadrant.planpolicy.read, read, allow p, role:default/api-owner, kuadrant.planpolicy.list, read, allow p, role:default/api-owner, kuadrant.apiproduct.create, create, allow 

**api consumer: Browses APIs, requests access. **

**api owner: Publishes APIs they own, approves requests for their APIs. **

**api admin: People who manage all API products. **

**g, group:default: Assign groups to roles. **

**g, user:development/guest, role:default/api-admin: Only for development and testing. **Assigns a guest user an admin role. For production environments, remove this line and assign roles to your actual users or groups. 

**2. Create a ConfigMap object from the RBAC policy file by running the following command: **

**3. Add the RBAC policy reference to the app-config.yaml file: **

p, role:default/api-owner, kuadrant.apiproduct.read.all, read, allow p, role:default/api-owner, kuadrant.apiproduct.update.own, update, allow p, role:default/api-owner, kuadrant.apiproduct.delete.own, delete, allow p, role:default/api-owner, kuadrant.apiproduct.list, read, allow p, role:default/api-owner, kuadrant.apikey.create, create, allow, apiproduct:*/* p, role:default/api-owner, kuadrant.apikey.read.own, read, allow p, role:default/api-owner, kuadrant.apikey.update.own, update, allow p, role:default/api-owner, kuadrant.apikey.delete.own, delete, allow p, role:default/api-owner, kuadrant.apikey.approve, update, allow p, role:default/api-owner, catalog.entity.read, read, allow 

p, role:default/api-admin, kuadrant.planpolicy.read, read, allow p, role:default/api-admin, kuadrant.planpolicy.list, read, allow p, role:default/api-admin, kuadrant.authpolicy.list, read, allow p, role:default/api-admin, kuadrant.ratelimitpolicy.list, read, allow p, role:default/api-admin, kuadrant.apiproduct.create, create, allow p, role:default/api-admin, kuadrant.apiproduct.read.all, read, allow p, role:default/api-admin, kuadrant.apiproduct.update.all, update, allow p, role:default/api-admin, kuadrant.apiproduct.delete.all, delete, allow p, role:default/api-admin, kuadrant.apiproduct.list, read, allow p, role:default/api-admin, kuadrant.httproute.list, read, allow p, role:default/api-admin, kuadrant.apikey.create, create, allow, apiproduct:*/* p, role:default/api-admin, kuadrant.apikey.read.all, read, allow p, role:default/api-admin, kuadrant.apikey.update.all, update, allow p, role:default/api-admin, kuadrant.apikey.delete.all, delete, allow p, role:default/api-admin, kuadrant.apikey.approve, update, allow p, role:default/api-admin, catalog.entity.read, read, allow p, role:default/api-admin, policy.entity.read, read, allow p, role:default/api-admin, policy.entity.create, create, allow p, role:default/api-admin, policy.entity.update, update, allow p, role:default/api-admin, policy.entity.delete, delete, allow 

g, group:default/api-consumers, role:default/api-consumer g, group:default/api-owners, role:default/api-owner g, group:default/api-admins, role:default/api-admin 

g, user:development/guest, role:default/api-admin 

$ oc create configmap rbac-policy --from-file=rbac-policy.csv --namespace=$RHDH_NS 

**Make sure that the mounting path /opt/app-root/etc configured in the Backstage CR matches **the path set here. 

**4. Add the APIProduct entity type to the catalog rules by adding the following content: **

5. Optional. Add catalog locations as required by adding the following content: 

**6. Create a ConfigMap from the app-config.yaml file by running the following command: **

Verification 

**1. Verify that the ConfigMap resources exist by running the following command: **

**2. Confirm that both rhdh-app-config and rbac-policy appear in the output. **

3. Optional. Configure basic guest authentication and authorization for testing by adding the following content: 

3.1.2.2. Create role-based access for Red Hat Developer Hub 

When you want to secure developer access to Connectivity Link-protected APIs directly, create role-based-access permissions that allow Red Hat Developer Hub to manage Connectivity Link resources. 

Prerequisites 

You installed Connectivity Link 1.4 or later on an OpenShift Container Platform cluster. 

permission:   enabled: true   rbac:     policies-csv-file: /opt/app-root/etc/rbac-policy.csv     policyFileReload: true 

catalog:   rules:     - allow: [Component, System, API, APIProduct, Resource, Location] 

catalog:   locations:     - type: file       target: /opt/app-root/src/catalog-entities/all.yaml 

$ oc create configmap rhdh-app-config --from-file=app-config.yaml --namespace=$RHDH_NS 

$ oc get configmap -n $RHDH_NS 

auth:   environment: development   providers:     guest:       dangerouslyAllowOutsideDevelopment: true 

You installed Red Hat Developer Hub on the same OpenShift Container Platform cluster. 

You have cluster administrator privileges to configure role-based-access (RBAC) policies and service accounts. 

**You installed the OpenShift CLI (oc). **

Your organization has APIs published through Connectivity Link gateways that you want to make discoverable to development teams. 

Procedure 

**1. Create ClusterRole and ClusterRoleBinding custom resources (CRs) by using the following **example: 

**Example ClusterRole and ClusterRoleBinding manifests **

apiVersion: rbac.authorization.k8s.io/v1 kind: ClusterRole metadata:   name: rhcl-rhdh-plugin-role rules:   - apiGroups: ["kuadrant.io"]     resources:       - authpolicies       - ratelimitpolicies       - dnspolicies       - tlspolicies     verbs: ["get", "list", "watch"]   - apiGroups: ["extensions.kuadrant.io"]     resources:       - planpolicies     verbs: ["get", "list", "watch"]   - apiGroups: ["devportal.kuadrant.io"]     resources:       - apiproducts       - apikeys     verbs: ["get", "list", "watch", "create", "delete", "patch", "update"]   - apiGroups: ["devportal.kuadrant.io"]     resources:       - apikeyrequests     verbs: ["get", "list", "watch"]   - apiGroups: ["devportal.kuadrant.io"]     resources:       - apikeyapprovals     verbs: ["get", "list", "watch", "create", "patch", "update"]   - apiGroups: ["gateway.networking.k8s.io"]     resources:       - gateways       - httproutes     verbs: ["get", "list", "watch"]   - apiGroups: [""]     resources:       - namespaces     verbs: ["get", "list", "watch", "create"]   - apiGroups: [""] 

2. Apply the CRs by running the following command: 

Replace the filename with the one you used. 

3. Verify permissions by running the following command: 

3.1.2.3. Configure the Backstage custom resource 

**To apply your configurations in Red Hat Developer Hub, you must update your Backstage custom **resource (CR) to put all of your instructions and permissions together. 

Prerequisites 

You installed Connectivity Link 1.4 or later on an OpenShift Container Platform cluster. 

You installed Red Hat Developer Hub on the same OpenShift Container Platform cluster. 

You have cluster administrator privileges to configure role-based-access (RBAC) policies and service accounts. 

**You installed the OpenShift CLI (oc). **

Your organization has APIs published through Connectivity Link gateways that you want to make discoverable to development teams. 

Procedure 

**1. Link the dynamic plugin ConfigMap object by adding the following content: **

    resources:       - secrets     verbs: ["get", "create", "delete"] ---apiVersion: rbac.authorization.k8s.io/v1 kind: ClusterRoleBinding metadata:   name: rhcl-rhdh-plugin-binding roleRef:   apiGroup: rbac.authorization.k8s.io   kind: ClusterRole   name: rhcl-rhdh-plugin-role subjects:   - kind: ServiceAccount     name: default     namespace: ${RHDH_NS} 

*$ oc apply -f <rhdh_rbac.yaml> *

$ oc auth can-i update apikeys.devportal.kuadrant.io --as=system:serviceaccount:$RHDH_NS:default 

spec:   application:     dynamicPluginsConfigMapName: dynamic-plugins-rhdh 

**2. Link the main rhdh-app-config ConfigMap object by adding the following content: **

**3. Link the RBAC policies from the rbac-policy ConfigMap object by adding the following **content: 

**The mounting path is referenced from app-config.yaml, RBAC for the kuadrant functionality **section. Ensure they match. 

**4. Optional. Enable service account token auto mount for in-cluster mode by adding the following **content: 

3.1.3. Confirm that developers can discover and access APIs 

After you complete the integration, verify that API products appear in the Developer Hub catalog. Verify that developers can request access and generate API keys. 

Prerequisites 

You installed the Red Hat Developer Hub plugin. 

Procedure 

1. Get the Red Hat Developer Hub route URL by running the following commands: 

***The route name follows the pattern backstage-<cr_name>. The default custom resource (CR) *****name developer-hub is used in this example. **

2. Navigate to the Red Hat Developer Hub URL in your web browser. 

spec:   application:     appConfig:       mountPath: /opt/app-root/src       configMaps:          - name: rhdh-app-config 

spec:   application:     extraFiles:       mountPath: /opt/app-root/etc       configMaps:          - name: rbac-policy 

spec:   deployment:     patch:       spec:         template:           spec:             automountServiceAccountToken: true 

$ export RHDH_URL=$(oc get route backstage-developer-hub -n ${RHDH_NS} -o jsonpath='{.status.ingress[0].host}') $ echo "https://${RHDH_URL}" 

**3. Navigate to the /kuadrant endpoint to view the Connectivity Link plugin page: **

**4. Verify that APIProduct objects appear in the catalog by navigating to the catalog view. **

5. Select an API entity and verify that the Kuadrant tab is visible and displays Connectivity Link policy and configuration information. 

Verification 

You can create and manage API keys through the plugin interface based on your assigned role. 

3.1.4. Customize RBAC policies 

**You can customize RBAC policies by modifying the ConfigMap custom resource (CR) in the Red Hat **Developer Hub namespace. 

Prerequisites 

You installed the Red Hat Developer Hub plugin. 

You have cluster administrator privileges to configure role-based-access (RBAC) policies and service accounts. 

**You installed the OpenShift CLI (oc). **

Procedure 

1. Add a custom role by running the following command: 

**2. Add the following lines to the rbac-policy.csv data: **

3. After modifying the ConfigMap, restart the Red Hat Developer Hub pods for the changes to take effect by running the following command: 

***Replace <rhdh> in the command with the name of your Backstage CR. ***

3.1.4.1. Red Hat Developer Hub plugin RBAC policy reference 

The Connectivity Link Red Hat Developer Hub plugin uses role-based access control (RBAC) policies to manage user permissions for API products and API keys. 

3.1.4.1.1. Default roles 

https://${RHDH_URL}/kuadrant 

$ oc edit configmap rbac-policy -n ${RHDH_NS} 

p, role:default/api-viewer, kuadrant.apiproduct.read.all, read, allow p, role:default/api-viewer, kuadrant.apikey.read.all, read, allow g, user:default/developer1, role:default/api-viewer 

*$ oc rollout restart deployment backstage-<rhdh> -n ${RHDH_NS} *

The Connectivity Link Backstage plugin defines three default roles with different permission levels. 

api-consumer 

Users with this role can read API products and manage their own API keys and namespace-scoped Secrets. This role is suitable for developers who consume APIs. 

Read API products 

Create API keys 

Read own API keys 

Delete own API keys 

api-owner 

Users with this role can manage API products and approve and reject API keys. This role is suitable for API product managers. 

Read API products 

Create API products 

Update API products 

Delete API products 

Approve and reject API keys 

api-admin 

Users with this role have full administrative access to API products and API keys. This role is suitable for platform administrators. 

Read API products 

Create API products 

Update API products 

Delete API products 

Read API keys 

Delete API keys 

Approve and reject API keys 

3.1.4.1.2. RBAC policy format 

The RBAC policy uses the CSV format with the following structure: 

**<role_name>: The name of the role. **

p, role:default/<role_name>, kuadrant.<resource>.<permission>, <action>, <effect> g, user:default/<username>, role:default/<role_name> 

**<resource>: The resource type, such as apiproduct or apikey. **

**<permission>: The permission level, read, create, update, or delete. **

**<action>: The action type, read, create, update, or delete. **

**<effect>: Either allow or deny. **

**<username>: The user to assign to the role. **

3.1.5. Additional resources 

Install the Red Hat Developer Hub Operator (Red Hat Developer Hub documentation) 

Backstage CRD reference (Backstage documentation) 

Troubleshooting plugins (Red Hat Developer Hub documentation) 

Using config maps with applications (OpenShift documentation) 