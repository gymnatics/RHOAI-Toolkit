# Library Directory

This directory contains modular functions, manifests, and utilities used by the installation scripts.

## Structure

```
lib/
├── functions/          # Reusable function modules
│   ├── model-deployment.sh  # Model deployment functions
│   ├── operators.sh         # Operator installation
│   └── rhoai.sh             # RHOAI-specific functions
│
├── manifests/          # YAML manifest files
│   ├── operators/      # NFD, GPU operator manifests
│   ├── rhcl/           # RHCL/Kuadrant manifests
│   └── rhoai/          # RHOAI manifests
│
└── utils/              # Utility libraries
    ├── aws-checks.sh   # AWS validation functions
    ├── colors.sh       # Color definitions and print functions
    ├── common.sh       # Common helper functions
    ├── config-manager.sh  # Configuration management
    └── os-compat.sh    # OS compatibility layer (macOS/Linux)
```

---

## Functions

### operators.sh
Operator installation functions:
- `install_nfd_operator()` - Node Feature Discovery
- `install_gpu_operator()` - NVIDIA GPU Operator
- `install_rhcl_operator()` - Red Hat Connectivity Link (Kuadrant)
- `install_lws_operator()` - Leader Worker Set
- `install_kueue_operator()` - Kueue

### rhoai.sh
RHOAI-specific functions:
- `get_rhoai_channel(version)` - Get OLM channel for RHOAI version
- `install_rhoai_operator(version)` - Install RHOAI operator
- `initialize_rhoai()` - Create DSCInitialization
- `create_datasciencecluster_v1()` - Create DSC for RHOAI 2.x
- `create_datasciencecluster_v2()` - Create DSC for RHOAI 3.x
- `configure_rhoai_dashboard()` - Enable dashboard features
- `create_gpu_hardware_profile()` - Create GPU hardware profile
- `enable_user_workload_monitoring()` - Enable monitoring

### model-deployment.sh
Model deployment functions:
- Model deployment with vLLM/llm-d
- Resource calculation
- InferenceService creation

---

## Utilities

### colors.sh
Print functions with colors:
- `print_header(message)` - Section header
- `print_step(message)` - Step message
- `print_success(message)` - Success message
- `print_error(message)` - Error message
- `print_warning(message)` - Warning message
- `print_info(message)` - Info message

### common.sh
Common helper functions:
- `apply_manifest(file, description)` - Apply YAML manifest
- `wait_for_resource(type, name, namespace, timeout)` - Wait for resource
- `check_operator_installed(name, namespace)` - Check operator exists
- `wait_for_operator_ready(name, namespace, timeout)` - Wait for operator
- `ensure_namespace(name)` - Create namespace if not exists

### os-compat.sh
Cross-platform compatibility (macOS/Linux):
- `grep_perl()`, `grep_extract()` - Portable grep
- `base64_encode()`, `base64_decode()` - Portable base64
- `sed_inplace()` - Portable sed -i
- `calc_half()`, `parse_memory_gi()`, `parse_cpu()` - Resource calculations

### config-manager.sh
Configuration persistence:
- `save_configuration()` - Save settings
- `load_configuration()` - Load settings
- `clear_saved_configuration()` - Clear saved config

---

## Manifests

### operators/
Operator subscription and configuration manifests.

### rhcl/
RHCL/Kuadrant manifests for MaaS authentication.

### rhoai/
RHOAI DataScienceCluster and related manifests.

**Note**: GPU MachineSet YAMLs are generated dynamically by `scripts/create-gpu-machineset.sh` and contain cluster-specific data.

---

## Usage

```bash
#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required libraries
source "$SCRIPT_DIR/lib/utils/colors.sh"
source "$SCRIPT_DIR/lib/utils/common.sh"
source "$SCRIPT_DIR/lib/utils/os-compat.sh"
source "$SCRIPT_DIR/lib/functions/operators.sh"
source "$SCRIPT_DIR/lib/functions/rhoai.sh"

# Use functions
print_header "Installing NFD"
install_nfd_operator

print_header "Installing RHOAI"
install_rhoai_operator "3.0"
```

---

## See Also

- [Main README](../README.md)
- [Scripts README](../scripts/README.md)
- [Documentation](../docs/README.md)
- [OS Compatibility Reference](../docs/reference/OS-COMPATIBILITY.md)
