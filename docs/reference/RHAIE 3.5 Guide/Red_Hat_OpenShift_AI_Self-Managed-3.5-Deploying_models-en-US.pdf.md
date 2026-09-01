# Red_Hat_OpenShift_AI_Self-Managed-3.5-Deploying_models-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Deploying models

Deploy models in Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Deploying models

Deploy models in Red Hat OpenShift AI Self-Managed

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

As a Red Hat OpenShift AI user, you can deploy your machine-learning models in Red Hat OpenShift AI Self-Managed.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

PREFACE 

CHAPTER 1. STORING MODELS 1.1. OCI-BASED MODEL STORAGE 1.2. STORE A MODEL IN AN OCI IMAGE 1.3. UPLOAD MODEL FILES TO A PERSISTENT VOLUME CLAIM 

CHAPTER 2 DEPLOYING MODELS 2.1. ABOUT KSERVE DEPLOYMENT MODES 2.2. AUTOMATIC SELECTION OF SERVING RUNTIMES 

2.2.1. Hardware profile matching 2.2.2. Predictive model selection 2.2.3. Selection limitations 2.2.4. Manual serving runtime selection 2.2.5. Administrator overrides 

2.3. SERVING RUNTIME BADGES 2.4. DEPLOYMENT STRATEGIES FOR RESOURCE OPTIMIZATION 

2.4.1. Choosing a deployment strategy 2.5. CANARY ROLLOUT FOR MODELS IN RAWDEPLOYMENT MODE 2.6. PERFORM A CANARY ROLLOUT FOR AN INFERENCESERVICE 2.7. CANARY FIELD API REFERENCE FOR INFERENCESERVICE 2.8. KNOWN LIMITATIONS FOR CANARY ROLLOUT IN RAWDEPLOYMENT MODE 2.9. DEPLOY MODELS ON THE MODEL SERVING PLATFORM 2.10. DEPLOY MODELS BY USING THE MLSERVER RUNTIME 2.11. DEPLOY A MODEL FROM AN OCI IMAGE BY USING THE CLI 2.12. MONITORING MODELS 

2.12.1. View performance metrics for a deployed model 2.12.2. View model-serving runtime metrics for the model serving platform 

CHAPTER 3 DEPLOYING DIFFUSIONGEMMA MODELS 3.1. DIFFUSIONGEMMA DISCRETE DIFFUSION LANGUAGE MODEL 

3.1.1. How block diffusion works 3.1.2. Available model variants 3.1.3. Known limitations 

3.2. DEPLOY A DIFFUSIONGEMMA MODEL 

CHAPTER 4 DEPLOYING MODELS ON THE NVIDIA NIM MODEL SERVING PLATFORM 4.1. DEPLOY MODELS ON THE NVIDIA NIM MODEL SERVING PLATFORM 4.2. VIEW NVIDIA NIM METRICS FOR A NIM MODEL 4.3. VIEW PERFORMANCE METRICS FOR A NIM MODEL 

CHAPTER 5 PRECACHE MODELS FOR FASTER DEPLOYMENT 5.1. CACHE A MODEL ON CLUSTER NODES 5.2. CACHE A MODEL WITHIN A NAMESPACE 5.3. MONITOR MODEL CACHE DOWNLOAD STATUS 5.4. DEPLOY AN INFERENCESERVICE WITH A CACHED MODEL 5.5. DEPLOY AN LLMINFERENCESERVICE WITH A CACHED MODEL 5.6. MODEL CACHE CUSTOM RESOURCE DEFINITIONS 

5.6.1. LocalModelCache 5.6.2. LocalModelNamespaceCache 5.6.3. LocalModelNodeGroup 5.6.4. LocalModelNode 

4 

5 5 5 7 

9 9 

10 10 10 10 11 11 11 

12 12 14 15 19 22 23 27 30 32 32 34 

35 35 35 35 35 36 

38 38 40 41 

43 43 45 46 48 50 51 51 

53 53 55 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

5.6.5. NodeStatus and ModelStatus values 

CHAPTER 6 MAKING INFERENCE REQUESTS TO DEPLOYED MODELS 6.1. ACCESS THE AUTHENTICATION TOKEN FOR A DEPLOYED MODEL 6.2. ACCESS THE INFERENCE ENDPOINT FOR A DEPLOYED MODEL 6.3. INFERENCE REQUESTS TO DEPLOYED MODELS 6.4. INFERENCE ENDPOINTS 

6.4.1. Caikit TGIS ServingRuntime for KServe 6.4.2. OpenVINO Model Server 6.4.3. vLLM NVIDIA GPU ServingRuntime for KServe 6.4.4. vLLM Intel Gaudi Accelerator ServingRuntime for KServe 6.4.5. vLLM AMD GPU ServingRuntime for KServe 6.4.6. vLLM Spyre AI Accelerator ServingRuntime for KServe 6.4.7. vLLM Spyre s390x ServingRuntime for KServe 6.4.8. vLLM Spyre ppc64le ServingRuntime for KServe 6.4.9. NVIDIA Triton Inference Server 6.4.10. MLServer ServingRuntime for KServe 6.4.11. Additional resources 

56 

58 58 58 59 59 59 59 60 61 61 61 61 61 61 

62 63 

### PREFACE

Deploy trained models on the OpenShift AI model-serving platform. 

### CHAPTER 1. STORING MODELS

You must store your model before you can deploy it. You can store a model in an S3 bucket, URI or Open Container Initiative (OCI) containers. 

1.1. OCI-BASED MODEL STORAGE 

As an alternative to storing a model in an S3 bucket or URI, you can upload models to Open Container Initiative (OCI) containers. Deploying models from OCI containers is also known as modelcars in KServe. 

Using OCI containers for model storage can help you: 

Reduce startup times by avoiding downloading the same model multiple times. 

Reduce disk space usage by reducing the number of models downloaded locally. 

Improve model performance by allowing pre-fetched images. 

Using OCI containers for model storage involves the following tasks: 

Storing a model in an OCI image. 

Deploying a model from an OCI image by using either the user interface or the command line interface. To deploy a model by using: 

*The user interface, see Deploying models on the model serving platform *. 

*The command line interface, see Deploying a model stored in an OCI image by using the CLI *. 

Additional resources 

Deploying models on the model serving platform 

Deploying a model stored in an OCI image by using the CLI 

1.2. STORE A MODEL IN AN OCI IMAGE 

You can store a model in an OCI image. The following procedure uses the example of storing a MobileNet v2-7 model in ONNX format. 

Prerequisites 

You have a model in the ONNX format. The example in this procedure uses the MobileNet v2-7 model in ONNX format. 

You have installed the Podman tool. 

Procedure 

1. In a terminal window on your local machine, create a temporary directory for storing both the model and the support files that you need to create the OCI image: 

cd $(mktemp -d) 

**2. Create a models folder inside the temporary directory: **

mkdir -p models/1 

NOTE 

**This example command specifies the subdirectory 1 because OpenVINO requires **numbered subdirectories for model versioning. If you are not using OpenVINO, **you do not need to create the 1 subdirectory to use OCI container images. **

3. Download the model and support files: 

DOWNLOAD_URL=https://github.com/onnx/models/raw/main/validated/vision/classification/mob ilenet/model/mobilenetv2-7.onnx curl -L $DOWNLOAD_URL -O --output-dir models/1/ 

**4. Use the tree command to confirm that the model files are located in the directory structure as **expected: 

tree 

**The tree command should return a directory structure similar to the following example: **

. ├── Containerfile └── models     └── 1         └── mobilenetv2-7.onnx 

**5. Create a Docker file named Containerfile: **

NOTE 

**Specify a base image that provides a shell. In the following example, ubi9-micro is the base container image. You cannot specify an empty image that does not provide a shell, such as scratch, because KServe uses the shell to **ensure the model files are accessible to the model server. 

Change the ownership of the copied model files and grant read permissions to the root group to ensure that the model server can access the files. OpenShift runs containers with a random user ID and the root group ID. 

FROM registry.access.redhat.com/ubi9/ubi-micro:latest COPY --chown=0:0 models /models RUN chmod -R a=rX /models + 

# nobody user USER 65534 

**6. Use podman build commands to create the OCI container image and upload it to a registry. **The following commands use Quay as the registry. 

NOTE 

If your repository is private, ensure that you are authenticated to the registry before uploading your container image. 

podman build --format=oci -t quay.io/<user_name>/<repository_name>:<tag_name> . podman push quay.io/<user_name>/<repository_name>:<tag_name> 

1.3. UPLOAD MODEL FILES TO A PERSISTENT VOLUME CLAIM 

When deploying a model, you can serve it from a preexisting Persistent Volume Claim (PVC) where your model files are stored. You can upload your local model files to a PVC in the IDE that you access from a running workbench. 

Prerequisites 

You have access to the OpenShift AI dashboard. 

You have access to a project that has a running workbench. 

You have created a persistent volume claim (PVC) with a context type of Model storage. 

The workbench is attached to the persistent volume (PVC). 

For instructions on attaching a PVC, see Creating a project workbench . 

You have the model files saved on your local machine. 

Procedure 

1. From the OpenShift AI dashboard, click the open icon (  ) to open your IDE in a new window. 

2. In your IDE, navigate to the File Browser pane on the left-hand side. 

a. In JupyterLab, this is usually labeled Files. 

b. In code-server, this is usually the Explorer view. 

**3. In the file browser, navigate to the /opt/app-root/src/ folder. This folder represents the root of **your attached PVC. 

NOTE 

Any files or folders that you create or upload to this folder persist in the PVC. 

4. Optional: Create a new folder to organize your models: 

**a. In the file browser, right-click within the /opt/app-root/src/ folder in the file browser and **select New Folder. 

**b. Name the folder (for example, models). **

**c. Double-click the new models folder to enter it. **

**5. Upload your model files to the current folder (/opt/app-root/src/ or /opt/app-root/src/models/): **

Using JupyterLab: 

a. Click the Upload Files icon (  ) in the file browser toolbar above the folder listing. 

b. In the file selection dialog, navigate to and select the model files from your local computer. Click Open. 

c. Wait for the upload progress bars next to the filenames to complete. 

Using code-server: 

a. Drag the model files directly from your local file explorer and drop them into the file browser pane in the target folder within code-server. 

6. Wait for the upload process to complete. 

Verification 

Confirm that your files appear in the file browser at the path where you uploaded them. 

Next steps 

When you follow the procedure to deploy a model, you can access the model files from the specified path within your PVC: 

1. In the Deploy model dialog, select Existing cluster storage under the Source model location section. 

2. From the Cluster storage list, select the PVC associated with your workbench. 

3. In the Model path field, enter the path to your model or the folder containing your model. 

### CHAPTER 2. DEPLOYING MODELS

The model serving platform is based on the KServe component and deploys each model from its own dedicated model server. This architecture is ideal for deploying, monitoring, scaling, and maintaining large models that require more resources, such as large language models (LLMs). 

2.1. ABOUT KSERVE DEPLOYMENT MODES 

KServe offers two deployment modes for serving models. The default mode, Knative Serverless, is based on the open-source Knative project and provides powerful autoscaling capabilities. It integrates with Red Hat OpenShift Serverless and Red Hat OpenShift Service Mesh. Alternatively, the KServe RawDeployment mode offers a more traditional deployment method with fewer dependencies. 

Before you choose an option, understand how your initial configuration affects future deployments: 

If you configure for Knative Serverless: You can use both Knative Serverless and KServe RawDeployment modes. 

If you configure for KServe RawDeployment only: You can only use the KServe RawDeployment mode. 

Use the following comparison to choose the option that best fits your requirements. 

Table 2.1. Comparison of deployment modes 

Criterion **Knative Serverless KServe RawDeployment **

Default mode Yes No 

Recommended use case 

Most workloads. Custom serving setups or models that must remain active. 

Autoscaling Scales up automatically based on request volume. 

Supports scaling down to zero when idle to save costs. 

No built-in autoscaling; you can configure Kubernetes Event-Driven Autoscaling (KEDA) or Horizontal Pod Autoscaler (HPA) on your deployment. 

Does not support scaling to zero by default, which might result in higher costs during periods of low traffic. 

Dependencies Red Hat Connectivity Link 

cert-manager Operator 

Leader Worker Set Operator 

Authorino. Required only if you enable token authentication and external routes. 

None; uses standard Kubernetes **resources such as Deployment, Service, and Horizontal Pod Autoscaler. **

Configuration flexibility 

Has some customization limitations inherited from Knative compared to raw Kubernetes deployments. 

Provides full control over pod specifications because it uses standard **Kubernetes Deployment resources. **

Resource footprint Larger, due to the additional dependencies required for serverless functionality. 

Smaller. 

Setup complexity Might require additional configuration in setup and management. If Serverless is not already installed on the cluster, you must install and configure it. 

Requires a simpler setup with fewer dependencies. 

Canary rollout Not supported. The **canaryTrafficPercent field is only used **for revision-based traffic splitting in Knative Serverless mode, but canary rollout functionality was only implemented for RawDeployment mode. 

**Supports canary rollout with the canary **field on the InferenceService spec. Creates explicit stable and canary Deployments with configurable traffic splitting through OpenShift Route **alternateBackends. For more **information, see Canary rollout for models in RawDeployment mode. 

Criterion **Knative Serverless KServe RawDeployment **

2.2. AUTOMATIC SELECTION OF SERVING RUNTIMES 

When you deploy a model, OpenShift AI can automatically select the best serving runtime for your deployment. This feature allows you to efficiently deploy applications without needing to manually research runtime compatibility. The system determines the optimal runtime by analyzing the model type, model format, and selected hardware profile. 

2.2.1. Hardware profile matching 

The system suggests a runtime by matching the accelerator defined in your selected hardware profile with available runtimes. For example, if you select a hardware profile that uses an NVIDIA GPU accelerator, the system filters for compatible runtimes, such as vLLM NVIDIA GPU ServingRuntime for KServe. 

NOTE 

Automatic selection is available only if a hardware profile exists for the specific accelerator that you want to use. 

2.2.2. Predictive model selection 

For predictive models, you must select a Model format before the system can determine the appropriate serving runtime. 

2.2.3. Selection limitations 

The Auto-select option is displayed only when the system can identify a single, distinct match. If multiple serving runtime templates are defined for the same accelerator, the system cannot determine the best option automatically, and the auto-select option is not displayed for that hardware profile. In such cases, you must manually select a runtime. 

2.2.4. Manual serving runtime selection 

You can manually select a specific runtime from the Serving runtime list if the automatically selected option does not meet your needs. This option is useful when you require a specific version of a runtime or want to use a custom runtime that you have added to the platform. The Serving runtime list displays all global and project-scoped serving runtime templates available to you. 

2.2.5. Administrator overrides 

Cluster administrator settings can override standard hardware profile matching. If the Use distributed inference with llm-d by default when deploying generative models option is enabled in the administrator settings, the system defaults to the Distributed inference with llm-d runtime, regardless of other potential matches. This option is available in Settings > Cluster settings > General settings. 

2.3. SERVING RUNTIME BADGES 

Visual badges in the model deployment wizard indicate vLLM runtime and accelerator configuration support levels, versions, and build types, helping you select appropriate resources for production workloads versus experimentation with newer features. 

Badge types 

The runtime selection dropdown in the model deployment workflow displays the following badge types: 

Limited support badge Indicates the runtime has a 1-month support coverage window after release. Your administrator has accepted the risk and enabled this limited-support runtime for your use. 

Version badge (for example, "0.6.1") Shows the upstream vLLM version number. Higher version numbers indicate newer vLLM features and model format support. 

Fast-N badge (for example, "fast-1") Indicates a fast build iteration number. Higher fast-N numbers represent newer monthly fast builds. 

Pre-installed label Indicates an Red Hat-provided runtime. Runtimes with the Pre-installed label are either GA runtimes (stable, full lifecycle support) or limited-support fast builds. 

No Pre-installed label Indicates a user-created custom runtime with no Red Hat support. Verify internal support coverage before using custom runtimes. 

Badge combinations and support levels 

Badge combination Support level Recommended use 

Pre-installed + Limited support + Version + Fast-N 

Limited support (1 month) 

Experimentation, accessing newest vLLM features, non-critical workloads 

Pre-installed + Version Full GA support Production workloads requiring long-term support 

No Pre-installed label No Red Hat support Use only with internal maintenance expertise 

Additional resources 

Understanding vLLM runtime support levels 

Deploying models on the single-model serving platform 

2.4. DEPLOYMENT STRATEGIES FOR RESOURCE OPTIMIZATION 

To optimize resource usage and manage downtime during model rollouts, you can configure the deployment strategy for your inference services. Choosing the appropriate strategy depends on your cluster’s available quotas, especially hardware accelerators such as GPUs, and your tolerance for service interruptions. 

There are two primary deployment strategies available for model serving: 

Rolling update 

This strategy ensures zero downtime and continuous availability of the model. New inference service pods start while the existing pods are running. Traffic is switched to the new pods only after they are fully ready, and then the old pods are terminated. However, rolling updates require increased resources like CPU, memory, and GPUs during the update process. Plan for approximately 200% of the pod requests as headroom during the transition because parallel instances exist briefly. 

Recreate 

This strategy prioritizes resource conservation over availability. All existing inference service pods are terminated before the new pods attempt to launch. However, this method requires a period of downtime. The model endpoint is unavailable and returns errors between the termination of the old pod and the readiness of the new pod. 

2.4.1. Choosing a deployment strategy 

Choose the deployment strategy that best fits your availability requirements and resource quotas. The following table compares the rolling update and recreate strategies. 

Strategy Description Resource impact Recommended scenarios 

Rolling update 

Replaces pods gradually to ensure zero downtime. Traffic switches to new pods only after they are fully ready. 

High: Requires approximately 200% of the request resources to host parallel instances during the transition. 

Production workloads: Environments where the model must remain accessible without interruption. 

High-quota clusters: Namespaces with sufficient headroom to accommodate parallel instances. 

Recreate Terminates the old pod before starting the new one. Service is unavailable during the transition. 

Low: Consumption does not exceed 100%. Prevents *Insufficient Resources errors. *

Resource-constrained environments: Projects using scarce hardware, such as high-end GPUs, where double allocation is not possible. 

Development and staging: Environments where downtime does not impact business operations. 

Batch processing: Workflows where immediate availability is not critical. 

Maintenance windows: Periods where service unavailability is expected. 

Strategy Description Resource impact Recommended scenarios 

IMPORTANT 

The Recreate strategy severs the connection to the old pod immediately. Ensure that your traffic routing gateway and client applications can handle a temporary gap in service before applying this strategy. 

NOTE 

The Recreate deployment strategy is available for all runtimes except Distributed inference with llm-d. If you select the Distributed inference with llm-d runtime, the deployment strategy options are not displayed and the system defaults to the Recreate strategy. 

2.5. CANARY ROLLOUT FOR MODELS IN RAWDEPLOYMENT MODE 

You can use canary rollout to progressively validate a new model version against live production traffic before fully replacing the stable version. Canary rollout reduces the risk of production regressions because you control what percentage of inference traffic is routed to the new model version. This **deployment strategy is available for InferenceService resources in KServe RawDeployment mode. **

**When you initiate a canary rollout, the platform creates a separate canary Deployment alongside the existing stable Deployment within the same InferenceService. Both Deployments serve under the **same model name and endpoint. You configure the percentage of inference traffic that is routed to the **canary Deployment by setting the trafficPercent field in the canary spec. The remaining traffic **continues to be served by the stable Deployment. 

How traffic splitting works 

Traffic splitting between the stable and canary Deployments is managed at the ingress layer. Red Hat **OpenShift AI uses OpenShift Route alternateBackends with percentage-based weights to distribute traffic between the stable and canary Services. When you set trafficPercent to a value such as 10, **approximately 10% of incoming inference requests are routed to the canary Deployment and 90% are routed to the stable Deployment. 

The traffic split applies at the connection level, not at the individual request level. Consecutive requests from the same client might be routed to either the stable or canary Deployment because session affinity is not supported for canary traffic. 

How canary rollout differs from rolling update and recreate 

Canary rollout is distinct from the Kubernetes deployment strategies (rolling update and recreate) that control how pods are replaced during updates. When you configure a canary rollout, both the stable and canary Deployments use the Kubernetes deployment strategy that you specify (rolling update or recreate) to manage their own pod lifecycles. 

Canary rollout operates at a higher level by creating separate Deployments and splitting traffic between them. This allows you to run two different model versions simultaneously and validate the new version against live traffic before fully replacing the stable version. 

With rolling update or recreate alone, you update the model version in place without the ability to compare two versions side by side or gradually shift traffic from the old version to the new version. Canary rollout provides controlled validation that is not possible with deployment strategies alone. 

NOTE 

**Canary rollout is distinct from the canaryTrafficPercent field used in Knative Serverless mode. The canaryTrafficPercent field splits traffic between Knative revisions and applies only to Serverless deployments. The canary field on InferenceServiceSpec creates **explicit Deployments and applies only to RawDeployment mode. These two fields are mutually exclusive. 

When to use canary rollout 

Use canary rollout when you need to validate a new model version against live production traffic before committing to a full replacement. Canary rollout is appropriate in the following scenarios: 

You are updating a mission-critical model that serves production inference workloads and you need confidence that the new version meets quality and latency expectations. 

You want to compare the behavior of a new model version with the stable version under real traffic conditions. 

You need the ability to roll back quickly to the stable version if the canary performs poorly. 

Resource considerations 

During the canary window, both the stable and canary Deployments run simultaneously. The stable Deployment is not automatically scaled down when a canary Deployment is created. Total GPU and compute resource usage is the sum of resources consumed by both Deployments. 

Plan your cluster capacity to accommodate both Deployments during the canary window. If your cluster has limited GPU or accelerator resources, verify that sufficient capacity is available before initiating a canary rollout. 

Autoscaling with KEDA or HPA does not apply to canary Deployments. Canary Deployments use a fixed replica count. Autoscaling continues to function for the stable Deployment if it is configured. 

2.6. PERFORM A CANARY ROLLOUT FOR AN INFERENCESERVICE 

You can perform a canary rollout to progressively route inference traffic to a new model version while the stable version continues serving the remaining traffic. You initiate the rollout, verify the traffic split, increase canary traffic, and then promote or roll back the canary. 

Prerequisites 

You have Red Hat OpenShift AI 3.5 or later installed. 

You have an InferenceService deployed in KServe RawDeployment mode with a stable predictor that is serving inference traffic. 

**The canary Deployment name follows the pattern <inferenceservice_name>-<canary_name>-predictor and must not exceed 63 characters. **

**You have CLI access to your OpenShift cluster by using the oc command-line tool. **

You have sufficient GPU and compute resources in your cluster to run both the stable and canary Deployments simultaneously. For more information about resource requirements, see Canary rollout for models in RawDeployment mode . 

You have a new model version stored in an accessible location such as S3-compatible object storage or an OCI-compliant registry. 

Procedure 

**1. Initiate the canary rollout by adding a canary field to your InferenceService spec. The canary field defines the predictor configuration for the canary Deployment and the **percentage of traffic to route to it. 

**Edit your InferenceService resource: **

**Add the canary field under spec. The following YAML shows the complete InferenceService spec for reference. When using oc edit, add only the canary field under spec in your existing **resource: 

where: 

**<inferenceservice_name>: Specifies the name of your InferenceService. **

**<runtime_name>: Specifies the model format name for the serving runtime, such as vLLM. **

**<stable_model_uri>: Specifies the storage URI for the current stable model version, such as s3://my-bucket/model-v1. **

**<canary_name>: Specifies a unique name for the canary model, such as v2. **

**<canary_model_uri>: Specifies the storage URI for the new model version to test, such as s3://my-bucket/model-v2. **

NOTE 

**A starting value of 5-10% for trafficPercent is common for production **workloads. This routes enough traffic to detect issues while limiting the blast radius if the canary performs poorly. 

2. Verify that both the stable and canary Deployments are running: 

The output shows both the stable Deployment and the canary Deployment: 

$ oc edit inferenceservice <inferenceservice_name> -n <project_name> 

apiVersion: serving.kserve.io/v1beta1 kind: InferenceService metadata:   name: <inferenceservice_name>   annotations:     serving.kserve.io/deploymentMode: RawDeployment spec:   predictor:     model:       modelFormat:         name: <runtime_name>       storageUri: "<stable_model_uri>"     minReplicas: 2   canary:     - name: <canary_name>       trafficPercent: 10       predictor:         model:           storageUri: "<canary_model_uri>" 

$ oc get deployments -n <project_name> -l serving.kserve.io/inferenceservice= <inferenceservice_name> 

IMPORTANT 

**If the canary Deployment does not reach Ready state, check for issues such as **invalid model URIs, insufficient GPU or compute resources, or image pull errors. Run the following commands to diagnose the problem: 

**oc describe deployment <inferenceservice_name>-<canary_name>-predictor -n <project_name> to check Deployment events and conditions. **

**oc get events -n <project_name> --sort-by='.lastTimestamp' to review **recent events such as scheduling failures or resource quota issues. 

**If the canary cannot be started, remove the canary field from the InferenceService spec to roll back. All traffic continues to be served by the **stable Deployment. 

3. Verify the traffic split on the OpenShift Route: **Find the Route for your InferenceService: **

Verify the traffic weights on the Route: 

**The output shows the traffic weights for the stable and canary Services. For a trafficPercent value of 10, the stable Service receives weight 90 and the canary Service receives weight 10. **

**4. Verify the canary status conditions on the InferenceService: **

Check for the following status conditions: 

**CanaryReady: Indicates that the canary Deployment is ready and serving traffic. **

**CanaryTrafficSplit: Indicates that traffic is split at the configured percentage. **

5. Increase the canary traffic percentage after validating canary performance. **Edit the InferenceService and update the trafficPercent value: **

**Change trafficPercent to a higher value, such as 50: **

NAME                                   READY   UP-TO-DATE   AVAILABLE <inferenceservice_name>-predictor              2/2     2            2 <inferenceservice_name>-<canary_name>-predictor        1/1     1            1 

$ oc get route -n <project_name> -l serving.kserve.io/inferenceservice= <inferenceservice_name> 

$ oc get route -n <project_name> -l serving.kserve.io/inferenceservice= <inferenceservice_name> -o jsonpath='{.items[0].spec.to.weight}{"\n"} {.items[0].spec.alternateBackends[*].weight}{"\n"}' 

$ oc get inferenceservice <inferenceservice_name> -n <project_name> -o jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.message}{"\n"}{end}' 

$ oc edit inferenceservice <inferenceservice_name> -n <project_name> 

The controller updates the Route weights to reflect the new traffic split. Repeat this step to progressively increase canary traffic as you gain confidence in the new model version. 

6. When you are satisfied with the canary model performance, promote the canary to stable, or roll back if the canary does not meet expectations. 

To promote the canary 

Promote the canary to stable by updating the stable predictor configuration and removing **the canary field. For a zero-restart promotion without downtime, copy the name field from the canary array into the stable predictor spec. If you do not copy the name field, the stable **deployment will restart with the new model. 

The controller terminates the canary Deployment and routes all traffic to the stable **Deployment. When the name field matches the canary name, the existing canary pods **become the stable pods without restarting. 

To roll back the canary 

**Remove the canary field without changing the stable predictor storageUri: **

  canary:     trafficPercent: 50     predictor: *      # ... unchanged canary predictor configuration *

apiVersion: serving.kserve.io/v1beta1 kind: InferenceService metadata:   name: <inferenceservice_name>   annotations:     serving.kserve.io/deploymentMode: RawDeployment spec:   predictor: *    name: <canary_name>  # Copy from canary array for zero-restart promotion *    model:       modelFormat:         name: <runtime_name>       storageUri: "<canary_model_uri>"     minReplicas: 2 *  # canary field removed *

apiVersion: serving.kserve.io/v1beta1 kind: InferenceService metadata:   name: <inferenceservice_name>   annotations:     serving.kserve.io/deploymentMode: RawDeployment spec:   predictor:     model:       modelFormat:         name: <runtime_name>       storageUri: "<stable_model_uri>"     minReplicas: 2 *  # canary field removed *

The controller terminates the canary Deployment and routes all traffic back to the stable Deployment running the original model version. 

7. Wait for the promotion or rollback to complete. **The controller sets a CanaryPromoting or CanaryRollingBack status condition while the **operation is in progress. Monitor the status conditions until the transient condition is no longer present: 

**When the CanaryPromoting or CanaryRollingBack condition no longer appears in the output, **the operation is complete. 

Verification 

Verify that the canary Deployment is removed after promotion or rollback: 

Only the stable Deployment should appear in the output. 

**Verify that the InferenceService status shows no canary conditions: **

**The CanaryReady and CanaryTrafficSplit conditions should no longer appear. **

Optionally, send a test inference request to confirm the endpoint is serving the expected model version. For information about accessing inference endpoints, see Accessing the inference endpoint for a deployed model. 

Additional resources 

Canary rollout for models in RawDeployment mode 

Canary field API reference for InferenceService 

Known limitations for canary rollout in RawDeployment mode 

2.7. CANARY FIELD API REFERENCE FOR INFERENCESERVICE 

**You can use the canary field on the InferenceService spec to configure canary rollout in KServe RawDeployment mode. The canary field defines the predictor configuration for the canary Deployment **and the percentage of traffic to route to it. 

Canary field schema 

**The canary field is an array of canary model configurations. You can define up to 3 canary models simultaneously. The canary field is a direct child of spec on the InferenceService resource. **

$ oc get inferenceservice <inferenceservice_name> -n <project_name> -o jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.message}{"\n"}{end}' 

$ oc get deployments -n <project_name> -l serving.kserve.io/inferenceservice= <inferenceservice_name> 

$ oc get inferenceservice <inferenceservice_name> -n <project_name> -o jsonpath='{.status.conditions[*].type}{"\n"}' 

Table 2.2. Canary field properties 

Field Type Required Description 

**name **String Yes A unique name for this canary model. This name is used in the canary Deployment name and must be unique across all canary models in the array. 

**trafficPercent **Integer Yes The percentage of inference traffic to route to this **canary Deployment. Valid values are 0 through 100. A value of 0 creates a deployment with no traffic. A value of 100 routes all traffic to the canary while **keeping the stable deployment active. 

**predictor **InferenceS ervicePred ictorSpec 

Yes The predictor configuration for the canary Deployment. This field follows the same schema as **spec.predictor and defines the model and resources for the canary. The minReplicas field is **optional; if not specified, the number of replicas is **dynamically determined from the trafficPercent **value. 

NOTE 

**For canary Deployments, the minReplicas value in the predictor spec is optional. If specified, it overrides the dynamic replica calculation based on trafficPercent. The maxReplicas field is ignored for canary Deployments. **

Example canary configuration 

Validation webhook rules 

apiVersion: serving.kserve.io/v1beta1 kind: InferenceService metadata:   name: my-model   annotations:     serving.kserve.io/deploymentMode: RawDeployment spec:   predictor:     model:       modelFormat:         name: vLLM       storageUri: "s3://my-bucket/model-v1"     minReplicas: 2   canary:     - name: v2       trafficPercent: 10       predictor:         model:           storageUri: "s3://my-bucket/model-v2" 

**The KServe validation webhook enforces the following rules when the canary field is present. Requests **that violate these rules are rejected with an error message. 

Table 2.3. Validation rules for the canary field 

Rule Description 

**trafficPercent must be between 0 and 100 A value of 0 creates a deployment but routes no traffic. A value of 100 keeps the stable model deployed but routes all **traffic to the canary model. 

Up to 3 canary models **You can define up to 3 canary models in the canary array. Each must have a unique name value. **

RawDeployment mode only **The canary field is valid only for InferenceService resources with serving.kserve.io/deploymentMode: RawDeployment. The webhook rejects the canary field on Knative Serverless InferenceService resources. **

Predictor component only Only the predictor component supports canary rollout. The **canary field applies to the predictor; you cannot define **canary configurations for Transformer or Explainer components. 

Canary Deployment name must not exceed 63 characters 

The canary Deployment name follows the pattern **<inferenceservice-name>-<canary-name>-predictor. **The total length must not exceed 63 characters to comply with Kubernetes DNS naming constraints. 

Status conditions and canary status 

**When a canary rollout is active, the InferenceService reports the CanaryPredictorReady status **condition to indicate whether the canary Deployment is ready. 

To query the canary predictor readiness condition, run the following command: 

**The InferenceService also reports detailed status information for each canary in the .status.canaryStatuses array. **

Table 2.4. Canary status fields 

Field Type Description 

**name **String **The name of the canary model as defined in the canary **array. 

$ oc get inferenceservice <inferenceservice_name> -n <project_name> -o jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.message}{"\n"}{end}' 

**ready **Boolean Indicates whether the canary Deployment is ready and **serving traffic. A value of true means all canary pods are **running and passing readiness checks. 

**trafficPercent **Integer The percentage of inference traffic currently routed to this canary Deployment. 

**modelStatus **ModelStatu s 

The status of the model within the canary Deployment. This field contains the same model status information as the stable predictor. 

Field Type Description 

To query the status of all canary Deployments, run the following command: 

+ where: 

**<inferenceservice_name> **

Specifies the name of the InferenceService. 

**<project_name> **

Specifies the name of the project containing the InferenceService. 

2.8. KNOWN LIMITATIONS FOR CANARY ROLLOUT IN RAWDEPLOYMENT MODE 

The following limitations apply to canary rollout for InferenceService resources in KServe RawDeployment mode. Review these limitations before planning a canary rollout to avoid unexpected behavior. 

RawDeployment mode only 

Canary rollout is available only for InferenceService resources that are configured for KServe **RawDeployment mode. The validation webhook rejects the canary field on InferenceService **resources that use Knative Serverless mode. For Serverless deployments, use the **canaryTrafficPercent field instead. **

Predictor component only 

Only the predictor component supports canary rollout. You cannot define canary configurations for Transformer or Explainer components. If your InferenceService uses a Transformer or Explainer, only the predictor is canary-deployed while the Transformer and Explainer continue to use the stable configuration. 

No autoscaling for canary Deployments 

KEDA and HPA autoscaling do not apply to canary Deployments. Canary Deployments use a fixed replica count. Autoscaling continues to function for the stable Deployment if it is configured. 

Increased GPU and resource usage 

The stable Deployment is not automatically scaled down when a canary Deployment is created. Total 

$ oc get inferenceservice <inferenceservice_name> -n <project_name> -o jsonpath='{range .status.canaryStatuses[*]}{.name}{"\t"}{.ready}{"\t"}{.trafficPercent}{"\n"}{end}' 

GPU and compute resource usage during the canary window is the sum of resources consumed by both the stable and canary Deployments. Plan your cluster capacity to accommodate both Deployments. 

CLI-only management 

**Canary rollout is managed by using the oc or kubectl command-line tools. The OpenShift AI **dashboard does not support canary rollout configuration. 

Mutual exclusivity with canaryTrafficPercent 

**The canary field and the legacy canaryTrafficPercent field are mutually exclusive. The canaryTrafficPercent field applies to Knative Serverless mode only. If both fields are present on an **InferenceService, the validation webhook rejects the request. 

OpenShift Route alternateBackends limit 

OpenShift Routes support a maximum of 3 alternate backends per Route. This limit constrains the number of traffic-splitting targets available on a single Route and affects future extensions for N-way traffic splitting. 

LLMInferenceService not supported 

Canary rollout applies to InferenceService v1beta1 resources only. LLMInferenceService is a separate **serving path and does not support the canary field. **

Manual promotion and rollback 

Automated canary analysis and progressive delivery are not included. Promotion and rollback are manual operations that you perform by editing the InferenceService spec. For the promotion and rollback workflow, see Perform a canary rollout for an InferenceService . 

Auth proxy configuration is inherited 

Auth proxy configuration for canary pods is inherited from the InferenceService-level auth settings. The canary Deployment uses the same OAuth proxy configuration as the stable Deployment. You do not need to configure auth proxy separately for the canary. 

No session affinity 

Session affinity is not supported for canary traffic. Consecutive requests from the same client might be routed to either the stable or canary Deployment. 

Additional resources 

Controlled deployment for distributed workloads 

2.9. DEPLOY MODELS ON THE MODEL SERVING PLATFORM 

You can deploy generative AI (gen AI) or predictive AI models on the model serving platform by using the Deploy a model wizard. The wizard allows you to configure your model, including specifying its location and type, selecting a serving runtime, assigning a hardware profile, and setting advanced configurations like external routes and token authentication. 

To successfully deploy a model, you must meet the following prerequisites. 

You have logged in to Red Hat OpenShift AI. 

You have installed KServe and enabled the model serving platform. 

You have enabled a preinstalled or custom model-serving runtime. 

You have created a project. 

You have access to S3-compatible object storage, a URI-based repository, an OCI-compliant registry or a persistent volume claim (PVC) and have added a connection to your project. For more information about adding a connection, see Adding a connection to your project . 

If you want to use graphics processing units (GPUs) with your model server, you have enabled GPU support in OpenShift AI. If you use NVIDIA GPUs, see Enabling NVIDIA GPUs. If you use AMD GPUs, see AMD GPU integration . 

Meet the requirements for the specific runtime you intend to use. 

Caikit-TGIS runtime 

To use the Caikit-TGIS runtime, you have converted your model to Caikit format. For an example, see Converting Hugging Face Hub models to Caikit format  in the caikit-tgis-serving repository. 

vLLM NVIDIA GPU ServingRuntime for KServe 

To use the vLLM NVIDIA GPU ServingRuntime for KServe runtime, you have enabled GPU support in OpenShift AI and have installed and configured the Node Feature Discovery Operator on your cluster. For more information, see Installing the Node Feature Discovery Operator and Enabling NVIDIA GPUs. 

vLLM CPU ServingRuntime for KServe 

To use the VLLM runtime on IBM Z and IBM Power, use the vLLM CPU ServingRuntime for KServe. You cannot use GPU accelerators with IBM Z and IBM Power architectures. For more information, see Red Hat OpenShift Multi Architecture Component Availability Matrix . 

vLLM Intel Gaudi Accelerator ServingRuntime for KServe 

To use the vLLM Intel Gaudi Accelerator ServingRuntime for KServe runtime, you have enabled support for hybrid processing units (HPUs) in OpenShift AI. This includes installing the Intel Gaudi Base Operator and configuring a hardware profile. For more information, see Intel Gaudi Base Operator OpenShift installation  in the AMD documentation and Working with hardware profiles. 

vLLM AMD GPU ServingRuntime for KServe 

To use the vLLM AMD GPU ServingRuntime for KServe runtime, you have enabled support for AMD graphic processing units (GPUs) in OpenShift AI. This includes installing the AMD GPU operator and configuring a hardware profile. For more information, see Deploying the AMD GPU operator on OpenShift  and Working with hardware profiles . 

vLLM Spyre AI Accelerator ServingRuntime for KServe 

IMPORTANT 

Support for IBM Spyre AI Accelerators on x86 is currently available in Red Hat OpenShift AI 3.5 as a Technology Preview feature. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

IMPORTANT 

Support for IBM Spyre AI Accelerators on ppc64le is currently available in Red Hat OpenShift AI 3.5 as a General Availability (GA) feature. 

To use the vLLM Spyre AI Accelerator ServingRuntime for KServe runtime on x86, you have installed the Spyre Operator and configured a hardware profile. For more information, see Spyre operator image and Working with hardware profiles . 

To use the vLLM Spyre AI Accelerator ServingRuntime for KServe runtime on ppc64le, you have installed the Spyre Operator and configured a hardware profile. For more information, see Spyre operator image and Working with hardware profiles . 

vLLM Spyre s390x ServingRuntime for KServe 

To use the vLLM Spyre s390x ServingRuntime for KServe runtime on IBM Z, you have installed the Spyre Operator and configured a hardware profile. For more information, see Spyre operator image and Working with hardware profiles . 

Procedure 

1. In the left menu, click Projects. 

2. Click the name of the project that you want to deploy a model in. A project details page opens. 

3. Click the Deployments tab. 

4. Click Deploy model. The Deploy a model wizard opens. 

5. In the Model details section, provide information about the model: 

a. From the Model location list, specify where your model is stored and complete the connection detail fields. 

NOTE 

The OCI-compliant registry, S3 compatible object storage, and URI options are preinstalled connection types. Additional options might be available if your OpenShift AI administrator added them. 

If you have uploaded model files to a persistent volume claim (PVC) and the PVC is attached to your workbench, the Cluster storage option becomes available in the Model location list. Use this option to select the PVC and specify the path to the model file. 

b. From the Model type list, select the type of model that you are deploying, Predictive or Generative AI model. 

c. Click Next. 

6. In the Model deployment section, configure the deployment: 

a. In the Model deployment name field, enter a unique name for your model deployment. 

b. In the Description field, enter a description of your deployment. 

c. From the Hardware profile list, select a hardware profile. 

d. Optional: To modify the default resource allocation, click Customize resource requests and limits and enter new values for the CPU and Memory requests and limits. 

e. In the Serving runtime field, select one of the following options: 

Auto-select the best runtime for your model based on model type, model format, and hardware profile The system analyzes the selected model framework and your available hardware profiles to recommend a serving runtime. 

Select from a list of serving runtimes, including custom ones Select this option to manually choose a runtime from the list of global and projectscoped serving runtime templates. 

For more information about how the system determines the best runtime and administrator overrides, see Automatic selection of serving runtimes. 

f. Optional: If you selected a Predictive model type, select a framework from the Model framework (name - version) list. This field is hidden for Generative AI models. 

g. In the Number of model server replicas to deploy field, specify a value. 

h. Click Next. 

7. In the Advanced settings section, configure advanced options: 

a. Optional: (Generative AI models only) Select the Add as AI asset endpoint checkbox if you want to add your model’s endpoint to the Gen AI studio → AI asset endpoints page. 

i. In the Use case field, enter the types of tasks that your model performs, such as chat, multimodal, or natural language processing. 

NOTE 

You must add your model as an AI asset endpoint to test your model on the Gen AI studio → playground page. 

If you enabled the endpoint, enter the types of tasks that your model performs in the Use case field. 

b. Optional: Select the Model access checkbox to make your model deployment available through an external route. 

c. Optional: To require token authentication for inference requests to the deployed model, select Require token authentication. 

d. In the Service account name field, enter the service account name that the token will be generated for. 

e. To add an additional service account, click Add a service account and enter another service account name. 

f. Optional: Select Add custom runtime arguments or Add custom runtime environment variables to add configuration parameters to your deployment. 

g. In the Deployment strategy section, select Rolling update or Recreate. 

NOTE 

The Recreate deployment strategy is available for all runtimes except Distributed inference with llm-d. If you select the Distributed inference with llm-d runtime, the deployment strategy options are not displayed and the system defaults to the Recreate strategy. 

8. Click Deploy. 

Verification 

Confirm that the deployed model is shown on the Deployments tab for the project, and on the Deployments page of the dashboard with a checkmark in the Status column. 

Additional resources 

Model-serving runtimes for accelerators 

Adding a custom model-serving runtime 

Deployment strategies for resource optimization 

2.10. DEPLOY MODELS BY USING THE MLSERVER RUNTIME 

Deploy models with the MLServer ServingRuntime for KServe option by selecting your model framework in the Deploy a model wizard. KServe automatically configures the runtime based on your model framework selection. If your model file uses a well-known filename and is located directly under **/mnt/models, KServe automatically detects and loads it without additional configuration. **

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

You have installed KServe and enabled the model serving platform. 

The MLServer ServingRuntime for KServe is enabled in your cluster. For more information, see Enabling the model serving platform. 

You have created a project. 

Your model is stored in a location accessible to the model server and you have added a connection to your project: 

OCI registry 

S3-compatible object storage 

URI 

Persistent Volume Claim 

You are deploying a model that uses one of the supported MLServer implementations: 

LightGBM 

ONNX 

Scikit-learn 

XGBoost 

**Your model file uses a well-known filename and is stored directly under /mnt/models after **download. If your model uses a different filename or is stored in a subdirectory, you must **manually configure the MLSERVER_MODEL_URI environment variable. Well-known filenames: **

**LightGBM: model.bst **

**ONNX: model.onnx **

**Scikit-learn: model.joblib, model.pickle, model.pkl **

**XGBoost: model.bst, model.json, model.ubj **

NOTE 

KServe automatically configures the MLServer runtime environment variables based on your model framework selection. The model name is set to your model deployment name, the model implementation is set based on your selected framework, and the model URI is **set to /mnt/models. **

IMPORTANT 

**You can also use MLServer’s model-settings.json file for model configuration. If a model-settings.json file is present alongside your model file, the MLServer runtime **loads configuration values from that file and overrides the automatic configuration. The model name in the file must match your model deployment name. 

Configuration beyond model name, model URI, and model implementation is tested and verified, but not officially supported. 

Procedure 

1. In the OpenShift AI dashboard, navigate to Projects and select or create a project. 

2. Deploy the model using the Deploy a model wizard. For complete deployment instructions, see Deploying models on the model serving platform . 

3. In the Model details section of the wizard: 

a. Select your model location from an existing data connection or cluster storage. 

b. For Model type, select Predictive. 

4. In the Model deployment section: 

a. Enter a model deployment name and optional description. 

b. Select your model framework from the Model framework list: 

LightGBM 

ONNX 

Scikit-learn 

XGBoost The Deployment resource field automatically selects MLServer ServingRuntime for KServe based on your framework selection. 

c. Configure the number of model server replicas to deploy. 

5. If your model file does not use a well-known filename or is not located directly under **/mnt/models, configure the MLSERVER_MODEL_URI environment variable in the Advanced **settings section: 

a. Select the Add custom runtime environment variables checkbox. 

b. Click Add variable. 

**c. Add the MLSERVER_MODEL_URI variable with the full path to your model file, for example, /mnt/models/my-custom-model.pkl or /mnt/models/subfolder/model.pkl. **

6. Click Deploy to deploy your model. 

Verification 

Confirm that the deployed model is shown on the Deployments tab for the project. The deployment status displays as Pending during the deployment process. When the deployment completes successfully, the status changes to Started. 

Test the model by making an inference request: 

a. On the Deployments tab, click the deployment name to view details. 

b. Click Internal and external endpoint to display the inference endpoints. 

c. Copy the external endpoint URL and query the model: 

where: 

**<inference_endpoint_url> **

Specifies the external endpoint URL for your deployed model. 

**<model_name> **

Specifies the name of your deployed model. 

**<input_name> **

Specifies the input name expected by your model. 

$ curl -X POST <inference_endpoint_url>/v2/models/<model_name>/infer \   -H "Content-Type: application/json" \   -d '{"inputs":[{"name":"<input_name>","shape":[<shape>],"datatype":" <datatype>","data":[<data>]}]}' 

**<shape> **

Specifies the shape of your input data. 

**<datatype> **

**Specifies the data type, for example, FP32. **

**<data> **

Specifies your input data values. The model returns an inference response with the prediction results. 

Additional resources 

Inference endpoints 

Deploying models on the model serving platform 

MLServer LightGBM Runtime 

MLServer ONNX Runtime 

MLServer scikit-learn Runtime 

MLServer XGBoost Runtime 

MLServer OpenAPI / Inference API 

2.11. DEPLOY A MODEL FROM AN OCI IMAGE BY USING THE CLI 

You can deploy a model that is stored in an OCI image from the command line interface. 

The following procedure uses the example of deploying a MobileNet v2-7 model in ONNX format, stored in an OCI image on an OpenVINO model server. 

NOTE 

By default in KServe, models are exposed outside the cluster and not protected with authentication. 

Prerequisites 

You have stored a model in an OCI image as described in Storing a model in an OCI image . 

If you want to deploy a model that is stored in a private OCI repository, you must configure an image pull secret. For more information about creating an image pull secret, see Using image pull secrets. 

You are logged in to your OpenShift cluster. 

Procedure 

1. Create a project to deploy the model: 

oc new-project oci-model-example 

**2. Use the OpenShift AI Applications project kserve-ovms template to create a ServingRuntime **resource and configure the OpenVINO model server in the new project: 

oc process -n redhat-ods-applications -o yaml kserve-ovms | oc apply -f -

**3. Verify that the ServingRuntime named kserve-ovms is created: **

oc get servingruntimes 

The command should return output similar to the following: 

NAME          DISABLED   MODELTYPE     CONTAINERS         AGE kserve-ovms              openvino_ir   kserve-container   1m 

**4. Create an InferenceService YAML resource, depending on whether the model is stored from a **private or a public OCI repository: 

**For a model stored in a public OCI repository, create an InferenceService YAML file with the following values, replacing <user_name>, <repository_name>, and <tag_name> with **values specific to your environment: 

apiVersion: serving.kserve.io/v1beta1 kind: InferenceService metadata:   name: sample-isvc-using-oci spec:   predictor:     model:       runtime: kserve-ovms # Ensure this matches the name of the ServingRuntime resource       modelFormat:         name: onnx       storageUri: oci://quay.io/<user_name>/<repository_name>:<tag_name>       resources:         requests:           memory: 500Mi           cpu: 100m           # nvidia.com/gpu: "1" # Only required if you have GPUs available and the model and runtime will use it         limits:           memory: 4Gi           cpu: 500m           # nvidia.com/gpu: "1" # Only required if you have GPUs available and the model and runtime will use it 

**For a model stored in a private OCI repository, create an InferenceService YAML file that specifies your pull secret in the spec.predictor.imagePullSecrets field, as shown in the **following example: 

apiVersion: serving.kserve.io/v1beta1 kind: InferenceService metadata:   name: sample-isvc-using-private-oci spec: 

  predictor:     model:       runtime: kserve-ovms # Ensure this matches the name of the ServingRuntime resource       modelFormat:         name: onnx       storageUri: oci://quay.io/<user_name>/<repository_name>:<tag_name>       resources:         requests:           memory: 500Mi           cpu: 100m           # nvidia.com/gpu: "1" # Only required if you have GPUs available and the model and runtime will use it         limits:           memory: 4Gi           cpu: 500m           # nvidia.com/gpu: "1" # Only required if you have GPUs available and the model and runtime will use it     imagePullSecrets: # Specify image pull secrets to use for fetching container images, including OCI model images     - name: <pull-secret-name> 

**After you create the InferenceService resource, KServe deploys the model stored in the OCI image referred to by the storageUri field. **

Verification 

Check the status of the deployment: 

oc get inferenceservice 

The command should return output that includes information, such as the URL of the deployed model and its readiness state. 

2.12. MONITORING MODELS 

You can monitor models that are deployed on the model serving platform to view performance and resource usage metrics. 

2.12.1. View performance metrics for a deployed model 

You can monitor the following metrics for a specific model that is deployed on the model serving platform: 

Number of requests - The number of requests that have failed or succeeded for a specific model. 

Average response time (ms) - The average time it takes a specific model to respond to requests. 

CPU utilization (%) - The percentage of the CPU limit per model replica that is currently utilized by a specific model. 

Memory utilization (%) - The percentage of the memory limit per model replica that is utilized by a specific model. 

You can specify a time range and a refresh interval for these metrics to help you determine, for example, when the peak usage hours are and how the model is performing at a specified time. 

Prerequisites 

You have installed Red Hat OpenShift AI. 

A cluster admin has enabled user workload monitoring (UWM) for user-defined projects on your OpenShift cluster. For more information, see Enabling monitoring for user-defined projects and Configuring monitoring for the model serving platform. 

You have logged in to Red Hat OpenShift AI. 

The following dashboard configuration options are set to the default values as shown: 

disablePerformanceMetrics:false disableKServeMetrics:false 

For more information about setting dashboard configuration options, see Customizing the dashboard. 

You have deployed a model on the model serving platform by using a preinstalled runtime. 

NOTE 

Metrics are only supported for models deployed by using a preinstalled model-serving runtime or a custom runtime that is duplicated from a preinstalled runtime. 

Procedure 

1. From the OpenShift AI dashboard navigation menu, click Projects. The Projects page opens. 

2. Click the name of the project that contains the data science models that you want to monitor. 

3. In the project details page, click the Deployments tab. 

4. Select the model that you are interested in. 

5. On the Endpoint performance tab, set the following options: 

Time range - Specifies how long to track the metrics. You can select one of these values: 1 hour, 24 hours, 7 days, and 30 days. 

Refresh interval - Specifies how frequently the graphs on the metrics page are refreshed (to show the latest data). You can select one of these values: 15 seconds, 30 seconds, 1 minute, 5 minutes, 15 minutes, 30 minutes, 1 hour, 2 hours, and 1 day. 

6. Scroll down to view data graphs for number of requests, average response time, CPU utilization, and memory utilization. 

Verification 

The Endpoint performance tab shows graphs of metrics for the model. 

2.12.2. View model-serving runtime metrics for the model serving platform 

When a cluster administrator has configured monitoring for the model serving platform, non-admin users can use the OpenShift web console to view model-serving runtime metrics for the KServe component. 

Prerequisites 

A cluster administrator has configured monitoring for the model serving platform. 

**You have been assigned the monitoring-rules-view role. For more information, see Granting **users permission to configure monitoring for user-defined projects. 

You are familiar with how to monitor project metrics in the OpenShift web console. For more information, see Monitoring your project metrics . 

Procedure 

1. Log in to the OpenShift web console. 

2. Switch to the Developer perspective. 

3. In the left menu, click Observe. 

4. As described in Monitoring your project metrics , use the web console to run queries for model-serving runtime metrics. You can also run queries for metrics that are related to OpenShift Service Mesh. Some examples are shown. 

a. The following query displays the number of successful inference requests over a period of time for a model deployed with the vLLM runtime: 

*sum(increase(vllm:request_success_total{namespace=${namespace},model_name=${m odel_name}}[${rate_interval}])) *

NOTE 

Certain vLLM metrics are available only after an inference request is processed by a deployed model. To generate and view these metrics, you must first make an inference request to the model. 

b. The following query displays the number of successful inference requests over a period of time for a model deployed with the OpenVINO Model Server runtime: 

*sum(increase(ovms_requests_success{namespace=${namespace},name=${model_nam e}}[${rate_interval}])) *

Additional resources 

OVMS metrics 

### CHAPTER 3. DEPLOYING DIFFUSIONGEMMA MODELS

You can deploy DiffusionGemma, a discrete diffusion language model, on the model serving platform by **using the vLLM ServingRuntime for KServe. DiffusionGemma uses block diffusion to generate text in **parallel, which provides higher per-request generation throughput compared to autoregressive models. 

3.1. DIFFUSIONGEMMA DISCRETE DIFFUSION LANGUAGE MODEL 

DiffusionGemma is a discrete diffusion language model that uses block diffusion to generate text in parallel instead of sequentially. You can deploy DiffusionGemma on OpenShift AI to achieve higher perrequest generation throughput compared to autoregressive models. 

3.1.1. How block diffusion works 

Traditional autoregressive language models generate tokens one at a time in a sequential process where each new token depends on all previously generated tokens. This sequential approach limits generation speed because the model must wait for each token before producing the next one. 

DiffusionGemma uses a different approach called block diffusion. Instead of generating tokens sequentially, the model initializes a fixed 256-token canvas with masked tokens, then iteratively denoises the entire canvas in parallel. Over multiple refinement steps, the model replaces the masked tokens with coherent text. Because the model processes all 256 tokens simultaneously, block diffusion achieves approximately 6x higher per-request generation throughput compared to autoregressive models of similar size. 

This throughput improvement requires a tradeoff in time-to-first-token, or TTFT. DiffusionGemma requires approximately 10x higher TTFT than an equivalent autoregressive model because the initial canvas must be fully denoised before any tokens are available. For example, on an H100 GPU, DiffusionGemma achieves a TTFT of approximately 489 ms compared to approximately 53 ms for autoregressive Gemma 4. 

DiffusionGemma is a 26 billion parameter model built on the Gemma 4 Mixture-of-Experts architecture, with 3.8 billion active parameters per token. The model uses the standard OpenAI-compatible **/v1/chat/completions API endpoint. The diffusion decoding process is transparent to API consumers **and does not require changes to client applications. 

3.1.2. Available model variants 

The following table lists the DiffusionGemma model variants that you can deploy on OpenShift AI. 

Table 3.1. DiffusionGemma model variants 

Model Quantization Minimum vRAM Validated GPU 

**RedHatAI/diffusiong emma-26B-A4B-it-FP8-dynamic **

FP8 31.3 GB 1x A100-80 or H100 

3.1.3. Known limitations 

DiffusionGemma has the following limitations: 

Single-GPU only: Tensor parallelism and pipeline parallelism with more than one GPU are not supported. You must deploy the model on a single GPU with sufficient vRAM. 

**Maximum 4 concurrent sequences: You must set the --max-num-seqs argument to 4 or **fewer. Values greater than 4 cause out-of-memory errors due to diffusion state buffer memory requirements. 

Higher time-to-first-token: DiffusionGemma requires approximately 10x higher TTFT than an equivalent autoregressive model because the initial denoising process must complete before tokens are available. 

Additional resources 

DiffusionGemma model card on Hugging Face 

RedHatAI DiffusionGemma FP8 model card on Hugging Face 

3.2. DEPLOY A DIFFUSIONGEMMA MODEL 

You can deploy a DiffusionGemma discrete diffusion language model on OpenShift AI by using the vLLM ServingRuntime for KServe. DiffusionGemma requires specific serving runtime arguments to enable diffusion decoding and manage memory constraints. 

Prerequisites 

You have logged in to OpenShift AI as a user with OpenShift AI administrator privileges. 

You have downloaded the DiffusionGemma FP8 model to your object storage. 

You have enabled the vLLM ServingRuntime for KServe runtime. 

You have enabled GPU support in OpenShift AI and have installed and configured the Node Feature Discovery Operator on your cluster. For more information, see Installing the Node Feature Discovery Operator and Enabling NVIDIA GPUs. 

You have an NVIDIA GPU with at least 32 GB of vRAM. DiffusionGemma is validated on A100-80 and H100 GPUs. 

Procedure 

1. Follow the steps to deploy a model as described in Deploying models on the model serving platform. 

2. In the Serving runtime field, select vLLM ServingRuntime for KServe. 

3. Add the following arguments under Additional serving runtime arguments in the Configuration parameters section: 

--diffusion-config={"canvas_length": 256} --hf-overrides={"diffusion_sampler": "entropy_bound", "diffusion_entropy_bound": 0.1} --max-num-seqs=4 --generation-config=vllm 

where: 

**--diffusion-config={"canvas_length": 256}: Enables diffusion decoding with 256-token **canvas blocks. 

**--hf-overrides={"diffusion_sampler": "entropy_bound", "diffusion_entropy_bound": 0.1}: Configures the entropy-bound denoising sampler with a threshold of 0.1. **

**--max-num-seqs=4: Limits concurrent sequences to 4. Values above 4 cause out-of-**memory errors due to diffusion state buffer memory requirements. 

**--generation-config=vllm: Overrides the checkpoint default 256-token max_tokens cap. **Without this argument, model responses are silently truncated to 256 tokens. 

4. Add the following environment variable under Additional serving runtime environment variables in the Configuration parameters section: 

VLLM_USE_V2_MODEL_RUNNER=1 

5. Click Deploy. 

Verification 

Confirm that the deployed model is shown on the Deployments tab for the project, and on the Deployments page of the dashboard with a checkmark in the Status column. 

Run the following command to verify API requests to your deployed model. In the following **command, replace <inference_endpoint_url> with the URL of your inference endpoint. Replace <model_name> with the name of your deployed DiffusionGemma model. **

Troubleshooting 

**If responses are truncated to approximately 256 tokens, verify that --generation-config=vllm is **included in the serving runtime arguments. 

**If the model server crashes with an out-of-memory error, verify that --max-num-seqs is set to 4 **or fewer. 

Additional resources 

vLLM: Engine Arguments 

$ curl -X POST \     "https://<inference_endpoint_url>:443/v1/chat/completions" \     -H "accept: application/json" \     -H "Content-Type: application/json" \     -d '{     "model": "<model_name>",     "messages": [{"role": "user", "content": "What is discrete diffusion?"}],     "max_tokens": 512     }' 

### CHAPTER 4. DEPLOYING MODELS ON THE NVIDIA NIM MODEL SERVING PLATFORM

You can deploy models using NVIDIA NIM inference services on the NVIDIA NIM model serving platform. 

NVIDIA NIM, part of NVIDIA AI Enterprise, is a set of microservices designed for secure, reliable deployment of high performance AI model inferencing across clouds, data centers and workstations. 

4.1. DEPLOY MODELS ON THE NVIDIA NIM MODEL SERVING PLATFORM 

When you have enabled the NVIDIA NIM model serving platform, you can start to deploy NVIDIA-optimized models on the platform. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

You have enabled the NVIDIA NIM model serving platform. 

You have created a project. 

You have enabled support for graphic processing units (GPUs) in OpenShift AI. This includes installing the Node Feature Discovery Operator and NVIDIA GPU Operator. For more information, see Installing the Node Feature Discovery Operator  and Enabling NVIDIA GPUs. 

Procedure 

1. In the left menu, click Projects. The Projects page opens. 

2. Click the name of the project that you want to deploy a model in. A project details page opens. 

3. Click the Deployments tab. 

4. In the Deployments section, perform one of the following actions: 

On the ​​NVIDIA NIM model serving platform tile, click Select NVIDIA NIM on the tile, and then click Deploy model. 

If you have previously selected the NVIDIA NIM model serving type, the Deployments page displays NVIDIA model serving enabled on the upper-right corner, along with the Deploy model button. To proceed, click Deploy model. 

The Deploy model dialog opens. 

5. Configure properties for deploying your model as follows: 

a. In the Model deployment name field, enter a unique name for the deployment. 

b. From the NVIDIA NIM list, select the NVIDIA NIM model that you want to deploy. For more information, see Supported Models 

c. In the NVIDIA NIM storage size field, specify the size of the cluster storage instance that will be created to store the NVIDIA NIM model. 

NOTE 

When resizing a PersistentVolumeClaim (PVC) backed by Amazon EBS in **OpenShift AI, you may encounter VolumeModificationRateExceeded: You've reached the maximum modification rate per volume limit. To **avoid this error, wait at least six hours between modifications per EBS volume. If you resize a PVC before the cooldown expires, the Amazon EBS **CSI driver (ebs.csi.aws.com) fails with this error. This error is an Amazon **EBS service limit that applies to all workloads using EBS-backed PVCs. 

d. In the Number of model server replicas to deploy field, specify a value. 

e. From the Model server size list, select a value. 

6. From the Hardware profile list, select a hardware profile. 

7. Optional: Click Customize resource requests and limit and update the following values: 

a. In the CPUs requests field, specify the number of CPUs to use with your model server. Use the list beside this field to specify the value in cores or millicores. 

b. In the CPU limits field, specify the maximum number of CPUs to use with your model server. Use the list beside this field to specify the value in cores or millicores. 

c. In the Memory requests field, specify the requested memory for the model server in gibibytes (Gi). 

d. In the Memory limits field, specify the maximum memory limit for the model server in gibibytes (Gi). 

8. Optional: In the Model route section, select the Make deployed models available through an external route checkbox to make your deployed models available to external clients. 

9. To require token authentication for inference requests to the deployed model, perform the following actions: 

a. Select Require token authentication. 

b. In the Service account name field, enter the service account name that the token will be generated for. 

c. To add an additional service account, click Add a service account and enter another service account name. 

10. Click Deploy. 

Verification 

Confirm that the deployed model is shown on the Deployments tab for the project, and on the Deployments page of the dashboard with a checkmark in the Status column. 

Additional resources 

NVIDIA NIM API reference 

Supported Models 

4.2. VIEW NVIDIA NIM METRICS FOR A NIM MODEL 

In OpenShift AI, you can observe the following NVIDIA NIM metrics for a NIM model deployed on the NVIDIA NIM model serving platform: 

GPU cache usage over time (ms) 

Current running, waiting, and max requests count 

Tokens count 

Time to first token 

Time per output token 

Request outcomes 

You can specify a time range and a refresh interval for these metrics to help you determine, for example, the peak usage hours and model performance at a specified time. 

Prerequisites 

You have enabled the NVIDIA NIM model serving platform. 

You have deployed a NIM model on the NVIDIA NIM model serving platform. 

A cluster administrator has enabled metrics collection and graph generation for your deployment. 

**The disableKServeMetrics OpenShift AI dashboard configuration option is set to its default value of false: **

disableKServeMetrics: false 

For more information about setting dashboard configuration options, see Customizing the dashboard. 

Procedure 

1. From the OpenShift AI dashboard navigation menu, click Projects. The Projects page opens. 

2. Click the name of the project that contains the NIM model that you want to monitor. 

3. In the project details page, click the Deployments tab. 

4. Click the NIM model that you want to observe. 

5. On the NIM Metrics tab, set the following options: 

Time range - Specifies how long to track the metrics. You can select one of these values: 1 hour, 24 hours, 7 days, and 30 days. 

Refresh interval - Specifies how frequently the graphs on the metrics page are refreshed (to show the latest data). You can select one of these values: 15 seconds, 30 seconds, 1 minute, 5 minutes, 15 minutes, 30 minutes, 1 hour, 2 hours, and 1 day. 

6. Scroll down to view data graphs for NIM metrics. 

Verification 

The NIM Metrics tab shows graphs of NIM metrics for the deployed NIM model. 

Additional resources 

NVIDIA NIM observability 

4.3. VIEW PERFORMANCE METRICS FOR A NIM MODEL 

You can observe the following performance metrics for a NIM model deployed on the NVIDIA NIM model serving platform: 

Number of requests - The number of requests that have failed or succeeded for a specific model. 

Average response time (ms) - The average time it takes a specific model to respond to requests. 

CPU utilization (%) - The percentage of the CPU limit per model replica that is currently utilized by a specific model. 

Memory utilization (%) - The percentage of the memory limit per model replica that is utilized by a specific model. 

You can specify a time range and a refresh interval for these metrics to help you determine, for example, the peak usage hours and model performance at a specified time. 

Prerequisites 

You have enabled the NVIDIA NIM model serving platform. 

You have deployed a NIM model on the NVIDIA NIM model serving platform. 

A cluster administrator has enabled metrics collection and graph generation for your deployment. 

**The disableKServeMetrics OpenShift AI dashboard configuration option is set to its default value of false: **

disableKServeMetrics: false 

For more information about setting dashboard configuration options, see Customizing the dashboard. 

Procedure 

1. From the OpenShift AI dashboard navigation menu, click Projects. The Projects page opens. 

2. Click the name of the project that contains the NIM model that you want to monitor. 

3. In the project details page, click the Deployments tab. 

4. Click the NIM model that you want to observe. 

5. On the Endpoint performance tab, set the following options: 

Time range - Specifies how long to track the metrics. You can select one of these values: 1 hour, 24 hours, 7 days, and 30 days. 

Refresh interval - Specifies how frequently the graphs on the metrics page are refreshed to show the latest data. You can select one of these values: 15 seconds, 30 seconds, 1 minute, 5 minutes, 15 minutes, 30 minutes, 1 hour, 2 hours, and 1 day. 

6. Scroll down to view data graphs for performance metrics. 

Verification 

The Endpoint performance tab shows graphs of performance metrics for the deployed NIM model. 

### CHAPTER 5. PRECACHE MODELS FOR FASTER DEPLOYMENT

**You can precache large language models on local node storage so that InferenceService pods start **from locally stored copies instead of downloading from remote storage on every pod startup. 

NOTE 

Before you can cache models, a cluster administrator must enable model caching and configure node groups and storage. For more information, see Enable model caching  in *Configuring your model-serving platform *. 

5.1. CACHE A MODEL ON CLUSTER NODES 

**You can create a LocalModelCache custom resource (CR) to pre-download a model from remote storage and cache it on designated cluster nodes. A LocalModelCache resource is cluster-scoped, so any InferenceService in any namespace can use the cached model. **

Prerequisites 

You have cluster administrator privileges or permissions to create cluster-scoped resources. 

**You have enabled model caching in the DataScienceCluster CR. For more information, see **Enable model caching * in Configuring your model-serving platform *. 

**A LocalModelNodeGroup exists for the target nodes. The Operator creates one automatically **when you enable model caching. To cache models on a subset of nodes, see Configure node *groups for model caching in Configuring your model-serving platform *. 

**You have configured download credentials in the kserve-localmodel-jobs namespace. For **more information, see Configure model cache download credentials * in Configuring your model-serving platform. *

**You have installed the OpenShift CLI (oc). **

Procedure 

**1. Create a YAML file named local-model-cache.yaml with the following content: **

In the preceding YAML, set the following values. 

apiVersion: serving.kserve.io/v1alpha1 kind: LocalModelCache metadata: *  name: <cache_name> *spec: *  sourceModelUri: <model_uri>   modelSize: <model_size> *  nodeGroups: *    - <node_group_name> *  storage: *    key: <storage_key> *

**<cache_name> **

**Specifies a descriptive name for the cache resource, for example, llama3-70b-cache. **

**<model_uri> **

Specifies the URI of the model to download. For Hugging Face Hub models, use the format **hf://<organization>/<model_name>, for example, hf://meta-llama/Meta-Llama-3-70B. For S3-compatible storage, use the format s3://<bucket>/<path>. **

**<model_size> **

**Specifies the approximate size of the model, for example, 140Gi. This value determines the **resource allocation for the download job and is used to verify that the model fits within the node group’s storage limit. 

**<node_group_name> **

**Specifies the name of the LocalModelNodeGroup where the model is cached. **

**<storage_key> **

**Specifies the key name in the storage-config secret that contains the download credentials. **This must match the key you created when configuring download credentials. Omit the **storage section if the model source is publicly accessible. **

NOTE 

**The sourceModelUri field is immutable after creation. To change the model URI, delete the LocalModelCache resource and create a new one. **

**2. Create the LocalModelCache resource: **

**The localmodel-controller-manager creates download jobs in the kserve-localmodel-jobs **namespace. The download jobs fetch the model artifacts from the specified URI and store them on local storage on each target node. 

3. Check the download status: 

**In the output, the status.copies field shows how many nodes have the model available. The status.nodeStatus field shows the download status for each node. **

Verification 

1. Verify that the model copies are available on all target nodes: 

The output shows the number of available copies matching the total number of target nodes: 

2. Verify the per-node status: 

$ oc apply -f local-model-cache.yaml 

*$ oc get localmodelcache <cache_name> -oyaml *

*$ oc get localmodelcache <cache_name> -o jsonpath={.status.copies} *

{"available":2,"total":2} 

**Each node shows a status of NodeDownloaded: **

Next steps 

**Deploy an InferenceService with a cached model **

5.2. CACHE A MODEL WITHIN A NAMESPACE 

**You can create a LocalModelNamespaceCache custom resource (CR) to pre-download and cache a model that is available only to InferenceService workloads in the same namespace. Use namespace-**scoped caching when you need to restrict model access to a specific project. 

Prerequisites 

**You have permissions to create LocalModelNamespaceCache resources in the target **namespace. 

**You have enabled model caching in the DataScienceCluster CR. For more information, see **Enable model caching * in Configuring your model-serving platform *. 

**A LocalModelNodeGroup exists for the target nodes. The Operator creates one automatically **when you enable model caching. To cache models on a subset of nodes, see Configure node *groups for model caching in Configuring your model-serving platform *. 

**You have configured download credentials in the kserve-localmodel-jobs namespace. For **more information, see Configure model cache download credentials * in Configuring your model-serving platform. *

**You have installed the OpenShift CLI (oc). **

Procedure 

**1. Create a YAML file named local-model-namespace-cache.yaml with the following content: **

In the preceding YAML, set the following values. 

*$ oc get localmodelcache <cache_name> -o jsonpath={.status.nodeStatus} *

{"node-1":"NodeDownloaded","node-2":"NodeDownloaded"} 

apiVersion: serving.kserve.io/v1alpha1 kind: LocalModelNamespaceCache metadata: *  name: <cache_name>   namespace: <target_namespace> *spec: *  sourceModelUri: <model_uri>   modelSize: <model_size> *  nodeGroups: *    - <node_group_name> *  storage: *    key: <storage_key> *

**<cache_name> **

Specifies a descriptive name for the cache resource. 

**<target_namespace> **

**Specifies the namespace where the cached model is accessible. Only InferenceService **workloads in this namespace can use the cached model. 

**<model_uri> **

**Specifies the URI of the model to download, for example, hf://meta-llama/Meta-Llama-3-70B. **

**<model_size> **

**Specifies the approximate size of the model, for example, 140Gi. **

**<node_group_name> **

**Specifies the name of the LocalModelNodeGroup where the model is cached. **

**<storage_key> **

**Specifies the key name in the storage-config secret that contains the download credentials. **This must match the key you created when configuring download credentials. Omit the **storage section if the model source is publicly accessible. **

**2. Create the LocalModelNamespaceCache resource: **

3. Check the download status: 

**The status.nodeStatus field shows the download status for each node. **

Verification 

Verify that the model copies are available: 

The output shows the number of available copies matching the total number of target nodes. 

Next steps 

**Deploy an InferenceService with a cached model **

5.3. MONITOR MODEL CACHE DOWNLOAD STATUS 

You can monitor the download progress of cached models to discover when a model is ready for use by **an InferenceService. Model Cache provides status information at both the cache level and the **individual node level. 

Prerequisites 

**You have created a LocalModelCache or LocalModelNamespaceCache resource. **

$ oc apply -f local-model-namespace-cache.yaml 

*$ oc get localmodelnamespacecache <cache_name> -n <target_namespace> -oyaml *

*$ oc get localmodelnamespacecache <cache_name> -n <target_namespace> -o jsonpath={.status.copies} *

**You have installed the OpenShift CLI (oc). **

Procedure 

1. Check the overall cache status: 

In the output, review the following status fields: 

**status.copies.available — The number of nodes that have the model downloaded and **ready. 

**status.copies.total — The total number of nodes where the model is expected to be **downloaded. 

**status.copies.failed — The number of nodes where the download failed. **

**status.nodeStatus — A map of node names to their current download status. The nodeStatus field uses the following values: **

Status Description 

**NodeNotReady **The node is not ready for model downloads. 

**NodeDownloadPending **The download job is created but has not started. 

**NodeDownloading **The model is being downloaded to the node. 

**NodeDownloaded **The model is downloaded and ready for use. 

**NodeDownloadError **The download failed on this node. 

2. Check per-node download status for more detail: 

**The status.modelStatus field shows the status of each model on the node. The modelStatus **field uses the following values: 

Status Description 

**ModelDownloadPending **The download is queued but has not started. 

**ModelDownloading **The model is currently being downloaded. 

**ModelDownloaded **The model is available on this node. 

*$ oc get localmodelcache <cache_name> -oyaml *

*$ oc get localmodelnode <node_name> -oyaml *

**ModelDownloadError **The download failed for this model on this node. 

Status Description 

3. Check the download jobs for troubleshooting: 

Each download job corresponds to a model being downloaded to a specific node. Failed jobs indicate download problems. 

4. View the logs of a download job: 

Verification 

**A model is ready for use by an InferenceService when all of the following conditions are met: **

**The status.copies.available value equals the status.copies.total value. **

**All entries in status.nodeStatus show NodeDownloaded. **

**The status.copies.failed value is 0. **

**5.4. DEPLOY AN INFERENCESERVICE WITH A CACHED MODEL **

**You can deploy an InferenceService that uses a locally cached model copy instead of downloading the model from remote storage. When the storageUri in an InferenceService matches the sourceModelUri of a LocalModelCache or LocalModelNamespaceCache resource, KServe **automatically detects the cached copy and mounts it directly. This significantly reduces startup time compared to downloading the model from remote storage on every pod start. 

Prerequisites 

**You have created a LocalModelCache or LocalModelNamespaceCache resource and the **model is fully downloaded. For more information, see Cache a model on cluster nodes  or Cache a model within a namespace. All nodes in the cache resource show a status of **NodeDownloaded. **

**You have installed the OpenShift CLI (oc). **

Procedure 

**1. Create a YAML file named inference-service.yaml with the following content: **

$ oc get jobs -n kserve-localmodel-jobs 

*$ oc logs job/<job_name> -n kserve-localmodel-jobs *

apiVersion: serving.kserve.io/v1beta1 kind: InferenceService metadata: *  name: <inferenceservice_name>   namespace: <target_namespace> *spec: 

In the preceding YAML, set the following values. 

**<inferenceservice_name> **

**Specifies a name for the InferenceService. **

**<target_namespace> **

**Specifies the namespace where the InferenceService is deployed. For namespace-scoped caching, this must match the namespace of the LocalModelNamespaceCache resource. **

**<model_format> **

**Specifies the serialization format of the model, for example, pytorch. Other valid values include tensorflow, onnx, and huggingface. This field specifies the model format, not the **serving runtime. 

**<model_uri> **

**Specifies the model URI. This value must match the sourceModelUri field of the LocalModelCache or LocalModelNamespaceCache resource. **

**<serving_runtime> **

**Specifies the serving runtime to use for the model, for example, vllm-runtime. **

IMPORTANT 

**The storageUri value must exactly match the sourceModelUri of the LocalModelCache or LocalModelNamespaceCache resource, or be a subdirectory of it. KServe uses a mutating admission webhook to match the storageUri against cached model URIs at resource creation time. If a match is found, KServe annotates the InferenceService with the cached model’s PVC **reference so that the pod mounts the local copy instead of downloading from remote storage. 

**2. Deploy the InferenceService: **

Verification 

**1. Verify that the InferenceService pod starts without a lengthy model download: **

**The pod transitions from Pending to Running significantly faster than a non-cached **deployment, confirming that the cached model is used. 

**2. Verify that the InferenceService is ready: **

  predictor:     model:       modelFormat: *        name: <model_format>       storageUri: <model_uri>       runtime: <serving_runtime> *

$ oc apply -f inference-service.yaml 

*$ oc get pods -n <target_namespace> -w *

*$ oc get inferenceservice <inferenceservice_name> -n <target_namespace> *

**The READY column shows True. **

**3. Verify that the InferenceService is listed in the cache resource: **

**The output includes the deployed InferenceService. **

**5.5. DEPLOY AN LLMINFERENCESERVICE WITH A CACHED MODEL **

**You can deploy an LLMInferenceService that uses a locally cached model copy instead of downloading the model from remote storage. When the spec.model.uri in an LLMInferenceService matches the sourceModelUri of a LocalModelCache or LocalModelNamespaceCache resource, KServe **automatically detects the cached copy and mounts it directly. This significantly reduces startup time compared to downloading the model from remote storage on every pod start. 

Prerequisites 

**You have created a LocalModelCache or LocalModelNamespaceCache resource and the **model is fully downloaded. For more information, see Cache a model on cluster nodes  or Cache a model within a namespace. All nodes in the cache resource show a status of **NodeDownloaded. **

**You have installed the OpenShift CLI (oc). **

Procedure 

**1. Create a YAML file named llm-inference-service.yaml with the following content: **

In the preceding YAML, set the following values. 

**<service_name> **

**Specifies a name for the LLMInferenceService. **

**<target_namespace> **

**Specifies the namespace where the LLMInferenceService is deployed. For namespacescoped caching, this must match the namespace of the LocalModelNamespaceCache **resource. 

**<model_uri> **

**Specifies the model URI. This value must match the sourceModelUri field of the LocalModelCache or LocalModelNamespaceCache resource. **

*$ oc get localmodelcache <cache_name> -o jsonpath={.status.inferenceServices} *

apiVersion: inference.rhaieng.openshift.io/v1alpha1 kind: LLMInferenceService metadata: *  name: <service_name>   namespace: <target_namespace> *spec:   model: *    uri: <model_uri>     name: <model_name> *

**<model_name> **

**Specifies the model name, for example, Qwen/Qwen3-0.6B. **

IMPORTANT 

**The spec.model.uri value must exactly match the sourceModelUri of the LocalModelCache or LocalModelNamespaceCache resource, or be a **subdirectory of it. KServe uses a mutating admission webhook to match the URI against cached model URIs at resource creation time. If a match is found, KServe annotates the resource with the cached model’s PVC reference so that the pod mounts the local copy instead of downloading from remote storage. 

**2. Deploy the LLMInferenceService: **

Verification 

**1. Verify that the LLMInferenceService pods start without a lengthy model download: **

**The pods transition from Pending to Running significantly faster than a non-cached **deployment, confirming that the cached model is used. 

**2. Verify that the LLMInferenceService is ready: **

**The READY column shows True. **

5.6. MODEL CACHE CUSTOM RESOURCE DEFINITIONS 

**Model Cache uses four custom resource definitions (CRDs) in the serving.kserve.io/v1alpha1 API **group to manage the lifecycle of cached models. You can use these CRDs to define which models to cache, where to cache them, and to monitor cache status. 

5.6.1. LocalModelCache 

**The LocalModelCache custom resource is a cluster-scoped resource that defines a model to predownload and cache on designated nodes. Any InferenceService in any namespace can use a model cached by a LocalModelCache resource. **

**Table 5.1. LocalModelCache spec fields **

Field Type Required Description 

**spec.sourceModelUri string **Yes The URI of the model to download, for **example, hf://meta-llama/Meta-Llama-3-70B or s3://bucket/model-path. This field **is immutable after creation. 

$ oc apply -f llm-inference-service.yaml 

*$ oc get pods -n <target_namespace> -w *

*$ oc get llminferenceservice <service_name> -n <target_namespace> *

**spec.modelSize Quantity **Yes The approximate size of the model, for **example, 140Gi. Used for resource allocation **and to verify the model fits within the node group storage limit. 

**spec.nodeGroups []string **Yes **A list of LocalModelNodeGroup names **that specify which nodes receive the cached model. At least one node group is required. 

**spec.serviceAccountNa me **

**string **No The service account to use for credential lookup during model download. 

**spec.storage.key string **No The storage key in the secret for this object. 

**spec.storage.parameters map[strin g]string **

No Parameters to override the default storage credentials and configuration. 

Field Type Required Description 

**Table 5.2. LocalModelCache status fields **

Field Type Description 

**status.nodeStatus map[string]N odeStatus **

The download status for each node, keyed by node **name. Values: NodeNotReady, NodeDownloadPending, NodeDownloading, NodeDownloaded, NodeDownloadError. **

**status.copies.available int **The number of nodes that have the model downloaded and available. 

**status.copies.total int **The total number of nodes where the model is expected to be downloaded. 

**status.copies.failed int **The number of nodes where the download failed. 

**status.inferenceServices []Namespace dName **

**A list of InferenceService resources that use this **cached model, identified by namespace and name. 

**Example LocalModelCache resource **

apiVersion: serving.kserve.io/v1alpha1 kind: LocalModelCache metadata:   name: llama3-70b-cache spec:   sourceModelUri: "hf://meta-llama/Meta-Llama-3-70B" 

5.6.2. LocalModelNamespaceCache 

**The LocalModelNamespaceCache custom resource is a namespace-scoped variant of LocalModelCache. Only InferenceService workloads in the same namespace can use the cached **model. 

**Table 5.3. LocalModelNamespaceCache spec fields **

Field Type Required Description 

**spec.sourceModelUri string **Yes The URI of the model to download. This field is immutable after creation. 

**spec.modelSize Quantity **Yes The approximate size of the model. 

**spec.nodeGroups []string **Yes **A list of LocalModelNodeGroup names. **At least one node group is required. 

**spec.serviceAccountNa me **

**string **No The service account to use for credential lookup. 

**spec.storage.key string **No The storage key in the secret for this object. 

**spec.storage.parameters map[strin g]string **

No Parameters to override the default storage credentials and configuration. 

**The status fields for LocalModelNamespaceCache are identical to those of LocalModelCache. **

**Example LocalModelNamespaceCache resource **

5.6.3. LocalModelNodeGroup 

**The LocalModelNodeGroup custom resource is a cluster-scoped resource that defines a group of nodes for model caching, including storage limits and PersistentVolume specifications. **

  modelSize: "140Gi"   nodeGroups:     - gpu-nodes 

apiVersion: serving.kserve.io/v1alpha1 kind: LocalModelNamespaceCache metadata:   name: llama3-70b-cache   namespace: my-project spec:   sourceModelUri: "hf://meta-llama/Meta-Llama-3-70B"   modelSize: "140Gi"   nodeGroups:     - gpu-nodes 

**Table 5.4. LocalModelNodeGroup spec fields **

Field Type Required Description 

**spec.storageLimit Quantity **Yes The maximum total storage for cached models on each node in this group, for **example, 500Gi. **

**spec.persistentVolumeS pec **

**Persistent VolumeSp ec **

Yes **The PersistentVolume template used to **provision storage on each node. The **local.path must be /var/lib/kserve/models. Includes accessModes, capacity, local, nodeAffinity, persistentVolumeReclaimPolicy, storageClassName, and volumeMode. **

**spec.persistentVolumeCl aimSpec **

**Persistent VolumeCl aimSpec **

Yes **The PersistentVolumeClaim template **used to request storage on each node. **Includes accessModes, resources.requests.storage, storageClassName, and volumeMode. **

**Table 5.5. LocalModelNodeGroup status fields **

Field Type Description 

**status.used Quantity **The used storage space on any node for this node group. 

**status.available Quantity **The available storage space on any node for this node group. 

**Example LocalModelNodeGroup resource **

apiVersion: serving.kserve.io/v1alpha1 kind: LocalModelNodeGroup metadata:   name: gpu-nodes spec:   storageLimit: "500Gi"   persistentVolumeSpec:     accessModes:       - ReadWriteOnce     capacity:       storage: "500Gi"     local:       path: /var/lib/kserve/models     nodeAffinity:       required:         nodeSelectorTerms: 

5.6.4. LocalModelNode 

**The LocalModelNode custom resource is a cluster-scoped resource that tracks the download status of models on a specific node. The localmodel-controller-manager creates and updates these resources **automatically. 

**Table 5.6. LocalModelNode spec fields **

Field Type Required Description 

**spec.localModels []LocalMo delInfo **

Yes A list of models assigned to this node for caching. Each entry includes the **sourceModelUri, modelName, and optionally the namespace and nodeGroup. **

**Table 5.7. LocalModelInfo fields **

Field Type Required Description 

**sourceModelUri string **Yes The URI of the model source. 

**modelName string **Yes The name used as the subdirectory name to store the model on the local file system. 

**namespace string **No The namespace of the **LocalModelNamespaceCache CR. **Empty for cluster-scoped **LocalModelCache resources. **

**nodeGroup string **No **The LocalModelNodeGroup that this **model belongs to. 

          - matchExpressions:               - key: kserve/localmodel                 operator: In                 values:                   - worker     persistentVolumeReclaimPolicy: Retain     storageClassName: ""     volumeMode: Filesystem   persistentVolumeClaimSpec:     accessModes:       - ReadWriteOnce     resources:       requests:         storage: "500Gi"     storageClassName: ""     volumeMode: Filesystem 

**serviceAccountName string **No The service account used for credential lookup. 

**storage LocalMod elStorage Spec **

No Storage credential configuration for model download. 

**storage.key string **No **The key in the storage-config secret that **contains the download credentials. 

**storage.parameters map[strin g]string **

No Parameters to override the default storage credentials and configuration. 

Field Type Required Description 

**Table 5.8. LocalModelNode status fields **

Field Type Description 

**status.modelStatus map[string] ModelStatus **

The download status for each model on this node, keyed by model name. Values: **ModelDownloadPending, ModelDownloading, ModelDownloaded, ModelDownloadError. **

5.6.5. NodeStatus and ModelStatus values 

**Table 5.9. NodeStatus values (used in LocalModelCache and LocalModelNamespaceCache) **

Value Description 

**NodeNotReady **The node is not ready for model downloads. 

**NodeDownloadPendi ng **

The download job is created but has not started. 

**NodeDownloading **The model is being downloaded to the node. 

**NodeDownloaded **The model is downloaded and ready for use. 

**NodeDownloadError **The download failed on this node. 

**Table 5.10. ModelStatus values (used in LocalModelNode) **

Value Description 

**ModelDownloadPen ding **

The download is queued but has not started. 

**ModelDownloading **The model is currently being downloaded. 

**ModelDownloaded **The model is available on this node. 

**ModelDownloadErro r **

The download failed for this model on this node. 

### CHAPTER 6. MAKING INFERENCE REQUESTS TO DEPLOYED MODELS

When you deploy a model, it is available as a service that you can access with API requests. You can get predictions from your model based on the data you provide in the request. 

6.1. ACCESS THE AUTHENTICATION TOKEN FOR A DEPLOYED MODEL 

If you secured your model inference endpoint by enabling token authentication, you must know how to access your authentication token so that you can specify it in your inference requests. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

You have deployed a model by using the model serving platform. 

Procedure 

1. From the OpenShift AI dashboard, click Projects. The Projects page opens. 

2. Click the name of the project that contains your deployed model. A project details page opens. 

3. Click the Deployments tab. 

4. In the Deployments list, expand the section for your model. Your authentication token is shown in the Token authentication section, in the Token secret field. 

5. Optional: To copy the authentication token for use in an inference request, click the Copy 

button (  ) next to the token value. 

6.2. ACCESS THE INFERENCE ENDPOINT FOR A DEPLOYED MODEL 

To make inference requests to your deployed model, you must know how to access the inference endpoint that is available. 

For a list of paths to use with the supported runtimes and example commands, see Inference endpoints. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

You have deployed a model by using the model serving platform. 

If you enabled token authentication for your deployed model, you have the associated token value. 

Procedure 

1. From the OpenShift AI dashboard, click AI hub → Deployments. The inference endpoint for the model is shown in the Inference endpoints field. 

2. Depending on what action you want to perform with the model (and if the model supports that action), copy the inference endpoint and then add a path to the end of the URL. 

3. Use the endpoint to make API requests to your deployed model. 

Additional resources 

Caikit API documentation 

OpenVINO KServe-compatible REST API documentation 

OpenAI API documentation 

6.3. INFERENCE REQUESTS TO DEPLOYED MODELS 

When you deploy a model by using the model serving platform, the model is available as a service that you can access using API requests. This enables you to return predictions based on data inputs. To use API requests to interact with your deployed model, you must know the inference endpoint for the model. 

In addition, if you secured your inference endpoint by enabling token authentication, you must know how to access your authentication token so that you can specify this in your inference requests. 

6.4. INFERENCE ENDPOINTS 

These examples show how to use inference endpoints to query the model. 

NOTE 

**If you enabled token authentication when deploying the model, add the Authorization **header and specify a token value. 

6.4.1. Caikit TGIS ServingRuntime for KServe 

**:443/api/v1/task/text-generation **

**:443/api/v1/task/server-streaming-text-generation **

Example command: 

+ 

curl --json '{"model_id": "<model_name__>", "inputs": "<text>"}' https://<inference_endpoint_url>:443/api/v1/task/server-streaming-text-generation -H 'Authorization: Bearer <token>' 

6.4.2. OpenVINO Model Server 

**/v2/models/<model-name>/infer **

Example command: 

+ curl -ks <inference_endpoint_url>/v2/models/<model_name>/infer -d '{ "model_name": " <model_name>", "inputs": [{ "name": "<name_of_model_input>", "shape": [<shape>], "datatype": " <data_type>", "data": [<data>] }]}' -H 'Authorization: Bearer <token>' 

6.4.3. vLLM NVIDIA GPU ServingRuntime for KServe 

**:443/version **

**:443/docs **

**:443/v1/models **

**:443/v1/chat/completions **

**:443/v1/completions **

**:443/v1/embeddings **

**:443/tokenize **

**:443/detokenize **

NOTE 

The vLLM runtime is compatible with the OpenAI REST API. 

To use the embeddings inference endpoint in vLLM, you must use an embeddings model that the vLLM supports. You cannot use the embeddings endpoint with generative models. For more information, see Supported embeddings models in vLLM. 

As of vLLM v0.5.5, you must provide a chat template while querying a model **using the /v1/chat/completions endpoint. If your model does not include a predefined chat template, you can use the chat-template command-line **parameter to specify a chat template in your custom vLLM runtime, as shown **in the example. Replace <CHAT_TEMPLATE> with the path to your **template. 

containers:   - args:       - --chat-template=<CHAT_TEMPLATE> 

**You can use the chat templates that are available as .jinja files here or with the vLLM image under /opt/app-root/template. For more information, see **Chat templates. 

As indicated by the paths shown, the model serving platform uses the HTTPS port of your OpenShift router (usually port 443) to serve external API requests. 

Example command: 

curl -v https://<inference_endpoint_url>:443/v1/chat/completions -H "Content-Type: 

application/json" -d '{ "messages": [{ "role": "<role>", "content": "<content>" }] -H 'Authorization: Bearer <token>' 

6.4.4. vLLM Intel Gaudi Accelerator ServingRuntime for KServe 

See vLLM NVIDIA GPU ServingRuntime for KServe. 

6.4.5. vLLM AMD GPU ServingRuntime for KServe 

See vLLM NVIDIA GPU ServingRuntime for KServe. 

6.4.6. vLLM Spyre AI Accelerator ServingRuntime for KServe 

IMPORTANT 

Support for IBM Spyre AI Accelerators on x86 is currently available in Red Hat OpenShift AI 3.5 as a Technology Preview feature. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

You can serve models with IBM Spyre AI accelerators on x86 by using the vLLM Spyre AI Accelerator ServingRuntime for KServe runtime. To use the runtime, you must install the Spyre Operator and configure a hardware profile. For more information, see Spyre operator image and Working with hardware profiles. 

6.4.7. vLLM Spyre s390x ServingRuntime for KServe 

You can serve models with IBM Spyre AI accelerators on IBM Z (s390x architecture) by using the vLLM Spyre s390x ServingRuntime for KServe runtime. To use the runtime, you must install the Spyre Operator and configure a hardware profile. For more information, see Spyre operator image and Working with hardware profiles . 

6.4.8. vLLM Spyre ppc64le ServingRuntime for KServe 

You can serve models with IBM Spyre AI accelerators on IBM Power (ppc64le architecture) by using the vLLM Spyre ppc64le ServingRuntime for KServe runtime. To use the runtime, you must install the Spyre Operator and configure a hardware profile. For more information, see Spyre operator image and Working with hardware profiles . 

6.4.9. NVIDIA Triton Inference Server 

REST endpoints: 

**v2/models/[/versions/<model_version>]/infer **

**v2/models/<model_name>[/versions/<model_version>] **

**v2/health/ready **

**v2/health/live **

**v2/models/<model_name>[/versions/]/ready **

**v2 **

+ Example command: 

+ 

curl -ks <inference_endpoint_url>/v2/models/<model_name>/infer -d '{ "model_name": " <model_name>", "inputs": [{ "name": "<name_of_model_input>", "shape": [<shape>], "datatype": " <data_type>", "data": [<data>] }]}' -H 'Authorization: Bearer <token>' 

**gRPC endpoints: * :443 inference.GRPCInferenceService/ModelInfer * :443 inference.GRPCInferenceService/ModelReady * :443 inference.GRPCInferenceService/ModelMetadata * :443 inference.GRPCInferenceService/ServerReady * :443 inference.GRPCInferenceService/ServerLive * :443 inference.GRPCInferenceService/ServerMetadata **

Example command: 

+ 

grpcurl -cacert ./openshift_ca_istio_knative.crt -proto ./grpc_predict_v2.proto -d @ -H "Authorization: Bearer <token>" <inference_endpoint_url>:443 inference.GRPCInferenceService/ModelMetadata 

6.4.10. MLServer ServingRuntime for KServe 

IMPORTANT 

MLServer ServingRuntime for KServe is currently available in Red Hat OpenShift AI as a Technology Preview feature. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

NOTE 

**HTTP requests to the MLServer ServingRuntime for KServe require the Content-Type: application/json header. **

**REST endpoints: * /v2 * /v2/health/live * /v2/health/ready * /v2/models/{model_name} * /v2/models/{model_name}/infer * /v2/models/{model_name}/ready **

Example command: 

+ 

For detailed configuration guidance, see Deploying models by using the MLServer runtime . 

6.4.11. Additional resources 

Caikit API documentation 

OpenVINO KServe-compatible REST API documentation 

OpenAI API documentation 

Open Inference Protocol 

Supported model-serving runtimes 

curl -ks <inference_endpoint_url>/v2/models/<model_name>/infer -H "Content-Type: application/json" -d '{ "inputs": [{ "name": "<name_of_model_input>", "shape": [<shape>], "datatype": " <data_type>", "data": [<data>] }]}' -H 'Authorization: Bearer <token>' 