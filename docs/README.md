# Documentation Index

Complete documentation for OpenShift AI installation and configuration on AWS.

## Quick Navigation

### Getting Started
- [Main README](../README.md) - Project overview and quick start
- [Quick Reference](../QUICK-REFERENCE.md) - Common commands cheat sheet
- [Features Guide](../FEATURES.md) - Feature quick reference

---

## Guides

Step-by-step instructions for common tasks.

| Guide | Description |
|-------|-------------|
| [Configuration Reuse](guides/CONFIGURATION-REUSE.md) | Save and reuse installation settings |
| [GPU Taints](guides/GPU-TAINTS-RHOAI3.md) | GPU node configuration and tolerations |
| [Hardware Profile Setup](guides/HARDWARE-PROFILE-SETUP.md) | Create hardware profiles for RHOAI 3.0 |
| [Interactive Model Deployment](guides/INTERACTIVE-MODEL-DEPLOYMENT.md) | Deploy models via the interactive menu |
| [Kubeconfig Management](guides/KUBECONFIG-MANAGEMENT.md) | Manage cluster connections |
| [LLMD Setup](guides/LLMD-SETUP-GUIDE.md) | Set up llm-d serving runtime |
| [MaaS Policy Enforcement](guides/MAAS-POLICY-ENFORCEMENT.md) | Configure MaaS authentication |
| [MaaS Serving Runtimes](guides/MAAS-SERVING-RUNTIMES.md) | Which runtimes work with MaaS |
| [MCP Servers](guides/MCP-SERVERS.md) | Model Context Protocol for tool calling |
| [MCP Server Setup](guides/MCP-SERVER-SETUP.md) | Configure MCP servers |
| [Model Registry](guides/MODEL-REGISTRY.md) | Model versioning and lifecycle |
| [GenAI Playground](guides/GENAI-PLAYGROUND-INTEGRATION.md) | Add models to playground |
| [Tool Calling](guides/TOOL-CALLING-GUIDE.md) | Enable function calling in models |
| [Using Existing AWS Infrastructure](guides/USING-EXISTING-AWS-INFRASTRUCTURE.md) | Reuse VPCs and subnets |

---

## Reference

Technical reference documentation.

| Document | Description |
|----------|-------------|
| [GPU ResourceFlavor Configuration](reference/GPU-RESOURCEFLAVOR-CONFIGURATION.md) | Kueue ResourceFlavor setup |
| [KServe Deployment Modes](reference/KSERVE-DEPLOYMENT-MODES.md) | RawDeployment vs Serverless |
| [OS Compatibility](reference/OS-COMPATIBILITY.md) | Cross-platform compatibility layer |
| [Serving Runtime Comparison](reference/SERVING-RUNTIME-COMPARISON.md) | Compare vLLM, llm-d, etc. |
| [Setup Comparison](reference/SETUP-COMPARISON.md) | Our setup vs reference repos |

---

## Troubleshooting

- [General Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [AWS Prerequisites Check](AWS-PREREQUISITES-CHECK.md) - Pre-installation validation
- [VPC Early Detection](VPC-EARLY-DETECTION-IMPROVEMENT.md) - VPC configuration issues

### Fix Documentation

Detailed documentation for specific fixes:

| Fix | Description |
|-----|-------------|
| [Cluster Restart Issues](fixes/CLUSTER-RESTART-ISSUES.md) | Issues after cluster restart |
| [Dashboard Route Fix](fixes/DASHBOARD-ROUTE-FIX.md) | Dashboard route not created |
| [Hardware Profile Fix](fixes/HARDWARE-PROFILE-FIX.md) | Hardware profiles not showing |
| [Kuadrant Fresh Cluster Fix](fixes/KUADRANT-FRESH-CLUSTER-FIX.md) | Kuadrant on new clusters |
| [Kueue Fix](fixes/KUEUE-FIX-SUMMARY.md) | Kueue configuration issues |
| [LWS Fix](fixes/LWS-FIX-SUMMARY.md) | Leader Worker Set issues |
| [macOS Grep/AWK Fix](fixes/MACOS-GREP-AWK-FIX.md) | macOS compatibility |
| [vLLM Args Error Fix](fixes/VLLM-ARGS-ERROR-FIX.md) | vLLM argument errors |

---

## Common Tasks

### Hardware Profiles Not Showing?
1. Ensure profile has `scheduling` section with Kueue configuration
2. See [Hardware Profile Setup](guides/HARDWARE-PROFILE-SETUP.md)

### GPU Models Failing with "untolerated taint"?
1. Run: `./scripts/fix-gpu-resourceflavor.sh`
2. See [GPU Taints](guides/GPU-TAINTS-RHOAI3.md)

### Enable Tool Calling for Qwen Models?
1. Use `--tool-call-parser=hermes` in vLLM args
2. See [Tool Calling Guide](guides/TOOL-CALLING-GUIDE.md)

### Which Runtime for MaaS?
- Only `llm-d` works with MaaS
- See [MaaS Serving Runtimes](guides/MAAS-SERVING-RUNTIMES.md)

---

## Scripts Reference

### Main Script
- `./rhoai-toolkit.sh` - Full installation (interactive menu)

### Installation Scripts
- `./scripts/openshift-installer-master.sh` - OpenShift only
- `./scripts/install-rhoai-minimal.sh` - Minimal RHOAI setup

### Configuration Scripts
- `./scripts/create-gpu-machineset.sh` - Add GPU nodes
- `./scripts/create-hardware-profile.sh` - Create hardware profiles
- `./scripts/fix-gpu-resourceflavor.sh` - Fix GPU tolerations
- `./scripts/enable-dashboard-features.sh` - Enable dashboard features
- `./scripts/setup-maas.sh` - Setup MaaS API
- `./scripts/setup-mcp-servers.sh` - Configure MCP servers

### Deployment Scripts
- `./scripts/deploy-llmd-model.sh` - Deploy llm-d model
- `./scripts/add-model-to-playground.sh` - Add model to playground

### Utility Scripts
- `./scripts/cleanup-all.sh` - Clean up AWS resources
- `./scripts/manage-kubeconfig.sh` - Manage kubeconfig
- `./scripts/check-aws-prerequisites.sh` - Validate AWS setup

---

## External Resources

- [RHOAI 3.0 Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0)
- [OpenShift Documentation](https://docs.openshift.com)
- [Kueue Documentation](https://kueue.sigs.k8s.io/)
- [KServe Documentation](https://kserve.github.io/website/)
- [vLLM Documentation](https://docs.vllm.ai/)

---

**Last Updated**: January 2026  
**RHOAI Version**: 3.0  
**OpenShift Version**: 4.19
