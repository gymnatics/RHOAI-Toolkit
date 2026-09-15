# Red_Hat_Connectivity_Link-1.4-Get_support-en-US.pdf

- Red Hat Connectivity Link 1.4

# Get support

Getting support for Red Hat Connectivity Link 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 Get support

Getting support for Red Hat Connectivity Link

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

This document provides information on getting support from Red Hat Connectivity Link.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. GETTING SUPPORT 1.1. GET SUPPORT 1.2. ABOUT THE RED HAT KNOWLEDGEBASE 1.3. SEARCH THE RED HAT KNOWLEDGEBASE 1.4. SUBMIT A SUPPORT CASE 

3 3 3 3 4 

### CHAPTER 1. GETTING SUPPORT

You can get support for Red Hat Connectivity Link by searching the Red Hat Knowledgebase, submitting a support case, and using remote health monitoring tools. 

1.1. GET SUPPORT 

If you experience difficulty with a procedure described in this documentation, or with Red Hat Connectivity Link in general, visit the Red Hat Customer Portal . 

From the Customer Portal, you can: 

Search or browse through the Red Hat Knowledgebase of articles and solutions relating to Red Hat products. 

Submit a support case to Red Hat Support. 

Access other product documentation. 

If you have a suggestion for improving this documentation or find an error, submit a Jira issue  for the most relevant documentation component. Please list specific details, such as the section name and Red Hat Connectivity Link version. 

1.2. ABOUT THE RED HAT KNOWLEDGEBASE 

The Red Hat Knowledgebase provides content to help you make the most of Red Hat products and technologies. The Red Hat Knowledgebase consists of articles, product documentation, and videos outlining best practices on installing, configuring, and using Red Hat products. In addition, you can search for solutions to known issues. Each solution provides concise root cause descriptions and remedial steps. 

1.3. SEARCH THE RED HAT KNOWLEDGEBASE 

To see whether a solution already exists when you have a Red Hat Connectivity Link issue, you can perform an initial search of the Red Hat Knowledgebase. 

Prerequisites 

You have a Red Hat Customer Portal account. 

Procedure 

1. Log in to the Red Hat Customer Portal . 

2. Click Search. 

3. In the search field, input keywords and strings relating to the problem, including: 

Red Hat Connectivity Link components, such as AuthPolicy 

Related procedure, such as installation 

Warnings, error messages, and other outputs related to explicit failures 

4. Click the Enter key. 

5. Optional: Select the Red Hat Connectivity Link product filter. 

6. Optional: Select the Documentation content type filter. 

1.4. SUBMIT A SUPPORT CASE 

Submit a support case to Red Hat Support to get help with issues you have with Red Hat Connectivity Link. 

Prerequisites 

**You have access to the cluster as a user with the cluster-admin role. **

**You have installed the OpenShift CLI (oc). **

You have a Red Hat Customer Portal account. 

You have a Red Hat Standard or Premium subscription. 

Procedure 

1. Log in to the Customer Support page of the Red Hat Customer Portal. 

2. Click Get support. 

3. On the Cases tab of the Customer Support page: 

a. Optional: Change the pre-filled account and owner details if needed. 

b. Select the appropriate category for your issue, such as Bug or Defect. Click Continue. 

4. Enter the following information: 

a. In the Summary field, enter a concise but descriptive problem summary and further details about what is happening and what you expected to happen. 

b. Select Red Hat Connectivity Link from the Product drop-down menu. 

c. Select 1.4 from the Version drop-down. 

5. Review the list of suggested Red Hat Knowledgebase solutions for a potential match against the problem you are reporting. If the suggested articles do not address the issue, click Continue. 

6. Review the updated list of suggested Red Hat Knowledgebase solutions for a potential match against the problem you are reporting. The list is refined as you give more information during the case creation process. If the suggested articles do not address the issue, click Continue. 

7. Ensure that the account information presented is as expected, and if not, amend accordingly. 

8. Check that the autofilled Red Hat Connectivity Link Cluster ID is correct. If it is not, manually obtain your cluster ID. 

To manually obtain your cluster ID using the OpenShift Container Platform web console: 

a. Navigate to Home → Overview. 

b. Find the value in the Cluster ID field of the Details section. 

Alternatively, it is possible to open a new support case through the OpenShift Container Platform web console and have your cluster ID autofilled. 

a. From the toolbar, navigate to (?) Help → Open Support Case. 

b. The Cluster ID value is autofilled. 

**To obtain your cluster ID using the OpenShift CLI (oc), run the following command: **

9. Complete the following questions where prompted and then click Continue: 

What are you experiencing? What are you expecting to happen? 

Define the value or impact to you or the business. 

Where are you experiencing this behavior? What environment? 

When does this behavior occur? Frequency? Repeatedly? At certain times? 

10. Upload relevant diagnostic data files and click Continue. **Red Hat recommends including data gathered using the oc adm must-gather command as a **starting point. Add any issue-specific data that is not collected by that command. 

11. Input relevant case management details and click Continue. 

12. Preview the case details and click Submit. 

$ oc get clusterversion -o jsonpath='{.items[].spec.clusterID}{"\n"}' 