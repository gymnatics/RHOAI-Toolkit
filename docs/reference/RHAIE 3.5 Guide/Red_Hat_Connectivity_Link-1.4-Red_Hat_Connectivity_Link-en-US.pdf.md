# Red_Hat_Connectivity_Link-1.4-Red_Hat_Connectivity_Link-en-US.pdf

- Red Hat Connectivity Link 1.4

# Red Hat Connectivity Link

Multicloud application connectivity and API management 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 Red Hat Connectivity Link

Multicloud application connectivity and API management

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

This guide provides an overview of the main features, technologies, benefits, and user workflows that are available with Red Hat Connectivity Link.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. ABOUT CONNECTIVITY LINK 1.1. ABOUT RED HAT CONNECTIVITY LINK 1.2. SUPPORTED CONFIGURATIONS WITH CONNECTIVITY LINK 

1.2.1. Supported OpenShift Container Platform version configurations 1.2.2. Supported Operators 1.2.3. Supported cloud providers 1.2.4. Supported cloud DNS providers 1.2.5. Supported on-premise DNS providers 1.2.6. Supported data stores for rate limiting 1.2.7. Supported identity access management 

1.3. ADDITIONAL RESOURCES 

3 3 4 5 5 5 5 6 6 6 6 

### CHAPTER 1. ABOUT CONNECTIVITY LINK

Red Hat Connectivity Link is a control plane for configuring the Gateway API data plane in OpenShift Container Platform clusters. You can use it to apply authentication, rate limiting, and DNS policies to gateway resources. 

1.1. ABOUT RED HAT CONNECTIVITY LINK 

Connect, secure, and observe all of your service endpoints by using Connectivity Link in multicloud and hybrid cloud environments. 

Apply policies to standard Gateway API resources in OpenShift Container Platform clusters by using Connectivity Link and remove the need to embed networking code into your applications. This enables an infrastructure-as-code approach to ingress traffic management and protocol support. 

**You can use OpenShift Service Mesh 3.4 or configure the OpenShift istio controller as the Gateway **API provider. 

**You can use an istio controller by enabling the Gateway API. To enable Gateway API, you must create a GatewayClass object that specifies the openshift.io/gateway-controller/v1 controller name. See **"Enable Gateway API for the Ingress Operator" in the Additional resources section for the procedure. 

IMPORTANT 

If you want to use Connectivity Link with mTLS enabled, or keep control over your Istio **configuration, you must deploy OpenShift Service Mesh 3.4 and apply your own Istio CR and IstioCNI CRs. **

User workflows 

Connectivity Link supports role-based access control tailored to specific responsibilities, for example: 

Platform or infrastructure providers 

Cluster administrators 

Application developers and API managers 

Automatic updates 

Connectivity Link consists of the following four Operators bundled into a single catalog: 

The Connectivity Link Operator manages policy attachment and Gateway API integration. 

The Authorino Operator handles authentication and authorization. 

The Limitador Operator manages rate-limiting. 

The DNS Operator manages multi-cluster DNS. 

The Connectivity Link Operator declares the other three Operators as dependencies through Operator Lifecycle Manager (OLM). This installation type means that updates are automatic. 

Example policy types 

**Configure Gateway objects with TLS policies for the following uses: **

Certificate management 

Authentication 

Authorization 

Rate limiting 

Integrate DNS policies for the following uses: 

Multicluster load balancing 

Health checks 

Remediation 

Observability 

Monitor your environment by using dashboards, metrics, tracing, and alerts, for example: 

Observability dashboards 

Observability metrics 

Tracing 

Alerts 

Connectivity Link combines state metrics, component metrics, and standard Envoy metrics to provide template alerts and dashboards. 

API management 

Use the OpenShift Container Platform web console plugin to manage APIs, for example: 

API security and governance 

API-level policies for authentication, authorization, and rate limiting 

1.2. SUPPORTED CONFIGURATIONS WITH CONNECTIVITY LINK 

Connectivity Link must run on a supported combination of OpenShift Container Platform and use the cert-manager Operator for Red Hat OpenShift. 

To configure observability, use Red Hat OpenShift Service Mesh. 

Red Hat provides both production and development support for supported configurations and tested integrations according to your subscription agreement. 

IMPORTANT 

If you use a configuration that includes OpenShift Container Platform 4.18 or older, you must also use Red Hat OpenShift Service Mesh as the Gateway API provider. 

1.2.1. Supported OpenShift Container Platform version configurations 

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

1.2.2. Supported Operators 

Red Hat Connectivity Link Red Hat OpenShift Service Mesh cert-manager Operator for Red Hat OpenShift 

Version 1.4 3.4 1.19, 1.20 

Version 1.3 3.2 1.18 

Version 1.2 3.1 1.17 

1.2.3. Supported cloud providers 

All versions of Connectivity Link support the following platforms as backing cloud providers for OpenShift Container Platform: 

Amazon Web Services 

Google Cloud Platform 

Microsoft Azure 

For more information, see the documentation for your chosen cloud provider. 

1.2.4. Supported cloud DNS providers 

For DNS policies, all supported versions of Connectivity Link support the following cloud DNS providers: 

Amazon Route 53 

Google Cloud Platform DNS 

Microsoft Azure DNS 

For more information, see the documentation for your chosen cloud DNS provider. 

1.2.5. Supported on-premise DNS providers 

You can use CoreDNS can to configure an on-cluster DNS zone. For more information, see Using onpremise DNS with CoreDNS. 

1.2.6. Supported data stores for rate limiting 

For rate limiting policies, Connectivity Link supports the following Redis-based data stores for rate limit counters in multicluster environments: 

Red Hat Connectivity Link Redis Enterprise or Cloud 

Amazon ElastiCache 

Dragonfly Community or Cloud 

1.4 8.6.2 latest 1.39.0 

1.3 latest latest latest 

1.2 latest latest latest 

For more information, see the documentation for your chosen Redis-based datastore. 

1.2.7. Supported identity access management 

For authentication policies, Connectivity Link supports API keys and the following product versions: 

Red Hat Connectivity Link Red Hat build of Keycloak 

1.4 26.7 

1.3 26.4 

1.2 26.4 

For more information, see Supported Configurations for Red Hat build of Keycloak . 

1.3. ADDITIONAL RESOURCES 

Red Hat Connectivity Link 

Gateway API with OpenShift Container Platform networking 

Enable Gateway API for the Ingress Operator 

Red Hat OpenShift Service Mesh 3.3 installation 