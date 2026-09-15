# Red_Hat_OpenShift_AI_Self-Managed-3.5-Working_with_MLflow-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Working with MLflow

Work with MLflow from Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Working with MLflow

Work with MLflow from Red Hat OpenShift AI Self-Managed

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

As a data scientist or platform engineer, you can use the MLflow operator in OpenShift AI.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. MLFLOW FOR EXPERIMENT TRACKING 

CHAPTER 2 INSTALL AND CONFIGURE MLFLOW 2.1. MLFLOW AND MLFLOWCONFIG CONFIGURATION PARAMETERS 2.2. AGGREGATE CLUSTER ROLES 

2.2.1. Cluster roles for global prompt registry namespaces 2.3. RBAC MODEL FOR MLFLOW API USAGE 

CHAPTER 3 INSTALL AND AUTHENTICATE THE MLFLOW SDK 3.1. CONFIGURE THE MLFLOW SDK FOR A LOCAL WORKSTATION 3.2. CONFIGURE MLFLOW SDK ENVIRONMENT VARIABLES FOR PODS 3.3. UPSTREAM MLFLOW SDK REFERENCE 3.4. MLFLOW SDK TROUBLESHOOTING 3.5. MLFLOW VERSION COMPATIBILITY 3.6. MLFLOW STORAGE AND DATABASE COMPATIBILITY 3.7. TRACK EXPERIMENTS WITH MLFLOW SDK 3.8. CONFIGURE PROJECT-SPECIFIC S3 ARTIFACT STORAGE 

CHAPTER 4 TRACK EXPERIMENTS WITH MLFLOW IN WORKBENCHES 4.1. MLFLOW WORKBENCH INTEGRATION 

4.1.1. How the integration works 4.1.2. Configuration methods 4.1.3. Annotation lifecycle 4.1.4. Non-blocking behavior 4.1.5. Limitations 

4.2. ENABLE THE MLFLOW OPERATOR COMPONENT 4.2.1. MLflow dashboard feature flag deprecation 

4.2.1.1. Deprecated field 4.2.1.2. Current behavior 4.2.1.3. mlflowPipelines field 

4.3. ENABLE MLFLOW INTEGRATION FOR A WORKBENCH 4.4. USE THE MLFLOW SDK IN A WORKBENCH NOTEBOOK 4.5. DISABLE MLFLOW INTEGRATION FOR A WORKBENCH 4.6. RESOLVE MLFLOW ANNOTATION REMOVAL REJECTION 4.7. MLFLOW WORKBENCH ENVIRONMENT VARIABLES AND ANNOTATIONS 

4.7.1. Annotation 4.7.2. Environment variables 4.7.3. RoleBinding 4.7.4. ClusterRole availability 4.7.5. Controller environment variables 

CHAPTER 5 TRACK AND COMPARE MLFLOW EXPERIMENTS 5.1. VIEW MLFLOW EXPERIMENTS AND RUNS 5.2. COMPARE MLFLOW RUNS 

CHAPTER 6 TRACE ARCHIVAL FOR MLFLOW 6.1. CONFIGURE TRACE ARCHIVAL 6.2. CONFIGURE TRACE ARCHIVAL RETENTION FOR EXPERIMENTS 6.3. ARCHIVED TRACE SEARCH AND RETRIEVAL BEHAVIOR 

6.3.1. Search filter behavior 6.3.2. Trace retrieval 

6.4. TRACE ARCHIVAL TROUBLESHOOTING 

3 

4 6 8 9 

10 

13 14 15 16 16 17 18 18 19 

21 21 21 21 22 22 22 22 24 24 24 24 25 26 28 29 30 30 31 31 32 32 

33 33 34 

36 37 40 41 41 41 

42 

### CHAPTER 1. MLFLOW FOR EXPERIMENT TRACKING

Red Hat OpenShift AI deploys a single shared MLflow instance through the MLflow operator. With this deployment, you can use MLflow workspaces and Kubernetes-backed authorization. For more information, see MLflow Workspaces. 

A project is a namespace that has its own set of objects, policies, constraints, and service accounts. Each Red Hat OpenShift Container Platform project maps to an MLflow workspace in a one-to-one relationship. MLflow provides logical isolation of experiments, runs, registered models, prompts, datasets, and traces per workspace. 

OpenShift AI manages the workspace lifecycle outside of MLflow. The MLflow API does not create, update, or delete workspaces. Instead, you manage workspaces through the OpenShift AI dashboard or the Red Hat OpenShift command-line interface (CLI). When you manage projects through these tools, the corresponding MLflow workspace becomes available automatically. 

Every MLflow API request relies on Kubernetes role-based access control (RBAC) for authorization. The MLflow server submits a SelfSubjectAccessReview against pseudo-resources in the mlflow.kubeflow.org API group, using the caller’s bearer token and the target project namespace. Users who already have the Red Hat OpenShift admin, edit, or view roles on a project automatically receive the corresponding MLflow permissions. 

### CHAPTER 2. INSTALL AND CONFIGURE MLFLOW

To track machine learning experiments in OpenShift AI, use the Red Hat OpenShift AI Operator to **deploy a cluster-scoped mlflow instance. **

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

You have installed the OpenShift Container Platform 

**You have permission to patch the DataScienceCluster resource and apply MLflow custom **resources. 

Procedure 

**The MLflow resource is cluster scoped. Therefore, you can install only one instance of mlflow in the **cluster. The Red Hat OpenShift AI Operator creates the MLflow resource in the redhat-ods-applications namespace. 

1. Log in to the OpenShift cluster by using the CLI. 

**2. Enable the MLflow Operator component by patching the DataScienceCluster object: **

$ oc patch datasciencecluster default-dsc \   --type=merge \ *  -p {"spec":{"components":{"mlflowoperator":{"managementState":"Managed"}}}} *

3. For a production-oriented deployment, create a secret that contains the S3-compatible storage credentials for artifact storage: 

where: 

**_<your_aws_access_key>_ **

Specifies the access key ID for your S3-compatible storage provider. 

**_<your_aws_secret_access_key>_ **

Specifies the secret access key for your S3-compatible storage provider. 

**_<your_aws_session_token>_ **

apiVersion: v1 kind: Secret metadata:   name: mlflow-s3-credentials   namespace: redhat-ods-applications type: Opaque stringData: *  AWS_ACCESS_KEY_ID: "<your_aws_access_key>"   AWS_SECRET_ACCESS_KEY: "<your_aws_secret_access_key>"   # Optional: Remove the following fields if they do not apply to your environment.   AWS_SESSION_TOKEN: "<your_aws_session_token>"   AWS_DEFAULT_REGION: "<your_aws_region>"   MLFLOW_S3_ENDPOINT_URL: "<your_s3_endpoint_url>" *

Optional. Specifies the session token for temporary credentials. Remove this field if you are using long-lived IAM credentials. 

**_<your_aws_region>_ **

Optional. Specifies the AWS region for the S3 bucket. Remove this field if your storage provider does not require a region. 

**_<your_s3_endpoint_url>_ **

Optional. Specifies the endpoint URL for S3-compatible object storage, for example **\https://minio.example.com:9000. Remove this field if you are using AWS S3. **

**4. Create an MLflow custom resource (CR). Choose the configuration that matches your **environment: 

Minimal development or test deployment 

Uses SQLite for the backend store and a persistent volume claim (PVC) for file-based artifact storage. 

IMPORTANT 

**Artifact serving is not supported when spec.artifactsDestination uses a file:// path together with spec.storage. **

Production-oriented deployment 

Uses PostgreSQL for metadata and S3-compatible object storage for artifacts. 

apiVersion: mlflow.opendatahub.io/v1 kind: MLflow metadata:   name: mlflow   namespace: redhat-ods-applications spec:   storage:     accessModes:       - ReadWriteOnce     resources:       requests:         storage: 10Gi   backendStoreUri: "sqlite:////mlflow/mlflow.db"   artifactsDestination: "file:///mlflow/artifacts" 

apiVersion: mlflow.opendatahub.io/v1 kind: MLflow metadata:   name: mlflow   namespace: redhat-ods-applications spec:   replicas: 2   backendStoreUriFrom:     name: mlflow-db-credentials     key: backend-store-uri   artifactsDestination: "s3://my-mlflow-bucket/artifacts"   serveArtifacts: true 

Table 2.1. MLflow Deployment and Artifact Configuration 

Parameter or Feature 

Configuration Details 

**replicas **Acts as an important scaling knob specifically for production-oriented deployments. 

**registryStoreUri Defaults to the value of backendStoreUri if not specified. In practice, the **same PostgreSQL database is typically utilized for both. 

**serveArtifacts **When enabled, clients log and retrieve artifacts through the MLflow server **REST API via the mlflow-artifacts:/ proxy URI scheme. If defaultArtifactRoot is not specified while this is enabled, it automatically defaults to mlflow-artifacts:/. **

**defaultArtifactRoot **Defines the directory for storing artifacts for each new experiment. Do not **set this to a direct-storage URI (e.g., s3://) when serveArtifacts is **enabled; doing so causes clients to bypass the proxy and attempt direct storage access. 

Artifact Storage Path If no per-project override is configured, artifacts are stored under **<default_artifact_root>/workspaces/<project_name>. **

5. In the OpenShift AI dashboard navigation bar, click the Applications menu. 

6. Confirm that the MLflow UI is displayed in the list. 

7. Open the UI, select your workspace, and verify that you can compare runs and visualize metrics. 

8. Alternatively, click Start Demo, which loads demo data to compare runs and visualize metrics. 

Additional resources 

**To view all available configuration options for the MLflow custom resource, run the oc explain mlflow.spec command. **

2.1. MLFLOW AND MLFLOWCONFIG CONFIGURATION PARAMETERS 

**The MLflow deployment on Red Hat OpenShift AI relies on two custom resources (CRs): MLflow and MLflowConfig. These resources configure metadata storage, artifact destinations, and project-specific **overrides. 

**The MLflow resource is cluster-scoped and must be named mlflow. This resource defines the global **state of the MLflow deployment, including the database backend, artifact storage, replica count, and TLS configuration. 

  envFrom:     - secretRef:         name: mlflow-s3-credentials 

**Table 2.2. Key fields in the MLflow resource **

Field Description 

**spec.replicas **The number of MLflow pods. The default value is 1. High-availability deployments require remote storage because PVC-backed storage does not support multiple concurrent writers. 

**spec.storage **The persistent storage configuration for file-based development or test deployments. This field provisions a persistent volume claim (PVC) for the MLflow pods. 

**spec.backendStoreU ri **

**The tracking metadata database URI. Supported values include sqlite:// for development and postgresql:// for production. For production usage, use spec.backendStoreUriFrom to avoid storing database credentials in the **MLflow CR. 

**spec.backendStoreU riFrom **

A secret reference for the backend database URI. This field is used when the URI contains credentials. 

**spec.artifactsDestin ation **

The base URI where MLflow stores artifacts for new experiments. If you do not set **this field, the operator uses a file:// URI for the /mlflow/artifacts path. Artifact serving is not supported when this field uses a file:// path together with spec.storage. **

**spec.serveArtifacts **When enabled, clients log and retrieve artifacts through the MLflow tracking server. Use remote object storage if you enable artifact serving. 

**mlflow.spec.resourc es **

Specifies the compute resources for the MLflow container. 

**The MLflowConfig resource is namespace-scoped and must be named mlflow. Project owners can use **this resource to override default artifact storage settings for their specific projects. 

**Table 2.3. Key fields in the MLflowConfig resource **

Field Description 

**spec.artifactRootSec ret **

The name of a secret in the project that contains S3-compatible connection **credentials and bucket information. The value must be mlflow-artifact-connection. **

**spec.artifactRootPat h **

An optional relative path appended to the bucket root from the secret. For **example, if the bucket is my-bucket and the path is mlflow-artifacts, the resolved artifact root is s3://my-bucket/mlflow-artifacts. **

**The traceArchival section in the MLflow resource configures automatic archival of trace span payloads **from the SQL tracking store to archive storage. 

**Table 2.4. Key fields in the traceArchival section of the MLflow resource **

Field Description 

**spec.traceArchival.e nabled **

**Enables trace archival. The default value is false. When set to true, the MLflow Operator creates a CronJob that runs the archival process on the configured **schedule. 

**spec.traceArchival.s chedule **

**The cron expression that controls how often the archival CronJob runs. The default value is 0 */6 * * *, which runs every 6 hours. This field is required when **trace archival is enabled. 

**spec.traceArchival.lo cation **

The archive URI where archived trace span payloads are stored, for example **s3://mlflow-trace-archive. A file:// URI is supported only when spec.storage uses shared ReadWriteMany (RWX) storage. Persistent volume claims that do **not provide RWX storage are not supported. This field is required when trace archival is enabled. 

**spec.traceArchival.re tention **

The age threshold after which traces are eligible for archival. The value must use **the format <number><unit>, where the unit is m for minutes, h for hours, or d for days. For example, 30d archives traces older than 30 days. This field is **required when trace archival is enabled. 

**spec.traceArchival.m axTracesPerPass **

**The maximum number of traces to archive in a single CronJob run. The default value is 1000. The minimum value is 1. **

**spec.traceArchival.lo ngRetentionAllowlist **

A list of experiment IDs that are permitted to set a retention period longer than the server default. You can list up to 64 experiment IDs. 

**spec.traceArchival.re sources **

**The compute resource requests and limits for the archival CronJob container. **

**To view all available configuration fields for a resource, use the oc explain <resource>.spec **command. 

2.2. AGGREGATE CLUSTER ROLES 

MLflow uses aggregate cluster roles to control access to MLflow resources in Red Hat OpenShift AI. These roles determine which MLflow operations a user can perform based on their existing role bindings. 

IMPORTANT 

**Standard bindings for view, edit, and admin roles do not grant identical access to all MLflow resources. While mlflow resources are cluster-scoped, mlflowconfig resources **are namespace-scoped. Effective access depends on whether permissions are granted at the cluster level or the namespace level. 

**The mlflow-view ClusterRole aggregates into the standard OpenShift AI view, edit, and admin roles. **User access depends on the scope of the binding set at the cluster level. 

This role grants read-only access to the following MLflow resources: 

**get, list, and watch permissions for the mlflow and mlflowconfigs Custom Resource **Definitions (CRDs) 

**get and list permissions for MLflow pseudo-resources, such as datasets, experiments, and registeredmodels **

**get permissions for MLflow status **

**The mlflow-edit ClusterRole aggregates into the standard OpenShift AI edit and admin roles. User **access depends on the scope of the binding set at the cluster level. 

This role grants write access to the following MLflow resources: 

**create, read, update, and delete permissions for the mlflow CRD **

**create, delete, patch, and update permissions for the mlflowconfigs CRD **

**create, update, and delete permissions for MLflow pseudo-resources **

**update permissions for finalizers **

**The mlflow-integration ClusterRole grants service accounts data-plane access to MLflow without **requiring full edit or delete privileges. When you bind this role with a RoleBinding, it provides **namespace-scoped access. This ClusterRole does not grant delete or access to the control-plane **resources. 

This role is intended for integration-focused tasks and grants the following access: 

**get, list, create, and update permissions for the experiments, datasets, and registeredmodels **authorization-plugin pseudo-resources 

Read access to MLflow resources and statuses 

Permissions to interact with the MLflow tracking API and model registry 

2.2.1. Cluster roles for global prompt registry namespaces 

IMPORTANT 

Global prompt registry namespaces is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

**The MLflow Operator uses two additional ClusterRoles to provision RBAC bindings in global prompt **registry namespaces. When an administrator designates a namespace as a global project, the Operator **creates RoleBindings in that namespace that reference these ClusterRoles. **

**The mlflow-operator-mlflow-view ClusterRole grants read-only access to MLflow resources. The Operator binds this role to all groups listed in the allowedGroups and adminGroups fields of the Auth **custom resource. 

**The mlflow-operator-mlflow-edit ClusterRole grants write access to MLflow resources. The Operator binds this role only to groups listed in the adminGroups field of the Auth custom resource. **

**The Operator manages these RoleBindings automatically. You do not need to create or modify them **directly. For more information about configuring a global prompt registry namespace, see Reusable system instructions. 

2.3. RBAC MODEL FOR MLFLOW API USAGE 

**The MLflow server authorizes every API request by using a Kubernetes SelfSubjectAccessReview. The **server uses the caller’s bearer token to determine if the token has permission to perform a specific verb on an MLflow pseudo-resource within the target project namespace. 

***The authorization checks use the mlflow.kubeflow.org API group. These pseudo-resources are used ***solely for role-based access control (RBAC) policy evaluation. Pseudo-resources are not actual Kubernetes resources or Custom Resource Definitions (CRDs), they do not exist as objects on the cluster. You cannot create, list, or inspect pseudo-resources by using the Kubernetes API or command-**line tools such as kubectl. **

**Access is granted through standard Kubernetes Role, ClusterRole, RoleBinding and ClusterRoleBinding objects. **

The workspace name serves as the Kubernetes namespace for access checks. The MLflow API access is project-scoped. 

The following table outlines primary pseudo-resources: 

Table 2.5. MLflow pseudo-resources 

Pseudo-resource Controls access to 

**experiments **Experiments, runs, traces, artifacts, logged models, scorers, and related tracking operations. 

**registeredmodels **Registered models, model versions, and prompts. 

**datasets **Evaluation datasets and related data set operations. 

+ .Role assignments for MLflow API usage 

The Red Hat OpenShift AI admin, edit, and view roles include the permissions required for MLflow API **authorization checks through aggregate ClusterRoles. These roles allow users to interact with MLflow **components within their assigned namespaces. 

Workloads or agents that require MLflow API access without using broad human-facing roles can use **built-in integration roles. For example, a dedicated mlflow-integration ClusterRole is available for **service accounts that need to perform automated tracking or model registry tasks. 

+ .Resource-name granularity The MLflow Kubernetes authorization plugin allows you to assign **permissions with resourceName granularity. For example, you can restrict an agent so that it sends **traces to only a specific experiment by defining the following attributes in the RBAC policy: 

**resourceName: The name of the specific experiment **

**resource: experiments **

**apiGroup: mlflow.kubeflow.org **

**verbs: get, list, update **

RBAC for global prompt registry namespaces 

IMPORTANT 

Global prompt registry namespaces is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

When an administrator configures a global prompt registry namespace, the MLflow Operator **automatically creates RoleBindings in that namespace so that users can access shared prompts across projects. The Operator monitors for the opendatahub.io/global-mlflow-workspace label on namespace objects and provisions the following RoleBindings: **

**odh-group-mlflow-view **

**References the mlflow-operator-mlflow-view ClusterRole. Grants read-only access to MLflow resources in the global namespace. Bound to all groups in the allowedGroups and adminGroups fields of the Auth custom resource. **

**odh-group-mlflow-edit **

**References the mlflow-operator-mlflow-edit ClusterRole. Grants write access to MLflow resources in the global namespace. Bound only to groups in the adminGroups field of the Auth custom **resource. 

**The Auth custom resource uses the services.platform.opendatahub.io/v1alpha1 API version. The resource name is auth. The Operator reads the spec.allowedGroups and spec.adminGroups fields to **identify the groups that receive view and edit access. 

**The Operator manages the full lifecycle of these RoleBindings: **

**When an administrator removes the namespace label, the Operator deletes both RoleBindings **from that namespace. 

**When the allowedGroups or adminGroups fields in the Auth custom resource change, the Operator re-reconciles RoleBindings across all labeled namespaces. **

**If the Auth custom resource is unavailable, the Operator removes any existing managed RoleBindings rather than preserving potentially stale permissions. **

**If Kubernetes garbage collection deletes the MLflow custom resource that owns the RoleBindings, it removes the RoleBindings automatically. **

**Allow up to 60 seconds for RBAC changes to propagate after a namespace label or Auth custom **resource change. 

### CHAPTER 3. INSTALL AND AUTHENTICATE THE MLFLOW SDK

Install the MLflow SDK and configure authentication for your OpenShift cluster to track machine learning experiments in Red Hat OpenShift AI. 

Prerequisites 

You have access to a OpenShift cluster. 

**You have installed the OpenShift CLI (oc) and are able to access MLflow in your OpenShift AI **project or MLflow workspace. 

For the automated authentication method, you have a service account with the appropriate permissions or are running locally. 

Procedure 

1. Install the MLflow SDK: 

2. Authenticate the SDK by using one of the following methods: 

**a. To use automated authentication, enable the kubernetes-namespaced client-side **authentication plugin. 

NOTE 

This plugin reads credentials from the mounted service account token when **running in a pod, or from the active kubeconfig context when running on a **workstation. The MLflow workspace is automatically configured by reading **either the service account’s namespace or active kubeconfig namespace. **

Enter the following commands: 

b. To authenticate manually, export your tracking token and project workspace as environment variables. Enter the following commands: 

IMPORTANT 

This configuration example is not recommended for production environments. 

pip install "mlflow[kubernetes]>=3.11" 

export MLFLOW_TRACKING_URI="https://<dashboard-url>/mlflow" export MLFLOW_TRACKING_AUTH=kubernetes-namespaced 

export MLFLOW_TRACKING_URI="https://<dashboard-url>/mlflow" export MLFLOW_TRACKING_TOKEN="$(oc whoami --show-token)" export MLFLOW_WORKSPACE="<project-name>" 

3. Optional: To enable direct-to-storage artifact transfers from the MLflow client, enter the following commands: 

When you set these variables, the client attempts to bypass the tracking server for artifact data transfer by requesting server-issued multipart upload credentials and presigned download URLs. 

NOTE 

If your MLflow server does not support these direct-to-storage flows, unset these variables and use the default proxied artifact transfer path. 

4. Optional: To tune multipart artifact transfer thresholds and chunk sizes, enter the following commands: 

where: 

**MLFLOW_MULTIPART_UPLOAD_MINIMUM_FILE_SIZE **

Specifies the file size threshold, in bytes, at which the client switches from a single-part upload to a multipart upload. 

**MLFLOW_MULTIPART_UPLOAD_CHUNK_SIZE **

Specifies the size, in bytes, of each multipart upload chunk. 

**MLFLOW_MULTIPART_DOWNLOAD_CHUNK_SIZE **

Specifies the size, in bytes, of each multipart download chunk. 

5. If your OpenShift cluster does not use trusted TLS certificates, enter the following command to disable TLS verification: 

Verification 

To verify connectivity, use the following command: 

This command lists the workspaces you can access on the OpenShift cluster. 

3.1. CONFIGURE THE MLFLOW SDK FOR A LOCAL WORKSTATION 

When you run the MLflow SDK on a local workstation, the authentication plugin uses the active kubeconfig context. The plugin uses the namespace from the kubeconfig context as the workspace and resolves the authentication token from your kubeconfig credentials, including exec-based **authentication providers used by oc login command. **

export MLFLOW_ENABLE_PROXY_MULTIPART_UPLOAD=true export MLFLOW_ENABLE_PROXY_MULTIPART_DOWNLOAD=true 

export MLFLOW_MULTIPART_UPLOAD_MINIMUM_FILE_SIZE=524288000 export MLFLOW_MULTIPART_UPLOAD_CHUNK_SIZE=10485760 export MLFLOW_MULTIPART_DOWNLOAD_CHUNK_SIZE=104857600 

export MLFLOW_TRACKING_INSECURE_TLS=true 

`python -c "import mlflow; print(mlflow.list_workspaces())"` 

Prerequisites 

You have installed the MLflow SDK. 

You have an active kubeconfig context. 

Procedure 

1. Set the following environment variables to configure the tracking URI and authentication method: 

2. Optional: If you prefer to set the token and workspace manually, export the following variables: 

3.2. CONFIGURE MLFLOW SDK ENVIRONMENT VARIABLES FOR PODS 

When you run a pod, the Kubernetes authentication plugin uses the mounted service account token and namespace to automatically set the workspace. 

**You do not have to call mlflow.set_workspace() when you enable the authentication plugin. The plugin **derives the workspace from the pod’s service account namespace. You can override the workspace explicitly if you need to target a different project, provided that your service account has the necessary RBAC permissions in that project. 

Prerequisites 

You have installed the MLflow SDK. 

Procedure 

1. Set the following environment variables in your pod configuration: 

Verification 

1. Run a Python script using the following code to confirm that the MLflow SDK successfully connects to the tracking server and logs data: 

export MLFLOW_TRACKING_URI="https://<dashboard-url>/mlflow" export MLFLOW_TRACKING_AUTH=kubernetes-namespaced 

export MLFLOW_TRACKING_URI="https://<dashboard-url>/mlflow" export MLFLOW_TRACKING_TOKEN="$(oc whoami --show-token)" export MLFLOW_WORKSPACE="<project-name>" 

export MLFLOW_TRACKING_URI="https://<dashboard-url>/mlflow" export MLFLOW_TRACKING_AUTH=kubernetes-namespaced 

import mlflow 

mlflow.set_experiment("demo-experiment") 

3.3. UPSTREAM MLFLOW SDK REFERENCE 

Additional resources 

For more information about the upstream MLflow SDK, see the following resources: 

MLflow tracking 

MLflow Tracking API reference 

MLflow Model Registry 

Getting started with MLflow workspaces 

MLflow workspace providers 

MLflow 3 migration guide 

MLflow Python API reference 

3.4. MLFLOW SDK TROUBLESHOOTING 

If you encounter errors when working with experiments or artifacts in the MLflow SDK, use the following information to resolve common issues and error messages. 

If your issue is not described here, contact Red Hat support. 

Common issues 

403 or permission denied 

Problem 

The active project is missing the required role-based access control (RBAC) permissions. 

Resolution 

Verify that your user or service account has the necessary role binding in the active project. 

Workspace not found 

Problem The SDK cannot locate the workspace because the project name is incorrect, the namespace is filtered, or no workspace was selected. Resolution Verify that your project name is correct and that the namespace is not restricted. Ensure that you have selected a workspace in your MLflow environment settings by using one of the following **methods: * The MLFLOW_TRACKING_AUTH=kubernetes-namespaced environment variable. * The MLFLOW_WORKSPACE=<workspace_name> environment variable. * The mlflow.set_workspace("team-a") Python function. **

Artifact override is not applied 

Problem 

with mlflow.start_run():     mlflow.log_param("framework", "pytorch")     mlflow.log_metric("accuracy", 0.95) 

**The MLflowConfig resource is missing, has the wrong name, or exists in the wrong project. **Alternatively, the associated secret does not exist. 

Resolution 

**Ensure that an MLflowConfig resource exists and is named mlflow. Verify that the mlflow-artifact-connection secret is present in the namespace. **

Kubernetes-namespaced authentication plugin cannot resolve credentials 

Problem 

The authentication plugin is missing a service account token (when running in-cluster) or an **active kubeconfig context (when running locally). **

Resolution 

If running in-cluster, ensure the service account has a valid token. If running locally, verify that **your kubeconfig context is active and points to the correct cluster and project by running oc project. **

Artifact writes go to the default storage location 

Problem 

**The MLflowConfig resource does not exist in the active project, or the artifactRootSecret is **invalid. 

Resolution 

**Create the MLflowConfig resource in your active project and verify that the artifactRootSecret **contains the correct connection credentials. 

JSON decode error: Expecting value 

Problem 

The Red Hat OpenShift AI authentication token is missing or invalid. Consequently, OpenShift AI receives an HTML response from MLflow instead of the expected JSON, causing OpenShift AI to prompt for a login. 

Resolution 

**Log in to the OpenShift cluster by running the oc login command. Ensure that your environment uses the MLFLOW_TRACKING_AUTH=kubernetes-namespaced environment variable to **authenticate requests. 

3.5. MLFLOW VERSION COMPATIBILITY 

The following information describes the compatible versions of MLflow and Red Hat OpenShift AI. 

Table 3.1. MLflow version compatibility and configuration 

Item Description 

Deployed MLflow server version **3.13.0 **

Required MLflow SDK version 3.11 or later 

Authentication plugin name **kubernetes-namespaced **

Environment variable **MLFLOW_TRACKING_AUTH=kubernetesnamespaced **

Item Description 

The following command installs the compatible version of the MLflow SDK: 

NOTE 

**MLflow SDK version 3.11 and later includes the kubernetes-namespaced authentication **plugin by default. 

3.6. MLFLOW STORAGE AND DATABASE COMPATIBILITY 

The following table lists the MLflow storage and database configurations. The configuration settings vary according to your environment, for example production, development, or testing. 

Table 3.2. Supported storage and database options 

Storage area Supported options 

Artifact storage S3 compatible object storage for production. File system for development and testing. 

Database PostgreSQL for production. SQLite for development and testing. 

Artifact repository plugins S3 and file. 

3.7. TRACK EXPERIMENTS WITH MLFLOW SDK 

Use the MLflow software development kit (SDK) to log and track machine learning experiments. With the SDK, you can record parameters, metrics, and artifacts to a centralized tracking server for later analysis. 

Prerequisites 

You have installed the MLflow SDK version 3.11 or later. 

You have access to a Red Hat OpenShift AI data science project that has MLflow permissions configured. 

You have configured a tracking URI and authentication. For more information, see MLflow Kubernetes Authentication. .Procedure 

1. In your notebook, log experiments, parameters, metrics, and artifacts by using the MLflow SDK: 

pip install "mlflow[kubernetes]>=3.11" 

When the kubernetes-namespaced authentication plugin is configured, the tracking URI and workspace are resolved automatically. 

2. Optional: To target a project other than the one associated with your credentials, set the workspace explicitly: 

Troubleshooting 

If you encounter errors when using the MLflow SDK to manage experiments or artifacts, see Troubleshooting MLflow SDK . 

3.8. CONFIGURE PROJECT-SPECIFIC S3 ARTIFACT STORAGE 

**By default, all projects use the artifact storage configured in the MLflow resource. You can override the artifact storage for a specific project by creating an MLflowConfig resource and a connection in that **project. After you create these resources, MLflow resolves the artifact root from the override for any new experiments and runs that you create in that project. However, MLflow does not serve artifacts when you configure a per-project override. The client accesses the S3 bucket directly, so the client must have valid S3 credentials. 

**The MLflowConfig resource is namespace-scoped and must be named mlflow. It points to an S3 **compatible object storage connection that holds the credentials and bucket information for the project. 

Prerequisites 

You have installed MLflow. 

You have an S3-compatible object storage bucket with credentials. 

Procedure 

1. In your project, add a connection of type S3 compatible object storage. Set the resource name **of the connection to mlflow-artifact-connection. Provide the following connection details: **

Access key: The S3 access key ID. 

Secret key: The S3 secret access key. 

Endpoint: The S3 compatible endpoint URL. 

import random import time import mlflow 

mlflow.set_experiment("demo-experiment") 

with mlflow.start_run(run_name="demo-run"):     mlflow.log_param("model_type", "baseline")     mlflow.log_param("feature_count", 3)     for step in range(5):         mlflow.log_metric("accuracy", 0.8 + random.random() * 0.2, step=step)         mlflow.log_metric("loss", 0.5 - random.random() * 0.2, step=step)         time.sleep(0.2) 

mlflow.set_workspace("<project-name>") 

Region: The S3 region. Optional if your storage provider does not require it. 

Bucket: The S3 bucket name. 

**If you are using the connections API instead of the dashboard, create a Secret with the annotation opendatahub.io/connection-type-protocol: "s3" and name it mlflow-artifact-connection. Setting an AWS_DEFAULT_REGION is optional. The required keys are: **

**AWS_ACCESS_KEY_ID **

**AWS_SECRET_ACCESS_KEY **

**AWS_S3_BUCKET **

**AWS_S3_ENDPOINT **

**2. Create an MLflowConfig resource named mlflow in the same project: **

**artifactRootSecret must be mlflow-artifact-connection. The Custom Resource Definition **(CRD) enforces this validation. 

NOTE 

**artifactRootPath is an optional relative path that the system appends to the bucket root from the secret. For example, if the bucket is ds-team-bucket and artifactRootPath is mlflow-artifacts, the resolved artifact root becomes s3://ds-team-bucket/mlflow-artifacts. The path must be relative, must not use backslashes, and must not contain path traversal such as ... **

apiVersion: mlflow.kubeflow.org/v1 kind: MLflowConfig metadata:   name: mlflow spec:   artifactRootSecret: mlflow-artifact-connection   artifactRootPath: mlflow-artifacts 

### CHAPTER 4. TRACK EXPERIMENTS WITH MLFLOW IN WORKBENCHES

You can track machine learning experiments in workbench notebooks with the MLflow SDK. OpenShift AI provides automatic MLflow SDK configuration for workbenches, which removes the need to manually set tracking URIs, configure authentication, or manage RBAC permissions. 

To use MLflow experiment tracking, a cluster administrator must first enable the MLflow Operator component, and then a data scientist can enable and use the integration in individual workbenches. 

4.1. MLFLOW WORKBENCH INTEGRATION 

You can enable automatic MLflow SDK configuration in your workbenches by annotating notebook **resources with the opendatahub.io/mlflow-instance annotation. When this annotation is present, **OpenShift AI automatically injects MLflow environment variables and provisions the required RBAC permissions, so that you can track experiments without manual SDK configuration. 

The MLflow workbench integration removes the need to manually set tracking URIs, configure authentication tokens, or create Kubernetes RBAC resources. When an administrator enables the **MLflow Operator component in the DataScienceCluster and creates an MLflow custom resource (CR), **the platform handles the remaining configuration at the workbench level. 

4.1.1. How the integration works 

The integration uses two mechanisms in the notebook controller to configure MLflow access: 

Environment variable injection 

**When a workbench notebook resource has the opendatahub.io/mlflow-instance annotation, the **notebook controller’s mutating webhook injects three environment variables into the notebook container before the pod starts: 

**MLFLOW_TRACKING_URI: The URL of the MLflow tracking server, constructed from the **GatewayAPI hostname and the MLflow instance name. 

**MLFLOW_K8S_INTEGRATION: Set to true to enable Kubernetes service account token **authentication with the MLflow server. 

**MLFLOW_TRACKING_AUTH: Set to kubernetes-namespaced to configure namespace-**scoped authentication. 

These variables allow the MLflow Python SDK to connect to the tracking server without additional configuration in your notebook code. 

RBAC provisioning 

**The notebook controller’s reconciler creates a namespace-scoped RoleBinding resource named __<notebook_name>__-mlflow that grants the workbench service account the permissions defined in the mlflow-operator-mlflow-integration ClusterRole resource. The RoleBinding resource uses **a controller owner reference to the notebook resource, so it is automatically deleted when the notebook is deleted. 

4.1.2. Configuration methods 

You can enable MLflow integration for workbenches in two ways: 

Dashboard-managed 

If you use the OpenShift AI dashboard with the Dashboard, MLflow, and Workbenches components **set to Managed in the DataScienceCluster, the dashboard automatically adds the opendatahub.io/mlflow-instance annotation when you create or update a workbench. No manual **configuration is required. 

Manual 

If you manage workbenches through GitOps, Helm charts, or direct YAML manifests without the **OpenShift AI dashboard, you must manually add the opendatahub.io/mlflow-instance annotation **to the notebook resource. 

4.1.3. Annotation lifecycle 

**The opendatahub.io/mlflow-instance annotation controls the MLflow integration for each workbench: **

Adding the annotation 

You can add the annotation to a stopped notebook or include it when you create a new notebook. The annotation value must be the name of the MLflow instance CR. Environment variables are **injected on the next pod start, and the RoleBinding resource is created by the reconciler. **

Removing the annotation 

**You must stop the workbench before removing the annotation. The RoleBinding resource is **deleted immediately when the annotation is removed, but environment variables in the running pod persist until restart. This mismatch can cause authentication failures if the workbench continues to **send requests to the MLflow tracking server after the RoleBinding resource is removed. A validating webhook checks that the kubeflow-resource-stopped annotation is present on the **notebook resource before it allows removal of the MLflow annotation. The webhook validates the annotation state, not the actual pod state. If you try to remove the annotation without first stopping the workbench through the dashboard or by setting the stop annotation, the API request is rejected with a webhook error. 

4.1.4. Non-blocking behavior 

MLflow integration failures do not block workbench admission. If the tracking URI cannot be determined, for example because the GatewayAPI hostname is not yet available, the webhook skips the **MLFLOW_TRACKING_URI injection but still allows the notebook to start. In this case, MLFLOW_K8S_INTEGRATION and MLFLOW_TRACKING_AUTH are still injected, which creates a **degraded state in which the MLflow SDK is configured for Kubernetes authentication but has no tracking **server to connect to. If MLflow operations such as mlflow.set_experiment() fail with a ConnectionError, verify that the MLFLOW_TRACKING_URI environment variable is set in your **workbench pod. 

**Similarly, if the mlflow-operator-mlflow-integration ClusterRole resource does not yet exist, the reconciler requeues the RoleBinding resource creation with a warning event every 30 seconds until the ClusterRole resource becomes available. **

4.1.5. Limitations 

Artifact-serving configuration with S3 connection types is not supported. You can log parameters, **metrics, and tags, but mlflow.log_artifact() functionality that relies on an S3-backed artifact store **requires additional configuration that is outside the scope of the automatic integration. 

4.2. ENABLE THE MLFLOW OPERATOR COMPONENT 

**You can enable the MLflow Operator as a managed component in the DataScienceCluster object so **that the MLflow tracking server and workbench integration are available on the platform. When the MLflow Operator component is enabled, workbench notebooks can use automatic MLflow SDK configuration. 

Prerequisites 

The Red Hat OpenShift AI Operator is installed on your OpenShift cluster. 

**A DataScienceCluster object exists. **

You have cluster administrator privileges. 

**You have installed the OpenShift CLI (oc). **

Procedure 

1. Log in to your OpenShift cluster as a cluster administrator: 

**2. Identify the name of the DataScienceCluster object: **

**3. Edit the DataScienceCluster object to enable the MLflow Operator component: **

**4. In the spec.components section, add or update the mlflowoperator field and set managementState to Managed: **

NOTE 

**The default managementState for the mlflowoperator component is Removed. You must explicitly set it to Managed to enable MLflow on the platform. **

5. Save and close the editor. **When you set mlflowoperator to Managed, the Red Hat OpenShift AI Operator automatically configures the notebook controller with MLFLOW_ENABLED=true and sets the appropriate GATEWAY_URL for the cluster. **

6. Create an MLflow CR to deploy a tracking server instance. The MLflow CR structure and namespace requirements depend on the MLflow Operator version. For more information, consult the MLflow Operator documentation for the CR specification. 

$ oc login --token=__<token>__ --server=__<openshift_cluster_url>__ 

$ oc get datasciencecluster 

$ oc edit datasciencecluster __<dsc_name>__ 

spec:   components: *    # ... *    mlflowoperator:       managementState: Managed *    # ... *

Verification 

1. Confirm that the MLflow Operator pod is running: 

**The output shows one or more MLflow Operator pods in Running status. If the command returns no results, verify that the mlflowoperator component managementState is set to Managed and wait for the Operator pods to start. **

**2. Confirm that the mlflowoperator component status is true in the DataScienceCluster object: **

**The expected output is true. **

4.2.1. MLflow dashboard feature flag deprecation 

**Starting with Red Hat OpenShift AI 3.4, the mlflow field in the OdhDashboardConfig custom resource (CR) is deprecated. MLflow availability in the dashboard is now determined by the mlflowoperator component state in the DataScienceCluster object, and the dashboard feature flag is no longer **required. 

4.2.1.1. Deprecated field 

**The mlflow field in spec.dashboardConfig of the OdhDashboardConfig CR is deprecated and no **longer controls MLflow visibility in the dashboard. You do not need to set this field to enable MLflow. The field has no effect on MLflow functionality. 

4.2.1.2. Current behavior 

**MLflow features in the OpenShift AI dashboard are automatically available when the mlflowoperator component is set to Managed in the DataScienceCluster object. No additional dashboard **configuration is required. 

**4.2.1.3. mlflowPipelines field **

**The mlflowPipelines field in the OdhDashboardConfig CR is not deprecated and remains active. This **field controls whether pipeline run tables display the MLflow experiment column. Do not confuse the **deprecated mlflow field with the active mlflowPipelines field. **

Table 4.1. Dashboard feature flag status 

Field Status Description 

**spec.dashboardConfig.mlflo w **

Deprecated In earlier releases, this field controlled MLflow visibility in the dashboard. No longer required; MLflow is enabled automatically by the **mlflowoperator component. **

$ oc get pods -n redhat-ods-applications -l app=mlflow-operator --field-selector status.phase=Running 

$ oc get datasciencecluster __<dsc_name>__ -o jsonpath='{.status.installedComponents.mlflowoperator}' 

**spec.dashboardConfig.mlflo wPipelines **

Active Controls whether the MLflow experiment column is displayed in pipeline run tables. 

Field Status Description 

4.3. ENABLE MLFLOW INTEGRATION FOR A WORKBENCH 

You can enable automatic MLflow SDK configuration for a workbench by adding the **opendatahub.io/mlflow-instance annotation to the notebook resource. When the workbench starts, **the platform injects MLflow environment variables and provisions the required RBAC resources. 

When you create or update a workbench, the OpenShift AI dashboard automatically adds the MLflow **annotation. For this to occur, the following components in the DataScienceCluster object must be set to Managed: **

Dashboard 

MLflow 

Workbenches 

The following procedure is for environments where you manage workbenches through GitOps, Helm charts, or direct YAML manifests without the OpenShift AI dashboard. 

Prerequisites 

A cluster administrator has enabled the MLflow Operator component in the **DataScienceCluster object. For more information, see Enable the MLflow Operator **component. 

An MLflow CR has been created in the same namespace as the workbench. 

The workbench is stopped. 

**You have installed the OpenShift CLI (oc). **

Procedure 

1. Log in to your OpenShift cluster: 

**2. Add the opendatahub.io/mlflow-instance annotation to the notebook resource. In the following command, replace __<notebook_name>__ with the name of your workbench notebook and __<mlflow_instance_name>__ with the name of your MLflow instance CR: **

**If the MLflow instance name is mlflow, the tracking URI path is /mlflow. If the instance name is different, the path is /mlflow-__<mlflow_instance_name>__. **

$ oc login --token=__<token>__ --server=__<openshift_cluster_url>__ 

$ oc annotate notebook -n __<namespace>__ __<notebook_name>__ opendatahub.io/mlflow-instance=__<mlflow_instance_name>__ 

Alternatively, you can add the annotation directly in the notebook resource YAML: 

3. Start or restart the workbench so that the environment variables are injected into the new pod. 

Verification 

1. Verify that the MLflow environment variables are present in the running workbench pod. First, find the pod name for your notebook: 

Then verify that the MLflow environment variables are present, where **__<notebook_pod_name>__ is the pod name from the previous command and __<notebook_name>__ is the notebook resource name: **

The expected output shows the following environment variables: 

**The <gateway_hostname> value is cluster-specific and matches the GatewayAPI public **endpoint for your cluster. 

**2. Verify that the MLflow RoleBinding resource exists in the namespace: **

**The output shows a RoleBinding resource referencing the mlflow-operator-mlflow-integration ClusterRole resource. **

4.4. USE THE MLFLOW SDK IN A WORKBENCH NOTEBOOK 

After MLflow integration is enabled for your workbench, you can use the MLflow Python SDK to create experiments, log parameters and metrics, and track runs. The required environment variables are already configured, so the SDK connects to the tracking server automatically. 

Prerequisites 

apiVersion: kubeflow.org/v1 kind: Notebook metadata:   name: __<notebook_name>__   namespace: __<namespace>__   annotations:     opendatahub.io/mlflow-instance: "__<mlflow_instance_name>__" spec: *  # ... *

$ oc get pods -n __<namespace>__ -l notebook-name=__<notebook_name>__ 

$ oc exec -n __<namespace>__ __<notebook_pod_name>__ -c __<notebook_name>__ -- env | grep MLFLOW 

MLFLOW_TRACKING_URI=https://<gateway_hostname>/mlflow MLFLOW_K8S_INTEGRATION=true MLFLOW_TRACKING_AUTH=kubernetes-namespaced 

$ oc get rolebinding -n __<namespace>__ __<notebook_name>__-mlflow 

A cluster administrator has enabled the MLflow Operator component in the **DataScienceCluster custom resource (CR). For more information, see Enable the MLflow **Operator component. 

An MLflow CR has been created in the namespace. 

**The workbench notebook resource has the opendatahub.io/mlflow-instance annotation. For **more information, see Enable MLflow integration for a workbench . 

The workbench is started and the MLflow environment variables are injected. 

**The mlflow Python package is installed in the workbench. Starting with OpenShift AI 3.4, all **workbench images except the minimal image include the MLflow SDK. For older images or **custom images, install the package by running pip install mlflow in a notebook cell. **

NOTE 

**If you need only basic tracking functionality, you can install the mlflow-skinny package instead for a smaller footprint. The mlflow-skinny package contains the **core tracking and logging features but does not include model serving integrations or the full MLflow CLI. 

Procedure 

1. Open a notebook in the workbench. 

2. Verify that the MLflow environment variables are available: 

All three variables display their configured values. 

3. Import the MLflow SDK and set an experiment: 

**The set_experiment() call returns an Experiment object and prints the experiment ID. If you see a ConnectionError, verify that the MLFLOW_TRACKING_URI environment variable is set **correctly by re-running the check in step 2. 

4. Start a run and log parameters and metrics: 

import os print(os.environ.get("MLFLOW_TRACKING_URI")) print(os.environ.get("MLFLOW_K8S_INTEGRATION")) print(os.environ.get("MLFLOW_TRACKING_AUTH")) 

import mlflow 

mlflow.set_experiment("my-experiment") 

with mlflow.start_run():     mlflow.log_param("learning_rate", 0.01)     mlflow.log_param("epochs", 10)     mlflow.log_metric("accuracy", 0.95)     mlflow.log_metric("loss", 0.05) 

**You can log any number of parameters, metrics, and tags within a run. If start_run() raises a ConnectionError or an authentication or authorization error, verify that the MLflow tracking server is running and that the workbench RoleBinding resource exists. **

5. View the experiment results in the MLflow UI, which is accessible from the OpenShift AI dashboard. 

Verification 

Confirm that the experiment and run are displayed in the MLflow UI. Navigate to the MLflow tracking server URL in your browser or through the OpenShift AI dashboard and verify that the logged parameters and metrics are visible. 

NOTE 

Artifact-serving configuration with S3 connection types is not supported. You can log **parameters, metrics, and tags, but mlflow.log_artifact() functionality that relies on an **S3-backed artifact store requires additional configuration. For more information, see MLflow workbench integration . 

4.5. DISABLE MLFLOW INTEGRATION FOR A WORKBENCH 

**You can disable MLflow integration for a workbench by removing the opendatahub.io/mlflow-instance **annotation from the notebook resource. You must stop the workbench before removing the annotation. 

IMPORTANT 

**When you remove the annotation, the platform deletes the associated RoleBinding **resource immediately, but environment variables in the running pod persist until the pod restarts. If the workbench is running when you remove the annotation, the MLflow SDK **continues to send requests to the tracking server without a valid RoleBinding resource in **place, which causes authentication failures. 

Prerequisites 

**Your workbench has the opendatahub.io/mlflow-instance annotation. **

**The workbench is stopped. The validating webhook requires the kubeflow-resource-stopped **annotation to be present on the notebook resource before it allows removal of the MLflow annotation. 

**You have installed the OpenShift CLI (oc). **

Procedure 

1. Log in to your OpenShift cluster: 

2. Verify that the workbench pod has stopped: 

$ oc login --token=__<token>__ --server=__<openshift_cluster_url>__ 

$ oc get pods -n __<namespace>__ -l notebook-name=__<notebook_name>__ 

The command produces no output when the pod has stopped. 

**3. Remove the opendatahub.io/mlflow-instance annotation from the notebook resource. In the following command, replace __<notebook_name>__ with the name of your workbench **notebook: 

**The trailing dash (-) removes the annotation. **

Verification 

1. Start the workbench and verify that the MLflow environment variables are no longer present. First, find the pod name for your notebook: 

Then verify that the MLflow environment variables are no longer present, where **__<notebook_pod_name>__ is the pod name from the previous command and __<notebook_name>__ is the notebook resource name: **

The command produces no output, confirming that the MLflow variables have been removed. 

**2. Verify that the MLflow RoleBinding resource has been removed: **

The expected output is: 

Troubleshooting 

If the annotation removal is rejected with a webhook error, see Resolve MLflow annotation removal rejection. 

4.6. RESOLVE MLFLOW ANNOTATION REMOVAL REJECTION 

**If you try to remove the opendatahub.io/mlflow-instance annotation from a running workbench, the **API request is rejected by a validating webhook. You can resolve this issue by stopping the workbench before removing the annotation. 

**The validating webhook checks that the kubeflow-resource-stopped annotation is present on the **notebook resource before it allows removal of the MLflow annotation. The webhook validates the annotation state, not the actual pod state. If the pod was stopped without setting the stop annotation, for example by deleting the pod directly, the webhook still rejects the annotation removal. 

Prerequisites 

$ oc annotate notebook -n __<namespace>__ __<notebook_name>__ opendatahub.io/mlflow-instance-

$ oc get pods -n __<namespace>__ -l notebook-name=__<notebook_name>__ 

$ oc exec -n __<namespace>__ __<notebook_pod_name>__ -c __<notebook_name>__ -- env | grep MLFLOW 

$ oc get rolebinding -n __<namespace>__ __<notebook_name>__-mlflow 

Error from server (NotFound): rolebindings.rbac.authorization.k8s.io "__<notebook_name>__-mlflow" not found 

**The workbench has the opendatahub.io/mlflow-instance annotation. **

You received a webhook error when trying to remove the annotation. 

**You have installed the OpenShift CLI (oc). **

Procedure 

1. Stop the workbench. You can stop the workbench from the OpenShift AI dashboard or by applying the stop annotation: 

**The value of the kubeflow-resource-stopped annotation is not significant for this purpose. The **validating webhook checks only for the presence of the annotation key. 

2. Wait for the notebook pod to stop fully: 

The command produces no output when the pod has stopped. 

3. Remove the MLflow annotation: 

Verification 

Confirm that the annotation has been removed: 

The command produces no output, confirming the annotation is removed. 

4.7. MLFLOW WORKBENCH ENVIRONMENT VARIABLES AND ANNOTATIONS 

When MLflow integration is enabled for a workbench, the notebook controller injects environment variables and creates RBAC resources automatically. You can use this reference to understand the **annotation, environment variables, and RoleBinding resource that the platform manages on your **behalf. 

4.7.1. Annotation 

Table 4.2. MLflow instance annotation 

$ oc annotate notebook -n __<namespace>__ __<notebook_name>__ kubeflow-resource-stopped=true 

$ oc get pods -n __<namespace>__ -l notebook-name=__<notebook_name>__ 

$ oc annotate notebook -n __<namespace>__ __<notebook_name>__ opendatahub.io/mlflow-instance-

$ oc get notebook -n __<namespace>__ __<notebook_name>__ -o jsonpath='{.metadata.annotations.opendatahub\.io/mlflow-instance}' 

Annotation Description 

**opendatahub.io/mlfl ow-instance **

Specifies the name of the MLflow instance CR to connect to. When this annotation is present and non-empty on a notebook resource, the notebook controller enables MLflow integration for the workbench. The annotation value determines the path segment in the tracking URI. 

Table 4.3. Annotation value to tracking URI path mapping 

Annotation value Tracking URI path 

**mlflow /mlflow **

**__<custom_instance_name>__ /mlflow-__<custom_instance_name>__ **

4.7.2. Environment variables 

The following environment variables are injected into the notebook container when the **opendatahub.io/mlflow-instance annotation is present. **

Table 4.4. MLflow environment variables 

Variable Value Description 

**MLFLOW_TRACKING_U RI **

**\https://__<gateway_hos tname>__/mlflow or \https://__<gateway_hos tname>__/mlflow-__<instance_name>__ **

Specifies the URL of the MLflow tracking server. The hostname is derived from the GatewayAPI public endpoint. If the instance **name is mlflow, the path is /mlflow. If the instance name differs from mlflow, the path is /mlflow-__<instance_name>__. **

**MLFLOW_K8S_INTEGR ATION **

**true **Specifies that the MLflow client uses Kubernetes service account token authentication. 

**MLFLOW_TRACKING_A UTH **

**kubernetes-namespaced **Specifies the authentication method for the MLflow client. This value configures namespace-scoped authentication using the workbench service account. 

4.7.3. RoleBinding 

**The notebook controller creates a namespace-scoped RoleBinding resource for each annotated **workbench. 

Table 4.5. MLflow RoleBinding details 

Property Value 

Name **__<notebook_name>__-mlflow **

Namespace Same as the notebook resource namespace 

Subject **ServiceAccount with the name of the notebook, in the notebook namespace **

RoleRef **ClusterRole named mlflow-operator-mlflow-integration **

Controller owner reference 

**Set to the notebook resource, so the RoleBinding is automatically deleted **when the notebook is deleted 

Labels **notebook-name: __<notebook_name>__ **

4.7.4. ClusterRole availability 

**The RoleBinding resource references the mlflow-operator-mlflow-integration ClusterRole resource, which is created by the MLflow Operator. If this ClusterRole resource does not yet exist when the reconciler attempts to create the RoleBinding resource, the reconciler requeues the request with a warning event every 30 seconds until the ClusterRole resource becomes available. These events are generated only when a notebook resource has the opendatahub.io/mlflow-instance annotation, but the ClusterRole resource does not yet exist. If no annotated notebooks exist, no events are generated. You can observe these events by running the following command, where __<namespace>__ is the **namespace containing your workbench notebook: 

4.7.5. Controller environment variables 

The Red Hat OpenShift AI Operator automatically configures the following environment variables on **the notebook controller when the mlflowoperator component is set to Managed in the DataScienceCluster object. You do not need to set these variables manually. **

Table 4.6. Controller environment variables 

Variable Description 

**MLFLOW_ENABLED Set to true when the mlflowoperator component is Managed in the DataScienceCluster object. Enables the **notebook controller to process MLflow annotations on workbench resources. 

**GATEWAY_URL **Set based on the cluster’s Gateway configuration. The notebook controller uses this value to construct the **MLFLOW_TRACKING_URI for workbench pods. **

$ oc get events -n __<namespace>__ --field-selector reason=MLflowClusterRolePending 

### CHAPTER 5. TRACK AND COMPARE MLFLOW EXPERIMENTS

When you train or tune models, you need to understand what combination of parameters, data, and code produces the best results. You can use the embedded MLflow experiment tracking page in the OpenShift AI dashboard to view, compare, and analyze your experiment runs without leaving the dashboard. 

The experiment tracking page is displayed under Develop & train > Experiments (MLflow) after you **enable the MLflow Operator component in the DataScienceCluster resource and create an MLflow **custom resource. The page displays the same experiment and run data as the standalone MLflow UI, integrated directly into the dashboard with native light and dark mode support. 

Experiments organize your runs into logical groups. Each run captures the parameters, metrics, and artifacts from a single training or evaluation execution. You can log runs to MLflow from a workbench by using the MLflow SDK, which is pre-installed in the Data Science workbench image. 

From the experiment tracking page, you can perform the following tasks: 

Browse experiments and runs 

View all experiments in your project and drill into individual experiments to see their associated runs. Each run displays its logged parameters, metrics, and system-level resource usage. 

Compare runs 

Select multiple runs from one or more experiments and compare them side by side. The comparison view provides visualizations such as parallel coordinates plots, scatter plots, box plots, and contour plots with configurable axes. You can toggle Show differences only to focus on the parameters and metrics that vary across runs. 

Create experiments 

Create new experiments to organize runs for a specific model, data set, or tuning strategy. Experiment names must be unique within the project. Within an experiment, a workflow type toggle controls which tabs are visible. Select GenAI to see Overview, Traces, and Sessions tabs, or select Model training to see Runs, Models, and Traces tabs. 

NOTE 

You can log metrics and create runs through the MLflow SDK in a workbench, or automatically through pipeline runs when you enable MLflow integration for your pipeline server. The dashboard provides a read-only and comparison view of the run data. 

Additional resources 

Installing and configuring MLflow 

Track pipeline experiments with MLflow 

5.1. VIEW MLFLOW EXPERIMENTS AND RUNS 

After you log training or evaluation runs by using the MLflow SDK, you can view experiment results and run details in the OpenShift AI dashboard. The Experiments page displays all experiments in your project and lets you drill into individual runs. 

Prerequisites 

**The MLflow Operator component is enabled in the DataScienceCluster resource. **

**An MLflow custom resource has been created. **

You have logged one or more runs to an MLflow experiment from a workbench. 

Procedure 

1. From the OpenShift AI dashboard, select the project that contains the MLflow experiments from the Project list. 

2. Click Develop & train → Experiments (MLflow). The Experiments list displays all MLflow experiments in your project. 

3. Click an experiment name to view its associated runs. The Runs table displays each run with its parameters, metrics, and status. 

4. Click a run name to view its details. The details page displays the following information: 

Parameters 

The hyperparameters and configuration values that you logged for the run. 

Metrics 

The performance metrics that you logged during the run, displayed as interactive charts that you can zoom and pan. 

System metrics 

Resource usage data such as CPU and memory consumption during the run. 

5. Optional: To create a new experiment, click Create. 

a. Enter a unique name for the experiment. 

b. Click Create. 

Verification 

The Experiments list displays your experiments and the Runs table shows the expected number of runs. 

The details page displays the parameters and metrics that you logged by using the MLflow SDK. 

5.2. COMPARE MLFLOW RUNS 

When you have several runs across one or more experiments, you can compare them side by side to identify which parameters and metrics differ. This helps you select the best-performing configuration. 

Prerequisites 

**The MLflow Operator component is enabled in the DataScienceCluster resource. **

**An MLflow custom resource has been created. **

You have logged two or more runs to MLflow experiments from a workbench. 

Procedure 

1. From the OpenShift AI dashboard, select the project that contains the MLflow experiments from the Project list. 

2. Click Develop & train → Experiments (MLflow). 

3. Click an experiment name to view its runs. 

4. Select the checkbox next to each run that you want to compare. 

5. Click Compare. The comparison view displays the selected runs with their parameters and metrics in a tabular layout. 

6. Optional: To focus on values that vary between runs, select Show differences only. 

7. Optional: To visualize the comparison, select a chart type from the visualization panel. The following chart types are available: 

Parallel coordinates plot 

Displays all selected runs as lines across parallel axes, one for each metric or parameter. Use this view to identify patterns and tradeoffs across many dimensions at once. 

Scatter plot 

Plots two metrics or parameters against each other across the selected runs. Use the X axis and Y axis dropdowns to select the axes. 

Box plot 

Displays the distribution of a metric across the selected runs. 

Contour plot 

Displays the density of data points across two parameters or metrics as a contour map. Use the X axis, Y axis, and Z axis dropdowns to configure the axes. 

8. Optional: To compare runs across different experiments, return to the Experiments list. 

a. Select runs from another experiment. 

b. Add the selected runs to the comparison. 

Verification 

The comparison view displays all selected runs with their parameters and metrics. 

Chart visualizations reflect the selected axes and chart type. 

### CHAPTER 6. TRACE ARCHIVAL FOR MLFLOW

As your MLflow deployment grows, trace span payloads can consume significant storage in the tracking database. Trace archival moves older span payloads from the SQL tracking store to S3-compatible artifact storage, reducing database size while preserving trace access for debugging, auditing, and **evaluation. A file:// archive location is also supported when spec.storage uses shared ReadWriteMany (RWX) storage. **

Trace archival is built on three architectural layers: 

Archival Engine 

A background process that migrates trace span payloads from PostgreSQL to S3-compatible **artifact storage. On Red Hat OpenShift AI, this runs as a Kubernetes CronJob. **

Metadata Preservation 

Trace metadata, including timestamps, trace IDs, tags, status, and column-based span attributes, remains in the PostgreSQL tracking database after archival. 

Transparent Retrieval 

Archived traces are fetched from S3 on-demand and displayed identically to active traces. No special tools or API changes are required to view archived trace data. 

MLflow tracks the location of span payloads through trace tags: 

**mlflow.trace.spansLocation **

**Indicates where span payloads are stored. When unset or set to TRACKING_STORE, span payloads are in the SQL tracking database. When set to ARCHIVE_REPO, span payloads are archived to **object storage. 

**mlflow.trace.archiveLocation **

After archival, this tag contains the artifact URI where the span payloads are stored. 

**mlflow.trace.archivalFailure **

Set on traces with malformed data that the archival engine cannot process. The engine skips traces with this tag on subsequent passes. 

**Archived span payloads are stored as OpenTelemetry Protocol (OTLP) TracesData protobuf files in object storage at {archive_location}/{experiment_id}/traces/{trace_id}/artifacts/traces.pb. **

During archival, the engine uploads span payloads to object storage, then finalizes the operation by clearing the SQL span content and updating the trace tags. If the upload fails, the trace remains database-backed and retries on the next scheduler pass. Metadata-based and tag-based search filters **continue to work after archival, but filters that depend on span payloads, such as trace.text and span.content, no longer match archived traces. **

**On Red Hat OpenShift AI, trace archival runs as a Kubernetes CronJob managed by the MLflow Operator. The CronJob runs as a single instance with concurrencyPolicy: Forbid, which prevents **overlapping archival runs. The MLflow server receives the archival configuration so that the dashboard can display the archival state of traces. 

NOTE 

The archival engine runs as a single replica per namespace. 

**Retention policies control how long traces remain in the tracking database before the archival CronJob **moves them to artifact storage. You can configure retention at two levels: 

Server 

**Set through the spec.traceArchival.retention field in the MLflow custom resource (CR). This value **applies to all experiments unless overridden. 

Experiment 

Set through the MLflow CLI, Python API, or the OpenShift AI dashboard. An experiment retention that is shorter than the server policy takes effect automatically. An experiment retention that is longer than the server policy takes effect only if the experiment ID is listed in the **longRetentionAllowlist field of the MLflow CR. **

IMPORTANT 

**Trace archival is disabled by default and must be explicitly enabled through the MLflow **CR. When enabled, archival moves span payloads to artifact storage but never deletes trace metadata from the database. Payloads are moved, not copied then deleted: the S3 upload is confirmed before the database record is updated. However, archival cannot be undone. After a trace is archived, its span payloads are served from artifact storage and cannot be moved back to the tracking database. You can still view and retrieve archived traces through the dashboard and the MLflow API, but retrieval latency increases because span data is read from object storage. 

The following limitations apply to trace archival: 

Trace archival applies only to trace span payloads. Experiment runs, model versions, registered models, and other MLflow data types are not archived. 

**To permanently remove archived traces, use the delete_traces API. This removes the tracking database rows and deletes the archived traces.pb span payloads from object storage. **

**Archival runs on a scheduled batch basis through the CronJob. Real-time or streaming archival **is not supported. 

Archived traces cannot be restored to the active tracking database. Once a trace is archived, its span payloads remain in artifact storage permanently. 

**A file:// archive location is supported only when spec.storage uses shared ReadWriteMany (RWX) storage. Persistent volume claims that do not provide RWX storage are not supported. **

Additional resources 

Configure trace archival 

Configure trace archival retention for experiments 

Archived trace search and retrieval behavior 

MLflow trace archival documentation 

6.1. CONFIGURE TRACE ARCHIVAL 

**You can enable trace archival for your MLflow deployment by adding the traceArchival section to the MLflow custom resource (CR). When enabled, the MLflow Operator creates a Kubernetes CronJob **

that periodically moves older trace span payloads from the SQL tracking store to S3-compatible artifact storage. 

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

You have installed and configured MLflow on Red Hat OpenShift AI. 

The MLflow deployment can write to the URI that you plan to set in **spec.traceArchival.location. For S3-compatible URIs, the archival CronJob inherits the credential environment from the MLflow CR spec.env and spec.envFrom fields. For file:// URIs, spec.storage must use shared ReadWriteMany (RWX) storage. **

Procedure 

**1. Update the MLflow CR to enable trace archival: **

**Example MLflow CR with trace archival enabled **

where: 

**enabled: true **

**Enables trace archival. The default value is false. When set to true, the MLflow Operator creates a CronJob that runs the archival process on the configured schedule. **

**<cron_schedule> **

**Specifies the cron expression that controls how often the archival CronJob runs. The default value is 0 */6 * * *, which runs every 6 hours. **

**<archive_storage_uri> **

Specifies the S3-compatible URI where archived trace span payloads are stored, for example **s3://mlflow-trace-archive. A file:// archive location is supported only when spec.storage uses shared ReadWriteMany (RWX) storage. Persistent volume claims that do not provide **RWX storage are not supported. This field is required when trace archival is enabled. 

**<retention_period> **

Specifies the age threshold after which traces are eligible for archival. The value must use 

apiVersion: mlflow.opendatahub.io/v1 kind: MLflow metadata:   name: mlflow spec:   backendStoreUriFrom:     name: mlflow-db-credentials     key: backend-store-uri   serveArtifacts: true   artifactsDestination: "s3://mlflow-artifacts"   traceArchival:     enabled: true     schedule: "<cron_schedule>"     location: "<archive_storage_uri>"     retention: "<retention_period>"     maxTracesPerPass: <max_traces> 

**the format <number><unit>, where the unit is m for minutes, h for hours, or d for days. For example, 30d archives traces older than 30 days. This field is required when trace archival is **enabled. 

**<max_traces> **

**Specifies the maximum number of traces to archive in a single CronJob run. The default value is 1000. The minimum value is 1. **

**2. Apply the updated MLflow CR: **

3. Optional: To allow specific experiments to use a longer retention period than the server default, **add experiment IDs to the longRetentionAllowlist field: **

where: 

**<experiment_id_1>, <experiment_id_2> **

Specifies the IDs of experiments that are permitted to set a retention period longer than the server default. You can list up to 64 experiment IDs. 

**4. Optional: To configure compute resources for the archival CronJob, add the resources field: **

Verification 

**Confirm that the archival CronJob was created: **

**The output lists a CronJob with the schedule that you configured. **

**Verify that the MLflow CR shows the expected trace archival configuration: **

$ oc apply -f mlflow.yaml 

spec:   traceArchival:     enabled: true     schedule: "0 */6 * * *"     location: "s3://mlflow-trace-archive"     retention: "30d"     longRetentionAllowlist:       - "<experiment_id_1>"       - "<experiment_id_2>" 

spec:   traceArchival:     resources:       requests:         cpu: "500m"         memory: "512Mi"       limits:         cpu: "1"         memory: "1Gi" 

$ oc get cronjob -n <mlflow_namespace> 

$ oc describe mlflow mlflow -n <mlflow_namespace> 

**If oc apply completes without error but no CronJob is displayed, confirm that the traceArchival field was accepted by running: **

If this returns empty, the MLflow Operator version does not support trace archival. 

Additional resources 

Trace archival for MLflow 

MLflow and MLflowConfig configuration parameters 

Configure trace archival retention for experiments 

6.2. CONFIGURE TRACE ARCHIVAL RETENTION FOR EXPERIMENTS 

After you enable trace archival at the server level, you can override the default retention period for individual experiments. A shorter experiment retention takes effect automatically. A longer experiment **retention takes effect only if the experiment ID is listed in the longRetentionAllowlist field of the MLflow custom resource (CR). **

Prerequisites 

**You have enabled trace archival in the MLflow CR. For more information, see Configure trace **archival. 

You have Edit or Admin access to the Data Science project. 

NOTE 

You can configure experiment-level retention through the OpenShift AI dashboard or the MLflow CLI. For CLI commands, see Set experiment-level retention in the MLflow documentation. 

Procedure 

1. From the OpenShift AI dashboard, navigate to the experiment. 

2. Click the three-dot menu and select Edit Experiment. 

**3. In the Trace archival retention field, enter the retention period, for example 7d. **To inherit the server default, leave the field blank. 

**To mark a specific experiment for archival on the next CronJob scheduler pass, use the --trace-archive-now flag with the MLflow CLI. For CLI syntax, see Trigger archival immediately in the **MLflow documentation. 

NOTE 

**The --trace-archive-now flag marks the experiment for archival on the next CronJob scheduler pass. It does not run archival immediately from the client. **

*$ oc get mlflow mlflow -n <mlflow_namespace> -o jsonpath={.spec.traceArchival} *

4. Click Save. 

Verification 

In the OpenShift AI dashboard, navigate to the experiment and confirm that the Archive after badge displays the expected retention period. 

Verify the effective retention for an experiment by checking the experiment details in the MLflow UI or by using the MLflow Python API to retrieve the experiment metadata. 

Additional resources 

Trace archival for MLflow 

Configure trace archival 

MLflow trace archival documentation 

6.3. ARCHIVED TRACE SEARCH AND RETRIEVAL BEHAVIOR 

After traces are archived, their span payloads are stored in S3-compatible artifact storage instead of the SQL tracking database. Trace metadata, tags, and column-based span attributes remain in the database. This tiered storage model affects which search filters work and how traces are retrieved. 

6.3.1. Search filter behavior 

Table 6.1. Search filters for archived traces 

Filter type Works after archival 

Details 

Metadata-based filters: timestamp, state, tags, trace attributes 

Yes Trace metadata remains in the tracking database after archival. 

Column-based span filters: **span.name, span.type, span.status **

Yes These span attributes are stored as dedicated database columns and are retained after archival. 

JSON-based span filters: **span.attributes.*, span.content **

No **These filters depend on the spans.content column, **which is cleared when the span payload moves to artifact storage. 

**trace.text **No This filter searches span payloads, which are no longer in the tracking database after archival. 

6.3.2. Trace retrieval 

Archived traces remain accessible through the OpenShift AI dashboard and the MLflow API. When you open an archived trace, MLflow reads the span payloads from artifact storage transparently. The dashboard displays a loading state while the span payload is retrieved from artifact storage. The retrieval 

process is the same as for active traces, but latency increases because span data is read from object storage instead of the database. 

The trace detail endpoint returns the complete payload regardless of whether a trace is active or archived. For details about the trace search and retrieval API endpoints, see the MLflow REST API reference. 

You cannot append new spans to an archived trace. If an application attempts to write spans to an archived trace, MLflow returns a write-conflict error. 

Additional resources 

Trace archival for MLflow 

Configure trace archival 

MLflow REST API reference 

MLflow trace archival documentation 

6.4. TRACE ARCHIVAL TROUBLESHOOTING 

Diagnose and resolve common trace archival problems. 

Traces are not archiving on schedule 

Problem **The archival CronJob does not exist or the MLflow custom resource (CR) is misconfigured. **

Resolution 

**Verify that the archival CronJob exists by running oc get cronjob -n <mlflow_namespace>. Confirm that the MLflow CR has traceArchival.enabled set to true and that you have configured the schedule, location, and retention fields. **

**A trace has the mlflow.trace.archivalFailure tag **

Problem The trace has malformed data that prevents archival. The archival scheduler skips traces with this tag on later passes. 

Resolution 

Fix the underlying trace data, then clear the failure tag by using the **mlflow.client.MlflowClient.delete_trace_tag() method. The archival scheduler retries the trace on **the next pass after you remove the tag. 

Search results do not include expected traces 

Problem **You are using trace.text, span.content, or span.attributes.* filters, which do not match archived **traces because these filters depend on span payloads that have been moved to artifact storage. 

Resolution 

Use metadata-based or tag-based filters instead. For more information about which filters work after archival, see Archived trace search and retrieval behavior . 

**An archive-now request has no visible effect **

Problem **The --trace-archive-now flag marks the experiment for archival on the next scheduler pass. It does **not run archival immediately from the client. 

Resolution 

**Wait for the next scheduled CronJob run. If the request is still pending after the next run, check for **traces eligible for retry or malformed traces that the scheduler cannot process. The request clears after the scheduler archives all matching traces or only terminal failures remain. 

**The archival CronJob completes but no traces move to archived status **

Problem The retention period has not elapsed for any traces, or the S3 storage connection is failing silently. 

Resolution 

Verify that traces older than the configured retention period exist in the tracking database. Check **the CronJob pod logs for S3 connection errors by running oc logs job/<cronjob_pod_name> -n <mlflow_namespace>. **

Additional resources 

Configure trace archival 

Trace archival for MLflow 