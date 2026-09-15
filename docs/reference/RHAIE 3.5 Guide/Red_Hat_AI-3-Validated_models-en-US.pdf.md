# Red_Hat_AI-3-Validated_models-en-US.pdf

- Red Hat AI 3

# Validated models

Red Hat AI validated models 

Last Updated: 2026-08-25

### Red Hat AI 3 Validated models

Red Hat AI validated models

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

Learn about the validated models that you can inference serve with Red Hat AI.

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

CHAPTER 1. RED HAT AI VALIDATED MODELS 

CHAPTER 2 VALIDATED MODEL SUPPORT LEVELS 

CHAPTER 3 VALIDATED MODEL SUPPORT MATRIX 

CHAPTER 4 VALIDATED OCI ARTIFACT MODEL CONTAINER IMAGES 

CHAPTER 5 VALIDATED RED HAT AI MODELCAR CONTAINER IMAGES 

CHAPTER 6 VALIDATED MODELS FOR X86_64 CPU INFERENCE SERVING 

CHAPTER 7 VALIDATED MODELS FOR USE WITH IBM POWER AND IBM SPYRE AI ACCELERATORS 

CHAPTER 8 VALIDATED MODELS FOR USE WITH IBM Z AND IBM SPYRE AI ACCELERATORS 

CHAPTER 9 VALIDATED MODELS FOR GEOSPATIAL INFERENCE WITH TERRATORCH 

3 

4 

5 

6 

32 

38 

46 

47 

48 

49 

### PREFACE

Red Hat AI validated and enabled models have been tested and verified to work with Red Hat AI Inference. You can deploy these models for inference serving on supported hardware configurations. 

### CHAPTER 1. RED HAT AI VALIDATED MODELS

Red Hat AI validated models have been tested and verified to work correctly across supported hardware and product configurations. These models are available as Hugging Face downloads, as OCI artifact images, and as modelcar container images. Platform-specific validated models are also available for IBM Spyre on IBM Power and IBM Z systems. 

*In addition to validated models, Red Hat ships enabled models * as modelcar container images. Enabled models are architecturally supported but have not completed the full validation pipeline. For details about the difference between validated and enabled models, see Model support levels . 

NOTE 

If you are using AI Inference with Podman as part of a RHEL AI deployment, use ModelCar container images or Hugging Face models. 

If you are using AI Inference as part of an Red Hat OpenShift AI deployment on OpenShift Container Platform, use OCI artifact images. 

Red Hat uses GuideLLM for performance benchmarking and Language Model Evaluation Harness for accuracy evaluations. 

For a complete list of models with platform compatibility data, see Model support matrix. 

IMPORTANT 

AMD GPUs support only FP8 and GGUF quantization variant models. For more information, see Supported hardware . 

### CHAPTER 2. VALIDATED MODEL SUPPORT LEVELS

Red Hat AI ships models at two support levels: validated and enabled. Understanding these support levels helps you make informed decisions about which models to deploy for your inference workloads. 

Validated models 

Red Hat has tested validated models with GuideLLM performance benchmarking and Language Model Evaluation Harness accuracy evaluations across specific OpenShift Container Platform, Red Hat OpenShift AI, and Red Hat AI Inference version combinations. Validated models are benchmarked for specific use cases. This can include inference performance, quality, and other benchmarks. All third-party models are governed by the third-party license of the original model provider. 

Validated models include general-purpose large language models such as Llama, Granite, Mistral, Qwen, and Phi model families, and quantized variants in FP8, INT4, INT8, NVFP4, and BF16 formats. 

Enabled models 

Red Hat ships enabled models as modelcar container images with architecturally compatible configurations. Enabled models have not completed the full benchmarking and accuracy evaluation pipeline that validated models receive. Enabled models include specialty categories such as: 

**Embedding models, for example granite-embedding-english-r2, all-MiniLM-L6-v2, nomic-embed-text-v1.5, and Qwen3-Embedding-8B **

**Safety and guard models, for example Llama-Guard-4-12B and granite-guardian-3.2-5b **

**Security models, for example Foundation-Sec-8B-Instruct **

**Reasoning models, for example Phi-4-reasoning **

Additional general-purpose models not yet through the full validation pipeline 

Both support levels indicate that Red Hat ships the model and provides support. The key difference is the depth of testing: validated models have quantified performance and accuracy data for specific platform configurations, while Red Hat verifies that enabled models work with the inference server architecture. 

To find the support level for a specific model, see Model support matrix. 

### CHAPTER 3. VALIDATED MODEL SUPPORT MATRIX

You can use the model support matrix to verify that a model is compatible with your Red Hat AI Inference, Red Hat OpenShift AI, and vLLM version combination before deploying it for inference serving. The matrix lists all validated and enabled models with their minimum platform version requirements and modelcar container image paths. 

For more information, see Red Hat AI models  on Hugging Face. 

NOTE 

Verify that your deployed Red Hat AI Inference, Red Hat OpenShift AI, and vLLM versions meet or exceed the minimum versions listed for your target model. For an explanation of the Validated and Enabled status values, see Model support levels . 

NOTE 

Hugging Face links require internet access. If you are working in a disconnected environment, use the modelcar container image paths with your mirrored registry. For more information, see Deploying the standalone Red Hat AI Inference container in a disconnected environment. 

Table 3.1. Red Hat AI Model support matrix 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Qwen2.5-7B-Instruct 

registry.redh at.io/rhelai1/ modelcar-qwen2-5-7b-instruct:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 17.6 GB 

1XA100-40, 1XA100-80, 1XH100, 1XH200, 1XL4, 2XA100-40, 2XA100-80, 2XH100, 2XL4, 4XA100-40, 4XA100-80, 4XH100 

n/a 

RedHatAI/Qwen3-Coder-480B-A35B-Instruct-FP8 

registry.redh at.io/rhelai1/ modelcar-qwen3-coder-480b-a35b-instruct-fp8:1.5 

Vali date d 

v0.1 0.1.1 

3.2. 2 

2.25 554 .5 GB 

4XB200, 4XH200 n/a 

RedHatAI/Qwen3-Embedding-8B 

registry.redh at.io/rhelai1/ modelcar-qwen3-embedding-8b:1.5 

Ena bled 

v0.11 .2 

3.2. 5 

3.2 17.5 GB 

1XL4 n/a 

RedHatAI/Apertus-8B-Instruct-2509-FP8-dynamic 

registry.redh at.io/rhai/m odelcar-apertus-8b-instruct-2509-fp8-dynamic:3.0 

Vali date d 

v0.11 .2 

3.2. 5 

3.2 10.5 GB 

1XA100-80, 1XB200, 1XH100, 1XH200, 2XA100-80, 2XB200, 2XH100, 2XH200, 4XA100-80, 4XB200, 4XH100, 4XH200, 8XA100-80, 8XB200, 8XH100, 8XH200 

n/a 

RedHatAI/DeepSee k-R1-0528-quantized.w4a16 

registry.redh at.io/rhelai1/ modelcar-deepseek-r1-0528-quantized-w4a16:1.5 

Vali date d 

v0.1 0.0 

3.2.1 2.24 427. 2 GB 

4XB200, 4XH200, 8XB200, 8XH100, 8XH200 

n/a 

RedHatAI/DeepSee k-V4-Flash 

registry.redh at.io/rhai/m odelcar-redhatai-deepseek-v4-flash:3.0 

Vali date d 

v0.2 4.0 

3.5. 0 

3.5. 0 

183. 6 GB 

4XH200 n/a 

RedHatAI/DeepSee k-V4-Pro 

registry.redh at.io/rhai/m odelcar-redhatai-deepseek-v4-pro-essential:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

994 .5 GB 

8XH200 n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Foundati on-Sec-8B-Instruct 

registry.redh at.io/rhai/m odelcar-foundation-sec-8b-instruct:3.0 

Ena bled 

v0.1 3.0 

3.3. 0 

3.3. 0 

18.5 GB 

1XH200 n/a 

RedHatAI/GLM-5.2-FP8 

registry.redh at.io/rhai/m odelcar-redhatai-glm-5-2-fp8:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

869 .0 GB 

4XMI300X, 8XH200, 8XMI300X 

n/a 

RedHatAI/Kimi-K2-Instruct-quantized.w4a16 

registry.redh at.io/rhelai1/ modelcar-kimi-k2-instruct-quantized-w4a16:1.5 

Vali date d 

v0.1 0.0 

3.2.1 2.24 628. 7 GB 

4XB200, 8XB200, 8XH200 

n/a 

RedHatAI/Laguna-XS.2 

registry.redh at.io/rhai/m odelcar-redhatai-laguna-xs-2:3.0 

Vali date d 

v0.2 4.0 

3.5. 0 

3.5. 0 

77. 0 GB 

1XH200, 8XA100-80 

n/a 

RedHatAI/Laguna-XS.2-FP8 

registry.redh at.io/rhai/m odelcar-redhatai-laguna-xs-2-fp8:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

40. 7 GB 

4XL4 n/a 

RedHatAI/Laguna-XS.2-NVFP4 

registry.redh at.io/rhai/m odelcar-redhatai-laguna-xs-2-nvfp4:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

24.8 GB 

1XA100-40 n/a 

RedHatAI/Llama-3.1-8B-Instruct 

  v0.11 .2 

3.2. 5 

3.2  1XH200 n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Llama-3.1-Nemotron-70B-Instruct-HF-FP8-dynamic 

registry.redh at.io/rhelai1/ modelcar-llama-3-1-nemotron-70b-instruct-hf-fp8-dynamic:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 83. 6 GB 

1XH200, 2XA100-80, 2XH100, 4XA100-40, 4XA100-80, 4XH100, 8XA100-40, 8XH100 

n/a 

RedHatAI/Llama-3.2-3B-Instruct-quantized.w8a8 

registry.redh at.io/rhai/m odelcar-redhatai-llama-3-2-3b-instruct-quantized-w8a8:3.0 

Vali date d 

v0.2 4.0 

3.5. 0 

3.5. 0 

5.1 GB 

1XH200 n/a 

RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic 

registry.redh at.io/rhelai1/ modelcar-llama-3-3-70b-instruct-fp8-dynamic:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 83. 6 GB 

1XH200, 2XH100, 4XA100-40, 4XA100-80, 4XH100, 8XA100-40, 8XA100-80, 8XH100 

n/a 

RedHatAI/Llama-3.3-70B-Instruct-quantized.w4a16 

registry.redh at.io/rhelai1/ modelcar-llama-3-3-70b-instruct-quantized-w4a16:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 45. 5 GB 

1XH100, 2XH100, 4XA100-40, 4XH100, 8XA100-40, 8XH100 

n/a 

RedHatAI/Llama-3.3-70B-Instruct-quantized.w8a8 

registry.redh at.io/rhelai1/ modelcar-llama-3-3-70b-instruct-quantized-w8a8:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 83. 6 GB 

2XH100, 4XA100-40, 4XA100-80, 4XH100, 8XA100-40, 8XH100 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Llama-3_1-Nemotron-Ultra-253B-v1 

registry.redh at.io/rhai/m odelcar-redhatai-llama-3-1-nemotron-ultra-253b-v1:3.0 

Vali date d 

v0.2 4.0 

3.5. 0 

3.5. 0 

582. 9 GB 

8XH100 n/a 

RedHatAI/Llama-4-Scout-17B-16E-Instruct-FP8-dynamic 

registry.redh at.io/rhelai1/ modelcar-llama-4-scout-17b-16e-instruct-fp8-dynamic:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 131. 9 GB 

2XH100, 2XH200, 4XH100, 8XH100, 8XL4 

n/a 

RedHatAI/Llama-4-Scout-17B-16E-Instruct-quantized.w4a16 

registry.redh at.io/rhelai1/ modelcar-llama-4-scout-17b-16e-instruct-quantized-w4a16:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 74. 7 GB 

2XH100, 2XH200, 4XA100-40, 4XH100, 8XA100-40, 8XH100 

n/a 

RedHatAI/Llama-Guard-4-12B 

registry.redh at.io/rhai/m odelcar-llama-guard-4-12b:3.0 

Ena bled 

v0.11 .2 

3.2. 5 

3.2 27.7 GB 

1XH200 n/a 

RedHatAI/Meta-Llama-3.1-8B-Instruct-FP8-dynamic 

registry.redh at.io/rhelai1/ modelcar-llama-3-1-8b-instruct-fp8-dynamic:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 10.5 GB 

1XH200 n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/MiniMax-M2.5 

registry.redh at.io/rhai/m odelcar-minimax-m2-5:3.0 

Vali date d 

v0.1 4.1 

3.4. 0-ea.1 

3.4. 0-ea.1 

264. 7 GB 

2XB200, 4XA100-80, 4XB200, 4XH100, 4XH200 

n/a 

RedHatAI/Ministral-3-14B-Instruct-2512 

registry.redh at.io/rhai/m odelcar-ministral-3-14b-instruct-2512:3.0 

Vali date d 

v0.1 0.1.1 

3.2. 2 

2.25 18.1 GB 

1XA100-80, 1XB200, 1XH100, 1XH200, 1XL4, 2XA100-80, 2XB200, 2XH100, 2XH200, 2XL4, 4XA100-80, 4XB200, 4XH100, 4XH200, 4XL4, 8XA100-80, 8XB200, 8XH100, 8XH200, 8XL4 

n/a 

RedHatAI/Mistral-Medium-3.5-128B 

registry.redh at.io/rhai/m odelcar-redhatai-mistral-medium-3-5-128b:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

153. 7 GB 

1XMI300X, 2XA100-80, 2XH100, 2XH200, 2XMI300X, 4XA100-80, 4XH100, 4XMI300X, 8XH100, 8XMI300X 

n/a 

RedHatAI/Mistral-Small-3.1-24B-Instruct-2503-FP8-dynamic 

registry.redh at.io/rhelai1/ modelcar-mistral-small-3-1-24b-instruct-2503-fp8-dynamic:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 29.7 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-40, 2XA100-80, 2XH100, 2XL4, 4XA100-40, 4XA100-80, 4XH100, 4XL4, 8XA100-40, 8XH100 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Mistral-Small-3.1-24B-Instruct-2503-quantized.w4a16 

registry.redh at.io/rhelai1/ modelcar-mistral-small-3-1-24b-instruct-2503-quantized-w4a16:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 17.3 GB 

1XA100-40, 1XA100-80, 1XH100, 1XH200, 2XA100-40, 2XA100-80, 2XH100, 4XA100-40, 4XA100-80, 4XH100, 8XA100-40, 8XH100 

n/a 

RedHatAI/Mistral-Small-3.1-24B-Instruct-2503-quantized.w8a8 

registry.redh at.io/rhelai1/ modelcar-mistral-small-3-1-24b-instruct-2503-quantized-w8a8:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 29.7 GB 

1XA100-40, 1XA100-80, 1XH100, 1XH200, 2XA100-40, 2XA100-80, 2XH100, 2XL4, 4XA100-40, 4XA100-80, 4XH100, 4XL4, 8XA100-40, 8XA100-80, 8XH100 

n/a 

RedHatAI/Mistral-Small-3.2-24B-Instruct-2506 

registry.redh at.io/rhai/m odelcar-redhatai-mistral-small-3-2-24b-instruct-2506:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

55.3 GB 

2XA100-80, 4XL4 n/a 

RedHatAI/Molmo2-4B 

registry.redh at.io/rhai/m odelcar-redhatai-molmo2-4b:3.0 

Vali date d 

v0.2 4.0 

3.5. 0 

3.5. 0 

22.4 GB 

1XA100-80 n/a 

RedHatAI/Molmo2-8B 

registry.redh at.io/rhai/m odelcar-redhatai-molmo2-8b:3.0 

Vali date d 

v0.2 4.0 

3.5. 0 

3.5. 0 

39. 9 GB 

1XA100-80 n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/NVIDIA-Nemotron-3-Super-120B-A12B-FP8 

registry.redh at.io/rhai/m odelcar-redhatai-nvidia-nemotron-3-super-120b-a12b-fp8:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

147. 7 GB 

1XMI300X, 2XMI300X, 4XMI300X, 8XL4, 8XMI300X 

n/a 

RedHatAI/NVIDIA-Nemotron-3-Ultra-550B-A55B-BF16-FP8-BLOCK 

registry.redh at.io/rhai/m odelcar-redhatai-nemotron-ultra-550b-bf16-fp8-block:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

647 .8 GB 

8XH200 n/a 

RedHatAI/NVIDIA-Nemotron-3-Ultra-550B-A55B-BF16-W4A16-G128 

registry.redh at.io/rhai/m odelcar-redhatai-nemotron-ultra-550b-bf16-w4a16-g128:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

336 .5 GB 

4XH200, 8XA100-80 

n/a 

RedHatAI/NVIDIA-Nemotron-3-Ultra-550B-A55B-FP8-Dynamic 

registry.redh at.io/rhai/m odelcar-redhatai-nvidia-nemotron-3-ultra-550b-a55b-fp8-dynamic:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

647 .8 GB 

4XMI300X, 8XA100-80, 8XH200, 8XMI300X 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4 

registry.redh at.io/rhai/m odelcar-redhatai-nvidia-nemotron-3-ultra-550b-a55b-nvfp4:3.0 

Vali date d 

v0.2 4.0 

3.5. 0 

3.5. 0 

405 .2 GB 

4XH200, 8XH100 n/a 

RedHatAI/NVIDIA-Nemotron-Nano-9B-v2-FP8-dynamic 

registry.redh at.io/rhelai1/ modelcar-nvidia-nemotron-nano-9b-v2-fp8-dynamic:1.5 

Vali date d 

v0.1 0.1.1 

3.2. 2 

2.25 11.6 GB 

1XA100-40, 1XB200, 1XH100, 1XH200 

n/a 

RedHatAI/Phi-4-mini-instruct-FP8-dynamic 

registry.redh at.io/rhai/m odelcar-phi-4-mini-instruct-fp8-dynamic:3.0 

Vali date d 

v0.1 4.1 

3.4. 0-ea.1 

3.4. 0-ea.1 

6.6 GB 

1XA100-80, 1XB200, 1XH100, 1XH200, 1XL4, 2XA100-80, 2XB200, 2XH100, 2XH200, 2XL4, 4XA100-80, 4XB200, 4XH100, 4XH200, 4XL4, 8XA100-80, 8XH100, 8XH200, 8XL4 

n/a 

RedHatAI/Phi-4-reasoning 

registry.redh at.io/rhai/m odelcar-phi-4-reasoning:3. 0 

Ena bled 

v0.11 .2 

3.2. 5 

3.2 33. 8 GB 

1XH200 n/a 

RedHatAI/Phi-4-reasoning-FP8-dynamic 

registry.redh at.io/rhai/m odelcar-phi-4-reasoning-fp8-dynamic:3.0 

Vali date d 

v0.1 3.0 

3.3. 0 

3.3. 0 

18.1 GB 

1XA100-80, 1XB200, 1XH100, 1XH200, 1XL4, 2XA100-40, 2XA100-80, 2XB200, 2XH100, 2XH200, 2XL4 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Qwen2.5-1.5B-quantized.w8a8 

registry.redh at.io/rhai/m odelcar-redhatai-qwen2-5-1-5b-quantized-w8a8:3.0 

Vali date d 

v0.2 4.0 

3.5. 0 

3.5. 0 

2.6 GB 

1XH200 n/a 

RedHatAI/Qwen2.5-7B-Instruct-FP8-dynamic 

registry.redh at.io/rhelai1/ modelcar-qwen2-5-7b-instruct-fp8-dynamic:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 10.1 GB 

1XA100-40, 1XA100-80, 1XH100, 1XH200, 1XL4, 2XA100-40, 2XA100-80, 2XH100, 2XL4, 4XA100-40, 4XA100-80, 4XH100 

n/a 

RedHatAI/Qwen2.5-7B-Instruct-quantized.w4a16 

registry.redh at.io/rhelai1/ modelcar-qwen2-5-7b-instruct-quantized-w4a16:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 6.4 GB 

1XA100-40, 1XA100-80, 1XH100, 1XL4, 2XA100-40, 2XH100, 4XA100-40, 4XH100, 4XL4 

n/a 

RedHatAI/Qwen2.5-7B-Instruct-quantized.w8a8 

registry.redh at.io/rhelai1/ modelcar-qwen2-5-7b-instruct-quantized-w8a8:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 10.1 GB 

1XA100-40, 1XA100-80, 1XH100, 1XL4, 2XA100-40, 2XA100-80, 2XH100, 2XL4, 4XA100-40, 4XH100, 4XL4 

n/a 

RedHatAI/Qwen3-8B 

registry.redh at.io/rhai/m odelcar-redhatai-qwen3-8b:3.0 

Vali date d 

v0.2 4.0 

3.5. 0 

3.5. 0 

18.9 GB 

1XH200, 8XA100-80 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Qwen3-8B-FP8-dynamic 

registry.redh at.io/rhelai1/ modelcar-qwen3-8b-fp8-dynamic:1.5 

Vali date d 

v0.1 0.0 

3.2.1 2.24 10.9 GB 

1XA100-40, 1XH100, 1XH200, 1XL4, 2XA100-40, 2XH100, 2XH200, 2XL4, 4XA100-40, 4XH100, 4XH200, 4XL4, 8XA100-40, 8XH100, 8XH200, 8XL4 

n/a 

RedHatAI/Qwen3-Coder-480B-A35B-Instruct-FP8 

registry.redh at.io/rhelai1/ modelcar-qwen3-coder-480b-a35b-instruct-fp8:1.5 

Vali date d 

v0.1 0.1.1 

3.2. 2 

2.25 554 .5 GB 

4XB200, 4XH200 n/a 

RedHatAI/Qwen3-Coder-Next-NVFP4 

registry.redh at.io/rhai/m odelcar-qwen3-coder-next-nvfp4:3.0 

Vali date d 

v0.1 4.1 

3.4. 0-ea.1 

3.4. 0-ea.1 

54. 8 GB 

1XB200, 1XH100, 1XH200, 2XB200, 2XH100, 2XH200, 4XB200, 4XH100, 4XH200, 8XB200, 8XH100, 8XH200 

n/a 

RedHatAI/Qwen3-Next-80B-A3B-Instruct-FP8 

registry.redh at.io/rhai/m odelcar-qwen3-next-80b-a3b-instruct-fp8:3.0 

Vali date d 

v0.1 3.0 

3.3. 0 

3.3. 0 

94. 4 GB 

1XB200, 2XA100-80, 2XB200, 2XH200, 4XA100-80, 4XH200 

n/a 

RedHatAI/Qwen3-Next-80B-A3B-Instruct-quantized.w4a16 

registry.redh at.io/rhai/m odelcar-qwen3-next-80b-a3b-instruct-quantized-w4a16:3.0 

Vali date d 

v0.1 3.0 

3.3. 0 

3.3. 0 

50. 5 GB 

1XA100-80, 1XB200, 1XH100, 1XH200, 2XA100-80, 2XB200, 2XH100, 2XH200, 4XA100-80, 4XB200, 4XH100, 4XH200 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Qwen3-VL-235B-A22B-Instruct-NVFP4 

registry.redh at.io/rhai/m odelcar-qwen3-vl-235b-a22b-instruct-nvfp4:3.0 

Vali date d 

v0.11 .2 

3.2. 5 

3.2 155. 6 GB 

1XB200, 2XA100-80, 2XB200, 2XH100, 2XH200, 4XA100-80, 4XB200, 4XH100, 4XH200, 8XA100-80, 8XB200, 8XH100, 8XH200 

n/a 

RedHatAI/Qwen3-VL-30B-A3B-Instruct 

registry.redh at.io/rhai/m odelcar-redhatai-qwen3-vl-30b-a3b-instruct:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

71.5 GB 

1XA100-80, 1XH100, 1XH200, 1XMI300X, 2XA100-80, 2XH100, 2XMI300X, 4XA100-80, 4XH100, 4XL4, 4XMI300X, 8XA100-80, 8XMI300X 

n/a 

RedHatAI/Qwen3.5-122B-A10B-FP8-dynamic 

registry.redh at.io/rhai/m odelcar-qwen3-5-122b-a10b-fp8-dynamic:3.0 

Vali date d 

v0.1 7.1 

3.4. 0-ea.2 

3.4. 0-ea.2 

147. 1 GB 

2XA100-80, 2XH100, 4XA100-80, 4XH200, 8XA100-80, 8XH100 

n/a 

RedHatAI/Qwen3.5-2B 

registry.redh at.io/rhai/m odelcar-redhatai-qwen3-5-2b:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

5.3 GB 

8XA100-80 n/a 

RedHatAI/Qwen3.5-35B-A3B-FP8-dynamic 

registry.redh at.io/rhai/m odelcar-qwen3-5-35b-a3b-fp8-dynamic:3.0 

Vali date d 

v0.1 7.1 

3.4. 0-ea.2 

3.4. 0-ea.2 

43. 4 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 2XH200, 4XA100-80, 4XH100, 4XH200, 8XA100-80, 8XH100, 8XH200 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Qwen3.5-397B-A17B-FP8-dynamic 

registry.redh at.io/rhai/m odelcar-qwen3-5-397b-a17b-fp8-dynamic:3.0 

Vali date d 

v0.1 7.1 

3.4. 0-ea.2 

3.4. 0-ea.2 

466 .0 GB 

4XH200, 8XA100-80, 8XH100 

n/a 

RedHatAI/Qwen3.6 -27B-FP8 

registry.redh at.io/rhai/m odelcar-redhatai-qwen3-6-27b-fp8:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

35.5 GB 

8XH100 n/a 

RedHatAI/Qwen3.6 -35B-A3B 

registry.redh at.io/rhai/m odelcar-redhatai-qwen3-6-35b-a3b:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

82.7 GB 

1XA100-80, 1XH100, 2XA100-80, 2XH100, 2XH200, 4XA100-80, 4XH100, 8XH100, 8XL4 

n/a 

RedHatAI/Qwen3.6 -35B-A3B-FP8 

registry.redh at.io/rhai/m odelcar-redhatai-qwen3-6-35b-a3b-fp8:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

43.1 GB 

1XA100-80, 1XH100, 1XH200, 1XMI300X, 2XA100-80, 2XH100, 2XH200, 2XL4, 2XMI300X, 4XA100-80, 4XH100, 4XH200, 4XL4, 4XMI300X, 8XH100, 8XMI300X 

n/a 

RedHatAI/Qwen3.6 -35B-A3B-FP8-dynamic 

registry.redh at.io/rhai/m odelcar-redhatai-qwen3-6-35b-a3b-fp8-dynamic:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

45. 3 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 2XH200, 2XL4, 4XA100-80, 4XH100, 4XH200, 4XL4, 8XA100-80, 8XH100 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Qwen3.6 -35B-A3B-NVFP4 

registry.redh at.io/rhai/m odelcar-redhatai-qwen3-6-35b-a3b-nvfp4:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

28.9 GB 

1XA100-40, 1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 2XH200, 4XA100-80, 4XH100, 4XH200, 8XA100-80, 8XH100 

n/a 

RedHatAI/Trinity-Large-Thinking-NVFP4 

registry.redh at.io/rhai/m odelcar-redhatai-trinity-large-thinking-nvfp4:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

266. 3 GB 

2XH200, 4XA100-80, 4XH100, 4XH200, 8XH200 

n/a 

RedHatAI/diffusion gemma-26B-A4B-it-FP8-dynamic 

registry.redh at.io/rhai/m odelcar-redhatai-diffusionge mma-26b-a4b-it-fp8-dynamic:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

31.3 GB 

1XA100-80, 1XMI300X, 2XMI300X, 4XMI300X, 8XMI300X 

n/a 

RedHatAI/diffusion gemma-26B-A4B-it-NVFP4 

registry.redh at.io/rhai/m odelcar-redhatai-diffusionge mma-26b-a4b-it-nvfp4:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

20. 8 GB 

1XA100-80 n/a 

RedHatAI/gemma-3-12b-it 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-3-12b-it:3.0 

Ena bled 

v0.11 .2 

3.2. 5 

3.2 28.1 GB 

1XH200 n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/gemma-3n-E4B-it-FP8-dynamic 

registry.redh at.io/rhelai1/ modelcar-gemma-3n-e4b-it-fp8-dynamic:1.5 

Vali date d 

v0.1 0.0 

3.2.1 2.24 13.6 GB 

1XA100-40, 1XH100, 1XH200, 1XL4, 2XA100-40, 2XH100, 2XH200, 2XL4, 4XA100-40, 4XH100, 4XH200, 4XL4, 8XA100-40, 8XH100, 8XH200, 8XL4 

n/a 

RedHatAI/gemma-4-12B-it-FP8-Dynamic 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-12b-it-fp8-dynamic:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

17.3 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 2XH200, 4XA100-80, 4XH100, 8XA100-80 

n/a 

RedHatAI/gemma-4-12B-it-NVFP4 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-12b-it-nvfp4:3.0 

Vali date d 

v0.2 4.0 

3.5. 0 

3.5. 0 

11.9 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 2XH200, 4XA100-80, 4XH100, 8XA100-80 

n/a 

RedHatAI/gemma-4-26B-A4B-it 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-26b-a4b-it:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

59. 4 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 2XH200, 4XA100-80, 4XH100, 4XL4 

n/a 

RedHatAI/gemma-4-26B-A4B-it-FP8-Dynamic 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-26b-a4b-it-fp8-dynamic:3.0 

Ena bled 

v0.1 8.0 

3.4. 0 

3.4. 0 

33. 0 GB 

1XA100-80, 1XH100, 1XH200, 1XMI300X, 2XA100-80, 2XH100, 2XH200, 2XL4, 2XMI300X, 4XH100, 4XMI300X, 8XMI300X 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/gemma-4-26B-A4B-it-NVFP4 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-26b-a4b-it-nvfp4:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

18.9 GB 

1XA100-40, 1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 4XA100-80, 4XH100 

n/a 

RedHatAI/gemma-4-26b-a4b 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-26b-a4b:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

59. 4 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 2XH200, 4XA100-80, 4XH100, 4XH200, 8XA100-80 

n/a 

RedHatAI/gemma-4-31B-it 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-31b-it:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

72. 0 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 4XA100-80, 4XH100 

n/a 

RedHatAI/gemma-4-31B-it-FP8-Dynamic 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-31b-it-fp8-dynamic:3.0 

Ena bled 

v0.1 8.0 

3.4. 0 

3.4. 0 

38. 3 GB 

1XA100-80, 1XH100, 1XH200, 1XMI300X, 2XA100-80, 2XH100, 2XH200, 2XL4, 2XMI300X, 4XA100-80, 4XH100, 4XMI300X, 8XA100-80, 8XMI300X 

n/a 

RedHatAI/gemma-4-31B-it-FP8-block 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-31b-it-fp8-block:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

38. 3 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 2XL4, 4XA100-80, 4XH100 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/gemma-4-31B-it-NVFP4 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-31b-it-nvfp4:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

26.8 GB 

1XA100-40, 1XA100-80, 1XH100, 1XH200, 2XA100-40, 2XA100-80, 2XH100, 4XA100-80, 4XH100, 8XA100-80 

n/a 

RedHatAI/gemma-4-31B 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-31b:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

72. 0 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 4XA100-80, 4XH100, 8XA100-80 

n/a 

RedHatAI/gemma-4-E4B-it 

registry.redh at.io/rhai/m odelcar-redhatai-gemma-4-e4b-it:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

18.4 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 2XH200, 4XA100-80, 4XH100, 8XA100-80 

n/a 

RedHatAI/gpt-oss-120b 

  v0.1 3.0 

3.3. 0 

3.3. 0 

 1XH200 n/a 

RedHatAI/gpt-oss-20b 

 Vali date d 

v0.1 3.0 

3.3. 0 

3.3. 0 

15.9 GB 

1XA100-80, 1XH200 n/a 

RedHatAI/granite-3.1-8b-instruct-fp8-dynamic 

registry.redh at.io/rhelai1/ modelcar-granite-3-1-8b-instruct-fp8-dynamic:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 10.1 GB 

1XH200 n/a 

RedHatAI/granite-3.1-8b-instruct-quantized.w4a16 

registry.redh at.io/rhelai1/ modelcar-granite-3-1-8b-instruct-quantized-w4a16:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 5.7 GB 

1XH200 n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/granite-4.0-h-small-FP8-dynamic 

registry.redh at.io/rhai/m odelcar-granite-4-0-h-small-fp8-dynamic:3.0 

Vali date d 

v0.1 3.0 

3.3. 0 

3.3. 0 

37. 6 GB 

1XA100-80, 1XB200, 1XH100, 1XH200 

n/a 

RedHatAI/phi-4-FP8-dynamic 

registry.redh at.io/rhelai1/ modelcar-phi-4-fp8-dynamic:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 18.1 GB 

1XA100-40, 1XA100-80, 1XH100, 1XH200, 2XA100-40, 2XA100-80, 2XH100, 2XL4 

n/a 

RedHatAI/phi-4-quantized.w4a16 

registry.redh at.io/rhelai1/ modelcar-phi-4-quantized-w4a16:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 10.5 GB 

1XA100-40, 1XA100-80, 1XH100, 2XA100-40, 2XA100-80, 2XH100, 2XL4 

n/a 

RedHatAI/phi-4-quantized.w8a8 

registry.redh at.io/rhelai1/ modelcar-phi-4-quantized-w8a8:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 18.1 GB 

1XA100-40, 1XA100-80, 1XH100, 2XA100-40, 2XA100-80, 2XH100 

n/a 

RedHatAI/sarvam-105b-FP8-Dynamic 

registry.redh at.io/rhai/m odelcar-sarvam-105b-fp8-dynamic:3.0 

Vali date d 

v0.1 8.0 

3.4. 0 

3.4. 0 

129. 6 GB 

1XH200, 2XH200, 4XH100, 4XH200, 8XH100, 8XH200 

n/a 

RedHatAI/sarvam-30b-FP8-Dynamic 

registry.redh at.io/rhai/m odelcar-sarvam-30b-fp8-dynamic:3.0 

Vali date d 

v0.1 8.0 

3.4. 0 

3.4. 0 

44. 5 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-80, 2XH100, 2XH200, 4XA100-80, 4XH100, 4XH200, 8XA100-80, 8XH100, 8XH200 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/snowflake -arctic-embed-l-v2.0 

registry.redh at.io/rhai/m odelcar-redhatai-snowflake-arctic-embed-l-v2-0:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

2.7 GB 

1XL4 n/a 

RedHatAI/translate gemma-4b-it 

registry.redh at.io/rhai/m odelcar-redhatai-translatege mma-4b-it:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

9.9 GB 

1XA100-80, 1XL4 n/a 

allenai/olmOCR-2-7B-1025-FP8 

registry.redh at.io/rhai/m odelcar-allenai-olmocr-2-7b-1025-fp8:3.0 

Vali date d 

v0.1 9.1 

3.5. 0-ea.1 

3.5. 0-ea.1 

11.6 GB 

1XA100-80, 1XL4 n/a 

RedHatAI/granite-3.1-8b-instruct 

registry.redh at.io/rhelai1/ modelcar-granite-3-1-8b-instruct:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 18.8 GB 

1XA100-40, 1XA100-80, 1XH100, 1XH200, 1XL4, 2XA100-40, 2XA100-80, 2XH100, 2XL4, 4XA100-40, 4XA100-80, 4XH100, 4XL4, 8XA100-40, 8XA100-80 

n/a 

ibm-granite/granite-docling-258m 

registry.redh at.io/rhai/m odelcar-ibm-granite-granite-docling-258m:3.0 

Vali date d 

v0.1 9.1 

3.5. 0-ea.1 

3.5. 0-ea.1 

0.6 GB 

1XA100-80, 1XL4 n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

ibm-granite/granite-guardian-3.2-5b 

registry.redh at.io/rhai/m odelcar-granite-guardian-3-2-5b:3.0 

Ena bled 

v0.11 .2 

3.2. 5 

3.2 13.3 GB 

1XH200 n/a 

RedHatAI/granite-4.0-h-tiny-FP8-dynamic 

registry.redh at.io/rhai/m odelcar-granite-4-0-h-tiny-fp8-dynamic:3.0 

Vali date d 

v0.1 0.1.1 

3.2. 2 

2.25 8.2 GB 

1XB200, 1XH100, 1XH200, 1XL4 

n/a 

meta-llama/Llama-2-7b-chat-hf 

registry.redh at.io/rhai/m odelcar-llama-2-7b-chat-hf:3.0 

Ena bled 

v0.11 .2 

3.2. 5 

3.2 15.5 GB 

1XH200 n/a 

RedHatAI/Llama-3.1-8B-Instruct 

registry.redh at.io/rhai/m odelcar-llama-3-1-8b-instruct-essential:3.0 

Vali date d 

v0.8 .4 

3.0 2.21 18.5 GB 

1XA100-40, 1XA100-80, 1XH100, 1XH200, 1XL4, 2XA100-40, 2XA100-80, 2XH100, 2XL4, 4XA100-40, 4XA100-80, 4XH100, 4XL4, 8XA100-40, 8XA100-80 

n/a 

RedHatAI/Llama-3.3-70B-Instruct 

registry.redh at.io/rhelai1/ modelcar-llama-3-3-70b-instruct:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 162. 3 GB 

2XH200, 4XA100-80, 4XH100, 8XA100-40, 8XH100 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Llama-4-Maverick-17B-128E-Instruct 

registry.redh at.io/rhelai1/ modelcar-llama-4-maverick-17b-128e-instruct:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 923. 7 GB 

8XH200 n/a 

RedHatAI/Llama-4-Maverick-17B-128E-Instruct-FP8 

registry.redh at.io/rhelai1/ modelcar-llama-4-maverick-17b-128e-instruct-fp8:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 479 .3 GB 

4XH200, 8XH100 n/a 

RedHatAI/Llama-4-Scout-17B-16E-Instruct 

registry.redh at.io/rhelai1/ modelcar-llama-4-scout-17b-16e-instruct:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 249. 9 GB 

4XA100-80, 4XH100, 4XH200, 8XH100 

n/a 

meta-llama/llama-3.1-8b-instruct 

  v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

 1XH200 n/a 

RedHatAI/phi-4 registry.redh at.io/rhelai1/ modelcar-phi-4:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 33. 8 GB 

1XA100-40, 1XA100-80, 1XH100, 1XH200, 2XA100-40, 2XA100-80, 2XH100, 2XL4 

n/a 

RedHatAI/Devstral-Small-2-24B-Instruct-2512 

registry.redh at.io/rhai/m odelcar-devstral-small-2-24b-instruct-2512:3.0 

Vali date d 

v0.1 4.1 

3.4. 0-ea.1 

3.4. 0-ea.1 

29.7 GB 

1XA100-80, 1XB200, 1XH100, 1XH200, 2XA100-80, 2XB200, 2XH100, 2XH200, 4XA100-80, 4XB200, 4XH100, 4XH200, 4XL4, 8XA100-80, 8XB200, 8XH100, 8XH200, 8XL4 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

mistralai/Magistral-Small-2509 

registry.redh at.io/rhai/m odelcar-mistralai-magistral-small-2509:3.0 

Vali date d 

v0.1 9.1 

3.5. 0-ea.1 

3.5. 0-ea.1 

55.3 GB 

2XA100-80, 4XL4 n/a 

RedHatAI/Ministral-3-3B-Instruct-2512 

registry.redh at.io/rhai/m odelcar-ministral-3-3b-instruct-2512:3.0 

Vali date d 

v0.1 4.1 

3.4. 0-ea.1 

3.4. 0-ea.1 

5.4 GB 

1XA100-80, 1XB200, 1XH100, 1XH200, 1XL4, 2XA100-80, 2XB200, 2XH100, 2XH200, 2XL4, 4XA100-80, 4XB200, 4XH100, 4XH200, 4XL4, 8XA100-80, 8XB200, 8XH100, 8XH200, 8XL4 

n/a 

RedHatAI/Mistral-Large-3-675B-Instruct-2512 

registry.redh at.io/rhai/m odelcar-mistral-large-3-675b-instruct-2512:3.0 

Vali date d 

v0.11 .2 

3.2. 5 

3.2 783 .8 GB 

8XB200, 8XH200 n/a 

RedHatAI/Mistral-Large-3-675B-Instruct-2512-NVFP4 

registry.redh at.io/rhai/m odelcar-mistral-large-3-675b-instruct-2512-nvfp4:3.0 

Vali date d 

v0.11 .2 

3.2. 5 

3.2 463 .7 GB 

4XB200, 4XH200, 8XA100-80, 8XB200, 8XH100, 8XH200 

n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/Mistral-Small-24B-Instruct-2501 

registry.redh at.io/rhelai1/ modelcar-mistral-small-24b-instruct-2501:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 54. 3 GB 

1XA100-80, 1XH100, 2XA100-40, 2XA100-80, 2XH100, 4XA100-40, 4XA100-80, 4XH100, 4XL4, 8XA100-40, 8XH100 

n/a 

RedHatAI/Mistral-Small-3.1-24B-Instruct-2503 

registry.redh at.io/rhelai1/ modelcar-mistral-small-3-1-24b-instruct-2503:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 55.3 GB 

1XA100-80, 1XH100, 1XH200, 2XA100-40, 2XA100-80, 2XH100, 4XA100-40, 4XA100-80, 4XH100, 4XL4, 8XA100-40, 8XH100 

n/a 

RedHatAI/Mixtral-8x7B-Instruct-v0.1 

registry.redh at.io/rhelai1/ modelcar-mixtral-8x7b-instruct-v0-1:1.4 

Vali date d 

v0.8 .4 

3.0 2.21 107. 5 GB 

1XH200, 2XA100-80, 2XH100, 4XA100-40, 4XA100-80, 4XH100, 8XA100-40, 8XH100, 8XL4 

n/a 

RedHatAI/Llama-3.1-Nemotron-70B-Instruct-HF 

registry.redh at.io/rhelai1/ modelcar-llama-3-1-nemotron-70b-instruct-hf:1.5 

Vali date d 

v0.8 .4 

3.0 2.21 162. 3 GB 

2XH200, 4XA100-80, 4XH100, 8XA100-40 

n/a 

nvidia/Llama-3.1-Nemotron-Safety-Guard-8B-v3 

registry.redh at.io/rhai/m odelcar-nvidia-llama-3-1-nemotron-safety-guard-8b-v3:3.0 

Vali date d 

v0.1 9.1 

3.5. 0-ea.1 

3.5. 0-ea.1 

18.5 GB 

1XA100-80, 1XL4 n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/NVIDIA-Nemotron-3-Nano-30B-A3B-FP8 

registry.redh at.io/rhai/m odelcar-nvidia-nemotron-3-nano-30b-a3b-fp8:3.0 

Vali date d 

v0.11 .2 

3.2. 5 

3.2 37. 6 GB 

1XB200, 1XH100, 1XH200, 2XB200, 2XH100, 2XH200, 4XB200, 4XH100, 4XH200, 8XB200, 8XH100, 8XH200 

n/a 

RedHatAI/NVIDIA-Nemotron-3-Super-120B-A12B-BF16 

registry.redh at.io/rhai/m odelcar-nvidia-nemotron-3-super-120b-a12b-bf16:3.0 

Vali date d 

v0.1 7.1 

3.4. 0-ea.2 

3.4. 0-ea.2 

284. 4 GB 

2XH200, 4XA100-80, 4XH100, 4XH200, 8XA100-80, 8XH100, 8XH200 

n/a 

RedHatAI/NVIDIA-Nemotron-3-Super-120B-A12B-FP8 

registry.redh at.io/rhai/m odelcar-nvidia-nemotron-3-super-120b-a12b-fp8:3.0 

Vali date d 

v0.1 7.1 

3.4. 0-ea.2 

3.4. 0-ea.2 

147. 7 GB 

1XH200, 2XH100, 2XH200, 4XH100, 4XH200, 8XH100, 8XH200 

n/a 

RedHatAI/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4 

registry.redh at.io/rhai/m odelcar-nvidia-nemotron-3-super-120b-a12b-nvfp4:3.0 

Vali date d 

v0.1 7.1 

3.4. 0-ea.2 

3.4. 0-ea.2 

92.4 GB 

1XH200, 2XH100, 2XH200 

n/a 

openai/Whisper-Large-V3 

registry.redh at.io/rhai/m odelcar-openai-whisper-large-v3:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

10.7 GB 

1XL4 n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/gpt-oss-120b 

registry.redh at.io/rhelai1/ modelcar-gpt-oss-120b:1.5 

Vali date d 

v0.1 0.1.1 

3.2. 2 

2.25 75.1 GB 

1XB200, 1XH100, 1XH200, 2XB200, 2XH100, 2XH200, 4XA100-40, 4XB200, 4XH100, 4XH200, 4XL4, 8XA100-40, 8XB200, 8XH100, 8XH200, 8XL4 

n/a 

RedHatAI/gpt-oss-20b 

registry.redh at.io/rhelai1/ modelcar-gpt-oss-20b:1.5 

Vali date d 

v0.1 0.1.1 

3.5. 0-ea.2 

3.5. 0-ea.2 

15.9 GB 

1XA100-40, 1XA100-80, 1XB200, 1XH100, 1XH200, 1XL4, 2XA100-40, 2XB200, 2XH100, 2XH200, 2XL4, 4XA100-40, 4XB200, 4XH100, 4XH200, 4XL4, 8XA100-40, 8XB200, 8XH100, 8XH200, 8XL4 

n/a 

openai/gpt-oss-safeguard-120b 

registry.redh at.io/rhai/m odelcar-openai-gpt-oss-safeguard-120b:3.0 

Vali date d 

v0.2 1.0 

3.5. 0-ea.2 

3.5. 0-ea.2 

75.1 GB 

1XA100-80, 2XA100-40 

n/a 

openai/gpt-oss-safeguard-20b 

registry.redh at.io/rhai/m odelcar-openai-gpt-oss-safeguard-20b:3.0 

Vali date d 

v0.1 9.1 

3.5. 0-ea.1 

3.5. 0-ea.1 

15.9 GB 

1XA100-80, 2XL4 n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

RedHatAI/gpt-oss-120b-essential 

registry.redh at.io/rhai/m odelcar-gpt-oss-120b-essential:3.0 

Vali date d 

v0.1 3.0 

3.3. 0 

3.3. 0 

75.1 GB 

1XH200 n/a 

RedHatAI/gpt-oss-20b-essential 

registry.redh at.io/rhai/m odelcar-gpt-oss-20b-essential:3.0 

Vali date d 

v0.1 3.0 

3.3. 0 

3.3. 0 

15.9 GB 

1XA100-80, 1XH200 n/a 

Model Modelcar Stat us 

Min. vLL M vers ion 

Min. RH AII vers ion 

Min. RH OAI vers ion 

Min. vRA M (GB ) 

Supported GPUs Mig rati on gui dan ce 

Additional resources 

Model support levels 

Validated Red Hat AI ModelCar container images 

Validated OCI artifact model container images for OpenShift Container Platform and Red Hat OpenShift AI deployments 

### CHAPTER 4. VALIDATED OCI ARTIFACT MODEL CONTAINER IMAGES

The following table lists validated OCI artifact model container images available from the Red Hat container registry, including baseline and quantized variants for each supported model. 

Table 4.1. Validated OCI artifact model container images 

Model Quantized variants OCI artifact images 

llama-4-scout-17b-16e-instruct 

INT4, FP8 Baseline: **registry.redhat.io/rhelai1/llama -4-scout-17b-16e-instruct:1.5 **

INT4: **registry.redhat.io/rhelai1/llama -4-scout-17b-16e-instruct-quantized-w4a16:1.5 **

FP8: **registry.redhat.io/rhelai1/llama -4-scout-17b-16e-instruct-fp8-dynamic:1.5 **

llama-4-maverick-17b-128e-instruct 

FP8 Baseline: **registry.redhat.io/rhelai1/llama -4-maverick-17b-128e-instruct:1.5 **

FP8: **registry.redhat.io/rhelai1/llama -4-maverick-17b-128e-instruct-fp8:1.5 **

mistral-small-3-1-24b-instruct-2503 

INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/mistr al-small-3-1-24b-instruct-2503:1.5 **

INT4: **registry.redhat.io/rhelai1/mistr al-small-3-1-24b-instruct-2503-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/mistr al-small-3-1-24b-instruct-2503-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/mistr al-small-3-1-24b-instruct-2503-fp8-dynamic:1.5 **

llama-3-3-70b-instruct INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/llama -3-3-70b-instruct:1.5 **

INT4: **registry.redhat.io/rhelai1/llama -3-3-70b-instruct-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/llama -3-3-70b-instruct-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/llama -3-3-70b-instruct-fp8-dynamic:1.5 **

llama-3-1-8b-instruct INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/llama -3-1-8b-instruct:1.5 **

INT4: **registry.redhat.io/rhelai1/llama -3-1-8b-instruct-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/llama -3-1-8b-instruct-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/llama -3-1-8b-instruct-fp8-dynamic:1.5 **

Model Quantized variants OCI artifact images 

granite-3-1-8b-instruct INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/grani te-3-1-8b-instruct:1.5 **

INT4: **registry.redhat.io/rhelai1/grani te-3-1-8b-instruct-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/grani te-3-1-8b-instruct-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/grani te-3-1-8b-instruct-fp8-dynamic:1.5 **

phi-4 INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/phi-4:1.5 **

INT4: **registry.redhat.io/rhelai1/phi-4-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/phi-4-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/phi-4-fp8-dynamic:1.5 **

Model Quantized variants OCI artifact images 

qwen2-5-7b-instruct INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/qwen 2-5-7b-instruct:1.5 **

INT4: **registry.redhat.io/rhelai1/qwen 2-5-7b-instruct-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/qwen 2-5-7b-instruct-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/qwen 2-5-7b-instruct-fp8-dynamic:1.5 **

mistral-small-24b-instruct-2501 

INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/mistr al-small-24b-instruct-2501:1.5 **

INT4: **registry.redhat.io/rhelai1/mistr al-small-24b-instruct-2501-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/mistr al-small-24b-instruct-2501-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/mistr al-small-24b-instruct-2501-fp8-dynamic:1.5 **

mixtral-8x7b-instruct-v0-1 None Baseline: **registry.redhat.io/rhelai1/mixtr al-8x7b-instruct-v0-1:1.4 **

granite-3-1-8b-base INT4 (baseline currently unavailable) INT4: 

**registry.redhat.io/rhelai1/grani te-3-1-8b-base-quantized-w4a16:1.5 **

Model Quantized variants OCI artifact images 

granite-3.1-8b-starter-v2 None Baseline: **registry.redhat.io/rhelai1/grani te-3.1-8b-starter-v2:1.5 **

llama-3-1-nemotron-70b-instruct-hf 

FP8 Baseline: **registry.redhat.io/rhelai1/llama -3-1-nemotron-70b-instruct-hf:1.5 **

FP8: **registry.redhat.io/rhelai1/llama -3-1-nemotron-70b-instruct-hf-fp8-dynamic:1.5 **

gemma-2-9b-it FP8 Baseline: **registry.redhat.io/rhelai1/gem ma-2-9b-it:1.5 **

FP8: **registry.redhat.io/rhelai1/gem ma-2-9b-it-fp8:1.5 **

deepseek-r1-0528 INT4 (baseline currently unavailable) INT4: 

**registry.redhat.io/rhelai1/deep seek-r1-0528-quantized-w4a16:1.5 **

qwen3-8b FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhelai1/qwen 3-8b-fp8-dynamic:1.5 **

kimi-k2-instruct INT4 (baseline currently unavailable) INT4: 

**registry.redhat.io/rhelai1/kimi-k2-instruct-quantized-w4a16:1.5 **

gemma-3n-e4b-it FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhelai1/gem ma-3n-e4b-it-fp8-dynamic:1.5 **

Model Quantized variants OCI artifact images 

gpt-oss-120b None Baseline: **registry.redhat.io/rhelai1/gpt-oss-120b:1.5 **

gpt-oss-20b None Baseline: **registry.redhat.io/rhelai1/gpt-oss-20b:1.5 **

qwen3-coder-480b-a35b-instruct 

FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhelai1/qwen 3-coder-480b-a35b-instruct-fp8:1.5 **

whisper-large-v3-turbo INT4 (baseline currently unavailable) INT4: 

**registry.redhat.io/rhelai1/whis per-large-v3-turbo-quantized-w4a16:1.5 **

voxtral-mini-3b-2507 FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhelai1/voxtr al-mini-3b-2507-fp8-dynamic:1.5 **

nvidia-nemotron-nano-9b-v2 

FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhelai1/nvidi a-nemotron-nano-9b-v2-fp8-dynamic:1.5 **

Model Quantized variants OCI artifact images 

### CHAPTER 5. VALIDATED RED HAT AI MODELCAR CONTAINER IMAGES

You can use ModelCar container images to deploy validated models with Red Hat AI Inference. The following table lists the available ModelCar container images and their quantized variants. 

NOTE 

For minimum platform version requirements and validation status for each model, see Model support matrix. 

Table 5.1. Validated Red Hat AI ModelCar container images 

Model Quantized variants ModelCar images 

llama-4-scout-17b-16e-instruct 

INT4, FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-llama-4-scout-17b-16e-instruct:1.5 **

INT4: **registry.redhat.io/rhelai1/mod elcar-llama-4-scout-17b-16e-instruct-quantized-w4a16:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-llama-4-scout-17b-16e-instruct-fp8-dynamic:1.5 **

llama-4-maverick-17b-128e-instruct 

FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-llama-4-maverick-17b-128e-instruct:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-llama-4-maverick-17b-128e-instruct-fp8:1.5 **

mistral-small-3-1-24b-instruct-2503 

INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-mistral-small-3-1-24b-instruct-2503:1.5 **

INT4: **registry.redhat.io/rhelai1/mod elcar-mistral-small-3-1-24b-instruct-2503-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/mod elcar-mistral-small-3-1-24b-instruct-2503-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-mistral-small-3-1-24b-instruct-2503-fp8-dynamic:1.5 **

llama-3-3-70b-instruct INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-llama-3-3-70b-instruct:1.5 **

INT4: **registry.redhat.io/rhelai1/mod elcar-llama-3-3-70b-instruct-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/mod elcar-llama-3-3-70b-instruct-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-llama-3-3-70b-instruct-fp8-dynamic:1.5 **

Model Quantized variants ModelCar images 

llama-3-1-8b-instruct INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-llama-3-1-8b-instruct:1.5 **

INT4: **registry.redhat.io/rhelai1/mod elcar-llama-3-1-8b-instruct-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/mod elcar-llama-3-1-8b-instruct-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-llama-3-1-8b-instruct-fp8-dynamic:1.5 **

granite-3-1-8b-instruct INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-granite-3-1-8b-instruct:1.5 **

INT4: **registry.redhat.io/rhelai1/mod elcar-granite-3-1-8b-instruct-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/mod elcar-granite-3-1-8b-instruct-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-granite-3-1-8b-instruct-fp8-dynamic:1.5 **

Model Quantized variants ModelCar images 

phi-4 INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-phi-4:1.5 **

INT4: **registry.redhat.io/rhelai1/mod elcar-phi-4-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/mod elcar-phi-4-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-phi-4-fp8-dynamic:1.5 **

qwen2-5-7b-instruct INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-qwen2-5-7b-instruct:1.5 **

INT4: **registry.redhat.io/rhelai1/mod elcar-qwen2-5-7b-instruct-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/mod elcar-qwen2-5-7b-instruct-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-qwen2-5-7b-instruct-fp8-dynamic:1.5 **

Model Quantized variants ModelCar images 

mistral-small-24b-instruct-2501 

INT4, INT8, FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-mistral-small-24b-instruct-2501:1.5 **

INT4: **registry.redhat.io/rhelai1/mod elcar-mistral-small-24b-instruct-2501-quantized-w4a16:1.5 **

INT8: **registry.redhat.io/rhelai1/mod elcar-mistral-small-24b-instruct-2501-quantized-w8a8:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-mistral-small-24b-instruct-2501-fp8-dynamic:1.5 **

mixtral-8x7b-instruct-v0-1 None Baseline: **registry.redhat.io/rhelai1/mod elcar-mixtral-8x7b-instruct-v0-1:1.4 **

granite-3-1-8b-base INT4 (baseline currently unavailable) INT4: 

**registry.redhat.io/rhelai1/mod elcar-granite-3-1-8b-base-quantized-w4a16:1.5 **

granite-3-1-8b-starter-v2 None Baseline: **registry.redhat.io/rhelai1/mod elcar-granite-3-1-8b-starter-v2:1.5 **

llama-3-1-nemotron-70b-instruct-hf 

FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-llama-3-1-nemotron-70b-instruct-hf:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-llama-3-1-nemotron-70b-instruct-hf-fp8-dynamic:1.5 **

Model Quantized variants ModelCar images 

gemma-2-9b-it FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-gemma-2-9b-it:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-gemma-2-9b-it-fp8:1.5 **

deepseek-r1-0528 INT4 (baseline currently unavailable) INT4: 

**registry.redhat.io/rhelai1/mod elcar-deepseek-r1-0528-quantized-w4a16:1.5 **

qwen3-8b FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhelai1/mod elcar-qwen3-8b-fp8-dynamic:1.5 **

kimi-k2-instruct INT4 (baseline currently unavailable) INT4: 

**registry.redhat.io/rhelai1/mod elcar-kimi-k2-instruct-quantized-w4a16:1.5 **

gemma-3n-e4b-it FP8 Baseline: **registry.redhat.io/rhelai1/mod elcar-gemma-3n-e4b-it:1.5 **

FP8: **registry.redhat.io/rhelai1/mod elcar-gemma-3n-e4b-it-fp8-dynamic:1.5 **

gpt-oss-120b None Baseline: **registry.redhat.io/rhelai1/mod elcar-gpt-oss-120b:1.5 **

gpt-oss-20b None Baseline: **registry.redhat.io/rhelai1/mod elcar-gpt-oss-20b:1.5 **

Model Quantized variants ModelCar images 

qwen3-coder-480b-a35b-instruct 

FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhelai1/mod elcar-qwen3-coder-480b-a35b-instruct-fp8:1.5 **

whisper-large-v3-turbo INT4 (baseline currently unavailable) INT4: 

**registry.redhat.io/rhelai1/mod elcar-whisper-large-v3-turbo-quantized-w4a16:1.5 **

voxtral-mini-3b-2507 FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhelai1/mod elcar-voxtral-mini-3b-2507-fp8-dynamic:1.5 **

nvidia-nemotron-nano-9b-v2 

FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhelai1/mod elcar-nvidia-nemotron-nano-9b-v2-fp8-dynamic:1.5 **

phi-4-reasoning FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhai/modelc ar-phi-4-reasoning-fp8-dynamic:3.0 **

qwen3-vl-235b-a22b-instruct-nvfp4 

None Baseline: **registry.redhat.io/rhai/modelc ar-qwen3-vl-235b-a22b-instruct-nvfp4:3.0 **

qwen3-next-80b-a3b-instruct 

INT4 (baseline currently unavailable) INT4: 

**registry.redhat.io/rhai/modelc ar-qwen3-next-80b-a3b-instruct-quantized-w4a16:3.0 **

Model Quantized variants ModelCar images 

granite-4-0-h-tiny FP8 Baseline: **registry.redhat.io/rhai/modelc ar-granite-4-0-h-tiny:3.0 **

FP8: **registry.redhat.io/rhai/modelc ar-granite-4-0-h-tiny-fp8-dynamic:3.0 **

granite-4-0-h-small FP8 Baseline: **registry.redhat.io/rhai/modelc ar-granite-4-0-h-small:3.0 **

FP8: **registry.redhat.io/rhai/modelc ar-granite-4-0-h-small-fp8-dynamic:3.0 **

mistral-large-3-675b-instruct-2512 

None Baseline: **registry.redhat.io/rhai/modelc ar-mistral-large-3-675b-instruct-2512:3.0 **

mistral-large-3-675b-instruct-2512-nvfp4 

None Baseline: **registry.redhat.io/rhai/modelc ar-mistral-large-3-675b-instruct-2512-nvfp4:3.0 **

apertus-8b-instruct-2509 FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhai/modelc ar-apertus-8b-instruct-2509-fp8-dynamic:3.0 **

nvidia-nemotron-3-nano-30b-a3b 

FP8 (baseline currently unavailable) FP8: 

**registry.redhat.io/rhai/modelc ar-nvidia-nemotron-3-nano-30b-a3b-fp8:3.0 **

ministral-3-14b-instruct-2512 

None Baseline: **registry.redhat.io/rhai/modelc ar-ministral-3-14b-instruct-2512:3.0 **

Model Quantized variants ModelCar images 

### CHAPTER 6. VALIDATED MODELS FOR X86_64 CPU INFERENCE SERVING

The following large language models have been validated for use with Red Hat AI Inference on x86_64 CPUs. 

Table 6.1. Validated models for inferencing with x86_64 CPU 

Model Hugging Face model card Number of parameters 

TinyLlama-1.1B-Chat-v1.0 TinyLlama/TinyLlama-1.1B-Chat-v1.0 1.1B 

Llama-3.2-1B-Instruct meta-llama/Llama-3.2-1B-Instruct 1B 

granite-3.2-2b-instruct ibm-granite/granite-3.2-2b-instruct 2B 

TinyLlama-1.1B-Chat-v1.0-pruned2.4 RedHatAI/TinyLlama-1.1B-Chat-v1.0-pruned2.4 

1.1B (pruned) 

IMPORTANT 

Quantization formats that require GPU-specific kernels, such as Marlin format, are not supported for CPU inference. Use AWQ or GPTQ quantization formats that are compatible with CPU execution. 

The following table provides general guidance for approximate system RAM requirements based on model size: 

Table 6.2. Memory requirements for inference serving with x86_64 CPU 

Model size Minimum RAM Recommended RAM 

125M - 500M 8 GB 16 GB 

500M - 1B 16 GB 32 GB 

1B - 3B 32 GB 64 GB 

NOTE 

Actual memory usage depends on the model architecture, context length, and batch size. **Increase the VLLM_CPU_KVCACHE_SPACE environment variable to allocate more **memory for the key-value cache when using longer context lengths. 

### CHAPTER 7. VALIDATED MODELS FOR USE WITH IBM POWER AND IBM SPYRE AI ACCELERATORS

The following large language models are supported for IBM Power systems with IBM Spyre AI accelerators. 

NOTE 

IBM Spyre AI accelerator cards support FP16 format model weights only. For compatible models, the Red Hat AI Inference inference engine automatically converts weights to FP16 at startup. No additional configuration is needed. 

Table 7.1. IBM Granite models for use with IBM Spyre AI accelerators 

Model Hugging Face model card 

granite-3.3-8b-instruct ibm-granite/granite-3.3-8b-instruct 

granite-embedding-30m-english ibm-granite/granite-embedding-30m-english 

granite-embedding-107m-multilingual ibm-granite/granite-embedding-107m-multilingual 

granite-embedding-125m-english ibm-granite/granite-embedding-125m-english 

granite-embedding-278m-multilingual ibm-granite/granite-embedding-278m-multilingual 

Table 7.2. Reranker models for use with IBM Spyre AI accelerators 

Model Hugging Face model card 

bge-reranker-v2-m3 BAAI/bge-reranker-v2-m3 

IMPORTANT 

Pre-built IBM Granite models run with the specific Python packages that are included in the Red Hat AI Inference Spyre container image. The models are tied to fixed configurations for Spyre card count, batch size, and input/output context sizes. 

Updating or replacing Python packages in the Red Hat AI Inference Spyre container image is not supported. 

### CHAPTER 8. VALIDATED MODELS FOR USE WITH IBM Z AND IBM SPYRE AI ACCELERATORS

The following large language models are supported for IBM Z systems with IBM Spyre AI accelerators. 

NOTE 

IBM Spyre AI accelerator cards support FP16 format model weights only. For compatible models, the Red Hat AI Inference inference engine automatically converts weights to FP16 at startup. No additional configuration is needed. 

Table 8.1. Decoder models for use with IBM Spyre AI accelerators 

Model Hugging Face model card 

granite-3.3-8b-instruct ibm-granite/granite-3.3-8b-instruct 

granite-3.3-8b-instruct-FP8 ibm-granite/granite-3.3-8b-instruct-FP8 

granite-4.1-8b ibm-granite/granite-4.1-8b 

granite-4.1-8b-fp8 ibm-granite/granite-4.1-8b-fp8 

Ministral-3-14B-Instruct-2512-BF16 mistralai/Ministral-3-14B-Instruct-2512-BF16 

IMPORTANT 

Pre-built IBM Granite models run with the specific Python packages that are included in the Red Hat AI Inference Spyre container image. The models are tied to fixed configurations for Spyre card count, batch size, and input/output context sizes. 

Updating or replacing Python packages in the Red Hat AI Inference Spyre container image is not supported. 

### CHAPTER 9. VALIDATED MODELS FOR GEOSPATIAL INFERENCE WITH TERRATORCH

The following IBM and NASA Prithvi geospatial foundation models are validated for use with AI Inference and TerraTorch. 

NOTE 

Prithvi-EO-2.0 models use the Vision Transformer (ViT) architecture and require TerraTorch as the model implementation backend. These models accept GeoTIFF imagery as input and return segmentation predictions. 

Table 9.1. Prithvi geospatial models for use with TerraTorch 

Model Use case Hugging Face model card Validated on 

Prithvi-EO-2.0-300M-TL-Sen1Floods11 

Flood detection and mapping 

Prithvi-EO-2.0-300M-TL-Sen1Floods11 

RHAIIS 3.3 

Prithvi-EO-2.0-300M-BurnScars 

Burn scar detection Prithvi-EO-2.0-300M-BurnScars 

RHAIIS 3.3 

Explore the IBM and NASA geospatial models collection on Hugging Face. 

IMPORTANT 

Prithvi geospatial models are validated for use with NVIDIA CUDA AI accelerators only. 

These models require specific vLLM server arguments to function correctly. You must **include --skip-tokenizer-init, --enforce-eager, and --enable-mm-embeds when starting **the inference server. 

For more information, see Serving TerraTorch Models with vLLM. 