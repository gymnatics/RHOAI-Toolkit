# Red_Hat_AI-3-Supported_product_and_hardware_configurations-en-US.pdf

- Red Hat AI 3

# Supported product and hardware configurations

Supported hardware and software configurations for deploying Red Hat AI software 

Last Updated: 2026-08-25

### Red Hat AI 3 Supported product and hardware configurations

Supported hardware and software configurations for deploying Red Hat AI software

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

Learn about supported hardware and software configurations for Red Hat AI.

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

CHAPTER 1. ABOUT RED HAT AI INFERENCE SUPPORTED HARDWARE AND SOFTWARE 

CHAPTER 2 PRODUCT AND VERSION COMPATIBILITY 

CHAPTER 3 SUPPORTED AI ACCELERATORS FOR RED HAT AI INFERENCE 

CHAPTER 4 SUPPORTED AI ACCELERATOR MODEL QUANTIZATION FORMATS 

CHAPTER 5 SUPPORTED AI ACCELERATORS FOR RHEL AI 

CHAPTER 6 SUPPORTED AI ACCELERATORS FOR RED HAT OPENSHIFT AI 

CHAPTER 7 SUPPORTED PLATFORMS FOR DISTRIBUTED INFERENCE WITH LLM-D 

CHAPTER 8 SUPPORTED AI ACCELERATORS FOR DISTRIBUTED INFERENCE WITH LLM-D 

CHAPTER 9 SUPPORTED DEPLOYMENT ENVIRONMENTS 

CHAPTER 10 OPENSHIFT CONTAINER PLATFORM SOFTWARE PREREQUISITES FOR GPU DEPLOYMENTS 

10.1. CLUSTER DEPLOYMENT PREREQUISITES 10.2. BARE METAL DEPLOYMENT PREREQUISITES 10.3. BUNDLED CONTAINER RUNTIME VERSIONS 10.4. OPENSHIFT CONTAINER PLATFORM OPERATOR PREREQUISITES 

CHAPTER 11 LIFECYCLE AND UPDATE POLICY 

3 

4 

5 

7 

14 

17 

19 

20 

21 

23 

25 25 26 28 29 

30 

### PREFACE

Red Hat AI software runs on a variety of supported hardware, software, and delivery platforms in production environments. 

### CHAPTER 1. ABOUT RED HAT AI INFERENCE SUPPORTED HARDWARE AND SOFTWARE

Supported configurations for Red Hat AI span multiple AI accelerator types including NVIDIA GPUs, AMD GPUs, Intel Xeon and AMD EPYC server CPUs, Google TPUs, and IBM Spyre accelerators. Red Hat AI Inference can be deployed in OpenShift Container Platform clusters, on standalone Red Hat Enterprise Linux (RHEL) hosts with Podman, or integrated with Red Hat OpenShift AI for managed AI/ML workflows. 

IMPORTANT 

Red Hat AI Inference is available only as a container image. You can download Red Hat AI **Inference container images from registry.redhat.io or browse available images in the **Red Hat Ecosystem Catalog . To find Red Hat AI Inference container images in the catalog, search for "AI Inference". 

The host operating system and kernel must support the required accelerator drivers. For more information, see Supported AI accelerators . 

IMPORTANT 

Technology Preview and Developer Preview features are provided for early access to potential new features. 

Technology Preview or Developer Preview features are not supported or recommended for production workloads. 

Additional resources 

Red Hat AI documentation 

Red Hat Enterprise Linux AI documentation 

Red Hat OpenShift AI documentation 

Red Hat AI on Hugging Face 

### CHAPTER 2. PRODUCT AND VERSION COMPATIBILITY

The following table lists the supported product versions for Red Hat AI Inference, Red Hat Enterprise Linux AI, and Red Hat OpenShift AI. 

Table 2.1. AI Inference product and version compatibility 

Product version vLLM core version LLM Compressor version 

3.5.0 v0.24.0 v0.12.0 

3.3 v0.13.0 v0.9.0.1 

3.2.5 v0.11.2 v0.8.1 

3.2.4 v0.11.0 v0.8.1 

3.2.3 v0.11.0 v0.8.1 

3.2.2 v0.10.1.1 v0.7.1 

3.2.1 v0.10.0 Not included in this release 

3.2.0 v0.9.2 Not included in this release 

Table 2.2. Red Hat OpenShift AI product and version compatibility 

Product version vLLM core version LLM Compressor version 

3.4 v0.18.0 v0.10.0.1 

3.3 v0.13.0 v0.9.0.1 

3.2 v0.11.2 v0.8.1 

3.0 v0.11.0 v0.8.1 

Table 2.3. Red Hat Enterprise Linux AI product and version compatibility 

Product version vLLM core version LLM Compressor version 

3.4 v0.18.0 v0.10.0.1 

3.3 v0.13.0 v0.9.0.1 

3.2 v0.11.2 v0.8.1 

3.0 v0.11.0 v0.8.1 

Product version vLLM core version LLM Compressor version 

### CHAPTER 3. SUPPORTED AI ACCELERATORS FOR RED HAT AI INFERENCE

The following tables list the supported AI accelerators for Red Hat AI Inference 3.5 with hardware specifications. Red Hat AI Inference supports data center, workstation, and edge AI accelerators. Verify that your accelerator model appears in the following tables. For software prerequisites including SDK versions, Python versions, and GPU operators, see OpenShift Container Platform software prerequisites for GPU deployments. 

The LLM Compressor support column indicates whether you can use the Red Hat AI Model Optimization Toolkit to optimize models for the accelerator. "Not supported" means offline quantization via LLM Compressor is unavailable. However, pre-quantized models or runtime quantization may still be supported as described in the quantization scheme details in each accelerator table. 

Table 3.1. Supported NVIDIA AI accelerators for registry.redhat.io/rhaiis/vllm-cuda-rhel9:3.5.0 

vLLM release 

AI accelerators Requirements vLLM architectur e support 

LLM Compresso r support 

vLLM v0.24.0 

NVIDIA data center GPUs: 

Turing: T4 

Ampere: A2, A10, A16, A30, A40, A100 

Ada Lovelace: L4, L20, L40, L40S 

Hopper: H100, H200, H20, GH200 

Blackwell: GB200, GB300, B200, B300, RTX PRO 6000 Blackwell Server Edition, RTX PRO 4500 Blackwell Server Edition 

CUDA Toolkit 13.0 

NVIDIA Container Toolkit 1.14 

NVIDIA GPU Operator 24.3 

Python 3.12 

PyTorch 2.9.1 

x8 6 

AA rch 64 

Supported, now packaged separately in the **model-opt-cuda-rhel9 **container image. 

IMPORTANT 

Red Hat AI Inference 3.5.0 is built with CUDA 13.0. The container images are compatible with earlier CUDA 12.9 drivers. 

If your host driver version is older than the CUDA toolkit version shipped in the AI Inference container, you can use NVIDIA Forward Compatibility  to avoid driver upgrades. 

NOTE 

NVIDIA T4 and A100 accelerators do not support FP8 (W8A8) quantization. 

Table 3.2. Supported NVIDIA DGX Spark AI accelerators for registry.redhat.io/rhaiis/vllm-cuda-rhel9:3.5.0 

vLLM release 

AI accelerators Hardware specifications vLLM architectur e support 

LLM Compresso r support 

vLLM v0.24.0 

NVIDIA DGX Spark (GB10 Grace Blackwell Superchip): 

NVIDIA DGX Spark 

ASUS Ascent GX10 

Dell Pro Max GB10 

GIGABYTE AI TOP ATOM 

HP ZGX Nano 

Lenovo ThinkStation PGX 

MSI EdgeXpert 

Compute Capability 12.1 

128 GB unified LPDDR5x CPU+GPU memory 

273 GB/s memory bandwidth 

Single GPU, 48 streaming multiprocessors 

ARM aarch64 architecture 

Edge and workstation form factor 

AA rch 64 

Not supported 

NOTE 

OEM systems based on the GB10 Grace Blackwell Superchip use the same GPU architecture and are compatible with the DGX Spark deployment procedure. DGX Spark **uses the vllm-cuda-rhel9 container image. Because the GPU and CPU share 128 GB of unified memory, you must adjust --gpu-memory-utilization below the default of 0.9 to **avoid out-of-memory conditions. For recommended settings, see Tuning vLLM for NVIDIA DGX Spark. 

Table 3.3. Supported AMD AI accelerators for registry.redhat.io/rhaiis/vllm-rocm-rhel9:3.5.0 

vLLM release 

AI accelerators Requirements vLLM architectur e support 

LLM Compresso r support 

vLLM v0.24.0 AMD Instinct MI210 

AMD Instinct MI300X 

AMD Instinct MI325X 

AMD Instinct MI350P 

AMD Instinct MI350X 

AMD Instinct MI355X 

ROCm 7.14 (MI350P) 

ROCm 7.1 (MI350X, MI355X) 

ROCm 6.3.4 (MI210, MI300X, MI325X) 

AMD GPU Operator 6.2 

Python 3.12 

PyTorch 2.10 

x86 Not supported 

vLLM release 

AI accelerators Requirements vLLM architectur e support 

LLM Compresso r support 

NOTE 

AMD GPUs support FP8 (W8A8) and GGUF quantization schemes only. 

Table 3.4. Supported Intel Gaudi AI accelerators for registry.redhat.io/rhaiis/vllm-gaudi-rhel9:3.5.0 (Technology Preview) 

vLLM release 

AI accelerators Requirements vLLM architectur e support 

LLM Compresso r support 

vLLM v0.24.0 

Intel Gaudi 3 Gaudi Software Suite 1.23.0 

vllm-gaudi plugin 0.16.0 

Python 3.12.9 

x86 Technology Preview 

Not supported 

IMPORTANT 

Intel Gaudi 3 accelerator support is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Table 3.5. Supported Google TPU AI accelerators for registry.redhat.io/rhaiis/vllm-tpu-rhel9:3.5.0 (Technology Preview) 

vLLM release 

AI accelerators Requirements vLLM architectur e support 

LLM Compresso r support 

vLLM v0.24.0 

Google v4, v5e, v5p, v6e (Trillium) Python 3.12 

x86 Technology Preview 

Not supported 

**Table 3.6. Supported IBM Spyre AI accelerators on registry.redhat.io/rhaiis/vllm‑spyre-rhel9:3.5.0 **

vLLM release 

AI accelerators Requirements vLLM architecture support 

LLM Compress or support 

vLLM v0.24.0 

IBM Spyre for Power (ppc64le) Python 3.12.9 

PyTorch 2.7.1 

vllm-tgis-adapter 0.9.2 

vllm-spyre 1.6.1 

IBM Spyre Enablement Stack 1.1.1 

IBM Power (ppc64le) Not supported 

vLLM v0.24.0 

IBM Spyre for Z (s390x) Python 3.12 

PyTorch 2.7.1 

vllm-tgis-adapter 0.9.2 

vllm-spyre 1.2.0 

IBM Spyre Enablement Stack 1.1.1 

IBM Z (s390x) Not supported 

vLLM v0.24.0 

IBM Spyre Accelerator (x86) x86_64 server 

with PCIe Gen4 or newer 

Minimum 32 GB system memory recommended 

IBM Spyre Accelerator card installed 

x86 Technology Preview 

Not supported 

vLLM release 

AI accelerators Requirements vLLM architecture support 

LLM Compress or support 

IMPORTANT 

IBM Spyre Accelerator support for x86 is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Table 3.7. Supported AWS Neuron AI accelerators for registry.redhat.io/rhaiis/vllm-neuron-rhel9:3.5.0 

vLLM release 

AI accelerators Requirements vLLM architectur e support 

LLM Compresso r support 

vLLM v0.24.0 

AWS Inferentia2 (Inf2), AWS Trainium (Trn1, Trn1n, Trn2) AWS Neuron SDK 

2.x 

Python 3.12 

vllm-neuron plugin 

x86 Dev Preview 

Not supported 

IMPORTANT 

AWS Trainium and Inferentia support is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Table 3.8. Supported Intel Gaudi 3 AI accelerators for registry.redhat.io/rhaiis/vllm-gaudi-rhel9:3.5.0 (Technology Preview) 

vLLM release 

AI accelerators Requirements vLLM architectur e support 

LLM Compresso r support 

vLLM v0.24.0 

Intel Gaudi 3 Intel Gaudi Software (SynapseAI) 

Python 3.12 

vllm-gaudi plugin 

x86 Technology Preview 

Not supported 

IMPORTANT 

Intel Gaudi 3 support is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Table 3.9. Supported x86_64 CPU configurations for registry.redhat.io/rhaiis/vllm-cpu-rhel9:3.5.0 

vLLM release 

Supported processors Requirements vLLM architectur e support 

LLM Compresso r support 

vLLM v0.24.0 

Intel Xeon and AMD EPYC server processors with: 

AVX2 (minimum): Intel Haswell or newer, AMD Excavator or newer 

AVX512: Intel Skylake-X or newer, AMD Zen 4 or newer 

AVX512 Advanced Matrix Extensions (AMX): Intel Sapphire Rapids or newer 

Python 3.12 

Minimum 16 GB system RAM (32 GB recommended) 

x86 Not supported 

vLLM release 

Supported processors Requirements vLLM architectur e support 

LLM Compresso r support 

NOTE 

The CPU container image supports AVX2, AVX512, and AVX512 AMX instruction sets in a single build. The container automatically detects and uses the best available instruction set for your processor. CPU inference is best suited for smaller models, typically under 3 billion parameters. 

### CHAPTER 4. SUPPORTED AI ACCELERATOR MODEL QUANTIZATION FORMATS

Different AI accelerator architectures support different types of model quantization, depending on the compute capabilities of the hardware. The following tables list the AI accelerators that support INT8, INT4, FP8, and NVFP4 quantization formats. 

INT8 (W8A8) quantization reduces model weights and activations to 8-bit integers, providing significant memory savings while maintaining acceptable accuracy for many use cases. 

INT8 (W4A8) quantization reduces model weights to 4-bit integers, keeping activations at 8-bit precision. INT8 (W4A8) improves memory efficiency compared to W8A8 while preserving higher activation fidelity for inference. 

INT4 (W4A16) quantization reduces model weights to 4-bit integers while maintaining 16-bit activations, enabling larger models to fit in GPU memory with minimal accuracy loss. 

FP8 (W8A8) quantization uses 8-bit floating point representation for weights and activations, offering a balance between memory efficiency and numerical precision for training and inference workloads. 

NVFP4 quantization uses NVIDIA’s 4-bit floating point format with two-level scaling (FP8 finegrained scales and FP32 tensor-level scale), providing maximum memory efficiency for inference on NVIDIA Blackwell hardware. 

Table 4.1. Supported NVIDIA AI accelerators for INT8 (W8A8) quantization 

Architecture Supported AI accelerators Minimum compute capability 

Turing Tesla T4 7.5 

Ampere A10, A30, A40, A100 8.0 

Ada Lovelace L4, L40, L40S 8.9 

Hopper H100, H200, GH200 9.0 

NOTE 

NVIDIA Blackwell architecture (B200, B300, GB200, GB300) does not support INT8 quantization in vLLM due to kernel limitations. Use FP8 or NVFP4 quantization instead. 

Table 4.2. Supported AMD AI accelerators for INT8 (W8A8) quantization 

Architecture Supported AI accelerators 

CDNA 2 MI210 

CDNA 3 MI300X, MI325X 

CDNA 4 MI350X, MI355X 

Architecture Supported AI accelerators 

Table 4.3. Supported NVIDIA AI accelerators for INT4 (W4A16) quantization 

Architecture Supported AI accelerators Minimum compute capability 

Ampere A10, A30, A40, A100 8.0 

Ada Lovelace L4, L40, L40S 8.9 

Hopper H100, H200, GH200 9.0 

Blackwell B200, B300, GB200, GB300 10.0 

NOTE 

NVIDIA Turing architecture (Tesla T4) does not have optimized vLLM kernel support for INT4 quantization. Use Ampere or newer architectures for INT4 inference. 

Table 4.4. Supported AMD AI accelerators for INT4 (W4A16) quantization 

Architecture Supported AI accelerators 

CDNA 3 MI300X, MI325X 

CDNA 4 MI350X, MI355X 

NOTE 

AMD CDNA 2 architecture (MI210) does not have optimized vLLM kernel support for INT4 quantization. 

Table 4.5. Supported NVIDIA AI accelerators for FP8 (W8A8) quantization 

Architecture Supported AI accelerators Minimum compute capability 

Ada Lovelace L4, L40, L40S 8.9 

Hopper H100, H200, GH200 9.0 

Blackwell B200, B300, GB200, GB300 10.0 

NOTE 

NVIDIA Turing architecture (Tesla T4) and Ampere architecture (A10, A30, A40, A100) AI accelerators do not support FP8 W8A8 quantization due to hardware limitations. However, FP8 weight-only (W8A16) quantization is available on these architectures by using Marlin kernels. 

Table 4.6. Supported AMD AI accelerators for FP8 (W8A8) quantization 

Architecture Supported AI accelerators 

CDNA 3 MI300X, MI325X 

CDNA 4 MI350X, MI355X 

NOTE 

AMD CDNA 2 architecture AI accelerators (MI210) do not support FP8 quantization due to hardware limitations. 

Table 4.7. Supported NVIDIA AI accelerators for NVFP4 quantization 

Architecture Supported AI accelerators Minimum compute capability 

Blackwell B200, B300, GB200, GB300 10.0 

NOTE 

NVFP4 quantization is only available on NVIDIA Blackwell architecture AI accelerators. AMD AI accelerators do not support NVFP4 quantization. 

Additional resources 

NVIDIA CUDA GPU compute capability 

vLLM quantization 

### CHAPTER 5. SUPPORTED AI ACCELERATORS FOR RHEL AI

The following AI accelerators are supported for inference serving with Red Hat AI Inference on RHEL AI. 

IMPORTANT 

Bare metal deployments of RHEL AI are supported for all NVIDIA CUDA and AMD ROCm AI accelerators listed in Supported AI accelerators for Red Hat AI Inference . 

Actual requirements vary based on the specific models you deploy, quantization methods, context lengths, and concurrent request loads. Aggregate GPU memory refers to the total GPU memory available across all GPUs in the system that can be used for tensor parallelism or pipeline parallelism. 

For more information about inference serving on bare metal or Cloud platforms, see Red Hat Enterprise Linux AI. 

IMPORTANT 

The recommended minimum additional disk storage for all platforms is 1 TB. 

Table 5.1. Supported AI accelerators for Amazon Web Services (AWS) deployments 

NVIDIA AI accelerator Aggregate GPU memory AWS instance family 

GB200 384 GB P6e series 

B200 192 GB P6 series 

RTX PRO 6000 Blackwell Server Edition 

96 GB G7e series 

H100 80 GB P5 series 

L40S 48 GB G6e series 

A100 40 GB P4d series 

L4 24 GB G6 series 

Table 5.2. Supported AI accelerators for IBM Cloud deployments 

NVIDIA AI accelerator Aggregate GPU memory IBM Cloud instance family 

H200 141 GB gx3 series 

H100 80 GB gx3 series 

A100 80 GB gx3 series 

L40S 48 GB gx3 series 

L4 24 GB gx3 series 

NVIDIA AI accelerator Aggregate GPU memory IBM Cloud instance family 

Table 5.3. Supported AI accelerators for Microsoft Azure deployments 

AI accelerator Aggregate GPU memory Azure instance family 

NVIDIA GB200 384 GB ND series 

AMD Instinct MI300X 192 GB ND series 

NVIDIA H100 80 GB ND series 

NVIDIA A100 80 GB ND series 

AMD Instinct MI210 64 GB ND series 

Table 5.4. Supported AI accelerators for Google Cloud deployments 

NVIDIA AI accelerator Aggregate GPU memory Google Cloud instance family 

GB200 384 GB A4X series 

B200 192 GB A4 series 

4xL4 96 GB G2 series 

H100 80 GB A3 series 

A100 40 GB A2 series 

### CHAPTER 6. SUPPORTED AI ACCELERATORS FOR RED HAT OPENSHIFT AI

You must install the AI accelerator Operator that is relevant to the AI accelerator that you want to use with Red Hat OpenShift AI. 

OpenShift AI provides Operators that support integration with AI accelerators. OpenShift AI also provides images that include libraries that work with NVIDIA, AMD, and Intel Gaudi data center grade AI accelerators. 

Additional resources 

Enabling AI accelerators 

Supported configurations 

### CHAPTER 7. SUPPORTED PLATFORMS FOR DISTRIBUTED INFERENCE WITH LLM-D

Distributed Inference with llm-d is a Kubernetes-native framework for serving large language models at scale. The following table lists the supported platforms and requirements for deploying Distributed Inference with llm-d. 

Table 7.1. Distributed Inference with llm-d supported platforms and requirements 

Platform Supported versions Requirements 

OpenShift Container Platform 

4.19+ Red Hat AI Operator 

Red Hat AI Helm chart 

KServe 

Istio service mesh 

cert-manager 

Gateway API 

Azure Kubernetes Service (AKS) 

Kubernetes 1.33+ Helm 3.17+ 

kubectl 1.33+ 

GPU-enabled node pool 

Red Hat AI Helm chart 

CoreWeave Kubernetes Service (CKS) 

Kubernetes 1.33+ Helm 3.17+ 

kubectl 1.33+ 

Red Hat AI Helm chart 

IMPORTANT 

Distributed Inference with llm-d is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

### CHAPTER 8. SUPPORTED AI ACCELERATORS FOR DISTRIBUTED INFERENCE WITH LLM-D

The following NVIDIA and AMD AI data center grade AI accelerators are supported for use with Distributed Inference with llm-d. 

IMPORTANT 

Distributed Inference with llm-d supports data center grade AI accelerators only. 

Table 8.1. Supported NVIDIA AI accelerators for Distributed Inference with llm-d 

Supported AI accelerators 

Use case Recommended networking 

Recommended storage 

H100, H200 

B200 

A100 

Intelligent inference scheduling routes requests to the optimal GPU. 

Standard DC Ethernet (25/100 GbE) 

Local SSD (NVMe Recommended) 

H100, H200 

B200 

Prefill/Decode disaggregation separates prefill and decode compute stages. 

High-Speed Ethernet (100 GbE) 

Local SSD (NVMe Recommended) 

H100, H200 

B200 

A100 

KV cache management increases throughput by offloading KV cache to CPU RAM. 

Standard DC Ethernet (25/100 GbE) 

High-speed NVMe SSDs 

H100, H200 

B200 

Wide expert parallelism (WEP) distributes MoE models across many GPUs. 

HPC Fabric with RDMA: InfiniBand, RoCE 

High-speed NVMe SSDs 

Table 8.2. Supported AMD AI accelerators for Distributed Inference with llm-d 

Supported AI accelerators 

Use case Recommended networking 

Recommended storage 

MI300X Intelligent inference scheduling routes requests to the optimal GPU. 

Standard DC Ethernet (25/100 GbE) 

Local NVMe SSD 

MI300X KV cache management increases throughput by offloading KV cache to CPU RAM. 

PCIe 5+ Not applicable 

Supported AI accelerators 

Use case Recommended networking 

Recommended storage 

Additional resources 

Enabling AI accelerators 

Supported configurations 

Distributed Inference with llm-d: release components versions 

### CHAPTER 9. SUPPORTED DEPLOYMENT ENVIRONMENTS

The following deployment environments for Red Hat AI Inference are supported. 

IMPORTANT 

Red Hat AI Inference is available only as a container image. You can download Red Hat AI **Inference container images from registry.redhat.io or browse available images in the **Red Hat Ecosystem Catalog . To find Red Hat AI Inference container images in the catalog, search for "AI Inference". 

The host operating system and kernel must support the required accelerator drivers. For more information, see Supported AI accelerators . 

Table 9.1. Red Hat AI Inference supported deployment environments 

Environment Supported versions Deployment notes 

OpenShift Container Platform (self‑managed) 

4.14+ Deploy on bare‑metal hosts or virtual machines. 

Red Hat OpenShift Service on AWS (ROSA) 

4.14+ Requires a ROSA cluster with STS and GPU‑enabled P5 or G5 node types. See Prepare your environment for more information. 

Red Hat Enterprise Linux AI 

3.0+ Deploy on bare‑metal hosts or virtual machines. 

Red Hat Enterprise Linux (RHEL) 

9.2+ Deploy on bare‑metal hosts or virtual machines. 

Linux (not RHEL) 

- Supported under third‑party policy deployed on bare‑metal hosts or virtual machines. OpenShift Container Platform Operators are not required. 

Kubernetes (not OpenShift Container Platform) 

- Supported under third‑party policy deployed on bare‑metal hosts or virtual machines. 

IMPORTANT 

Single-host deployments for IBM Spyre AI accelerators on IBM Z and IBM Power are supported for RHEL AI 9.6+. 

Cluster deployments for IBM Spyre AI accelerators on IBM Z are supported as part of Red Hat OpenShift AI version 3.0+ only. 

Table 9.2. Distributed Inference with llm-d supported deployment environments (Technology Preview) 

Environment Supported versions Deployment notes 

OpenShift Container Platform 

4.19+ Deployed by using the Red Hat AI Helm chart. Requires the Red Hat AI Operator, KServe, Istio, certmanager, and Gateway API. 

Azure Kubernetes Service (AKS) 

Kubernetes 1.33+ Deployed by using the Red Hat AI Helm chart. Requires Helm 3.17+, kubectl 1.33+, and a GPU-enabled node pool. 

CoreWeave Kubernetes Service (CKS) 

Kubernetes 1.33+ Deployed by using the Red Hat AI Helm chart. Requires Helm 3.17+, kubectl 1.33+, and GPU instances (A100, H100, H200, or B200). 

IMPORTANT 

Distributed Inference with llm-d is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

### CHAPTER 10. OPENSHIFT CONTAINER PLATFORM SOFTWARE PREREQUISITES FOR GPU DEPLOYMENTS

The following table lists the minimum OpenShift Container Platform software prerequisites for AI accelerator workloads. 

10.1. CLUSTER DEPLOYMENT PREREQUISITES 

The following prerequisites apply to OpenShift Container Platform and Kubernetes cluster deployments. GPU Operators manage CUDA and ROCm driver installations automatically. 

Table 10.1. Cluster deployment platform prerequisites for AI accelerators 

Accelerator type Container image variant Platform prerequisites 

NVIDIA CUDA registry.redhat.io/rhaiis/vllm -cuda-rhel9:3.5.0 NVIDIA GPU Operator 24.3 

CUDA driver 12.0 or later (managed by GPU Operator) 

Node Feature Discovery Operator 4.14+ 

AMD ROCm (MI210, MI300X, MI325X) 

registry.redhat.io/rhaiis/vllm -rocm-rhel9:3.5.0 AMD GPU Operator 6.2 

ROCm 6.3.4 drivers (managed by GPU Operator) 

AMD ROCm (MI350P) registry.redhat.io/rhaiis/vllm -rocm-rhel9:3.5.0 AMD GPU Operator 6.2 

ROCm 7.14 drivers (managed by GPU Operator) 

AMD ROCm (MI350X, MI355X) 

registry.redhat.io/rhaiis/vllm -rocm-rhel9:3.5.0 AMD GPU Operator 6.2 

ROCm 7.1 drivers (managed by GPU Operator) 

Intel Gaudi 3 registry.redhat.io/rhaiis/vllm -gaudi-rhel9:3.5.0 Gaudi Software Suite 1.23.0 

vllm-gaudi plugin 0.16.0 [1] 

Google TPU (v4, v5e, v5p, v6e) 

registry.redhat.io/rhaiis/vllm -tpu-rhel9:3.5.0 

Cloud TPU SDK 

IBM Spyre for Power (ppc64le) 

registry.redhat.io/rhaiis/vllm -spyre-rhel9:3.5.0 IBM Spyre Operator 1.0 

IBM Spyre Enablement Stack 1.1.1 

vllm-tgis-adapter 0.9.2 

vllm-spyre 1.6.1 

IBM Spyre for Z (s390x) registry.redhat.io/rhaiis/vllm -spyre-rhel9:3.5.0 IBM Spyre Operator 1.0 

IBM Spyre Enablement Stack 1.1.1 

vllm-tgis-adapter 0.9.2 

vllm-spyre 1.2.0 

IBM Spyre Accelerator (x86) registry.redhat.io/rhaiis/vllm -spyre-rhel9:3.5.0 IBM Spyre Operator 1.0 

IBM Spyre Enablement Stack 1.1.1 

vllm-tgis-adapter 0.9.2 

vllm-spyre 1.0.2 

AWS Neuron (Inferentia2, Trainium) 

registry.redhat.io/rhaiis/vllm -neuron-rhel9:3.5.0 AWS Neuron SDK 2.x 

vllm-neuron plugin 

x86_64 CPU registry.redhat.io/rhaiis/vllm -cpu-rhel9:3.5.0 

Minimum 16 GB system RAM (32 GB recommended) 

Accelerator type Container image variant Platform prerequisites 

[1] vllm-gaudi uses independent versioning; version 0.16.0 is verified compatible with vLLM v0.24.0. 

IMPORTANT 

Red Hat AI Inference 3.5.0 is built with CUDA 13.0. The container images are compatible with earlier CUDA 12.9 drivers. 

If your host driver version is older than the CUDA toolkit version shipped in the AI Inference container, you can use NVIDIA Forward Compatibility  to avoid driver upgrades. 

NOTE 

AMD ROCm version requirements vary by GPU model. MI350P requires ROCm 7.14. MI350X and MI355X require ROCm 7.1. MI210, MI300X, and MI325X use ROCm 6.3.4. 

10.2. BARE METAL DEPLOYMENT PREREQUISITES 

The following prerequisites apply to single-host deployments on Red Hat Enterprise Linux (RHEL) and Red Hat Enterprise Linux AI. You must install CUDA Toolkit and NVIDIA Container Toolkit directly on the host. 

Table 10.2. Bare metal deployment platform prerequisites for AI accelerators 

Accelerator type Container image variant Platform prerequisites 

NVIDIA CUDA registry.redhat.io/rhaiis/vllm -cuda-rhel9:3.5.0 CUDA Toolkit 13.0 (installed directly 

on host) 

NVIDIA Container Toolkit 1.14 (installed directly on host) 

CUDA driver 12.0 or later (installed directly on host) 

NVIDIA DGX Spark (GB10) registry.redhat.io/rhaiis/vllm -cuda-rhel9:3.5.0 NVIDIA driver 580.65.06 or later 

with open source GPU kernel modules (DGX OS ships driver 580.95.05) 

CUDA 13.0 

NVIDIA Container Toolkit 1.14 

ARM aarch64 architecture 

Host OS: Red Hat Enterprise Linux (RHEL) or DGX OS based on Ubuntu 24.04 

AMD ROCm (MI210, MI300X, MI325X) 

registry.redhat.io/rhaiis/vllm -rocm-rhel9:3.5.0 ROCm 6.3.4 drivers (installed 

directly on host) 

Podman or Docker configured for GPU device passthrough 

AMD ROCm (MI350P) registry.redhat.io/rhaiis/vllm -rocm-rhel9:3.5.0 ROCm 7.14 drivers (installed directly 

on host) 

Podman or Docker configured for GPU device passthrough 

AMD ROCm (MI350X, MI355X) 

registry.redhat.io/rhaiis/vllm -rocm-rhel9:3.5.0 ROCm 7.1 drivers (installed directly 

on host) 

Podman or Docker configured for GPU device passthrough 

Intel Gaudi 3 registry.redhat.io/rhaiis/vllm -gaudi-rhel9:3.5.0 Gaudi Software Suite 1.23.0 

vllm-gaudi plugin 0.16.0 [1] 

IBM Spyre for Power (ppc64le) 

registry.redhat.io/rhaiis/vllm -spyre-rhel9:3.5.0 IBM Spyre Enablement Stack 1.1.1 

(installed directly on host) 

vllm-tgis-adapter 0.9.2 

vllm-spyre 1.6.1 

IBM Spyre for Z (s390x) registry.redhat.io/rhaiis/vllm -spyre-rhel9:3.5.0 IBM Spyre Enablement Stack 1.1.1 

(installed directly on host) 

vllm-tgis-adapter 0.9.2 

vllm-spyre 1.2.0 

IBM Spyre Accelerator (x86) registry.redhat.io/rhaiis/vllm -spyre-rhel9:3.5.0 IBM Spyre Enablement Stack 1.1.1 

(installed directly on host) 

vllm-tgis-adapter 0.9.2 

vllm-spyre 1.0.2 

x86_64 CPU registry.redhat.io/rhaiis/vllm -cpu-rhel9:3.5.0 

Minimum 16 GB system RAM (32 GB recommended) 

Accelerator type Container image variant Platform prerequisites 

[1] vllm-gaudi uses independent versioning; version 0.16.0 is verified compatible with vLLM v0.24.0. 

IMPORTANT 

For bare metal deployments, you are responsible for installing and maintaining CUDA Toolkit and NVIDIA Container Toolkit on the host system. 

For cluster deployments using GPU Operators, the operator manages driver installation and updates automatically. For more information, see Cluster deployment prerequisites . 

10.3. BUNDLED CONTAINER RUNTIME VERSIONS 

The following Python and PyTorch versions ship in the Red Hat AI Inference container images. You do not need to install them separately. 

Table 10.3. Bundled Python and PyTorch versions by accelerator 

Accelerator type Python PyTorch 

NVIDIA CUDA 3.12 2.11.0 

AMD ROCm 3.12 2.11.0 

Intel Gaudi 3 3.12 2.11.0 

Google TPU 3.12 2.10.0 

IBM Spyre for Power (ppc64le) 3.12 2.11.0 

IBM Spyre for Z (s390x) 3.12 2.11.0 

IBM Spyre Accelerator (x86) 3.12 2.11.0 

AWS Neuron 3.12 2.9.1 

10.4. OPENSHIFT CONTAINER PLATFORM OPERATOR PREREQUISITES 

Table 10.4. OpenShift Container Platform operator prerequisites for AI accelerator workloads 

Component Minimum version Operator 

NVIDIA GPU Operator 24.3 NVIDIA GPU Operator OLM Operator 

AMD GPU Operator 6.2 AMD GPU Operator OLM Operator 

IBM Spyre Operator 1.0 IBM Spyre Operator 

Node Feature Discovery [1] 

4.14 Node Feature Discovery Operator 

[1] Included by default with OpenShift Container Platform. Node Feature Discovery is required for scheduling NUMA-aware workloads . 

### CHAPTER 11. LIFECYCLE AND UPDATE POLICY

Security and critical bug fixes are delivered as container images available from the **registry.access.redhat.com/rhaii container registry and are announced through RHSA advisories. See **RHAII container images on catalog.redhat.com for more details. 