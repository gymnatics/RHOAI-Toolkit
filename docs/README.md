# Documentation Index

Documentation for OpenShift AI installation and configuration on AWS.

## Quick Navigation

- [Main README](../README.md) — Project overview and quick start
- [Troubleshooting](TROUBLESHOOTING.md) — All issues and solutions in one place

---

## Guides

Step-by-step instructions for common tasks.

### Installation

| Guide | Description |
|-------|-------------|
| [RHOAI 3.4 Installation](guides/RHOAI-34-INSTALLATION.md) | Full RHOAI 3.4 install guide (recommended) |
| [RHOAI 3.4 What's New](guides/RHOAI-34-WHATS-NEW.md) | Changes from 3.3 to 3.4 (MaaS GA, NeMo GA, AutoML/AutoRAG) |
| [RHOAI 3.3 Installation](guides/RHOAI-33-INSTALLATION.md) | Full RHOAI 3.3 install guide |
| [RHOAI 3.3 What's New](guides/RHOAI-33-WHATS-NEW.md) | Changes from 3.2 to 3.3 |
| [Manual Installation](guides/RHOAI-MANUAL-INSTALLATION-GUIDE.md) | Step-by-step with all YAMLs |
| [Manual RHOAI Setup](guides/MANUAL-RHOAI-SETUP.md) | Alternative manual setup |
| [AWS Prerequisites](guides/AWS-PREREQUISITES-CHECK.md) | Pre-installation validation |
| [Using Existing AWS Infrastructure](guides/USING-EXISTING-AWS-INFRASTRUCTURE.md) | Reuse VPCs and subnets |
| [Configuration Reuse](guides/CONFIGURATION-REUSE.md) | Save and reuse install settings |
| [Kubeconfig Management](guides/KUBECONFIG-MANAGEMENT.md) | Manage cluster connections |

### GPU & Hardware

| Guide | Description |
|-------|-------------|
| [GPU Taints](guides/GPU-TAINTS-RHOAI3.md) | GPU node configuration and tolerations |
| [Hardware Profile Setup](guides/HARDWARE-PROFILE-SETUP.md) | Create hardware profiles for RHOAI 3.x |

### Model Deployment

| Guide | Description |
|-------|-------------|
| [Interactive Model Deployment](guides/INTERACTIVE-MODEL-DEPLOYMENT.md) | Deploy models via interactive menu |
| [llm-d Setup](guides/LLMD-SETUP-GUIDE.md) | Set up llm-d serving runtime |
| [Tool Calling](guides/TOOL-CALLING-GUIDE.md) | Enable function calling in models |
| [Model Registry](guides/MODEL-REGISTRY.md) | Model versioning and lifecycle |
| [GenAI Playground](guides/GENAI-PLAYGROUND-INTEGRATION.md) | Add models to playground |

### MaaS (Model as a Service)

| Guide | Description |
|-------|-------------|
| [MaaS Setup](guides/MAAS-SETUP-STEP-BY-STEP.md) | Step-by-step MaaS configuration |
| [MaaS Serving Runtimes](guides/MAAS-SERVING-RUNTIMES.md) | Which runtimes work with MaaS |
| [MaaS Policy Enforcement](guides/MAAS-POLICY-ENFORCEMENT.md) | Configure MaaS authentication |
| [MaaS Demo](guides/MAAS-DEMO-GUIDE.md) | Running the MaaS demo |

### Third-Party on OpenShift

| Guide | Description |
|-------|-------------|
| [Dify Enterprise — Kaniko Fix](guides/DIFY-OPENSHIFT-KANIKO-TROUBLESHOOTING.md) | Fix Kaniko plugin builder permission errors on OpenShift |

### MCP & Tool Calling

| Guide | Description |
|-------|-------------|
| [MCP Servers](guides/MCP-SERVERS.md) | Model Context Protocol for tool calling |
| [MCP Server Setup](guides/MCP-SERVER-SETUP.md) | Configure MCP servers |
| [OCP MCP Server Deployment](guides/OCP-MCP-SERVER-DEPLOYMENT.md) | Deploy MCP servers on OpenShift |

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

All troubleshooting is consolidated in [TROUBLESHOOTING.md](TROUBLESHOOTING.md), covering:
- OpenShift installation issues
- RHOAI component problems (Kueue, LWS, Authorino, dashboard)
- Model deployment (hardware profiles, vLLM args)
- MaaS / rate limiting (RHOAI 3.3 Tech Preview)
- macOS compatibility

---

## Demo Applications

| Demo | Description |
|------|-------------|
| [MaaS Demo](../demo/maas-demo/README.md) | Interactive MaaS demonstration |
| [LlamaStack Demo](../demo/llamastack-demo/README.md) | Chatbot frontend with MCP |
| [Guardrails Demo](../demo/guardrails-demo/README.md) | AI safety demo |
| [GuideLLM Demo](../demo/guidellm-demo/README.md) | LLM benchmarking |

---

## External Resources

- [RHOAI 3.3 Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.3)
- [OpenShift Documentation](https://docs.openshift.com)
- [Kueue Documentation](https://kueue.sigs.k8s.io/)
- [KServe Documentation](https://kserve.github.io/website/)
- [vLLM Documentation](https://docs.vllm.ai/)

---

**Last Updated**: May 2026
**RHOAI Version**: 3.3
**OpenShift Version**: 4.19+
