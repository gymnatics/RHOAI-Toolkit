# Library Directory

This directory contains modular functions and manifests used by the installation scripts.

## 📂 Structure

```
lib/
├── functions/          # Reusable function modules
│   ├── operators.sh    # Operator installation (NFD, GPU, RHCL, LWS, Kueue)
│   └── rhoai.sh        # RHOAI-specific functions
├── manifests/          # YAML manifest files
│   ├── operators/      # NFD, GPU operator manifests
│   ├── rhcl/           # RHCL/Kuadrant manifests
│   └── rhoai/          # RHOAI manifests (future)
└── utils/              # Utility functions
    ├── colors.sh       # Color definitions and print functions
    └── common.sh       # Common helper functions
```

## 🔧 Functions

### operators.sh
Provides functions for installing operators:
- `install_nfd_operator()` - Node Feature Discovery
- `install_gpu_operator()` - NVIDIA GPU Operator
- `install_rhcl_operator()` - Red Hat Connectivity Link (Kuadrant)
- `install_lws_operator()` - Leader Worker Set
- `install_kueue_operator()` - Kueue

### rhoai.sh
Provides RHOAI-specific functions:
- `get_rhoai_channel(version)` - Get OLM channel for RHOAI version
- `install_rhoai_operator(version)` - Install RHOAI operator
- `initialize_rhoai()` - Create DSCInitialization
- `create_datasciencecluster_v1()` - Create DSC for RHOAI 2.x
- `create_datasciencecluster_v2()` - Create DSC for RHOAI 3.x with GenAI/MaaS
- `configure_rhoai_dashboard()` - Enable GenAI Studio and Dashboard features
- `create_gpu_hardware_profile()` - Create GPU hardware profile
- `enable_user_workload_monitoring()` - Enable monitoring

### utils/colors.sh
Provides color definitions and print functions:
- `print_header(message)` - Print section header
- `print_step(message)` - Print step message
- `print_success(message)` - Print success message
- `print_error(message)` - Print error message
- `print_warning(message)` - Print warning message
- `print_info(message)` - Print info message

### utils/common.sh
Provides common utility functions:
- `get_script_dir()` - Get script directory
- `apply_manifest(file, description)` - Apply YAML manifest
- `wait_for_resource(type, name, namespace, timeout)` - Wait for resource
- `check_operator_installed(name, namespace)` - Check if operator exists
- `wait_for_operator_ready(name, namespace, timeout)` - Wait for operator
- `ensure_namespace(name)` - Create namespace if not exists

## 📝 Usage

To use these functions in your script:

```bash
#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required libraries
source "$SCRIPT_DIR/lib/utils/colors.sh"
source "$SCRIPT_DIR/lib/utils/common.sh"
source "$SCRIPT_DIR/lib/functions/operators.sh"
source "$SCRIPT_DIR/lib/functions/rhoai.sh"

# Now you can use the functions
print_header "Installing NFD"
install_nfd_operator

print_header "Installing RHOAI"
install_rhoai_operator "3.0"
```

## 🎯 Benefits

1. **Code Reusability**: Functions can be used across multiple scripts
2. **Maintainability**: Changes in one place affect all scripts
3. **Testability**: Functions can be tested independently
4. **Readability**: Main scripts are cleaner and easier to understand
5. **Consistency**: Same behavior across all scripts

## 🔄 Migration

Scripts are being gradually migrated to use these modular functions:
- ✅ `integrated-workflow-v2.sh` - Fully modular
- 🔄 `scripts/integrated-workflow.sh` - Original (still works)
- 🔄 `scripts/enable-genai-maas.sh` - To be updated
- 🔄 `scripts/setup-maas.sh` - To be updated

## 📚 See Also

- Main README: `../README.md`
- Scripts README: `../scripts/README.md`
- Documentation: `../docs/README.md`
