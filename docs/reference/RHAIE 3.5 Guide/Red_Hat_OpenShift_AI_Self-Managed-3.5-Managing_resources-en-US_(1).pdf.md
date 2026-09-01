# Red_Hat_OpenShift_AI_Self-Managed-3.5-Managing_resources-en-US (1).pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Managing resources

Manage administration tasks from the OpenShift AI dashboard 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Managing resources

Manage administration tasks from the OpenShift AI dashboard

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

As an OpenShift AI adminstrator, manage custom workbench images, cluster PVC size, user groups, and Jupyter notebook servers.

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

CHAPTER 1. SELECT ADMIN AND USER GROUPS 

CHAPTER 2 CUSTOMIZE THE DASHBOARD 2.1. EDIT THE DASHBOARD CONFIGURATION 2.2. CONFIGURE GLOBAL PROMPT REGISTRY NAMESPACES 2.3. DASHBOARD CONFIGURATION OPTIONS 

CHAPTER 3 IMPORT A CUSTOM WORKBENCH IMAGE 

CHAPTER 4 MIGRATE CUSTOM WORKBENCH IMAGES TO THE KUBERNETES GATEWAY API 4.1. PATH-BASED ROUTING FOR WORKBENCH ACCESS 4.2. MIGRATE CUSTOM WORKBENCH IMAGES TO THE KUBERNETES GATEWAY API 4.3. MIGRATE CUSTOM WORKBENCH IMAGES TO THE KUBERNETES GATEWAY API WITH NGINX 

CHAPTER 5 MANAGE CLUSTER PVC SIZE 5.1. CONFIGURE THE DEFAULT PVC SIZE FOR YOUR CLUSTER 5.2. RESTORE THE DEFAULT PVC SIZE FOR YOUR CLUSTER 

CHAPTER 6 MANAGE CONNECTION TYPES 6.1. VIEW CONNECTION TYPES 6.2. CREATE A CONNECTION TYPE 6.3. CREATE A CONNECTION TYPE FOR A PYTHON PACKAGE INDEX 6.4. DUPLICATE A CONNECTION TYPE 6.5. EDIT A CONNECTION TYPE 6.6. ENABLE A CONNECTION TYPE 6.7. DELETE A CONNECTION TYPE 

CHAPTER 7 MANAGE STORAGE CLASSES 7.1. PERSISTENT STORAGE FOR WORKBENCHES 

7.1.1. Storage classes in OpenShift AI 7.1.2. Access modes 

7.1.2.1. Using shared storage (RWX) 7.2. CONFIGURE STORAGE CLASS SETTINGS 7.3. CONFIGURE THE DEFAULT STORAGE CLASS FOR YOUR CLUSTER 7.4. OBJECT STORAGE ENDPOINTS 

7.4.1. MinIO (On-Cluster) 7.4.2. Amazon S3 7.4.3. Other S3-Compatible Object Stores 7.4.4. Verification and Troubleshooting 

CHAPTER 8 MANAGE BASIC WORKBENCHES 8.1. ACCESS THE ADMINISTRATION INTERFACE FOR BASIC WORKBENCHES 8.2. START BASIC WORKBENCHES OWNED BY OTHER USERS 8.3. ACCESS BASIC WORKBENCHES OWNED BY OTHER USERS 8.4. STOP BASIC WORKBENCHES OWNED BY OTHER USERS 8.5. STOP IDLE WORKBENCHES 8.6. WORKBENCH POD TOLERATIONS 8.7. TROUBLESHOOTING REFERENCE: WORKBENCHES FOR ADMINISTRATORS 

8.7.1. A user receives a 404: Page not found error when logging in to Jupyter 8.7.2. A user’s workbench does not start 8.7.3. The user receives a database or disk is full error or a no space left on device error when they run notebook cells 

4 

5 

6 6 7 9 

18 

20 20 20 22 

24 24 24 

26 26 26 28 29 30 30 31 

33 33 33 33 34 34 36 36 36 37 37 38 

39 39 39 40 40 41 

42 42 42 43 

44 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .CHAPTER 9 MANAGE THE COLLECTION OF USAGE DATA 9.1. USAGE DATA COLLECTION NOTICE FOR OPENSHIFT AI 9.2. ENABLE USAGE DATA COLLECTION 9.3. DISABLE USAGE DATA COLLECTION 9.4. DISABLE USAGE DATA COLLECTION BY USING THE CLI 9.5. HIDE THE USAGE DATA COLLECTION SECTION IN THE DASHBOARD UI 

46 46 46 47 48 49 

### PREFACE

As an OpenShift AI administrator, you can manage the following resources: 

OpenShift AI admin and user groups 

Dashboard customization 

Custom workbench images 

Cluster PVC size 

Connection types 

Cluster storage classes 

You can also specify whether to allow Red Hat to collect data about OpenShift AI usage in your cluster. 

### CHAPTER 1. SELECT ADMIN AND USER GROUPS

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

### CHAPTER 2. CUSTOMIZE THE DASHBOARD

The OpenShift AI dashboard provides features that are designed to work for most scenarios. These **features are configured in the OdhDashboardConfig custom resource (CR). **

To see a description of the options in the OpenShift AI dashboard configuration, see Dashboard configuration options. 

As an OpenShift AI administrator, you can customize the interface of the dashboard. For example, you can show or hide some of the dashboard navigation menu items. To change the default settings of the **dashboard, edit the OdhDashboardConfig CR as described in Editing the dashboard configuration **. 

2.1. EDIT THE DASHBOARD CONFIGURATION 

As an OpenShift AI administrator, you can customize the interface of the dashboard by editing the dashboard configuration. 

Prerequisites 

You have OpenShift AI administrator privileges. 

Procedure 

1. Log in to the OpenShift console as a user with OpenShift AI administrator privileges. 

2. In the Administrator perspective, click Home → API Explorer. 

**3. In the search bar, enter OdhDashboardConfig to filter by kind. **

**4. Click the OdhDashboardConfig custom resource (CR) to open the resource details page. **

**5. From the Project list, select the OpenShift AI application namespace; the default is redhat-ods-applications. **

6. Click the Instances tab. 

**7. Click the odh-dashboard-config instance to open the details page. **

8. Click the YAML tab. 

9. Edit the values of the options that you want to change. For example, to show or hide a menu item in the dashboard navigation menu, update the **spec.dashboardConfig section to edit the relevant dashboard configuration option. **

NOTE 

**If a dashboard configuration option is not included in the OdhDashboardConfig **CR, the default value is used. 

**To change the default behavior for such options, edit the OdhDashboardConfig CR to add the missing entry to the spec.dashboardConfig section, and set the **preferred value: 

**To show the feature, set the value to false **

**To hide the feature, set the value to true **

Example 

By default, the Observe & monitor → Workload metrics menu item is shown in the dashboard navigation menu. To hide this menu item, set the **disableDistributedWorkloads value to true, as follows: **

disableDistributedWorkloads: true 

For more information about dashboard configuration options and their default values, see Dashboard configuration options . 

10. Click Save to apply your changes and then click Reload to synchronize your changes to the cluster. 

Verification 

Log in to OpenShift AI and verify that your dashboard configurations apply. 

2.2. CONFIGURE GLOBAL PROMPT REGISTRY NAMESPACES 

IMPORTANT 

Global prompt registry namespaces is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Share organization-curated prompts with users across projects by configuring the global MLflow prompt registry namespace. When you configure the global namespace, the MLflow Operator creates the required RBAC bindings automatically. 

You can configure the global namespace from the OpenShift AI dashboard or by editing the **OdhDashboardConfig custom resource (CR) directly. **

Prerequisites 

You have OpenShift AI administrator privileges. 

**The mlflowoperator component is set to Managed in the DataScienceCluster custom **resource (CR). 

**Gen AI Studio is enabled: spec.dashboardConfig.genAiStudio is set to true in the OdhDashboardConfig CR. **

**Prompt management is enabled: spec.dashboardConfig.promptManagement is set to true in the OdhDashboardConfig CR. **

An MLflow server instance is running in the target namespace with one or more prompts registered. The MLflow Operator creates RBAC bindings only when an active MLflow server is present in the namespace. 

Procedure 

To configure the global namespace from the dashboard: 

a. In the OpenShift AI dashboard, click Settings → General settings. 

b. In the Global project section, select the project that contains the prompts you want to share. 

c. Click Save changes. 

To configure the global namespace by editing the CR: 

a. Log in to OpenShift as a user with OpenShift AI administrator privileges. 

**b. Edit the OdhDashboardConfig CR to add the target namespace to the spec.globalMLflowNamespaces field. In the following example, replace _<namespace>_ with the name of the namespace that **contains the MLflow prompt registry you want to share: 

NOTE 

**The globalMLflowNamespaces field is limited to a single namespace entry. This field is located directly under spec, not under spec.dashboardConfig. **

**c. Apply the opendatahub.io/global-mlflow-workspace label to the target namespace. In the following command, replace _<namespace>_ with the same namespace name you added to globalMLflowNamespaces: **

apiVersion: opendatahub.io/v1alpha kind: OdhDashboardConfig metadata:   name: odh-dashboard-config   namespace: pass:attributes[{dbd-config-default-namespace}] spec:   globalMLflowNamespaces: *    - <namespace> *  # ... 

**This label triggers the MLflow Operator to create mlflow-view RBAC bindings in the target **namespace so that users can browse prompts from that namespace. The Operator responds to this label only when an active MLflow server instance is present in the namespace. 

d. Allow up to 60 seconds for the configuration change to take effect. 

Verification 

**Verify that the mlflow-view RoleBinding was created in the target namespace: **

Log in to the OpenShift AI dashboard as a non-administrator user who has a project with a configured playground. Open the Gen AI Studio playground, click Load Prompt, and verify that the Global prompts tab displays prompts from the configured namespace. 

Additional resources 

Dashboard configuration options 

Reusable system instructions 

2.3. DASHBOARD CONFIGURATION OPTIONS 

The OpenShift AI dashboard includes a set of core features enabled by default that are designed to work for most scenarios. OpenShift AI administrators can configure the OpenShift AI dashboard from **the OdhDashboardConfig custom resource (CR) in OpenShift. **

**If a dashboard configuration option is not included in the OdhDashboardConfig CR, the default value is used. To change the default behavior for such options, edit the OdhDashboardConfig CR to add the missing entry to the spec.dashboardConfig section, and set the preferred value: **

**To show the feature, set the value to false **

**To hide the feature, set the value to true **

For more information about setting dashboard configuration options, see Editing the dashboard configuration. 

IMPORTANT 

**Features denoted with (Technology Preview) in this table are not supported with **Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using Technology Preview features in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Table 2.1. Dashboard feature configuration options 

*$ oc label namespace <namespace> opendatahub.io/global-mlflow-workspace=mlflow *

*$ oc get rolebindings -n <namespace> | grep mlflow-view *

Feature configuration option 

Default Description 

**spec.dashboardConfig. agentConfigManageme nt **

(Developer Preview) 

**false **Shows agent management features in the Gen AI Studio Playground, including the ability to save, load, rename, delete, and create variant copies of playground agents. To enable this feature, **set the value to true. **

**spec.dashboardConfig. agentOps (Developer **Preview) 

**false **Enables the Agent Ops features in the Gen AI Studio. To enable **this feature, set the value to true. **

**spec.dashboardConfig. agentsCatalog **(Developer Preview) 

**false **Shows the Agents Catalog page in the dashboard navigation **menu. To enable this feature, set the value to true. **

**spec.dashboardConfig. aiAssetCustomEndpoin ts **

(Technology Preview) 

**false **Shows the Gen AI studio → AI asset endpoints → Create endpoint feature on the dashboard when enabled. To enable, set **the value to true. **

**spec.dashboardConfig. automl (Technology **Preview) 

**false **Enables Automated Machine Learning (AutoML) features in the **dashboard. To enable these features, set the value to true. **

**spec.dashboardConfig. autorag (Technology **Preview) 

**false **Enables Automated Retrieval-Augmented Generation (AutoRAG) features in the dashboard. To enable these features, set the value **to true. **

**spec.dashboardConfig. connectionTest **(Technology Preview) 

**false **Enables connection verification in the dashboard. When enabled, users can verify that connection credentials are valid and endpoints are reachable before saving a connection. The Connections tab also displays a Status column showing **verification results. To enable this feature, set the value to true. **

**spec.dashboardConfig. deploymentWizardYAM LViewer **

(Technology Preview) 

**false Shows a preview of the YAML for the LLMInferenceServices resource. To disable the feature, set the value to false. Note: You **can switch to manual editing for final adjustments. Switching to manual editing disables the configuration wizard. 

**spec.dashboardConfig. disableAcceleratorProfil es **

No longer used 

Deprecated as of OpenShift AI 3.0. Accelerator profiles have been replaced by hardware profiles. 

**spec.dashboardConfig. disableAdminConnectio nTypes **

**false Shows the Settings → Environment setup → Connection types **menu item in the dashboard navigation menu. To hide this menu **item, set the value to true. **

**spec.dashboardConfig. disableBYONImageStre am **

**false Shows the Settings → Environment setup → Workbench images **menu item in the dashboard navigation menu. To hide this menu **item, set the value to true. **

**spec.dashboardConfig. disableClusterManager **

**false Shows the Settings → Cluster settings menu item in the **dashboard navigation menu. To hide this menu item, set the value **to true. **

**spec.dashboardConfig. disableCustomServing Runtimes **

**false Shows the Settings → Model resources and operations → **Serving runtimes menu item in the dashboard navigation menu. **To hide this menu item, set the value to true. **

**spec.dashboardConfig. disableDistributedWorkl oads **

**false **Shows the Workload metrics menu item under Observe and monitor in the dashboard navigation menu. To hide this menu **item, set the value to true. **

**spec.dashboardConfig. disableFeatureStore **

**false **Shows the Feature store menu item in the dashboard navigation **menu. To hide this menu item, set the value to true. **

**spec.dashboardConfig. disableFineTuning **

No longer used 

Deprecated. This option has no effect. 

**spec.dashboardConfig. disableKueue (Developer **Preview) 

**true **Hides Kueue-related options in the dashboard. Set the value to **false to enable Kueue in the dashboard so that users can select Kueue-enabled hardware profiles. When false, new projects **created from the dashboard are automatically configured for Kueue management with the required label and a default local queue. 

**spec.dashboardConfig. disableLMEval **

**true **When true, it hides Eval Hub evaluation features from the **dashboard navigation Develop & train → Evaluations. Set to false **to show these items. 

**spec.dashboardConfig. disableHardwareProfile s **

No longer used 

Deprecated as of OpenShift AI 3.0. Hardware profiles are generally available and cannot be disabled. 

**spec.dashboardConfig. disableHome **

**false **Shows the Home menu item in the dashboard navigation menu. To **hide this menu item, set the value to true. **

**spec.dashboardConfig. disableInfo **

**false On the Applications → Explore page, when a user clicks on an **application tile, an information panel opens with more details about the application. To disable the information panel for all **applications on the Applications → Explore page , set the value to true. **

Feature configuration option 

Default Description 

**spec.dashboardConfig. disableISVBadges **

**false **Shows the label on a tile that indicates whether the application is **Red Hat-managed, Partner managed, or Self-managed. To hide these labels, set the value to true. **

**spec.dashboardConfig. disableKServe **

**false **Enables the ability to select KServe as a model-serving platform. **To disable this ability, set the value to true. **

**spec.dashboardConfig. disableKServeAuth **

**false **Enables the ability to use authentication with KServe. To disable **this ability, set the value to true. **

**spec.dashboardConfig. disableKServeMetrics **

**false **Enables the ability to view KServe metrics. To disable this ability, **set the value to true. **

**spec.dashboardConfig. disableKServeRaw **

**false On the Settings → Cluster settings page, in the Model serving **platform section, shows the Default deployment mode list. 

**spec.dashboardConfig. disableLLMd **

**false **Controls the state of the Enable distributed inference with llm-d **toggle on the Settings → General settings page. If set to true, **the toggle is set to Off and the Distributed inference with llm-d option is hidden in the model serving deployment wizard. 

**spec.dashboardConfig. disableModelCatalog **

**false Shows the AI hub → Catalog menu item in the dashboard navigation menu. To hide this menu item, set the value to true. **

**spec.dashboardConfig. disableModelMesh **

No longer used 

**Deprecated as of OpenShift AI 3.0. The ModelMesh **configuration has been removed. 

**spec.dashboardConfig. disableModelRegistry **

**false Shows the AI hub → Registry menu item and the Settings → Model resources and operations → AI registry settings menu **item in the dashboard navigation menu. To hide these menu items, **set the value to true. **

**spec.dashboardConfig. disableModelRegistryS ecureDB **

**false **Shows the Add CA certificate to secure database connection section in the Create model registry dialog and the Edit model **registry dialog. To hide this section, set the value to true. **

**spec.dashboardConfig. disableModelServing **

**false Shows the AI hub → Deployments menu item in the dashboard **navigation menu, and the Deployments tab in the Projects menu. **To hide these items, set the value to true. **

**spec.dashboardConfig. disableNIMModelServin g **

**false **Enables the ability to select NVIDIA NIM as a model-serving **platform. To disable this ability, set the value to true. **

Feature configuration option 

Default Description 

**spec.dashboardConfig. disablePerformanceMet rics **

**false **Shows the Endpoint Performance tab on the Deployments page. **To hide this tab, set the value to true. **

**spec.dashboardConfig. disablePipelines **

**false **Shows the Develop and train menu item in the dashboard **navigation menu. To hide this menu item, set the value to true. **

**spec.dashboardConfig. disableProjects **

**false **Shows the Projects menu item in the dashboard navigation menu. **To hide this menu item, set the value to true. **

**spec.dashboardConfig. projectRBAC **

**true **Controls the enhanced Permissions tab on the Projects page, which provides role-based access control (RBAC) for project **members. To show this tab, set the value to true. This option is independent of roleManagement. **

**spec.dashboardConfig. roleManagement **

**true **Enables custom role management features in Data Science Projects, including the Roles tab, the custom role creation form, built-in role templates, and edit and duplicate actions. To disable **these features, set the value to false. This option is independent of projectRBAC. **

**spec.dashboardConfig. disableProjectScoped **(Developer Preview) 

**false **Distinguishes between global items and project-scoped items (if project-scoped items exist) in the OpenShift AI web console. This option applies to workbench images, hardware profiles, and model-serving runtimes for KServe. To disable this functionality, **set the value to true. **

**spec.dashboardConfig. disableProjectSharing **

**false **Enables project sharing so that users can share access to their projects with other users. To prevent users from sharing projects, **set the value to true. **

**spec.dashboardConfig. disableServingRuntime Params **

**false **Shows the Configuration parameters section in the Deploy model dialog and the Edit model dialog when using the model serving **platform. To hide this section, set the value to true. **

**spec.dashboardConfig. disableStorageClasses **

**false Shows the Settings → Cluster settings → Storage classes menu **item in the dashboard navigation menu. To hide this menu item, set **the value to true. **

**spec.dashboardConfig. disableSupport **

**false **Shows the Support menu item when a user clicks the Help icon in the dashboard toolbar. To hide this menu item, set the value to **true. **

**spec.dashboardConfig. disableTracking **

**false Hides the Usage data collection section from Settings → General settings in the dashboard. When set to true, the UI section is hidden and tracking is disabled. When set to false, users can view **and configure usage data collection from the dashboard interface. 

Feature configuration option 

Default Description 

**spec.dashboardConfig. disableTrustyBiasMetri cs **

**false **Shows the Model Bias tab on the Models page. To hide this tab, **set the value to true. **

**spec.dashboardConfig. disableUserManagemen t **

**false Shows the Settings → User management menu item in the **dashboard navigation menu. To hide this menu item, set the value **to true. **

**spec.dashboardConfig. enablement **

**true **Enables OpenShift AI administrators to add applications to the OpenShift AI dashboard Applications → Enabled page. To disable **this ability, set the value to false. **

**spec.dashboardConfig. externalModels **

(Technology Preview) 

**false **Enables the external models page in the dashboard. To enable this **feature, set the value to true. **

**spec.dashboardConfig. externalVectorStores **

(Technology Preview) 

**false **When you enable this feature, the Vector stores tab displays on the AI asset endpoints page. The pre-configured vector stores are **defined in the gen-ai-aa-vector-stores ConfigMap namespace. **After you configure a vector store for a playground, select this **option in Settings → Knowledge tab → Use an existing vector **store. 

**spec.dashboardConfig. featureStoreAdmin **

(Technology Preview) 

**false **Enables the Feature Store admin UI, including the create wizard **and manage page. To enable this feature, set the value to true. **

**spec.dashboardConfig. genAiStudio (Technology **Preview) 

**false **Shows or hides the Gen AI studio and AI asset endpoints navigation items in the dashboard. To show these items, set the **value to true. The Playground navigation item additionally **requires the OGX Operator to be installed. 

**spec.dashboardConfig. genAiTracing **

(Technology Preview) 

**false **Enables tracing support in the Gen AI Studio playground. To enable **this feature, set the value to true. **

Feature configuration option 

Default Description 

**spec.dashboardConfig. globalProjectPrompts **

(Technology Preview) 

**false **Shows the global project setting for prompts in the Settings → Cluster settings page. To enable this feature, set the value to **true. **

**spec.dashboardConfig. gpuaas **

**true **Shows the GPUaaS Infrastructure page for cluster capacity and accelerator utilization monitoring. To hide this page, set the value **to false. **

**spec.dashboardConfig. guardrails (Technology **Preview) 

**false **Enables guardrails configuration for model deployments. To enable **this feature, set the value to true. **

**spec.dashboardConfig. llmGatewayField **(Technology Preview) 

**false **Shows or hides a drop-down list of global and local project-scoped gateways in the Advanced Settings step of your model deployment. Users can access the model deployment through these gateways. The selected gateway is applied to the **llminferenceservice.spec.router.gateway resource. If you make no selection, the value remains empty ({}). The cluster **automatically infers this value based on how the administrator configured the llmd option. 

**spec.dashboardConfig. llmdTemplates **

(Technology Preview) 

**false **Enables llm-d topology and routing configuration fields in the deployment wizard and admin settings pages. To enable this **feature, set the value to true. **

**spec.dashboardConfig. maasAuthPolicies **

No longer used 

Deprecated. This option has no effect. 

**spec.dashboardConfig. mcpCatalog **

(Technology Preview) 

**false **Enable this feature to browse and deploy MCP servers from Red Hat partners and other providers. In the left navigation menu, click **AI hub → MCP servers. On the Catalog tab, you can find a specific **MCP server by using the Search field, or you can filter by collection using the Red Hat MCP server, Red Hat Partner MCP server, or Other MCP server tabs. 

**spec.dashboardConfig. mcpRegistry **

(Technology Preview) 

**false **Shows the Registry tab within the MCP Servers page. To enable **this feature, set the value to true. **

**spec.dashboardConfig. mlflow **

No longer used 

**Deprecated. The MLflow configuration is now always enabled **when the Operator component is present. 

Feature configuration option 

Default Description 

**spec.dashboardConfig. modelAsService **(Technology Preview) 

**true **Shows or hides the Model as a service tab on the AI assets **endpoint page. To hide this tab, set the value to false. **

**spec.dashboardConfig. observabilityDashboard **

**true **Shows the Observe and monitor → Dashboard menu item in the dashboard navigation menu. To hide this menu item, set the value **to false. **

**spec.dashboardConfig. promptManagement **(Technology Preview) 

**false **Shows or hides prompt management features in the Gen AI Studio Chat Playground. When enabled, you can load prompts from the MLflow prompt registry, and save new prompts or versions of existing prompts. You can search, preview versions, and load prompts into the playground with the prompt library modal. 

**spec.dashboardConfig. roleManagement **

**true **Enables project role management features for custom RBAC roles. **To disable this feature, set the value to false. **

**spec.dashboardConfig. trainingJobs **

**true **Shows or hides the Develop and train → Training jobs menu item in the dashboard navigation menu. To show this menu item, set the **value to true. **

**spec.dashboardConfig. toolCalling **

(Technology Preview) 

**false **Enables tool calling configuration such as filters, labels and commands for validated models in the model catalog. To enable **this feature, set the value to true. **

**spec.dashboardConfig. vLLMDeploymentOnMa aS (Technology Preview) **

**false **Shows or hides the option to use the new default deployment method for basic vLLM generative AI models. Previously, you could **only deploy an LLMInferenceService resource by selecting the **llm-d option. Enable this flag to give your users the choice to deploy basic vLLM generative AI models by using the new vLLM on Maas option. 

These vLLM options are displayed from preconfigured and **configurable LLMInferenceServiceConfigs resources in the **global application namespace. Each resource is tied to a specific GPU accelerator. 

**spec.genAiStudioConfi g.aiAssetCustomEndpo ints. clusterDomains **

**[] **Specifies an array of domains that the cluster treats as internal, in **addition to .svc.cluster.local, which the cluster always treats as **internal. To disable this feature, leave the array empty. 

Feature configuration option 

Default Description 

**spec.genAiStudioConfi g.aiAssetCustomEndpo ints. externalProviders **

**false **Shows the Gen AI studio → AI asset endpoints feature on the dashboard to specify if users can create external third-party **provider endpoints. Set to true to enable external providers. You must also set the aiAssetCustomEndpoints resource to true. To hide this feature, set the value to false. **

**spec.globalMLflowNam espaces (Technology **Preview) 

**[] **Specifies the namespace that contains the MLflow prompt registry to share across projects. When you add a namespace to this list **and label it with opendatahub.io/global-mlflow-workspace, the MLflow Operator creates mlflow-view RBAC bindings that **allow users to browse prompts from that namespace. Limited to a **single namespace entry. Requires promptManagement to be set to true. This field is located directly under spec, not under spec.dashboardConfig. For more information, see Configure **global prompt registry namespaces. 

**spec.groupsConfig **No longer used 

Read-only. To configure access to the OpenShift AI dashboard, **use the spec.adminGroups and spec.allowedGroups options in the OpenShift Auth resource in the services.platform.opendatahub.io API group. **

**spec.modelServerSizes **No longer used 

Deprecated. Use hardware profiles instead to customize names and resources for model servers. 

**spec.notebookControlle r. enabled **

**true **Shows the Start basic workbench tile in the Applications section, and the Start basic workbench button on the Projects page. To **hide these items, set the value to false. **

**spec.notebookSizes **No longer used 

Deprecated. Use hardware profiles instead to customize names and resources for workbenches. 

**spec.templateOrder [] **Specifies the order of custom Serving Runtime templates. When the user creates a new template, it is added to this list. 

Feature configuration option 

Default Description 

### CHAPTER 3. IMPORT A CUSTOM WORKBENCH IMAGE

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

### CHAPTER 4. MIGRATE CUSTOM WORKBENCH IMAGES TO THE KUBERNETES GATEWAY API

Previously, the standard setup of JupyterLab and code-server leveraged OpenShift Routes and unique hostnames or subdomains for each workbench. Traffic was directed to the pod, and the application inside the pod usually served content from the root path (/). Red Hat OpenShift AI now leverages the Kubernetes Gateway API for request routing. This architecture replaces individual OpenShift Routes and Ingress resources with path-based routing through a single entry point. 

4.1. PATH-BASED ROUTING FOR WORKBENCH ACCESS 

Path-based routing is a traffic management strategy where an API Gateway or load balancer sends requests to specific backend services based on the URL path provided by the client. 

The Kubernetes Gateway API introduces path-based routing to your workbench image updating workflow. 

Key architectural change 

OpenShift Route (Previous) External: /notebook/user/workbench/app/ → Route strips prefix → Container receives: /app/ 

Gateway API (New) External: /notebook/user/workbench/app/ → Gateway preserves full path (path-based routing) → Container receives: /notebook/user/workbench/app/ 

**If your application redirects to paths outside of the ${NB_PREFIX}, the Gateway cannot route those **requests back to your application. The path-based matching at the Gateway level requires all traffic to stay within the configured prefix. 

IMPORTANT 

Your application (or reverse proxy) must handle the full path including the prefix and never redirect outside of it. 

Any request from a browser to a different path will not be routed to the workbench container. This is because the routing, handled by the Gateway API uses the same value **as the environment variable (NB_PREFIX) that is injected into the workbench at runtime. **

4.2. MIGRATE CUSTOM WORKBENCH IMAGES TO THE KUBERNETES GATEWAY API 

To ensure that your workbench maintains compatibility with the latest versions of Red Hat OpenShift AI, update your custom workbench images to the Kubernetes Gateway API to support this path-based model. 

Prerequisites 

You are a Red Hat OpenShift AI user with OpenShift AI administrator privileges. 

Your OpenShift cluster version is at least version 4.19. 

Your Red Hat OpenShift AI Operator version is at least version 3.0. 

Your system can build custom workbench images 

Procedure 

1. Implement required health check endpoints. The Gateway API requires a specific endpoint to verify workbench pod availability. 

**Configure the application to return an HTTP 200 status at: GET /{NB_PREFIX}/api. **

2. Configure culler support: To support automatic idleness culling, the workbench must expose kernels and terminal status as JSON arrays. Ensure the application implements these endpoints: 

**GET /{NB_PREFIX}/api/kernels **

**GET /{NB_PREFIX}/api/terminals **

3. Use relative URLs throughout your application. 

NOTE 

**Avoid hardcoded absolute paths such as /static/app.js or /api/data. These paths bypass the {NB_PREFIX} and cannot be routed by the Gateway. Instead, use relative paths like static/app.js or api/data, which resolve correctly within the **prefixed context. 

If your application contains hardcoded absolute URLs that cannot be modified, *you must use NGINX as a reverse proxy to handle path translation. See Migrating your custom workbench images to the Kubernetes Gateway API using NGINX for *configuration details. 

4. Configure your application’s base path. If your framework supports a configurable base path or root path, set it to the value of the **NB_PREFIX environment variable. This ensures that generated URLs, redirects, and static **asset references include the correct prefix. 

**For example, in Python frameworks you can set root_path (FastAPI) or APPLICATION_ROOT **(Flask). In JavaScript frameworks, configure the base URL or public path setting accordingly. 

Verification 

Click on your workbench through the Workbenches tab on the project details page. Verify that the page loads correctly. If the page displays without formatting or functional errors, the **${NB_PREFIX} variable is configured correctly. **

Use the OpenShift CLI to verify the gateway can reach the health endpoint: 

oc exec <pod-name> -- curl -I http://localhost:8888/${NB_PREFIX}/api 

**The command should return an HTTP/1.1 200 OK response. **

**Monitor the Gateway Controller logs for No route matched errors. These errors indicate that **the workbench is sending responses that lack the required path-based routing prefix. 

4.3. MIGRATE CUSTOM WORKBENCH IMAGES TO THE KUBERNETES GATEWAY API WITH NGINX 

If your application does not support base path configuration, you will need NGINX to handle the path translation. 

Prerequisites 

You are a Red Hat OpenShift AI user with OpenShift AI administrator privileges. 

Your OpenShift cluster version is at least version 4.19. 

Your Red Hat OpenShift AI Operator version is at least version 3.0. 

Your system can build custom workbench images. 

Procedure 

**1. Update redirects to preserve NB_PREFIX. All redirects must include ${NB_PREFIX} to keep **requests within the Gateway route: 

#   BAD - Strips prefix location = ${NB_PREFIX} {     return 302 $custom_scheme://$http_host/myapp/; } 

#   GOOD - Preserves prefix location ${NB_PREFIX} {     return 302 $custom_scheme://$http_host${NB_PREFIX}/myapp/; } 

2. Add a prefix-aware proxy location that matches the full prefixed path, and strips the prefix before proxying. 

location ${NB_PREFIX}/myapp/ {     # Strip the prefix before proxying to backend     rewrite ^${NB_PREFIX}/myapp/(.*)$ /$1 break; 

    # Proxy to your application     proxy_pass http://localhost:8080/;     proxy_http_version 1.1; 

    # Essential for WebSocket support     proxy_set_header Upgrade $http_upgrade;     proxy_set_header Connection $connection_upgrade; 

    # Long timeout for interactive sessions     proxy_read_timeout 20d; 

    # Pass through important headers     proxy_set_header Host $http_host;     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;     proxy_set_header X-Forwarded-Proto $custom_scheme; } 

3. Update health check endpoints to preserve the prefix: 

# Health check endpoint location = ${NB_PREFIX}/api {     return 302 ${NB_PREFIX}/myapp/healthz/;     access_log off; } 

Verification 

Verify that the page loads correctly. If the page displays without formatting or functional errors, the ${NB_PREFIX} variable is configured correctly. 

Use the OpenShift CLI to verify the gateway can reach the health endpoint: 

oc exec <pod-name> -- curl -I http://localhost:8888/${NB_PREFIX}/api 

**The command should return an HTTP/1.1 200 OK response. **

**Monitor the Gateway Controller logs for No route matched errors. These errors indicate that **the workbench is sending responses that lack the required path-based routing prefix. 

### CHAPTER 5. MANAGE CLUSTER PVC SIZE

5.1. CONFIGURE THE DEFAULT PVC SIZE FOR YOUR CLUSTER 

To configure how resources are claimed within your OpenShift AI cluster, you can change the default size of the cluster’s persistent volume claim (PVC) ensuring that the storage requested matches your common storage workflow. PVCs are requests for resources in your cluster and also act as claim checks to the resource. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

NOTE 

Changing the PVC setting restarts the workbench pod and makes it unavailable for up to 30 seconds. As a workaround, it is recommended that you perform this action outside of your organization’s typical working day. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Cluster settings. 

2. Under PVC size, enter a new size in gibibytes or mebibytes. 

3. Click Save changes. 

Verification 

New PVCs are created with the default storage size that you configured. 

Additional resources 

Understanding persistent storage 

5.2. RESTORE THE DEFAULT PVC SIZE FOR YOUR CLUSTER 

To change the size of resources utilized within your OpenShift AI cluster, you can restore the default size of your cluster’s persistent volume claim (PVC). 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Cluster settings. 

2. Click Restore Default to restore the default PVC size of 20GiB. 

3. Click Save changes. 

Verification 

New PVCs are created with the default storage size of 20 GiB. 

Additional resources 

Understanding persistent storage 

### CHAPTER 6. MANAGE CONNECTION TYPES

In Red Hat OpenShift AI, a connection comprises environment variables along with their respective values. Data scientists can add connections to project resources, such as workbenches and model servers. 

When a data scientist creates a connection, they start by selecting a connection type. Connection types are templates that include customizable fields and optional default values. Starting with a connection type decreases the time required by a user to add connections to data sources and sinks. OpenShift AI includes pre-installed connection types for S3-compatible object storage databases and URI-based repositories. 

As an OpenShift AI administrator, you can manage connection types for users in your organization as follows: 

View connection types and preview user connection forms 

Create a connection type 

Duplicate an existing connection type 

Edit a connection type 

Delete a custom connection type 

Enable or disable a connection type in a project, to control whether it is available as an option to users when they create a connection 

6.1. VIEW CONNECTION TYPES 

As an OpenShift AI administrator, you can view the connection types that are available in a project. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Environment setup → Connection types. The Connection types page opens, displaying the available connection types for the current project. 

2. Optionally, you can select the Options menu  and then click Preview to see how the connection form associated with the connection type is displayed to your users. 

6.2. CREATE A CONNECTION TYPE 

As an OpenShift AI administrator, you can create a connection type for users in your organization. 

You can create a new connection type as described in this procedure or you can create a copy of an existing connection type and edit it, as described in Duplicating a connection type . 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

You know the environment variables that are required or optional for the connection type that you want to create. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Environment setup → Connection types. The Connection types page opens, displaying the available connection types. 

2. Click Create connection type. 

3. In the Create connection type form, enter the following information: 

a. Enter a name for the connection type. A resource name is generated based on the name of the connection type. A resource name is the label for the underlying resource in OpenShift. 

b. Optionally, edit the default resource name. Note that you cannot change the resource name after you create the connection type. 

c. Optionally, in the Connection type description field, provide a description of the connection type. 

d. Specify at least one category label. By default, the category labels are database, model registry, object storage, and URI. Optionally, you can create a new category by typing the new category label in the field. You can specify more than one category. The category label is for descriptive purposes only. It allows you and the users in your origanization to sort the available connection types when viewing them in the OpenShift AI dashboard interface. 

e. Check the Enable users in your organization to use this connection type when adding connections" option if you want the connection type to appear in the list of connections available to users, for example, when they configure a workbench, a model server, or a pipeline. Note that you can also enable/disable the connection type after you create it. 

f. For the Fields section, add the fields and section headings that you want your users to see in the form when they add a connection to a project resource (such as a workbench or a model server). Note that the connection name and description fields are included by default, so you do not need to add them. 

Optionally, select a model serving compatible type to automatically add the fields required to use its corresponding model serving method. 

Click Add field to add a field to prompt users to input information, and optionally assign default values to those fields. 

Click Add section heading to organize the fields under headings. 

4. Click Preview to open a preview of the connection form as it will appear to your users. 

5. Click Create. 

Verification 

1. On the Settings → Environment setup → Connection types page, the new connection type is displayed in the list. 

6.3. CREATE A CONNECTION TYPE FOR A PYTHON PACKAGE INDEX 

As an OpenShift AI administrator, you can create a connection type that configures a custom Python package index URL for workbench users. When users add this connection to a workbench, the **PIP_INDEX_URL environment variable is set automatically, directing pip to use the specified package **index instead of the default Red Hat Python index. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

You know the URL of the Python package index that you want to configure for users. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Environment setup → Connection types. The Connection types page opens, displaying the available connection types. 

2. Click Create connection type. 

3. In the Create connection type form, configure the following settings: 

**a. In the Connection type name field, enter a name, such as Python package index. **

**b. Optional: In the Connection type description field, enter a description, such as Configures the Python package index URL for pip. **

c. In the Category field, select URI. 

d. Check the Enable users in your organization to use this connection type when adding connections option to make the connection type available to users immediately. 

4. In the Fields section, click Add field and configure the field with the following settings: 

**a. In the Name field, enter a name, such as Package index URL. **

b. From the Type list, select URI. 

**c. In the Environment variable field, enter PIP_INDEX_URL. **

d. Optional: In the Default value field, enter the URL of the package index that you want to use as a default for users. 

e. Optional: Select the Field is required checkbox to make the field required. 

5. Click Preview to verify that the connection form is displayed as expected. 

6. Click Create. 

NOTE 

If the index uses HTTP or a certificate that pip does not trust, add a **PIP_TRUSTED_HOST field by repeating step 4 before creating the connection **type. 

Verification 

1. On the Settings → Environment setup → Connection types page, verify that the new connection type is displayed in the list. 

2. To verify that the connection type works: 

a. Add a connection of this type to a workbench. For more information, see Adding a connection to your project. Updating the workbench connection configuration restarts the workbench. 

b. After the workbench restarts, open a terminal in the workbench and confirm that the **PIP_INDEX_URL environment variable is set: **

Additional resources 

Creating a connection type 

Adding a connection to your project 

6.4. DUPLICATE A CONNECTION TYPE 

As an OpenShift AI administrator, you can create a new connection type by duplicating an existing one, as described in this procedure, or you can create a new connection type as described in Creating a connection type. 

You might also want to duplicate a connection type if you want to create versions of a specific connection type. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Environment setup → Connection types. 

2. From the list of available connection types, find the connection type that you want to duplicate. 

Optionally, you can select the Options menu  and then click Preview to see how the related connection form is displayed to your users. 

3. Click the Options menu  , and then click Duplicate. The Create connection type form is displayed populated with the information from the connection type that you duplicated. 

$ echo "$PIP_INDEX_URL" 

4. Edit the form according to your use case. 

5. Click Preview to open a preview of the connection form as it will appear to your users and verify that the form is displayed as you expect. 

6. Click Save. 

Verification 

In the Settings → Environment setup → Connection types page, the duplicated connection type is displayed in the list. 

6.5. EDIT A CONNECTION TYPE 

As an OpenShift AI administrator, you can edit a connection type for users in your organization. 

Note that you cannot edit the connection types that are pre-installed with OpenShift AI. Instead, you have the option of duplicating a pre-installed connection type, as described in Duplicating a connection type. 

When you edit a connection type, your edits do not apply to any existing connections that users previously created. If you want to keep track of previous versions of this connection type, consider duplicating it instead of editing it. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

The connection type must exist and must not be a pre-installed connection type (which you are unable to edit). 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Environment setup → Connection types. 

2. From the list of available connection types, find the connection type that you want to edit. 

3. Click the Options menu  , and then click Edit. The Edit connection type form is displayed. 

4. Edit the form fields and sections. 

5. Click Preview to open a preview of the connection form as it will appear to your users and verify that the form is displayed as you expect. 

6. Click Save. 

Verification 

In the Settings → Environment setup → Connection types page, the duplicated connection type is displayed in the list. 

6.6. ENABLE A CONNECTION TYPE 

As an OpenShift AI administrator, you can enable or disable a connection type to control whether it is available as an option to your users when they create a connection. 

Note that if you disable a connection type, any existing connections that your users created based on that connection type are not effected. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

The connection type that you want to enable exists in your project, either pre-installed or created by a user with administrator privileges. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Environment setup → Connection types. 

2. From the list of available connection types, find the connection type that you want to enable or disable. 

3. On the row containing the connection type, click the toggle in the Enable column. 

Verification 

If you enabled a connection type, it is available for selection when a user adds a connection to a project resource (for example, a workbench or model server). 

If you disabled a connection type, it does not show in the list of available connection types when a user adds a connection to a project resource. 

6.7. DELETE A CONNECTION TYPE 

As an OpenShift AI administrator, you can delete a connection type that you or another administrator created. 

Note that you cannot delete the connection types that are pre-installed with OpenShift AI. Instead, you have the option of disabling them so that they are not visible to your users, as described in Enabling a connection type. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

The connection type must exist and must not be a pre-installed connection type (which you are unable to delete). 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Environment setup → Connection types. 

2. From the list of available connection types, find the connection type that you want to delete. 

Optionally, you can select the Options menu  and then click Preview to see how the related connection form is displayed to your users. 

3. Click the Options menu  , and then click Delete. 

4. In the Delete connection type? form, type the name of the connection type that you want to delete and then click Delete. 

Verification 

In the Settings → Environment setup → Connection types page, the connection type is no longer displayed in the list. 

### CHAPTER 7. MANAGE STORAGE CLASSES

OpenShift cluster administrators use storage classes to describe the different types of storage that is available in their cluster. These storage types can represent different quality-of-service levels, backup policies, or other custom policies set by cluster administrators. 

7.1. PERSISTENT STORAGE FOR WORKBENCHES 

OpenShift AI uses persistent storage to support workbenches, project data, and model training. 

Persistent storage is provisioned through OpenShift storage classes and persistent volumes. Volume provisioning and data access are determined by access modes. 

Understanding storage classes and access modes can help you choose the right storage for your use case and avoid potential risks when sharing data across multiple workbenches. 

7.1.1. Storage classes in OpenShift AI 

Storage classes in OpenShift AI are available from the underlying OpenShift cluster. A storage class defines how persistent volumes are provisioned, including which storage backend is used and what access modes the provisioned volumes can support. For more information, see Dynamic provisioning in the OpenShift documentation. 

Cluster administrators create and configure storage classes in the OpenShift cluster. These storage classes provision persistent volumes that support one or more access modes, depending on the capabilities of the storage backend. OpenShift AI administrators then enable specific storage classes and access modes for use in OpenShift AI. 

When adding cluster storage to your project or workbench, you can choose from any enabled storage classes and access modes. 

7.1.2. Access modes 

Storage classes create persistent volumes that can support different access modes, depending on the storage backend. Access modes control how a volume can be mounted and used by one or more workbenches. If a storage class allows more than one access mode, you can select the one that best fits **your needs when you request storage. All persistent volumes support ReadWriteOnce (RWO) by **default. 

Access mode Description 

**ReadWriteOnce (RWO) (Default) **

The storage can be attached to a single workbench or pod at a time and is ideal **for most individual workloads. RWO is always enabled by default and cannot be **disabled by the administrator. 

**ReadWriteMany (RWX) **

**The storage can be attached to many workbenches simultaneously. RWX enables **shared data access, but can introduce data risks. 

**ReadOnlyMany (ROX) **

**The storage can be attached to many workbenches as read-only. ROX is useful **for sharing reference data without allowing changes. 

**ReadWriteOncePod (RWOP) **

The storage can be attached to a single pod on a single node with read-write **permissions. RWOP is similar to RWO but includes additional node-level **restrictions. 

Access mode Description 

NOTE 

You can enable access modes that are required. A warning is displayed if you request an access mode with unknown support, but you can continue to select Save to create the storage class with the selected access mode. 

7.1.2.1. Using shared storage (RWX) 

**The ReadWriteMany (RWX) access mode allows multiple workbenches to access and write to the same storage volume at the same time. Use RWX access mode for collaborative work where multiple users **need to access shared datasets or project files. 

However, shared storage introduces several risks: 

Data corruption or data loss: If multiple workbenches modify the same part of a file simultaneously, the data can become corrupted or lost. Ensure your applications or workflows are designed to safely handle shared access, for example, by using file locking or database transactions. 

Security and privacy: If a workbench with access to shared storage is compromised, all data on that volume might be at risk. Only share sensitive data with trusted workbenches and users. 

To use shared storage safely: 

Ensure that your tools or workflows are designed to work with shared storage and can manage simultaneous writes. For example, use databases or distributed data processing frameworks. 

Be cautious with changes. Deleting or editing files affects everyone who shares the volume. 

Back up your data regularly, which can help prevent data loss due to mistakes or misconfigurations. 

Limit access to RWX volumes to trusted users and secure workbenches. 

**Use ReadWriteMany (RWX) only when collaboration on a shared volume is required. For most individual tasks, ReadWriteOnce (RWO) is ideal because only one workbench can write to the **volume at a time. 

7.2. CONFIGURE STORAGE CLASS SETTINGS 

As an OpenShift AI administrator, you can manage the following OpenShift cluster storage class settings for use within OpenShift AI: 

Display name 

Description 

Access modes 

Whether users can use the storage class when creating or editing cluster storage 

These settings do not impact the storage class within OpenShift. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Cluster settings → Storage classes. The Storage classes page opens, displaying the storage classes for your cluster as defined in OpenShift. 

2. To enable or disable a storage class for users, on the row containing the storage class, click the toggle in the Enable column. 

3. To edit a storage class, on the row containing the storage class, click the action menu (⋮) and then select Edit. The Edit storage class details dialog opens. 

4. Optional: In the Display Name field, update the name for the storage class. This name is used only in OpenShift AI and does not impact the storage class within OpenShift. 

5. Optional: In the Description field, update the description for the storage class. This description is used only in OpenShift AI and does not impact the storage class within OpenShift. 

6. For storage classes that support multiple access modes, select an Access mode to define how the volume can be accessed. For more information, see About persistent storage. 

NOTE 

A warning is displayed if you request an access mode with unknown support, but you can continue to select Save to create the storage class with the selected access mode. Only the access modes that have been enabled for the storage class by cluster and OpenShift AI administrators are visible. 

7. Click Save. 

Verification 

If you enabled a storage class, the storage class is available for selection when a user adds cluster storage to a project or workbench. 

If you disabled a storage class, the storage class is not available for selection when a user adds cluster storage to a project or workbench. 

If you edited a storage class name, the updated storage class name is displayed when a user adds cluster storage to a project or workbench. 

Additional resources 

Storage classes in OpenShift 

7.3. CONFIGURE THE DEFAULT STORAGE CLASS FOR YOUR CLUSTER 

As an OpenShift AI administrator, you can configure the default storage class for OpenShift AI to be different from the default storage class in OpenShift. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Cluster settings → Storage classes. The Storage classes page opens, displaying the storage classes for your cluster as defined in OpenShift. 

2. If the storage class that you want to set as the default is not enabled, on the row containing the storage class, click the toggle in the Enable column. 

3. To set a storage class as the default for OpenShift AI, on the row containing the storage class, select Set as default. 

Verification 

When a user adds cluster storage to a project or workbench, the default storage class that you configured is automatically selected. 

Additional resources 

Storage classes in OpenShift 

7.4. OBJECT STORAGE ENDPOINTS 

To ensure correct configuration of object storage in OpenShift AI, you must format endpoints correctly for the different types of object storage supported. These instructions are for formatting endpoints for Amazon S3, MinIO, or other S3-compatible storage solutions, minimizing configuration errors and ensuring compatibility. 

IMPORTANT 

Properly formatted endpoints enable connectivity and reduce the risk of misconfigurations. Use the appropriate endpoint format for your object storage type. Improper formatting might cause connection errors or restrict access to storage resources. 

7.4.1. MinIO (On-Cluster) 

For on-cluster MinIO instances, use a local endpoint URL format. Ensure the following when configuring MinIO endpoints: 

**Prefix the endpoint with http:// or https:// depending on your MinIO security setup. **

Include the cluster IP or hostname, followed by the port number if specified. 

**Use a port number if your MinIO instance requires one (default is typically 9000). **

Example: 

http://minio-cluster.local:9000 

NOTE 

Verify that the MinIO instance is accessible within the cluster by checking your cluster DNS settings and network configurations. 

7.4.2. Amazon S3 

When configuring endpoints for Amazon S3, use region-specific URLs. Amazon S3 endpoints generally follow this format: 

**Prefix the endpoint with https://. **

**Format as <bucket-name>.s3.<region>.amazonaws.com, where <bucket-name> is the name of your S3 bucket, and <region> is the AWS region code (for example, us-west-1, eu-central-1). **

Example: 

https://my-bucket.s3.us-west-2.amazonaws.com 

NOTE 

For improved security and compliance, ensure that your Amazon S3 bucket is in the correct region. 

7.4.3. Other S3-Compatible Object Stores 

For S3-compatible storage solutions other than Amazon S3, follow the specific endpoint format required by your provider. Generally, these endpoints include the following items: 

**The provider base URL, prefixed with https://. **

The bucket name and region parameters as specified by the provider. 

Review the documentation from your S3-compatible provider to confirm required endpoint formats. 

**Replace placeholder values like <bucket-name> and <region> with your specific configuration **details. 

WARNING 

Incorrectly formatted endpoints for S3-compatible providers might lead to access denial. Always verify the format in your storage provider documentation to ensure compatibility. 

7.4.4. Verification and Troubleshooting 

After configuring endpoints, verify connectivity by performing a test upload or accessing the object storage directly through the OpenShift AI dashboard. For troubleshooting, check the following items: 

Network Accessibility: Confirm that the endpoint is reachable from your OpenShift AI cluster. 

Authentication: Ensure correct access credentials for each storage type. 

Endpoint Accuracy: Double-check the endpoint URL format for any typos or missing components. 

Additional resources 

Amazon S3 Region and Endpoint Documentation: AWS S3 Documentation 

- 

### CHAPTER 8. MANAGE BASIC WORKBENCHES

8.1. ACCESS THE ADMINISTRATION INTERFACE FOR BASIC WORKBENCHES 

You can use the administration interface to control basic workbenches in your Red Hat OpenShift AI environment. 

Prerequisite 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

Procedure 

To access the administration interface for basic workbenches from OpenShift AI, perform the following actions: 

1. In OpenShift AI, in the Applications section of the left menu, click Enabled. 

2. Locate the Start basic workbench tile and click Open application. 

3. On the page that opens, click the Administration tab. The Administration page opens. 

Verification 

You can see the administration interface for basic workbenches. 

8.2. START BASIC WORKBENCHES OWNED BY OTHER USERS 

OpenShift AI administrators can start a basic workbench for another existing user from the administration interface for basic workbenches. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

You have launched the Start basic workbench application, as described in Starting a basic workbench. 

Procedure 

1. On the page that opens when you launch a basic workbench, click the Administration tab. 

2. On the Administration tab, perform the following actions: 

a. In the Users section, locate the user whose workbench you want to start. 

b. Click Start workbench beside the relevant user. 

c. Complete the Start a basic workbench page. 

d. Optional: Select the Start workbench in current tab checkbox if necessary. 

e. Click Start workbench. After the server starts, you see one of the following behaviors: 

If you previously selected the Start workbench in current tab checkbox, the JupyterLab interface opens in the current tab of your web browser. 

If you did not previously select the Start workbench in current tab checkbox, the Workbench status dialog box prompts you to open the server in a new browser tab or in the current tab. The JupyterLab interface opens according to your selection. 

Verification 

The JupyterLab interface opens. 

8.3. ACCESS BASIC WORKBENCHES OWNED BY OTHER USERS 

OpenShift AI administrators can access basic workbenches that are owned by other users to correct configuration errors or to help them troubleshoot problems with their environment. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

You have launched the Start basic workbench application, as described in Starting a basic workbench. 

The workbench that you want to access is running. 

Procedure 

1. On the page that opens when you launch a basic workbench, click the Administration tab. 

2. On the Administration page, perform the following actions: 

a. In the Users section, locate the user that the workbench belongs to. 

b. Click View server beside the relevant user. 

c. On the Workbench control panel page, click Access workbench. 

Verification 

The JupyterLab interface opens in the user’s workbench. 

8.4. STOP BASIC WORKBENCHES OWNED BY OTHER USERS 

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

8.5. STOP IDLE WORKBENCHES 

You can reduce resource usage in your OpenShift AI deployment by stopping workbenches that have been idle (without logged in users) for a period of time. This is useful when resource demand in the cluster is high. By default, idle workbenches are not stopped after a specific time limit. 

NOTE 

If you have configured your cluster settings to disconnect all users from a cluster after a specified time limit, then this setting takes precedence over the idle workbench time limit. Users are logged out of the cluster when their session duration reaches the clusterwide time limit. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Cluster settings. 

2. Under Idle workbench timeout, select Stop idle workbenches after defined period. 

3. Enter a time limit, in hours and minutes, for when idle workbenches are stopped. 

4. Click Save changes. 

Verification 

**In OpenShift, go to Workloads → ConfigMaps and open the notebook-controller-culler-config ConfigMap in the redhat-ods-applications project to verify that it contains the **following culling configuration settings: 

**ENABLE_CULLING: Specifies if the culling feature is enabled or disabled (this is false by **default). 

**IDLENESS_CHECK_PERIOD: The polling frequency to check for a notebook’s last known **activity (in minutes). 

**CULL_IDLE_TIME: The maximum allotted time to scale an inactive notebook to zero (in **minutes). 

Idle workbenches stop at the time limit that you set. 

8.6. WORKBENCH POD TOLERATIONS 

You can configure tolerations for workbench pods by using hardware profiles. Hardware profiles replace the earlier cluster-wide toleration setting and offer more flexible, per-profile tolerations. You can define tolerations as part of a hardware profile and apply them selectively to individual workbenches. 

To configure tolerations for workbench pods, create or update a hardware profile with the required tolerations. 

Additional resources 

Working with hardware profiles 

Creating a hardware profile 

Updating a hardware profile 

8.7. TROUBLESHOOTING REFERENCE: WORKBENCHES FOR ADMINISTRATORS 

If your users are experiencing errors in Red Hat OpenShift AI relating to Jupyter, their Jupyter notebooks, or their workbench, read this section to understand what could be causing the problem, and how to resolve the problem. 

If you cannot see the problem here or in the release notes, contact Red Hat Support. 

8.7.1. A user receives a 404: Page not found error when logging in to Jupyter 

Problem 

If you have configured OpenShift AI user groups, the user name might not be added to the default user group for OpenShift AI. 

Diagnosis 

Check whether the user is part of the default user group. 

1. Find the names of groups allowed access to Jupyter. 

a. Log in to the OpenShift web console. 

b. Click User Management → Groups. 

**c. Click the name of your user group, for example, rhods-users. **The Group details page for that group is displayed. 

2. Click the Details tab for the group and confirm that the Users section for the relevant group contains the users who have permission to access Jupyter. 

Resolution 

If the user is not added to any of the groups with permission access to Jupyter, follow Adding users to OpenShift AI user groups to add them. 

If the user is already added to a group with permission to access Jupyter, contact Red Hat Support. 

8.7.2. A user’s workbench does not start 

Problem 

The OpenShift cluster that hosts the user’s workbench might not have access to enough resources, or the workbench pod may have failed. 

Diagnosis 

1. Log in to the OpenShift web console. 

2. Delete and restart the workbench pod for this user. 

**a. Click Workloads → Pods and set the Project to rhods-notebooks or your custom **workbench namespace. 

**b. Search for the workbench pod that belongs to this user, for example, jupyter-nb-<username>-*. **If the workbench pod exists, an intermittent failure might have occurred in the workbench pod. 

If the workbench pod for the user does not exist, continue with diagnosis. 

3. Check the resources currently available in the OpenShift cluster against the resources required by the selected workbench image. If worker nodes with sufficient CPU and RAM are available for scheduling in the cluster, continue with diagnosis. 

4. Check the state of the workbench pod. 

Resolution 

If there was an intermittent failure of the workbench pod: 

a. Delete the workbench pod that belongs to the user. 

b. Ask the user to start their workbench again. 

If the workbench does not have sufficient resources to run the selected workbench image, either add more resources to the OpenShift cluster, or choose a smaller image size. 

If the workbench pod is in a FAILED state: 

**a. Retrieve the logs for the jupyter-nb-* pod and send them to Red Hat Support for further **evaluation. 

**b. Delete the jupyter-nb-* pod. **

If none of the previous resolutions apply, contact Red Hat Support. 

8.7.3. The user receives a database or disk is full error or a no space left on device error when they run notebook cells 

Problem 

The user might have run out of storage space on their workbench. 

Diagnosis 

1. Log in to Jupyter and start the workbench that belongs to the user having problems. If the workbench does not start, follow these steps to check whether the user has run out of storage space: 

a. Log in to the OpenShift web console. 

**b. Click Workloads → Pods and set the Project to rhods-notebooks or your custom **workbench namespace. 

**c. Click the workbench pod that belongs to this user, for example, jupyter-nb-<idp>-<username>-*. **

d. Click Logs. The user has exceeded their available capacity if you see lines similar to the following: 

Unexpected error while saving file: XXXX database or disk is full 

Resolution 

Increase the user’s available storage by expanding their persistent volume: Expanding persistent volumes 

**Work with the user to identify files that can be deleted from the /opt/app-root/src directory on **their workbench to free up their existing storage space. 

NOTE 

When you delete files using the JupyterLab file explorer, the files move to the hidden **/opt/app-root/src/.local/share/Trash/files folder in the persistent storage for the **workbench. To free up storage space for workbenches, you must permanently delete these files. 

### CHAPTER 9. MANAGE THE COLLECTION OF USAGE DATA

Red Hat OpenShift AI administrators can choose whether to allow Red Hat to collect data about OpenShift AI usage in their cluster. Collecting this data allows Red Hat to monitor and improve our software and support. For further details about the data Red Hat collects, see Usage data collection notice for OpenShift AI. 

Usage data collection is enabled by default when you install OpenShift AI on your OpenShift cluster except when clusters are installed in a disconnected environment. 

See Disabling usage data collection  for instructions on disabling the collection of this data in your cluster. If you have disabled data collection on your cluster, and you want to enable it again, see Enabling usage data collection for more information. 

9.1. USAGE DATA COLLECTION NOTICE FOR OPENSHIFT AI 

In connection with your use of this Red Hat offering, Red Hat may collect usage data about your use of the software. This data allows Red Hat to monitor the software and to improve Red Hat offerings and support, including identifying, troubleshooting, and responding to issues that impact users. 

What information does Red Hat collect? 

Tools within the software monitor various metrics and this information is transmitted to Red Hat. Metrics include information such as: 

Information about applications enabled in the product dashboard. 

The deployment sizes used (that is, the CPU and memory resources allocated). 

Information about documentation resources accessed from the product dashboard. 

The name of the notebook images used, such as Jupyter | Minimal | CPU | Python 3.12, Jupyter | Data Science | CPU | Python 3.12, and other images. 

A unique random identifier that generates during the initial user login to associate data to a particular username. 

Usage information about components, features, and extensions. 

Third Party Service Providers 

Red Hat uses certain third party service providers to collect the telemetry data. 

Security 

Red Hat employs technical and organizational measures designed to protect the usage data. 

Personal Data 

Red Hat does not intend to collect personal information. If Red Hat discovers that personal information has been inadvertently received, Red Hat will delete such personal information and treat such personal information in accordance with Red Hat’s Privacy Statement. For more information about Red Hat’s privacy practices, see Red Hat’s Privacy Statement. 

Enabling and Disabling Usage Data 

You can disable or enable usage data by following the instructions in Disabling usage data collection or Enabling usage data collection. 

9.2. ENABLE USAGE DATA COLLECTION 

Red Hat OpenShift AI administrators can select whether to allow Red Hat to collect data about OpenShift AI usage in their cluster. Usage data collection is enabled by default when you install OpenShift AI on your OpenShift cluster except when clusters are installed in a disconnected environment. If you have disabled data collection previously, you can re-enable it by following these steps. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Cluster settings. 

2. Locate the Usage data collection section. 

3. Select the Allow collection of usage data checkbox. 

4. Click Save changes. 

Verification 

**A notification is shown when settings are updated: Settings changes saved. **

Additional resources 

Usage data collection notice for OpenShift AI 

9.3. DISABLE USAGE DATA COLLECTION 

Red Hat OpenShift AI administrators can choose whether to allow Red Hat to collect data about OpenShift AI usage in their cluster. Usage data collection is enabled by default when you install OpenShift AI on your OpenShift cluster except when clusters are installed in a disconnected environment. 

You can disable data collection by following these steps. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Cluster settings. 

2. Locate the Usage data collection section. 

3. Clear the Allow collection of usage data checkbox. 

4. Click Save changes. 

Verification 

**A notification is shown when settings are updated: Settings changes saved. **

Additional resources 

Usage data collection notice for OpenShift AI 

9.4. DISABLE USAGE DATA COLLECTION BY USING THE CLI 

**You can disable the collection of usage data for OpenShift AI by using the OpenShift CLI (oc). When **disabled, OpenShift AI does not send usage data to Red Hat. 

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

**You have installed the OpenShift CLI (oc). **

Procedure 

1. Disable usage data collection by patching the segment key configuration: 

where: 

**_<namespace>_ **

**Specifies your application namespace. The namespace defaults to redhat-ods-applications **unless customized in the DSCI. 

NOTE 

**To re-enable usage data collection, set the "segmentKeyEnabled" value to "true". **

Verification 

Verify that the segment key is disabled: 

where: 

**_<namespace>_ **

**Specifies your application namespace. The namespace defaults to redhat-ods-applications **unless customized in the DSCI. **The command returns false. **

Verify the segment key API returns an empty value. 

Port forward the dashboard service: 

$ oc patch configmap odh-segment-key-config \   -n _<namespace>_ \   --type=merge \   -p '{"data":{"segmentKeyEnabled":"false"}}' 

$ oc get configmap odh-segment-key-config \   -n _<namespace>_ \   -o jsonpath='{.data.segmentKeyEnabled}{"\n"}' 

where: 

**_<namespace>_ **

**Specifies your application namespace. The namespace defaults to redhat-ods-applications unless customized in the DSCI. **

From another terminal, run the following command: 

**When usage data collection is disabled, the segmentKey value is empty. **

In the OpenShift AI dashboard, navigate to Settings → General settings and verify that the Usage data collection checkbox shows the option as disabled. 

Additional resources 

Managing the collection of usage data 

Hiding the usage data collection UI section 

9.5. HIDE THE USAGE DATA COLLECTION SECTION IN THE DASHBOARD UI 

You can hide the Usage data collection section from the OpenShift AI dashboard by using the **disableTracking feature flag. When enabled, this flag removes the UI section from Settings → General **settings and prevents users from viewing or modifying the usage data collection setting through the dashboard interface. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

**You have installed the OpenShift CLI (oc). **

Procedure 

1. Hide the usage data collection UI section by patching the dashboard configuration: 

where: 

**_<namespace>_ **

**Specifies your application namespace. The namespace defaults to redhat-ods-applications unless customized in the DataScienceClusterInitialization (DSCI). **

$ oc -n _<namespace>_ port-forward svc/rhods-dashboard 8443:8443 

$ curl -sk -H "Authorization: Bearer $(oc whoami -t)" https://127.0.0.1:8443/api/segment-key 

$ oc patch odhdashboardconfig odh-dashboard-config \ *  -n <namespace> \ *  --type=merge \ *  -p {"spec":{"dashboardConfig":{"disableTracking":true}}} *

Verification 

**Verify that the disableTracking feature flag is set to true: **

where: 

**_<namespace>_ **

**Specifies your application namespace. The namespace defaults to redhat-ods-applications **unless customized in the DSCI. **The command returns true. **

Wait up to two minutes for the dashboard to refresh the configuration. In the OpenShift AI dashboard, navigate to Settings → General settings and verify that the Usage data collection section does not appear. 

Additional resources 

Dashboard configuration options 

$ oc get odhdashboardconfig odh-dashboard-config \ *  -n <namespace> \   -o jsonpath={.spec.dashboardConfig.disableTracking}{"\n"} *