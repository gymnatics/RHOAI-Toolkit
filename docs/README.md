# OpenShift AI Documentation

Complete documentation for OpenShift AI installation and configuration on AWS.

## 📚 Quick Navigation

### Getting Started
- [Main README](../README.md) - Quick start guide
- [Quick Reference](../QUICK-REFERENCE.md) - Common commands

### Essential Guides
- [Hardware Profiles](../HARDWARE-PROFILE-FINAL-SOLUTION.md) - **START HERE** for hardware profile issues
- [GPU Taints](guides/GPU-TAINTS-RHOAI3.md) - GPU node configuration and tolerations
- [Interactive Taint Feature](../INTERACTIVE-TAINT-FEATURE.md) - Automatic GPU taint detection

### How-To Guides
- [Configuration Reuse](guides/CONFIGURATION-REUSE.md) - Save and reuse installation settings
- [Tool Calling](guides/TOOL-CALLING-GUIDE.md) - Enable function calling in models
- [MaaS Serving Runtimes](guides/MAAS-SERVING-RUNTIMES.md) - Which runtimes work with MaaS
- [Using Existing AWS Infrastructure](guides/USING-EXISTING-AWS-INFRASTRUCTURE.md) - Reuse VPCs and subnets

### Reference
- [KServe Deployment Modes](reference/KSERVE-DEPLOYMENT-MODES.md) - RawDeployment vs Serverless
- [Setup Comparison](reference/SETUP-COMPARISON.md) - Our setup vs reference repos

### Troubleshooting
- [General Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [Fix Summaries](fixes/) - Detailed fix documentation

## 📖 Documentation Structure

```
docs/
├── README.md (this file)          # Documentation index
├── TROUBLESHOOTING.md             # General troubleshooting
│
├── guides/                        # Step-by-step guides
│   ├── CONFIGURATION-REUSE.md    # Save/reuse installation config
│   ├── GPU-TAINTS-RHOAI3.md      # GPU taint configuration
│   ├── TOOL-CALLING-GUIDE.md     # Model tool calling setup
│   ├── MAAS-SERVING-RUNTIMES.md  # MaaS compatibility
│   └── USING-EXISTING-AWS-INFRASTRUCTURE.md  # Reuse VPCs
│
├── reference/                     # Reference documentation
│   ├── KSERVE-DEPLOYMENT-MODES.md
│   └── SETUP-COMPARISON.md
│
└── fixes/                         # Fix summaries
    ├── KUEUE-FIX-SUMMARY.md
    ├── LWS-FIX-SUMMARY.md
    ├── HARDWARE-PROFILE-FIX.md
    └── CLUSTER-RESTART-ISSUES.md
```

## 🎯 Common Tasks

### Hardware Profiles Not Showing?
1. Read: [HARDWARE-PROFILE-FINAL-SOLUTION.md](../HARDWARE-PROFILE-FINAL-SOLUTION.md)
2. Key fix: Add `scheduling` section with Kueue configuration

### GPU Models Failing with "untolerated taint"?
1. Read: [guides/GPU-TAINTS-RHOAI3.md](guides/GPU-TAINTS-RHOAI3.md)
2. Run: `./scripts/fix-gpu-resourceflavor.sh`

### Enable Tool Calling for Qwen Models?
1. Read: [guides/TOOL-CALLING-GUIDE.md](guides/TOOL-CALLING-GUIDE.md)
2. Use: `--tool-call-parser=hermes`

### Which Runtime for MaaS?
1. Read: [guides/MAAS-SERVING-RUNTIMES.md](guides/MAAS-SERVING-RUNTIMES.md)
2. Answer: Only `llm-d` works with MaaS

## 🔧 Scripts

### Installation
- `./complete-setup.sh` - Full installation (interactive menu)
- `./scripts/openshift-installer-master.sh` - OpenShift only
- `./scripts/create-gpu-machineset.sh` - Add GPU nodes

### Configuration
- `./scripts/create-hardware-profile.sh <namespace>` - Create GPU hardware profile
- `./scripts/fix-gpu-resourceflavor.sh` - Fix GPU taint tolerations
- `./scripts/setup-maas.sh` - Setup MaaS API

### Cleanup
- `./scripts/cleanup-all.sh` - Clean up all AWS resources

## 📝 Key Concepts

### Hardware Profiles (RHOAI 3.0)
- Define resource requirements (CPU, Memory, GPU)
- **Must include** `scheduling` section for Kueue
- Namespace-scoped for model deployment
- Global profiles go in `redhat-ods-applications`

### Kueue Architecture
```
HardwareProfile → LocalQueue → ClusterQueue → ResourceFlavor
```
- **ResourceFlavor** defines node selection and tolerations
- **NOT** the HardwareProfile!

### GPU Taints
- Recommended: Taint GPU nodes with `nvidia.com/gpu:NoSchedule`
- Prevents non-GPU workloads on expensive GPU instances
- Tolerations go in **ResourceFlavor**, not HardwareProfile

### MaaS (Model as a Service)
- Only works with `llm-d` serving runtime
- Does NOT work with `vLLM` through UI
- Requires RHCL operator (Kuadrant + Authorino)

## 🆘 Getting Help

1. **Check Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. **Search Documentation**: Use your IDE's search (Cmd+Shift+F)
3. **Check Fixes**: Look in [fixes/](fixes/) for similar issues
4. **Verify Installation**: Run verification commands in troubleshooting guide

## 📚 External Resources

- [RHOAI 3.0 Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0)
- [Kueue Documentation](https://kueue.sigs.k8s.io/)
- [KServe Documentation](https://kserve.github.io/website/)
- [vLLM Documentation](https://docs.vllm.ai/)

---

**Last Updated**: November 2025  
**RHOAI Version**: 3.0  
**OpenShift Version**: 4.19
