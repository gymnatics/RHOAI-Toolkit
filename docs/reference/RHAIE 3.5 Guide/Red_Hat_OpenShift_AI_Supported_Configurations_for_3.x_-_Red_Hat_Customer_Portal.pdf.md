# Red Hat OpenShift AI_ Supported Configurations for 3.x - Red Hat Customer Portal.pdf

Red Hat OpenShift AI: Supported Configurations for 

3.x 

Products & Services Knowledgebase Articles 

- Red Hat OpenShift AI: Supported

- Configurations for 3.x

### Updated Saturday at 10:00 AM -

### TABLE OF CONTENTS

### This article lists the Red Hat OpenShift AI (RHOAI) 3.x offering, the RHOAI components,

### their current support phase, and their compatibility with the underlying platforms.

## ⚠ ATTENTION: For Red Hat OpenShift AI 2.x go to the

## supported pages HERE.

### English

### Architecture, Version and Components

### RHOAI and vLLM version compatibility

### Red Hat OpenShift AI Operator Dependencies

### Support requirements and limitations

### Supported workbench images

### Supported model-serving runtimes

### Training images

### Ray-based training images

### Kubeflow Trainer v2 ClusterTrainingRuntimes

Subscriptions Downloads Red Hat Console Get Support 

## Red Hat OpenShift AI Self-Managed

### You install OpenShift AI Self-Managed by installing the Red Hat OpenShift AI Operator

### and then configuring the Operator to manage standalone components of the product.

### RHOAI Self-Managed is supported on any supported OpenShift Container Platform

### configuration running on x86_64, ppc64le, s390x and aarch64 architectures. This includes,

### but is not limited to, the following deployment topologies:

### Bare Metal

### Single Node OpenShift (SNO)

### Hosted control planes (on Bare Metal, OpenShift Virtualization, or cloud providers)

### IBM Cloud

### Red Hat OpenStack

### Amazon Web Services

### Google Cloud Platform

### Microsoft Azure

### VMware vSphere

### Nutanix

### Oracle Cloud

### IBM Power

### IBM Z

### Note: RHOAI GPU workloads can be utilized on Hosted control planes with OpenShift

### Virtualization with GPU passthrough, as per the GPU provider's (e.g. NVIDIA) documentation

### for supported GPU models and feature availability, and subject to HCP and oVirt's GPU

### support.

### This also includes support for RHOAI Self-Managed on managed OpenShift offerings such

### as OpenShift Dedicated, Red Hat OpenShift Service on AWS (ROSA with HCP), Red Hat

### OpenShift Service on AWS (classic architecture), Microsoft Azure Red Hat OpenShift, and

### OpenShift Kubernetes Engine. Currently, RHOAI Self-Managed is not supported on

### OpenShift running on platforms such as MicroShift.

### For a full overview of the RHOAI Self-Managed life cycle and the currently supported

### releases, visit this page.

# Architecture, Version and Components

### x86_64 architecture

RHOAI 

Operator 

Version 

3.3 3.4 3.5 

OpenShift 

Supported 

Versions 

4.19.9+, 

4.20, 

4.21 

4.19.9+, 

4.20, 

4.21, 

4.22 

4.19 

4.2 

4.2 

4.2 

Components Status Version Status Version Status Ve 

Dashboard GA 2.0.0 GA 2.0.0 GA 2.0 

AI Pipelines GA 2.5.0 GA 2.16.0 GA 2.16 

↳ Argo 

Workflows GA v3.6.7 GA v3.7.3 GA v3. 

Distributed 

Inference with 

llm-d - (1) 

GA 0.4 GA 0.7.1 GA 0.9 

Feature Store 

(Feast) GA 0.59.0 GA 0.62.0 GA 0.6 

KServe GA 0.15 GA 0.17.0 GA 0.1 

Red Hat AI 

Inference (2) - - GA 3.4.0 GA 3.5 

Kubeflow 

Training 

Operator v1 

Deprecated 1.9.0 Deprecated 1.9.0 Deprecated 

(3) 1.9 

Kubeflow Trainer 

v2 GA 2.1.0 GA 2.1.0 GA 2.1. 

KubeRay GA 1.4.2 GA 1.4.2 GA 1.4 

Llama Stack 

Operator TP 0.6.0 TP 0.9.0 - -

OGX Operator - - - - GA 0.1 

↳ OGX - - - - GA 1.1.2 

### ARM (aarch64) architecture

RHOAI 

Operator 

Version 

3.3 3.4 3.5 

Model as a 

Service (MaaS) TP 0.0.2 GA 0.1.1 GA 0.2 

MLflow TP 3.6.0 GA 3.10.1 GA 3.14 

MLServer GA 1.7.1 GA 1.7.1 GA 1.7. 

Spark Operator - - TP 2.4.0 GA 2.4 

↳ Spark - - TP 4.0.1 GA 4.0 

TrustyAI GA 1.37.0 GA 1.37.0 GA 1.37 

↳ LM-Eval GA 0.4.8 GA 0.4.8 GA 0.4 

↳ NeMo 

Guardrails TP 0.9.4 GA 0.9.4 GA 0.9 

AI Hub GA 0.3.5 GA 0.3.9 GA 0.3 

Kubeflow 

Notebook 

Controller 

GA 1.10.0 GA 1.10.0 GA 1.10 

AutoML - - TP 1.11.0 TP 1.11 

AutoRAG - - TP 1.11.0 TP 1.11 

RHOAI 

Operator 

Version 

3.3 3.4 3.5 

OpenShift 

Supported 

Versions 

4.19.9+, 

4.20, 

4.21 

4.19.9+, 

4.20, 

4.21, 

4.22 

4.19 

4.2 

4.2 

4.2 

Components Status Version Status Version Status Ve 

Dashboard GA 2.0.0 GA 2.0.0 GA 2.0 

AI Pipelines GA 2.5.0 GA 2.16.0 GA 2.16 

↳ Argo 

Workflows GA v3.6.7 GA v3.7.3 GA v3. 

Distributed 

Inference with 

llm-d - (1) 

GA 0.4 GA 0.7.1 GA 0.9 

Feature Store 

(Feast) GA 0.59.0 GA 0.62.0 GA 0.6 

KServe GA 0.15 GA 0.17.0 GA 0.1 

Red Hat AI 

Inference (2) - - GA 3.4.0 GA 3.5 

Kubeflow 

Training 

Operator v1 

Deprecated 1.9.0 Deprecated 1.9.0 Deprecated 

(3) 1.9 

Kubeflow Trainer 

v2 - - - - - -

KubeRay GA 1.4.2 GA 1.4.2 GA 1.4 

Llama Stack 

Operator TP 0.6.0 TP 0.9.0 - -

OGX Operator - - - - GA 0.1 

↳ OGX - - - - GA 1.1.2 

### IBM Power (ppc64le) architecture

RHOAI 

Operator 

Version 

3.3 3.4 3.5 

Model as a 

Service (MaaS) TP 0.0.2 GA 0.1.1 GA 0.2 

MLflow - - - - - -

MLServer - - - - - -

Spark Operator - - - - - -

↳ Spark - - - - - -

TrustyAI GA 1.37.0 GA 1.37.0 GA 1.37 

↳ LM-Eval GA 0.4.8 GA 0.4.8 GA 0.4 

↳ NeMo 

Guardrails - - - - - -

AI Hub GA 0.3.5 GA 0.3.9 GA 0.3 

Kubeflow 

Notebook 

Controller 

GA 1.10.0 GA 1.10.0 GA 1.10 

AutoML - - - - - -

AutoRAG - - - - - -

RHOAI 

Operator 

Version 

3.3 3.4 3.5 

OpenShift 

Supported 

Versions 

4.19.9+, 

4.20, 

4.21 

4.19.9+, 

4.20, 

4.21, 

4.22 

4.19 

4.2 

4.2 

4.2 

Components Status Version Status Version Status Ve 

Dashboard GA 2.0.0 GA 2.0.0 GA 2.0 

AI Pipelines GA 2.5.0 GA 2.16.0 GA 2.16 

↳ Argo 

Workflows GA v3.6.7 GA v3.7.3 GA v3. 

Distributed 

Inference with 

llm-d 

- - - - - -

Feature Store 

(Feast) TP 0.59.0 TP 0.62.0 TP 0.6 

KServe GA 0.15 GA 0.17.0 GA 0.1 

Red Hat AI 

Inference (2) - - GA 3.4.0 GA 3.5 

Kubeflow 

Training 

Operator v1 

Deprecated 1.9.0 Deprecated 1.9.0 Deprecated 

(3) 1.9 

Kubeflow Trainer 

v2 - - - - - -

KubeRay - - TP 1.4.2 TP 1.4 

Llama Stack 

Operator - - TP 0.9.0 - -

OGX Operator - - - - GA 0.1 

↳ OGX - - - - GA 1.1.2 

### IBM Z (s390x) architecture

RHOAI 

Operator 

Version 

3.3 3.4 3.5 

Model as a 

Service (MaaS) - - - - - -

MLflow - - - - TP 3.14 

MLServer - - - - TP 1.7. 

Spark Operator - - - - TP 2.4 

↳ Spark - - - - TP 4.0 

TrustyAI GA 1.37.0 GA 1.37.0 GA 1.37 

↳ LM-Eval GA 0.4.8 GA 0.4.8 GA 0.4 

↳ NeMo 

Guardrails TP 0.9.4 GA 0.9.4 GA 0.9 

AI Hub GA 0.3.5 GA 0.3.9 GA 0.3 

Kubeflow 

Notebook 

Controller 

GA 1.10.0 GA 1.10.0 GA 1.10 

AutoML - - TP 1.11.0 TP 1.11 

AutoRAG - - - - - -

RHOAI Operator 

Version 3.3 3.4 3.5 

OpenShift 

Supported 

Versions 

4.19.9+, 

4.20, 

4.21 

4.19.9+, 

4.20, 

4.21, 4.22 

4.19.9+, 

4.20, 

4.21, 4.22 

RHOAI Operator 

Version 3.3 3.4 3.5 

Components Status Version Status Version Status Version 

Dashboard GA 2.0.0 GA 2.0.0 GA 2.0.0 

AI Pipelines - - - - - -

↳ Argo Workflows - - - - - -

Distributed 

Inference with llm-

d 

- - - - - -

Feature Store 

(Feast) - - - - - -

KServe GA 0.15 GA 0.17.0 GA 0.19.0 

Red Hat AI 

Inference (2) - - GA 3.4.0 GA 3.5.0 

Kubeflow Training 

Operator v1 - - - - - -

Kubeflow Trainer 

v2 - - - - - -

KubeRay - - - - - -

Llama Stack 

Operator - - - - - -

OGX Operator - - - - - -

↳ OGX - - - - - -

Model as a Service 

(MaaS) - - - - - -

MLflow - - - - - -

MLServer - - - - - -

Spark Operator - - - - - -

↳ Spark - - - - - -

## Notes

### (1) Distributed Inference with llm-d requires OpenShift 4.20 or later

### (2) For supported AI accelerators for Red Hat AI Inference Server, see Supported AI

### accelerators for Red Hat AI Inference Server

### (3) Kubeflow Training Operator v1 is supported through the Full Support phase of Red Hat

### OpenShift AI 3.5 only. It is not supported during the Extended Update Support (EUS) phase

### of 3.5. Support for this component ends when 3.5 exits Full Support ([DATE — end of 3.5

### Full Support]). After that date, Kubeflow Training Operator v1 is End of Life (EOL).

### Customers should migrate to Kubeflow Trainer v2 before that date.

### TP: Technology Preview

### DP: Developer Preview

### Developer and Technology Previews: How they compare

RHOAI Operator 

Version 3.3 3.4 3.5 

TrustyAI GA 1.37.0 GA 1.37.0 GA 1.37.0 

↳ LM-Eval - - - - - -

↳ NeMo 

Guardrails - - - - - -

IBM Spyre 

Operator GA 1.1.1 GA 1.2.1 GA TBD 

AI Hub GA 0.3.5 GA 0.3.9 GA 0.3.10 

Kubeflow 

Notebook 

Controller 

GA 1.10.0 GA 1.10.0 GA 1.10.0 

AutoML - - - - - -

AutoRAG - - - - - -

EvalHub - - - - - -

### GA: General Availability.

### EUS: Extended Update Support. During the EUS phase, Red Hat will maintain component

### specific support.

### EOL: End of Life. During this phase, the component will no longer be supported.

### Deprecated (EUS exception): The component remains Deprecated and supported through

### Full Support of the listed release, but is excluded from Extended Update Support. See the

### component footnote for the support end date.

# RHOAI and vLLM version compatibility

### vLLM runtime versions are maintained as part of Red Hat AI Inference (RHAII). For the vLLM

### version compatibility matrix, supported accelerators, and related configuration details, see

### Red Hat AI Inference - Supported Product and Hardware Configurations.

# Red Hat OpenShift AI Operator Dependencies

### For information on the compatibility and supported versions of Red Hat OpenShift AI

### Operator dependencies, see the following documentation:

### Red Hat OpenShift Serverless: release notes

### Red Hat OpenShift Service Mesh: release notes

### Red Hat Build of Kueue: release notes

### Node Feature Discovery Operator: documentation

### Red Hat - Authorino Operator: documentation

### NVIDIA GPU Operator: documentation

### Intel Gaudi Base Operator: documentation

### AMD GPU Operator: documentation

### NVIDIA Network Operator: documentation

### Red Hat Connectivity Link: release notes

### IBM Spyre Operator : documentation

### cert-manager Operator for Red Hat OpenShift: documentation

### PostgreSQL Operator: required for Llama Stack server deployments (3.4+)

### Red Hat Leader Worker Set Operator: required for Distributed Inference with llm-d

### Starting with RHOAI 3.4, Red Hat Connectivity Link (RHCL) is included in Red Hat AI SKUs

### for Models as a Service (MaaS) use cases only. For all other RHOAI components, RHCL is not

### included. When MaaS is enabled, RHCL is deployed via the Kuadrant Operator, which

### provides authentication, authorization, and rate limiting. For the RHCL version compatibility

### matrix, see Red Hat Connectivity Link Supported Configurations.

### functionality in OpenShift AI, the relevant accelerator Operators are required. OpenShift AI

### supports integration with the relevant Operators, and provides many images across the

### product that include the libraries to work with NVIDIA GPUs, AMD GPUs, Intel Gaudi AI

### accelerators and IBM Spyre. For more information about which devices are supported by an

### Operator, see the documentation for that Operator.

# Support requirements and limitations

### Review this section to understand the requirements for Red Hat support and any limitations

### to Red Hat support of Red Hat OpenShift AI.

### Supported browsers

### Google Chrome

### Mozilla Firefox

### Safari

### Supported services

### Red Hat OpenShift AI supports the following services:

Service Name Description 

EDB Postgres AI -

solution including 

Pgvector 

Use powerful hybrid search for AI RAG and multimodal AI recommender 

applications with EDB's vector database solution including Pgvector. 

Combine AI, transactional, and analytical workloads with native vector index 

search, enterprise-grade security, and scalability in a unified Postgres 

environment. 

Elasticsearch 

Build transformative RAG applications, proactively resolve observability 

issues, and address complex security threats — all with the power of Search 

AI. 

IBM Watson Studio 

IBM® watsonx.ai is part of the IBM watsonx AI and data platform, bringing 

together new generative AI capabilities powered by foundation models and 

traditional machine learning (ML) into a powerful studio spanning the AI 

lifecycle. 

Intel® oneAPI AI 

Analytics Toolkit 

Container 

The AI Kit is a set of AI software tools to accelerate end-to-end data 

science and analytics pipelines on Intel® architectures. 

# Supported workbench images

### The latest supported workbench images in Red Hat OpenShift AI are installed with Python by

### default.

### You can install packages that are compatible with the supported version of Python on any

### workbench server that has the binaries required by that package. If the required binaries are

### not included on the workbench image you want to use, contact Red Hat Support to request

### that the binary be considered for inclusion.

### To provide a consistent, stable platform for your model development, select workbench

### images that contain the same version of Python. Workbench images available on OpenShift

### AI are pre-built and ready for you to use immediately after OpenShift AI is installed or

### upgraded.

### Workbench images are supported for a minimum of one year. Major updates to pre-

### configured workbench images occur about every six months. Therefore, two supported

Service Name Description 

NVIDIA NIM 

NVIDIA NIM, part of NVIDIA AI Enterprise, is a set of easy-to-use 

microservices designed for secure, reliable deployment of high-

performance AI model inferencing across the cloud, data center and 

workstations. Supporting a wide range of AI models, including open-source 

community and NVIDIA AI Foundation models, it ensures seamless, scalable 

AI inferencing, on-premises or in the cloud, leveraging industry standard 

APIs. 

OpenVINO OpenVINO is an open source toolkit to help optimize deep learning 

performance and deploy using an inference engine onto Intel® hardware. 

Pachyderm 

Pachyderm is the data foundation for machine learning. It provides 

industry-leading pipelines, data versioning, and lineage for data science 

teams to automate the machine learning lifecycle. 

Starburst 

Enterprise 

Starburst Enterprise platform (SEP) is the commericial distribution of Trino, 

which is an open-source, Massively Parallel Processing (MPP) ANSI SQL 

query engine. Starburst simplifies data access for your Red Hat OpenShift 

AI workloads by providing fast access to all of your data, no matter where it 

lives. Starburst does this by connecting directly to each data source and 

pulling the data back into memory for processing, alleviating the need to 

copy or move the data into a single location first. 

Jupyter Jupyter is a multi-user version of the notebook designed for companies, 

classrooms, and research labs. 

### period to update your code to use components from the latest available workbench image.

### Legacy workbench image versions, that is, not the two most recent versions, might still be

### available for selection. Legacy image versions include a label that indicates the image is out-

### of-date. To use the latest package versions, Red Hat recommends that you use the most

### recently added workbench image. If necessary, you can still access older workbench images

### from the registry, even if they are no longer supported. You can then add the older

### workbench images as custom workbench images to cater for your project’s specific

### requirements.

### *Workbench images denoted with Technology Preview in the following table are not supported *

### with Red Hat production service level agreements (SLAs) and might not be functionally

### complete. Red Hat does not recommend using Technology Preview features in production.

### These features provide early access to upcoming product features, enabling customers to

### test functionality and provide feedback during the development process.

### Notebooks Supported on x86_64

Image name Image version Preinstalled packages 

Code Server | Data 

Science | CPU | 

Python 3.12 

2025.2 

(Recommended) 

code-server: 4.104, Python 3.12, Boto3: 1.40, Kafka-

Python-ng: 2.2, Matplotlib: 3.10, NumPy: 2.3, Pandas: 

2.3, scikit-learn: 1.7, Scipy: 1.16, Sklearn-onnx: 1.19, 

ipykernel: 6.30, Kubeflow-Training: 1.9 

Jupyter | Data 

Science | CPU | 

Python 3.12 

2025.2 

(Recommended) 

Python 3.12, JupyterLab: 4.4, Boto3: 1.40, Kafka-

Python-ng: 2.2, Kubeflow SDK: 2.14, Matplotlib: 3.10, 

NumPy: 2.3, Pandas: 2.3, scikit-learn: 1.7, Scipy: 1.16, 

Odh-Elyra: 4.3, PyMongo: 4.15, Pyodbc: 5.2, 

Codeflare-SDK: 0.34, Feast: 0.59, Sklearn-onnx: 1.19, 

Psycopg: 3.2, MySQL Connector/Python: 9.4, 

Kubeflow-Training: 1.9 

Jupyter | Minimal | 

CPU | Python 3.12 

2025.2 

(Recommended) Python 3.12, JupyterLab: 4.4 

Jupyter | Minimal | 

CUDA | Python 3.12 

2025.2 

(Recommended) CUDA 12.9, Python 3.12, JupyterLab: 4.4 

Jupyter | Minimal | 

ROCm | Python 

3.12 

2025.2 

(Recommended) ROCm 6.4, Python 3.12, JupyterLab: 4.4 

Image name Image version Preinstalled packages 

Jupyter | PyTorch 

LLM Compressor | 

CUDA | Python 3.12 

2025.2 

(Recommended) 

CUDA 12.9, Python 3.12, PyTorch: 2.7, LLM-

Compressor: 0.9, JupyterLab: 4.4, Tensorboard: 

2.20, Boto3: 1.40, Kafka-Python-ng: 2.2, Kubeflow 

SDK: 2.14, Matplotlib: 3.10, NumPy: 2.3, Pandas: 2.3, 

scikit-learn: 1.7, Scipy: 1.16, Odh-Elyra: 4.3, PyMongo: 

4.15, Pyodbc: 5.2, Feast: 0.59, Sklearn-onnx: 1.19, 

Psycopg: 3.2, MySQL Connector/Python: 9.4, 

Kubeflow-Training: 1.9 

Jupyter | PyTorch | 

CUDA | Python 3.12 

2025.2 

(Recommended) 

CUDA 12.9, Python 3.12, PyTorch: 2.7, JupyterLab: 

4.4, Tensorboard: 2.20, Boto3: 1.40, Kafka-Python-

ng: 2.2, Kubeflow SDK: 2.14, Matplotlib: 3.10, NumPy: 

2.3, Pandas: 2.3, scikit-learn: 1.7, Scipy: 1.16, Odh-

Elyra: 4.3, PyMongo: 4.15, Pyodbc: 5.2, Codeflare-

SDK: 0.34, Feast: 0.59, Sklearn-onnx: 1.19, Psycopg: 

3.2, MySQL Connector/Python: 9.4, Kubeflow-

Training: 1.9 

Jupyter | PyTorch | 

ROCm | Python 

3.12 

2025.2 

(Recommended) 

ROCm 6.4, Python 3.12, ROCm-PyTorch: 2.7, 

JupyterLab: 4.4, Tensorboard: 2.20, Kafka-Python-

ng: 2.2, Matplotlib: 3.10, NumPy: 2.3, Pandas: 2.3, 

scikit-learn: 1.7, Scipy: 1.16, Odh-Elyra: 4.3, PyMongo: 

4.15, Pyodbc: 5.2, Codeflare-SDK: 0.34, Feast: 0.59, 

Sklearn-onnx: 1.19, Psycopg: 3.2, MySQL 

Connector/Python: 9.4, Kubeflow-Training: 1.9 

Jupyter | 

TensorFlow | CUDA 

| Python 3.12 

2025.2 

(Recommended) 

CUDA 12.9, Python 3.12, TensorFlow: 2.20, 

JupyterLab: 4.4, Tensorboard: 2.20, Nvidia-CUDA-

CU12-Bundle: 12.9, Boto3: 1.40, Kafka-Python-ng: 

2.2, Kubeflow SDK: 2.14, Matplotlib: 3.10, NumPy: 2.1, 

Pandas: 2.3, scikit-learn: 1.7, Scipy: 1.16, Odh-Elyra: 

4.3, PyMongo: 4.15, Pyodbc: 5.2, Codeflare-SDK: 

0.34, Feast: 0.59, Sklearn-onnx: 1.19, Psycopg: 3.2, 

MySQL Connector/Python: 9.4 

Jupyter | 

TensorFlow | 

ROCm | Python 

3.12 

2025.2 

(Recommended) 

ROCm 6.4, Python 3.12, TensorFlow-ROCm: 2.18, 

JupyterLab: 4.4, Tensorboard: 2.18, Kafka-Python-

ng: 2.2, Matplotlib: 3.10, NumPy: 1.26, Pandas: 2.3, 

scikit-learn: 1.7, Scipy: 1.16, Odh-Elyra: 4.3, PyMongo: 

4.15, Pyodbc: 5.2, Codeflare-SDK: 0.34, Sklearn-

onnx: 1.19, Psycopg: 3.2, MySQL Connector/Python: 

### Notebooks supported on IBM Power

Image name Image version Preinstalled packages 

Jupyter | TrustyAI | 

CPU | Python 3.12 

2025.2 

(Recommended) 

Python 3.12, JupyterLab: 4.4, TrustyAI: 0.6, 

Transformers: 4.56, Datasets: 4.0, Accelerate: 1.10, 

Torch: 2.7, Boto3: 1.40, Kafka-Python-ng: 2.2, 

Kubeflow SDK: 2.14, Matplotlib: 3.10, NumPy: 1.26, 

Pandas: 1.5, scikit-learn: 1.7, Scipy: 1.16, Odh-Elyra: 

4.3, PyMongo: 4.15, Pyodbc: 5.2, Codeflare-SDK: 

0.34, Sklearn-onnx: 1.19, Psycopg: 3.2, MySQL 

Connector/Python: 9.4, Kubeflow-Training: 1.9 

Image name Image 

version Preinstalled packages 

Code Server | Data 

Science | CPU | 

Python 3.12 

2025.2 

code-server 1.104, Python 3.12, Boto3: 1.40, Kafka-Python-

ng: 2.2, Matplotlib: 3.10, Numpy: 2.3, Pandas: 2.3, Scikit-

learn: 1.7, Scipy: 1.16, Sklearn-onnx: 1.19, ipykernel: 6.30, 

Kubeflow-Training: 1.9 

Jupyter | Data 

Science | CPU | 

Python 3.12 

2025.2 

Python 3.12, JupyterLab: 4.4, Boto3: 1.40, Kafka-Python-ng: 

2.2, Kfp: 2.14, Matplotlib: 3.10, Numpy: 2.3, Pandas: 2.3, 

Scikit-learn: 1.7, Scipy: 1.16, Odh-Elyra: 4.2, PyMongo: 4.14, 

Pyodbc: 5.2, Sklearn-onnx: 1.19, Psycopg: 3.2, MySQL 

Connector/Python: 9.3, Kubeflow-Training: 1.9 

Jupyter | Minimal | 

CPU | Python 3.12 2025.2 Python 3.12, JupyterLab: 4.4 

Jupyter | TrustyAI | 

CPU | Python 3.12 2025.2 

Python 3.12, JupyterLab: 4.4, TrustyAI: 0.6, Transformers: 

4.56, Datasets: 4.0, Accelerate: 1.10, Torch: 2.7, Boto3: 1.40, 

Kafka-Python-ng: 2.2, Kfp: 2.14, Matplotlib: 3.10, Numpy: 

1.26, Pandas: 1.5, Scikit-learn: 1.7, Scipy: 1.16, Odh-Elyra: 4.2, 

PyMongo: 4.14, Pyodbc: 5.2, Sklearn-onnx: 1.19, Psycopg: 

3.2, Kubeflow-Training: 1.9 

Jupyter | TrustyAI | 

Minimal | CPU | 

Python 3.12 

2025.2 

IPython: 9.8.0, ipykernel: 7.1.0, ipywidgets: 8.1.2, 

jupyter_client: 8.7.0, jupyter_core: 5.9.1, jupyter_server: 

2.17.0, jupyterlab: 4.4.9, nbclient: 0.10.2, nbconvert: 7.16.6, 

nbformat: 5.10.4, notebook: not installed, qtconsole: not 

installed, traitlets: 5.14.3 

### Notebooks Supported on IBM Z

# Supported model-serving runtimes

Image name Image version Preinstalled packages 

Code Server | Data 

Science | CPU | 

Python 3.12 

2025.2 

(Recommended) 

code-server 1.104, Python 3.12, Boto3: 1.40, Kafka-

Python-ng: 2.2, Numpy: 2.3, Pandas: 2.3, Scikit-

learn: 1.7, Scipy: 1.16, ipykernel: 6.30 

Jupyter | Data 

Science | CPU | 

Python 3.12 

2025.2 

(Recommended) 

Python 3.12, JupyterLab: 4.4, Boto3: 1.40, Kafka-

Python-ng: 2.2, Kfp: 2.14, Matplotlib: 3.10, Numpy: 

2.3, Pandas: 2.3, Scikit-learn: 1.7, Scipy: 1.16, 

PyMongo: 4.14, Pyodbc: 5.2, Sklearn-onnx: 1.19, 

Psycopg: 3.2, MySQL Connector/Python: 9.3 

Jupyter | Minimal | 

CPU | Python 3.12 

2025.2 

(Recommended) Python 3.12, JupyterLab: 4.4 

2024.2 Python 3.11, JupyterLab: 4.4 

Jupyter | TrustyAI | 

CPU | Python 3.12 

2025.2 

(Recommended) 

Python 3.12, JupyterLab: 4.4, TrustyAI: 0.6, 

Transformers: 4.56, Datasets: 4.0, Accelerate: 1.10, 

PyArrow 20.0, Torch: 2.7, Boto3: 1.40, Kafka-Python-

ng: 2.2, Kfp: 2.14, Matplotlib: 3.10, Numpy: 1.26, 

Pandas: 1.5, Scikit-learn: 1.7, Scipy: 1.16, PyMongo: 

4.14, Pyodbc: 5.2, Psycopg: 3.2 

Runtime name Description Exported model 

format 

vLLM Spyre AI Accelerator 

ServingRuntime for KServe 

A high-throughput and memory-

efficient inference and serving 

runtime that supports IBM Spyre AI 

accelerators on x86 

Supported models 

Caikit Text Generation Inference 

Server (Caikit-TGIS) 

ServingRuntime for KServe (1) 

A composite runtime for serving 

models in the Caikit format 

Caikit Text 

Generation 

Runtime name Description Exported model 

format 

Caikit Standalone 

ServingRuntime for KServe (2) 

A runtime for serving models in the 

Caikit embeddings format for 

embeddings tasks 

Caikit Embeddings 

OpenVINO Model Server 

A scalable, high-performance 

runtime for serving models that are 

optimized for Intel architectures 

PyTorch, 

TensorFlow, 

OpenVINO IR, 

PaddlePaddle, 

MXNet, Caffe, Kaldi 

[Deprecated] Text Generation 

Inference Server (TGIS) 

Standalone ServingRuntime for 

KServe (3) 

A runtime for serving TGI-enabled 

models 

PyTorch Model 

Formats 

vLLM NVIDIA GPU 

ServingRuntime for KServe 

A high-throughput and memory-

efficient inference and serving 

runtime for large language models 

that supports NVIDIA GPU 

accelerators 

Supported models 

vLLM Intel Gaudi Accelerator 

ServingRuntime for KServe 

A high-throughput and memory-

efficient inference and serving 

runtime that supports Intel Gaudi 

accelerators 

Supported models 

vLLM AMD GPU ServingRuntime 

for KServe 

A high-throughput and memory-

efficient inference and serving 

runtime that supports AMD GPU 

accelerators 

Supported models 

vLLM CPU ServingRuntime for 

KServe 

A high-throughput and memory-

efficient inference and serving 

runtime that supports IBM Power 

(ppc64le) and IBM Z (s390x) 

Supported models 

vLLM Spyre s390x 

ServingRuntime for KServe 

A high-throughput and memory-

efficient inference and serving 

runtime that supports IBM Spyre 

accelerators on s390x (IBM Z) 

Supported models 

### (1) The composite Caikit-TGIS runtime is based on Caikit and Text Generation Inference

### Server (TGIS). To use this runtime, you must convert your models to Caikit format. For an

### example, see Converting Hugging Face Hub models to Caikit format in the caikit-tgis-

### serving repository.

### (2) The Caikit Standalone runtime is based on Caikit NLP. To use this runtime, you must

### convert your models to the Caikit embeddings format. For an example, see Tests for text

### embedding module.

### *(3) The Text Generation Inference Server (TGIS) Standalone ServingRuntime for KServe is *

### deprecated. For more information, see Red Hat OpenShift AI release notes.

### Deployment requirements for supported model-serving runtimes

Runtime name Description Exported model 

format 

vLLM Spyre ppc64le 

ServingRuntime for KServe 

A high-throughput and memory-

efficient inference and serving 

runtime that supports IBM Spyre 

accelerators on ppc64le (IBM 

Power) 

Supported models 

MLServer ServingRuntime for 

KServe 

A runtime designed to simplify the 

deployment of machine learning 

models 

Scikit-Learn 

(sklearn), XGBoost, 

LightGBM, ONNX 

MLServer NVIDIA GPU 

ServingRuntime for KServe 

A GPU-accelerated inference and 

serving runtime for ONNX models 

that supports NVIDIA GPU 

accelerators 

ONNX 

AutoGluon (Technology Preview) A runtime that enables streamlined 

deployment of AutoML models 

AutoGluon 

TabularPredictor 

Runtime name Default 

protocol 

Additonal 

protocol 

Single 

node 

OpenShift 

support 

Deployment 

mode 

vLLM Spyre AI Accelerator 

ServingRuntime for KServe REST No Yes Raw 

### (1) For vLLM CPU ServingRuntime for KServe, if you are using IBM Z and IBM Power

### architecture, you can only deploy models in standard deployment mode.

### Tested and verified model-serving runtimes

Runtime name Default 

protocol 

Additonal 

protocol 

Single 

node 

OpenShift 

support 

Deployment 

mode 

Caikit Text Generation 

Inference Server (Caikit-TGIS) 

ServingRuntime for KServe 

REST gRPC Yes Raw 

Caikit Standalone 

ServingRuntime for KServe REST gRPC Yes Raw 

OpenVINO Model Server REST None Yes Raw 

[Deprecated] Text Generation 

Inference Server (TGIS) 

Standalone ServingRuntime for 

KServe 

gRPC None Yes Raw 

vLLM NVIDIA GPU 

ServingRuntime for KServe REST None Yes Raw 

vLLM Intel Gaudi Accelerator 

ServingRuntime for KServe REST None Yes Raw 

vLLM AMD GPU 

ServingRuntime for KServe REST None Yes Raw 

vLLM CPU ServingRuntime for 

KServe (1) REST None Yes Raw 

MLServer ServingRuntime for 

KServe REST No Yes Raw 

MLServer NVIDIA GPU 

ServingRuntime for KServe REST No Yes Raw 

AutoGluon (Technology 

Preview) REST No Yes Raw 

### Deployment requirements for tested and verified model-serving runtimes

# Training images

### To run distributed training jobs in OpenShift AI, you can use one of the following types of

### training image:

### Ray-based training images — purpose-built images tested and verified for

### distributed training with Ray. See the table below.

### Workbench images with the Kubeflow Training Operator (KFTO) — the same

### x86_64 workbench images listed in the Supported workbench images section can also

Name Description Exported model format 

NVIDIA Triton 

Inference Server 

An open-source inference-serving 

software for fast and scalable AI in 

applications. 

TensorRT, TensorFlow, PyTorch, 

ONNX, OpenVINO, Python, 

RAPIDS FIL, and more. 

IBM Power 

accelerated Triton 

Inference Server 

An open-source inference-serving 

software for fast and scalable AI in 

applications. 

PyTorch, ONNX, Python and ML 

IBM Z Accelerated 

for NVIDIA Triton 

Inference Server 

An open-source AI inference server 

that standardizes model deployment 

and execution, delivering 

streamlined, high‐performance 

inference at scale. 

ONNX-MLIR, Snap ML (C++), 

PyTorch. 

Name Default 

protocol 

Additional 

protocol 

Single node 

OpenShift 

support 

Deployment 

mode 

NVIDIA Triton 

Inference Server gRPC REST Yes 

Standard 

(Raw) 

IBM Power accelerated 

Triton Inference Server REST None Yes 

Standard 

(Raw) 

IBM Z Accelerated for 

NVIDIA Triton 

Inference Server 

gRPC REST Yes Standard 

(Raw) 

### described in the product documentation.

## Ray-based training images

### The following table provides information about the latest available Ray-based training

### images in Red Hat OpenShift AI. These images are AMD64 images, which might not work on

### other architectures.

### You can use the provided images as base images, and install additional packages to create

### custom images, as described in the product documentation. If the required packages are not

### included in the training image you want to use, contact Red Hat Support to request that the

### package be considered for inclusion, the images are Tested & Verified but not yet officially

### supported.

### The images are updated periodically with new versions of the installed packages. These

### images have been tested and verified for the use cases and configurations that are

### documented in the corresponding product documentation. Bug fixes and CVE fixes are

### delivered after they are available in upstream packages, in newer versions of these images

### only; fixes are not backported to earlier image versions.

Image 

type 

RHOAI 

version 

Image 

version URL 

Preinstalled 

packages 

CUDA 3.3 

2.52.1-

py312-

cu128 

quay.io/modh/ray:2.52.1-

py312-cu128 

Ray 2.52.1, CUDA 

12.8, Python 3.12 

3.4 

2.53.0-

py312-

cu128 

quay.io/modh/ray:2.53.0-

py312-cu128 

Ray 2.53.0, CUDA 

12.8, Python 3.12 

3.5 

2.55.1-

py312-

cu128 

quay.io/modh/ray:2.55.1-

py312-cu128 

Ray 2.55.1, CUDA 

12.8, Python 3.12 

Ray 

ROCm 3.3 

2.52.1-

py312-

rocm62 

quay.io/modh/ray:2.52.1-

py312-rocm62 

Ray 2.52.1, ROCm 

6.2, Python 3.12 

3.4 

2.53.0-

py312-

rocm64 

quay.io/modh/ray:2.53.0-

py312-rocm64 

Ray 2.53.0, ROCm 

6.4, Python 3.12 

## Kubeflow Trainer v2 ClusterTrainingRuntimes

### The following table lists the pre-installed ClusterTrainingRuntimes available in RHOAI 3.4 for

### use with the Kubeflow Trainer v2 ( `TrainJob ` API). These runtimes provide ready-to-use

### templates for distributed PyTorch training jobs.

Image 

type 

RHOAI 

version 

Image 

version URL 

Preinstalled 

packages 

3.5 

2.55.1-

py312-

rocm64 

quay.io/modh/ray:2.55.1-

py312-rocm64 

Ray 2.55.1, ROCm 

6.4, Python 3.12 

Runtime 

name Framework Default image Accelerator Preinstalled pa 

training-

hub training-hub 

registry.redhat.io/rhoai/odh-

th06-cuda130-torch210-

py312-rhel9 

CUDA 

Python 3.12, PyT 

Transformers: 4 

Datasets: 4.3.0, 

1.12.0, PEFT: 0.18 

0.24.0, DeepSpe 

Unsloth: 2026.3 

Attention: 2.8.3, 

Kubeflow SDK: 0 

2.4.4, Pandas: 2 

learn: 1.8.0 

training-

hub-cpu training-hub 

registry.redhat.io/rhoai/odh-

th06-cpu-torch210-py312-

rhel9 

CPU 

Python 3.12, PyT 

Transformers: 4 

Datasets: 4.3.0, 

1.12.0, PEFT: 0.18 

0.24.0, MLflow: 

Kubeflow SDK: 0 

2.4.4, Pandas: 2 

learn: 1.8.0 

Runtime 

name Framework Default image Accelerator Preinstalled pa 

training-

hub-rocm training-hub 

registry.redhat.io/rhoai/odh-

th06-rocm64-torch291-

py312-rhel9 

ROCm 

Python 3.12, PyT 

Transformers: 4 

Datasets: 4.3.0, 

1.12.0, PEFT: 0.18 

0.24.0, DeepSpe 

Unsloth: 2026.3 

Attention: 2.8.3, 

Kubeflow SDK: 0 

2.4.4, Pandas: 2 

learn: 1.8.0 

torch-

distributed torch 

registry.redhat.io/rhoai/odh-

th06-cuda130-torch210-

py312-rhel9 

CUDA 

Python 3.12, PyT 

Transformers: 4 

Datasets: 4.3.0, 

1.12.0, PEFT: 0.18 

0.24.0, DeepSpe 

Unsloth: 2026.3 

Attention: 2.8.3, 

Kubeflow SDK: 0 

2.4.4, Pandas: 2 

learn: 1.8.0 

torch-

distributed-

cpu 

torch 

registry.redhat.io/rhoai/odh-

th06-cpu-torch210-py312-

rhel9 

CPU 

Python 3.12, PyT 

Transformers: 4 

Datasets: 4.3.0, 

1.12.0, PEFT: 0.18 

0.24.0, MLflow: 

Kubeflow SDK: 0 

2.4.4, Pandas: 2 

learn: 1.8.0 

- ❢

SBR Shift Hosted Product(s) Red Hat OpenShift AI Category Supportability 

Tags 3scale_active_docs ai rhoai-self-managed 

Internal Tags distributed inference inference llm-d rhoai Article Type General 

# Private Notes

### This article is managed by Product Operations and contains

### authoritative support information for the OpenShift AI product.

### Please reach out to Ignacio Lago for any requested changes or raise a

### jira ticket [HERE]

### (https://redhat.atlassian.net/secure/CreateIssueDetails!init.jspa?

### pid=10450&issuetype=10014&reporter=70121%3A6da365fb-e842-

### 4453-a457-3a9e22

### 5e81ba&assignee=70121%3A6da365fb-e842-4453-a457-

### 3a9e225e81ba&priority=10004&components=25615&labels=rhoai&s

### ummary=Review/Update+RHOAI+Supp

### orted+Configuration).

### For discussion or queries relating to this article, please feel free to

### raise them in #team-openshift-ai-devel".

Runtime 

name Framework Default image Accelerator Preinstalled pa 

torch-

distributed-

rocm 

torch 

registry.redhat.io/rhoai/odh-

th06-rocm64-torch291-

py312-rhel9 

ROCm 

Python 3.12, PyT 

Transformers: 4 

Datasets: 4.3.0, 

1.12.0, PEFT: 0.18 

0.24.0, DeepSpe 

Unsloth: 2026.3 

Attention: 2.8.3, 

Kubeflow SDK: 0 

2.4.4, Pandas: 2 

### Was this helpful?

YES NO 

### Get notified when this content is updated FOLLOW

### People who viewed this article also viewed

### Red Hat OpenShift

### AI: 3.x でサポートさ

### れる構成

### Article - Aug 29,

### 2026

### Red Hat OpenShift

### AI: 3.x 버전에서 지원

### 되는 구성

### Article - Aug 29,

### 2026

### Red Hat OpenShift

### AI: Supported

### Configurations

### Article - Jun 12, 2026

- Comments

COMMUNITY MEMBER 

### Add comment

### Send notifications to content followers

### Mark comment as private

RED HAT 

### Submit

PRO 

519 Points 

Private Comment May 11, 2026 6:04 PM 

### Codrin Bucur

### The ONNX format, used by most of our customers, seems to be

### missing from the OpenVINO "Exported model format" column

Reply Privately 

RED HAT 

PRO 

519 Points 

Private Comment May 11, 2026 6:08 PM 

### Codrin Bucur

### The "Supported models" link

### (https://docs.vllm.ai/en/latest/models/supported_models.html), next

### to many of the vLLM runtimes takes the Red Hat customer, reading this

### document, to the upstream vLLM documentation which is very

### confusing. What the RH customers would expect instead, is a link to RH

### validated models or models that run specifically with the vLLM runtime

### from the table.

### More specifically, for "vLLM CPU ServingRuntime for KServe" runtime,

### based on discussions with Intel, only certain models are supported and

### we would need to link to such a documentation not to the whole list of

### models from vLLM upstream

Reply Privately 

RED HAT 

### Quick Links

### Help

### Site Info

### Related Sites

About 

Red Hat Subscription Value 

About Red Hat 

Red Hat Jobs 

About Red Hat 

Jobs 

Events 

Locations 

Contact Red Hat 

Red Hat Blog 

Inclusion at Red Hat 

Cool Stuff Store 

Red Hat Summit 

Copyright © 2026 Red Hat 

Privacy statement 

Terms of use 

All policies and guidelines 

Digital accessibility 

Cookie preferences 