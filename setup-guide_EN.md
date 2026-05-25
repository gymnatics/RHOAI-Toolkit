# RHOAI Toolkit - Step-by-Step Setup Guide

A complete walkthrough from OpenShift cluster installation on AWS to RHOAI 3.4 deployment, GPU configuration, and model serving.

---

## Prerequisites Checklist

Verify the following items are ready before you begin.

- [ ] **AWS Access Key ID** (e.g. `AKIAV...`)
- [ ] **AWS Secret Access Key**
- [ ] **OpenShift Pull Secret** file (`pull-secret.txt`)
  - Download: https://console.redhat.com/openshift/install/pull-secret
- [ ] **AWS Route53 Domain** (e.g. `.sandbox1785.opentlc.com`)
- [ ] **AWS Region** (e.g. `us-east-2`)
- [ ] **HuggingFace Token** (required only for gated models, optional)
  - Gemma 4 E2B (`google/gemma-4-E2B-it`) — Apache 2.0, **no token needed**
  - Llama, Mistral, etc. (gated models) — token **required**
  - Get token: https://huggingface.co/settings/tokens
  - Set up: `export HF_TOKEN=hf_your_token_here` (recommended to add to `.bashrc` or `.zshrc`)

---

## Step 0: Local Environment Setup

### 0-1. Verify Required Tools

```bash
# Check each tool is installed
oc version          # OpenShift CLI (4.14+)
aws --version       # AWS CLI (2.x)
jq --version        # JSON processor (1.6+)
yq --version        # YAML processor (4.x)
```

> **If not installed:**
> - oc CLI: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/
> - AWS CLI: `brew install awscli` / https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html
> - jq: `brew install jq` (macOS) or `sudo yum install jq` (Linux)
> - yq: `brew install yq` (macOS) or https://github.com/mikefarah/yq

### 0-2. Configure AWS CLI

```bash
aws configure
```

Enter the following when prompted:

```
AWS Access Key ID [None]: <your Access Key>
AWS Secret Access Key [None]: <your Secret Key>
Default region name [None]: us-east-2
Default output format [None]: json
```

### 0-3. Verify Configuration

```bash
# Test AWS credentials
aws sts get-caller-identity

# Check Route53 domains
aws route53 list-hosted-zones --query 'HostedZones[].Name' --output table
```

> **Checkpoint:** If `get-caller-identity` returns your Account/Arn, you're good to go.

### 0-4. SSH Key Setup

An SSH key is required for OpenShift cluster installation.

```bash
# Check for existing SSH keys
ls ~/.ssh/id_rsa.pub 2>/dev/null || ls ~/.ssh/id_ed25519.pub 2>/dev/null

# Generate a new key if none exists
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Start SSH agent and add key
eval $(ssh-agent)
ssh-add ~/.ssh/id_ed25519
```

> **Note:** If you already have an `id_rsa` key, use `ssh-add ~/.ssh/id_rsa` instead.

### 0-5. Verify Pull Secret File Location

```bash
# Check the pull-secret.txt path
ls -la ~/pull-secret.txt
# or the directory where you downloaded it
```

> **Tip:** Remember the file path — you'll need it during cluster installation.

---

## Step 1: OpenShift Cluster Installation

### 1-1. Launch the Toolkit

```bash
cd /path/to/RHOAI-Toolkit
./rhoai-toolkit.sh
```

### 1-2. Select from Main Menu

```
╔════════════════════════════════════════════════════════════════╗
║                    Main Menu                                   ║
╚════════════════════════════════════════════════════════════════╝

RHOAI 3.x (Current):
1) Complete Setup (OpenShift + RHOAI 3.x + GPU + MaaS) [Full]   ← Don't select yet
2) Minimal RHOAI 3.x Setup (choose operators) [Flexible]
3) Install RHOAI 3.x [Recommended]                               ← Not yet

Management & Tools:
9) Configure Kubeconfig [Connection]
```

**What to do now:** Since there is no cluster yet, select `1`.

> **Already have a cluster?** → Skip to [Step 2](#step-2-verify-cluster-connection).

### 1-3. Values to Enter During Installation

The script will prompt for the following values. Have them ready.

| Item | Example | Description |
|------|---------|-------------|
| Cluster Name | `my-cluster` | Your desired cluster name |
| Base Domain | `sandbox1785.opentlc.com` | Route53 domain |
| AWS Region | `us-east-2` | AWS region |
| Master Instance Type | `m6i.xlarge` | Recommended to use default |
| Worker Instance Type | `m6i.2xlarge` | Recommended to use default |
| Worker Replicas | `2` | Minimum 2 |
| Pull Secret Path | `/path/to/pull-secret.txt` | Path to your pull secret file |

### 1-4. Wait for Installation

> **Expected time:** ~30–45 minutes
>
> The following message during installation is normal:
> ```
> INFO Waiting up to 40m0s for the cluster at https://api.my-cluster.sandbox1785.opentlc.com:6443 to initialize...
> ```

### 1-5. Verify Installation

Once complete, you'll see:

```
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run
    export KUBECONFIG=/path/to/auth/kubeconfig
INFO Access the OpenShift web-console here:
    https://console-openshift-console.apps.my-cluster.sandbox1785.opentlc.com
```

**Make sure to record:**
- `KUBECONFIG` path
- Web Console URL
- `kubeadmin` password

---

## Step 2: Verify Cluster Connection

### 2-1. Set Kubeconfig

```bash
# If you just finished installation, this may already be set
export KUBECONFIG=/path/to/auth/kubeconfig

# Alternatively, use oc login
oc login https://api.my-cluster.sandbox1785.opentlc.com:6443 \
  -u kubeadmin -p <password>
```

### 2-2. Verify Connection

```bash
oc whoami                    # Current logged-in user
oc get nodes                 # Node list
oc get clusterversion        # OpenShift version
```

> **Checkpoints:**
> - `oc whoami` outputs a username
> - `oc get nodes` shows Master/Worker nodes in `Ready` state
> - OpenShift version is **4.19+**

---

## Step 3: Install RHOAI 3.4

### 3-1. Select Option 3 from Main Menu

```bash
./rhoai-toolkit.sh
```

```
3) Install RHOAI 3.x [Recommended]    ← Select this
```

### 3-2. Choose Version

```
╔════════════════════════════════════════════════════════════════╗
║              RHOAI Installation - Version Selection            ║
╚════════════════════════════════════════════════════════════════╝

  1) RHOAI 3.4 [Latest GA]          ← Select 1
     MaaS GA, MLflow GA, native vLLM multi-node

  2) RHOAI 3.3
```

### 3-3. Monitor Installation Progress

The script automatically installs in this order:

```
[1/10] ▶ Checking prerequisites...
[2/10] ▶ Scaling cluster nodes...
[3/10] ▶ Installing NFD Operator...
[4/10] ▶ Installing NVIDIA GPU Operator...
[5/10] ▶ Installing Kueue Operator...
[6/10] ▶ Installing cert-manager Operator...
[7/10] ▶ Installing LWS Operator...
[8/10] ▶ Installing RHCL Operator...
[9/10] ▶ Installing RHOAI Operator...
[10/10] ▶ Creating DataScienceCluster...
```

### 3-4. Channel Selection (prompted during install)

```
Available RHOAI Channels:

Stable Channels:
  1) stable-3.x [default]    ← Recommended: press Enter for default

Select channel (1-N) [default: 1]:
```

> **Recommended:** Just press Enter to select `stable-3.x`.

### 3-5. Installation Complete

```
╔════════════════════════════════════════════════════════════════╗
║          RHOAI 3.4 Installation Complete!                      ║
╚════════════════════════════════════════════════════════════════╝

Dashboard URL: https://data-science-gateway.apps.my-cluster.sandbox1785.opentlc.com
Inference Gateway: https://inference-gateway.apps.my-cluster.sandbox1785.opentlc.com
```

### 3-6. Verify Installation

```bash
oc get datasciencecluster           # Check Phase: Ready
oc get csv -n redhat-ods-operator   # Check Succeeded
oc get pods -n redhat-ods-applications | head -20   # Check pod status
```

> **Expected time:** ~20–30 minutes (operator installation + DSC readiness)

---

## Step 4: Add GPU Nodes

> **Note:** GPU nodes may have been automatically created during Step 3. Verify with the commands below.

### 4-1. Check GPU Nodes

```bash
oc get machineset -n openshift-machine-api | grep gpu
oc get nodes -l nvidia.com/gpu.present=true
```

### 4-2. If No GPU Nodes Exist

```bash
./rhoai-toolkit.sh
# Select 7) Create GPU MachineSet
```

Or run directly:

```bash
./scripts/create-gpu-machineset.sh
```

**Options:**

| Item | Recommended | Description |
|------|-------------|-------------|
| Instance Type | `g6e.xlarge` | 1x L40S GPU, most cost-effective |
| Spot Instance | `Y` | Cost savings (up to 90%) |
| Replicas | `1` | Start with 1 |

### 4-3. Wait for GPU Node Ready

```bash
# Watch until GPU node reaches Ready state (5–10 min)
watch "oc get nodes -l nvidia.com/gpu.present=true"
```

### 4-4. Verify GPU Operation

```bash
./rhoai-toolkit.sh
# 8) GPU & ClusterPolicy Management
# 9) Run nvidia-smi on GPU Node
```

> **Checkpoint:** If `nvidia-smi` outputs GPU information, the setup is successful.

---

## Step 5: Model Deployment (Optional)

### 5-1. Quick Deploy with Presets

```bash
./scripts/serve-model.sh
```

Running without arguments displays the preset menu:

```
1) Gemma 4 E2B (google/gemma-4-E2B-it)  — 1 GPU, 5B, Apache 2.0
2) Qwen2.5-Coder-7B (OCI ModelCar)      — coding-optimized, 1 GPU
3) Custom S3 model
4) Custom PVC model
5) Custom OCI model
```

### 5-2. Interactive Deployment (More Options)

```bash
./rhoai-toolkit.sh
# 6) RHOAI Management → 1) Deploy Model
```

Step-by-step configuration from runtime selection (llm-d, vLLM, vLLM-Community, vLLM-Gemma4, vLLM-Omni) to model catalog (9 presets), namespace, resources, tool-calling, and authentication.

Storage options: **OCI, S3 (MinIO), PVC, and HuggingFace URL** all supported.

### 5-3. CLI Automation (for scripts/pipelines)

```bash
# serve-model.sh CLI mode (mode name path [vllm_args])
./scripts/serve-model.sh oci qwen3-4b oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b
./scripts/serve-model.sh s3 qwen3-8b Qwen/Qwen3-8B-Instruct
./scripts/serve-model.sh hf gemma4-e2b google/gemma-4-E2B-it  # Apache 2.0, no token needed

# Specify namespace/runtime via environment variables
NAMESPACE=my-project RUNTIME=vllm-gemma4 \
  ./scripts/serve-model.sh hf gemma4-e2b google/gemma-4-E2B-it

# Additional vLLM arguments
./scripts/serve-model.sh oci my-model oci://quay.io/... "--max-model-len 8192 --enable-auto-tool-choice"
```

Supported modes:

| Mode | Description | URI Format |
|------|-------------|------------|
| `oci` | OCI ModelCar registry | `oci://registry.redhat.io/...` |
| `s3` | S3 (MinIO/AWS) storage | Relative path (e.g. `Qwen/Qwen3-8B`) |
| `pvc` | PVC volume | Relative path (e.g. `meta-llama/...`) |
| `hf` | HuggingFace model | Model ID (e.g. `google/gemma-4-E2B-it`) |

Environment variables: `NAMESPACE` (default: demo), `RUNTIME` (default: vllm), `HF_TOKEN`, `HF_TOKEN_SECRET`

### 5-4. Download HuggingFace Model to S3, then Deploy

```bash
./scripts/setup-model-storage.sh                          # Set up MinIO
./scripts/download-model.sh s3 Qwen/Qwen3-8B-Instruct    # Download model
./scripts/serve-model.sh s3 qwen3-8b Qwen/Qwen3-8B-Instruct  # Deploy
```

### 5-5. Quick Start Wizard

```bash
./rhoai-toolkit.sh
# 6) RHOAI Management → 6) Quick Start Wizard ✨
```

The Wizard guides you through 4 steps:
1. Enable Dashboard features
2. Deploy a model (optional)
3. Add model to Playground (optional)
4. Configure MCP Server (optional)

---

## Step 6: MaaS Setup (Optional)

### 6-1. Set Up MaaS

```bash
./rhoai-toolkit.sh
# 6) RHOAI Management
# 2) AI Services & Infrastructure
# 1) Setup MaaS
```

Or run directly:

```bash
./scripts/setup-maas.sh
```

### 6-2. Verify MaaS Endpoint

```bash
# RHOAI 3.4 integrated MaaS
curl -k https://inference-gateway.apps.my-cluster.sandbox1785.opentlc.com/v1/models
```

---

## Post-Installation Verification Commands

```bash
# Full status check
oc get datasciencecluster                          # DSC status
oc get csv -A | grep -E "nfd|gpu|kueue|lws|rhcl|rhods"   # Operator status
oc get nodes -l nvidia.com/gpu.present=true        # GPU nodes
oc get hardwareprofiles -n redhat-ods-applications  # Hardware profiles
oc get gateway -n openshift-ingress                 # MaaS gateway
oc get inferenceservice -A                          # Deployed models
```

---

## Cluster Instance Management (AWS)

In sandbox environments such as the Red Hat Demo Platform, instance states may not sync correctly with the portal. Use the script below to manage all EC2 instances at once.

> **Prerequisite:** Run this script from the directory where OpenShift was installed.
> It uses the installer kubeconfig (`openshift-cluster-install/auth/kubeconfig`) with a client certificate
> to authenticate before OAuth recovers after cluster restart.

```bash
# Check status
./restart-cluster-instances.sh status

# Full restart (stop → start → wait for API → operator stabilization)
./restart-cluster-instances.sh restart

# Stop only
./restart-cluster-instances.sh stop

# Start only
./restart-cluster-instances.sh start
```

> **Start/restart flow:**
> 1. Pre-flight: verify installer kubeconfig (client certificate)
> 2. Auto-detect cluster infra ID and region from `metadata.json`
> 3. Stop/start EC2 instances
> 4. Phase 1: Wait for API server healthz
> 5. Phase 2: Auto-approve kubelet CSRs (client cert auth, no OAuth needed)
> 6. Phase 3: Wait for OAuth/Ingress recovery
> 7. Phase 4: oc login + approve remaining CSRs + operator stabilization

---

## Troubleshooting

| Symptom | Diagnostic Command | Resolution |
|---------|-------------------|------------|
| Cannot connect to cluster | `oc whoami` | `./rhoai-toolkit.sh` → 9 (Configure Kubeconfig) |
| GPU node NotReady | `oc get nodes` | Approve CSR: `./rhoai-toolkit.sh` → 6 → 7 (Day 2 Operations) |
| GPU Operator error | `oc get csv -n nvidia-gpu-operator` | `./rhoai-toolkit.sh` → 8 → 4 (Check GPU Operator Status) |
| RHOAI install stuck | `oc get csv -n redhat-ods-operator` | Check InstallPlan: `./scripts/check-pending-installplans.sh` |
| Model deployment failed | `oc get pods -n <namespace>` | `./rhoai-toolkit.sh` → 6 → 8 (Troubleshooting) |
| Dashboard inaccessible | Check URL in browser | `oc get route -n redhat-ods-applications` |

> For detailed troubleshooting, see [TROUBLESHOOTING.md](../TROUBLESHOOTING.md).

---

## Estimated Total Time

| Step | Duration | Notes |
|------|----------|-------|
| Step 0: Environment setup | 5–10 min | Excluding tool installation |
| Step 1: OpenShift installation | 30–45 min | Includes AWS infrastructure |
| Step 2: Connection verification | 2 min | |
| Step 3: RHOAI installation | 20–30 min | 10 operators installed |
| Step 4: GPU nodes | 5–10 min | Node provisioning |
| Step 5: Model deployment | 5–15 min | Varies by model size |
| **Total** | **~1 to 1.5 hours** | |
