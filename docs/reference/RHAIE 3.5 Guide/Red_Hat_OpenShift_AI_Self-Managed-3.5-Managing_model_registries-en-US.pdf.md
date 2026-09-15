# Red_Hat_OpenShift_AI_Self-Managed-3.5-Managing_model_registries-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Managing model registries

Managing model registries in Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Managing model registries

Managing model registries in Red Hat OpenShift AI Self-Managed

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

As an OpenShift AI administrator, you can create, delete, and manage permissions for model registries in OpenShift AI.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

PREFACE 

CHAPTER 1. MODEL CATALOG AND MODEL REGISTRIES 1.1. MODEL CATALOG 1.2. MODEL REGISTRY 

CHAPTER 2 ENABLE THE MODEL REGISTRY COMPONENT 

CHAPTER 3 CREATE A MODEL REGISTRY 

CHAPTER 4 EDIT A MODEL REGISTRY 

CHAPTER 5 MANAGE MODEL REGISTRY PERMISSIONS 

CHAPTER 6 DELETE A MODEL REGISTRY 

3 

4 4 4 

5 

7 

10 

12 

14 

### PREFACE

As an OpenShift AI administrator, you can create, delete, and manage permissions for model registries in OpenShift AI. 

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

### CHAPTER 2. ENABLE THE MODEL REGISTRY COMPONENT

Before data scientists and AI engineers in your organization can work with the model registry and model **catalog, you must ensure that the modelregistry component is enabled in OpenShift AI. **

NOTE 

**The modelregistry component is enabled by default in a new OpenShift AI 3.5 **installation. However, if the model registry was not enabled in a previous version of OpenShift AI, you must enable this component after upgrading to OpenShift AI 3.5. 

Prerequisites 

You have cluster administrator privileges for your OpenShift cluster. 

You have access to the data science cluster. 

You have installed the Red Hat OpenShift AI Operator on your OpenShift cluster. 

You have sufficient resources. For more information about the minimum resources required to use OpenShift AI, see Installing and deploying OpenShift AI  (for disconnected environments, see Deploying OpenShift AI in a disconnected environment ). 

Procedure 

1. Log in to the OpenShift web console as a cluster administrator. 

2. Go to the Installed Operators page. The navigation path depends on your OpenShift version: 

On OpenShift 4.20 and later, click Ecosystem → Installed Operators. 

On OpenShift 4.19, click Operators → Installed Operators. 

3. Search for the Red Hat OpenShift AI Operator, and then click the Operator name to open the Operator details page. 

4. Click the Data Science Cluster tab. 

5. Click the default instance name (for example, default-dsc) to open the instance details page. 

6. Click the YAML tab to show the instance specifications. 

**7. Find the spec.components section, and then add or update it to include the following modelregistry component entry, with the managementState field set to Managed, and the registriesNamespace field set to rhoai-model-registries: **

 modelregistry:     managementState: Managed     registriesNamespace: rhoai-model-registries 

8. Click Save. 

Verification 

Confirm that the model registry namespace was created successfully: 

a. In the OpenShift console, click Home → Projects. 

**b. Confirm that the rhoai-model-registries namespace is displayed in the Projects drop-**down list. 

Check the status of the model-registry-operator-controller-manager pod: 

a. In the OpenShift console, from the Project list, select redhat-ods-applications. 

b. Click Workloads → Deployments. 

c. Search for the model-registry-operator-controller-manager deployment. 

d. Check the status: 

i. Click the deployment name to open the deployment details page. 

ii. Click the Pods tab. 

iii. View the pod status. *When the status of the model-registry-operator-controller-manager-<pod-id> pod is *Running, the pod is ready to use. 

Next steps 

OpenShift AI administrators can create, delete, and manage permissions for model registries. For more information, see Managing model registries. 

### CHAPTER 3. CREATE A MODEL REGISTRY

You can create a model registry to store, share, version, deploy, and track your models. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

The model registry component is enabled in your OpenShift AI deployment. For more information, see Enabling the model registry component. 

For production use cases, you have access to one of the following external databases: 

PostgreSQL 16.x database 

MySQL database that uses at least MySQL 5.x. However, it is best to use MySQL 9.x. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Model resources and operations → Model registry settings. 

2. Click Create model registry. The Create model registry dialog opens. 

3. In the Name field, enter a name for the model registry. 

4. Optional: Click Edit resource name, and enter a specific resource name for the model registry in the Resource name field. By default, the resource name matches the name of the model registry. 

IMPORTANT 

Resource names are what your resources are labeled as in OpenShift. Your resource name cannot exceed 253 characters, must consist of lowercase *alphanumeric characters or -, and must start and end with an alphanumeric *character. Resource names are not editable after creation. 

The resource name must not match the name of any other model registry resource in your OpenShift cluster. 

5. Optional: In the Description field, enter a description for the model registry. 

6. In the Database section, click one of the following options to select where your model data is stored: 

Default database (non-production): Use the PostgreSQL database that is enabled by default on your OpenShift cluster. 

NOTE 

The default database is designed for evaluation, development, and testing purposes only. Red Hat does not support this database for production use cases. 

External database: Connect an external MySQL or PostgreSQL database designed for production use cases. 

7. If you selected External database, enter the details for the external database where your model data is stored: 

Database type: Select MySQL or PostgreSQL from the list. 

Host: Enter the database hostname, depending on where the database is running: 

**a. In the rhoai-model-registries namespace, enter only the hostname for the database. **

**b. In a different namespace from rhoai-model-registries, enter the database hostname details in <hostname>.<namespace>.svc.cluster.local format. **

**Port: Enter the port number for the database. The default port for MySQL is 3306. The default port for PostgreSQL is 5432. **

Username: Enter the default user name that is connected to the database. 

Password: Enter the password for the default user account. 

Database: Enter the database name. 

Optional: Add CA certificate to secure database connection: Select this option to use a certificate with your database connection and specify one of the following options. 

IMPORTANT 

If your external database is configured to enforce Transport Layer Security (TLS), you must add a Certificate Authority (CA) certificate. 

**a. Click Use cluster-wide CA bundle to use the ca-bundle.crt bundle in the odh-trusted-ca-bundle ConfigMap. **

**b. Click Use Red Hat OpenShift AI CA bundle to use the odh-ca-bundle.crt bundle in the odh-trusted-ca-bundle ConfigMap. **

c. Click Choose from existing certificates to select an existing certificate. You can select **the key of any ConfigMap or secret in the rhoai-model-registries namespace. **

i. From the Resource list, select a ConfigMap or secret. 

ii. From the Key list, select a key. 

d. Click Upload new certificate to upload a new certificate as a ConfigMap. 

i. Drag and drop the PEM file for your certificate into the Certificate field, or click Upload to select a file from your local machine’s file system. 

NOTE 

**Uploading a certificate creates the db-credential ConfigMap with the ca.crt key. **

To upload a certificate as a secret, you must create a secret in the **OpenShift rhoai-model-registries namespace, and then select it as **an existing certificate when you create your model registry. 

For more information about creating secrets, see Providing sensitive data to pods by using secrets in the OpenShift Container Platform documentation. 

8. Click Create. 

NOTE 

To find the resource name or type of a model registry, click the help icon  beside the registry name. Resource names and types are used to find your resources in OpenShift. 

Verification 

The new model registry is displayed on the Model registry settings page. 

**You can edit the model registry by clicking the action menu (⋮) beside it, and then clicking Edit **model registry. 

Next steps 

After creating the model registry, manage its permissions to make the model registry accessible to users and projects. For more information, see Managing model registry permissions . 

You can register a model in the model registry from the Registry tab. For more information, see Working with model registries. 

### CHAPTER 4. EDIT A MODEL REGISTRY

You can edit the details of existing model registries, such as the model registry name, description, and database connection details. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

The model registry component is enabled in your OpenShift AI deployment. For more information, see Enabling the model registry component. 

Your OpenShift AI deployment contains at least one model registry. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Model resources and operations → Model registry settings. 

**2. Click the action menu (⋮) beside the model registry that you want to edit, and then click Edit **model registry. The Edit model registry dialog opens. 

3. Optional: In the Name field, edit the name of the model registry. 

4. Optional: In the Description field, edit the description of the model registry. 

5. Optional: In the Database section, click one of the following options to select where your model data is stored: 

Default database (non-production): Use the PostgreSQL database that is enabled by default on your OpenShift cluster. 

NOTE 

The default database is designed for evaluation, development, and testing purposes only. This database is not supported by Red Hat for production use cases. 

External database: Connect an external MySQL or PostgreSQL database designed for production use cases. 

6. If you selected External database, edit the details for the external database where your model data is stored: 

Database type: Select MySQL or PostgreSQL from the list. 

Host: Enter the database hostname, depending on where the database is running: 

**a. In the rhoai-model-registries namespace, enter only the hostname for the database. **

**b. In a different namespace from rhoai-model-registries, enter the database hostname details in <hostname>.<namespace>.svc.cluster.local format. **

**Port: Enter the port number for the database. The default port for MySQL is 3306. The default port for PostgreSQL is 5432. **

Username: Enter the default user name that is connected to the database. 

Password: Enter the password for the default user account. 

Database: Enter the database name. 

Optional: Add CA certificate to secure database connection: Select this option to use a certificate with your database connection and specify one of the following options. 

IMPORTANT 

If your external database is configured to enforce Transport Layer Security (TLS), you must add a Certificate Authority (CA) certificate. 

**a. Click Use cluster-wide CA bundle to use the ca-bundle.crt bundle in the odh-trusted-ca-bundle ConfigMap. **

**b. Click Use Red Hat OpenShift AI CA bundle to use the odh-ca-bundle.crt bundle in the odh-trusted-ca-bundle ConfigMap. **

c. Click Choose from existing certificates to select an existing certificate. You can select **the key of any ConfigMap or secret in the rhoai-model-registries namespace. **

i. From the Resource list, select a ConfigMap or secret. 

ii. From the Key list, select a key. 

d. Click Upload new certificate to upload a new certificate as a ConfigMap. 

i. Drag and drop the PEM file for your certificate into the Certificate field, or click Upload to select a file from your local machine’s file system. 

NOTE 

**Uploading a certificate creates the db-credential ConfigMap with the ca.crt key. **

To upload a certificate as a secret, you must create a secret in the **OpenShift rhoai-model-registries namespace, and then select it as **an existing certificate when you create your model registry. 

For more information about creating secrets, see Providing sensitive data to pods by using secrets in the OpenShift Container Platform documentation. 

7. Click Update. 

Verification 

The model registry is displayed with updated details on the Model registry settings page. 

### CHAPTER 5. MANAGE MODEL REGISTRY PERMISSIONS

You can manage access to a model registry for individual users and user groups in your organization, and for service accounts in a project. 

NOTE 

**OpenShift AI creates the <model-registry-name>-users group automatically for use **with model registries. You can add users to this group in OpenShift, or ask the cluster administrator to do so. 

The model registry operator uses OpenShift Role-Based Access Control (RBAC), and **creates various RBAC resources in the rhoai-model-registries namespace. **

**For each model registry instance, the operator creates a registry-users-<model registry instance name> role and an OpenShift group called <model registry instance name>-users. To grant an individual user, service account, or group access to a model registry instance, your cluster administrator must create a role binding to the registry-users-<model registry instance name> role for the instance. **

**The <model registry instance name>-users group has a role binding to the registry-users-<model registry instance name> role. Your cluster administrator can add users **to this group to grant them access to the model registry instance without needing to create a role binding for each user. 

For more information about managing RBAC in OpenShift, see Using RBAC to define and apply permissions. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

An available model registry exists in your deployment. 

The users and groups that you want to provide access to already exist in OpenShift. For more information, see Managing users and groups. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Model resources and operations → AI registry settings. 

2. Click Manage permissions beside the model registry that you want to manage access for. The permissions page for the model registry opens. 

3. Provide one or more OpenShift groups with access to the project. 

a. On the Users tab, in the Groups section, click Add group. 

b. From the Select a group drop-down list, select a group. 

NOTE 

**To enable access for all cluster users, add system:authenticated to the **group list. 

c. To confirm your entry, click Confirm (  ). 

d. Optional: To add an additional group, click Add group and repeat the process. 

4. Provide one or more users with access to the model registry. 

a. On the Users tab, in the Users section, click Add user. 

b. In the Type username field, enter the username of the user to whom you want to provide access. 

c. To confirm your entry, click Confirm (  ). 

d. Optional: To add an additional user, click Add user and repeat the process. 

5. Provide all service accounts in a project with access to the model registry. 

a. On the Projects tab, in the Projects section, click Add project. 

b. In the Select or enter a project field, select or enter the name of the project to which you want to provide access. 

c. To confirm your entry, click Confirm (  ). 

d. Optional: To add an additional project, click Add project and repeat the process. 

Verification 

Users, groups, and accounts that were granted access to a model registry can register, view, edit, version, deploy, delete, archive, and restore models in that registry. 

The Users and Groups sections on the Permissions tab show the respective users and groups that you granted access to the model registry. 

The Projects sections on the Projects tab show the projects that you granted access to the model registry. 

After you provide access to a model registry, users with access can store, share, version, deploy, and track models using the model registry feature. For more information, see Working with model registries. 

### CHAPTER 6. DELETE A MODEL REGISTRY

You can delete model registries that you no longer require. 

IMPORTANT 

When you delete a model registry, databases connected to the model registry will not be removed. To remove any remaining databases, contact your cluster administrator. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

An available model registry exists in your deployment. 

Procedure 

1. From the OpenShift AI dashboard, click Settings → Model resources and operations → AI registry settings. 

**2. Click the action menu (⋮) beside the model registry that you want to delete. **

3. Click Delete model registry. 

4. In the Delete model registry? dialog that opens, enter the name of the model registry in the text field to confirm that you intend to delete it. 

5. Click Delete model registry. 

Verification 

The model registry is no longer displayed on the AI registry settings page. 