# Red_Hat_OpenShift_AI_Self-Managed-3.5-Manage_and_govern_model_catalog_sources-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Manage and govern model catalog sources

Manage and govern model catalog sources in Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Manage and govern model catalog sources

Manage and govern model catalog sources in Red Hat OpenShift AI Self-Managed

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

OpenShift AI administrators can manage and govern model catalog sources to control which models are available to data scientists and AI engineers in their organization.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

PREFACE 

CHAPTER 1. MANAGE AND GOVERN MODEL CATALOG SOURCES IN THE OPENSHIFT AI DASHBOARD 1.1. VIEW MODEL CATALOG SOURCES 1.2. ENABLE OR DISABLE CATALOG SOURCES 1.3. CONFIGURE MODEL VISIBILITY SETTINGS TO ALLOW AND DISALLOW MODELS 1.4. LIMITATIONS FOR HUGGING FACE MODEL SOURCES 

CHAPTER 2 ADD A MODEL CATALOG SOURCE 

CHAPTER 3 MANAGE A MODEL CATALOG SOURCE 

CHAPTER 4 DELETE A MODEL CATALOG SOURCE 

CHAPTER 5 CONFIGURE MODEL CATALOG SOURCES IN OPENSHIFT 

3 

4 4 4 4 5 

6 

8 

10 

11 

### PREFACE

As an OpenShift AI administrator, you can use the OpenShift AI dashboard to manage model catalog sources and control which models are available to data scientists and AI engineers in your organization. You can add catalog sources from YAML files or Hugging Face repositories, and configure model visibility settings to allow or disallow specific models for governance and compliance. 

As an OpenShift cluster administrator, you can also configure a catalog source by adding an entry to the model catalog sources config map. 

### CHAPTER 1. MANAGE AND GOVERN MODEL CATALOG SOURCES IN THE OPENSHIFT AI DASHBOARD

As an OpenShift AI administrator, you can manage and govern model catalog sources to control which models are available to data scientists and AI engineers in your organization. Model catalog sources make models available from different providers that users can discover, register, and deploy. 

The OpenShift AI dashboard includes model catalog settings screens where you can add, edit, preview, and delete catalog sources. You can configure model visibility settings to allow or disallow specific models for governance and compliance purposes. You can also enable or disable a model catalog source. 

1.1. VIEW MODEL CATALOG SOURCES 

In the OpenShift AI dashboard, under Settings → Model resources and operations → Model catalog settings, you can view all configured model catalog sources and their status. Each catalog source displays the following information: 

Source name: The name of the source to be displayed in the catalog. The default sources are Red Hat AI, Red Hat AI validated, and Other. 

Organization: For Hugging Face sources only, the organization that provides the models, for **example, meta-llama. Only models in this organization are included in the catalog. **

Model visibility: Indicates whether all models from a source display in the catalog or if models are filtered based on visibility settings. 

Source type: The catalog source type, either Hugging Face repository or YAML file. 

Enable: You can enable a source to make its models available in the catalog for users in your organization. 

Validation status: When a non-default source is enabled, the validation status indicates whether the source has successfully connected to the catalog. 

You can filter catalog sources by source name, organization, model visibility, source type, and enabled status to quickly find the sources that you want to manage. 

1.2. ENABLE OR DISABLE CATALOG SOURCES 

When you add a new catalog source, you can keep it disabled while you configure the source details and model visibility settings. After you finish configuring the source, you can enable it to make the models available in the catalog for users. 

When you enable a catalog source, OpenShift AI validates the connection to ensure that the source is accessible. The validation status updates to show when the connection is starting, successful, or failed. 

You can disable a catalog source at any time to remove its models from the catalog without deleting the source configuration. 

1.3. CONFIGURE MODEL VISIBILITY SETTINGS TO ALLOW AND DISALLOW MODELS 

For governance and compliance, you can configure model visibility settings to control which models from 

a catalog source are available to users in your organization. This capability is essential for highly regulated organizations, where you must ensure that specific third-party models are not exposed to end users due to intellectual property concerns, geopolitical risks, or compliance requirements. 

You can use model visibility settings to include or exclude specific models by using pattern matching and wildcards. OpenShift AI applies included patterns first to select models from the catalog source, and then applies excluded patterns to filter out specific models from that set. 

1.4. LIMITATIONS FOR HUGGING FACE MODEL SOURCES 

The following limitations apply for Hugging Face repository sources: 

Public non-gated models only: This feature does not support gated or private models that require API keys or secret management. 

Connectivity requirements: OpenShift AI does not support deployment of this feature in disconnected environments. The cluster must have external network access to Hugging Face. 

Model validation: Red Hat does not validate or guarantee the security of third-party models. You are responsible for vetting all external content. 

Performance: Deployment times depend on model size and network speed, both of which might increase initial startup latency. 

### CHAPTER 2. ADD A MODEL CATALOG SOURCE

You can add a model catalog source to make additional models available in the model catalog. You can add a catalog source from a Hugging Face repository or a YAML file. 

Prerequisites 

You have logged in to the OpenShift AI dashboard as an administrator. 

Procedure 

1. In the OpenShift AI dashboard, click Settings → Model resources and operations → Model catalog settings. 

2. Click Add a source. 

3. In the Add a source dialog, configure the following settings: 

Name: Enter a descriptive name for the catalog source. 

Source type: Select the type of catalog source: 

Hugging Face repository: A source from a Hugging Face repository and organization. 

YAML file: A source defined by a YAML file that contains model metadata. 

4. Configure the catalog source based on the selected type: 

For a Hugging Face repository: In the Allowed organization field, enter the Hugging Face **organization name to sync models from, for example, meta-llama or ibm-granite. **All public models from the specified organization will be available in the catalog. 

NOTE 

You must enter the organization name used in the Hugging Face URL slug, **for example, meta-llama, and not the display name of Meta Llama. **

For a YAML file: In the Upload a YAML file field, drag and drop or click Upload to select your catalog YAML file. Alternatively, you can paste the contents of the YAML file into the text box. The YAML file must contain the model definitions with metadata that includes model name, description, and deployment information. 

5. Optional: Configure model visibility settings to control which models are available to users: 

a. Click Model visibility. 

b. To include only specific models, enter one or more patterns in the Include models field. **For example, Llama* only includes model names that start with Llama. **

IMPORTANT 

For YAML sources, you must specify the full model name prefix including the organization. For Hugging Face sources, specify only the model name without the organization prefix. 

c. To exclude specific models, enter one or more patterns in the Exclude models field. **For example, Llama-2* excludes all Llama 2 models, or *DeepSeek* excludes all models that contain DeepSeek in the name. **

d. Click Preview to view the available models based on your visibility settings. The preview shows which models are included and which are excluded based on your patterns. 

6. Optional: To enable the source in the catalog, select Enable source. When the source is disabled, the source is saved but models are not available to users. You can enable the source later after reviewing the configuration. 

7. Click Add to create the catalog source. 

Verification 

1. On the Model catalog settings page, verify that the new catalog source displays in the list. If you enabled the source, the validation status is Starting. Wait for the validation status to update to Connected. 

2. Click AI hub → Catalog. 

3. In the menu bar, verify that models from your new catalog source are displayed: 

If the source has no label, click Other models. 

If the source has a label, click <your-label-name> models. 

### CHAPTER 3. MANAGE A MODEL CATALOG SOURCE

You can manage an existing model catalog source to update the source configuration or to change the model visibility settings. You can manage both the default catalog sources and sources that you have added. 

Prerequisites 

You have logged in to the OpenShift AI dashboard as an administrator. 

Procedure 

1. In the OpenShift AI dashboard, click Settings → Model resources and operations → Model catalog settings. 

2. In the list of sources, find the source that you want to update, and click Manage source. 

3. Optional: Update the catalog source configuration: 

Name: Update the descriptive name for the catalog source. 

For a Hugging Face repository: In the Allowed organization field, update the Hugging Face **organization name to sync models from, for example, meta-llama or ibm-granite. **

NOTE 

You must enter the organization name used in the Hugging Face URL slug, **for example, meta-llama, and not the display name of Meta Llama. **

For a YAML file: In the Upload a YAML file field, drag and drop or upload your updated catalog YAML file. Alternatively, you can paste the contents of the YAML file into the text box. 

4. Optional: Update the model visibility settings to control which models are available to users: 

a. Click Model visibility. 

b. To include only specific models, enter one or more patterns in the Include models field. **For example, Llama* only includes model names that start with Llama. **

IMPORTANT 

For YAML sources, you must specify the full model name prefix including the organization. For Hugging Face sources, specify only the model name without the organization prefix. 

c. To exclude specific models, enter one or more patterns in the Exclude models field. **For example, Llama-2* excludes all Llama 2 models, or *DeepSeek* excludes all models that contain DeepSeek in the name. **

d. Click Preview to view the available models based on your visibility settings. The preview shows which models are included and which are excluded based on your patterns. 

5. Optional: Select or clear the Enable catalog source option to enable or disable the source in the catalog. 

6. Click Save to apply your changes. 

Verification 

1. On the Model catalog settings page, verify that the updated catalog source shows the correct configuration. If you enabled the source, wait for the validation status to update to Connected. 

2. Click AI hub → Catalog. 

3. Verify that the models from your updated catalog source reflect your changes: 

If the source has no label, click Other models. 

If the source has a label, click <your-label-name> models. 

### CHAPTER 4. DELETE A MODEL CATALOG SOURCE

You can delete a previously added catalog source to remove all of its models from the model catalog. 

NOTE 

You cannot delete the default catalog sources. 

Prerequisites 

You have logged in to the OpenShift AI dashboard as an administrator. 

You have added a model catalog source. 

Procedure 

1. In the OpenShift AI dashboard, click Settings → Model resources and operations → Model catalog settings. 

2. In the list of sources, find the source that you want to delete. 

3. Click the action menu (⋮) for the catalog source, and then click Delete. 

4. In the Delete a source dialog, enter the source name to confirm the deletion. 

5. Click Delete to confirm the deletion. 

Verification 

1. On the Model catalog settings page, verify that the deleted catalog source no longer displays in the list. 

2. Click AI hub → Catalog. 

3. Verify that models from the deleted catalog source are no longer available in the catalog. 

### CHAPTER 5. CONFIGURE MODEL CATALOG SOURCES IN OPENSHIFT

As an OpenShift cluster administrator, you can configure a custom model catalog source by adding an **entry to the model-catalog-sources config map in OpenShift. This entry provides details such as the **catalog name and the location of the catalog source file that specifies your model definitions. 

Prerequisites 

You are logged in to the OpenShift web console with cluster administrator privileges. 

You have created a catalog source file that specifies your model definitions. For an example catalog source file, see the sample-catalog.yaml file from Kubeflow Model Registry. 

Procedure 

**1. In the OpenShift web console navigation menu, click Workloads → ConfigMaps. **

**2. In the Project list, enter rhoai-model-registries, and click the project name. **

3. Click the model-catalog-sources config map name. 

**4. Click the YAML tab to view the contents of the config map .yaml file. **

**5. Find the data: sources.yaml section to add your custom catalog source. **

**6. Add a new entry under the catalogs field, for example: **

**This example adds the sample-catalog.yaml file in the same config map as a sibling of sources.yaml and references the sample catalog file in the yamlCatalogPath property. **

The sample catalog source entry is described as follows: 

**name: The user-friendly name of the catalog source. **

**id: The unique ID of the catalog source. **

**type: The catalog source type. Use yaml. **

**enabled: Whether the catalog source is enabled. Defaults to true. **

data:   sources.yaml: |-    catalogs:      - name: Sample Catalog        id: sample_custom_catalog        type: yaml        enabled: true        properties:         yamlCatalogPath: sample-catalog.yaml        labels:        - Sample Catalog   sample-catalog.yaml: |-     <contents of your catalog file> 

**properties.yamlCatalogPath: The location of your catalog source file. **

**labels: Optional labels for your catalog source to display in the catalog. **

7. Click Save. 

NOTE 

**Configuring custom model catalog sources is not supported on the s390x **architecture. 

Verification 

**1. In the OpenShift AI dashboard, click AI hub → Catalog. **

2. In the menu bar, to view models from your new catalog source: 

If your catalog source has no label, click Other models. 

If your catalog source has a label, click <your-label-name> models. 

NOTE 

These changes might take a few minutes to be displayed in the catalog on the dashboard. 

Additional resources 

Open Data Hub Model Registry documentation on configuring catalog sources 