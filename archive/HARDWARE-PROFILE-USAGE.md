# GPU Hardware Profile - Usage Guide

## 🎯 Quick Start

### Method 1: Interactive Menu (Recommended)

```bash
./complete-setup.sh
```

Select **Option 2: Create GPU Hardware Profile**

The wizard will guide you through:

1. **Namespace Selection**
   - Enter the namespace where you deploy models
   - Creates namespace if it doesn't exist
   - Validates namespace before proceeding

2. **CPU Configuration**
   - Default: 2 CPUs
   - Minimum: 1 CPU
   - Maximum: 16 CPUs

3. **Memory Configuration**
   - Default: 16Gi
   - Minimum: 1Gi
   - Maximum: 64Gi

4. **GPU Configuration**
   - Default: 1 GPU
   - Minimum: 1 GPU
   - Maximum: 8 GPUs

5. **Profile Naming**
   - Profile name: `gpu-profile` (default)
   - Display name: `GPU Profile` (default)

### Method 2: Standalone Script

```bash
# Use current namespace
./scripts/create-hardware-profile.sh

# Specify namespace
./scripts/create-hardware-profile.sh my-project
```

This uses default values (same as pressing Enter for all prompts in interactive mode).

### Method 3: Fix Existing Profile

```bash
./scripts/fix-hardware-profile.sh
```

This fixes profiles that aren't visible in the UI.

## 📋 Example Walkthrough

```bash
$ ./complete-setup.sh

╔════════════════════════════════════════════════════════════════╗
║                    Main Menu                                   ║
╚════════════════════════════════════════════════════════════════╝

1) Complete Setup (OpenShift + RHOAI + GPU + MaaS)
2) Create GPU Hardware Profile (for existing cluster)
3) Setup MaaS Only (assumes RHOAI exists)
4) Exit

Select an option (1-4): 2

╔════════════════════════════════════════════════════════════════╗
║ Create GPU Hardware Profile
╚════════════════════════════════════════════════════════════════╝

✓ Connected to OpenShift cluster

Enter the namespace where you want to create the hardware profile
(This should be the namespace where you deploy models)
Current namespace: 0-demo
Press Enter to use current namespace, or type a different one: 

▶ Configuring hardware profile resources...

CPU Configuration:
Default CPU count [2]: 4
Minimum CPU count [1]: 2
Maximum CPU count [16]: 32

Memory Configuration:
Default Memory (e.g., 16Gi) [16Gi]: 32Gi
Minimum Memory (e.g., 1Gi) [1Gi]: 8Gi
Maximum Memory (e.g., 64Gi) [64Gi]: 128Gi

GPU Configuration:
Default GPU count [1]: 2
Minimum GPU count [1]: 1
Maximum GPU count [8]: 8

Hardware profile name [gpu-profile]: 
Display name [GPU Profile]: High-Performance GPU

▶ Creating hardware profile 'gpu-profile' in namespace '0-demo'...

hardwareprofile.infrastructure.opendatahub.io/gpu-profile created

✓ Hardware profile 'gpu-profile' created successfully in namespace '0-demo'

▶ Verifying...
NAME          DISPLAY                  DISABLED
gpu-profile   High-Performance GPU     false

ℹ The hardware profile should now be visible in the RHOAI dashboard
ℹ when deploying models in the '0-demo' namespace.

⚠ Remember: Hardware profiles are namespace-scoped in RHOAI 3.0
⚠ Create this profile in each namespace where you want to deploy GPU models

Press Enter to return to main menu...
```

## 🎨 Customization Examples

### Small GPU Workloads

```
CPU: Default 2, Min 1, Max 8
Memory: Default 8Gi, Min 4Gi, Max 32Gi
GPU: Default 1, Min 1, Max 2
```

### Large GPU Workloads

```
CPU: Default 8, Min 4, Max 32
Memory: Default 64Gi, Min 16Gi, Max 256Gi
GPU: Default 4, Min 1, Max 8
```

### Multi-GPU Training

```
CPU: Default 16, Min 8, Max 64
Memory: Default 128Gi, Min 32Gi, Max 512Gi
GPU: Default 8, Min 2, Max 8
```

## 🔧 Advanced Usage

### Create Profiles in Multiple Namespaces

```bash
# Method 1: Interactive (recommended)
./complete-setup.sh
# Select option 2, repeat for each namespace

# Method 2: Script (faster for multiple namespaces)
for ns in project-1 project-2 project-3; do
    ./scripts/create-hardware-profile.sh $ns
done
```

### Verify Profile

```bash
# Check profile exists
oc get hardwareprofile gpu-profile -n my-namespace

# Check full configuration
oc get hardwareprofile gpu-profile -n my-namespace -o yaml

# Check labels (required for UI discovery)
oc get hardwareprofile gpu-profile -n my-namespace -o jsonpath='{.metadata.labels}' | jq .
```

### Update Existing Profile

Just run the creation again - it will update the existing profile:

```bash
./complete-setup.sh
# Select option 2
# Enter same namespace and profile name
# Provide new resource values
```

## 📝 Important Notes

### Namespace-Scoped Profiles

- Hardware profiles MUST be in the **same namespace** as your model deployment
- Creating in `redhat-ods-applications` won't make them visible for model deployment
- Each project needs its own hardware profile

### Required Metadata

The interactive wizard automatically adds:
- ✅ `app.opendatahub.io/hardwareprofile: "true"` label (required for UI discovery)
- ✅ `app.kubernetes.io/part-of: hardwareprofile` label
- ✅ All required annotations (display-name, disabled, managed, description)

### No Scheduling Constraints

The profiles created by this wizard **do not include scheduling constraints** (nodeSelector).

**Why?**
- Profiles with nodeSelector are hidden when no matching nodes exist
- GPU resource requests still ensure pods are scheduled on GPU nodes
- Better user experience - profile always visible

**If you need scheduling constraints**, edit the profile manually:
```bash
oc edit hardwareprofile gpu-profile -n my-namespace
```

## 🐛 Troubleshooting

### Profile Not Visible in UI

1. **Check you're in the right namespace**:
   ```bash
   oc project
   oc get hardwareprofile
   ```

2. **Verify profile has required labels**:
   ```bash
   oc get hardwareprofile gpu-profile -o jsonpath='{.metadata.labels}' | jq .
   ```
   Should include: `app.opendatahub.io/hardwareprofile: "true"`

3. **Restart dashboard**:
   ```bash
   oc delete pod -n redhat-ods-applications -l app=rhods-dashboard
   ```

4. **Use the fix script**:
   ```bash
   ./scripts/fix-hardware-profile.sh
   ```

### Namespace Doesn't Exist

The wizard will prompt to create it:
```
✗ Namespace 'my-project' does not exist
Do you want to create it? (y/n): y
```

### Permission Issues

You need cluster-admin or appropriate RBAC permissions to:
- Create namespaces
- Create HardwareProfile resources
- Access the target namespace

## 🔗 Related Documentation

- [HARDWARE-PROFILE-FIX.md](docs/HARDWARE-PROFILE-FIX.md) - Complete troubleshooting guide
- [HARDWARE-PROFILE-TROUBLESHOOTING.md](docs/HARDWARE-PROFILE-TROUBLESHOOTING.md) - Detailed technical info
- [FIXES-APPLIED.md](FIXES-APPLIED.md) - Summary of fixes
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Quick reference card

## 💡 Tips

1. **Use defaults for quick setup** - Just press Enter for all prompts
2. **Create profiles before deploying models** - Saves time later
3. **Document your resource limits** - Keep track of what profiles you created where
4. **Test in UI** - Always verify the profile appears after creation
5. **Use descriptive display names** - Makes it easier to identify profiles in the UI

## ✅ Checklist

Before deploying a model:
- [ ] Hardware profile exists in the deployment namespace
- [ ] Profile has correct resource limits for your workload
- [ ] Profile is visible in RHOAI dashboard
- [ ] GPU nodes are available (if using GPU profile)
- [ ] NFD and GPU operators are running

After creating a profile:
- [ ] Verify with `oc get hardwareprofile -n <namespace>`
- [ ] Check it appears in the RHOAI dashboard
- [ ] Test by deploying a model
- [ ] Document the profile configuration

