# Red_Hat_OpenShift_AI_Self-Managed-3.5-Working_with_the_model_catalog-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Working with the model catalog

Working with the model catalog in Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Working with the model catalog

Working with the model catalog in Red Hat OpenShift AI Self-Managed

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

Discover and evaluate generative AI models in the AI hub model catalog and select models to register, deploy, and customize.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

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

CHAPTER 1. MODEL CATALOG AND MODEL REGISTRIES 1.1. MODEL CATALOG 1.2. MODEL REGISTRY 

CHAPTER 2 DISCOVER MODELS IN THE MODEL CATALOG 

CHAPTER 3 OPERATIONAL MODEL METRICS IN THE MODEL CATALOG 3.1. COLD START LOAD TIME 3.2. RUNTIME COMMAND 3.3. MINIMUM VRAM 3.4. CONTAINER SIZE 

CHAPTER 4 MODEL PERFORMANCE VIEW 

CHAPTER 5 VIEW PERFORMANCE DATA FOR VALIDATED MODELS 

CHAPTER 6 TENSOR TYPES AND MODEL VARIANTS 

CHAPTER 7 FILTER MODEL CATALOG BY TENSOR TYPE 

CHAPTER 8 SAFETY AND SECURITY EVALUATION DATA IN THE MODEL CATALOG 8.1. EVALUATION CATEGORIES 8.2. EVALUATION SCORE COMPUTATION 8.3. MODELS WITHOUT SECURITY EVALUATION DATA 8.4. SCOPE AND LIMITATIONS 8.5. DISCONNECTED ENVIRONMENT SUPPORT 

CHAPTER 9 VIEW SAFETY AND SECURITY INSIGHTS FOR A MODEL 

CHAPTER 10 FILTER AND SORT SAFETY AND SECURITY EVALUATION RESULTS 

CHAPTER 11 REGISTER A MODEL FROM THE MODEL CATALOG 

CHAPTER 12. DEPLOY A MODEL FROM THE MODEL CATALOG 

3 

4 4 4 

5 

8 8 8 8 8 

10 

11 

13 

14 

15 15 15 15 16 16 

17 

18 

19 

21 

### PREFACE

As a data scientist or AI engineer in OpenShift AI, you can discover and evaluate the generative AI models that are available in the AI hub model catalog. From the model catalog, you can select the models to register, deploy, and customize. 

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

### CHAPTER 2. DISCOVER MODELS IN THE MODEL CATALOG

You can discover and evaluate the available gen AI models in the model catalog to find the best fit for your use cases. You can select from available model categories, search by text, and filter by labels. 

For validated models, you can view performance benchmark data for specific hardware configurations and safety and security evaluation results to evaluate and compare options for deployment. 

Prerequisites 

You are logged in to the Red Hat OpenShift AI dashboard. 

The model registry component is enabled in your OpenShift AI deployment. For more information, see Enabling the model registry component. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Models → Catalog. The Catalog page displays a high-level view of available models, including the model category, name, description, and labels such as task, license, and provider. You can also view performance benchmark data for third-party validated models. 

2. In the menu bar, select from the available model categories: 

All models: All models available in the model catalog. 

Red Hat AI models: Models provided and supported by Red Hat. 

Red Hat AI validated models: Third-party models benchmarked by Red Hat for performance and quality by using open-source evaluation datasets. 

Other models: Custom third-party and community models configured by your administrator that do not have any catalog source labels. This category is only displayed if there are catalog sources without labels. Otherwise, custom models with labels configured by your administrator are displayed in a category with the same name as the label set for the custom catalog source. 

NOTE 

**On the s390x architecture, only the granite-3.3-8b-instruct model is supported. **Its model card is available from the All models category in the menu bar of the model catalog. 

3. Use the search bar to find a model in the catalog. Enter text to search by model name, description, or provider. 

4. Use the filter menu to search and select filters by the following labels: 

**Task: For example, Text-generation. **

**Provider: For example, Meta. **

**License: For example, Apache 2.0. **

**Language: For example, Japanese. **

**Tensor type: For example, BF16. **

5. Click the name of a model to view the model details page. This page displays the model description and the Model card information supplied by the model provider. This includes details such as the model’s intended use and potential limitations, training parameters and datasets, and evaluation results. The Model details section on the right side of the page shows key model properties. For validated models, the Model details section includes the following infrastructure fields: 

Minimum vRAM: The minimum GPU memory, in GiB, required to load and serve this model. 

Container size: The size of the model container image in GiB. 

6. For validated models, click the Performance insights tab to compare performance metrics for specific hardware configurations and identify the most suitable options for deployment. You can filter the performance data by the following options: 

Workload type: Select a workload type to view performance for different input and output **token lengths, for example, Chatbot. **

Latency: Set your maximum acceptable latency. Hardware configurations with response times above this value are not displayed. You can select a specific metric in the list: 

**E2E (end-to-end request latency): The time taken from submitting the request to **receiving the final response. 

**TTFT (time to first token): The time that the user must wait before seeing output from **the model. 

**TPS (tokens per second): The total number of tokens that are output per second. **

**ITL (inter-token latency): The average time taken between consecutive tokens. You can also select a percentile value, for example, P90. **

Use the slider to set the maximum acceptable latency value in milliseconds, and click Apply filter. 

Max RPS: Set your target traffic load in requests per second. The catalog uses this value to calculate the recommended number of replicas for reliable performance at the specified load. Use the slider to set the target requests per second value, and click Apply filter. 

**Hardware: Select one or more hardware types from the list, for example, H200. **You can click Clear all filters to reset your filters and try again. 

The Performance insights table also displays the following columns for each hardware configuration: 

Cold start load time: The time, in seconds, that vLLM takes to load the model weights into GPU memory for this hardware configuration. This does not include the time to pull the container image or download model weights. 

Runtime command: The vLLM command used during benchmark validation for this hardware configuration. Click View in this column to open a popover displaying the command in copyable format. 

For background on what each metric measures, see Operational model metrics in the model catalog. 

7. For models with safety and security evaluation data, click the Safety and security insights tab to view pre-computed evaluation results for the model, including evaluation scores across benchmarks for risk vectors such as prompt injection, jailbreak resistance, and harmful content generation. 

8. For categories with more than 10 models, you can click Load more models to scroll and view additional models available in the catalog. Repeat this step until all models are loaded. 

Verification 

For all models, you can view the information about a selected model on the model details page. 

When you click a model name, the model details page displays the model name heading, the Model card content section, and the Model details sidebar. 

For validated models, you can view the benchmark information about a selected model on the Performance Insights tab. 

For models with safety and security evaluation data, you can view evaluation results on the Safety and security insights tab. 

### CHAPTER 3. OPERATIONAL MODEL METRICS IN THE MODEL CATALOG

Validated models in the OpenShift AI model catalog include operational metrics that help you evaluate whether a model fits your deployment infrastructure before you commit to registering or deploying it. 

Use them to match models to your available hardware without consulting engineering teams separately. 

The model catalog displays four operational metrics for validated models: 

Cold start load time 

Runtime command 

Minimum vRAM 

Container size 

Cold start load time and runtime command are displayed in the Performance insights tab. Minimum vRAM and container size are displayed in the Model details section on the right side of the model details page. 

3.1. COLD START LOAD TIME 

Cold start load time is the time, measured in seconds, that vLLM requires to load the model weights into GPU memory after the weights have been downloaded and copied into the container. It does not include image pull time or model weight download time. 

Because the time to load model weights into GPU memory depends on GPU hardware, cold start load time differs by GPU type and GPU count. 

3.2. RUNTIME COMMAND 

The runtime command is the vLLM command used to start the model server during benchmark validation for a given hardware configuration. Click View in the Runtime command column on the Performance insights tab to open a popover that displays the command in copyable format. 

You can use the runtime command to reproduce the exact benchmark conditions, audit the configuration used during validation, or derive a starting point for your own deployment. 

3.3. MINIMUM VRAM 

Minimum vRAM is the minimum amount of GPU memory, in GiB, required to load and serve the model. Minimum vRAM does not vary by hardware configuration. 

Use minimum vRAM to verify that your target GPU has enough memory before committing to a model. The Minimum vRAM sidebar slider in the catalog filters the model list to exclude models whose minimum vRAM requirement exceeds the value you set. 

3.4. CONTAINER SIZE 

Container size is the size of the model container image in GiB. 

Use container size to plan available node storage and to estimate image pull time in your environment. The Container size sidebar slider in the catalog filters the model list to exclude models whose container image exceeds the size you set. 

Additional resources 

Discover and evaluate models in the model catalog 

### CHAPTER 4. MODEL PERFORMANCE VIEW

The Model performance view displays only validated models in the model catalog. You can filter models based on advanced workload, hardware, and infrastructure constraints. Pareto-optimal filtering determines the recommended hardware configurations, output token throughput, and latency metrics by providing non-dominated options across all performance dimensions. 

When you select a validated model card in the catalog, the active performance filter constraints transfer to the Performance insights tab on the model details page. You can immediately compare compression variants and hardware options against the specified constraints in the catalog. This streamlines the process of moving from initial discovery to selecting the optimal model and hardware combination for a specific production workload. 

Modifying the performance filter settings changes all the displayed model cards and their content to align with the applied constraints. Disabling and enabling the Model performance view resets the performance filter to the default settings. 

When you enable the Model performance view, models appear in Pareto-optimal ranking order, which prioritizes non-dominated options across all performance dimensions. The model cards display only validated models and show performance data with labels. In addition, the time to first token, inter-token, and end-to-end latency metrics change according to the workload and performance constraint filters you select. 

The Model performance view enables two categories of filters: 

Workload and latency filters 

These filters govern which benchmark performance data is displayed for each model and hardware configuration. The available filters are Workload type, Latency, Max RPS (maximum requests per second), and Hardware. 

Infrastructure constraint filter 

This filter screens models based on startup latency, narrowing the catalog to models that meet your cold start time requirement before you examine individual model details. The available toolbar filter is Cold start load time. 

Additional resources 

Operational model metrics in the model catalog 

### CHAPTER 5. VIEW PERFORMANCE DATA FOR VALIDATED MODELS

You can use the Model performance view to display only validated models and filter by workload, hardware, and infrastructure constraints such as cold start load time, minimum vRAM, and container size. 

For background on the infrastructure metrics, see Operational model metrics in the model catalog . 

Prerequisites 

You are logged in to the Red Hat OpenShift AI dashboard. 

Procedure 

1. In the OpenShift AI dashboard, click AI hub → Models → Catalog. 

2. Click the Model performance view toggle in the left filter pane of the catalog. This enables the performance filters and infrastructure constraint filters, displays model benchmark data, excludes unvalidated models, and orders models by Pareto-optimal ranking. 

3. Optional: Review the default workload and latency filter settings and adjust them for your use case. The default settings are as follows: 

Workload type: Chatbot 

Latency: Time to first token for 90th percentile 

Max RPS: 1 

Hardware: none In addition to these workload filters, the Model performance view enables the Cold start load time toolbar filter, which screens models based on startup latency. The Minimum vRAM and Container size sliders in the left filter pane are available in both the baseline catalog view and the Model performance view. 

4. Optional: In the toolbar, click Cold start load time and use the slider to set your maximum acceptable cold start load time in seconds. The catalog does not display models whose cold start load time exceeds this value. 

5. Optional: In the left filter pane, use the Minimum vRAM slider to set the maximum GPU memory requirement you can support. Use the slider to set the maximum GiB value, and click Apply filter. The catalog does not display models whose minimum vRAM requirement exceeds this value. 

6. Optional: In the left filter pane, use the Container size slider to set the maximum container image size you can support. Use the slider to set the maximum GiB value, and click Apply filter. The catalog does not display models with a container image larger than this value. 

7. To apply the active performance filters to a specific model, click the model name on a model card. The performance filters transfer automatically to the Performance insights tab for the model. 

8. To transfer the filter changes made on the Performance insights tab back to the model catalog, click Catalog in the breadcrumb navigation. 

NOTE 

This transfer occurs only if you enable the Model performance view before accessing the model details. Returning to the model catalog by using the Models link in the left navigation panel deactivates the Model performance view. 

9. Optional: On the Performance insights tab for a model, click Customize columns to add or remove columns from the Performance insights table. The performance filters do not need to be active to customize columns. 

Verification 

The model catalog displays only validated models, ordered by Pareto-optimal ranking across all performance dimensions. 

Each model card displays hardware, replicas, and time to first token latency instead of the model description. 

Models that do not meet your infrastructure constraint filter values are not displayed. 

### CHAPTER 6. TENSOR TYPES AND MODEL VARIANTS

Each tensor type is a compression variant of the same base model, which means that the same model can have multiple variants with different trade-offs in performance. All models include tensor type and size on their details page in the model catalog. 

A validated model can have multiple variants, each with a different tensor type. For example, the Llama-3-8B model can have the following variants: 

Llama-3-8B-FP16 (16-bit floating point) - full precision, highest quality, heavier resource requirements. 

Llama-3-8B-INT8 (8-bit integer) - quantized to 8 bits, good balance between quality and efficiency. 

Llama-3-8B-INT4 (4-bit integer) - quantized to 4 bits, lightest, lower accuracy. 

Each model variant has its own performance artifacts: recommended hardware, throughput, and latency can vary significantly between them. 

Pareto-optimal filtering takes model variants into account when recommending configurations in the catalog. For example, an INT4 variant can achieve the same requests per second with less hardware than an FP16 variant. 

### CHAPTER 7. FILTER MODEL CATALOG BY TENSOR TYPE

You can use a model’s Performance Insights tab to compare model variants based on tensor types and to decide which variant best fits your deployment requirements such as hardware cost and response quality. 

NOTE 

The Performance Insights tab includes a Model variants by tensor type comparison card only for validated models that have variants. 

Prerequisites 

You are logged in to the Red Hat OpenShift AI dashboard. 

Procedure 

1. In the OpenShift AI dashboard, click AI hub → Models → Catalog. 

2. In the filter pane on the left, scroll down to the filter options for Tensor type. 

3. Select one or more tensor types, for example, FP16 (16-bit floating point) and BF16 (brain floating point). The model catalog is filtered to show only models that have variants matching the selected tensor types. 

NOTE 

The Tensor type filter is always available and works regardless of whether the Model performance view toggle is enabled. 

4. Click a validated model to display its model details. 

5. Click the Performance Insights tab. This tab contains a Model variants by tensor type comparison card for compression variants based on tensor types. 

6. Click a model compression variant to visually assess the trade-off between compression and quality for the selected model in the metrics displayed on the Performance Insights tab. 

NOTE 

If you enabled the Model performance view and set active filters in the catalog, those filters are automatically carried over to the Performance Insights tab. 

Verification 

The catalog displays only models with variants matching the selected tensor types. 

The Performance Insights tab for a selected model displays the Model variants by tensor type comparison card. 

### CHAPTER 8. SAFETY AND SECURITY EVALUATION DATA IN THE MODEL CATALOG

The Safety and security insights tab on the model catalog detail page displays pre-computed AI security evaluation results for each model. You can use these results to assess a model’s safety and security posture before you register or deploy it. 

Red Hat evaluates models in the default model catalog for AI-specific safety and security risks by using adversarial evaluation scans. The evaluation benchmarks table organizes results by category, benchmark, and evaluation score. You can review these results to make informed deployment decisions based on a model’s resistance to risk vectors such as prompt injection, jailbreak attempts, harmful content generation, toxicity, and data leakage. 

8.1. EVALUATION CATEGORIES 

Safety and security evaluations fall into the following categories: 

System Prompt Override / Prompt Injection 

Evaluates a model’s resistance to attacks that override the system prompt or inject malicious instructions through user input. 

Compliance / Jailbreak Resistance 

Evaluates a model’s compliance with usage policies and its resistance to attempts to bypass safety constraints. 

Augmented System Prompt Override 

Evaluates a model’s resistance to augmented attack variants that combine system prompt override with additional context manipulation techniques. 

Composite Vulnerability Summary 

Provides an aggregated score across multiple vulnerability categories to summarize the model’s overall security posture. 

Each category is displayed in the evaluation benchmarks table to help you identify and compare results by security risk area. 

8.2. EVALUATION SCORE COMPUTATION 

Evaluation scores represent the normalized, weighted value of the benchmark primary metric, such as accuracy or resilience. Scores are displayed as percentages in the evaluation benchmarks table. 

Red Hat pre-computes evaluation results by using adversarial evaluation scans. The scans cover risk vectors aligned with industry frameworks, including the Open Worldwide Application Security Project (OWASP) Top 10 for Large Language Model Applications and the AI Vulnerability Database (AVID) taxonomy. Red Hat packages and ships the evaluation data as part of the model catalog release. 

8.3. MODELS WITHOUT SECURITY EVALUATION DATA 

Not all models in the catalog have safety and security evaluation data at any given time. The availability of evaluation data depends on the scope of the Red Hat scanning pipeline for each release. 

**If a model was not evaluated, the Safety and security insights tab displays a No safety and security insights message. This state indicates that the model was not scanned and it is not an error condition. **

8.4. SCOPE AND LIMITATIONS 

Safety and security evaluation data has the following scope and limitations: 

Pre-computed results 

Evaluation results are pre-computed by Red Hat on a per-release cadence. Results are not generated in real time or on-demand. 

Not a formal certification 

Evaluation results do not constitute a formal security certification, compliance attestation, or security guarantee. 

AI-specific risk vectors only 

Evaluations cover AI-specific safety and security vectors only. Traditional software vulnerabilities such as CVEs and National Vulnerability Database (NVD) entries are not in scope. 

Default catalog models only 

Only models in the Red Hat AI default model catalog are evaluated. Red Hat does not evaluate useruploaded or custom catalog source models. 

No pass/fail certification 

Evaluation results provide scores for comparison and assessment. They do not provide pass/fail certification. 

Current release only 

Evaluation results reflect the current release. Historical comparison of results across releases is not available. 

8.5. DISCONNECTED ENVIRONMENT SUPPORT 

Safety and security evaluation data is available in disconnected and air-gapped environments without additional configuration. Red Hat pre-computes evaluation results, packages them as static content in the OCI image, and ingests them into the Model Catalog Server database during deployment. You do not need external network access to view evaluation results at runtime. The container image bundles all UI assets with no external content delivery network (CDN) dependencies. 

### CHAPTER 9. VIEW SAFETY AND SECURITY INSIGHTS FOR A MODEL

You can view pre-computed safety and security evaluation results for a model in the catalog to assess its security posture before you register or deploy it. The Safety and security insights tab displays an evaluation benchmarks table with scores for risk vectors such as prompt injection, jailbreak resistance, and harmful content generation. 

Prerequisites 

You are logged in to the Red Hat OpenShift AI dashboard. 

The model registry component is enabled in your OpenShift AI deployment. For more information, see Enabling the model registry component. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Models → Catalog. 

2. Click the name of a model to open the model details page. 

3. Click the Safety and security insights tab. 

4. Review the evaluation benchmarks table, which displays the following columns: Evaluation name, Category, Benchmark, and Evaluation score. 

5. Review evaluation scores displayed as percentages to assess the model’s security posture across benchmarks. 

Verification 

**The evaluation benchmarks table displays results for the selected model, or the No safety and security insights state for models without security evaluation data. **

### CHAPTER 10. FILTER AND SORT SAFETY AND SECURITY EVALUATION RESULTS

You can filter and sort the evaluation benchmarks table on the Safety and security insights tab to focus on specific risk areas or evaluation categories. Filtering helps you identify the benchmarks most relevant to your deployment requirements. 

Prerequisites 

You are logged in to the Red Hat OpenShift AI dashboard. 

You are viewing a model’s Safety and security insights tab. For more information, see View safety and security insights for a model. 

Procedure 

1. On the Safety and security insights tab, select a filter type from the filter dropdown: Evaluation name, Category, or Benchmark. 

2. Enter search text in the filter input field to narrow the displayed results. 

3. To sort results, click any column header to toggle between ascending and descending order. 

4. To clear all applied filters, click Clear all filters to reset the table view. 

5. Use the pagination controls at the bottom of the table to navigate through results when there are more benchmarks than fit on a single page. 

Verification 

The evaluation benchmarks table displays filtered results matching the selected criteria, or all results after clearing filters. 

### CHAPTER 11. REGISTER A MODEL FROM THE MODEL CATALOG

As a data scientist or AI engineer, you can register models directly from the model catalog and create the first version of the new model. 

Prerequisites 

You are logged in to Red Hat OpenShift AI. 

You have access to an available model registry in your deployment. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Models → Catalog. 

2. The Catalog page provides a high-level view of available models, including the model category, name, description, and labels such as task, license, and provider. 

3. You can use the search bar to search by model name, description, or provider. 

4. You can use the filter menu to search and select filters by task, provider, or license. 

5. Click the name of a model to view the model details page. 

6. Click Register model. 

7. From the Model registry drop-down list, select the model registry that you want to register the model in. 

8. In the Model details section, configure details to apply to all versions of the model: 

a. Optional: In the Model name field, update the name of the model. 

b. Optional: In the Model description field, update the description of the model. 

9. In the Version details section, enter details to apply to the first version of the model: 

a. In the Version name field, enter a name for the model version. 

b. Optional: In the Version description field, enter a description for the first version of the model. 

**c. In the Source model format field, enter the name of the model format, for example, ONNX. **

d. In the Source model format version field, enter the version of the model format. 

10. In the Model location section, the URI of the model is displayed. 

11. Click Register model. 

NOTE 

**Registering models from the model catalog is not supported on the s390x **architecture. 

Verification 

The new model details and version are displayed on the Overview tab on the model details page. 

The new model and version are displayed on the Model registry page. 

### CHAPTER 12. DEPLOY A MODEL FROM THE MODEL CATALOG

You can deploy models directly from the model catalog. 

NOTE 

OpenShift AI model serving deployments use the global cluster pull secret to pull models in OCI-compliant ModelCar format from the catalog. 

For more information about using pull secrets in OpenShift, see Updating the global cluster pull secret in the OpenShift documentation. 

Prerequisites 

You have completed the prerequisites in Deploying models . 

The model registry component is enabled in your OpenShift AI deployment. For more information, see Enabling the model registry component. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Models → Catalog. 

2. The Catalog page provides a high-level view of available models, including the model category, name, description, and labels such as task, license, and provider. 

3. You can use the search bar to search by model name, description, or provider. 

4. You can use the filter menu to search and select filters by task, provider, or license. 

5. Click the name of a model to view the model details page. 

6. Click Deploy model to display the Deploy a model wizard. 

7. On the Model details page, in the Model type field, you can select Generative AI model or Predictive model. The default model type in the catalog is generative. 

NOTE 

For models in the catalog, the Model details page displays read-only information in the Model location and URI fields. 

8. In the Model deployment page, configure the deployment as follows: 

a. From the Project list, select the project in which to deploy your model. 

b. In the Model deployment name field, enter a unique name for your model deployment. This field is autofilled with the model name by default. This is the name of the inference service created when the model is deployed. 

c. Optional: Click Edit resource name, and enter a specific name in the Resource name field. By default, the resource name matches the name of the model deployment. 

IMPORTANT 

Resource names are what your resources are labeled as in OpenShift. Your resource name cannot exceed 253 characters, must consist of lowercase *alphanumeric characters or -, and must start and end with an alphanumeric *character. You cannot edit resource names after creation. 

The resource name must not match the name of any other model deployment resource in your OpenShift cluster. 

d. In the Description field, enter a description of your deployment. 

e. From the Hardware profile list, select a hardware profile. Models provided in the catalog **use the default-profile. **

f. Optional: To modify the default resource allocation, click Customize resource requests and limits and enter new values for the CPU and memory requests and limits. 

g. In the Serving runtime field, select one of the following options: 

Auto-select the best runtime for your model based on model type, model format, and hardware profile The system analyzes the selected model framework and your available hardware profiles to recommend a serving runtime. 

Select from a list of serving runtimes, including custom ones Select this option to manually choose a runtime from the list of global and projectscoped serving runtime templates. 

For more information about how the system determines the best runtime and administrator overrides, see Automatic selection of serving runtimes. 

h. Optional: For predictive AI models only, you can select a framework from the Model framework (name - version) list. This field is not displayed for generative AI models. 

i. In the Number of model server replicas to deploy field, specify a value. 

j. Click Next. 

9. On the Advanced settings page, configure the following options: 

Select the Add as AI asset endpoint checkbox if you want to add your gen AI model endpoint to the Gen AI studio → AI asset endpoints page. 

In the Use case field, enter the types of tasks that your model performs, such as chat, multimodal, or natural language processing. 

NOTE 

You must add your model as an AI asset endpoint to test your model on the Gen AI studio → playground page. 

To require token authentication for inference requests to the deployed model, select Require token authentication. 

In the Service account name field, enter the service account name that the token will be generated for. 

To add an additional service account, click Add a service account and enter another service account name. 

In the Configuration parameters section: 

Select Add custom runtime arguments, and then enter arguments in the text field. 

Select Add custom runtime environment variables, and then click Add variable to enter custom variables in the text field. 

In the Deployment strategy section, select one of the following options: 

*Rolling update: Existing inference service pods are terminated after new pods are *started. This ensures zero downtime and continuous availability. This is the default option. 

*Recreate: Existing inference service pods are terminated before new pods are started. *This saves resources but guarantees a period of downtime. 

10. On the Review page, review the settings that you have selected before deploying the model. 

11. Click Deploy model. 

NOTE 

**Advanced settings are not supported on the s390x architecture. **

Verification 

The model deployment is displayed in the following places in the dashboard: 

The AI hub → Deployments page. 

The Latest deployments section of the model details page. 

The Deployments tab for the model version. 

Additional resources 

Deploying models on the model serving platform . 