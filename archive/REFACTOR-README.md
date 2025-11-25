## 🎯 Modular Refactoring Branch

This branch contains a refactored version of the OpenShift + RHOAI installation scripts with improved modularity and maintainability.

## 📁 New Directory Structure

```
Openshift-installation/
├── lib/                                    # Modular library (NEW!)
│   ├── functions/                          # Reusable function libraries
│   │   ├── operators.sh                    # NFD, GPU, RHCL operators
│   │   ├── rhoai.sh                        # RHOAI installation (TODO)
│   │   └── maas.sh                         # MaaS setup (TODO)
│   ├── manifests/                          # Kubernetes YAML manifests
│   │   ├── operators/                      # Operator subscriptions
│   │   │   ├── nfd-operator.yaml
│   │   │   ├── nfd-instance.yaml
│   │   │   ├── gpu-operator.yaml
│   │   │   └── gpu-clusterpolicy.yaml
│   │   ├── rhoai/                          # RHOAI manifests (TODO)
│   │   ├── rhcl/                           # RHCL/Kuadrant manifests
│   │   │   ├── rhcl-operator.yaml
│   │   │   ├── kuadrant-instance.yaml
│   │   │   └── authorino-tls.yaml
│   │   └── maas/                           # MaaS manifests (TODO)
│   ├── utils/                              # Utility functions
│   │   ├── colors.sh                       # Color definitions
│   │   └── common.sh                       # Common utilities
│   └── README.md                           # Library documentation
├── integrated-workflow-v2.sh               # Refactored main script (NEW!)
├── integrated-workflow.sh                  # Original script (kept for reference)
├── setup-maas.sh                           # Original MaaS script
├── enable-genai-maas.sh                    # Original GenAI script
└── ... (other existing scripts)
```

## ✨ Key Improvements

### 1. **Separation of Concerns**
- **Logic** (functions) separated from **Data** (YAML manifests)
- Each component has its own file
- Easy to find and modify specific parts

### 2. **Reduced Script Length**
- Main scripts are now ~200 lines instead of 1000+
- Functions are organized by purpose
- Manifests are in separate, readable YAML files

### 3. **Easier Debugging**
- Can test individual functions in isolation
- Can validate YAML manifests separately
- Clear error messages with component context

### 4. **Better Maintainability**
- Update a manifest without touching script logic
- Reuse functions across different scripts
- Add new components without modifying existing ones

### 5. **Version Control Benefits**
- Cleaner diffs in Git
- Easier to review changes
- Can track manifest changes separately from logic

## 🚀 Usage Examples

### Using the Modular Script

```bash
# Full installation
./integrated-workflow-v2.sh

# Skip OpenShift installation (use existing cluster)
./integrated-workflow-v2.sh --skip-openshift

# Install only RHOAI (no OpenShift, no GPU)
./integrated-workflow-v2.sh --skip-openshift --skip-gpu
```

### Using Functions Directly

```bash
#!/bin/bash

# Source the libraries
source lib/utils/colors.sh
source lib/utils/common.sh
source lib/functions/operators.sh

# Use individual functions
install_nfd_operator
install_gpu_operator
install_rhcl_operator
```

### Applying Manifests Manually

```bash
# Apply a specific manifest
oc apply -f lib/manifests/operators/nfd-operator.yaml

# Apply all operator manifests
oc apply -f lib/manifests/operators/

# Validate a manifest without applying
oc apply -f lib/manifests/operators/gpu-operator.yaml --dry-run=client
```

## 📊 Comparison: Before vs After

### Before (Monolithic)
```bash
integrated-workflow.sh          # 1139 lines
├── All logic inline
├── All YAML in heredocs
├── Hard to debug
└── Difficult to maintain
```

### After (Modular)
```bash
integrated-workflow-v2.sh       # ~200 lines
├── Sources lib/functions/operators.sh
├── Calls install_nfd_operator()
├── Calls install_gpu_operator()
└── Calls install_rhcl_operator()

lib/functions/operators.sh      # ~200 lines
├── install_nfd_operator()
├── install_gpu_operator()
└── install_rhcl_operator()

lib/manifests/operators/
├── nfd-operator.yaml           # 20 lines
├── gpu-operator.yaml           # 25 lines
└── gpu-clusterpolicy.yaml      # 100 lines
```

## 🔧 Migration Status

### ✅ Completed
- [x] Directory structure created
- [x] Color and print utilities
- [x] Common utility functions
- [x] NFD operator (function + manifests)
- [x] GPU operator (function + manifests)
- [x] RHCL operator (function + manifests)
- [x] Example refactored script (integrated-workflow-v2.sh)
- [x] Documentation (lib/README.md)

### 🚧 In Progress / TODO
- [ ] RHOAI operator functions
- [ ] RHOAI manifests (operator, DSC, DSCInit)
- [ ] MaaS setup functions
- [ ] MaaS manifests (Gateway, kustomize, etc.)
- [ ] GenAI/Dashboard configuration functions
- [ ] Complete refactoring of all main scripts
- [ ] Testing and validation

## 🎓 How to Contribute

### Adding a New Component

1. **Create the manifest file:**
   ```bash
   # Create YAML file
   cat > lib/manifests/operators/my-operator.yaml << 'EOF'
   ---
   apiVersion: operators.coreos.com/v1alpha1
   kind: Subscription
   ...
   EOF
   ```

2. **Add a function:**
   ```bash
   # Edit lib/functions/operators.sh
   install_my_operator() {
       print_header "Installing My Operator"
       apply_manifest "$SCRIPT_DIR/lib/manifests/operators/my-operator.yaml" "My Operator"
       wait_for_operator_ready "my-operator" "my-namespace"
       print_success "My operator installation complete"
   }
   ```

3. **Use in main script:**
   ```bash
   # Edit integrated-workflow-v2.sh
   source "$SCRIPT_DIR/lib/functions/operators.sh"
   install_my_operator
   ```

### Testing Changes

```bash
# Test a specific function
bash -c "
source lib/utils/colors.sh
source lib/utils/common.sh
source lib/functions/operators.sh
install_nfd_operator
"

# Validate manifests
oc apply -f lib/manifests/operators/ --dry-run=client

# Run the full script
./integrated-workflow-v2.sh --skip-openshift
```

## 📝 Design Principles

1. **Idempotency**: All functions check if resources exist before creating
2. **Error Handling**: Functions return proper exit codes
3. **Logging**: Use print_* functions for consistent output
4. **Documentation**: Each function has a clear purpose
5. **Reusability**: Functions can be used independently

## 🔄 Backwards Compatibility

- Original scripts (`integrated-workflow.sh`, etc.) are **kept unchanged**
- New modular scripts have `-v2` suffix
- Users can choose which version to use
- Gradual migration path

## 🎯 Benefits Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Script Length** | 1000+ lines | 200 lines |
| **Debugging** | Hard (find in 1000 lines) | Easy (specific file) |
| **YAML Editing** | Edit heredoc in script | Edit .yaml file |
| **Reusability** | Copy/paste functions | Import library |
| **Testing** | Test entire script | Test individual functions |
| **Git Diffs** | Large, complex | Small, focused |
| **Onboarding** | Read 1000+ lines | Read modular docs |

## 📚 Additional Resources

- [lib/README.md](lib/README.md) - Detailed library documentation
- [lib/utils/colors.sh](lib/utils/colors.sh) - Color utilities
- [lib/utils/common.sh](lib/utils/common.sh) - Common functions
- [lib/functions/operators.sh](lib/functions/operators.sh) - Operator functions

## 🤝 Feedback Welcome!

This is a work in progress. Feedback and suggestions are welcome!

- What works well?
- What could be improved?
- What other components should be modularized?

