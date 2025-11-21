# Modular Script Library

This directory contains the modular components for the OpenShift + RHOAI installation scripts.

## Directory Structure

```
lib/
├── functions/          # Reusable function libraries
│   ├── operators.sh    # Operator installation functions (NFD, GPU, RHCL)
│   ├── rhoai.sh        # RHOAI installation and configuration functions
│   └── maas.sh         # MaaS setup functions
├── manifests/          # Kubernetes/OpenShift YAML manifests
│   ├── operators/      # Operator subscriptions and configurations
│   │   ├── nfd-operator.yaml
│   │   ├── nfd-instance.yaml
│   │   ├── gpu-operator.yaml
│   │   ├── gpu-clusterpolicy.yaml
│   │   └── ...
│   ├── rhoai/          # RHOAI manifests
│   │   ├── rhoai-operator.yaml
│   │   ├── dscinitalization.yaml
│   │   ├── datasciencecluster.yaml
│   │   └── ...
│   ├── rhcl/           # RHCL/Kuadrant manifests
│   │   ├── rhcl-operator.yaml
│   │   ├── kuadrant-instance.yaml
│   │   ├── authorino-tls.yaml
│   │   └── ...
│   └── maas/           # MaaS manifests
│       ├── gatewayclass.yaml
│       └── ...
└── utils/              # Utility functions
    ├── colors.sh       # Color definitions and print functions
    └── common.sh       # Common utility functions

## Benefits

### 1. Easier Debugging
- Each component is isolated in its own file
- YAML manifests are separate from logic
- Easy to identify and fix issues

### 2. Better Maintainability
- Changes to manifests don't require editing large scripts
- Functions can be reused across different scripts
- Clear separation of concerns

### 3. Version Control
- Easier to track changes to specific components
- Better diff visibility in Git
- Can update manifests independently

### 4. Testing
- Individual functions can be tested in isolation
- Manifests can be validated separately
- Easier to create test scenarios

## Usage

### In Your Scripts

```bash
#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required libraries
source "$SCRIPT_DIR/lib/utils/colors.sh"
source "$SCRIPT_DIR/lib/utils/common.sh"
source "$SCRIPT_DIR/lib/functions/operators.sh"
source "$SCRIPT_DIR/lib/functions/rhoai.sh"

# Use the functions
install_nfd_operator
install_gpu_operator
install_rhcl_operator
install_rhoai_operator
```

### Applying Manifests

```bash
# Apply a manifest directly
oc apply -f lib/manifests/operators/nfd-operator.yaml

# Or use the helper function
apply_manifest "$SCRIPT_DIR/lib/manifests/operators/nfd-operator.yaml" "NFD Operator"
```

## Manifest Templates

Some manifests may contain placeholders that need to be substituted:

- `{{RHOAI_VERSION}}` - RHOAI version
- `{{RHOAI_CHANNEL}}` - OLM channel for RHOAI
- `{{CLUSTER_ID}}` - OpenShift cluster ID

Use `envsubst` or `sed` to replace these before applying.

## Adding New Components

1. Create the manifest file in the appropriate directory
2. Add a function in the corresponding function library
3. Update this README with the new component
4. Test the component in isolation before integrating

## Conventions

- All functions should use the print_* functions for output
- All functions should check if resources already exist (idempotent)
- All manifests should be valid YAML that can be applied directly
- Use descriptive names for files and functions

