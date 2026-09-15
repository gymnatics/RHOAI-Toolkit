# Red_Hat_OpenShift_AI_Self-Managed-3.5-Managing_OpenShift_AI-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Managing OpenShift AI

Cluster administrator tasks for managing OpenShift AI 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Managing OpenShift AI

Cluster administrator tasks for managing OpenShift AI

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

As an OpenShift cluster administrator, manage OpenShift AI users and groups, the dashboard interface and applications, deployment resources, accelerators, distributed workloads, and data backup.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

PREFACE 

CHAPTER 1. SET UP USER ACCESS AND IDENTITY 1.1. SET UP USER ACCESS AND IDENTITY 

1.1.1. Platform user types 1.1.2. Custom roles for project resources 

1.2. VIEW OPENSHIFT AI USERS 1.3. ADD USERS TO OPENSHIFT AI USER GROUPS 1.4. SELECT ADMIN AND USER GROUPS 1.5. REMOVE USER ACCESS AND CLEAN UP RESOURCES 1.6. STOP BASIC WORKBENCHES OWNED BY OTHER USERS 1.7. REVOKE USER ACCESS TO BASIC WORKBENCHES 1.8. BACKING UP STORAGE DATA 1.9. CLEAN UP AFTER DELETING USERS 

CHAPTER 2 CREATE CUSTOM WORKBENCH IMAGES 2.1. CREATE A CUSTOM IMAGE FROM A DEFAULT OPENSHIFT AI IMAGE 2.2. GUDIELINES TO CREATE A CUSTOM IMAGE FROM YOUR OWN IMAGE 2.3. ENABLE CUSTOM IMAGES IN OPENSHIFT AI 2.4. HIDE AND SHOW PRE-INSTALLED WORKBENCH IMAGES 2.5. IMPORT A CUSTOM WORKBENCH IMAGE 

CHAPTER 3 MANAGE APPLICATIONS THAT SHOW IN THE OPENSHIFT AI DASHBOARD 3.1. ADD AN APPLICATION TO THE DASHBOARD 3.2. PREVENT USERS FROM ADDING APPLICATIONS TO THE DASHBOARD 3.3. DISABLE APPLICATIONS CONNECTED TO OPENSHIFT AI 3.4. SHOW OR HIDE INFORMATION ABOUT AVAILABLE APPLICATIONS 3.5. HIDE THE DEFAULT BASIC WORKBENCH APPLICATION 

CHAPTER 4 CREATE PROJECT-SCOPED RESOURCES 

CHAPTER 5 ALLOCATE ADDITIONAL RESOURCES TO OPENSHIFT AI USERS 

CHAPTER 6 CUSTOMIZE COMPONENT DEPLOYMENT RESOURCES 6.1. CUSTOMIZE COMPONENT DEPLOYMENT RESOURCES 6.2. CUSTOMIZE COMPONENT RESOURCES 6.3. DISABLE COMPONENT RESOURCE CUSTOMIZATION 6.4. RE-ENABLE COMPONENT RESOURCE CUSTOMIZATION 

CHAPTER 7 ENABLE ACCELERATORS 7.1. ENABLE NVIDIA GPUS 7.2. INTEL GAUDI AI ACCELERATOR INTEGRATION 

7.2.1. Enable Intel Gaudi AI accelerators 7.3. AMD GPU INTEGRATION 

7.3.1. Verify AMD GPU availability on your cluster 7.3.2. Enable AMD GPUs 

CHAPTER 8 MANAGE WORKLOADS WITH KUEUE 8.1. KUEUE WORKLOAD MANAGEMENT 

8.1.1. Kueue workflow 8.2. CONFIGURE WORKLOAD MANAGEMENT WITH KUEUE 

8.2.1. Enable Kueue in the dashboard 8.2.2. Manage ClusterQueues and LocalQueues outside the Operator 

5 

6 6 6 6 7 8 9 9 

10 11 11 

12 

14 14 16 19 

20 20 

23 23 24 25 26 27 

29 

31 

32 32 33 34 35 

36 36 38 39 40 41 

42 

44 44 48 49 51 

53 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

8.3. TROUBLESHOOTING REFERENCE: KUEUE 8.3.1. A user receives a "failed to call webhook" error message for Kueue 8.3.2. A user receives a "Default Local Queue …​ not found" error message 8.3.3. A user receives a "local_queue provided does not exist" error message 8.3.4. The pod provisioned by Kueue is terminated before the image is pulled 8.3.5. Additional resources 

8.4. MIGRATE TO THE RED HAT BUILD OF KUEUE OPERATOR 

CHAPTER 9 MANAGE DISTRIBUTED WORKLOADS 9.1. CONFIGURE QUOTA MANAGEMENT FOR DISTRIBUTED WORKLOADS 9.2. EXAMPLE KUEUE RESOURCE CONFIGURATIONS FOR DISTRIBUTED WORKLOADS 

9.2.1. NVIDIA GPUs without shared cohort 9.2.1.1. NVIDIA RTX A400 GPU resource flavor 9.2.1.2. NVIDIA RTX A1000 GPU resource flavor 9.2.1.3. NVIDIA RTX A400 GPU cluster queue 9.2.1.4. NVIDIA RTX A1000 GPU cluster queue 

9.2.2. NVIDIA GPUs and AMD GPUs without shared cohort 9.2.2.1. AMD GPU resource flavor 9.2.2.2. NVIDIA GPU resource flavor 9.2.2.3. AMD GPU cluster queue 9.2.2.4. NVIDIA GPU cluster queue 

9.3. CONFIGURE A CLUSTER FOR RDMA 9.4. TROUBLESHOOTING REFERENCE: DISTRIBUTED WORKLOADS FOR ADMINISTRATORS 

9.4.1. A user’s Ray cluster is in a suspended state 9.4.2. A user’s Ray cluster is in a failed state 9.4.3. A user’s Ray cluster does not start 9.4.4. A user cannot create a Ray cluster or submit jobs 9.4.5. Additional resources 

CHAPTER 10 CONFIGURE A CENTRAL AUTHENTICATION SERVICE FOR AN EXTERNAL OIDC PROVIDER 

10.1. CENTRALIZED AUTHENTICATION SERVICE FOR EXTERNAL OIDC PROVIDERS 10.1.1. Authentication methods for the centralized authentication service 

10.2. CONFIGURE OIDC FOR THE CENTRALIZED AUTHENTICATION SERVICE 10.3. CONFIGURE SERVICE TOKEN AUTH FOR THE GATEWAY API 10.4. CONFIGURE CUSTOM CA CERTIFICATES FOR OIDC 10.5. TROUBLESHOOTING REFERENCE: THE CENTRAL AUTHENTICATION SERVICE 

10.5.1. Token duration error when creating a service account token 10.5.2. HTTP 401 Unauthorized error during Gateway access 10.5.3. The GatewayConfig status shows as not ready 10.5.4. Authentication proxy fails to start 10.5.5. The Gateway is inaccessible 10.5.6. The OIDC authentication fails 10.5.7. The dashboard is not accessible after authentication 

CHAPTER 11 BACK UP DATA 11.1. BACKING UP STORAGE DATA 11.2. CLUSTER BACKUP 

CHAPTER 12. MANAGE OBSERVABILITY 12.1. ENABLE THE OBSERVABILITY STACK 12.2. OBSERVE PLATFORM AND MODEL METRICS 

12.2.1. Observability dashboards overview 12.2.1.1. Available dashboards 

56 56 57 57 58 58 58 

63 63 67 67 67 67 68 68 68 68 69 69 69 70 72 72 73 74 74 75 

76 76 76 76 81 

82 83 84 84 84 85 86 88 89 

91 91 91 

92 92 94 94 94 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

12.2.1.2. Dashboard access 12.2.1.3. Dashboard controls 

12.2.2. Enable the observability dashboards 12.2.3. Cluster dashboard metrics 

12.2.3.1. Overview metrics 12.2.3.2. Cluster resource overview 12.2.3.3. Project resource usage 12.2.3.4. Cluster details 

12.2.4. Models dashboard metrics 12.2.4.1. Model deployments table 12.2.4.2. Performance metrics 12.2.4.3. Response time distribution 12.2.4.4. Filters 

12.2.5. View model performance metrics 12.2.6. Metrics beyond the built-in dashboards 

12.2.6.1. Query Prometheus directly 12.2.6.2. Export metrics to external tools 

12.3. COLLECT METRICS FROM USER WORKLOADS 12.4. EXPORT METRICS TO EXTERNAL OBSERVABILITY TOOLS 12.5. VIEW TRACES IN EXTERNAL TRACING PLATFORMS 12.6. ACCESS BUILT-IN ALERTS 

CHAPTER 13. VIEW LOGS AND AUDIT RECORDS 13.1. CONFIGURE THE OPENSHIFT AI OPERATOR LOGGER 13.2. VIEW AUDIT RECORDS 

95 95 95 96 96 96 97 97 98 98 98 99 99 

100 101 101 101 101 

103 105 106 

108 108 110 

### PREFACE

As an OpenShift cluster administrator, you can manage the following Red Hat OpenShift AI resources: 

Users and groups 

Custom workbench images 

Applications that show in the dashboard 

Custom deployment resources that are related to the Red Hat OpenShift AI Operator, for example, CPU and memory limits and requests 

Accelerators 

Workload resources with Kueue 

Distributed workloads 

Configure external OIDC identity providers 

Data backup 

Monitoring and observability 

Logs and audit records 

### CHAPTER 1. SET UP USER ACCESS AND IDENTITY

Users with cluster administrator access to OpenShift can add, modify, and remove user permissions for Red Hat OpenShift AI. 

1.1. SET UP USER ACCESS AND IDENTITY 

Red Hat OpenShift AI provides several levels of access control, from platform-wide user types to finegrained, resource-level custom roles within projects. 

1.1.1. Platform user types 

The following table describes the Red Hat OpenShift AI user types. 

Table 1.1. User types 

User type Permissions 

Users Machine learning operations (MLOps) engineers and data scientists can access and use individual components of Red Hat OpenShift AI, such as workbenches and AI pipelines. See also Accessing the OpenShift AI dashboard. 

Administrators In addition to the actions permitted to users, administrators can perform these actions: 

Configure Red Hat OpenShift AI settings. 

Access and manage workbenches. 

Access and manage pipeline applications for any project. 

By default, all OpenShift users have access to Red Hat OpenShift AI. In addition, users in the OpenShift **administrator group (cluster admins), automatically have administrator access in OpenShift AI. **

Optionally, if you want to restrict access to your OpenShift AI deployment to specific users or groups, you can create user groups for users and administrators. 

If you decide to restrict access, and you already have groups defined in your configured identity provider, you can add these groups to your OpenShift AI deployment. If you decide to use groups without adding these groups from an identity provider, you must create the groups in OpenShift and then add users to them. 

**There are some operations relevant to OpenShift AI that require the cluster-admin role. Those **operations include: 

Adding users to the OpenShift AI user and administrator groups, if you are using groups. 

Removing users from the OpenShift AI user and administrator groups, if you are using groups. 

Managing custom environment and storage configuration for users in OpenShift, such as Jupyter notebook resources, ConfigMaps, and persistent volume claims (PVCs). 

1.1.2. Custom roles for project resources 

In addition to the platform-wide user types, project administrators can define custom roles that provide fine-grained, resource-level permissions within a project. With custom roles, you can control exactly who can view, edit, connect to, or manage specific resources such as workbenches. 

**Custom roles are Kubernetes Role or ClusterRole objects that you create by using the OpenShift AI dashboard, the oc CLI, or the OpenShift web console. A Role is scoped to a single project namespace, while a ClusterRole can be reused across multiple projects. When you create a role through the OpenShift AI dashboard, the required opendatahub.io/dashboard: 'true' label is applied automatically. **When you create a role by using the CLI or web console, you must apply this label manually. Roles with this label display with an AI role badge in the Type column in the dashboard, distinguishing them from default OpenShift roles. 

For more information about creating and assigning custom roles, see Custom roles for workbenches . 

IMPORTANT 

Although users of OpenShift AI and its components are authenticated through OpenShift, session management is separate from authentication. This means that logging out of OpenShift or OpenShift AI does not affect a logged-in Jupyter session running on those platforms. When a user’s permissions change, that user must log out of all current sessions for the changes to take effect. 

Additional resources 

OpenShift Authentication and authorization 

1.2. VIEW OPENSHIFT AI USERS 

If you have defined OpenShift AI user groups, you can view the users that belong to these groups. 

Prerequisites 

The Red Hat OpenShift AI user group, administrator group, or both exist. 

**You have the cluster-admin role in OpenShift. **

You have configured a supported identity provider for OpenShift. 

Procedure 

1. In the OpenShift web console, click User Management → Groups. 

2. Click the name of the group containing the users that you want to view. 

**For administrative users, click the name of your administrator group. for example, rhodsadmins. **

**For normal users, click the name of your user group, for example, rhods-users. **The Group details page for the group is displayed. 

Verification 

In the Users section for the relevant group, you can view the users who have permission to access Red Hat OpenShift AI. 

1.3. ADD USERS TO OPENSHIFT AI USER GROUPS 

By default, all OpenShift users have access to Red Hat OpenShift AI. 

Optionally, you can restrict user access to your OpenShift AI instance by defining user groups. You must grant users permission to access Red Hat OpenShift AI by adding user accounts to the Red Hat OpenShift AI user group, administrator group, or both. You can either use the default group name, or specify a group name that already exists in your identity provider. 

The user group provides the user with access to product components in the Red Hat OpenShift AI dashboard, such as AI pipelines, and associated services, such as Jupyter. By default, users in the user group have access to AI pipeline applications within projects that they created. 

The administrator group provides the user with access to developer and administrator functions in the Red Hat OpenShift AI dashboard, such as AI pipelines, and associated services, such as Jupyter. Users in the administrator group can configure AI pipeline applications in the OpenShift AI dashboard for any project. 

If you restrict access by using user groups, users that are not in the OpenShift AI user group or administrator group cannot view the dashboard and use associated services, such as Jupyter. They are also unable to access the Cluster settings page. 

IMPORTANT 

If you are using LDAP as your identity provider, you need to configure LDAP syncing to OpenShift. For more information, see Syncing LDAP groups. 

Follow the steps in this section to add users to your OpenShift AI administrator and user groups. 

Note: You can add users in OpenShift AI but you must manage the user lists in the OpenShift web console. 

Prerequisites 

You have configured a supported identity provider for OpenShift. 

**You are assigned the cluster-admin role in OpenShift. **

You have defined an administrator group and user group for OpenShift AI. 

Procedure 

1. In the OpenShift web console, click User Management → Groups. 

2. Click the name of the group you want to add users to. 

**For administrative users, click the administrator group, for example, rhods-admins. **

**For normal users, click the user group, for example, rhods-users. **The Group details page for that group opens. 

3. Click Actions → Add Users. The Add Users dialog opens. 

4. In the Users field, enter the relevant user name to add to the group. 

5. Click Save. 

Verification 

Click the Details tab for each group and confirm that the Users section contains the user names that you added. 

1.4. SELECT ADMIN AND USER GROUPS 

By default, all users authenticated in OpenShift can access OpenShift AI. 

**Also by default, users with cluster-admin permissions are OpenShift AI administrators. A cluster admin **is a superuser that can perform any action in any project in the OpenShift cluster. When bound to a user with a local binding, they have full control over quota and every action on every resource in the project. 

**After a cluster admin user defines additional administrator and user groups in OpenShift, you can add **those groups to OpenShift AI by selecting them in the OpenShift AI dashboard. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

The groups that you want to select as administrator and user groups for OpenShift AI already exist in OpenShift. For more information, see Managing users and groups. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → User management. 

2. Select your OpenShift AI administrator groups: Under Red Hat OpenShift AI administrator groups, click the text box and select an OpenShift group. Repeat this process to define multiple administrator groups. 

3. Select your OpenShift AI user groups: Under Red Hat OpenShift AI user groups, click the text box and select an OpenShift group. Repeat this process to define multiple user groups. 

IMPORTANT 

**The system:authenticated setting allows all users authenticated in OpenShift to **access OpenShift AI. 

4. Click Save changes. 

Verification 

Administrator users can successfully log in to OpenShift AI and have access to the Settings navigation menu. 

Non-administrator users can successfully log in to OpenShift AI. They can also access and use individual components, such as projects and workbenches. 

1.5. REMOVE USER ACCESS AND CLEAN UP RESOURCES 

If you have administrator access to OpenShift, you can revoke a user’s access to workbenches and delete the user’s resources from Red Hat OpenShift AI. Before you delete a user from OpenShift AI, it is good practice to back up the data on your persistent volume claims (PVCs). 

Deleting a user and the user’s resources involves the following tasks: 

Stop workbenches owned by the user. 

Revoke user access to workbenches. 

Remove the user from the allowed group in your OpenShift identity provider. 

After you delete a user, delete their associated configuration files from OpenShift. 

1.6. STOP BASIC WORKBENCHES OWNED BY OTHER USERS 

OpenShift AI administrators can stop basic workbenches that are owned by other users to reduce resource consumption on the cluster, or as part of removing a user and their resources from the cluster. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

You have launched the Start basic workbench application, as described in Starting a basic workbench. 

The workbench that you want to stop is running. 

Procedure 

1. On the page that opens when you launch a basic workbench, click the Administration tab. 

2. Stop one or more servers. 

If you want to stop one or more specific servers, perform the following actions: 

i. In the Users section, locate the user that the workbench belongs to. 

ii. To stop the workbench, perform one of the following actions: 

**Click the action menu (⋮) beside the relevant user and select Stop server. **

Click View server beside the relevant user and then click Stop workbench. The Stop server dialog box opens. 

iii. Click Stop server. 

If you want to stop all workbenches, perform the following actions: 

i. Click the Stop all workbenches button. 

ii. Click OK to confirm stopping all servers. 

Verification 

The Stop server link beside each server changes to a Start workbench link when the workbench has stopped. 

1.7. REVOKE USER ACCESS TO BASIC WORKBENCHES 

You can revoke a user’s access to basic workbenches by removing the user from the OpenShift AI user groups that define access to OpenShift AI. When you remove a user from the user groups, the user is prevented from accessing the OpenShift AI dashboard and from using associated services that consume resources in your cluster. 

IMPORTANT 

Follow these steps only if you have implemented OpenShift AI user groups to restrict access to OpenShift AI. To completely remove a user from OpenShift AI, you must remove them from the allowed group in your OpenShift identity provider. 

Prerequisites 

You have stopped any workbenches owned by the user you want to delete. 

**You are assigned the cluster-admin role in OpenShift. **

You are using OpenShift AI user groups, and the user is part of the user group, administrator group, or both. 

Procedure 

1. In the OpenShift web console, click User Management → Groups. 

2. Click the name of the group that you want to remove the user from. 

**For administrative users, click the name of your administrator group, for example, rhodsadmins. **

**For non-administrator users, click the name of your user group, for example, rhods-users. **

The Group details page for the group is displayed. 

3. In the Users section on the Details tab, locate the user that you want to remove. 

**4. Click the action menu (⋮) beside the user that you want to remove and click Remove user. **

Verification 

In the Users section on the Details tab of the Group details page, confirm that the user that you removed is not visible. In Workloads → Pods, select the default workbench project ( **rhodsnotebooks or your custom workbench namespace), and ensure that there is no workbench pod for this user. If you see a pod named jupyter-nb-<username>-* for the user that you have **removed, delete that pod to ensure that the deleted user is not consuming resources on the cluster. 

In the OpenShift AI dashboard, check the list of projects. Delete any projects that belong to the user. 

1.8. BACKING UP STORAGE DATA 

It is a best practice to back up the data on your persistent volume claims (PVCs) regularly. 

Backing up your data is particularly important before you delete a user and before you uninstall OpenShift AI, as all PVCs are deleted when OpenShift AI is uninstalled. 

For more information about backing up PVCs for your cluster platform, see OADP Application backup and restore in the OpenShift Container Platform documentation. 

Additional resources 

Understanding persistent storage 

1.9. CLEAN UP AFTER DELETING USERS 

After you remove a user’s access to Red Hat OpenShift AI, you must also delete the configuration files for the user from OpenShift. Red Hat recommends that you back up the user’s data before removing their configuration files. 

Prerequisites 

(Optional) If you want to completely remove the user’s access to OpenShift AI, you have removed their credentials from your identity provider. 

You have backed up the user’s storage data. 

**You have logged in to the OpenShift web console as a user with the cluster-admin role. **

Procedure 

1. Delete the user’s persistent volume claim (PVC). 

a. Click Storage → PersistentVolumeClaims. 

**b. If it is not already selected, select the default workbench project (rhods-notebooks or your **custom workbench namespace) from the project list. 

**c. Locate the jupyter-nb-<username> PVC. Replace <username> with the relevant user name. **

d. Click the action menu (⋮) and select Delete PersistentVolumeClaim from the list. The Delete PersistentVolumeClaim dialog opens. 

e. Inspect the dialog and confirm that you are deleting the correct PVC. 

f. Click Delete. 

2. Delete the user’s ConfigMap. 

a. Click Workloads → ConfigMaps. 

**b. If it is not already selected, select the default workbench project (rhods-notebooks or your **custom workbench namespace) from the project list. 

**c. Locate the jupyterhub-singleuser-profile-<username> ConfigMap. Replace <username> with the relevant user name. **

d. Click the action menu (⋮) and select Delete ConfigMap from the list. 

The Delete ConfigMap dialog opens. 

e. Inspect the dialog and confirm that you are deleting the correct ConfigMap. 

f. Click Delete. 

Verification 

The user cannot access OpenShift AI and sees an "Access permission needed" message if they try. 

The user’s single-user profile, persistent volume claim (PVC), and ConfigMap are not visible in OpenShift. 

### CHAPTER 2. CREATE CUSTOM WORKBENCH IMAGES

Red Hat OpenShift AI includes a selection of default workbench images that a data scientist can select when they create or edit a workbench. You can control the visibility of pre-installed images and import custom images tailored to your project requirements. 

In addition to pre-installed images, you can import a custom workbench image. Custom images are useful when you want to add libraries that data scientists often use, or when you need a specific library version that differs from the default image. Custom workbench images are also useful when your data scientists require operating system packages or applications. Data scientist users do not have root access, so they cannot install these packages directly in their running environment. 

A custom workbench image is a container image that you build using a Containerfile or Dockerfile, starting from an existing base image and adding your required elements. 

You have the following options for creating a custom workbench image: 

Start from one of the default images, as described in Creating a custom image from a default OpenShift AI image. 

Create your own image by following the guidelines for making it compatible with OpenShift AI, as described in Creating a custom image from your own image . 

IMPORTANT 

Red Hat supports importing custom workbench images into OpenShift AI but does not support the contents of custom images. You are responsible for ensuring that your custom images produce usable workbenches. 

Additional resources 

Creating a custom image from a default OpenShift AI image 

Creating a custom image from your own image 

Supported Configurations for 3.x 

Red Hat OpenShift Container Platform - Creating Images 

Red Hat OpenShift Service on AWS - Creating images 

Red Hat OpenShift Dedicated - Dockerfile reference documentation 

2.1. CREATE A CUSTOM IMAGE FROM A DEFAULT OPENSHIFT AI IMAGE 

After Red Hat OpenShift AI is installed on a cluster, you can find the default workbench images in the **OpenShift console, under Builds → ImageStreams for the redhat-ods-applications project. **

You can create a custom image by adding OS packages or applications to a default OpenShift AI image. 

Prerequisites 

You know which default image you want to use as the base for your custom image. 

IMPORTANT 

If you want to create a custom Elyra-compatible image, the base image must be an OpenShift AI image that contains the Elyra extension. 

See Supported Configurations for 3.x  for a list of the OpenShift AI default workbench images and their preinstalled packages. 

**You have cluster-admin access to the OpenShift console for the cluster where OpenShift AI is **installed. 

Procedure 

1. Obtain the location of the default image that you want to use as the base for your custom image. 

a. In the OpenShift console, select Builds → ImageStreams. 

b. Select the redhat-ods-applications project. 

c. From the list of installed imagestreams, click the name of the image that you want to use as the base for your custom image. For example, click pytorch. 

d. On the ImageStream details page, click YAML. 

**e. In the spec:tags section, find the tag for the version of the image that you want to use. The location of the original image is shown in the tag’s from:name section, for example: **

**name: 'quay.io/modh/odh-pytorch-notebook@sha256:b68e0192abf7d…' **

f. Copy this location for use in your custom image. 

2. Create a standard Containerfile or Dockerfile. 

**3. For the FROM instruction, specify the base image location that you copied in Step 1, for **example: **FROM quay.io/modh/odh-pytorch-notebook@sha256:b68e0… **

4. Optional: Install OS images: 

**a. Switch to USER 0 (USER 0 is required to install OS packages). **

b. Install the packages. 

**c. Switch back to USER 1001. **The following example creates a custom workbench image that adds Java to the default PyTorch image: 

 FROM quay.io/modh/odh-pytorch-notebook@sha256:b68e0… 

 USER 0 

 RUN INSTALL_PKGS="java-11-openjdk java-11-openjdk-devel" && \     dnf install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \ 

*    dnf -y clean all --enablerepo=* *

 USER 1001 

IMPORTANT 

**To use the dnf install command, you must have an active RHEL AI 3 **subscription and active Red Hat Enterprise Linux EUS subscription with active RHEL packages. 

5. Optional: Add Python packages: 

**a. Specify USER 1001. **

**b. Copy the requirements.txt file. **

c. Install the packages. **The following example installs packages from the requirements.txt file in the default **PyTorch image: 

 FROM quay.io/modh/odh-pytorch-notebook@sha256:b68e0… 

 USER 1001 

 COPY requirements.txt ./requirements.txt 

 RUN pip install -r requirements.txt 

**6. Build the image file. For example, you can use podman build locally where the image file is **located and then push the image to a registry that is accessible to OpenShift AI: 

$ podman build -t my-registry/my-custom-image:0.0.1 . $ podman push my-registry/my-custom-image:0.0.1 

Alternatively, you can leverage OpenShift’s image build capabilities by using BuildConfig. 

2.2. GUDIELINES TO CREATE A CUSTOM IMAGE FROM YOUR OWN IMAGE 

You can build your own custom image. However, you must make sure that your image is compatible with OpenShift and OpenShift AI. 

The following basic guidelines provide information to consider when you build your own custom workbench image. 

Design your image to run with USER 1001 

**In OpenShift, your container will run with a random UID and a GID of 0. Make sure that your image is **compatible with these user and group requirements, especially if you need write access to directories. **Best practice is to design your image to run with USER 1001. **

Avoid placing artifacts in $HOME 

**The persistent volume attached to the workbench will be mounted on /opt/app-root/src. This location is also the location of $HOME. Therefore, do not put any files or other resources directly in $HOME **because they are not visible after the workbench is deployed (and the persistent volume is mounted). 

Specify the API endpoint 

**OpenShift readiness and liveness probes will query the /api endpoint. For a Jupyter IDE, this is the default endpoint. For other IDEs, you must implement the /api endpoint. **

The following guidelines provide information to consider when you build your own custom workbench image. 

Minimize image size 

A workbench image uses a "layered" file system. Every time you use a COPY or a RUN command in your workbench image file, a new layer is created. Artifacts are not deleted. When you remove an artifact, for example, a file, it is "masked" in the next layer. Therefore, consider the following guidelines when you create your workbench image file. 

**Point to a newer version of your base image rather than performing a dnf update on an older **version. 

NOTE 

**If you start from an image that is constantly updated, such as ubi9/python-39 from the Red Hat Catalog, you might not need to use the dnf update command. This command **fetches new metadata, updates files that might not have impact, and increases the workbench image size. 

**If you prefer to use the dnf update command, you will need to have an active RHEL AI 3 **subscription and active Red Hat Enterprise Linux EUS subscription with active RHEL packages. 

**Group RUN commands. Chain your commands by adding && \ at the end of each line. **

If you must compile code (such as a library or an application) to include in your custom image, implement multi-stage builds so that you avoid including the build artifacts in your final image. That is, compile the library or application in an intermediate image and then copy the result to your final image, leaving behind build artifacts that you do not want included. 

Set access to files and directories 

**Set the ownership of files and folders to 1001:0 (user "default", group "0"), for example: **

COPY --chown=1001:0 os-packages.txt ./ 

On OpenShift, every container is in a standard namespace (unless you modify security). The **container runs with a user that has a random user ID (uid) and with a group ID (gid) of 0. **Therefore, all folders that you want to write to - and all the files you want to (temporarily) modify - in your image must be accessible by the user that has the random user ID (uid). Alternatively, you can set access to any user, as shown in the following example: 

COPY --chmod=775 os-packages.txt ./ 

**Build your image with /opt/app-root/src as the default location for the data that you want **persisted, for example: 

WORKDIR /opt/app-root/src 

When a user launches a workbench from the OpenShift AI Applications → Enabled page, the **personal volume of the user is mounted in the user’s HOME directory (/opt/app-root/src). **Because this location is not configurable, when you build your custom image, you must specify this default location for persisted data. 

Fix permissions to support PIP (the package manager for Python packages) in OpenShift environments. Add the following command to your custom image (if needed, change **python3.11 to the Python version that you are using): **

chmod -R g+w /opt/app-root/lib/python3.11/site-packages && \    fix-permissions /opt/app-root -P 

IMPORTANT 

Your workbench image needs to serve all of its content from the base path **/${NB_PREFIX} because the routing, handled by the Gateway API, is path-based and uses the same value as the environment variable NB_PREFIX. **

**The NB_PREFIX environment variable is injected in the workbench at runtime. Any call from a browser to a different path, for example /index.html, /api/my-endpoint, or simply /, will not be routed to the workbench container. **

**A service within your workbench image must answer at ${NB_PREFIX}/api, otherwise the **OpenShift liveness/readiness probes fail and delete the pod for the workbench image. **The NB_PREFIX environment variable specifies the URL path where the container is expected **to be listening. 

The following is an example of an Nginx configuration: 

location = ${NB_PREFIX}/api {  return 302  /healthz;  access_log  off; } 

**For idle culling to work, the ${NB_PREFIX}/api/kernels URL must return a specifically-**formatted JSON payload, as shown in the following example: The following is an example of an Nginx configuration: 

location = ${NB_PREFIX}/api/kernels {  return 302 $custom_scheme://$http_host/api/kernels/;  access_log  off; } 

location ${NB_PREFIX}/api/kernels/ {  return 302 $custom_scheme://$http_host/api/kernels/;  access_log  off; } 

location /api/kernels/ {   index access.cgi;   fastcgi_index access.cgi;   gzip  off;   access_log off;  } 

The returned JSON payload should be: 

{"id":"rstudio","name":"rstudio","last_activity":(time in ISO8601 format),"execution_state":"busy","connections": 1} 

Enable CodeReady Builder (CRB) and Extra Packages for Enterprise Linux (EPEL) 

CRB and EPEL are repositories that provide packages which are absent from a standard Red Hat Enterprise Linux (RHEL) or Universal Base Image (UBI) installation. They are useful and required for installing some software, for example, RStudio. 

On UBI9 images, CRB is enabled by default. To enable EPEL on UBI9-based images, run the following command: 

 RUN yum install -y https://download.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm 

To enable CRB and EPEL on Centos Stream 9-based images, run the following command: 

 RUN yum install -y yum-utils && \     yum-config-manager --enable crb && \     yum install -y https://download.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm 

Additional resources 

General Container image guidelines section in the OpenShift Container Platform Images documentation 

Red Hat Universal Base Image 

Red Hat Ecosystem Catalog 

2.3. ENABLE CUSTOM IMAGES IN OPENSHIFT AI 

All OpenShift AI administrators can import custom workbench images, by default, by selecting the Settings → Environment setup → Workbench images navigation option in the OpenShift AI dashboard. 

If the Settings → Environment setup → Workbench images option is not available, check the following settings, depending on which navigation element does not appear in the dashboard: 

The Settings menu does not appear in the OpenShift AI navigation bar. The visibility of the OpenShift AI dashboard Settings menu is determined by your user permissions. By default, the Settings menu is available to OpenShift AI administration users **(users that are members of the rhods-admins group). Users with the OpenShift cluster-admin role are automatically added to the rhods-admins group and are granted administrator access **in OpenShift AI. 

The Workbench images menu item does not appear under the Settings menu. The visibility of the Workbench images menu item is controlled in the dashboard configuration, **by the value of the dashboardConfig: disableBYONImageStream option. It is set to false (the **Workbench images menu item is visible) by default. 

You need OpenShift AI administrator permissions to edit the dashboard configuration. 

Additional resources 

Managing users and groups 

Customizing the dashboard 

2.4. HIDE AND SHOW PRE-INSTALLED WORKBENCH IMAGES 

To prevent data scientists from selecting workbench images that are not applicable to your environment, you can disable individual pre-installed images. 

Disabling an image does not affect existing workbenches, and visibility settings persist across OpenShift AI operator upgrades. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

The Settings → Environment setup → Workbench images dashboard navigation menu item is enabled, as described in Enabling custom workbench images in OpenShift AI . 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Environment setup → Workbench images. 

2. To hide a pre-installed image, click the toggle in the Enable column for that image. 

3. To show a previously hidden image, click the toggle in the Enable column for that image. 

Verification 

The disabled image is marked as disabled in the Enable column on the Workbench images page. 

When creating a new workbench, the disabled image does not appear in the Image selection list. 

Optional: Use the Enabled filter set to Disabled to confirm the image is in the disabled list. 

Additional resources 

Import a custom workbench image 

Enabling custom workbench images in OpenShift AI 

2.5. IMPORT A CUSTOM WORKBENCH IMAGE 

In addition to workbench images provided and supported by Red Hat and independent software vendors (ISVs), you can import custom workbench images that cater to your project’s specific requirements. 

You must import it so that your OpenShift AI users (data scientists) can access it when they create a project workbench. 

Red Hat supports importing custom workbench images into OpenShift AI but does not support the contents of custom images. You are responsible for ensuring that your custom images produce usable workbenches. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

Your custom image exists in an image registry that is accessible to OpenShift AI. 

The Settings → Environment setup → Workbench images dashboard navigation menu item is enabled, as described in Enabling custom workbench images in OpenShift AI . 

If you want to associate an accelerator with the custom image that you want to import, you know the accelerator’s identifier - the unique string that identifies the hardware accelerator. You must also have enabled GPU support in OpenShift AI. This includes installing the Node Feature Discovery Operator and NVIDIA GPU Operator. For more information, see Installing the Node Feature Discovery Operator and Enabling NVIDIA GPUs. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Environment setup → Workbench images. The Workbench images page opens. 

To manage the visibility of pre-installed workbench images, see Hiding and showing preinstalled workbench images. 

2. Optional: To associate an accelerator, click Create profile on the image row. If the image does not contain an accelerator identifier, configure one manually before creating the profile. 

3. Click Import new image. The Import workbench image dialog opens. 

4. In the Image location field, enter the URL of the repository containing the image. For example: **quay.io/my-repo/my-image:tag, quay.io/my-repo/my-image@sha256:xxxxxxxxxxxxx, or docker.io/my-repo/my-image:tag. **

5. In the Name field, enter an appropriate name for the image. 

6. Optional: In the Description field, enter a description for the image. 

7. Optional: From the Hardware profile identifier list, select one or more identifiers to set the recommended hardware profiles for the image. 

8. Optional: Add software to the image. After the import has completed, the software is added to the image’s metadata and displayed on the workbench creation page. 

a. Click the Software tab. 

b. Click the Add software button. 

c. Click Edit (  ). 

d. Enter the software name. 

e. Enter the software version. 

f. Click Confirm (  ) to confirm your entry. 

g. To add additional software, click Add software, complete the relevant fields, and confirm your entry. 

9. Optional: Add packages to the workbench images. 

a. Click the Packages tab. 

b. Click the Add package button. 

c. Click Edit (  ). 

d. In the Packages field, enter the package name. 

**e. Enter the package Version. For example, type 3.16.7. **

f. Click Confirm (  ) to confirm your entry. 

g. To add an additional package, click Add package, complete the relevant fields, and confirm your entry. 

10. Click Import. 

Verification 

The image that you imported is displayed in the table on the Workbench images page, alongside any pre-installed images. 

Your custom image is available for selection when a user creates a workbench. 

Additional resources 

Managing image streams 

Understanding build configurations 

### CHAPTER 3. MANAGE APPLICATIONS THAT SHOW IN THE OPENSHIFT AI DASHBOARD

3.1. ADD AN APPLICATION TO THE DASHBOARD 

If you have installed an application in your OpenShift cluster, an OpenShift AI administrator can add a tile for that application to the OpenShift AI dashboard (the Applications → Enabled page) to make it accessible for OpenShift AI users. 

Prerequisites 

You have OpenShift AI administrator privileges. 

**The spec.dashboardConfig.enablement dashboard configuration option is set to true (the **default). For more information about setting dashboard configuration options, see Customizing the dashboard. 

Procedure 

1. Log in to the OpenShift console as an OpenShift AI administrator. 

2. In the Administrator perspective, click Home → API Explorer. 

**3. In the search bar, enter OdhApplication to filter by kind. **

**4. Click the OdhApplication custom resource (CR) to open the resource details page. **

**5. From the Project list, select the OpenShift AI application namespace; the default is redhat-ods-applications. **

6. Click the Instances tab. 

7. Click Create OdhApplication. 

8. On the Create OdhApplication page, copy the following code and paste it into the YAML editor. 

apiVersion: dashboard.opendatahub.io/v1 kind: OdhApplication metadata:   name: examplename   namespace: redhat-ods-applications   labels:     app: odh-dashboard     app.kubernetes.io/part-of: odh-dashboard spec:   enable:     validationConfigMap: examplename-enable   img: >-    <svg width="24" height="25" viewBox="0 0 24 25" fill="none" xmlns="http://www.w3.org/2000/svg">     <path d="path data" fill="#ee0000"/>     </svg> 

9. Modify the parameters in the code for your application. 

TIP 

**To see example YAML files, click Home → API Explorer, select OdhApplication, click the **Instances tab, select an instance, and then click the YAML tab. 

10. Click Create. The application details page opens. 

11. Log in to OpenShift AI. 

12. In the left menu, click Applications → Explore. 

13. Locate the new tile for your application and click it. 

14. In the information pane for the application, click Enable. 

Verification 

In the left menu of the OpenShift AI dashboard, click Applications → Enabled and verify that your application is available. 

3.2. PREVENT USERS FROM ADDING APPLICATIONS TO THE DASHBOARD 

By default, OpenShift AI administrators can add applications to the OpenShift AI dashboard **Application → Enabled page. **

As an OpenShift AI administrator, you can disable the ability for OpenShift AI administrators to add applications to the dashboard. 

Note: The Start basic workbench tile is enabled by default. To disable it, see Hiding the default basic workbench application. 

Prerequisite 

  getStartedLink: 'https://example.org/docs/quickstart.html'   route: exampleroutename   routeNamespace: examplenamespace   displayName: Example Name   kfdefApplications: []   support: third party support   csvName: ''   provider: example   docsLink: 'https://example.org/docs/index.html'   quickStart: ''   getStartedMarkDown: >-*    # Example *

    Enter text for the information panel. 

  description: >-    Enter summary text for the tile.   category: Self-managed | Partner managed | Red Hat managed 

You have OpenShift AI administrator privileges. 

Procedure 

1. Log in to the OpenShift console as an OpenShift AI administrator. 

2. Open the dashboard configuration file: 

a. In the Administrator perspective, click Home → API Explorer. 

**b. In the search bar, enter OdhDashboardConfig to filter by kind. **

**c. Click the OdhDashboardConfig custom resource (CR) to open the resource details page. **

**d. From the Project list, select the OpenShift AI application namespace; the default is redhat-ods-applications. **

e. Click the Instances tab. 

**f. Click the odh-dashboard-config instance to open the details page. **

g. Click the YAML tab. 

**3. In the spec.dashboardConfig section, set the value of enablement to false to disable the **ability for dashboard users to add applications to the dashboard. 

4. Click Save to apply your changes and then click Reload to make sure that your changes are synced to the cluster. 

Verification 

**Open the OpenShift AI dashboard Application → Enabled page. **

3.3. DISABLE APPLICATIONS CONNECTED TO OPENSHIFT AI 

You can disable applications and components so that they do not appear on the OpenShift AI dashboard when you no longer want to use them, for example, when data scientists no longer use an application or when the application license expires. 

Disabling unused applications allows your data scientists to manually remove these application tiles from their OpenShift AI dashboard so that they can focus on the applications that they are most likely to use. See Removing disabled applications from the dashboard  for more information about manually removing application tiles. 

Prerequisites 

You have logged in to the OpenShift web console. 

**You are part of the cluster-admins user group in OpenShift. **

You have installed or configured the service on your OpenShift cluster. 

The application or component that you want to disable is enabled and visible on the Enabled page. 

Procedure 

1. In the OpenShift web console, switch to the Administrator perspective. 

**2. Switch to the redhat-ods-applications project. **

3. Go to the Installed Operators page. The navigation path depends on your OpenShift version: 

On OpenShift 4.20 and later, click Ecosystem → Installed Operators. 

On OpenShift 4.19, click Operators → Installed Operators. 

4. Click on the Operator that you want to uninstall. You can enter a keyword into the Filter by name field to help you find the Operator faster. 

5. Delete any Operator resources or instances by using the tabs in the Operator interface. During installation, some Operators require the administrator to create resources or start process instances using tabs in the Operator interface. These must be deleted before the Operator can uninstall correctly. 

6. On the Operator Details page, click the Actions drop-down menu and select Uninstall Operator. An Uninstall Operator? dialog box is displayed. 

7. Select Uninstall to uninstall the Operator, Operator deployments, and pods. After this is complete, the Operator stops running and no longer receives updates. 

IMPORTANT 

Removing an Operator does not remove any custom resource definitions or managed resources for the Operator. Custom resource definitions and managed resources still exist and must be cleaned up manually. Any applications deployed by your Operator and any configured off-cluster resources continue to run and must be cleaned up manually. 

Verification 

The Operator is uninstalled from its target clusters. 

The Operator is no longer displayed on the Installed Operators page. 

The disabled application is no longer available for your data scientists to use, and is marked as **Disabled on the Enabled page of the OpenShift AI dashboard. This action may take a few **minutes to occur following the removal of the Operator. 

3.4. SHOW OR HIDE INFORMATION ABOUT AVAILABLE APPLICATIONS 

You can view a list of available applications in the Exploring applications page of the OpenShift AI dashboard. By default, the following information is provided for each application: 

Any independent software vendor (ISV) application is indicated with a label on the tile indicating **Red Hat-managed, Partner managed, or Self-managed. As an OpenShift AI administrator, you **can hide or show the labels. For example, if you are running a self-managed environment, you might want to show all available applications regardless of the support level. 

When a user clicks on an application, an information panel is displayed and provides more information about the application, including links to quick starts or detailed documentation. You can disable or enable the appearance of application information panels. 

Prerequisites 

You have OpenShift AI administrator privileges. 

Procedure 

1. Log in to the OpenShift console as an OpenShift AI administrator. 

2. Open the dashboard configuration file: 

a. In the Administrator perspective, click Home → API Explorer. 

**b. In the search bar, enter OdhDashboardConfig to filter by kind. **

**c. Click the OdhDashboardConfig custom resource (CR) to open the resource details page. **

**d. From the Project list, select the OpenShift AI application namespace; the default is redhat-ods-applications. **

e. Click the Instances tab. 

**f. Click the odh-dashboard-config instance to open the details page. **

g. Click the YAML tab. 

**3. In the spec.dashboardConfig section, set either or both of the following options: **

**disableInfo: Set to true to hide the appearance of application information panel. Set to False (the default) to show the application information panel. **

**disableISVBadges: Set to true to hide the appearance of the support-level label. Set to False (the default) to show the support-level label. **

4. Click Save to apply your changes and then click Reload to make sure that your changes are synced to the cluster. 

Verification 

Log in to OpenShift AI and verify that your dashboard configurations apply. 

3.5. HIDE THE DEFAULT BASIC WORKBENCH APPLICATION 

The OpenShift AI dashboard includes Start basic workbench as an enabled application by default. 

To hide the Start basic workbench tile so that it is no longer included in the list of applications on the Applications → Enabled page, edit the dashboard configuration file. 

Prerequisite 

You have OpenShift AI administrator privileges. 

Procedure 

1. Log in to the OpenShift console as an OpenShift AI administrator. 

2. Open the dashboard configuration file: 

a. In the Administrator perspective, click Home → API Explorer. 

**b. In the search bar, enter OdhDashboardConfig to filter by kind. **

**c. Click the OdhDashboardConfig custom resource (CR) to open the resource details page. **

**d. From the Project list, select the OpenShift AI application namespace; the default is redhat-ods-applications. **

e. Click the Instances tab. 

**f. Click the odh-dashboard-config instance to open the details page. **

g. Click the YAML tab. 

**3. In the spec:notebookController section, set the value of enabled to false to remove the Start **basic workbench tile from the list of applications on the Applications → Enabled page. 

4. Click Save to apply your changes and then click Reload to make sure that your changes are synced to the cluster. 

Verification 

In the OpenShift AI dashboard, click Applications → Enabled. The list of applications no longer includes the Start basic workbench tile. 

### CHAPTER 4. CREATE PROJECT-SCOPED RESOURCES

*OpenShift AI users can access global resources in all OpenShift AI projects. However, they can access project-scoped resources only within projects that they have permissions to access. *

As a cluster administrator, you can create the following types of project-scoped resources in any OpenShift AI project: 

Workbench images 

Hardware profiles 

Model-serving runtimes for KServe 

All resource names must be unique within a project. 

NOTE 

A user with access permissions to a project can create project-scoped resources for that project, as described in Creating project-scoped resources for your project . 

Prerequisites 

You can access the OpenShift console as a cluster administrator. 

**You have set the disableProjectScoped dashboard configuration option to false, as described **in Customizing the dashboard. 

Procedure 

1. Log in to the OpenShift console as a cluster administrator. 

2. Copy the YAML code to create the resource. You can get the YAML code from a trusted source, such as an existing resource, a Git repository, or documentation. 

For example, you can copy the YAML code from an existing resource, as follows: 

a. In the Administrator perspective, click Home → Search. 

b. From the Project list, select the appropriate project. **To limit the search to global OpenShift AI resources only, select the redhat-ods-applications project. **

c. In the Resources list, search for the relevant resource type: 

**For workbench images, search for ImageStream. **

**For hardware profiles, search for HardwareProfile. **

**For serving runtimes, search for Template. From the resulting list, find the templates that have the objects.kind specification set to ServingRuntime. **

d. Select a resource, and then click the YAML tab. 

e. Copy the YAML content, and then click Cancel. 

3. From the Project list, select the target project name. 

4. From the toolbar, click the + icon to open the Import YAML page. 

5. Paste the relevant YAML content into the code area. 

**6. Edit the metadata.namespace value to specify the name of the target project. **

**7. If necessary, edit the metadata.name value to ensure that the resource name is unique within **the specified project. 

8. Optional: Edit the resource name that is displayed in the OpenShift AI console: 

**For workbench images, edit the metadata.annotations.opendatahub.io/notebook-image-name value. **

**For hardware profiles, edit the spec.displayName value. **

**For serving runtimes, edit the objects.metadata.annotations.openshift.io/display-name **value. 

9. Click Create. 

Verification 

1. Log in to the OpenShift AI console as a regular user. 

2. Verify that the project-scoped resource is shown in the specified project: 

For workbench images and hardware profiles, see Creating a workbench . 

For serving runtimes, see Deploying models . 

### CHAPTER 5. ALLOCATE ADDITIONAL RESOURCES TO OPENSHIFT AI USERS

As a cluster administrator, you can allocate additional resources to a cluster to support compute-intensive data science work. This support includes increasing the number of nodes in the cluster and changing the cluster’s allocated machine pool. 

Additional resources 

Manually scaling a compute machine set 

### CHAPTER 6. CUSTOMIZE COMPONENT DEPLOYMENT RESOURCES

You can customize deployment resources for Red Hat OpenShift AI Operator components, such as CPU and memory limits and requests. 

6.1. CUSTOMIZE COMPONENT DEPLOYMENT RESOURCES 

You can customize deployment resources that are related to the Red Hat OpenShift AI Operator, for example, CPU and memory limits and requests. For resource customizations to persist without being **overwritten by the Operator, the opendatahub.io/managed: true annotation must not be present in the **YAML file for the component deployment. This annotation is absent by default. 

**The following table shows the deployment names for each component in the redhat-ods-applications **namespace. 

IMPORTANT 

**Components denoted with (Technology Preview) in this table are not supported with **Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using Technology Preview features in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Component Deployment names 

KServe kserve-controller-manager 

odh-model-controller 

Ray kuberay-operator 

Kueue kueue-controller-manager 

Workbenches notebook-controller-deployment 

odh-notebook-controller-manager 

Dashboard rhods-dashboard 

Model serving modelmesh-controller 

odh-model-controller 

Model registry model-registry-operator-controller-manager 

AI pipelines data-science-pipelines-operator-controller-manager 

Training Operator kubeflow-training-operator 

Component Deployment names 

6.2. CUSTOMIZE COMPONENT RESOURCES 

You can customize component deployment resources by updating the **.spec.template.spec.containers.resources section of the YAML file for the component deployment. **

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

Procedure 

1. Log in to the OpenShift console as a cluster administrator. 

2. In the Administrator perspective, click Workloads → Deployments. 

**3. From the Project drop-down list, select redhat-ods-applications. **

4. In the Name column, click the name of the deployment for the component that you want to customize resources for. 

NOTE 

For more information about the deployment names for each component, see Overview of component resource customization. 

5. On the Deployment details page that is displayed, click the YAML tab. 

**6. Find the .spec.template.spec.containers.resources section. **

7. Update the value of the resource that you want to customize. For example, to update the memory limit to 500Mi, make the following change: 

containers:         - resources:             limits:                 cpu: '2'                 memory: 500Mi             requests:                 cpu: '1'                 memory: 1Gi 

8. Click Save. 

9. Click Reload. 

Verification 

Log in to OpenShift AI and verify that your resource changes apply. 

6.3. DISABLE COMPONENT RESOURCE CUSTOMIZATION 

You can disable customization of component deployment resources, and restore default values, by **adding the opendatahub.io/managed: true annotation to the YAML file for the component **deployment. 

IMPORTANT 

**Manually removing or setting the opendatahub.io/managed: true annotation to false **after manually adding it to the YAML file for a component deployment might cause unexpected cluster issues. 

To remove the annotation from a deployment, use the steps described in Re-enabling component resource customization. 

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

Procedure 

1. Log in to the OpenShift console as a cluster administrator. 

2. In the Administrator perspective, click Workloads → Deployments. 

**3. From the Project drop-down list, select redhat-ods-applications. **

4. In the Name column, click the name of the deployment for the component to which you want to add the annotation. 

NOTE 

For more information about the deployment names for each component, see Overview of component resource customization. 

5. On the Deployment details page that opens, click the YAML tab. 

**6. Find the metadata.annotations: section. **

**7. Add the opendatahub.io/managed: true annotation. **

metadata:   annotations:      opendatahub.io/managed: true 

8. Click Save. 

9. Click Reload. 

Verification 

**The opendatahub.io/managed: true annotation is displayed in the YAML file for the **component deployment. 

6.4. RE-ENABLE COMPONENT RESOURCE CUSTOMIZATION 

You can re-enable customization of component deployment resources after manually disabling it. 

IMPORTANT 

**Manually removing or setting the opendatahub.io/managed: annotation to false after **adding it to the YAML file for a component deployment might cause unexpected cluster issues. 

To remove the annotation from a deployment, use the following steps to delete the deployment. The controller pod for the deployment will automatically redeploy with the default settings. 

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

Procedure 

1. Log in to the OpenShift console as a cluster administrator. 

2. In the Administrator perspective, click Workloads → Deployments. 

**3. From the Project drop-down list, select redhat-ods-applications. **

4. In the Name column, click the name of the deployment for the component for which you want to remove the annotation. 

5. Click the Options menu  . 

6. Click Delete Deployment. 

Verification 

The controller pod for the deployment automatically redeploys with the default settings. 

### CHAPTER 7. ENABLE ACCELERATORS

7.1. ENABLE NVIDIA GPUS 

Before you can use NVIDIA GPUs in OpenShift AI, you must install the NVIDIA GPU Operator. 

IMPORTANT 

If you are using OpenShift AI in a disconnected self-managed environment, see Enabling accelerators instead. 

Prerequisites 

You have logged in to your OpenShift cluster. 

**You have the cluster-admin role in your OpenShift cluster. **

You have installed an NVIDIA GPU and confirmed that it is detected in your environment. 

NOTE 

On OpenShift 4.21 and later, the OLMv1 catalog is enabled by default as a Technology Preview feature. When installing Operators, such as the Node Feature Discovery (NFD) Operator or the NVIDIA GPU Operator from **OperatorHub, you might be redirected to a ClusterExtensions page instead of **the standard installation form. To restore the standard installation experience, disable the OLMv1 catalog before proceeding with the installation steps below. For more information, see Troubleshooting common installation problems . 

Procedure 

1. To enable GPU support on an OpenShift cluster, follow the instructions here: NVIDIA GPU Operator on Red Hat OpenShift Container Platform in the NVIDIA documentation. 

IMPORTANT 

After you install the Node Feature Discovery (NFD) Operator, you must create an instance of NodeFeatureDiscovery. In addition, after you install the NVIDIA GPU Operator, you must create a ClusterPolicy and populate it with default values. 

2. Delete the migration-gpu-status ConfigMap. 

a. In the OpenShift web console, switch to the Administrator perspective. 

b. Set the Project to All Projects or redhat-ods-applications to ensure you can see the appropriate ConfigMap. 

c. Search for the migration-gpu-status ConfigMap. 

d. Click the action menu (⋮) and select Delete ConfigMap from the list. The Delete ConfigMap dialog opens. 

e. Inspect the dialog and confirm that you are deleting the correct ConfigMap. 

f. Click Delete. 

3. Restart the dashboard replicaset. 

a. In the OpenShift web console, switch to the Administrator perspective. 

b. Click Workloads → Deployments. 

**c. Set the Project to All Projects or redhat-ods-applications to ensure you can see the **appropriate deployment. 

d. Search for the rhods-dashboard deployment. 

e. Click the action menu (⋮) and select Restart Rollout from the list. 

f. Wait until the Status column indicates that all pods in the rollout have fully restarted. 

Verification 

The reset migration-gpu-status instance is no longer present on the Instances tab on the **HardwareProfile custom resource definition (CRD) details page. **

1. Go to the Installed Operators page. The navigation path depends on your OpenShift version: 

On OpenShift 4.20 and later, click Ecosystem → Installed Operators. 

On OpenShift 4.19, click Operators → Installed Operators. 

2. Confirm that the following Operators appear: 

NVIDIA GPU 

Node Feature Discovery (NFD) 

Kernel Module Management (KMM) 

The GPU is correctly detected a few minutes after full installation of the Node Feature **Discovery (NFD) and NVIDIA GPU Operators. The OpenShift CLI (oc) displays the appropriate **output for the GPU worker node. For example: 

# Expected output when the GPU is detected properly oc describe node <node name> ... Capacity:   cpu:                4   ephemeral-storage:  313981932Ki   hugepages-1Gi:      0   hugepages-2Mi:      0   memory:             16076568Ki   nvidia.com/gpu:     1   pods:               250 Allocatable:   cpu:                3920m   ephemeral-storage:  288292006229   hugepages-1Gi:      0   hugepages-2Mi:      0 

  memory:             12828440Ki   nvidia.com/gpu:     1   pods:               250 

NOTE 

In OpenShift AI, Red Hat supports the use of accelerators within the same cluster only. 

Starting from Red Hat OpenShift AI 2.19, Red Hat supports remote direct memory access (RDMA) for NVIDIA GPUs only, enabling them to communicate directly with each other by using NVIDIA GPUDirect RDMA across either Ethernet or InfiniBand networks. 

After installing the NVIDIA GPU Operator, create a hardware profile as described in Working with hardware profiles. 

7.2. INTEL GAUDI AI ACCELERATOR INTEGRATION 

To accelerate your high-performance deep learning models, you can integrate Intel Gaudi AI accelerators into OpenShift AI. This integration enables your data scientists to use Gaudi libraries and software associated with Intel Gaudi AI accelerators through custom-configured workbench instances. 

Intel Gaudi AI accelerators offer optimized performance for deep learning workloads, with the latest Gaudi 3 devices providing significant improvements in training speed and energy efficiency. These accelerators are suitable for enterprises running machine learning and AI applications on OpenShift AI. 

Before you can enable Intel Gaudi AI accelerators in OpenShift AI, you must complete the following steps: 

1. Install the latest version of the Intel Gaudi Base Operator from the software catalog. 

2. Create and configure a custom workbench image for Intel Gaudi AI accelerators. A prebuilt workbench image for Gaudi accelerators is not included in OpenShift AI. 

3. Manually define and configure a hardware profile for each Intel Gaudi AI device in your environment. 

Red Hat supports Intel Gaudi devices up to Intel Gaudi 3. The Intel Gaudi 3 accelerators, in particular, offer the following benefits: 

Improved training throughput: Reduce the time required to train large models by using advanced tensor processing cores and increased memory bandwidth. 

Energy efficiency: Lower power consumption while maintaining high performance, reducing operational costs for large-scale deployments. 

Scalable architecture: Scale across multiple nodes for distributed training configurations. 

Your OpenShift platform must support EC2 DL1 instances to use Intel Gaudi AI accelerators in an Amazon EC2 DL1 instance. You can use Intel Gaudi AI accelerators in workbench instances or model serving after you enable the accelerators, create a custom workbench image, and configure the hardware profile. 

Additional resources 

lspci(8) - Linux man page 

Amazon EC2 DL1 Instances 

Intel Gaudi AI Operator OpenShift installation 

What version of the Kubernetes API is included with each OpenShift 4.x release? 

7.2.1. Enable Intel Gaudi AI accelerators 

Before you can use Intel Gaudi AI accelerators in OpenShift AI, you must install the required dependencies, deploy the Intel Gaudi Base Operator, and configure the environment. 

Prerequisites 

You have logged in to OpenShift. 

**You have the cluster-admin role in OpenShift. **

You have installed your Intel Gaudi accelerator and confirmed that it is detected in your environment. 

Your OpenShift environment supports EC2 DL1 instances if you are running on Amazon Web Services (AWS). 

**You have installed the OpenShift CLI (oc) as described in the appropriate documentation for **your cluster: 

Installing the OpenShift CLI for OpenShift Container Platform 

Installing the OpenShift CLI for Red Hat OpenShift Service on AWS 

Procedure 

1. Install the latest version of the Intel Gaudi Base Operator, as described in Intel Gaudi Base Operator OpenShift installation. 

2. By default, OpenShift sets a per-pod PID limit of 4096. If your workload requires more processing power, such as when you use multiple Gaudi accelerators or when using vLLM with **Ray, you must manually increase the per-pod PID limit to avoid Resource temporarily unavailable errors. These errors occur due to PID exhaustion. Red Hat recommends setting this **limit to 32768, although values over 20000 are sufficient. 

a. Run the following command to label the node: 

oc label node <node_name> custom-kubelet=set-pod-pid-limit-kubelet 

b. Optional: To prevent workload distribution on the affected node, you can mark the node as unschedulable and then drain it in preparation for maintenance. For more information, see Understanding how to evacuate pods on nodes . 

**c. Create a custom-kubelet-pidslimit.yaml KubeletConfig resource file with the following content. Set the PodPidsLimit value to 32768: **

apiVersion: machineconfiguration.openshift.io/v1 kind: KubeletConfig metadata:   name: custom-kubelet-pidslimit 

d. Apply the configuration: 

oc apply -f custom-kubelet-pidslimit.yaml 

This operation causes the node to reboot. For more information, see Understanding node rebooting. 

e. Optional: If you previously marked the node as unschedulable, you can allow scheduling again after the node reboots. 

3. Create a custom workbench image for Intel Gaudi AI accelerators, as described in Creating custom workbench images. 

4. After installing the Intel Gaudi Base Operator, create a hardware profile, as described in Working with hardware profiles. 

Verification 

1. Go to the Installed Operators page. The navigation path depends on your OpenShift version: 

On OpenShift 4.20 and later, click Ecosystem → Installed Operators. 

On OpenShift 4.19, click Operators → Installed Operators. 

2. Confirm that the following Operators appear: 

Intel Gaudi Base Operator 

Node Feature Discovery (NFD) 

Kernel Module Management (KMM) 

7.3. AMD GPU INTEGRATION 

You can use AMD GPUs with OpenShift AI to accelerate AI and machine learning (ML) workloads. AMD GPUs provide high-performance compute capabilities, allowing users to process large data sets, train deep neural networks, and perform complex inference tasks more efficiently. 

Integrating AMD GPUs with OpenShift AI involves the following components: 

ROCm workbench images: Use the ROCm workbench images to streamline AI/ML workflows on AMD GPUs. These images include libraries and frameworks optimized with the AMD ROCm platform, enabling high-performance workloads for PyTorch and TensorFlow. The preconfigured images reduce setup time and provide an optimized environment for GPU-accelerated development and experimentation. 

AMD GPU Operator: The AMD GPU Operator simplifies GPU integration by automating driver installation, device plugin setup, and node labeling for GPU resource management. It ensures compatibility between OpenShift and AMD hardware while enabling scaling of GPU-enabled 

spec:   kubeletConfig:     PodPidsLimit: 32768   machineConfigPoolSelector:     matchLabels:       custom-kubelet: set-pod-pid-limit-kubelet 

workloads. 

7.3.1. Verify AMD GPU availability on your cluster 

Before you proceed with the AMD GPU Operator installation process, you can verify the presence of an **AMD GPU device on a node within your OpenShift cluster. You can use commands such as lspci or oc **to confirm hardware and resource availability. 

Prerequisites 

You have administrative access to the OpenShift cluster. 

You have a running OpenShift cluster with a node equipped with an AMD GPU. 

**You have access to the OpenShift CLI (oc) and terminal access to the node. **

Procedure 

**1. Use the OpenShift CLI (oc) to verify if GPU resources are allocatable: **

a. List all nodes in the cluster to identify the node with an AMD GPU: 

oc get nodes 

b. Note the name of the node where you expect the AMD GPU to be present. 

c. Describe the node to check its resource allocation: 

oc describe node <node_name> 

d. In the output, locate the Capacity and Allocatable sections and confirm that **amd.com/gpu is listed. For example: **

Capacity:   amd.com/gpu:  1 Allocatable:   amd.com/gpu:  1 

**2. Check for the AMD GPU device using the lspci command: **

a. Log in to the node: 

oc debug node/<node_name> chroot /host 

**b. Run the lspci command and search for the supported AMD device in your deployment. For **example: 

lspci | grep -E "MI210|MI250|MI300|MI350|MI355" 

c. Verify that the output includes one of the AMD GPU models. For example: 

03:00.0 Display controller: Advanced Micro Devices, Inc. [AMD] Instinct MI210 

**3. Optional: Use the rocminfo command if the ROCm stack is installed on the node: **

rocminfo 

a. Confirm that the ROCm tool outputs details about the AMD GPU, such as compute units, memory, and driver status. 

Verification 

**The oc describe node <node_name> command lists amd.com/gpu under Capacity and **Allocatable. 

**The lspci command output identifies an AMD GPU as a PCI device matching one of the **specified models (for example, MI210, MI250, MI300, MI350, MI355). 

**Optional: The rocminfo tool provides detailed GPU information, confirming driver and hardware **configuration. 

Additional resources 

AMD GPU Operator GitHub Repository 

7.3.2. Enable AMD GPUs 

Before you can use AMD GPUs in OpenShift AI, you must install the required dependencies, deploy the AMD GPU Operator, and configure the environment. 

Prerequisites 

You have logged in to OpenShift. 

**You have the cluster-admin role in OpenShift. **

You have installed your AMD GPU and confirmed that it is detected in your environment. 

If you are running OpenShift AI in a public cloud, you have verified that your cloud provider offers instances with AMD GPUs supported by the AMD GPU Operator and ROCm. You can verify instance and VM types and GPU models against the AMD GPU Operator support matrix . 

Procedure 

1. Install the latest version of the AMD GPU Operator, as described in Install AMD GPU Operator on OpenShift. 

2. After installing the AMD GPU Operator, configure the AMD drivers required by the Operator as described in the documentation: Configure AMD drivers for the GPU Operator . 

NOTE 

Alternatively, you can install the AMD GPU Operator from the Red Hat Catalog. For more information, see Install AMD GPU Operator from Red Hat Catalog . 

1. After installing the AMD GPU Operator, create a hardware profile, as described in Working with hardware profiles. 

Verification 

1. Go to the Installed Operators page. The navigation path depends on your OpenShift version: 

On OpenShift 4.20 and later, click Ecosystem → Installed Operators. 

On OpenShift 4.19, click Operators → Installed Operators. 

2. Confirm that the following Operators appear: 

AMD GPU Operator 

Node Feature Discovery (NFD) 

Kernel Module Management (KMM) 

NOTE 

Ensure that you follow all the steps for proper driver installation and configuration. Incorrect installation or configuration may prevent the AMD GPUs from being recognized or functioning properly. 

### CHAPTER 8. MANAGE WORKLOADS WITH KUEUE

As a cluster administrator, you can manage AI and machine learning workloads at scale by integrating the Red Hat build of Kueue with Red Hat OpenShift AI. This integration provides capabilities for quota management, resource allocation, and prioritized job scheduling. 

IMPORTANT 

Starting with OpenShift AI 2.24, the embedded Kueue component for managing distributed workloads is deprecated. Kueue is now provided through Red Hat build of Kueue, which is installed and managed by the Red Hat build of Kueue Operator. You cannot install both the embedded Kueue and the Red Hat build of Kueue Operator on the same cluster because this creates conflicting controllers that manage the same resources. 

OpenShift AI does not automatically migrate existing workloads. To ensure your workloads continue using queue management after upgrading, cluster administrators must manually migrate from the embedded Kueue to the Red Hat build of Kueue *Operator. For more information, see Migrate to the Red Hat build of Kueue Operator *. 

Additional resources 

Migrate to the Red Hat build of Kueue Operator 

8.1. KUEUE WORKLOAD MANAGEMENT 

You can use Kueue in OpenShift AI to manage AI and machine learning workloads at scale. Kueue controls how cluster resources are allocated and shared through hierarchical quota management, dynamic resource allocation, and prioritized job scheduling. These capabilities help prevent cluster contention, ensure fair access across teams, and optimize the use of heterogeneous compute resources, such as hardware accelerators. 

**You can use Kueue to schedule diverse workloads, including distributed training jobs (RayJob, RayCluster, PyTorchJob), workbenches (Notebook), and model serving ( InferenceService). Kueue **validation and queue enforcement apply only to workloads in namespaces with the **kueue.openshift.io/managed=true label. **

Using Kueue in OpenShift AI provides these benefits: 

Prevents resource conflicts and prioritizes workload processing 

Manages quotas across teams and projects 

Ensures consistent scheduling for all workload types 

Maximizes GPU and other specialized hardware use 

IMPORTANT 

Starting with OpenShift AI 2.24, the embedded Kueue component for managing distributed workloads is deprecated. Kueue is now provided through Red Hat build of Kueue, which is installed and managed by the Red Hat build of Kueue Operator. You cannot install both the embedded Kueue and the Red Hat build of Kueue Operator on the same cluster because this creates conflicting controllers that manage the same resources. 

OpenShift AI does not automatically migrate existing workloads. To ensure your workloads continue using queue management after upgrading, cluster administrators must manually migrate from the embedded Kueue to the Red Hat build of Kueue *Operator. For more information, see Migrate to the Red Hat build of Kueue Operator * in the Additional resources section. 

Kueue management states: 

**You configure how OpenShift AI interacts with Kueue by setting the managementState in the DataScienceCluster object. **

**Unmanaged **

**This state is supported for using Kueue with OpenShift AI. In Unmanaged state, OpenShift AI **integrates with an existing Kueue installation managed by the Red Hat build of Kueue Operator. You must have the Red Hat build of Kueue Operator installed and running on the cluster. **When you enable Unmanaged mode, the OpenShift AI Operator creates a default Kueue custom **resource (CR) if one does not already exist. This prompts the Red Hat build of Kueue Operator to activate Kueue on the cluster. 

**Managed **

This state is deprecated. Previously, OpenShift AI deployed and managed an embedded Kueue **distribution. Managed mode is not compatible with the Red Hat build of Kueue Operator. If both are **installed, OpenShift AI stops reconciliation to avoid conflicts. You must migrate any environment by **using the Managed state to the Unmanaged state to ensure continued support. **

**Removed **

**This state disables Kueue in OpenShift AI. If the state was previously Managed, OpenShift AI uninstalls the embedded Kueue distribution. If the state was previously Unmanaged, OpenShift AI **stops checking for the external Kueue integration but does not uninstall the Red Hat build of Kueue **Operator. An empty managementState value also functions as Removed. **

Queue creation modes: 

**You control whether the OpenShift AI Operator automatically creates default ClusterQueue and LocalQueue resources by setting the autoCreateQueues field in the DataScienceCluster resource. **

**Operator-managed queues: autoCreateQueues: true **

**The Operator creates a default ClusterQueue and a LocalQueue in each Kueue-managed namespace. The Operator applies the platform.opendatahub.io/part-of=kueue label to these resources. You can customize the queue names by using the defaultClusterQueueName and defaultLocalQueueName fields. This mode is suitable for quick-start deployments and evaluation **environments. 

**Self-managed queues: autoCreateQueues: false or omitted **

**The Operator does not create queue resources. You manage all ClusterQueue and LocalQueue **

**resources outside the Operator by using GitOps tools, kubectl, or the Red Hat build of Kueue **Operator directly. This mode is the default and is suitable for enterprise multitenant GPU environments that require strict quota control. *For more information, see Manage ClusterQueues and LocalQueues outside the Operator * in Additional resources. 

NOTE 

**When autoCreateQueues transitions from true to false, the Operator stops creating new queue resources but does not remove previously created ClusterQueue or LocalQueue **instances. 

Queue enforcement for projects: 

To ensure workloads do not bypass the queuing system, a validating webhook automatically enforces queuing rules on any project that is enabled for Kueue management. You enable a project for Kueue **management by applying the kueue.openshift.io/managed=true label to the project namespace. **

NOTE 

This validating webhook enforcement method replaces the Validating Admission Policy that was used with the deprecated embedded Kueue component. The system also **supports the legacy kueue-managed label for backward compatibility, but kueue.openshift.io/managed=true is the recommended label going forward. **

After a project is enabled for Kueue management, the webhook requires that any new or updated **workload has the kueue.x-k8s.io/queue-name label. If this label is missing, the webhook prevents the **workload from being created or updated. 

**When autoCreateQueues is set to true, OpenShift AI creates a default, cluster-scoped ClusterQueue and a namespace-scoped LocalQueue for that namespace if one does not already exist. These default resources are created with the opendatahub.io/managed=false annotation, so they are not managed **after creation. Cluster administrators can change or delete them. 

**When autoCreateQueues is set to false or is omitted, the Operator does not create queue resources. You must create ClusterQueue and LocalQueue resources before submitting workloads. **

NOTE 

**Enabling Kueue in the OpenShift AI dashboard creates a LocalQueue in new project namespaces independently of the autoCreateQueues setting. This dashboard-triggered queue creation is a separate mechanism from the DataScienceCluster-level queue creation controlled by autoCreateQueues. **

**The webhook enforces this rule on the create and update operations for the following resource types: **

**InferenceService **

**Notebook **

**PyTorchJob **

**RayCluster **

**RayJob **

NOTE 

You can apply hardware profiles to other workload types, but the validation webhook **enforces the kueue.x-k8s.io/queue-name label requirement only for these specific **resource types. 

Restrictions for managing workloads with Kueue: 

When you use Kueue to manage workloads in OpenShift AI, the following restrictions apply: 

**Namespaces must be labeled with kueue.openshift.io/managed=true to enable Kueue **validation and queue enforcement. 

All workloads that you create from the OpenShift AI dashboard, such as workbenches and model servers, must use a hardware profile that specifies a local queue. 

When you specify a local queue in a hardware profile, OpenShift AI automatically applies the **corresponding kueue.x-k8s.io/queue-name label to workloads that use that profile. **

You cannot use hardware profiles that contain node selectors or tolerations for node placement. To direct workloads to specific nodes, use a hardware profile that specifies a local queue that is associated with a queue configured with the appropriate resource flavors. 

Because workbenches are not suspendable workloads, you can only assign them to a local queue that is associated with a non-preemptive cluster queue. 

**When autoCreateQueues is set to true, the default cluster queue that OpenShift AI creates is **non-preemptive. If you manage queues outside the Operator, ensure that your cluster queue is configured as non-preemptive for workbench workloads. 

Workbench scheduling visibility: 

**When a project namespace has the kueue.openshift.io/managed=true label and Kueue is enabled, the **OpenShift AI dashboard provides scheduling visibility for workbenches in that project. 

The following indicators are available: 

Project-level Kueue indicator 

An informational banner is displayed on the project details page confirming that the project uses queue-based scheduling. This banner is mutually exclusive with the Kueue-disabled alert. 

Workbench scheduling states 

The Status column on the Workbenches tab displays Kueue-derived states such as Queued, Inadmissible, Preempted, and Evicted for workbenches in the project. When a workbench is admitted by Kueue, the status column shows Starting rather than a Kueue-specific label. Data scientists can monitor these states to track the progress of their workbenches through the scheduling system. 

Anomaly warning for workbenches bypassing Kueue 

**When a workbench in a Kueue-managed namespace lacks the kueue.x-k8s.io/queue-name label, it **bypasses Kueue scheduling entirely. The dashboard shows a warning indicator on those workbench rows with a tooltip explaining the bypass. This situation typically occurs when a workbench is created 

through GitOps or the command-line interface without a queue assignment. 

Additional resources 

Manage ClusterQueues and LocalQueues outside the Operator 

Migrate to the Red Hat build of Kueue Operator 

Red Hat build of Kueue documentation 

Kueue workload scheduling status for workbenches 

8.1.1. Kueue workflow 

Managing workloads with Kueue in OpenShift AI involves tasks for OpenShift cluster administrators, OpenShift AI administrators, and machine learning (ML) engineers or data scientists: 

Cluster administrator 

Installs and configures Kueue: 

*1. Installs the Red Hat build of Kueue Operator on the cluster, as described in the Red Hat build of Kueue documentation in Additional resources. *

**2. Activates the Kueue integration by setting the managementState to Unmanaged in the *****DataScienceCluster custom resource, as described in Configure workload management with ****Kueue in Additional resources. *

3. Chooses a queue management mode: 

**Operator-managed queues: Sets autoCreateQueues to true to have the Operator create default ClusterQueue and LocalQueue resources. **

**Self-managed queues: Keeps autoCreateQueues set to false or omits it, then creates ClusterQueue and LocalQueue resources outside the Operator by using GitOps, kubectl, ***or the Red Hat build of Kueue Operator directly. For more information, see Manage ClusterQueues and LocalQueues outside the Operator in Additional resources. *

4. Configures quotas to optimize resource allocation for user workloads, as described in the *Red Hat build of Kueue documentation in Additional resources. *

**5. Enables Kueue in the dashboard by setting disableKueue to false in the *****OdhDashboardConfig custom resource, as described in Enable Kueue in the dashboard *** in Additional resources. 

NOTE 

When Kueue is enabled in the dashboard, OpenShift AI automatically enables Kueue management for all new projects created from the dashboard. 

OpenShift AI administrator 

Prepares the OpenShift AI environment: 

1. Creates Kueue-enabled hardware profiles so that users can submit workloads from the *OpenShift AI dashboard, as described in Working with hardware profiles * in Additional resources. 

ML Engineer or data scientist 

Submits workloads to the queuing system and monitors scheduling status: 

1. For workloads created from the OpenShift AI dashboard, such as workbenches and model servers, selects a Kueue-enabled hardware profile during creation. 

2. For workloads created by using a command-line interface or a software development kit (SDK), **such as distributed training jobs, adds the kueue.x-k8s.io/queue-name label to the workload’s YAML manifest and sets its value to the target LocalQueue name. **

3. After starting or creating a workbench, views the scheduling status on the Workbenches tab. For Kueue-managed workbenches, the status shows the current Kueue state, such as Queued or Starting, and the queue position when available. 

NOTE 

When Kueue is enabled in the dashboard, workbenches that were created through **GitOps or the command-line interface without the kueue.x-k8s.io/queue-name label **bypass Kueue scheduling and show an anomaly warning on the Workbenches tab. 

Additional resources 

Red Hat build of Kueue documentation 

Configure workload management with Kueue 

Manage ClusterQueues and LocalQueues outside the Operator 

Enable Kueue in the dashboard 

View workbench scheduling status 

Working with hardware profiles 

8.2. CONFIGURE WORKLOAD MANAGEMENT WITH KUEUE 

To use workload queuing in OpenShift AI, install the Red Hat build of Kueue Operator, activate the Kueue integration, and choose how to manage queue resources. You can have the Operator create default queue resources automatically, or you can manage queues outside the Operator for strict quota control. 

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

You are using OpenShift 4.19 or later. 

You have installed and configured the cert-manager Operator for Red Hat OpenShift for your cluster. 

**You have installed the OpenShift CLI (oc) as described in the appropriate documentation for **your cluster: 

Installing the OpenShift CLI for OpenShift Container Platform 

Installing the OpenShift CLI for Red Hat OpenShift Service on AWS 

Procedure 

**1. In a terminal window, log in to the OpenShift CLI (oc) as shown in the following example: **

2. Install the Red Hat build of Kueue Operator on your OpenShift cluster as described in the Red Hat build of Kueue documentation . 

3. Activate the Kueue integration. Choose one of the following options based on how you want to manage queue resources. 

NOTE 

**In OpenShift AI 3.5, the autoCreateQueues field defaults to false. The Operator does not create default ClusterQueue or LocalQueue resources unless you explicitly set autoCreateQueues to true. **

Operator-managed queues with predefined names: To have the Operator create default **queue resources with the predefined name default, run the following command. Replace <operator_namespace> with your Operator namespace. The default Operator namespace is redhat-ods-operator. **

Operator-managed queues with custom names: To have the Operator create default queue resources with custom names, run the following command. Replace **<example_cluster_queue> and <example_local_queue> with your custom queue names, and replace <operator_namespace> with your Operator namespace. The default Operator namespace is redhat-ods-operator. **

Self-managed queues: To manage queue resources outside the Operator by using GitOps, **kubectl, or the Red Hat build of Kueue Operator directly, run the following command. Replace <operator_namespace> with your Operator namespace. The default Operator namespace is redhat-ods-operator. **

**Because autoCreateQueues defaults to false, this command activates the Kueue **integration without creating Operator-managed queue resources. You must create 

*$ oc login <openshift_cluster_url> -u <admin_username> -p <password> *

$ oc patch datasciencecluster default-dsc --type='merge' -p '{"spec":{"components": {"kueue":{"managementState":"Unmanaged","autoCreateQueues":true}}}}' -n <operator_namespace> 

$ oc patch datasciencecluster default-dsc --type='merge' -p '{"spec":{"components": {"kueue": {"managementState":"Unmanaged","autoCreateQueues":true,"defaultClusterQueueName ":"<example_cluster_queue>","defaultLocalQueueName":"<example_local_queue>"}}}}' -n <operator_namespace> 

$ oc patch datasciencecluster default-dsc --type='merge' -p '{"spec":{"components": {"kueue":{"managementState":"Unmanaged"}}}}' -n <operator_namespace> 

**ClusterQueue and LocalQueue resources before submitting workloads. For more **information, see Manage ClusterQueues and LocalQueues outside the Operator . 

Verification 

**1. Verify that the Kueue custom resource was created: **

**You see a Kueue CR listed. If no resource is returned, the OpenShift AI Operator has not **activated Kueue, and subsequent steps fail. 

2. Verify that the Red Hat build of Kueue pods are running: 

**If the Red Hat build of Kueue Operator was installed in a custom namespace, replace openshift-kueue-operator with your namespace. **

You see output similar to the following example: 

kueue-controller-manager-d9fc745df-ph77w    1/1     Running openshift-kueue-operator-69cfbf45cf-lwtpm   1/1     Running 

**3. If you chose Operator-managed queues, verify that the default ClusterQueue was created: **

**4. If you chose self-managed queues, verify that no Operator-managed ClusterQueue exists: **

The output should show no resources. 

Next steps 

Manage ClusterQueues and LocalQueues outside the Operator 

Red Hat build of Kueue documentation 

Enable Kueue in the dashboard 

Working with hardware profiles 

8.2.1. Enable Kueue in the dashboard 

Enable Kueue in the OpenShift AI dashboard so that users can select Kueue-enabled options when creating workloads. 

When you enable Kueue in the dashboard, OpenShift AI automatically enables Kueue management for all new projects created from the dashboard. For these projects, OpenShift AI applies the **kueue.openshift.io/managed=true label to the namespace and creates a LocalQueue object if one does not already exist. The LocalQueue object is created with the opendatahub.io/managed=false **

$ oc get kueue -A 

$ oc get pods -n openshift-kueue-operator 

$ oc get clusterqueues 

$ oc get clusterqueues -l platform.opendatahub.io/part-of=kueue 

annotation, so it is not managed after creation. Cluster administrators can modify or delete it as needed. A validating webhook then enforces that any new or updated workload resource in a Kueue-enabled **project includes the kueue.x-k8s.io/queue-name label. **

NOTE 

**This dashboard-triggered LocalQueue creation in new project namespaces is independent of the autoCreateQueues setting in the DataScienceCluster resource. The autoCreateQueues field controls whether the Operator creates default ClusterQueue and LocalQueue resources at the DataScienceCluster level. The dashboard creates a LocalQueue in new projects regardless of whether autoCreateQueues is true or false. **

NOTE 

**For existing projects, or for projects created by using the OpenShift CLI (oc), you must enable Kueue management manually by applying the kueue.openshift.io/managed=true **label to the project namespace. 

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

You are using OpenShift 4.19 or later. 

You have installed and activated the Red Hat build of Kueue Operator, as described in Configure workload management with Kueue. 

You have configured quotas, as described in the Red Hat build of Kueue documentation . 

Procedure 

**1. In a terminal window, log in to the OpenShift CLI (oc) as shown in the following example: **

**2. Update the odh-dashboard-config custom resource in the OpenShift AI applications namespace. Replace <applications_namespace> with your OpenShift AI applications namespace. The default is redhat-ods-applications. **

Verification 

1. From the OpenShift AI dashboard, create a new project. 

2. Verify that the project namespace is labeled for Kueue management: 

$ oc label namespace <project_namespace> kueue.openshift.io/managed=true --overwrite 

*$ oc login <openshift_cluster_url> -u <admin_username> -p <password> *

$ oc patch odhdashboardconfig odh-dashboard-config \   -n <applications_namespace> \   --type merge \ *  -p {"spec":{"dashboardConfig":{"disableKueue":false}}} *

**The output should be true. **

**3. Confirm that a LocalQueue exists for the project namespace: **

**The LocalQueue might be created by the dashboard for new projects, by the Operator when autoCreateQueues is true, or by the cluster administrator when managing queues outside the **Operator. 

**4. Create a test workload, for example a Notebook, and verify that it includes the kueue.x-k8s.io/queue-name label. **

Next steps 

Working with hardware profiles 

8.2.2. Manage ClusterQueues and LocalQueues outside the Operator 

**You can manage ClusterQueue and LocalQueue resources outside the OpenShift AI Operator to enforce strict quota control in multitenant GPU environments. When autoCreateQueues is set to false in the DataScienceCluster resource, the Operator does not create queue resources, and you manage all queue resources by using GitOps tools, kubectl, or the Red Hat build of Kueue Operator directly. **

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

You are using OpenShift 4.19 or later. 

You have installed and configured the cert-manager Operator for Red Hat OpenShift for your cluster. 

You have installed the Red Hat build of Kueue Operator on your cluster, as described in the Red Hat build of Kueue documentation . 

**You have activated the Kueue integration by setting kueue.managementState to Unmanaged in the DataScienceCluster resource, as described in Configure workload management with **Kueue. 

**The autoCreateQueues field is set to false or is omitted in the DataScienceCluster resource. **This is the default behavior. 

**You have installed the OpenShift CLI (oc) as described in the appropriate documentation for **your cluster: 

Installing the OpenShift CLI for OpenShift Container Platform 

Installing the OpenShift CLI for Red Hat OpenShift Service on AWS 

$ oc get ns <project_namespace> -o jsonpath='{.metadata.labels.kueue\.openshift\.io/managed}{"\n"}' 

$ oc get localqueues -n <project_namespace> 

**The jq command-line JSON processor is installed on your workstation. This tool is used in the **verification steps. 

Procedure 

**1. In a terminal window, log in to the OpenShift CLI (oc) as shown in the following example: **

**2. Verify that autoCreateQueues is set to false or is not present in the DataScienceCluster **resource: 

**The autoCreateQueues field is either absent or set to false. If the field is set to true, the **Operator manages queue resources automatically and you do not need to create them manually. 

**3. Create a ClusterQueue resource with quota definitions. The following example creates a **cluster queue with CPU, memory, and GPU quotas: 

where: 

**<cluster_queue_name> **

**Specifies the name of the cluster queue, for example team-gpu-cluster-queue. **

**namespaceSelector: {} **

Specifies that all namespaces can submit workloads to this cluster queue. In multitenant environments, replace this with a label selector to restrict access to specific namespaces. 

**<resource_flavor_name> **

**Specifies the name of a ResourceFlavor you have already created. For ResourceFlavor **configuration, see Configuring a resource flavor . 

**nominalQuota **

Specifies the maximum amount of each resource that the cluster queue can allocate. Replace the example quota values with values appropriate for your cluster. If you use AMD **GPUs, replace nvidia.com/gpu with amd.com/gpu in the example code. **

*$ oc login <openshift_cluster_url> -u <admin_username> -p <password> *

$ oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kueue}' | jq . 

apiVersion: kueue.x-k8s.io/v1beta1 kind: ClusterQueue metadata:   name: <cluster_queue_name> spec:   namespaceSelector: {}   resourceGroups:   - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]     flavors:     - name: "<resource_flavor_name>"       resources:       - name: "cpu"         nominalQuota: 9       - name: "memory"         nominalQuota: 36Gi       - name: "nvidia.com/gpu"         nominalQuota: 5 

Apply the configuration: 

**4. Create a LocalQueue resource in each project namespace that points to the cluster queue. **The following example creates a local queue in a project namespace: 

where: 

**<local_queue_name> **

**Specifies the name of the local queue, for example team-gpu-local-queue. **

**<project_namespace> **

Specifies the namespace of the project that uses this queue. 

**<cluster_queue_name> **

Specifies the name of the cluster queue you created in the previous step. Apply the configuration: 

Repeat this step for each project namespace that requires workload scheduling. 

5. Enable Kueue management for each project namespace by applying the **kueue.openshift.io/managed=true label: **

Verification 

**1. Verify that the ClusterQueue resource was created and is active: **

**2. Verify that the LocalQueue resource exists in the target namespace: **

3. Verify that the local queue is ready to admit workloads: 

$ oc apply -f cluster_queue.yaml 

apiVersion: kueue.x-k8s.io/v1beta1 kind: LocalQueue metadata:   name: <local_queue_name>   namespace: <project_namespace> spec:   clusterQueue: <cluster_queue_name> 

$ oc apply -f local_queue.yaml 

$ oc label namespace <project_namespace> kueue.openshift.io/managed=true --overwrite 

$ oc get clusterqueues 

$ oc get localqueues -n <project_namespace> 

$ oc get localqueues -n <project_namespace> -o jsonpath='{.items[0].status.conditions}' | jq . 

NOTE 

**When autoCreateQueues is false, the Operator does not create, modify, or reconcile any **queue resources. Previously created queue resources remain on the cluster. Resources you create outside the Operator are not affected. 

Next steps 

Enable Kueue in the dashboard 

Working with hardware profiles 

Red Hat build of Kueue documentation 

8.3. TROUBLESHOOTING REFERENCE: KUEUE 

If your users are experiencing errors in Red Hat OpenShift AI relating to Kueue workloads, read this section to understand what could be causing the problem, and how to resolve the problem. 

If the problem is not documented here or in the release notes, contact Red Hat Support. 

8.3.1. A user receives a "failed to call webhook" error message for Kueue 

Problem 

**After the user runs the cluster.apply() command, the following error is shown: **

Diagnosis 

The Kueue pod might not be running. 

Resolution 

1. In the OpenShift console, select the user’s project from the Project list. 

**2. Click Workloads → Pods. **

3. Verify that the Kueue pod is running. If necessary, restart the Kueue pod. 

4. Review the logs for the Kueue pod to verify that the webhook server is serving, as shown in the following example: 

ApiException: (500) Reason: Internal Server Error HTTP response body: {"kind":"Status","apiVersion":"v1","metadata": {},"status":"Failure","message":"Internal error occurred: failed calling webhook \"mraycluster.kb.io\": failed to call webhook: Post \"https://kueue-webhook-service.redhat-ods-applications.svc:443/mutate-ray-io-v1-raycluster?timeout=10s\": no endpoints available for service \"kueue-webhook-service\"","reason":"InternalError","details":{"causes":[{"message":"failed calling webhook \"mraycluster.kb.io\": failed to call webhook: Post \"https://kueue-webhook-service.redhat-ods-applications.svc:443/mutate-ray-io-v1-raycluster?timeout=10s\": no endpoints available for service \"kueue-webhook-service\""}]},"code":500} 

8.3.2. A user receives a "Default Local Queue …​ not found" error message 

Problem 

**After the user runs the cluster.apply() command, the following error is shown: **

Diagnosis 

No default local queue is defined, and a local queue is not specified in the cluster configuration. 

Resolution 

1. Check whether a local queue exists in the user’s project, as follows: 

a. In the OpenShift console, select the user’s project from the Project list. 

**b. Click Home → Search, and from the Resources list, select LocalQueue. **

c. If no local queues are found, create a local queue. 

d. Provide the user with the details of the local queues in their project, and advise them to add a local queue to their cluster configuration. 

2. Define a default local queue. For information about creating a local queue and defining a default local queue, see Configuring quota management for distributed workloads. 

8.3.3. A user receives a "local_queue provided does not exist" error message 

Problem 

**After the user runs the cluster.apply() command, the following error is shown: **

Diagnosis 

An incorrect value is specified for the local queue in the cluster configuration, or an incorrect default local queue is defined. The specified local queue either does not exist, or exists in a different namespace. 

Resolution 

a. In the OpenShift console, select the user’s project from the Project list. 

1. Click Search, and from the Resources list, select LocalQueue. 

{"level":"info","ts":"2024-06-24T14:36:24.255137871Z","logger":"controller-runtime.webhook","caller":"webhook/server.go:242","msg":"Serving webhook server","host":"","port":9443} 

Default Local Queue with kueue.x-k8s.io/default-queue: true annotation not found please create a default Local Queue or provide the local_queue name in Cluster Configuration. 

local_queue provided does not exist or is not in this namespace. Please provide the correct local_queue name in Cluster Configuration. 

2. Resolve the problem in one of the following ways: 

If no local queues are found, create a local queue. 

If one or more local queues are found, provide the user with the details of the local queues in their project. Advise the user to ensure that they spelled the local queue **name correctly in their cluster configuration, and that the namespace value in the **cluster configuration matches their project name. 

3. Define a default local queue. For information about creating a local queue and defining a default local queue, see Configuring quota management for distributed workloads . 

8.3.4. The pod provisioned by Kueue is terminated before the image is pulled 

Problem 

Kueue waits for a period of time before marking a workload as ready for all of the workload pods to become provisioned and running. By default, Kueue waits for 5 minutes. If the pod image is very large and is still being pulled after the 5-minute waiting period elapses, Kueue fails the workload and terminates the related pods. 

Diagnosis 

1. In the OpenShift console, select the user’s project from the Project list. 

2. Click Workloads → Pods. 

3. Click the user’s pod name to open the pod details page. 

4. Click the Events tab, and review the pod events to check whether the image pull completed successfully. 

Resolution 

If the pod takes more than 5 minutes to pull the image, resolve the problem in one of the following ways: 

**Add an OnFailure restart policy for resources that are managed by Kueue. **

**Configure a custom timeout for the waitForPodsReady property in the Kueue custom resource (CR). The CR is installed in the openshift-kueue-operator namespace by the Red Hat **build of Kueue Operator. 

For more information about this configuration option, see Enabling waitForPodsReady in the Kueue documentation. 

8.3.5. Additional resources 

Troubleshooting common problems with distributed workloads for administrators 

Troubleshooting common problems with distributed workloads for users 

8.4. MIGRATE TO THE RED HAT BUILD OF KUEUE OPERATOR 

Starting with OpenShift AI 2.24, the embedded Kueue component for managing distributed workloads is deprecated. 

OpenShift AI now uses the Red Hat build of Kueue Operator to provide enhanced workload scheduling for distributed training, workbench, and model serving workloads. 

Check if your environment is using the embedded Kueue component by verifying the **spec.components.kueue.managementState field in the DataScienceCluster custom resource. If the field is set to Managed, you must migrate to the Red Hat build of Kueue Operator before upgrading **OpenShift AI to avoid controller conflicts and ensure continued support for queue-based workloads. 

OpenShift AI does not automatically migrate workloads, and you cannot install both the embedded Kueue and the Red Hat build of Kueue Operator on the same cluster. 

Prerequisites 

Your environment is currently using the embedded Kueue component. That is, the **spec.components.kueue.managementState field in the DataScienceCluster custom resource is set to Managed. **

NOTE 

**If spec.components.kueue.managementState is set to Removed or Unmanaged, skip this migration. **

You have cluster administrator privileges for your OpenShift cluster. 

You are using OpenShift 4.19 or later. 

You have installed and configured the cert-manager Operator for Red Hat OpenShift for your cluster. 

Procedure 

1. Optional: When you migrate from the embedded Kueue to Red Hat build of Kueue, the **OpenShift AI Operator automatically moves your existing Kueue configuration from the kueue-manager-config ConfigMap to the Kueue custom resource (CR). If you want to keep the kueue-manager-config ConfigMap for reference, run the following command. Replace <applications_namespace> with your OpenShift AI applications namespace. The default namespace is redhat-ods-applications. **

2. Log in to the OpenShift web console as a cluster administrator. 

3. Uninstall the embedded Kueue component to avoid potential configuration conflicts. 

NOTE 

If you need to keep workloads running without interruption, you can skip this step. However, skipping it is not recommended because it might cause temporary configuration issues during the OpenShift AI upgrade. 

a. Go to the Installed Operators page. The navigation path depends on your OpenShift version: 

$ oc annotate configmap kueue-manager-config -n <applications_namespace> opendatahub.io/managed=false 

On OpenShift 4.20 and later, click Ecosystem → Installed Operators. 

On OpenShift 4.19, click Operators → Installed Operators. 

b. Click the Red Hat OpenShift AI Operator. 

c. Click the Data Science Cluster tab. 

d. Click the default-dsc object. 

e. Click the YAML tab. 

**f. Set spec.components.kueue.managementState to Removed as shown: **

g. Click Save. 

h. Wait for the OpenShift AI Operator to reconcile, and then verify that the embedded Kueue was removed: 

**On the Details tab of the default-dsc object, check that the KueueReady condition has a Status of False and a Reason of Removed. **

Go to Workloads → Deployments, select the project where OpenShift AI is installed **(for example, redhat-ods-applications), and confirm that Kueue-related deployments (for example, kueue-controller-manager) are no longer present. **

4. Install the Red Hat build of Kueue Operator on your OpenShift cluster: 

a. Follow the steps to install the Red Hat build of Kueue Operator, as described in the Red Hat build of Kueue documentation. 

b. Go to Ecosystem → Installed Operators and confirm that the Red Hat build of Kueue Operator is listed with Status as Succeeded. 

5. Activate the Red Hat build of Kueue Operator in OpenShift AI: 

a. In the web console, go to the Installed Operators page. The navigation path depends on your OpenShift version: 

On OpenShift 4.20 and later, click Ecosystem → Installed Operators. 

On OpenShift 4.19, click Operators → Installed Operators. 

b. Click the Red Hat OpenShift AI Operator. 

c. Click the Data Science Cluster tab. 

d. Click the default-dsc object. 

e. Click the YAML tab. 

spec:   components:     kueue:       managementState: Removed 

**f. Set spec.components.kueue.managementState to Unmanaged and choose a queue **management mode. The following examples show the available options. 

NOTE 

**In OpenShift AI 3.5, autoCreateQueues defaults to false. If you want the **Operator to create default queue resources after migrating from embedded **Kueue, you must explicitly set autoCreateQueues to true. **

To use Operator-managed queues with the predefined queue names, apply the following configuration: 

To use Operator-managed queues with custom queue names, apply the following **configuration, replacing <example_cluster_queue> and <example_local_queue> with **your custom values: 

**To manage queue resources outside the Operator, set only managementState to Unmanaged and omit autoCreateQueues. For more information, see Manage **ClusterQueues and LocalQueues outside the Operator. 

g. Click Save. 

6. Enable Kueue management for existing projects by applying the **kueue.openshift.io/managed=true label to each project namespace: **

**Replace <project_namespace> with the name of your project. **

NOTE 

Kueue validation and queue enforcement apply only to workloads in namespaces **labeled with kueue.openshift.io/managed=true. **

Verification 

1. Verify that the embedded Kueue component was removed by confirming that Kueue-related deployments are no longer present in the OpenShift AI applications namespace: 

spec:   components:     kueue:       managementState: Unmanaged       autoCreateQueues: true 

spec:   components:     kueue:       managementState: Unmanaged       autoCreateQueues: true       defaultClusterQueueName: <example_cluster_queue>       defaultLocalQueueName: <example_local_queue> 

$ oc label namespace <project_namespace> kueue.openshift.io/managed=true --overwrite 

The output should be empty, indicating that no Kueue-related deployments exist. 

**2. Verify that the DataScienceCluster resource shows a healthy Unmanaged status for Kueue: **

**Confirm that the reason field shows Unmanaged. **

3. Verify that the Red Hat build of Kueue Operator pods are running: 

**If the Red Hat build of Kueue Operator was installed in a custom namespace, replace openshift-kueue-operator with your namespace. **

4. Verify that queue resources are available: 

5. Verify that existing workloads in the queue continue to be processed by the Red Hat build of Kueue controllers by submitting a test workload and confirming that it is admitted. 

Next steps 

Red Hat build of Kueue documentation 

Enable Kueue in the dashboard 

Working with hardware profiles 

$ oc get deployments -n <applications_namespace> | grep kueue 

$ oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[? (@.type=="KueueReady")]}{"\n"}' 

$ oc get pods -n openshift-kueue-operator 

$ oc get clusterqueues $ oc get localqueues --all-namespaces 

### CHAPTER 9. MANAGE DISTRIBUTED WORKLOADS

**In OpenShift AI, distributed workloads like PyTorchJob, RayJob, and RayCluster are created and **managed by their respective workload operators. Kueue provides queueing and admission control and integrates with these operators to decide when workloads can run based on cluster-wide quotas. 

You can perform advanced configuration for your distributed workloads environment, such as configuring quota management or setting up a cluster for RDMA. 

9.1. CONFIGURE QUOTA MANAGEMENT FOR DISTRIBUTED WORKLOADS 

Configure quotas for distributed workloads by creating Kueue resources. Quotas ensure that you can share resources between several projects. 

Prerequisites 

**You have logged in to OpenShift with the cluster-admin role. **

**You have installed the OpenShift CLI (oc) as described in the appropriate documentation for **your cluster: 

Installing the OpenShift CLI for OpenShift Container Platform 

Installing the OpenShift CLI for Red Hat OpenShift Service on AWS 

You have installed and activated the Red Hat build of Kueue Operator as described in Configure workload management with Kueue. 

You have installed the required distributed workloads components as described in Installing the distributed workloads components (for disconnected environments, see Installing the distributed workloads components). 

You have created a project that contains a workbench, and the workbench is running a default workbench image that contains the CodeFlare SDK, for example, the Standard Data Science workbench. For information about how to create a project, see Creating a project . 

You have sufficient resources. In addition to the base OpenShift AI resources, you need 1.6 vCPU and 2 GiB memory to deploy the distributed workloads infrastructure. 

The resources are physically available in the cluster. For more information about Kueue resources, see the Red Hat build of Kueue documentation . 

If you want to use graphics processing units (GPUs), you have enabled GPU support in OpenShift AI. If you use NVIDIA GPUs, see Enabling NVIDIA GPUs. If you use AMD GPUs, see AMD GPU integration . 

NOTE 

In OpenShift AI 3.5, Red Hat supports only NVIDIA GPU accelerators and AMD GPU accelerators for distributed workloads. 

Procedure 

1. In a terminal window, if you are not already logged in to your OpenShift cluster as a cluster **administrator, log in to the OpenShift CLI (oc) as shown in the following example: **

2. Verify that a resource flavor exists or create a custom one, as follows: 

**a. Check whether a ResourceFlavor already exists: **

**b. If a ResourceFlavor already exists and you need to modify it, edit it in place: **

**c. If a ResourceFlavor does not exist or you want a custom one, create a file called default_flavor.yaml and populate it with the following content: **

Empty Kueue resource flavor 

For more examples, see Example Kueue resource configurations for distributed workloads . 

d. Perform one of the following actions: 

If you are modifying the existing resource flavor, save the changes. 

If you are creating a new resource flavor, apply the configuration to create the **ResourceFlavor object: **

3. Verify that a default cluster queue exists or create a custom one, as follows: 

NOTE 

**If autoCreateQueues is set to true in the DataScienceCluster resource, the **Operator automatically creates a default cluster queue when the Kueue integration is activated. You can verify and modify the default cluster queue, or **create a custom one. If autoCreateQueues is false or is omitted, no Operator-**managed cluster queue is created, and you must create one manually. 

**a. Check whether a ClusterQueue already exists: **

**b. If a ClusterQueue already exists and you need to modify it (for example, to change the **resources), edit it in place: 

*$ oc login <openshift_cluster_url> -u <admin_username> -p <password> *

$ oc get resourceflavors 

$ oc edit resourceflavor <existing_resourceflavor_name> 

apiVersion: kueue.x-k8s.io/v1beta1 kind: ResourceFlavor metadata:   name: <example_resource_flavor> 

$ oc apply -f default_flavor.yaml 

$ oc get clusterqueues 

**c. If a ClusterQueue does not exist or you want a custom one, create a file called cluster_queue.yaml and populate it with the following content: **

Example cluster queue 

**namespaceSelector - Defines which namespaces can use the resources governed by this cluster queue. An empty namespaceSelector as shown in the example means that **all namespaces can use these resources. 

**coveredResources - Defines the resource types governed by the cluster queue. This example ClusterQueue object governs CPU, memory, and GPU resources. If you use AMD GPUs, replace nvidia.com/gpu with amd.com/gpu in the example code. **

**name (under flavors) - Defines the resource flavor that is applied to the resource **types listed. In this example, the <resource_flavor_name> resource flavor is applied to CPU, memory, and GPU resources. 

**resources - Defines the resource requirements for admitting jobs. The cluster queue **starts a distributed workload only if the total required resources are within these quota limits. 

d. Replace the example quota values (9 CPUs, 36 GiB memory, and 5 NVIDIA GPUs) with the **appropriate values for your cluster queue. If you use AMD GPUs, replace nvidia.com/gpu with amd.com/gpu in the example code. For more examples, see Example Kueue resource **configurations for distributed workloads. You must specify a quota for each resource that the user can request, even if the requested **value is 0, by updating the spec.resourceGroups section as follows: **

**Include the resource name in the coveredResources list. **

**Specify the resource name and nominalQuota in the flavors.resources section, even if the nominalQuota value is 0. **

e. Perform one of the following actions: 

$ oc edit clusterqueue <existing_clusterqueue_name> 

apiVersion: kueue.x-k8s.io/v1beta1 kind: ClusterQueue metadata:   name: <example_cluster_queue> spec: **  namespaceSelector: {}  1 **  resourceGroups: **  - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]  2 **    flavors: **    - name: "<resource_flavor_name>"  3       resources:  4 **      - name: "cpu"         nominalQuota: 9       - name: "memory"         nominalQuota: 36Gi       - name: "nvidia.com/gpu"         nominalQuota: 5 

If you are modifying the existing cluster queue, save the changes. 

If you are creating a new cluster queue, apply the configuration to create the **ClusterQueue object: **

4. Verify that a local queue that points to your cluster queue exists for your project namespace, or create a custom one, as follows: 

NOTE 

**A LocalQueue might already exist in the project namespace from one of the following sources: the Operator when autoCreateQueues is true, the dashboard **for new projects when Kueue is enabled, or a cluster administrator managing queues outside the Operator. You can verify and modify the local queue, or create a custom one. 

**a. Check whether a LocalQueue already exists for your project namespace: **

**b. If a LocalQueue already exists and you need to modify it (for example, to point to a different ClusterQueue), edit it in place: **

**c. If a LocalQueue does not exist or you want a custom one, create a file called local_queue.yaml and populate it with the following content: **

Example local queue 

**d. Replace the name, namespace, and clusterQueue values accordingly. **

e. Perform one of the following actions: 

If you are modifying an existing local queue, save the changes. 

**If you are creating a new local queue, apply the configuration to create the LocalQueue **object: 

Verification 

$ oc apply -f cluster_queue.yaml 

$ oc get localqueues -n <project_namespace> 

$ oc edit localqueue <existing_localqueue_name> -n <project_namespace> 

apiVersion: kueue.x-k8s.io/v1beta1 kind: LocalQueue metadata:   name: <example_local_queue>   namespace: <project_namespace> spec:   clusterQueue: <cluster_queue_name> 

$ oc apply -f local_queue.yaml 

Check the status of the local queue in a project, as follows: 

Additional resources 

Red Hat build of Kueue documentation 

Kueue documentation 

9.2. EXAMPLE KUEUE RESOURCE CONFIGURATIONS FOR DISTRIBUTED WORKLOADS 

You can use these example configurations as a starting point for creating Kueue resources to manage your distributed training workloads. 

These examples show how to configure Kueue resource flavors and cluster queues for common distributed training scenarios. 

NOTE 

In OpenShift AI 3.5, Red Hat does not support shared cohorts. 

9.2.1. NVIDIA GPUs without shared cohort 

9.2.1.1. NVIDIA RTX A400 GPU resource flavor 

9.2.1.2. NVIDIA RTX A1000 GPU resource flavor 

$ oc get localqueues -n <project_namespace> 

apiVersion: kueue.x-k8s.io/v1beta1 kind: ResourceFlavor metadata:   name: "a400node" spec:   nodeLabels:     instance-type: nvidia-a400-node   tolerations:   - key: "HasGPU"     operator: "Exists"     effect: "NoSchedule" 

apiVersion: kueue.x-k8s.io/v1beta1 kind: ResourceFlavor metadata:   name: "a1000node" spec:   nodeLabels:     instance-type: nvidia-a1000-node   tolerations:   - key: "HasGPU"     operator: "Exists"     effect: "NoSchedule" 

9.2.1.3. NVIDIA RTX A400 GPU cluster queue 

9.2.1.4. NVIDIA RTX A1000 GPU cluster queue 

9.2.2. NVIDIA GPUs and AMD GPUs without shared cohort 

9.2.2.1. AMD GPU resource flavor 

apiVersion: kueue.x-k8s.io/v1beta1 kind: ClusterQueue metadata:   name: "a400queue" spec: *  namespaceSelector: {} # match all. *  resourceGroups:   - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]     flavors:     - name: "a400node"       resources:       - name: "cpu"         nominalQuota: 16       - name: "memory"         nominalQuota: 64Gi       - name: "nvidia.com/gpu"         nominalQuota: 2 

apiVersion: kueue.x-k8s.io/v1beta1 kind: ClusterQueue metadata:   name: "a1000queue" spec: *  namespaceSelector: {} # match all. *  resourceGroups:   - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]     flavors:     - name: "a1000node"       resources:       - name: "cpu"         nominalQuota: 16       - name: "memory"         nominalQuota: 64Gi       - name: "nvidia.com/gpu"         nominalQuota: 2 

apiVersion: kueue.x-k8s.io/v1beta1 kind: ResourceFlavor metadata:   name: "amd-node" spec:   nodeLabels:     instance-type: amd-node   tolerations: 

9.2.2.2. NVIDIA GPU resource flavor 

9.2.2.3. AMD GPU cluster queue 

9.2.2.4. NVIDIA GPU cluster queue 

  - key: "HasGPU"     operator: "Exists"     effect: "NoSchedule" 

apiVersion: kueue.x-k8s.io/v1beta1 kind: ResourceFlavor metadata:   name: "nvidia-node" spec:   nodeLabels:     instance-type: nvidia-node   tolerations:   - key: "HasGPU"     operator: "Exists"     effect: "NoSchedule" 

apiVersion: kueue.x-k8s.io/v1beta1 kind: ClusterQueue metadata:   name: "team-a-amd-queue" spec: *  namespaceSelector: {} # match all. *  resourceGroups:   - coveredResources: ["cpu", "memory", "amd.com/gpu"]     flavors:     - name: "amd-node"       resources:       - name: "cpu"         nominalQuota: 16       - name: "memory"         nominalQuota: 64Gi       - name: "amd.com/gpu"         nominalQuota: 2 

apiVersion: kueue.x-k8s.io/v1beta1 kind: ClusterQueue metadata:   name: "team-a-nvidia-queue" spec: *  namespaceSelector: {} # match all. *  resourceGroups:   - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]     flavors:     - name: "nvidia-node"       resources:       - name: "cpu"         nominalQuota: 16 

Additional resources 

Red Hat build of Kueue documentation 

Resource Flavor in the Kueue documentation 

Cluster Queue in the Kueue documentation 

9.3. CONFIGURE A CLUSTER FOR RDMA 

NVIDIA GPUDirect RDMA uses Remote Direct Memory Access (RDMA) to provide direct GPU interconnect. To configure a cluster for RDMA, a cluster administrator must install and configure several Operators. 

Prerequisites 

You can access an OpenShift cluster as a cluster administrator. 

Your cluster has multiple worker nodes with supported NVIDIA GPUs, and can access a compatible NVIDIA accelerated networking platform. 

You have installed Red Hat OpenShift AI with the required distributed training components as described in Installing the distributed workloads components (for disconnected environments, see Installing the distributed workloads components). 

You have configured the distributed training resources as described in Managing distributed workloads. 

Procedure 

1. Log in to the OpenShift Console as a cluster administrator. 

2. Enable NVIDIA GPU support in OpenShift AI. This process includes installing the Node Feature Discovery Operator and the NVIDIA GPU Operator. For more information, see Enabling NVIDIA GPUs. 

NOTE 

**After the NVIDIA GPU Operator is installed, ensure that rdma is set to enabled in your ClusterPolicy custom resource instance. **

3. To simplify the management of NVIDIA networking resources, install and configure the NVIDIA Network Operator, as follows: 

a. Install the NVIDIA Network Operator, as described in Adding Operators to a cluster  in the OpenShift documentation. 

b. Configure the NVIDIA Network Operator, as described in the deployment examples in the Network Operator Application Notes in the NVIDIA documentation. 

      - name: "memory"         nominalQuota: 64Gi       - name: "nvidia.com/gpu"         nominalQuota: 2 

4. [Optional] To use Single Root I/O Virtualization (SR-IOV) deployment modes, complete the following steps: 

a. Install the SR-IOV Network Operator, as described in the Installing the SR-IOV Network Operator section in the OpenShift documentation. 

b. Configure the SR-IOV Network Operator, as described in the Configuring the SR-IOV Network Operator section in the OpenShift documentation. 

5. Use the Machine Configuration Operator to increase the limit of pinned memory for non-root users in the container engine (CRI-O) configuration, as follows: 

**a. In the OpenShift Console, in the Administrator perspective, click Compute → **MachineConfigs. 

b. Click Create MachineConfig. 

c. Replace the placeholder text with the following content: 

Example machine configuration 

apiVersion: machineconfiguration.openshift.io/v1 kind: MachineConfig metadata:   labels:     machineconfiguration.openshift.io/role: worker   name: 02-worker-container-runtime spec:   config:     ignition:       version: 3.2.0     storage:       files:         - contents:             inline: |               [crio.runtime]               default_ulimits = [                 "memlock=-1:-1"               ]           mode: 420           overwrite: true           path: /etc/crio/crio.conf.d/10-custom 

**d. Edit the default_ulimits entry to specify an appropriate value for your configuration. For **more information about default limits, see the Set default ulimits on CRIO Using machine config Knowledgebase solution. 

e. Click Create. 

f. Restart the worker nodes to apply the machine configuration. 

This configuration enables non-root users to run the training job with RDMA in the most restrictive OpenShift default security context. 

Verification 

1. Verify that the Operators are installed correctly, as follows: 

**a. In the OpenShift Console, in the Administrator perspective, click Workloads → Pods. **

b. Select your project from the Project list. 

c. Verify that a pod is running for each of the newly installed Operators. 

2. Verify that RDMA is being used, as follows: 

**a. Edit the PyTorchJob resource to set the *NCCL_DEBUG* environment variable to INFO, **as shown in the following example: 

Setting the NCCL debug level to INFO 

        spec:           containers:           - command:             - /bin/bash             - -c             - "your container command"             env:             - name: NCCL_SOCKET_IFNAME               value: "net1"             - name: NCCL_IB_HCA               value: "mlx5_1"             - name: NCCL_DEBUG               value: "INFO" 

b. Run the PyTorch job. 

c. Check that the pod logs include an entry similar to the following text: 

Example pod log entry 

NCCL INFO NET/IB : Using [0]mlx5_1:1/RoCE [RO] 

Additional resources 

Machine configuration  in the OpenShift documentation 

Managing security context constraints in the OpenShift documentation 

9.4. TROUBLESHOOTING REFERENCE: DISTRIBUTED WORKLOADS FOR ADMINISTRATORS 

If your users are experiencing errors in Red Hat OpenShift AI relating to distributed workloads, read this section to understand what could be causing the problem, and how to resolve the problem. 

If the problem is not documented here or in the release notes, contact Red Hat Support. 

9.4.1. A user’s Ray cluster is in a suspended state 

Problem 

The resource quota specified in the cluster queue configuration might be insufficient, or the resource flavor might not yet be created. 

Diagnosis 

The user’s Ray cluster head pod or worker pods remain in a suspended state. Check the status of the **Workload resource that is created with the RayCluster resource. The status.conditions.message **field provides the reason for the suspended state, as shown in the following example: 

Resolution 

1. Check whether the resource flavor is created, as follows: 

a. In the OpenShift console, select the user’s project from the Project list. 

**b. Click Home → Search, and from the Resources list, select ResourceFlavor. **

c. If necessary, create the resource flavor. 

2. Check the cluster queue configuration in the user’s code, to ensure that the resources that they requested are within the limits defined for the project. 

3. If necessary, increase the resource quota. 

For information about configuring resource flavors and quotas, see Configuring quota management for distributed workloads. 

9.4.2. A user’s Ray cluster is in a failed state 

Problem 

The user might have insufficient resources. 

Diagnosis 

The user’s Ray cluster head pod or worker pods are not running. When a Ray cluster is created, it initially **enters a failed state. This failed state usually resolves after the reconciliation process completes and **the Ray cluster pods are running. 

Resolution 

If the failed state persists, complete the following steps: 

1. In the OpenShift console, select the user’s project from the Project list. 

**2. Click Workloads → Pods. **

3. Click the user’s pod name to open the pod details page. 

4. Click the Events tab, and review the pod events to identify the cause of the problem. 

status:  conditions:    - lastTransitionTime: '2024-05-29T13:05:09Z'      message: 'couldn''t assign flavors to pod set small-group-jobtest12: insufficient quota for nvidia.com/gpu in flavor default-flavor in ClusterQueue' 

**5. Check the status of the Workload resource that is created with the RayCluster resource. The status.conditions.message field provides the reason for the failed state. **

9.4.3. A user’s Ray cluster does not start 

Problem 

**After the user runs the cluster.apply() command, when they run either the cluster.details() command or the cluster.status() command, the Ray cluster status remains as Starting instead of changing to Ready. No pods are created. **

Diagnosis 

**Check the status of the Workload resource that is created with the RayCluster resource. The status.conditions.message field provides the reason for remaining in the Starting state. Similarly, check the status.conditions.message field for the RayCluster resource. **

Resolution 

1. In the OpenShift console, select the user’s project from the Project list. 

**2. Click Workloads → Pods. **

3. Verify that the KubeRay pod is running. If necessary, restart the KubeRay pod. 

4. Review the logs for the KubeRay pod to identify errors. 

9.4.4. A user cannot create a Ray cluster or submit jobs 

Problem 

**After the user runs the cluster.apply() command, an error similar to the following text is shown: **

Diagnosis 

**The correct OpenShift login credentials are not specified in the TokenAuthentication section of the **user’s notebook code. 

Resolution 

1. Advise the user to identify and specify the correct OpenShift login credentials as follows: 

a. In the OpenShift console header, click your username and click Copy login command. 

b. In the new tab that opens, log in as the user whose credentials you want to use. 

c. Click Display Token. 

RuntimeError: Failed to get RayCluster CustomResourceDefinition: (403) Reason: Forbidden HTTP response body: {"kind":"Status","apiVersion":"v1","metadata": {},"status":"Failure","message":"rayclusters.ray.io is forbidden: User \"system:serviceaccount:regularuser-project:regularuser-workbench\" cannot list resource \"rayclusters\" in API group \"ray.io\" in the namespace \"regularuser-project\"","reason":"Forbidden","details":{"group":"ray.io","kind":"rayclusters"},"code":403} 

**d. From the Log in with this token section, copy the token and server values. **

**e. Specify the copied token and server values in your notebook code as follows: **

**2. Verify that the user has the correct permissions and is part of the rhods-users group. **

9.4.5. Additional resources 

Troubleshooting common problems with distributed workloads for users 

Troubleshooting common problems with Kueue 

auth = TokenAuthentication( *    token = "<token>",     server = "<server>", *    skip_tls=False ) auth.login() 

### CHAPTER 10. CONFIGURE A CENTRAL AUTHENTICATION SERVICE FOR AN EXTERNAL OIDC PROVIDER

The built-in OpenShift OAuth server supports integration with various identity providers. However, it has limitations in direct OpenID Connect (OIDC) configurations on Red Hat OpenShift Service on AWS **(ROSA) and on-premises OpenShift (OCP) 4.20 and later clusters. The internal oauth service is disabled, which breaks applications that have dependencies on oauth-proxy sidecar containers. **

You can configure an external OIDC identity provider directly with Red Hat OpenShift AI by configuring a centralized authentication service. This service provides a secure, scalable, and manageable authentication solution because it centralizes the authentication logic and decouples it from individual backend services. 

10.1. CENTRALIZED AUTHENTICATION SERVICE FOR EXTERNAL OIDC PROVIDERS 

The centralized authentication service routes ingress traffic for all services behind a single domain, providing the following advanced capabilities: 

Centralized authentication: A single authentication service requiring only one client ID and secret from the external OIDC Identity Provider (IDP). 

Simplified backend services: Backend services assume all incoming traffic is authenticated and contains necessary user headers. 

Authorization handling: Services still handle authorization at the service or pod level using **sidecars like kube-rbac-proxy. **

Encrypted Communication: Traffic from the gateway to the backend services is fully encrypted with Transport Layer Security (TLS). 

10.1.1. Authentication methods for the centralized authentication service 

The centralized authentication service supports two primary authentication methods to accommodate different access requirements: 

User authentication via OIDC: Used for interactive browser-based access. When a user navigates to a protected service, the Gateway redirects the request to the configured external OIDC provider for login. 

Service account token authentication: Used for programmatic access, automated workflows, and CLI tools. The Gateway validates Kubernetes service account bearer tokens against the cluster’s API server. 

The centralized authentication service is based on Gateway API support available in OpenShift (OCP) 4.19.9 or later. 

For more information on supported OpenID Connect (OIDC) identity providers, see OpenShift documentation on Direct authentication identity providers 

10.2. CONFIGURE OIDC FOR THE CENTRALIZED AUTHENTICATION SERVICE 

As an OpenShift AI administrator, you can configure an OpenID Connect (OIDC) authentication for the centralized authentication service using parameters from your external OIDC identity provider. 

IMPORTANT 

To ensure proper functionality, you must configure the OpenShift cluster for direct authentication with an external OIDC identity provider before configuring the central authentication service. 

Prerequisites 

You have configured the OpenShift cluster for direct authentication with an external OIDC identity provider. 

To configure OpenShift for direct authentication, follow the appropriate OpenShift documentation: Enabling direct authentication with an external OIDC identity provider . 

To configure OpenShift for direct authentication using ROSA, follow the appropriate Red Hat OpenShift Service on AWS documentation: Creating an OpenID Connect configuration. 

NOTE 

You must configure OpenShift for direct authentication using the same OIDC provider that the Gateway uses. 

You have successfully installed and deployed OpenShift AI. 

You have deployed the DataScienceCluster (DSC) and DSCInitialization. For more information, see Installing and deploying OpenShift AI . 

**You have deployed the OpenShift AI Operator in the rhods-operator namespace. **

You have enabled Gateway API support on OCP 4.19.9 or later. 

You have the following external authentication provider details: 

Issuer URL 

Client ID 

Client Secret 

Realm name (for Keycloak) 

You have cluster administrator access which is required to create secrets and configure **GatewayConfig. **

For detailed step-by-step instructions, troubleshooting, and field definitions, refer to the OpenShift documentation on Configuring an external OIDC identity provider . 

Procedure 

**1. In the OpenShift CLI (oc), verify the OpenShift authentication type by running the following **command: 

**If the authentication is successful, you will see the following output: OIDC **

2. Verify that your OIDC provider is configured as expected by running the following command: 

**If the OIDC configuration is successful, you will see your provider name (e.g., keycloak). **

**3. Verify that the kube-apiserver has rolled out changes as expected. **

If success is indicated, the expected output should look like the following example: 

NAME              VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE kube-apiserver    4.14.9    True        False         False      1d 

NOTE 

The rollout can take 20 minutes or more. Wait until all nodes have the new revision before proceeding. You can proceed to Gateway configuration steps **when oc get authentication.config/cluster shows type: OIDC, oc get co kubeapiserver shows the authentication rollout is complete, and you can successfully **authenticate to OpenShift using OIDC credentials. 

4. Define the the following environment variables. You must replace the placeholder values with the actual details from your OIDC Identity Provider (IdP): 

**5. Create the client secret in the openshift-ingress namespace: **

**6. Update the GatewayConfig custom resource to enable OIDC authentication by patching it with **the secret reference and OIDC details: 

$ oc get authentication.config/cluster -o jsonpath='{.spec.type}' 

$ oc get authentication.config/cluster -o jsonpath='{.spec.oidcProviders[*].name}' 

$ oc get co kube-apiserver 

*# Replace with your actual values *IDP_DOMAIN="<keycloak.example.com>" IDP_REALM="<your-realm>" IDP_CLIENT_ID="<your-client-id>" IDP_CLIENT_SECRET="<your-client-secret>" IDP_ISSUER_URL=”<https://keycloak.example.com/realms/your-realm>” 

$ oc create secret generic idp-client-secret \     --from-literal=clientSecret=$IDP_CLIENT_SECRET \     -n openshift-ingress 

$ oc patch gatewayconfig default-gateway --type='merge' -p='{     "spec": {       "oidc": {         "issuerURL": "'$IDP_ISSUER_URL'",         "clientID": "'$IDP_CLIENT_ID'",         "clientSecretRef": {           "name": "idp-client-secret", 

**7. Verify that the client secret has been created and that the GatewayConfig shows the correct **OIDC configuration: 

**Expected output for secret and GatewayConfig should look like the following example: **

Verification 

1. After configuring and authenticating the Gateway for your identity provider, you need to ensure that you can access your OpenShift console. 

a. Access the gateway by accessing the Console link: 

b. Login with your OIDC credentials and verify the following: 

i. You are redirected to the OIDC provider login page. A successful authentication redirects back to the Gateway. 

ii. Your OpenShift AI components are accessible (for example: Dashboard, Notebooks). 

**2. Check the GatewayConfig status to verify that the OIDC configuration was successfully **provisioned: 

**The expected output is the full YAML configuration of the GatewayConfig resource, showing the OIDC configuration details under spec.oidc and confirming successful deployment by displaying both the Ready and ProvisioningSucceeded conditions with a status: "True" **value. 

**3. Verify the kube-auth-proxy deployment is running successfully in the openshift-ingress **namespace: 

The expected output looks like the following example: 

          "key": "clientSecret"         }       }     }   }' 

$ oc get secret keycloak-client-secret -n openshift-ingress $ oc get gatewayconfig default-gateway -o jsonpath='{.spec.oidc}' 

*# Expected output (for secret) *NAME                     TYPE     DATA   AGE keycloak-client-secret   Opaque   1      2m *# Expected output (for GatewayConfig) *{"clientID":"your-client-id","clientSecretRef":{"key":"clientSecret","name":"idp-client-secret"},"issuerURL":"https://keycloak.example.com/realms/your-realm"} 

$ oc get consolelink 

$ oc get gatewayconfig default-gateway -o yaml 

$ oc get deployment kube-auth-proxy -n openshift-ingress 

**4. Check the status and accessibility of the data-science-gateway: **

The expected output looks like the following example: 

5. Test the OIDC discovery endpoint by running the following command: 

**The expected output is a JSON object containing the OIDC configuration endpoints (issuer, authorization_endpoint, token_endpoint, etc.) that confirm the OIDC provider is publicly **discoverable. 

Next steps 

Once the external OIDC is configured and authenticated, the Cluster Administrator must perform the necessary authorization by mapping external Identity Provider (IdP) groups to specific OpenShift **ClusterRoles to grant access to projects and resources. **

**1. Create a ClusterRole that grants users read and list access to OpenShift projects in the **console: 

**2. Bind the odh-projects-read ClusterRole to your IdP group (for example, odh-users). **

3. Grant the ability to create and manage new projects by assigning the built-in self-provisioner ClusterRole to your group. 

Security considerations 

Secret management: Store OIDC client secrets securely and rotate them regularly. 

NAME              READY   UP-TO-DATE   AVAILABLE   AGE kube-auth-proxy   1/1     1            1           5m 

$ oc get gateway data-science-gateway -n openshift-ingress 

NAME                   CLASS                        ADDRESS                                                                        PROGRAMMED   AGE data-science-gateway   data-science-gateway-class   aa87f5da7f0c748d5aa63b4916604108-107643684.us-east-1.elb.amazonaws.com         True         5m 

curl -s https://keycloak.example.com/realms/your-realm/.well-known/openid-configuration 

apiVersion: rbac.authorization.k8s.io/v1 kind: ClusterRole metadata:   name: odh-projects-read rules: - apiGroups: ["project.openshift.io"]   resources: ["projects"]   verbs: ["get","list"] 

$ oc adm policy add-cluster-role-to-group odh-projects-read odh-users 

$ oc adm policy add-cluster-role-to-group self-provisioner odh-users 

Network policies: Consider implementing network policies to restrict access to the authentication proxy. 

TLS configuration: Ensure all OIDC communication uses Transport Layer Security (TLS). 

**Token validation: While kube-auth-proxy validates tokens, ensure your OIDC provider is **configured with appropriate token lifetimes. 

Audit logging: Enable audit logging for authentication events. 

10.3. CONFIGURE SERVICE TOKEN AUTH FOR THE GATEWAY API 

As an OpenShift AI administrator, you can configure service account token authentication for central authentication service to enable programmatic and CLI-based access using Kubernetes service account bearer tokens. 

IMPORTANT 

Service account token authentication is designed for programmatic access, automation, and CLI tools. For interactive user access through a web browser, use OpenID Connect (OIDC) authentication instead. 

Prerequisites 

You have cluster administrator access. 

You have installed OpenShift AI with Gateway API support enabled on OpenShift Container Platform 4.19.9 or later. 

Procedure 

**1. Create a ServiceAccount for your application or CLI tool: **

**Replace <your-namespace> with your application namespace. For example, redhat-ods-applications. **

**2. Grant the ServiceAccount appropriate RBAC permissions to access your services. The following example grants access to a specific service through the kube-rbac-proxy: **

$ oc create serviceaccount my-app-sa -n <your-namespace> 

apiVersion: rbac.authorization.k8s.io/v1 kind: Role metadata:   name: my-app-service-access rules: - apiGroups: [""]   resources: ["services/proxy"]   resourceNames: ["my-service"]   verbs: ["get", "create"] 

$ oc create -f role.yaml -n <your-namespace> $ oc create rolebinding my-app-service-access \     --role=my-app-service-access \ 

3. Generate a service account token for authentication. 

NOTE 

Set the token duration based on your security requirements. Kubernetes requires a minimum duration of 10 minutes. 

4. Get the Gateway URL. 

5. Access your service through the Gateway using the bearer token. 

Verification 

1. Test authentication with your service account token. 

A successful authentication returns HTTP 200. Requests with invalid or missing tokens return HTTP 403 or redirect to authentication. 

Security considerations 

**Token lifecycle management: Service account tokens should have limited lifetimes. Use the --duration flag to set appropriate expiration times based on your security requirements. **

RBAC principle of least privilege: Grant service accounts only the permissions they need to function. Avoid granting cluster-admin or overly broad permissions. 

Token storage: Never commit service account tokens to source control. Store tokens securely using secrets management solutions. 

Token rotation: Implement a token rotation strategy for long-running services. Regenerate tokens before expiration. 

10.4. CONFIGURE CUSTOM CA CERTIFICATES FOR OIDC 

**To establish a secure connection between kube-auth-proxy and an external OpenID Connect (OIDC) **provider, and to validate the identity of the authentication provider securely, you can configure the Gateway controller to trust your OAuth or OIDC provider by creating a Secret and referencing it in the **GatewayConfig resource. **

    --serviceaccount=<your-namespace>:my-app-sa \     -n <your-namespace> 

$ TOKEN=$(oc create token my-app-sa -n <your-namespace> --duration=1h) 

$ GATEWAY_URL=$(oc get route data-science-gateway -n openshift-ingress -o jsonpath='{.spec.host}') 

$ curl -k -H "Authorization: Bearer ${TOKEN}" \     "https://${GATEWAY_URL}/your-service-path" 

$ curl -k -i -H "Authorization: Bearer ${TOKEN}" \     "https://${GATEWAY_URL}/your-service-path" 

Prerequisities 

You have cluster administrator access. 

You have the CA certificate for your OAuth or OIDC provider. 

Procedure 

**1. Create a Secret containing the custom CA certificate in the openshift-ingress namespace. This **Secret must contain the CA certificate that signed the TLS certificate of your provider. 

NOTE 

**Replace <oidc_ca_bundle> with a unique name for your bundle and </path/to/your_ca.crt> with the local path to your certificate file. **

**2. Reference the Secret in the GatewayConfig resource by updating the spec.providerCASecretName field to the name of the Secret you created in the previous step. The Gateway controller mounts this Secret and configures the kube-auth-proxy to trust the **CA. 

Verification 

**After you save the GatewayConfig, the Operator reconciles the changes and updates the kube-auth-proxy deployment. **

**Check that the kube-auth-proxy pods in the openshift-ingress namespace have restarted and are Running. **

Log in to the dashboard to verify that authentication succeeds without TLS certificate errors. 

10.5. TROUBLESHOOTING REFERENCE: THE CENTRAL AUTHENTICATION SERVICE 

If you are experiencing errors in Red Hat OpenShift AI relating to central authentication service configuration, read this section to understand what could be causing the problem, and how to resolve the problem. 

If the problem is not documented here or in the release notes, contact Red Hat Support. 

$ oc create secret generic <oidc-ca-bundle> \   --from-file=ca.crt=</path/to/your-ca.crt> \   -n openshift-ingress 

apiVersion: opendatahub.io/v1alpha1 kind: GatewayConfig metadata:   name: gatewayconfig spec: *  # ... other spec fields (subdomain, ingressMode, etc.) ... *  providerCASecretName: oidc-ca-bundle *  # Optional, dev/test only - do not use in production:   # insecureSkipVerify: true *

10.5.1. Token duration error when creating a service account token 

Problem 

When attempting to generate a service account token for Gateway authentication, the command fails **with the following error: "may not specify a duration less than 10 minutes". **

Diagnosis 

**Kubernetes security policies enforce a minimum 10 minute expiration time for tokens. If the --duration **flag is set to a value lower than 10 minutes, the request is rejected by the API server. 

Resolution 

Update the command to specify a duration of at least 10 minutes. For example: 

10.5.2. HTTP 401 Unauthorized error during Gateway access 

Problem 

The Gateway fails to authenticate the provided bearer token. Requests to the Gateway URL return an **HTTP 401 Unauthorized error. **

Diagnosis 

This error indicates that the token is technically invalid. Common causes include: 

**The token may have expired (surpassing the specified --duration). **

**The kube-auth-proxy may not have the TokenReview permissions needed to communicate **with the Kubernetes API to validate the token. 

Resolution 

**1. Generate a new token using oc create token with a valid duration. **

**2. Ensure the token is passed correctly in the header as "Authorization: Bearer ${TOKEN}". **

**3. Check the kube-auth-proxy logs in the openshift-ingress namespace for connection errors to **the API server. 

**10.5.3. The GatewayConfig status shows as not ready **

Problem 

**While setting up the OIDC, the GatewayConfig status shows as not ready. You see error messages about missing OIDC configuration and the GatewayConfig resource shows its status as Ready: False. **

Diagnosis 

**1. Check GatewayConfig status by running the following command. **

$ oc create token my-app-sa -n <your-namespace> --duration=10m 

$ oc get gatewayconfig default-gateway -o yaml 

2. Check for specific error messages by running the following command. 

The expected output confirms that the GatewayConfig resource is successfully provisioned by **showing the OIDC configuration details under Spec.Oidc and displaying both the Ready and ProvisioningSucceeded status conditions with a True status. **

3. Verify that the OIDC configuration is correct by running the following command. 

Expected output shows the following example: 

Resolution 

1. Verify the OIDC secret exists and is correct by running the following command. 

2. Check OIDC issuer URL accessibility by running the following command. 

The expected output confirms the OIDC issuer URL is accessible by returning the HTTP status **code HTTP/2 200 and the correct content-type: application/json header. **

3. Ensure that the client Secret is correct. 

10.5.4. Authentication proxy fails to start 

Problem 

**The authentication proxy component fails to start after deploying kube-auth-proxy. The associated Pods are in a failing state, showing statuses such as CrashLoopBackOff or Pending, and the kube-auth-proxy Deployment is not ready. **

Diagnosis 

**1. Check the kube-auth-proxy deployment status by running the following command. **

**The expected output confirms that the deployment is successfully provisioned, showing 1/1 under the READY column. **

2. Check the Pod logs by running the following command. 

$ oc describe gatewayconfig default-gateway 

$ oc get gatewayconfig default-gateway -o jsonpath='{.spec.oidc}' 

{"clientID":"your-client-id","clientSecretRef":{"key":"clientSecret","name":"keycloak-client-secret"},"issuerURL":"https://keycloak.example.com/realms/your-realm"} 

$ oc get secret keycloak-client-secret -n openshift-ingress 

curl -I https://your-keycloak-domain/realms/your-realm/.well-known/openid-configuration 

$ oc get deployment kube-auth-proxy -n openshift-ingress 

$ oc logs -l app=kube-auth-proxy -n openshift-ingress 

The expected output confirms that the OAuth2 Proxy is configured and starting on the specified ports. 

3. Check the Pod events for errors by running the following command. 

The expected output should look like the following example. 

Resolution 

1. Verify that the authentication secret contains the correct client secret by running the following command. 

**The expected output should contain the keys OAUTH2_PROXY_CLIENT_SECRET, OAUTH2_PROXY_COOKIE_SECRET, and OAUTH2_PROXY_CLIENT_ID. **

2. Check if the OIDC issuer URL is accessible from the cluster by running the following command. 

**The expected output should return the HTTP status code HTTP/2 200. **

3. Ensure that the client ID exists in your OIDC provider. 

10.5.5. The Gateway is inaccessible 

Problem 

After configuring OIDC, you cannot access the Gateway URL: https://data-science-gateway.$CLUSTER_DOMAIN. Attempts to access the URL return 502 (Bad Gateway) or 503 (Service Unavailable) errors, indicating a networking failure that prevents external access or traffic routing to the 

*# Expected output *time="2024-01-15T10:30:00Z" level=info msg="OAuth2 Proxy configured" time="2024-01-15T10:30:00Z" level=info msg="OAuth2 Proxy starting on :4180" time="2024-01-15T10:30:00Z" level=info msg="OAuth2 Proxy starting on :8443" 

$ oc describe pod -l app=kube-auth-proxy -n openshift-ingress 

*# Expected output *Name:          kube-auth-proxy-7d4f8b9c6-xyz12 Namespace:     openshift-ingress Status:        Running Containers:   kube-auth-proxy:     State:          Running     Ready:          True     Restart Count:  0 Events:   Type    Reason       Age   From                 Message   ----    ------       ----  ----                 -------  Normal  Scheduled    5m    default-scheduler    Successfully assigned openshift-ingress/kube-auth-proxy-7d4f8b9c6-xyz12 to worker-node-1 

$ oc get secret kube-auth-proxy-creds -n openshift-ingress -o yaml 

curl -I https://your-keycloak-domain/realms/your-realm/.well-known/openid-configuration 

service endpoint. 

Diagnosis 

**1. Check the Gateway status of data-science-gateway by running the following command. **

**The expected output shows PROGRAMMED column as True, and a valid address is listed under the ADDRESS column. **

**2. Check the HTTPRoute status by running the following command. **

**The expected output shows that the oauth-callback-route is present. **

**3. Check the EnvoyFilter by running the following command. **

**The expected output shows that the authn-filter is present. **

**4. Check the kube-auth-proxy Service by running the following command. **

The expected output shows that the Service and correct ports are present, like the following example: 

Resolution 

1. Verify the Gateway has a valid address by running the following command. 

The expected output shows a valid IP address or hostname. 

**2. Check if the HTTPRoute is properly configured by running the following command. **

The expected output confirms proper parent references and backend services. 

**3. Ensure the EnvoyFilter is applied correctly by running the following command. **

$ oc get gateway data-science-gateway -n openshift-ingress 

$ oc get httproute -n openshift-ingress 

$ oc get envoyfilter -n openshift-ingress 

$ oc get service kube-auth-proxy -n openshift-ingress 

*# Expected output *NAME              TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)           AGE kube-auth-proxy   ClusterIP   172.30.31.69   <none>        8443/TCP,9000/TCP   41h 

$ oc get gateway data-science-gateway -n openshift-ingress -o jsonpath='{.status.addresses}' 

$ oc describe httproute oauth-callback-route -n openshift-ingress 

$ oc describe envoyfilter authn-filter -n openshift-ingress 

**The expected outputconfirms the proper configuration for kube-auth-proxy. **

10.5.6. The OIDC authentication fails 

Problem 

The OIDC authentication fails and you are unable to log in through the Gateway. You also experience symptoms such as redirect loops or explicit authentication errors after attempting to log in. 

Diagnosis 

**1. Check the kube-auth-proxy logs for specific error messages by running the following **command. 

The expected output confirms that the OAuth2 Proxy is configured and starting on the specified ports. 

**2. Verify the OIDC configuration in the kube-auth-proxy Secret by running the following **command. 

**The expected output shows that the Secret contains the keys OAUTH2_PROXY_CLIENT_ID, OAUTH2_PROXY_CLIENT_SECRET, and OAUTH2_PROXY_COOKIE_SECRET. The output **should look like the following example. 

3. Test the OIDC discovery endpoint by running the following command. 

The expected output returns the complete JSON configuration, including valid endpoints for **issuer, authorization_endpoint, and token_endpoint. **

Resolution 

1. Log in to the OIDC provider (for example, Keycloak) and verify that the redirect URI registered **for the client matches the expected endpoint on the Gateway: https://data-science-gateway.$CLUSTER_DOMAIN/oauth2/callback. Mismatches are a frequent cause of redirect **loops. 

$ oc logs -l app=kube-auth-proxy -n openshift-ingress 

$ oc get secret kube-auth-proxy-creds -n openshift-ingress -o yaml 

*# Expected output *apiVersion: v1 kind: Secret metadata:   name: kube-auth-proxy-creds   namespace: openshift-ingress type: Opaque data: *  OAUTH2_PROXY_CLIENT_ID: b2RoLWNsaWVudA==  # base64 encoded "data-science" *  OAUTH2_PROXY_CLIENT_SECRET: <base64-encoded-secret>   OAUTH2_PROXY_COOKIE_SECRET: <base64-encoded-cookie-secret> 

curl -s https://your-keycloak-domain/realms/your-realm/.well-known/openid-configuration | jq . 

2. Check if the client secret is properly set by running the following command. 

The expected output matches the secret in your OIDC provider. 

3. Ensure that the issuer URL is accessible and correct by running the following command. 

**The expected output returns HTTP/2 200. **

10.5.7. The dashboard is not accessible after authentication 

Problem 

After successfully authenticating with OIDC, you experience an authorization failure that prevents access to the dashboard. The failure results in 403 Forbidden errors while accessing the dashboard. 

**1. Check the odh-dashboard Deployment status by running the following command. **

The expected outcome confirms that the Pods are running, similar to the following example. 

2. Check the dashboard logs for any authorization errors by running the following command. 

In the expected output, the logs confirm the Dashboard is running and ready to serve requests. 

3. Verify the user permissions by running the following command. 

The expected output confirms that the user has the required access. 

Resolution 

1. Ensure that you have cluster-level RBAC permissions by running the following command. 

The expected output confirms that the view cluster role has been added to the user. 

**2. Verify that the odh-dashboard HTTPRoute is properly configured with correct parent **references (linking it to the Gateway) by running the following command. 

echo $KEYCLOAK_CLIENT_SECRET | base64 -d 

curl -I https://keycloak.example.com/realms/your-realm/.well-known/openid-configuration 

$ oc get deployment -n redhat-ods-applications rhods-dashboard 

NAME            READY   UP-TO-DATE   AVAILABLE   AGE rhods-dashboard   2/2     2            2          7h42m 

$ oc logs -l app=rhods-dashboard -n redhat-ods-applications 

$ oc auth can-i get projects --as=your-username 

$ oc adm policy add-cluster-role-to-user view your-username 

$ oc get httproute rhods-dashboard -n redhat-ods-applications -o yaml 

The expected output shows proper parent references to the Gateway. 

3. Check if the user is in the expected groups that may have roles bound to them required by the dashboard. 

**The expected output confirms that the user is in the odh-users group. **

$ oc get user your-username -o yaml 

### CHAPTER 11. BACK UP DATA

Backing up OpenShift AI involves various components, including the OpenShift cluster and storage data. 

11.1. BACKING UP STORAGE DATA 

It is a best practice to back up the data on your persistent volume claims (PVCs) regularly. 

Backing up your data is particularly important before you delete a user and before you uninstall OpenShift AI, as all PVCs are deleted when OpenShift AI is uninstalled. 

For more information about backing up PVCs for your cluster platform, see OADP Application backup and restore in the OpenShift Container Platform documentation. 

Additional resources 

Understanding persistent storage 

11.2. CLUSTER BACKUP 

If you plan to upgrade or uninstall OpenShift AI on your cluster, back up your cluster data so that you can restore it later if needed. 

For more information, see Backup and restore in the OpenShift Container Platform documentation. 

### CHAPTER 12. MANAGE OBSERVABILITY

Red Hat OpenShift AI provides centralized platform observability: an integrated solution for monitoring the health and performance of your OpenShift AI instance and user workloads. 

This centralized solution includes a dedicated, pre-configured observability stack, featuring the OpenTelemetry Collector (OTC) for standardized data ingestion, Prometheus for metrics, and the Red Hat build of Tempo for distributed tracing. This architecture enables a common set of health metrics and alerts for OpenShift AI components and offers mechanisms to integrate with your existing external observability tools. 

12.1. ENABLE THE OBSERVABILITY STACK 

The observability stack collects and correlates metrics, traces, and alerts for OpenShift AI so that you can monitor, troubleshoot, and optimize OpenShift AI components. A cluster administrator must **explicitly enable this capability in the DataScienceClusterInitialization (DSCI) custom resource. **

Once enabled, you can perform the following actions: 

Accelerate troubleshooting by viewing metrics, traces, and alerts for OpenShift AI components in one place. 

Maintain platform stability by monitoring health and resource usage and receiving alerts for critical issues. 

Integrate with existing tools by exporting telemetry to third-party observability solutions through the Red Hat build of OpenTelemetry. 

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

You have installed Red Hat OpenShift AI. 

You have installed the following Operators, which provide the components of the observability stack: 

Cluster Observability Operator: Deploys and manages Prometheus and Alertmanager for metrics and alerts. 

Tempo Operator: Provides the Tempo backend for distributed tracing. 

Red Hat build of OpenTelemetry: Deploys the OpenTelemetry Collector for collecting and exporting telemetry data. 

Procedure 

1. Log in to the OpenShift web console as a cluster administrator. 

2. Go to the Installed Operators page. The navigation path depends on your OpenShift version: 

On OpenShift 4.20 and later, click Ecosystem → Installed Operators. 

On OpenShift 4.19, click Operators → Installed Operators. 

3. Search for the Red Hat OpenShift AI Operator, and then click the Operator name to open the Operator details page. 

4. Click the DSCInitialization tab. 

5. Click the default instance name (for example, default-dsci) to open the instance details page. 

6. Click the YAML tab to show the instance specifications. 

**7. In the spec.monitoring section, set the value of the managementState field to Managed, and **configure metrics, alerting, and tracing settings as shown in the following example: 

Example monitoring configuration 

8. Click Save to apply your changes. 

Verification 

Verify that the observability stack components are running in the configured namespace: 

1. In the OpenShift web console, click Workloads → Pods. 

2. From the project list, select redhat-ods-monitoring. 

3. Confirm that there are running pods for your configuration. The following pods indicate that the observability stack is active: 

*# ... *spec:   monitoring: *    managementState: Managed                 # Required: Enables and manages the observability stack     namespace: redhat-ods-monitoring    # Required: Namespace where monitoring components are deployed     alerting: {}                              # Alertmanager configuration, uses default settings if empty     metrics:                                  # Prometheus configuration for metrics collection       replicas: 1                             # Optional: Number of Prometheus instances       resources:                              # CPU and memory requests and limits for Prometheus pods         cpulimit: 500m                        # Optional: Maximum CPU allocation in millicores         cpurequest: 100m                      # Optional: Minimum CPU allocation in millicores         memorylimit: 512Mi                    # Optional: Maximum memory allocation in mebibytes         memoryrequest: 256Mi                  # Optional: Minimum memory allocation in mebibytes       storage:                                # Storage configuration for metrics data         size: 5Gi                             # Required: Storage size for Prometheus data         retention: 90d                        # Required: Retention period for metrics data in days       exporters: {}                           # External metrics exporters     traces:                                   # Tempo backend for distributed tracing       sampleRatio: '0.1'                      # Optional: Portion of traces to sample, expressed as a decimal       storage:                                # Storage configuration for trace data         backend: pv                           # Required: Storage backend for Tempo traces (pv, s3, or gcs)         retention: 2160h                      # Optional: Retention period for trace data in hours       exporters: {}                           # External traces exporters # ... *

Next step 

*Collecting metrics from user workloads *

12.2. OBSERVE PLATFORM AND MODEL METRICS 

Use the built-in observability dashboards in OpenShift AI to monitor cluster infrastructure health and model deployment performance. Dashboard metrics are scoped to the namespaces each user has access to. 

12.2.1. Observability dashboards overview 

Red Hat OpenShift AI provides built-in observability dashboards that display curated metrics for monitoring cluster infrastructure health and model deployment performance. The dashboards are available in the OpenShift AI console at Observe & monitor → Dashboard. 

The observability dashboards provide an opinionated view of the metrics that cluster administrators and non-admin users should monitor. The dashboards do not display all available Prometheus metrics. For metrics that are not included in the built-in dashboards, you can query Prometheus directly or export metrics to external observability tools. 

12.2.1.1. Available dashboards 

OpenShift AI includes the following built-in dashboards: 

Cluster 

Displays cluster-wide infrastructure health, resource utilization, and capacity metrics. This dashboard is available only to cluster administrators. 

Models 

Displays model deployment performance metrics for the namespaces that the user has access to. Users can filter by project and model deployment. 

Usage 

Displays Models-as-a-Service token consumption, request counts, and rate-limit violations across *subscriptions and users. See the Additional resources section for more information about Models-as-a-Service observability. *

LLM Traffic 

Displays cluster-level request health indicators for Distributed Inference with llm-d deployments, including request rate, error rate, and token consumption. See the Additional resources section for *more information about Distributed Inference with llm-d observability *. 

LLM Performance 

Displays latency and cache diagnostics for Distributed Inference with llm-d deployments, including time to first token percentiles, inter-token latency, and KV cache hit rate. See the Additional *resources section for more information about Distributed Inference with llm-d observability *. 

LLM Utilization 

alertmanager-data-science-monitoringstack-#      2/2   Running   0   1m data-science-collector-collector-#               1/1   Running   0   1m prometheus-data-science-monitoringstack-#        2/2   Running   0   1m tempo-data-science-tempomonolithic-#             1/1   Running   0   1m thanos-querier-data-science-thanos-querier-#     2/2   Running   0   1m 

Displays per-replica resource consumption for Distributed Inference with llm-d deployments, including GPU utilization, memory utilization, and request queue depth. See the Additional resources *section for more information about Distributed Inference with llm-d observability *. 

12.2.1.2. Dashboard access 

Dashboard access is automatic and based on user permissions: 

Cluster administrators can view the Cluster tab and the Models tab with metrics across all projects. 

Non-admin users can view the Models tab with metrics scoped to the namespaces they have access to. The Cluster tab is not available to non-admin users. 

No additional role-based access control (RBAC) configuration is required. The dashboards use the user’s authentication token to determine which namespaces and metrics are visible. 

12.2.1.3. Dashboard controls 

All dashboards provide the following global controls: 

Time range selector 

Select a time period to display metrics for a specific duration. 

Auto-refresh 

Enable automatic refresh to keep dashboard metrics current. 

Project filter 

Filter metrics by project. Cluster administrators can select from all projects. Non-admin users see only their accessible projects. 

Additional resources 

View the Models-as-a-Service observability dashboard 

Built-in observability dashboards for llm-d deployments 

12.2.2. Enable the observability dashboards 

Enable the observability dashboards to monitor cluster health and model deployment performance from the OpenShift AI console. After the monitoring metrics stack is enabled, the dashboards are available automatically. 

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

You have installed Red Hat OpenShift AI. 

You have installed the Cluster Observability Operator. 

**You have enabled the observability stack in the DataScienceClusterInitialization (DSCI) custom resource with at least the metrics section configured. The alerting and traces sections **are not required for the observability dashboards. For more information, see Enabling the observability stack. 

Procedure 

1. Log in to the OpenShift AI dashboard as a user with cluster administrator privileges. 

2. In the left navigation menu, click Observe & monitor → Dashboard. The observability dashboard page displays the Cluster and Models tabs. 

Verification 

The Cluster tab displays overview metrics, cluster resource utilization charts, and project resource usage charts. 

The Models tab displays the model deployments table and performance metrics charts. 

Additional resources 

Cluster dashboard metrics 

Models dashboard metrics 

12.2.3. Cluster dashboard metrics 

The Cluster dashboard provides cluster administrators with an overview of infrastructure health, resource utilization, and project-level resource consumption. This dashboard is available only to cluster administrators and requires the observability stack to be enabled. 

12.2.3.1. Overview metrics 

The overview section displays summary statistics for cluster health. 

Table 12.1. Overview metrics 

Metric Description 

System health The percentage and count of healthy nodes in the cluster. A node is considered **healthy when its Ready condition is true. A declining value indicates nodes under pressure or in a NotReady state. **

Deployed models The total number of active model deployments across the cluster. This count is derived from unique model deployments that are currently running and processing requests. 

GPU utilization The average GPU utilization percentage across all GPUs in the cluster. High utilization can indicate compute bottlenecks that affect model serving performance. 

Request success rate The percentage of successfully completed model serving requests during the selected time period. A declining success rate separates slow responses from actual failures and warrants investigation. 

12.2.3.2. Cluster resource overview 

The cluster resource overview section displays time-series charts for resource usage trends over the selected time period. 

Table 12.2. Cluster resource overview metrics 

Metric Description 

GPU utilization Average GPU utilization across all GPUs in the cluster, displayed as a percentage over time. Use this chart to identify GPU capacity trends and plan for scaling. 

Memory allocated Total container working-set memory usage as a proportion of total node memory, displayed over time. Rising memory allocation can indicate growing workload demands or potential memory pressure. 

CPU utilization Total container CPU usage as a proportion of total allocatable CPU across all nodes, displayed over time. Use this chart to assess overall compute capacity and identify utilization trends. 

Inbound traffic Total inbound network traffic rate across all containers, displayed in bytes over time. Use this chart to monitor network load patterns associated with model serving traffic. 

12.2.3.3. Project resource usage 

The project resource usage section displays stacked time-series charts that compare resource usage across projects. 

Table 12.3. Project resource usage metrics 

Metric Description 

GPU utilization GPU utilization broken down by project, displayed as a stacked chart to show each project’s contribution to total GPU usage. 

CPU utilization CPU utilization broken down by project, displayed as a stacked chart to show each project’s contribution to total CPU usage. 

Memory allocated Memory usage broken down by project, displayed as a stacked chart to show each project’s contribution to total memory usage. 

12.2.3.4. Cluster details 

The cluster details section displays cluster configuration metadata. 

Table 12.4. Cluster details 

Field Description 

Provider The infrastructure provider for the cluster. 

OpenShift version The version of OpenShift running on the cluster. 

Channel The update channel configured for the cluster. 

API server The API server URL for the cluster. 

Field Description 

12.2.4. Models dashboard metrics 

The Models dashboard displays model deployment performance metrics, including a deployments inventory table and time-series performance charts. All users can view this dashboard, with metrics scoped to the namespaces they have access to. The observability stack must be enabled by a cluster administrator to view this dashboard. 

12.2.4.1. Model deployments table 

The model deployments table displays an inventory of model deployments with real-time performance and resource information. You can sort the table by clicking column headers and use pagination to browse results. 

Table 12.5. Model deployments table columns 

Column Description 

Model deployment The name of the model deployment. 

Project The namespace where the model is deployed. 

Total requests The total count of successfully completed inference requests during the selected time period. 

P90 E2E request latency 

The 90th percentile end-to-end latency of a request, from when it is received to when it completes. A rising value indicates slower response times for users. 

Error rate The percentage of requests that failed due to errors or aborts during the selected time period. Use this metric to distinguish between slow responses and actual failures. 

GPU utilization The GPU utilization percentage attributed to the model deployment. High utilization can indicate a bottleneck that affects latency and throughput. 

CPU usage (cores) The CPU consumption of the model deployment in cores. 

CPU quota utilization The CPU usage of the model deployment as a percentage of the namespace CPU quota. 

12.2.4.2. Performance metrics 

The performance metrics section displays time-series charts for monitoring model serving health, latency, throughput, and scaling signals. 

Table 12.6. Performance metrics 

Metric Description 

Request queue length The current number of requests waiting in the queue for processing. This is the earliest saturation indicator; an increasing queue length typically precedes latency degradation. 

Replica count The number of running replicas serving each model deployment. Changes in replica count indicate autoscaling reactions to load changes. 

P90 E2E request latency 

The 90th percentile end-to-end latency of a request, from when it is received to when it completes. This is the primary user-visible experience metric. 

P90 Time to first token (TTFT) 

The 90th percentile latency from request start until the first output token is generated. This LLM-specific responsiveness metric often degrades before overall latency increases, making it an early warning signal for performance issues. 

Token throughput (tokens/sec) 

The combined rate of prompt tokens processed and generation tokens produced per second. Prompt tokens represent input tokens processed by the model; generation tokens represent output tokens produced. Use this metric to measure model and runtime processing speed. 

Request success rate (requests/sec) 

The rate of successfully completed requests per second. Successful requests are **those that completed with a length or stop finish reason. **

12.2.4.3. Response time distribution 

The response time distribution section displays a bar chart that categorizes requests by response time, providing a quick view of overall request performance. 

Table 12.7. Response time categories 

Category Description 

Fast <1s Requests that completed in less than 1 second. 

Acceptable 1-5s Requests that completed between 1 and 5 seconds. 

Slow 5-30s Requests that completed between 5 and 30 seconds. 

Degraded >30s Requests that took longer than 30 seconds to complete. 

12.2.4.4. Filters 

In addition to the global time range and auto-refresh controls, the Models dashboard provides the following filters: 

Model deployment 

Filter performance metrics by one or more model deployments. You can select multiple deployments to compare metrics side by side. 

Project 

Filter metrics by project. 

Cluster administrators can select from all projects or filter by a specific project. 

Non-admin users see only the namespaces they have access to. The project filter is automatically scoped to accessible namespaces. 

12.2.5. View model performance metrics 

You can use the Models dashboard in OpenShift AI to monitor performance metrics for your deployed models, including latency, throughput, resource utilization, and request success rates. The dashboard displays metrics only for models deployed in namespaces that you have access to. 

Prerequisites 

You have access to at least one namespace with deployed models in OpenShift AI. 

A cluster administrator has enabled the monitoring metrics stack for OpenShift AI. 

Procedure 

1. In the OpenShift AI dashboard, click Observe & monitor → Dashboard in the left navigation menu. 

2. Click the Models tab. 

3. Optional: To filter by specific model deployments, select one or more models from the Model deployment dropdown. 

4. Optional: To change the time range, select a value from the time range selector. 

5. Review the Model deployments table for an overview of all model deployments, including total requests, latency, error rate, and resource utilization. 

6. Review the Performance metrics section for time-series charts showing request queue length, replica count, latency, time to first token, token throughput, and request success rate. 

7. Review the Response time distribution chart for a breakdown of requests by response time categories. 

Verification 

The Model deployments table lists model deployments from your accessible namespaces. 

The Performance metrics charts display data for the selected model deployments and time range. 

Additional resources 

Models dashboard metrics 

12.2.6. Metrics beyond the built-in dashboards 

The built-in observability dashboards in OpenShift AI display a curated subset of the available Prometheus metrics. If you need metrics that are not included in the built-in dashboards, you can access Prometheus directly or export metrics to external observability tools. 

12.2.6.1. Query Prometheus directly 

You can query the full set of available Prometheus metrics through the OpenShift web console. To access Prometheus metrics, navigate to Observe → Metrics in the OpenShift web console and enter PromQL queries to retrieve specific metrics. 

The following Prometheus metric prefixes are relevant to OpenShift AI model serving: 

**kserve_vllm:* **

Metrics from vLLM model serving runtimes, including request counts, latency histograms, token counts, and queue depth. 

**accelerator_gpu_utilization **

GPU utilization metrics from the DCGM Exporter. 

**container_* **

Container-level resource metrics, including CPU and memory usage. 

**kube_* **

Kubernetes resource metrics, including node status, resource quotas, and pod health. 

12.2.6.2. Export metrics to external tools 

You can export OpenShift AI metrics to external observability platforms such as Grafana or any OpenTelemetry-compatible backend. With external tools, you can create custom dashboards that combine OpenShift AI metrics with data from other systems. 

Additional resources 

Exporting metrics to external observability tools 

12.3. COLLECT METRICS FROM USER WORKLOADS 

After a cluster administrator enables the observability stack in your cluster, metric collection becomes available but is not automatically active for all deployed workloads. The monitoring system relies on a specific label to identify which pods Prometheus should scrape for metrics. 

To include a workload, such as a user-created workbench, training job, or inference service, in the **centralized observability stack, add the label monitoring.opendatahub.io/scrape=true to the pod **template in the workload’s deployment configuration. This ensures that all pods created by the deployment include the label and are automatically scraped by Prometheus. 

NOTE 

**Apply the monitoring.opendatahub.io/scrape=true label only to workloads that expose **metrics and that you want the observability stack to monitor. Do not add this label to operator-managed workloads, because the operator might overwrite or remove it during reconciliation. 

Prerequisites 

*A cluster administrator has enabled the observability stack as described in Enabling the observability stack. *

You have OpenShift AI administrator privileges or you are the project owner. 

**You have deployed a workload that exposes a /metrics endpoint, such as a workbench server or **model service pod. 

You have access to the project where the workload is running. 

Procedure 

1. Log in to the OpenShift web console as a cluster administrator or project owner. 

2. Click Workloads → Deployments. 

3. In the Project list at the top of the page, select the project where your workload is deployed. 

4. Identify the deployment that you want to collect metrics from and click its name. 

5. On the Deployment details page, click the YAML tab. 

**6. In the YAML editor, add the required label under the spec.template.metadata.labels section, **as shown in the following example: 

7. Click Save. OpenShift automatically rolls out a new ReplicaSet and pods with the updated label. When the new pods start, the observability stack begins scraping their metrics. 

Verification 

Verify that metrics are being collected by accessing the Prometheus instance deployed by OpenShift AI. 

1. Access Prometheus by using a route: 

a. In the OpenShift web console, click Networking → Routes. 

b. From the project list, select redhat-ods-monitoring. 

**c. Locate the route associated with the Prometheus service, such as data-science-prometheus-route. **

d. Click the Location URL to open the Prometheus web console. 

apiVersion: apps/v1 kind: Deployment metadata:   name: <example_name>   namespace: <example_namespace> spec:   template:     metadata:       labels:         monitoring.opendatahub.io/scrape: 'true' *# ... *

2. Alternatively, access Prometheus locally by using port forwarding: 

a. List the Prometheus pods: 

b. Start port forwarding: 

c. In a web browser, open the following URL: 

3. In the Prometheus web console, search for a metric exposed by your workload. If the label is applied correctly and the workload exposes metrics, the metrics appear in the Prometheus instance deployed by OpenShift AI. 

12.4. EXPORT METRICS TO EXTERNAL OBSERVABILITY TOOLS 

You can export OpenShift AI operational metrics to an external observability platform, such as Grafana, Prometheus, or any OpenTelemetry-compatible backend. This allows you to visualize and monitor OpenShift AI metrics alongside data from other systems in your existing observability environment. 

**Metrics export is configured in the DataScienceClusterInitialization (DSCI) custom resource by populating the .spec.monitoring.metrics.exporters field. When you define one or more exporters in **this field, the OpenTelemetry Collector (OTC) deployed by OpenShift AI automatically updates its configuration to include each exporter in its metrics pipeline. If this field is empty or undefined, metrics are collected only by the in-cluster Prometheus instance that is deployed with OpenShift AI. 

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

*The observability stack is enabled as described in Enabling the observability stack *. 

The external observability platform can receive metrics through a supported export protocol. 

You know the URL of your external metrics receiver endpoint. 

Procedure 

1. Log in to the OpenShift web console as a cluster administrator. 

2. Go to the Installed Operators page. The navigation path depends on your OpenShift version: 

On OpenShift 4.20 and later, click Ecosystem → Installed Operators. 

On OpenShift 4.19, click Operators → Installed Operators. 

3. Select the Red Hat OpenShift AI Operator from the list. 

4. Click the DSCInitialization tab. 

5. Click the default DSCI instance, for example, default-dsci, to open its details page. 

$ oc get pods -n redhat-ods-monitoring -l prometheus=data-science-monitoringstack 

$ oc port-forward __<prometheus-pod-name>__ 9090:9090 -n redhat-ods-monitoring 

http://localhost:9090 

6. Click the YAML tab. 

**7. In the spec.monitoring.metrics section, add an exporters list that defines the external **receiver configuration, as shown in the following example: 

**name: A unique, descriptive name for the exporter configuration. Do not use reserved names such as prometheus or otlp/tempo. **

**type: The protocol used for export, for example: **

**otlp: For OpenTelemetry-compatible backends using gRPC or HTTP. **

**prometheusremotewrite: For Prometheus-compatible systems that use the remote **write protocol. 

**endpoint: The full URL of your external metrics receiver. For OTLP, endpoints typically use port 4317 (gRPC) or 4318 (HTTP). For Prometheus remote write, endpoints typically end with /api/v1/write. For example: **

**otlp: https://example-otlp-receiver.example.com:4317 (gRPC) or https://example-otlp-receiver.example.com:4318 (HTTP) **

**prometheusremotewrite: https://example-prometheus-remote.example.com/api/v1/write **

8. Click Save. The OpenTelemetry Collector automatically reloads its configuration and begins forwarding metrics to the specified external endpoint. 

Verification 

1. Verify that the OpenTelemetry Collector pods restart and apply the new configuration: 

**The data-science-collector-collector-* pods should restart and display a Running status. **

2. In your external observability platform, verify that new metrics from OpenShift AI appear in the metrics list or dashboard. 

NOTE 

**If you remove the .spec.monitoring.metrics.exporters configuration from the DSCI, the **OpenTelemetry Collector automatically reverts to collecting metrics only for the incluster Prometheus instance. 

spec:   monitoring:     metrics:       exporters:         - name: <external_exporter_name>           type: <type>           endpoint: https://example-otlp-receiver.example.com:4317 

$ oc get pods -n redhat-ods-monitoring 

12.5. VIEW TRACES IN EXTERNAL TRACING PLATFORMS 

**When tracing is enabled in the DataScienceClusterInitialization (DSCI) custom resource, OpenShift AI **deploys the Red Hat build of Tempo as the tracing backend and the Red Hat build of OpenTelemetry Collector (OTC) to receive and route trace data. 

To view and analyze traces outside of OpenShift AI, complete the following tasks: 

Configure your instrumented applications to send traces to the OpenTelemetry Collector. 

Connect your preferred visualization tool, such as Grafana or Jaeger, to the Tempo Query API. 

Prerequisites 

A cluster administrator has enabled tracing as part of the observability stack in the DSCI configuration. 

**You have access to the monitoring namespace, for example redhat-ods-monitoring. **

You have network access or cluster administrator privileges to create a route or port forward from the cluster. 

Your application is instrumented with an OpenTelemetry SDK or library to generate and export trace data. 

Procedure 

1. Find the OpenTelemetry Collector endpoint. The OpenTelemetry Collector receives trace data from instrumented applications by using the OpenTelemetry Protocol (OTLP). 

a. In the OpenShift web console, navigate to Networking → Services. 

**b. In the Project list, select the monitoring namespace, for example, redhat-ods-monitoring. **

**c. Locate the Service named data-science-collector or a similar name associated with the **OpenTelemetry Collector. 

d. Use the Service name or ClusterIP as the OTLP endpoint in your application configuration. Your application must export traces to one of the following ports on the collector service: 

**gRPC: 4317 **

**HTTP: 4318 **Example environment variable: 

NOTE 

See the Red Hat build of OpenTelemetry documentation  for details about configuring application instrumentation. 

OTEL_EXPORTER_OTLP_ENDPOINT=http://data-science-collector.redhat-ods-monitoring.svc.cluster.local:4318 

2. Connect your visualization tool to the Tempo query service. You can use a visualization tool, such as Grafana or Jaeger, to query and display traces from the Red Hat build of Tempo deployed by OpenShift AI. 

a. In the OpenShift web console, navigate to Networking → Services. 

**b. In the Project list, select the monitoring namespace, for example, redhat-ods-monitoring. **

**c. Locate the Service named tempo-query or tempo-query-frontend. **

d. To make the service accessible to external tools, a cluster administrator must perform one of the following actions: 

Create a route: Expose the Tempo Query service externally by creating an OpenShift route. 

Use port forwarding: Temporarily forward a local port to the Tempo Query service by **using the OpenShift CLI (oc): **

After the port is forwarded, connect your visualization tool to the Tempo Query API endpoint, for example: 

NOTE 

See the Tempo Operator documentation for details about connecting to Tempo. 

Verification 

1. Confirm that your instrumented application is generating and exporting trace data. 

2. Verify that the OpenTelemetry Collector pod is running in the monitoring namespace: 

**The data-science-collector-collector-* pod should display a Running status. **

3. Access your visualization tool and confirm that new traces appear in the trace list or search view. 

12.6. ACCESS BUILT-IN ALERTS 

The centralized observability stack deploys a Prometheus Alertmanager instance that provides a common set of built-in alerts for OpenShift AI components. These alerts monitor critical platform conditions, such as operator downtime, crashlooping pods, and unresponsive services. 

By default, the Alertmanager is internal to the cluster and is not exposed through a route. You can **access the Alertmanager web interface locally by using the OpenShift CLI (oc). **

Prerequisites 

$ oc port-forward svc/tempo-query-frontend 3200:3200 -n redhat-ods-monitoring 

http://localhost:3200 

$ oc get pods -n redhat-ods-monitoring | grep collector 

You have OpenShift AI administrator privileges. 

*The observability stack is enabled as described in Enabling the observability stack *. 

**You know the monitoring namespace, for example redhat-ods-monitoring. **

**You have installed the OpenShift CLI (oc) as described in the appropriate documentation for **your cluster: 

Installing the OpenShift CLI for OpenShift Container Platform 

Installing the OpenShift CLI for Red Hat OpenShift Service on AWS 

Procedure 

**1. In a terminal window, log in to the OpenShift CLI (oc) as a cluster administrator: **

2. Verify that the Alertmanager pods are running in the monitoring namespace: 

Example output: 

3. Confirm that a ClusterIP service exposes the Alertmanager web interface on port 9093: 

Example output: 

4. Start a local port forward to the Alertmanager service: 

5. In a web browser, open the following URL to access the Alertmanager web interface: 

Verification 

**Confirm that the Alertmanager web interface opens at http://localhost:9093 and displays **active alerts for OpenShift AI components. 

$ oc login https://api.198.51.100.10:6443 

$ oc get pods -n redhat-ods-monitoring | grep alertmanager 

alertmanager-data-science-monitoringstack-0   2/2   Running   0   2h alertmanager-data-science-monitoringstack-1   2/2   Running   0   2h 

$ oc get svc -n redhat-ods-monitoring | grep alertmanager 

data-science-monitoringstack-alertmanager     ClusterIP   198.51.100.5   <none>   9093/TCP 

$ oc port-forward svc/data-science-monitoringstack-alertmanager 9093:9093 -n redhat-ods-monitoring 

http://localhost:9093 

### CHAPTER 13. VIEW LOGS AND AUDIT RECORDS

As a cluster administrator, you can use the OpenShift AI Operator logger to monitor and troubleshoot issues. You can also use OpenShift audit records to review a history of changes made to the OpenShift AI Operator configuration. 

13.1. CONFIGURE THE OPENSHIFT AI OPERATOR LOGGER 

**You can change the log level for the OpenShift AI Operator by setting the .spec.devFlags.logLevel flag for the DSC Initialization (DSCI) custom resource during runtime. If you do not set a logLevel value, the logger uses the info log level by default. **

**The log level that you set with .spec.devFlags.logLevel applies only to the rhods-operator itself, not **to the individual OpenShift AI components that the Operator manages. 

The following table describes the available log levels: 

Table 13.1. Available log levels for the OpenShift AI Operator 

Log level Severity Verbosity Output format Description 

**error **N/A Low JSON Restricts logging **output to error **messages only. 

**info 0 **Medium JSON Enables standard informational logs **and error. Default **when not set. 

**debug -1 **High JSON Enables all logs: **debug, info, and error. **

Custom numeric **1 or higher **Very High JSON Fine-grained controller execution logging for advanced troubleshooting. Higher integers yield progressively more detailed tracing output. 

Prerequisites 

**You have administrator access to the DSCInitialization resources in the OpenShift cluster. **

**You have installed the OpenShift CLI (oc) as described in the appropriate documentation for **your cluster: 

Installing the OpenShift CLI for OpenShift Container Platform 

Installing the OpenShift CLI for Red Hat OpenShift Service on AWS 

Procedure 

1. Log in to the OpenShift as a cluster administrator. 

2. Go to the Installed Operators page. The navigation path depends on your OpenShift version: 

On OpenShift 4.20 and later, click Ecosystem → Installed Operators. 

On OpenShift 4.19, click Operators → Installed Operators. 

3. Click the DSC Initialization tab. 

4. Click the default-dsci object. 

5. Click the YAML tab. 

**6. In the spec section, update the .spec.devFlags.logLevel flag with the log level that you want **to set. 

7. Click Save. 

8. Alternatively, to configure the log level from the OpenShift CLI ( **oc), run the following **command: 

Verification 

**If you set the log level to error, logs generate infrequently and only capture critical execution **failures and errors. 

**If you set the log level to info (or leave it unset), logs generate at a standard frequency and include info and error messages. **

**If you set the log level to debug, logs generate often and include all debug, info, and error **messages. 

**If you set the log level to a numeric value (such as 1, 2, or 3), logs generate at an extremely high **frequency, exposing deep, fine-grained controller execution data for advanced troubleshooting. Higher integers yield progressively more detailed tracing output. 

View the OpenShift AI Operator logs 

**1. Log in to the OpenShift CLI (oc). **

apiVersion: dscinitialization.opendatahub.io/v2 kind: DSCInitialization metadata:   name: default-dsci spec:   devFlags:     logLevel: debug 

***$ oc patch dsci default-dsci -p {"spec":{"devFlags":{"logLevel":"debug"}}} --*****type=merge **

2. Run the following command to stream logs from all Operator pods: 

The Operator pod logs open in your terminal. 

TIP 

**Press Ctrl+C to stop viewing. To fully stop all log streams, run kill $(jobs -p). **

You can also view each Operator pod log in the OpenShift console by navigating to Workloads → Pods, **selecting the redhat-ods-operator project, clicking a pod name, and then clicking the Logs tab. **

13.2. VIEW AUDIT RECORDS 

Cluster administrators can use OpenShift auditing to see changes made to the OpenShift AI Operator configuration by reviewing modifications to the DataScienceCluster (DSC) and DSCInitialization (DSCI) custom resources. Audit logging is enabled by default in standard OpenShift cluster configurations. For more information, see Viewing audit logs in the OpenShift documentation. 

NOTE 

In Red Hat OpenShift Service on AWS, audit logging is disabled by default because the Elasticsearch log store does not provide secure storage for audit logs. To configure log forwarding, see Logging in the Red Hat OpenShift Service on AWS documentation. 

The following example shows how to use the OpenShift audit logs to see the history of changes made (by users) to the DSC and DSCI custom resources. 

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

**You have installed the OpenShift CLI (oc) as described in the appropriate documentation for **your cluster: 

Installing the OpenShift CLI for OpenShift Container Platform 

Installing the OpenShift CLI for Red Hat OpenShift Service on AWS 

Procedure 

1. In a terminal window, if you are not already logged in to your OpenShift cluster as a cluster administrator, log in to the OpenShift CLI as shown in the following example: 

*$ oc login <openshift_cluster_url> -u <admin_username> -p <password> *

2. To access the full content of the changed custom resources, set the OpenShift audit log policy **to WriteRequestBodies or a more comprehensive profile. For more information, see **Configuring the audit log policy . 

3. Fetch the audit log files that are available for the relevant control plane nodes. For example: 

**for pod in $(oc get pods -l name=rhods-operator -n redhat-ods-operator -o name); do oc logs -f "$pod" -n redhat-ods-operator & done **

oc adm node-logs --role=master --path=kube-apiserver/ \   | awk '{ print $1 }' | sort -u \   | while read node ; do       oc adm node-logs $node --path=kube-apiserver/audit.log < /dev/null     done \   | grep opendatahub > /tmp/kube-apiserver-audit-opendatahub.log 

4. Search the files for the DSC and DSCI custom resources. For example: 

jq 'select((.objectRef.apiGroup == "dscinitialization.opendatahub.io"                 or .objectRef.apiGroup == "datasciencecluster.opendatahub.io")               and .user.username != "system:serviceaccount:redhat-ods-operator:redhat-ods-operator-controller-manager"               and .verb != "get" and .verb != "watch" and .verb != "list")' < /tmp/kube-apiserver-audit-opendatahub.log 

Verification 

The commands return relevant log entries. 

TIP 

To configure the log retention time, see the Logging section in the OpenShift documentation. 