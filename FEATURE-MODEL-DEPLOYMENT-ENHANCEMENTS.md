# Model Deployment Enhancements

## Summary of Changes

The model deployment functionality has been significantly enhanced to be runtime-agnostic and more intelligent.

---

## New Features

### 1. ✅ Auto-Detect Serving Runtimes

The deployment script now automatically detects available serving runtimes:

- **llm-d (LLMInferenceService)** - Multi-replica, MaaS support, Leader Worker Set
- **vLLM (InferenceService)** - Simple deployment, GenAI Playground
- **ServingRuntime templates** - Shows available custom runtimes

**What you'll see:**
```
╔════════════════════════════════════════════════════════════════╗
║ Serving Runtime Selection
╚════════════════════════════════════════════════════════════════╝

▶ Detecting available serving runtimes...

Available serving runtimes:

1) llm-d (LLMInferenceService)
   Multi-replica, MaaS support, Leader Worker Set

2) vLLM (InferenceService)
   Simple deployment, GenAI Playground

Select serving runtime (1-2):
```

### 2. ✅ Auto-Detect Hardware Profiles

The script now detects GPU hardware profiles and lets you choose:

**What you'll see:**
```
╔════════════════════════════════════════════════════════════════╗
║ Resource Configuration
╚════════════════════════════════════════════════════════════════╝

▶ Detecting available hardware profiles...

Found GPU hardware profiles:

  - gpu-large: 2 GPU, 16 CPU, 64Gi Memory
  - gpu-medium: 1 GPU, 8 CPU, 32Gi Memory
  - gpu-small: 1 GPU, 4 CPU, 16Gi Memory

Resource configuration options:

1) Use hardware profile: gpu-large
   GPU: 2, CPU: 16, Memory: 64Gi

2) Use hardware profile: gpu-medium
   GPU: 1, CPU: 8, Memory: 32Gi

3) Use hardware profile: gpu-small
   GPU: 1, CPU: 4, Memory: 16Gi

4) Use default resources (GPU: 1, CPU: 4, Memory: 16Gi)

5) Custom configuration (enter manually)

Select option (1-5):
```

### 3. ✅ Runtime-Specific Deployment

The script now deploys using the appropriate API based on selected runtime:

#### For llm-d:
```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-4b
spec:
  replicas: 1
  model:
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest
  router:
    route: {}
    gateway: {}
    scheduler: {}
  template:
    containers:
    - name: main
      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: "--enable-auto-tool-choice --tool-call-parser=hermes"
```

#### For vLLM:
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: qwen3-4b
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: vllm-runtime
      storage:
        path: oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest
      args:
        - --enable-auto-tool-choice
        - --tool-call-parser=hermes
```

### 4. ✅ Added to complete-setup.sh Menu

New menu option added:

```
╔════════════════════════════════════════════════════════════════╗
║                    Main Menu                                   ║
╚════════════════════════════════════════════════════════════════╝

1) Complete Setup (OpenShift + RHOAI + GPU + MaaS)
2) Deploy Model (interactive model deployment)  ← NEW!
3) Create GPU Hardware Profile (for existing cluster)
4) Setup MaaS Only (assumes RHOAI exists)
5) Exit
```

---

## Files Modified

### Core Changes:

1. **`lib/functions/model-deployment.sh`**
   - Renamed function: `deploy_llmd_model_interactive()` → `deploy_model_interactive()`
   - Added backward-compatible alias
   - Added serving runtime detection
   - Added hardware profile detection
   - Added runtime-specific deployment logic
   - Support for both llm-d and vLLM

2. **`complete-setup.sh`**
   - Added menu option 2: "Deploy Model"
   - Added `deploy_model_interactive()` function
   - Updated menu handling for 5 options

3. **`scripts/deploy-llmd-model.sh`**
   - Updated to use new `deploy_model_interactive()` function
   - Removed llm-d-specific prerequisite checks (now runtime-agnostic)
   - Updated documentation

### Backward Compatibility:

All existing scripts that call `deploy_llmd_model_interactive()` will continue to work via the alias.

---

## Usage

### From complete-setup.sh Menu:

```bash
./complete-setup.sh
# Select option 2: Deploy Model
```

### From Standalone Script:

```bash
./scripts/deploy-llmd-model.sh
```

### Programmatically:

```bash
source lib/functions/model-deployment.sh
deploy_model_interactive
```

---

## What Gets Detected

### Serving Runtimes:

- ✅ Checks for `llminferenceservices.serving.kserve.io` CRD (llm-d)
- ✅ Checks for `inferenceservices.serving.kserve.io` CRD (vLLM)
- ✅ Lists available `ServinRuntime` templates

### Hardware Profiles:

- ✅ Queries `hardwareprofiles` with GPU selector
- ✅ Extracts GPU count, CPU, and memory specs
- ✅ Presents as selectable options

---

## Benefits

### For Users:

✅ **No need to know which runtime to use** - Script detects what's available  
✅ **Easy hardware profile selection** - No manual resource configuration  
✅ **Consistent experience** - Same script works for llm-d and vLLM  
✅ **Intelligent defaults** - Uses hardware profiles when available  
✅ **Flexible** - Can still manually configure resources  

### For Developers:

✅ **Runtime-agnostic** - Single function supports multiple runtimes  
✅ **Extensible** - Easy to add more runtime support  
✅ **Backward compatible** - Old function name still works  
✅ **Well-documented** - Clear code and comments  

---

## Example Flow

### Complete Workflow:

```
1. User runs: ./complete-setup.sh
2. Selects: "2) Deploy Model"
3. Script detects: llm-d and vLLM available
4. User selects: llm-d
5. Script detects: 3 GPU hardware profiles
6. User selects: gpu-medium (1 GPU, 8 CPU, 32Gi)
7. User selects: Qwen3-4B model
8. User selects: Create new namespace "my-models"
9. User enables: Tool calling
10. User enables: Authentication
11. Script deploys: LLMInferenceService with selected config
12. Done!
```

---

## Testing

### Test 1: Runtime Detection

```bash
# Check what CRDs exist
oc get crd | grep -E 'inferenceservice|llminferenceservice'

# Run deployment
./scripts/deploy-llmd-model.sh

# Should show available runtimes
```

### Test 2: Hardware Profile Detection

```bash
# Check hardware profiles
oc get hardwareprofiles

# Run deployment
./scripts/deploy-llmd-model.sh

# Should show hardware profiles if any exist
```

### Test 3: llm-d Deployment

```bash
./scripts/deploy-llmd-model.sh
# Select llm-d runtime
# Select hardware profile or default
# Deploy model
# Verify: oc get llmisvc -A
```

### Test 4: vLLM Deployment

```bash
./scripts/deploy-llmd-model.sh
# Select vLLM runtime
# Select hardware profile or default
# Deploy model
# Verify: oc get inferenceservice -A
```

---

## Migration Notes

### Old Code:
```bash
source lib/functions/model-deployment.sh
deploy_llmd_model_interactive  # Old function name
```

### New Code:
```bash
source lib/functions/model-deployment.sh
deploy_model_interactive  # New function name
```

### Backward Compatible:
```bash
# Both work! Old name is aliased to new name
deploy_llmd_model_interactive  # Still works
deploy_model_interactive       # Preferred
```

---

## Future Enhancements

Possible additions:

- [ ] Support for Caikit runtime
- [ ] Support for TGI (Text Generation Inference)
- [ ] Support for custom ServingRuntime templates
- [ ] Resource quota checking
- [ ] Node availability checking
- [ ] Model registry integration
- [ ] Multi-model deployment
- [ ] Batch deployment from file

---

## Summary

✅ **Runtime detection** - Auto-detect llm-d, vLLM, and custom runtimes  
✅ **Hardware profile detection** - Auto-detect and select GPU profiles  
✅ **Runtime-agnostic deployment** - Single function for all runtimes  
✅ **Menu integration** - Added to complete-setup.sh  
✅ **Backward compatible** - Old function name still works  
✅ **Enhanced UX** - Smarter, more intuitive deployment  

**The model deployment is now intelligent, flexible, and runtime-agnostic!** 🚀

