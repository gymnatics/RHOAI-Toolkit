# Red_Hat_Connectivity_Link-1.4-Update_Red_Hat_Connectivity_Link-en-US.pdf

- Red Hat Connectivity Link 1.4

# Update Red Hat Connectivity Link

Update Red Hat Connectivity Link 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 Update Red Hat Connectivity Link

Update Red Hat Connectivity Link

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

Learn how to update Red Hat Connectivity Link.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. UPDATE CONNECTIVITY LINK 1.4 1.1. SUPPORTED CONFIGURATIONS WITH CONNECTIVITY LINK 

1.1.1. Supported OpenShift Container Platform version configurations 1.1.2. Supported Operators 1.1.3. Supported cloud providers 1.1.4. Supported cloud DNS providers 1.1.5. Supported on-premise DNS providers 1.1.6. Supported data stores for rate limiting 1.1.7. Supported identity access management 

1.2. UPDATE CONNECTIVITY LINK WITH THE OPENSHIFT CONTAINER PLATFORM WEB CONSOLE 1.3. UPDATE TO CONNECTIVITY LINK 1.4 IN THE WEB CONSOLE 1.4. ADDITIONAL RESOURCES 

3 3 3 3 4 4 4 4 5 5 5 6 

### CHAPTER 1. UPDATE CONNECTIVITY LINK 1.4

You can update your Red Hat Connectivity Link from one version to the next if your supported configuration meets the requirements of the version you want to update to. 

IMPORTANT 

Use the latest version: Install or upgrade to Red Hat Connectivity Link 1.4.1 or later. 

Deprecation notice: Red Hat Connectivity Link 1.4.0 is deprecated. OpenShift Container Platform clusters running Connectivity Link 1.4.0 might experience authentication failures, API key management errors, gateway instability, or gateway pod memory pressure because of integration changes that are not fully compatible on all supported OpenShift Container Platform and OpenShift Service Mesh combinations. 

1.1. SUPPORTED CONFIGURATIONS WITH CONNECTIVITY LINK 

Connectivity Link must run on a supported combination of OpenShift Container Platform and use the cert-manager Operator for Red Hat OpenShift. 

To configure observability, use Red Hat OpenShift Service Mesh. 

Red Hat provides both production and development support for supported configurations and tested integrations according to your subscription agreement. 

IMPORTANT 

If you use a configuration that includes OpenShift Container Platform 4.18 or older, you must also use Red Hat OpenShift Service Mesh as the Gateway API provider. 

1.1.1. Supported OpenShift Container Platform version configurations 

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

1.1.2. Supported Operators 

Red Hat Connectivity Link Red Hat OpenShift Service Mesh cert-manager Operator for Red Hat OpenShift 

Version 1.4 3.4 1.19, 1.20 

Version 1.3 3.2 1.18 

Version 1.2 3.1 1.17 

1.1.3. Supported cloud providers 

All versions of Connectivity Link support the following platforms as backing cloud providers for OpenShift Container Platform: 

Amazon Web Services 

Google Cloud Platform 

Microsoft Azure 

For more information, see the documentation for your chosen cloud provider. 

1.1.4. Supported cloud DNS providers 

For DNS policies, all supported versions of Connectivity Link support the following cloud DNS providers: 

Amazon Route 53 

Google Cloud Platform DNS 

Microsoft Azure DNS 

For more information, see the documentation for your chosen cloud DNS provider. 

1.1.5. Supported on-premise DNS providers 

You can use CoreDNS can to configure an on-cluster DNS zone. For more information, see Using onpremise DNS with CoreDNS. 

1.1.6. Supported data stores for rate limiting 

For rate limiting policies, Connectivity Link supports the following Redis-based data stores for rate limit counters in multicluster environments: 

Red Hat Connectivity Link Redis Enterprise or Cloud 

Amazon ElastiCache 

Dragonfly Community or Cloud 

1.4 8.6.2 latest 1.39.0 

1.3 latest latest latest 

1.2 latest latest latest 

Red Hat Connectivity Link Redis Enterprise or Cloud 

Amazon ElastiCache 

Dragonfly Community or Cloud 

For more information, see the documentation for your chosen Redis-based datastore. 

1.1.7. Supported identity access management 

For authentication policies, Connectivity Link supports API keys and the following product versions: 

Red Hat Connectivity Link Red Hat build of Keycloak 

1.4 26.7 

1.3 26.4 

1.2 26.4 

For more information, see Supported Configurations for Red Hat build of Keycloak . 

1.2. UPDATE CONNECTIVITY LINK WITH THE OPENSHIFT CONTAINER PLATFORM WEB CONSOLE 

You can update from Connectivity Link 1.3.x to Connectivity Link 1.4 by using the OpenShift Container Platform web console. Make sure that the OpenShift Container Platform version you have is compatible with the Connectivity Link version you want to update to. See the Red Hat Connectivity LInk Life Cycle Policy for details about version support and OpenShift Container Platform compatibility. 

IMPORTANT 

On OpenShift Container Platform 4.19 or later, if you are updating your cluster from a previous OpenShift Container Platform version that contains Gateway API Custom Resource Definitions (CRDs), you must ensure that these resources exactly match the Gateway API version supported by OpenShift Container Platform 4.19. For more information, see the OpenShift documentation on managing Gateway API resources . 

1.3. UPDATE TO CONNECTIVITY LINK 1.4 IN THE WEB CONSOLE 

Update your Red Hat Connectivity Link with the OpenShift Container Platform web console. 

Prerequisites 

You already have Connectivity Link 1.3.x installed on OpenShift Container Platform 4.19 or later. 

Procedure 

1. Click Ecosystem > Installed Operators > Red Hat Connectivity Link. 

**2. Ensure that the Update channel is set to stable. **

3. If Update approval is set to Automatic, the update is installed immediately. 

4. If Update approval is set to Manual, click Install. 

5. Wait until the Connectivity Link Operator is deployed. 

6. Verify that Connectivity Link 1.4 is installed and that your deployment is up and running. 

1.4. ADDITIONAL RESOURCES 

Updating installed Operators 