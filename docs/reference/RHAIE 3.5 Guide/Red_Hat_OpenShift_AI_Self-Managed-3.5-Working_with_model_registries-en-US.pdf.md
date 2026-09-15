# Red_Hat_OpenShift_AI_Self-Managed-3.5-Working_with_model_registries-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Working with model registries

Working with model registries in Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Working with model registries

Working with model registries in Red Hat OpenShift AI Self-Managed

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

As a data scientist or AI engineer in OpenShift AI, you can register, store, version, deploy, and track models by using a model registry.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

PREFACE 

CHAPTER 1. MODEL CATALOG AND MODEL REGISTRIES 1.1. MODEL CATALOG 1.2. MODEL REGISTRY 

CHAPTER 2 WORK WITH MODEL REGISTRIES 2.1. REGISTERING A MODEL FROM THE DASHBOARD 2.2. REGISTERING A MODEL VERSION 2.3. REGISTER AND STORE A MODEL AS AN OCI IMAGE 2.4. MONITORING MODEL TRANSFER JOBS 2.5. RETRY A FAILED MODEL TRANSFER JOB 2.6. DELETE A MODEL TRANSFER JOB 2.7. VIEWING REGISTERED MODELS 2.8. VIEWING REGISTERED MODEL VERSIONS 2.9. EDITING MODEL METADATA IN A MODEL REGISTRY 2.10. EDITING MODEL VERSION METADATA IN A MODEL REGISTRY 2.11. DEPLOYING A MODEL VERSION FROM A MODEL REGISTRY 2.12. EDITING THE DEPLOYMENT PROPERTIES OF A MODEL DEPLOYED BY USING THE MODEL SERVING PLATFORM 2.13. DELETING A DEPLOYED MODEL VERSION FROM A MODEL REGISTRY 2.14. ARCHIVING A MODEL 2.15. ARCHIVING A MODEL VERSION 2.16. RESTORING A MODEL 2.17. RESTORING A MODEL VERSION 

3 

4 4 4 

5 5 6 8 

10 11 

12 13 14 15 15 16 

18 20 20 21 22 22 

### PREFACE

As a data scientist or AI engineer in OpenShift AI, you can register, store, version, deploy, and track models by using a model registry. 

### CHAPTER 1. MODEL CATALOG AND MODEL REGISTRIES

The model catalog provides a curated library where data scientists and AI engineers can discover and evaluate the available generative AI (gen AI) models to find the best fit for their use cases. 

A model registry acts as a central repository for administrators, data scientists, and AI engineers to register, version, and manage the lifecycle of AI models before configuring them for deployment. A model registry is a key component for AI model governance. 

1.1. MODEL CATALOG 

Data scientists and AI engineers can use the model catalog to discover and evaluate the gen AI models that are available and ready for their organization to register, deploy, and customize. 

The model catalog provides models from different providers that you can search, discover, and evaluate before you register models in a model registry and deploy them to a model serving runtime. Third-party gen AI models are benchmarked by Red Hat for performance and quality by using open-source evaluation datasets. Red Hat AI models also include pre-computed safety and security evaluation results covering risk vectors such as prompt injection, jailbreak resistance, and harmful content generation. You can compare performance metrics for specific hardware configurations and evaluate a model’s security posture to determine the most suitable option for deployment. 

OpenShift AI provides a default model catalog that includes models from different source providers. OpenShift AI administrators can manage and govern model catalog sources to control which models are available to data scientists and AI engineers. For more information, see Manage and govern model catalog sources. 

Data scientists and AI engineers can discover and evaluate models in the catalog before registering and deploying them. 

1.2. MODEL REGISTRY 

A model registry is an important component in the lifecycle of an artificial intelligence/machine learning (AI/ML) model, and is a vital part of any machine learning operations (MLOps) platform or workflow. A model registry acts as a central repository, storing metadata related to machine learning models from development to deployment. This metadata ranges from high-level information like the deployment environment and project, to specific details like training hyperparameters, performance metrics, and deployment events. 

A model registry acts as a bridge between model experimentation and serving, offering a secure, collaborative metadata store interface for stakeholders in the ML lifecycle. Model registries provide a structured and organized way to store, share, version, deploy, and track models. 

OpenShift AI administrators can create model registries in OpenShift AI and grant model registry access to data scientists and AI engineers. For more information, see Managing model registries. 

Data scientists and AI engineers with access to a model registry can use it to store, share, version, deploy, and track models. For more information, see Working with model registries. 

### CHAPTER 2. WORK WITH MODEL REGISTRIES

2.1. REGISTERING A MODEL FROM THE DASHBOARD 

As a data scientist or AI engineer, you can register a model from the OpenShift AI dashboard and create the first version of the new model. 

Prerequisites 

You are logged in to Red Hat OpenShift AI. 

You have access to an available model registry in your deployment. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that you want to register a model in. 

3. Click Register model. The Register model dialog opens. 

4. In the Model details section, configure details to apply to all versions of the model: 

a. In the Model name field, enter a name for the model. 

b. Optional: In the Model description field, enter a description for the model. 

5. In the Version details section, enter details to apply to the first version of the model: 

a. In the Version name field, enter a name for the model version. 

b. Optional: In the Version description field, enter a description for the first version of the model. 

**c. In the Source model format field, enter the name of the model format, for example, ONNX. **

d. In the Source model format version field, enter the version of the model format. 

6. In the Model location section, specify the location of the model by providing either object storage details, or a URI. 

a. To provide object storage details, ensure that the Object storage radio button is selected. 

i. To autofill the details of an existing connection: 

A. Click Autofill from connection. 

B. In the Autofill from connection dialog that opens, from the Project drop-down list, select the project that contains the connection. 

C. From the Connection name drop-down list, select the connection that you want to use. This list contains only object storage types which contain a bucket. 

D. Click Autofill. 

ii. Alternatively, manually fill out your object storage details: 

A. In the Endpoint field, enter the endpoint of your S3-compatible object storage bucket. 

B. In the Bucket field, enter the name of your S3-compatible object storage bucket. 

C. In the Region field, enter the region of your S3-compatible object storage account. 

D. In the Path field, enter a path to a model or folder. This path cannot point to a root folder. 

b. To provide a URI, ensure that the URI radio button is selected. 

i. In the URI field, enter the URI for the model. 

IMPORTANT 

Deployment of models that are registered by using a URI is currently supported for public OCI repositories only. 

7. Click Register model. 

Verification 

The new model and version details are displayed on the Details tab for the model version. 

The new model and version are displayed on the Model registry page. 

2.2. REGISTERING A MODEL VERSION 

You can register a new model version. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

You have access to an available model registry in your deployment. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that you want to register a model version in. 

3. In the Model name column, click the name of the model that you want to register a new version of. The details page for the model opens. 

4. Click the Versions tab, and then click Register new version. 

5. In the Version details section, enter details to apply to this version of the model: 

a. In the Version name field, enter a name for the model version. 

b. Optional: In the Version description field, enter a description for this version of the model. 

**c. In the Source model format field, enter the name of the model format, for example, ONNX. **

d. In the Source model format version field, enter the version of the model format. 

6. In the Model location section, specify the location of the model by providing either object storage details, or a URI. 

a. To provide object storage details, ensure that the Object storage radio button is selected. 

i. To autofill the details of an existing connection: 

A. Click Autofill from connection. 

B. In the Autofill from connection dialog that opens, from the Project drop-down list, select the project that contains the connection. 

C. From the Connection name drop-down list, select the connection that you want to use. This list contains only object storage types which contain a bucket. 

D. Click Autofill. 

ii. Alternatively, manually fill out your object storage details: 

A. In the Endpoint field, enter the endpoint of your S3-compatible object storage bucket. 

B. In the Bucket field, enter the name of your S3-compatible object storage bucket. 

C. In the Region field, enter the region of your S3-compatible object storage account. 

D. In the Path field, enter a path to a model or folder. This path cannot point to a root folder. 

b. To provide a URI, ensure that the URI radio button is selected. 

i. In the URI field, enter the URI for the model. 

IMPORTANT 

Deployment of models that are registered by using a URI is currently supported for public OCI repositories only. 

7. Click Register new version. 

Verification 

The new model version is displayed in the Latest versions section on the Overview tab on the model details page. 

The new model version is displayed in the Latest version column on the Model registry page. 

2.3. REGISTER AND STORE A MODEL AS AN OCI IMAGE 

You can register and store a model as an Open Container Initiative (OCI) image from the OpenShift AI dashboard. You can register a model from object storage or a URL and transform it into an OCI ModelCar image. 

The ModelCar target format enables fast deployment with KServe. The model transfer job runs as a background Kubernetes Job that you can also monitor from the dashboard. 

Prerequisites 

You have logged in to the Red Hat OpenShift AI dashboard. 

You have access to an available model registry in your deployment. 

If using object storage as the model origin, you have the required credentials. 

You have credentials for the OCI registry in which to store the ModelCar image. 

Procedure 

1. In the OpenShift AI dashboard, click AI hub → Models → Registry. 

2. From the Model registry drop-down list, select the model registry for the model. 

3. Click Register model to create a new model, or navigate to an existing model, and click Register new version. 

NOTE 

You can also start from the model catalog and register a model in the catalog into your registry. For more details, see Working with the model catalog . 

4. In the Model location and storage section, select Register and store. The Register and store option starts an async Kubernetes Job that copies the model into an OCI registry as a ModelCar-format image and then registers the metadata. 

The Register option registers metadata only and points to an artifact that is already stored elsewhere. 

NOTE 

**If you register a catalog model whose source is already an oci:// URI, the UI forces **Register mode only because the model is already stored in OCI format. 

5. In the Model transfer job name field, provide a human-readable display name for the job, for **example, Upload granite-7b to Quay. **

6. Optional: Click Edit resource name to edit the Kubernetes Job resource name, autogenerated from the display name. This must be a valid Kubernetes name. 

7. In the Project field, select the Kubernetes namespace where the transfer job runs. 

NOTE 

If you are a non-admin user, you see only projects and namespaces to which you have access. The UI validates that the selected namespace has access to the model registry instance. If access cannot be confirmed, this displays a warning, and you must select a different project. 

8. In the Model origin location section, click the Object storage or URI source location type. 

9. Provide the details for your selected model source location: 

For Object storage (S3-compatible), enter: 

**Endpoint: S3 or MinIO endpoint URL, for example: https://s3.amazonaws.com. **

**Bucket: Bucket name, for example: ods-ci-s3, **

**Region: AWS region, if applicable, for example: us-east-1. **

**Path: Prefix or path to the model files in the bucket, for example: /kserve-openvino-test/openvino-example-model. **

Access Key ID and Secret Access Key: Credentials for the source bucket. 

For URI, provide a direct URL. The supported schemas are: 

**https:// or http:// **

**hf:// for HuggingFace Hub, which uses snapshot_download **

NOTE 

For catalog models, the URI is prefilled from the catalog source and cannot be changed. 

10. In the Model destination location section, provide the OCI registry details: 

**Registry: OCI registry host such as quay.io or your self-hosted registry. **

**URI: Image reference without a scheme, for example, myorg/granite-7b:v1. **

Username: OCI registry username. 

Password: OCI registry token or password. In the background, OpenShift AI creates a ModelCar-compatible OCI image: 

**A busybox:latest base image is pulled. For Quay destinations, quay.io/quay/busybox:latest is used automatically. **

**Model files are layered on top using olot (OCI Layers On Top). **

The resulting image is pushed to your specified OCI destination. 

11. Complete the remaining model metadata fields: model name, version, format, description, and so on. 

12. Click Register. This creates the transfer job and Kubernetes resources in the selected namespace: 

ConfigMap with model metadata. 

Secret with source credentials (S3 only). 

**Secret with destination registry credentials in .dockerconfigjson format. **

Kubernetes Job running the async-upload container image. The ConfigMap and Secrets are owned by the Job and are garbage-collected when the Job is deleted. 

The Job container downloads from the source, layers files into a ModelCar OCI image, pushes to the destination, and calls the Model Registry API to create the model artifact with **the oci:// URI. **

Verification 

A Model transfer job started notification message displays immediately and you can click the link to the model transfer job. 

When the transfer job completes, click the link in the relevant notification message: 

Success: View the newly registered model and version. 

Failure: View Kubernetes events for the job pods, and retry or delete the job. 

On success, on the newly registered model version page: 

The Storage location section shows the OCI destination details. 

**The artifact URI is set to oci://<registry>/<image>:<tag>, which KServe ModelCar can then **use for model serving. 

2.4. MONITORING MODEL TRANSFER JOBS 

You can monitor the model transfer jobs that are created when you store model artifacts at registration time. Model transfer jobs are background Kubernetes Jobs that copy models from a source location to an OCI registry as ModelCar images. 

Prerequisites 

You have logged in to the Red Hat OpenShift AI dashboard. 

You have access to a model registry instance. 

You have created at least one model transfer job by registering and storing a model. 

Procedure 

1. In the OpenShift AI dashboard, click AI hub → Models → Registry. 

2. From the Model registry drop-down list, select the model registry instance in which to monitor transfer jobs. 

3. On the Models page, click the action menu (⋮) beside the Register model button, and click View model transfer jobs. Alternatively, you can follow a link in a notification message. The Model transfer jobs table shows the following details: 

Job name: Job display name and resource name. 

Model name and Model version name: These display as links only when the transfer job is successful. 

Namespace: Where the job runs. 

Created: When the job was created. 

Author: Username who created the job. 

**Transfer job status: Status indicator of Pending, Running, Complete, or Failed. The page auto-polls while any job is in Pending or Running state. **

4. Optional: In the filter drop-down list, you can select filters to refine the list of jobs, for example, by a specific job name, model name, status, or author. 

5. To view detailed status and events for a job, click a status indicator in a row to open the Status dialog. If the job has failed, this includes a failure alert with details. 

6. In the Status dialog, on the Event log tab, you can view Kubernetes events for the job pods, for example, pulled image, started container, errors, and so on. These events auto-refresh while the job is active. 

Verification 

Monitor the Transfer job status column for real-time updates on the progress of your transfer job. 

When a transfer job completes successfully, click the Model name or Model version name links to view your registered model version. 

If a transfer job fails, click the Failed status indicator to open the Status dialog and review the error details. 

2.5. RETRY A FAILED MODEL TRANSFER JOB 

You can retry a failed model transfer job to create a new transfer job with the same configuration. Model transfer jobs are created when you choose to store model artifacts at registration time. Retrying a job creates a new transfer job and a new Kubernetes resource name. 

Prerequisites 

You have logged in to the Red Hat OpenShift AI dashboard. 

You have access to a model registry instance. 

You have a failed model transfer job. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Models → Registry. 

2. From the Model registry drop-down list, select the model registry instance in which to retry a failed transfer job. 

3. On the Models page, click the action menu (⋮) beside the Register model button, and click View model transfer jobs. Alternatively, you can also follow a link in a notification message. 

4. Locate the failed job in the table, and in the Transfer job status column, click the Retry link. 

5. In the Retry model transfer job dialog, review the prepopulated New model transfer job name field, and edit if necessary. 

6. Optional: Click Edit resource name to edit the autogenerated name for the Kubernetes Job. This must be a valid Kubernetes name. 

7. Optional: Ensure that Delete the failed <job-name> transfer job is selected to delete the job as part of the retry. 

8. Click Retry. The Retry dialog generates a new Kubernetes resource name and a new transfer job. A new job is created with the same configuration as the failed job. 

Verification 

**A new model transfer job displays in the Model transfer jobs table with a status of Pending or Running. **

If you selected to delete the failed job, the old job is removed from the table. 

Monitor the new job status to verify that the transfer completes successfully. 

2.6. DELETE A MODEL TRANSFER JOB 

You can delete a model transfer job to remove the Kubernetes Job and its owned resources from your namespace. Deleting a transfer job does not affect the storage location of the model if the transfer was successful. 

Prerequisites 

You have logged in to the Red Hat OpenShift AI dashboard. 

You have access to a model registry instance. 

You have at least one model transfer job that you want to delete. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Models → Registry. 

2. From the Model registry drop-down list, select the model registry instance in which to delete a transfer job. 

3. On the Models page, click the action menu (⋮) beside the Register model button, and click View model transfer jobs. Alternatively, you can also follow a link in a notification message. 

4. Locate the job to delete in the table, and from the row action menu (⋮), click Delete. 

5. In the Delete model transfer job dialog, enter the job name to confirm deletion. 

6. Click Delete. This deletes the transfer job and its owned resources of ConfigMap and Secrets. 

Verification 

The job is removed from the Model transfer jobs table. 

The Kubernetes Job and its owned resources are deleted from the namespace. 

If the model was successfully transferred before deletion, the model remains available in the OCI registry and the model registry. 

2.7. VIEWING REGISTERED MODELS 

You can view the details of models registered in OpenShift AI, such as registered versions, deployments, and metadata associated with the model. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

An available model registry exists in your deployment, and contains at least 1 registered model. 

You have access to the model registry that contains the model that you want to view. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that contains the model that you want to view. 

3. The Model registry page provides a high-level view of registered models, including the model name, latest version, deployments, labels, last modified timestamp, and owner of each model. Models are sorted by their Last modified timestamp by default. 

4. Use the search bar to find a model in the list. You can filter with a keyword by default by entering a model name, description, or label. Alternatively, click the search bar drop-down list and select Owner to filter by entering a model owner. Searching by keyword performs a search across the name, description, and labels of registered models and their versions. 

5. Click the name of a model to view the details page for the model: 

a. On the Overview tab, you can view model metadata such as labels, description, owner, model ID, last modified and created timestamps, and custom properties, along with latest versions and deployments. 

b. On the Versions tab, you can view the registered versions of the model. 

c. On the Deployments tab, you can view deployments initiated from the model registry for this model. 

Verification 

You can view information about the selected model on the details page for the model. 

2.8. VIEWING REGISTERED MODEL VERSIONS 

You can view the details of model versions that are registered in OpenShift AI, such as the version metadata and deployment information. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

An available model registry exists in your deployment, and contains at least 1 registered model. 

You have access to the model registry that contains the model version that you want to view. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that contains the model version that you want to view. 

3. Click the name of a model to view Overview tab on the model details page, which includes the latest model versions and deployments. 

4. On the Versions tab, you can view the registered versions of the model. Versions are sorted by their Last modified timestamp by default. 

5. Use the search bar to find a version in the list. You can filter with a keyword by default by entering a model name, description, or label. Alternatively, click the search bar drop-down list and select Author to filter by entering a model owner. Searching by keyword performs a search across the name, description, and labels of registered models and their versions. 

6. Click the name of a version to view the version details page. 

7. On the Details tab, you can view the Version details metadata, such as labels, description, custom properties, version ID, author, and last modified and registered timestamps. This also includes where the model is registered from, model location, and model format information. You can also click Model details to view non-version metadata, such as labels, description, owner, model ID, last modified and created timestamps, and custom properties. 

8. On the Deployments tab, you can view deployments initiated from the model registry for this version. 

a. Click the name of a deployment to open its metrics page. For information about model metrics, see Viewing performance metrics for a deployed model. 

Verification 

You can view the details of registered model versions on the Model registry page. 

2.9. EDITING MODEL METADATA IN A MODEL REGISTRY 

You can edit the metadata of models registered in OpenShift AI, such as the model description, labels, and custom properties. Editing model metadata affects all versions of the model. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

An available model registry exists in your deployment, and contains at least 1 registered model. 

You have access to the model registry that contains the model that you want to edit. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that contains the model that you want to edit. 

3. The Model registry page provides a high-level view of registered models, including the model name, latest version, deployments, labels, last modified timestamp, and owner of each model. 

4. Click the name of a model to view the model details page. 

5. On the Overview tab, you can edit metadata for the model. 

**a. In the Labels section, click Edit to edit the labels of the model, for example, text-to-text. **

b. In the Description section, click Edit to edit the description of the model. 

c. In the Properties section, click Add property to add a new property to the model, for **example, Key: license, Value: apache. **

TIP 

If you enter any property value as a URL, this is displayed as a clickable link in the Properties section, for example: https://www.apache.org/licenses/LICENSE-2.0. 

**i. To edit an existing property, click the action menu (⋮) beside the property, and then **click Edit. 

**ii. To delete a property, click the action menu (⋮) beside the property, and then click **Delete. 

Verification 

You can view the updated metadata on the details page for the model. 

2.10. EDITING MODEL VERSION METADATA IN A MODEL REGISTRY 

You can edit the metadata of model versions that are registered in OpenShift AI, such as the version’s description, labels, and custom properties. Editing model version metadata affects that model version only. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

An available model registry exists in your deployment, and contains at least 1 registered model. 

You have access to the model registry that contains the model version that you want to edit. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that contains the model version that you want to edit. 

3. Click the name of a model to view the model details page. 

4. Click the Versions tab to view the available model versions. 

5. Click a version name to view the version details page. 

6. In the Version details section, you can edit the version metadata. 

**a. In the Labels section, click Edit to edit the labels of the version, for example, text-to-text. **

b. In the Description section, click Edit to edit the description of the version. 

c. In the Properties section, click Add property to add a new property to the version, for **example, Key: license, Value: apache. **

TIP 

If you enter any property value as a URL, this is displayed as a clickable link in the Properties section, for example: https://www.apache.org/licenses/LICENSE-2.0. 

**i. To edit an existing property, click the action menu (⋮) beside the property, and then **click Edit. 

**ii. To delete a property, click the action menu (⋮) beside the property, and then click **Delete. 

d. In the Model format section, click Edit to edit the format of the model version, for example, **ONNX. **

e. In the Model format version section, click Edit to edit the format version of the model version. 

Verification 

You can view the updated metadata on the details page for the model version. 

2.11. DEPLOYING A MODEL VERSION FROM A MODEL REGISTRY 

You can deploy a version of a registered model directly from a model registry. 

Prerequisites 

An available model registry exists in your deployment, and contains at least one registered model. 

To deploy a model version by using the model serving platform, you have fulfilled the prerequisites described in Deploying models on the model serving platform . 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry list, select the model registry from which you want to deploy a model version. 

3. In the Model name column, click the name of the model that contains the version that you want to deploy. The details page for the model version opens. 

**4. Click the action menu (⋮) beside the model version that you want to deploy. **

5. Click Deploy for the model version. 

6. In the Deploy model dialog, configure properties for deploying the model: 

a. From the Project list, select a target project. When you select a project, OpenShift AI scans through the connections to that project and checks if any match the connections that the model was registered with. 

If there is a single matching connection, this is autoselected. If there are multiple matching connections, these are displayed next in the Connection list. 

If there are no matching connections, you can go straight to the deployment wizard, without selecting a connection, and the model location data will be autofilled as a new connection. 

b. When there are multiple matching connections, from the Connection list, select the connection that you want to use when deploying the model. The deployment wizard is autofilled with the details for your selected connection. If you selected a connection or one was autoselected, you can change the connection or create a new one in the next steps. 

c. Click Deploy. This displays the deployment wizard. 

7. On the Model details page, provide information about the model: 

a. From the Model location list, specify where your model is stored and complete the appropriate details for your connection. For a matching connection selected in the Deploy model dialog, the details are autofilled. Alternatively, you can create a new connection. For more information about connections, see Adding a connection to your project . 

b. Optional: In the Model deployment name field, enter a unique name for your model deployment. This field is autofilled with a value that contains the model name by default. This will be the name of the inference service that is created when the model is deployed. 

8. Click Next. 

9. On the Model deployment and Advanced settings pages, configure the remaining properties for deploying your model, as described in Deploying models on the model serving platform . 

10. On the Review page, review the settings that you have selected before deploying the model. 

11. Click Deploy. 

Verification 

The model deployment is displayed on the AI hub → Deployments page. 

The model deployment is displayed in the Latest deployments section of the model details page. 

The model version is displayed on the Deployments tab for the model. 

**You can edit the model version deployment by clicking the action menu (⋮) beside it, and then **clicking Edit. 

**You can delete the model version deployment by clicking the action menu (⋮) beside it, and **then clicking Delete. 

2.12. EDITING THE DEPLOYMENT PROPERTIES OF A MODEL DEPLOYED BY USING THE MODEL SERVING PLATFORM 

You can edit the deployment properties of a deployed model version from a model registry. For example, you can change the deployment name, model framework, number of model server replicas, model server size, and source model location details. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

An available model registry exists in your deployment, and contains at least 1 registered and deployed model version. 

You have access to the model registry that contains the model version deployment that you want to edit. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that contains the model deployment that you want to edit. 

3. In the Model name column, click the name of the model that contains the deployment that you want to edit. The details page for the model opens. 

4. Click the name of the model version with the deployment that you want to edit. 

5. Click Deployments 

**6. Click the action menu (⋮) beside the model deployment that you want to edit. **

7. Click Edit. 

8. In the Edit model dialog, edit the model deployment properties: 

a. In the Model deployment name field, enter a new, unique name for your model deployment. 

b. From the Model framework list, select a different framework for your model. 

NOTE 

The Model framework list shows only the frameworks that are supported by the model serving runtime that you specified when you deployed your model. 

c. In the Number of model server replicas to deploy field, specify a value. 

d. From the Model server size list, select a value. 

e. In the Model route section, select the Make deployed models available through an external route checkbox to make your deployed models available to external clients. 

f. In the Token authentication section, select the Require token authentication checkbox to require token authentication for your model server. To finish configuring token authentication, perform the following actions: 

i. In the Service account name field, enter a service account name for which the token will be generated. The generated token is created and displayed in the Token secret field when the model server is configured. 

ii. To add an additional service account, click Add a service account and enter another service account name. 

g. Edit the connection by specifying an existing connection, or by creating a new connection. 

h. Customize the runtime parameters in the Configuration parameters section: 

i. Modify the values in Additional serving runtime arguments to define how the deployed model behaves. 

ii. Modify the values in Additional environment variables to define variables in the model’s environment. The Configuration parameters section shows predefined serving runtime parameters, if any are available. 

NOTE 

Do not modify the port or model serving runtime arguments, because they require specific values to be set. Overwriting these parameters can cause the deployment to fail. 

i. Click Redeploy. 

Verification 

The model redeploys and is displayed with updated details on the Deployments tab for the model version. 

2.13. DELETING A DEPLOYED MODEL VERSION FROM A MODEL REGISTRY 

You can delete the deployments of model versions from a model registry. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

An available model registry exists in your deployment, and contains at least 1 registered model with a deployed model version. 

You have access to the model registry that contains the model version deployment that you want to delete. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that contains the deployment that you want to delete. 

3. Click the name of a model to view more details. The details page for the model opens. 

4. Click the name of the model version with the deployment that you want to delete. The details page for the model version opens. 

5. Click Deployments. 

**6. To delete a deployment, click the action menu (⋮) beside the deployment, and then click **Delete. The Delete deployed model? dialog opens. 

7. Enter the name of the model deployment in the text field to confirm that you intend to delete it. 

8. Click Delete deployed model. 

Verification 

The model deployment is no longer displayed on the Deployments tab for the model version. 

2.14. ARCHIVING A MODEL 

You can archive a model that you no longer require. The model and all of its versions will be archived and unavailable for use unless it is restored. 

IMPORTANT 

Models with deployed versions cannot be archived. To archive a model, you must first delete all deployments of its registered versions from the AI hub → Deployments page. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

An available model registry exists in your deployment, and contains at least 1 registered model. 

You have access to the model registry that contains the model that you want to archive. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that you want to archive a model in. 

**3. Click the action menu (⋮) beside the model that you want to archive. **

4. Click Archive model. 

5. In the Archive model? dialog that is displayed, enter the name of the model in the text field to confirm that you intend to archive it. 

6. Click Archive. 

Verification 

The model is no longer visible on the Model registry page. 

The model is displayed on the archived models page for the model registry. 

2.15. ARCHIVING A MODEL VERSION 

You can archive a model version that you no longer require. The model version will be archived and unavailable for use unless it is restored. 

IMPORTANT 

Deployed model versions cannot be archived. To archive a model version, you must first delete all deployments of the version from the AI hub → Deployments page. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

An available model registry exists in your deployment, and contains at least 1 registered model. 

You have access to the model registry that contains the model version that you want to archive. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that you want to archive a model in. 

3. In the Model name column, click the name of the model that contains the version that you want to archive. 

The details page for the model version opens. 

**4. Click the action menu (⋮) beside the version that you want to archive. **

5. Click Archive model version. 

6. In the Archive version? dialog that opens, enter the name of the model version in the text field to confirm that you intend to archive it. 

7. Click Archive. 

Verification 

The model version is no longer visible on the details page for the model. 

The model version is displayed on the archived versions page for the model. 

2.16. RESTORING A MODEL 

You can restore an archived model. The model and all of its versions will be restored and returned to the registered models list. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

An available model registry exists in your deployment, and contains at least one archived model. 

You have access to the model registry that contains the model that you want to restore. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that you want to restore a model in. 

**3. Click the action menu (⋮) beside the Register model button, and then click View archived **models. The archived models page for the model registry opens. 

**4. Click the action menu (⋮) beside the model that you want to restore. **

5. Click Restore model. 

6. In the Restore model? dialog that is displayed, click Restore. 

Verification 

The model is displayed on the Model registry page. 

The model is no longer displayed on the archived models page for the model registry. 

2.17. RESTORING A MODEL VERSION 

You can restore an archived model version. The model version will be restored and returned to the versions list for the model. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

An available model registry exists in your deployment, and contains at least one archived model version. 

You have access to the model registry that contains the model version that you want to restore. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Registry. 

2. From the Model registry drop-down list, select the model registry that you want to restore a model version in. 

3. In the Model name column, click the name of the model that contains the version that you want to restore. The details page for the model version opens. 

**4. Click the action menu (⋮) beside the Register new version button, and then click View **archived versions. The archived versions page for the model opens. 

**5. Click the action menu (⋮) beside the version that you want to restore. **

6. Click Restore version. 

7. In the Restore version? dialog that opens, click Restore. The details page for the version opens. 

Verification 

The model version is displayed on the details page for the model. 

The model is no longer displayed on the archived versions page for the model. 