# Red_Hat_Connectivity_Link-1.4-Install_Connectivity_Link-en-US.pdf

- Red Hat Connectivity Link 1.4

# Install Connectivity Link

Single cluster and multicluster deployments 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 Install Connectivity Link

Single cluster and multicluster deployments

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

This guide describes how to install Connectivity Link components on OpenShift in single-cluster and multicluster environments.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. INSTALL ON OPENSHIFT CONTAINER PLATFORM 1.1. GET READY TO INSTALL CONNECTIVITY LINK 

1.1.1. Required platforms and components 1.1.2. Optional components 1.1.3. Supported configurations with Connectivity Link 

1.1.3.1. Supported OpenShift Container Platform version configurations 1.1.3.2. Supported Operators 1.1.3.3. Supported cloud providers 1.1.3.4. Supported cloud DNS providers 1.1.3.5. Supported on-premise DNS providers 1.1.3.6. Supported data stores for rate limiting 1.1.3.7. Supported identity access management 

1.2. INSTALL CONNECTIVITY LINK WITH THE OPENSHIFT CONTAINER PLATFORM WEB CONSOLE 1.3. INSTALL CONNECTIVITY LINK ON OPENSHIFT CONTAINER PLATFORM FROM THE CLI 1.4. INSTALL CONNECTIVITY LINK ON OPENSHIFT CONTAINER PLATFORM FROM THE CLI WITH ISTIO AS THE GATEWAY CONTROLLER 1.5. CONFIGURE DNS PROVIDER CREDENTIALS FOR AWS 1.6. CONFIGURE GOOGLE DNS PROVIDER CREDENTIALS 1.7. CONFIGURE AZURE DNS PROVIDER CREDENTIALS 1.8. CONFIGURE REDIS STORAGE FOR RATE LIMITING 1.9. ENABLE THE DYNAMIC PLUGIN FOR THE OPENSHIFT CONTAINER PLATFORM WEB CONSOLE 1.10. ADDITIONAL RESOURCES 

CHAPTER 2 INSTALL CONNECTIVITY LINK IN A DISCONNECTED ENVIRONMENT 2.1. ABOUT CONNECTIVITY LINK IN DISCONNECTED ENVIRONMENTS 2.2. MIRROR THE CONNECTIVITY LINK OPERATOR CATALOG 2.3. INSTALL CONNECTIVITY LINK ON OPENSHIFT CONTAINER PLATFORM FROM THE CLI 2.4. TROUBLESHOOT A CATALOG IMAGE NOT ACCESSIBLE 2.5. CHECK FOR DEPENDENT OPERATORS THAT ARE NOT INSTALLED 2.6. TROUBLESHOOT STUCK PODS IN A DISCONNECTED INSTALLATION 2.7. ADDITIONAL RESOURCES 

3 3 3 4 4 5 5 5 5 6 6 6 6 8 

11 13 15 16 18 19 

20 

21 21 21 

24 27 27 28 29 

### CHAPTER 1. INSTALL ON OPENSHIFT CONTAINER PLATFORM

You can install Connectivity Link on OpenShift Container Platform clusters to apply authentication, rate limiting, and DNS policies to gateway resources. 

IMPORTANT 

Use the latest version: Install or upgrade to Red Hat Connectivity Link 1.4.1 or later. 

Deprecation notice: Red Hat Connectivity Link 1.4.0 is deprecated. OpenShift Container Platform clusters running Connectivity Link 1.4.0 might experience authentication failures, API key management errors, gateway instability, or gateway pod memory pressure because of integration changes that are not fully compatible on all supported OpenShift Container Platform and OpenShift Service Mesh combinations. 

1.1. GET READY TO INSTALL CONNECTIVITY LINK 

As you plan your Connectivity Link install, ensure that you have access to the required platforms in your environment with the correct user permissions. You can also decide whether to use optional supported components, such as rate limiting and Observability. 

1.1.1. Required platforms and components 

The following platforms and components are required to install Connectivity Link successfully: 

Red Hat account 

You have a Red Hat account with subscriptions for Connectivity Link and OpenShift Container Platform. 

OpenShift Container Platform 

OpenShift Container Platform 4.18 or later is installed, or you have access to a supported OpenShift Container Platform cloud service. See OpenShift Container Platform installation documentation . 

IMPORTANT 

When using the Gateway API custom resource definitions (CRDs) provided in **OpenShift Container Platform 4.19 or newer, you must create a GatewayClass named openshift-default and specify a controllerName of openshift.io/gateway-controller/v1. For more details, see the Getting started with Gateway API for the **Ingress Operator (OpenShift Container Platform documentation). 

OpenShift Service Mesh 

A separate OpenShift Service Mesh installation is not required with Connectivity Link 1.3 or newer. If you use OpenShift Service Mesh, ensure that you are using 3.4 to stay in a supported configuration. 

cert-manager Operator for Red Hat OpenShift 

You installed cert-manager Operator for Red Hat OpenShift 1.18 to manage the TLS certificates for your gateways. See the cert-manager Operator for Red Hat OpenShift documentation . 

IMPORTANT 

**Before using a Connectivity Link TLSPolicy custom resource (CR), you must set up a **certificate issuer for your cloud provider platform. See the OpenShift documentation on configuring an ACME issuer. 

1.1.2. Optional components 

The following components are optional with Connectivity Link. You can decide what you want to use and plan for those configurations before beginning your installation. 

DNSPolicy 

**For a DNSPolicy CR, you must have an account for one of the supported cloud DNS providers and **have set up a hosted zone for Connectivity Link. For more details, see your cloud DNS provider documentation: 

Amazon Route 53 documentation 

Google Cloud DNS documentation 

Microsoft Azure DNS documentation 

RateLimitPolicy 

**For RateLimitPolicy CRs, you must have a shared accessible Redis-based datastore for rate-limit **counters in a multicluster environment. For details on how to install and configure a secure and highly available datastore, see the documentation for your Redis-compatible datastore: 

Redis documentation 

AWS ElastiCache (Redis OSS) User Guide 

Dragonfly documentation 

Valkey documentation 

AuthPolicy 

**For an AuthPolicy CR, you can install Red Hat build of Keycloak if required in your environment. For **more details, see the Red Hat build of Keycloak documentation . 

Observability 

For Observability, you must configure OpenShift Container Platform user workload monitoring to remote-write to a central storage system. 

1.1.3. Supported configurations with Connectivity Link 

Connectivity Link must run on a supported combination of OpenShift Container Platform and use the cert-manager Operator for Red Hat OpenShift. 

To configure observability, use Red Hat OpenShift Service Mesh. 

Red Hat provides both production and development support for supported configurations and tested integrations according to your subscription agreement. 

IMPORTANT 

If you use a configuration that includes OpenShift Container Platform 4.18 or older, you must also use Red Hat OpenShift Service Mesh as the Gateway API provider. 

1.1.3.1. Supported OpenShift Container Platform version configurations 

Red Hat Connectivity Link Red Hat OpenShift Container Platform 

Red Hat OpenShift Dedicated 

Red Hat OpenShift Service on AWS 

Microsoft Azure Red Hat OpenShift 

1.4 4.22, 4.21, 4.20, 4.19 

4.22, 4.21, 4.20, 4.19 

4.22, 4.21, 4.20, 4.19 

4.19 

1.3 4.21, 4.20, 4.19, 4.18 

4.21, 4.20, 4.19, 4.18 

4.21, 4.20, 4.19, 4.18 

4.19 

1.2 4.20, 4.19, 4.18 4.20, 4.19, 4.18 4.20, 4.19, 4.18 4.17 

For Microsoft Azure, see the Support lifecycle for Azure Red Hat OpenShift 4 . 

1.1.3.2. Supported Operators 

Red Hat Connectivity Link Red Hat OpenShift Service Mesh cert-manager Operator for Red Hat OpenShift 

Version 1.4 3.4 1.19, 1.20 

Version 1.3 3.2 1.18 

Version 1.2 3.1 1.17 

1.1.3.3. Supported cloud providers 

All versions of Connectivity Link support the following platforms as backing cloud providers for OpenShift Container Platform: 

Amazon Web Services 

Google Cloud Platform 

Microsoft Azure 

For more information, see the documentation for your chosen cloud provider. 

1.1.3.4. Supported cloud DNS providers 

For DNS policies, all supported versions of Connectivity Link support the following cloud DNS providers: 

Amazon Route 53 

Google Cloud Platform DNS 

Microsoft Azure DNS 

For more information, see the documentation for your chosen cloud DNS provider. 

1.1.3.5. Supported on-premise DNS providers 

You can use CoreDNS can to configure an on-cluster DNS zone. For more information, see Using onpremise DNS with CoreDNS. 

1.1.3.6. Supported data stores for rate limiting 

For rate limiting policies, Connectivity Link supports the following Redis-based data stores for rate limit counters in multicluster environments: 

Red Hat Connectivity Link Redis Enterprise or Cloud 

Amazon ElastiCache 

Dragonfly Community or Cloud 

1.4 8.6.2 latest 1.39.0 

1.3 latest latest latest 

1.2 latest latest latest 

For more information, see the documentation for your chosen Redis-based datastore. 

1.1.3.7. Supported identity access management 

For authentication policies, Connectivity Link supports API keys and the following product versions: 

Red Hat Connectivity Link Red Hat build of Keycloak 

1.4 26.7 

1.3 26.4 

1.2 26.4 

For more information, see Supported Configurations for Red Hat build of Keycloak . 

1.2. INSTALL CONNECTIVITY LINK WITH THE OPENSHIFT CONTAINER PLATFORM WEB CONSOLE 

You can use the OpenShift Container Platform web console to install the Red Hat Connectivity Link Operator. You must perform these steps on each OpenShift Container Platform cluster that you want to use Connectivity Link on. 

The OpenShift Container Platform Cluster Ingress Operator is the default gateway controller for Connectivity Link. 

**An OperatorGroup custom resource (CR) is created automatically when you use the web console. For **more information, see Operator Groups. 

WARNING 

**Connectivity Link requires kuadrant.io/* labels to search and filter resources on the **cluster. Do not remove labels with this prefix. Removal might cause unexpected behavior and degradation of Connectivity Link. 

Prerequisites 

You are using a supported configuration of OpenShift Container Platform and required components. 

You are logged into OpenShift Container Platform as a cluster administrator. 

**You are logged into the OpenShift Container Platform web console with cluster-admin **privileges. 

Procedure 

1. In the navigation menu, click Ecosystem > Software Catalog. 

**2. In the Filter by keyword text box, enter Connectivity to find the Red Hat Connectivity Link **Operator. 

3. Read the information about the Operator, and click Install to display the Operator subscription page. 

4. Select your subscription settings as follows: 

Update Channel: stable 

Version: 1.4.1 

Installation mode: All namespaces on the cluster (default). 

Installed namespace: Select the namespace where you want to install the Operator, for example, kuadrant-system. If the namespace does not already exist, click this field and select Create Project to create the namespace. 

Approval Strategy: Select Automatic or Manual. 

5. Click Install, and wait a few moments until the Operator is installed and ready for use. 

- 

6. Click Ecosystem > Installed Operators > Red Hat Connectivity Link. 

7. Click the Kuadrant tab, and click Create Kuadrant to create a Kuadrant custom resource (CR). 

**8. In the Configure via field, click YAML view to edit the definition, for example, the Kuadrant CR **name. 

9. Click Create and wait for the deployment to be displayed in the list. 

NOTE 

If you are using OpenShift Service Mesh, no additional configuration is required. Connectivity Link automatically detects and uses OpenShift Service Mesh as your Gateway object controller. 

Verification 

After you have installed the Operator, click Ecosystem > Installed Operators to verify that the Red Hat Connectivity Link Operator and the following component Operators are installed in your namespace: 

Authorino Operator: Enables authentication and authorization for gateways and applications in a Gateway API network. 

DNS Operator: Configures how north-south traffic from outside the network is balanced and reaches gateways. 

Limitador Operator: Enables rate limiting for gateways and applications in a Gateway API network. 

Next step 

Update your Subscription CR to use the OpenShift Container Platform Cluster Ingress Operator. 

1.3. INSTALL CONNECTIVITY LINK ON OPENSHIFT CONTAINER PLATFORM FROM THE CLI 

**You can install Connectivity Link with OpenShift CLI (oc) using the OpenShift Container Platform Cluster Ingress Operator as the default Gateway object controller. You must complete these steps on **each OpenShift Container Platform cluster that you want to use Connectivity Link on. 

WARNING 

**Connectivity Link uses labels formatted as kuadrant.io/* to search and filter **resources on the cluster. Removing of any labels with the prefix might cause unexpected behavior and degradation of Connectivity Link. 

Prerequisites 

You are logged into OpenShift Container Platform as a cluster administrator. 

- 

You are using a supported configuration of OpenShift Container Platform and required components. 

**You installed the OpenShift CLI (oc). **

Procedure 

1. Create the namespace where you want to install Connectivity Link by running the following command: 

***You can replace the default <kuadrant_system> with the namespace you want to use. ***

**2. Create the Subscription custom resource (CR) by using the following example: **

***Replace <kuadrant_system> with the namespace you created to install Connectivity Link. ***

IMPORTANT 

**For disconnected installations, you must replace the spec.source parameter value of the Subscription object with the name of the CatalogSource object created by oc-mirror. You can find the catalog source name by running the **following command: 

**3. Apply the Subscription CR by running the following command: **

**4. Create the OperatorGroup CR by using the following example: **

*$ oc create ns <kuadrant_system> *

apiVersion: operators.coreos.com/v1alpha1 kind: Subscription metadata:   name: rhcl-operator *  namespace: <kuadrant_system> *spec:   channel: stable   installPlanApproval: Automatic   name: rhcl-operator   source: redhat-operators   sourceNamespace: openshift-marketplace 

$ oc get catalogsource -n openshift-marketplace 

$ oc apply -f subscription.yaml 

apiVersion: operators.coreos.com/v1 kind: OperatorGroup metadata:   name: kuadrant *  namespace: <kuadrant_system> *spec:   upgradeStrategy: Default 

***Replace <kuadrant_system> with the namespace where you are installing Connectivity Link. ***

**5. Apply the OperatorGroup CR by running the following command: **

6. Confirm that the Connectivity Link installation has finished by running one of the following commands: 

**Expect the status of installplan.operators.coreos.com/install-<suffix> when Connectivity Link is ready. The name of the install plan has a random suffix, for example, 4rql7. **

7. Create your Connectivity Link CR by using the following example: 

***Replace <kuadrant_system> with the namespace where you installed Connectivity Link. ***

8. Optional. If you have a Red Hat Developer Hub subscription, enable the Red Hat Developer Hub plugin enabled by using the following example: 

***Replace <kuadrant_system> with the namespace where you installed Connectivity Link. ***

9. Apply the Connectivity Link CR by running the following command: 

Verification 

1. Check the status of the Connectivity Link CR generation by running the following command: 

$ oc apply -f operatorgroup.yaml 

$ oc wait --for=jsonpath={.status.installPlanRef.name} subscription rhcl-operator --timeout=10s ip=$(oc get subscription rhcl-operator -o=jsonpath={.status.installPlanRef.name}) 

$ oc wait --for=condition=Installed installplan ${ip} --timeout=60s 

apiVersion: kuadrant.io/v1beta1 kind: Kuadrant metadata:   name: kuadrant *  namespace: <kuadrant_system> *spec: {} 

apiVersion: kuadrant.io/v1beta1 kind: Kuadrant metadata:   name: kuadrant *  namespace: <kuadrant_system> *spec:   components:     developerPortal:       enabled: true *#... *

$ oc apply -f kuadrant.yaml 

***Replace <kuadrant_system> with the namespace where you installed Connectivity Link. ***

Example output 

2. Verify that all component Operator pods are running by entering the following command: 

***Replace <kuadrant_system> with the namespace where you installed Connectivity Link. ***

Example output 

3. For a disconnected installation, verify that there are no image pull errors by running the following command: 

***Replace <kuadrant_system> with the namespace where you installed Connectivity Link. ***

The output should not show image pull failures. 

NOTE 

Pod specifications still show original the image references, for example, **registry.redhat.io/redhat/… ​, even when images are pulled from your mirror **registry. The redirection happens transparently at the CRI-O level through **ImageDigestMirrorSet or ImageTagMirrorSet configuration objects. **

1.4. INSTALL CONNECTIVITY LINK ON OPENSHIFT CONTAINER PLATFORM FROM THE CLI WITH ISTIO AS THE GATEWAY CONTROLLER 

**If you are using OpenShift Service Mesh, you can install Connectivity Link with OpenShift CLI (oc) using Istio as your Gateway object controller. You must complete these steps on each OpenShift Container **Platform cluster that you want to use Connectivity Link on. 

*$ oc wait kuadrant/kuadrant --for="condition=Ready=true" -n <kuadrant_system> --*timeout=300s 

kuadrant.kuadrant.io/kuadrant Ready 

*$ oc get pods -n <kuadrant_system> *

NAME                                                READY   STATUS    RESTARTS   AGE authorino-operator-controller-manager-<hash>        2/2     Running   0          5m dns-operator-controller-manager-<hash>              2/2     Running   0          5m kuadrant-operator-controller-manager-<hash>         2/2     Running   0          7m limitador-operator-controller-manager-<hash>        2/2     Running   0          5m 

*$ oc get events -n <kuadrant_system> --field-selector reason=Failed *

WARNING 

**Connectivity Link uses labels formatted as kuadrant.io/* to search and filter **resources on the cluster. Removing of any labels with the prefix might cause unexpected behavior and degradation of Connectivity Link. 

Prerequisites 

You are logged into OpenShift Container Platform as a cluster administrator. 

You are using a supported configuration of OpenShift Container Platform and required components. 

**You installed the OpenShift CLI (oc). **

You installed and configured OpenShift Service Mesh. 

Procedure 

1. Create the namespace where you want to install Connectivity Link by running the following command: 

***You can replace the default <kuadrant_system> with the namespace you want to use. ***

2. Install Connectivity Link by running the following command: 

- 

*$ oc create ns <kuadrant_system> *

apiVersion: operators.coreos.com/v1alpha1 kind: Subscription metadata:   name: rhcl-operator   namespace: kuadrant-system spec:   channel: stable   installPlanApproval: Automatic   name: rhcl-operator   source: redhat-operators   sourceNamespace: openshift-marketplace   config:     env:     - name: ISTIO_GATEWAY_CONTROLLER_NAMES       value: istio.io/gateway-controller ---kind: OperatorGroup apiVersion: operators.coreos.com/v1 metadata:   name: kuadrant   namespace: kuadrant-system spec:   upgradeStrategy: Default 

**3. Apply the Subscription CR by running the following command: **

4. Confirm that the Connectivity Link installation has finished by running one of the following commands: 

**Expect the status of installplan.operators.coreos.com/install-<suffix> when Connectivity Link is ready. The name of the install plan has a random suffix, for example, 4rql7. **

5. Create your Connectivity Link custom resource (CR) by running the following command: 

***Replace <kuadrant_system> with the namespace you used. ***

**6. Apply the Kuadrant CR by running the following command: **

Verification 

Check the status of the Connectivity Link CR generation by running the following command: 

*Replace <kuadrant_system> with the namespace you used. *

Example output 

1.5. CONFIGURE DNS PROVIDER CREDENTIALS FOR AWS 

If you want to configure AWS DNS policies in Connectivity Link, you must configure the DNS credentials. You must perform the steps on each OpenShift Container Platform cluster that you want to use Connectivity Link on. 

You must configure a DNS hosted zone. The credentials for your DNS provider must have permissions to update DNS records within this zone. 

$ oc apply -f kuadrant-system-subscription.yaml 

$ oc wait --for=jsonpath={.status.installPlanRef.name} subscription rhcl-operator --timeout=10s ip=$(oc get subscription rhcl-operator -o=jsonpath={.status.installPlanRef.name}) 

$ oc wait --for=condition=Installed installplan ${ip} --timeout=60s 

apiVersion: kuadrant.io/v1beta1 kind: Kuadrant metadata:   name: kuadrant *  namespace: <kuadrant_system> *

$ oc apply -f kuadrant.yaml 

*$ oc wait kuadrant/kuadrant --for="condition=Ready=true" -n <kuadrant_system> --*timeout=300s 

kuadrant.kuadrant.io/kuadrant Ready 

Prerequisites 

You installed Connectivity Link on an OpenShift Container Platform cluster. 

**You have access to the namespace of your gateway, for example, api-gateway. **

NOTE 

If you already know your environment variable values, you can create the required YAML files as required for your use case. 

Procedure 

1. Optional. Set up your environment variables with the following values: 

**a. Assign the AWS_ACCESS_KEY_ID environment variable by running the following **command: 

**AWS_ACCESS_KEY_ID: is the ID from AWS with Route 53 access. **

**b. Assign the AWS_SECRET_ACCESS_KEY environment variable by running the following **command: 

**AWS_SECRET_ACCESS_KEY: is the key from AWS with Route 53 access. **

**c. Assign the AWS_REGION environment variable by running the following command: **

**AWS_REGION: specifies your region, for example, us-east-2 or eu-west-1. **

2. Create a Secret resource for your credentials as follows: 

IMPORTANT 

**You must configure the Secret in the same namespace where your Gateway **object is applied. 

Additional resources 

Amazon Route 53 documentation 

Configuring a DNS Provider - AWS IAM Permissions Required 

$ export AWS_ACCESS_KEY_ID=xxxxxxx 

$ export AWS_SECRET_ACCESS_KEY=xxxxxxx 

$ export AWS_REGION=your-aws-region 

$ oc create secret generic aws-credentials \   --namespace=api-gateway \   --type=kuadrant.io/aws \   --from-literal=AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \   --from-literal=AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \   --from-literal=AWS_REGION=$AWS_REGION 

1.6. CONFIGURE GOOGLE DNS PROVIDER CREDENTIALS 

If you want to configure DNS policies in Connectivity Link using Google Cloud, you must configure the DNS credentials. You must perform the steps on each OpenShift Container Platform cluster that you want to use Connectivity Link on. 

You must configure a DNS hosted zone. The credentials for your DNS provider must have permissions to update DNS records within this zone. 

Prerequisites 

You installed Connectivity Link on an OpenShift Container Platform cluster. 

**You have access to the namespace of your gateway, for example, api-gateway. **

NOTE 

If you already know your environment variable values, you can create the required YAML files as required for your use case. 

Procedure 

**1. Optional: Specify your GOOGLE environment variable by running the following command: **

**GOOGLE: specifies the JSON credentials generated by the gcloud CLI or by the service account. For example, $HOME/.config/gcloud/application_default_credentials.json, which **has the following credentials: 

**2. Optional: Specify your PROJECT_ID environment variable by running the following command: **

**PROJECT_ID: specifies the Google project ID. **

**3. Create a Secret resource for your credentials by running the following command: **

IMPORTANT 

You must configure the secret in the same namespace as your gateway. 

Additional resources 

Google Cloud DNS documentation 

$ export GOOGLE=xxxxxxx 

{"client_id": "***","client_secret": "***","refresh_token": "***","type": "authorized_user"} 

$ export PROJECT_ID=xxxxxxx 

$ oc create secret generic test-gcp-credentials \   --namespace=api-gateway \   --type=kuadrant.io/gcp \   --from-literal=PROJECT_ID=$PROJECT_ID \   --from-file=GOOGLE=$GOOGLE 

1.7. CONFIGURE AZURE DNS PROVIDER CREDENTIALS 

If you want to configure Microsoft Azure DNS policies in Connectivity Link, you must configure the DNS credentials. You must perform the steps on each OpenShift Container Platform cluster that you want to use Connectivity Link on. 

You must configure a DNS hosted zone. The credentials for your DNS provider must have permissions to update DNS records within this zone. 

Prerequisites 

You installed Connectivity Link on an OpenShift Container Platform cluster. 

**You have access to the namespace where your Gateway object is applied. **

NOTE 

If you already know your environment variable values, you can create the required YAML files as required for your use case. 

Procedure 

1. Create a new Azure service principal for managing DNS by setting the following environment variables: 

**a. Set the DNS_NEW_SP_NAME environment variable by running the following command: **

***Replace <kuadrantDnsPrincipal> with your service principal. ***

**b. Set the DNS_SP environment variable by running the following command: **

**c. Set the DNS_SP_APP_ID environment variable by running the following command: **

**d. Set the NS_SP_PASSWORD environment variable by running the following command: **

For more details on service principals, see the Service principal object. 

2. Set the resource group environment variable by running the following command: 

***Replace <ExampleDNSResourceGroup> with the DNS resource group that you want to use. ***

3. To grant read and contributor access to the zones that you want managed for the service principal you are using, perform the following steps: 

*$ export DNS_NEW_SP_NAME=<kuadrantDnsPrincipal> *

$ export DNS_SP=$(az ad sp create-for-rbac --name $DNS_NEW_SP_NAME) 

$ export DNS_SP_APP_ID=$(echo $DNS_SP | jq -r '.appId') 

$ export DNS_SP_PASSWORD=$(echo $DNS_SP | jq -r '.password') 

*$ export DNS_RESOURCE_GROUP=<ExampleDNSResourceGroup> *

a. Fetch the DNS ID used to grant access to the service principal by running the following command: 

***Replace <example.com> with your DNS zone domain name. ***

b. Get your resource group ID by running the following command: 

c. Give reader access to the resource group by running the following command: 

d. Give contributor access to the DNS zone by running the following command: 

4. Because you are setting up advanced traffic rules for geographic and weighted responses, you must also grant traffic manager and DNS zone access by running the following commands: 

a. Create the role assignment for the traffic manager contributor by running the following command: 

b. Create the role assignment for the DNS zone contributor by running the following command: 

c. Configure the DNS zone access by running the following command: 

5. Create a Secret resource for your credentials by running the following command: 

*$ DNS_ID=$(az network dns zone show --name <example.com> \ * --resource-group $DNS_RESOURCE_GROUP --query "id" --output tsv) 

$ RESOURCE_GROUP_ID=$(az group show --resource-group $DNS_RESOURCE_GROUP | jq ".id" -r) 

$ az role assignment create --role "Reader" --assignee $DNS_SP_APP_ID --scope $DNS_ID 

$ az role assignment create --role "Contributor" --assignee $DNS_SP_APP_ID --scope $DNS_ID 

$ az role assignment create --role "Traffic Manager Contributor" --assignee $DNS_SP_APP_ID --scope $RESOURCE_GROUP_ID 

$ az role assignment create --role "DNS Zone Contributor" --assignee $DNS_SP_APP_ID --scope $RESOURCE_GROUP_ID 

$ cat <<-EOF > /local/path/to/azure.json {   "tenantId": "$(az account show --query tenantId -o tsv)",   "subscriptionId": "$(az account show --query id -o tsv)",   "resourceGroup": "$DNS_RESOURCE_GROUP",   "aadClientId": "$DNS_SP_APP_ID",   "aadClientSecret": "$DNS_SP_PASSWORD" } EOF 

$ oc create secret generic test-azure-credentials \ 

IMPORTANT 

**You must configure the Secret in the same namespace where your Gateway **object is applied. 

Additional resources 

Microsoft Azure DNS documentation 

1.8. CONFIGURE REDIS STORAGE FOR RATE LIMITING 

To configure persistence for rate limit counters in a multicluster environment, you must configure the connection details for your shared Redis-based datastore. This datastore makes shared rate limit counters for the Limitador Operator component of Connectivity Link persistent. 

IMPORTANT 

You must configure connection details for your shared Redis-based datastore on each OpenShift Container Platform cluster that you want to use Connectivity Link for rate limiting. 

Prerequisites 

You installed Connectivity Link on one or more clusters. 

You have a shared Redis-based datastore. 

**You installed the OpenShift CLI (oc). **

You have write access to the OpenShift Container Platform namespaces you need to work with. 

You have access to external or on-premise DNS. 

**You created a Gateway object. **

**You configured your policies and HTTP routes. **

Procedure 

1. Set the following environment variable to your shared Redis-based instance URL: 

Include the appropriate URI scheme for your environment, for example: 

**Secure Redis: rediss:// **

**Standard Redis: redis:// **

2. Create a Secret resource for your Redis URL as follows: 

  --namespace=api-gateway \   --type=kuadrant.io/azure \   --from-file=azure.json=/local/path/to/azure.json 

$ export REDIS_URL=rediss://user:xxxxxx@some-redis.com:10340 

3. Update your Limitador custom resource to use the Secret that you created as follows: 

Additional resources 

Redis documentation 

Valkey documentation 

AWS ElastiCache (Redis OSS) User Guide 

Dragonfly documentation 

1.9. ENABLE THE DYNAMIC PLUGIN FOR THE OPENSHIFT CONTAINER PLATFORM WEB CONSOLE 

You can use the Connectivity Link dynamic plugin to view and manage your gateways and policies in the OpenShift Container Platform web console. You must perform these steps on each OpenShift Container Platform cluster. 

Prerequisites 

You are using a supported configuration of OpenShift Container Platform and required components. 

You are logged into OpenShift Container Platform as a cluster administrator. 

You are logged into the OpenShift Container Platform web console with administrator access. 

Procedure 

1. In the navigation menu, select the Administrator perspective. 

2. Click Home > Overview. 

3. In the Status panel, click Dynamic Plugins > View all. 

4. On the Console plugins tab, find the kuadrant-console-plugin entry in the table, which should be listed but disabled. 

5. In the kuadrant-console-plugin row, click Disabled. 

6. Select the Enable option, and click Save. 

$ oc -n kuadrant-system create secret generic redis-config \   --from-literal=URL=$REDIS_URL 

$ oc patch limitador limitador --type=merge -n kuadrant-system -p ' spec:   storage:     redis:       configSecretRef:         name: redis-config ' 

7. Wait for the plugin status to change to Loaded. 

Verification 

1. Refresh the OpenShift Container Platform web console. A new Connectivity Link menu item is displayed in the navigation sidebar. 

a. You can click Connectivity Link > Overview to explore the available resources and to get started with creating a Gateway and configuring policies in the OpenShift Container Platform web console. 

Next steps 

**Create a Gateway object. **

Create policies. 

1.10. ADDITIONAL RESOURCES 

OpenShift Operators 

### CHAPTER 2. INSTALL CONNECTIVITY LINK IN A DISCONNECTED ENVIRONMENT

You can use Connectivity Link in a disconnected environment to apply the speed and automation of cloud-like traffic management within your private, secure network. 

IMPORTANT 

Use the latest version: Install or upgrade to Red Hat Connectivity Link 1.4.1 or later. 

Deprecation notice: Red Hat Connectivity Link 1.4.0 is deprecated. OpenShift Container Platform clusters running Connectivity Link 1.4.0 might experience authentication failures, API key management errors, gateway instability, or gateway pod memory pressure because of integration changes that are not fully compatible on all supported OpenShift Container Platform and OpenShift Service Mesh combinations. 

IMPORTANT 

Disconnected installation is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features offer early access to upcoming product features, enabling customers to test functionality and give feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

2.1. ABOUT CONNECTIVITY LINK IN DISCONNECTED ENVIRONMENTS 

You can do many tasks on isolated clusters when you use Connectivity Link as a disconnected gateway. For example, securely route traffic, limit request rates, and handle automatic failover. You can also manage internal network policies, security rules, and automate TLS certificates. 

Install Connectivity Link Operators in disconnected OpenShift Container Platform environments by **mirroring the Operator catalog and images to your internal registry. Use the oc-mirror tool to perform **the following actions, in order: 

1. Mirror the Red Hat Operator catalog containing the Connectivity Link Operator package to your local registry. 

2. Configure your OpenShift Container Platform cluster to use the mirrored catalog. 

3. Install the Connectivity Link Operator using Operator Lifecycle Manager (OLM). 

2.2. MIRROR THE CONNECTIVITY LINK OPERATOR CATALOG 

To begin your disconnected Connectivity Link installation, you must mirror the Red Hat Operator catalog to your disconnected environment. By mirroring, you are making a complete local copy of Connectivity Link on a private container registry that your isolated cluster can reach. 

NOTE 

**Applying ImageDigestMirrorSet or ImageTagMirrorSet objects triggers MachineConfig object updates and restarts cluster nodes. **

If you want to use the Connectivity Link Red Hat Developer Hub plugin in your disconnected environment, you must also mirror the OCI images. 

IMPORTANT 

With Connectivity Link on OpenShift Container Platform 4.19 and newer, you can **configure the OpenShift istio controller as the Gateway API provider to manage gateway **traffic. You do not need to install OpenShift Service Mesh. However, the underlying Istio container images remain a hard dependency. In a disconnected environment, ensure that you mirror these images alongside your cluster image set configuration. Istio images are not included in the Connectivity Link Operator catalog. 

Prerequisites 

You have a supported-version, disconnected OpenShift Container Platform cluster. 

You configured a mirror registry. 

**You have access to registry.redhat.io on an internet-connected workstation. **

**You have credentials for your mirror registry configured in ${HOME}/.docker/config.json. **

**You have either an ImageDigestMirrorSet or ImageTagMirrorSet object configured for **platform images. 

**You installed the oc-mirror CLI tool for mirroring operator catalogs. **

Procedure 

**1. On your internet-connected workstation, create an ImageSetConfiguration file named rhcl-imageset-config.yaml by using the following example: **

**Example ImageSetConfiguration YAML **

**In the mirror.operators.catalog parameter, specify the Red Hat Operator catalog version **matching your OpenShift Container Platform cluster version. 

apiVersion: mirror.openshift.io/v2alpha1 kind: ImageSetConfiguration mirror:   operators:   - catalog: registry.redhat.io/redhat/redhat-operator-index:v4.22     packages:     - name: rhcl-operator     - name: authorino-operator     - name: limitador-operator     - name: dns-operator   additionalImages:   - name: registry.redhat.io/rhcl-1/coredns-rhel9:<vX.Y.Z> 

**Optional. The value of the mirror.additionalImages.name parameter is the dns-operator Operator version. Set this value if you want to use the Core DNS Operator. Replace vX.Y.Z **with the version matching the Connectivity Link Operator release. 

2. Mirror the catalog to a local directory by running the following command: 

**This command downloads the catalog and Operator images to the rhcl-mirror directory. **

**3. Transfer the rhcl-mirror directory to your disconnected environment using removable media. **

4. On a host in the disconnected environment that has access to your mirror registry, push the images to the registry by running the following command: 

***Replace <mirror_registry:port> with the path and port to your mirror registry. ***

**5. Apply either or both the ImageDigestMirrorSet and ImageTagMirrorSet files to configure the **cluster to use the mirrored images by running the following commands: 

**a. Apply the ImageDigestMirrorSet by running the following command: **

**b. Apply the ImageTagMirrorSet by running the following command: **

NOTE 

**The oc-mirror tool generates these manifests based on how you reference **your images in the mirrored Operators. 

**6. Wait for the MachineConfigPool object to update by running the following command: **

Example output 

**7. From your disconnected cluster, apply the generated CatalogSource manifest by running the **following command: 

***Replace <cs-redhat-operator-index-v4-21.yaml> with the manifest filename. ***

$ oc mirror --v2 --config rhcl-imageset-config.yaml file://./rhcl-mirror 

$ oc mirror --v2 --config rhcl-imageset-config.yaml \   --from file://./rhcl-mirror \ *  docker://<mirror_registry:port> *

$ oc apply -f results-*/cluster-resources/idms-oc-mirror.yaml 

$ oc apply -f results-*/cluster-resources/itms-oc-mirror.yaml 

$ oc wait mcp --all --for=condition=Updated --timeout=30m 

machineconfigpool.machineconfiguration.openshift.io/master condition met machineconfigpool.machineconfiguration.openshift.io/worker condition met 

*$ oc apply -f cluster-resources/<cs-redhat-operator-index-v4-21.yaml> *

8. Wait for the Operator catalog to be ready by running the following command: 

Example output 

2.3. INSTALL CONNECTIVITY LINK ON OPENSHIFT CONTAINER PLATFORM FROM THE CLI 

**You can install Connectivity Link with OpenShift CLI (oc) using the OpenShift Container Platform Cluster Ingress Operator as the default Gateway object controller. You must complete these steps on **each OpenShift Container Platform cluster that you want to use Connectivity Link on. 

WARNING 

**Connectivity Link uses labels formatted as kuadrant.io/* to search and filter **resources on the cluster. Removing of any labels with the prefix might cause unexpected behavior and degradation of Connectivity Link. 

Prerequisites 

You are logged into OpenShift Container Platform as a cluster administrator. 

You are using a supported configuration of OpenShift Container Platform and required components. 

**You installed the OpenShift CLI (oc). **

Procedure 

1. Create the namespace where you want to install Connectivity Link by running the following command: 

***You can replace the default <kuadrant_system> with the namespace you want to use. ***

**2. Create the Subscription custom resource (CR) by using the following example: **

$ oc wait catalogsource -n openshift-marketplace --all --for=condition=Ready --timeout=5m 

catalogsource.operators.coreos.com/cs-redhat-operator-index-v4-21 condition met 

- 

*$ oc create ns <kuadrant_system> *

apiVersion: operators.coreos.com/v1alpha1 kind: Subscription metadata:   name: rhcl-operator *  namespace: <kuadrant_system> *spec:   channel: stable 

***Replace <kuadrant_system> with the namespace you created to install Connectivity Link. ***

IMPORTANT 

**For disconnected installations, you must replace the spec.source parameter value of the Subscription object with the name of the CatalogSource object created by oc-mirror. You can find the catalog source name by running the **following command: 

**3. Apply the Subscription CR by running the following command: **

**4. Create the OperatorGroup CR by using the following example: **

***Replace <kuadrant_system> with the namespace where you are installing Connectivity Link. ***

**5. Apply the OperatorGroup CR by running the following command: **

6. Confirm that the Connectivity Link installation has finished by running one of the following commands: 

**Expect the status of installplan.operators.coreos.com/install-<suffix> when Connectivity Link is ready. The name of the install plan has a random suffix, for example, 4rql7. **

7. Create your Connectivity Link CR by using the following example: 

  installPlanApproval: Automatic   name: rhcl-operator   source: redhat-operators   sourceNamespace: openshift-marketplace 

$ oc get catalogsource -n openshift-marketplace 

$ oc apply -f subscription.yaml 

apiVersion: operators.coreos.com/v1 kind: OperatorGroup metadata:   name: kuadrant *  namespace: <kuadrant_system> *spec:   upgradeStrategy: Default 

$ oc apply -f operatorgroup.yaml 

$ oc wait --for=jsonpath={.status.installPlanRef.name} subscription rhcl-operator --timeout=10s ip=$(oc get subscription rhcl-operator -o=jsonpath={.status.installPlanRef.name}) 

$ oc wait --for=condition=Installed installplan ${ip} --timeout=60s 

apiVersion: kuadrant.io/v1beta1 kind: Kuadrant 

***Replace <kuadrant_system> with the namespace where you installed Connectivity Link. ***

8. Optional. If you have a Red Hat Developer Hub subscription, enable the Red Hat Developer Hub plugin enabled by using the following example: 

***Replace <kuadrant_system> with the namespace where you installed Connectivity Link. ***

9. Apply the Connectivity Link CR by running the following command: 

Verification 

1. Check the status of the Connectivity Link CR generation by running the following command: 

***Replace <kuadrant_system> with the namespace where you installed Connectivity Link. ***

Example output 

2. Verify that all component Operator pods are running by entering the following command: 

***Replace <kuadrant_system> with the namespace where you installed Connectivity Link. ***

Example output 

metadata:   name: kuadrant *  namespace: <kuadrant_system> *spec: {} 

apiVersion: kuadrant.io/v1beta1 kind: Kuadrant metadata:   name: kuadrant *  namespace: <kuadrant_system> *spec:   components:     developerPortal:       enabled: true *#... *

$ oc apply -f kuadrant.yaml 

*$ oc wait kuadrant/kuadrant --for="condition=Ready=true" -n <kuadrant_system> --*timeout=300s 

kuadrant.kuadrant.io/kuadrant Ready 

*$ oc get pods -n <kuadrant_system> *

NAME                                                READY   STATUS    RESTARTS   AGE authorino-operator-controller-manager-<hash>        2/2     Running   0          5m dns-operator-controller-manager-<hash>              2/2     Running   0          5m kuadrant-operator-controller-manager-<hash>         2/2     Running   0          7m limitador-operator-controller-manager-<hash>        2/2     Running   0          5m 

3. For a disconnected installation, verify that there are no image pull errors by running the following command: 

***Replace <kuadrant_system> with the namespace where you installed Connectivity Link. ***

The output should not show image pull failures. 

NOTE 

Pod specifications still show original the image references, for example, **registry.redhat.io/redhat/… ​, even when images are pulled from your mirror **registry. The redirection happens transparently at the CRI-O level through **ImageDigestMirrorSet or ImageTagMirrorSet configuration objects. **

2.4. TROUBLESHOOT A CATALOG IMAGE NOT ACCESSIBLE 

**If your CatalogSource object shows a READY=False status, the catalog image is not accessible from **your mirror registry. You can check pod logs and check that the catalog image exists to troubleshoot this situation. 

Prerequisites 

You completed a disconnected installation of Connectivity Link. 

Procedure 

1. Check the catalog pod logs by running the following command: 

**Make sure you use the information that was created by the oc mirror tool to run this command. **

2. Verify that the catalog image exists in the mirror registry by running the following command: 

***Replace <mirror_registry> with the path to your mirror registry. ***

2.5. CHECK FOR DEPENDENT OPERATORS THAT ARE NOT INSTALLED 

**If you only see the Connectivity Link Operator ClusterServiceVersion, but the Authorino, Limitador, or **DNS Operators are missing, the catalog might be missing digest references or the dependencies are not declared. You can track the source of the problem by checking a couple of resources. 

Prerequisites 

You completed a disconnected installation of Connectivity Link. 

*$ oc get events -n <kuadrant_system> --field-selector reason=Failed *

$ oc logs -n openshift-marketplace -l olm.catalogSource=cs-redhat-operator-index-v{ocp-latest-version} 

*$ oc image info <mirror_registry>/redhat/redhat-operator-index:v{ocp-latest-version} *

Procedure 

**1. Verify that all of the required Operators are available as PackageManifest resources by running **the following command: 

2. If any packages are missing, the catalog was not mirrored or applied correctly. Check that the **catalog is ready and running with no errors and that the ImageSetConfiguration is created **correctly. 

**3. Check that the InstallPlan shows all dependencies by running the following command: **

***Replace <kuadrant_system> with the namespace in which you installed Connectivity Link. ***

**Look for all required Operators in the InstallPlan specification output. **

**4. If an Operator is missing, check the InstallPlan for errors or re-mirror the catalog. **

2.6. TROUBLESHOOT STUCK PODS IN A DISCONNECTED INSTALLATION 

**If your pods are stuck with an ImagePullBackOff status, this might mean that the image is either not in the mirror registry or that the ImageDigestMirrorSet object not applied correctly. **

Prerequisites 

You completed a disconnected installation of Connectivity Link. 

Procedure 

**1. Verify that ImageDigestMirrorSet exists by running the following command: **

2. Check whether the specific image was mirrored by running the following command: 

***Replace <mirror_registry> with the path to your mirror registry. ***

***Replace <digest> with the complete digest value. ***

3. Check pod events by running the following command: 

***Replace <pod_name> with the name of the stuck pod. ***

***Replace <kuadrant_system> with the namespace in which you installed Connectivity Link. ***

$ oc get packagemanifest -n openshift-marketplace | grep -E '(rhcl|authorino|limitador|dns)-operator' 

*$ oc get installplan -n <kuadrant_system> -o yaml *

$ oc get imagedigestmirrorset 

*$ oc image info <mirror_registry>/rhcl-1/rhcl-operator@sha256:_<digest>_ *

*$ oc describe pod <pod_name> -n <kuadrant_system> *

2.7. ADDITIONAL RESOURCES 

Managing image settings 

Managing custom catalogs 

Disconnected installation overview 

Using Operator Lifecycle Manager in disconnected environments 

Mirroring an image set in a fully disconnected environment 