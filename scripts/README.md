# Utility Scripts

This folder contains utility scripts that support the main installation workflows.

## Scripts

---

### check-aws-prerequisites.sh
**Purpose**: Validate AWS environment before OpenShift installation

**Usage**:
```bash
# Run standalone check
./scripts/check-aws-prerequisites.sh

# Or it runs automatically in rhoai-toolkit.sh
```

**What it checks**:
- ✅ AWS CLI installation and credentials
- ✅ Route53 hosted zones (public vs private)
- ✅ AWS service quotas (VPC, Elastic IPs)
- ✅ Existing OpenShift resources
- ✅ SSH key configuration
- ✅ OpenShift installer binary
- ⚠️ Conflicting private hosted zones from failed installs

**When to use**:
- Before first installation
- After failed installation (diagnose issues)
- After changing AWS environments
- When troubleshooting DNS/bootstrap failures

**Benefits**:
- Catches issues BEFORE spending 30-45 minutes on installation
- Clear error messages with actionable solutions
- Prevents common mistakes (like domain with leading dot!)

**See**: `docs/AWS-PREREQUISITES-CHECK.md` for detailed documentation

---

### manage-kubeconfig.sh
**Purpose**: Manage kubeconfig files and KUBECONFIG environment variable

**Usage**:
```bash
# Interactive menu
./scripts/manage-kubeconfig.sh

# Quick commands
./scripts/manage-kubeconfig.sh --show      # Show current configuration
./scripts/manage-kubeconfig.sh --clear     # Clear kubeconfig
./scripts/manage-kubeconfig.sh --logout    # Logout from cluster
./scripts/manage-kubeconfig.sh --set       # Set kubeconfig file
```

**What it does**:
- Shows current kubeconfig configuration and cluster connection
- Clears KUBECONFIG environment variable
- Removes kubeconfig files (with backup)
- Logs out from current cluster
- Sets kubeconfig to a specific file
- Checks shell profiles for KUBECONFIG exports

**When to use**:
- When switching between clusters
- When kubeconfig is pointing to an old/deleted cluster
- To clean up after cluster deletion
- To troubleshoot connection issues
- Before installing a new cluster

**Common scenarios**:
```bash
# Stuck with old cluster? Clear it
./scripts/manage-kubeconfig.sh --clear

# Want to see current setup?
./scripts/manage-kubeconfig.sh --show

# Need to logout?
./scripts/manage-kubeconfig.sh --logout
```

---

### cleanup-all.sh
**Purpose**: Comprehensive cleanup of AWS resources (now with quick local cleanup option!)

**Usage**:
```bash
# Interactive menu (recommended)
./scripts/cleanup-all.sh

# Quick local cleanup only (no AWS changes)
./scripts/cleanup-all.sh --local-only
./scripts/cleanup-all.sh -l

# See detailed usage guide
cat scripts/CLEANUP-USAGE.md
```

**What it does**:

**Option 1: Local Cleanup Only** (Quick - seconds)
- Removes `openshift-cluster-install/` directory
- Removes `cluster-info.txt`
- Does NOT touch AWS resources
- Perfect for retrying failed installations

**Option 2: Complete Cleanup** (Thorough - 10-20 minutes)
- Runs `openshift-install destroy` if cluster exists
- Releases unassociated Elastic IPs
- Deletes NAT Gateways and waits for deletion
- Cleans up subnets, security groups, network interfaces
- Removes route tables and internet gateways
- Deletes VPCs
- Handles orphaned resources

**When to use**:
- **Local cleanup**: Failed installation, quick retry, local files only
- **Complete cleanup**: Decommissioning cluster, stopping AWS charges, full reset

---

### create-gpu-machineset.sh
**Purpose**: Create GPU worker nodes dynamically

**Usage**:
```bash
./scripts/create-gpu-machineset.sh
```

**What it does**:
- Detects cluster ID automatically
- Extracts AMI ID and IAM profile from existing workers
- Lists available subnets for selection
- Prompts for GPU instance type (p5.48xlarge, g6e.*)
- Configures storage (default or custom)
- Generates MachineSet YAML
- Applies to cluster

**When to use**:
- After cluster installation
- When you need GPU workers
- To add more GPU capacity
- Works across different clusters

---

### manage-gpu-nodes.sh
**Purpose**: Stop/start the AWS EC2 instances behind GPU MachineSets directly, instead of deleting/recreating them via `oc scale machineset --replicas=0/N`

**Usage**:
```bash
./scripts/manage-gpu-nodes.sh status                    # show AWS power state + Node Ready for all GPU machines
./scripts/manage-gpu-nodes.sh stop                       # AWS-stop all GPU instances (Machine objects untouched)
./scripts/manage-gpu-nodes.sh start                      # AWS-start them, wait for Nodes to rejoin Ready
./scripts/manage-gpu-nodes.sh start --machineset <name>  # target one MachineSet only
./scripts/manage-gpu-nodes.sh stop --no-wait             # fire-and-forget
```

**What it does**:
- Finds all Machines in MachineSets with `gpu` in the name (or `--machineset <name>`)
- Resolves each Machine's underlying EC2 instance ID from `spec.providerID`
- `stop`/`start` calls `aws ec2 stop-instances`/`start-instances` directly — the
  Machine API object is never touched
- `start` waits for AWS state `running`, then waits for the same Node to
  rejoin as `Ready`

**Why use this instead of scaling the MachineSet to 0**: scaling to 0 deletes
the Machine and EC2 instance; scaling back up provisions a **brand-new**
instance from scratch (full RHCOS boot, ignition, cluster join, GPU Operator
driver/toolkit reinstall). For bare metal GPU nodes (e.g. `g4dn.metal`) this
can take 15-30+ minutes and can trigger unrelated MachineConfigPool churn if
the node belongs to a custom pool. AWS stop/start preserves the EBS root
volume and node identity, so the same node just resumes in a couple of
minutes with everything already installed.

**Caveats**:
- Local instance-store (ephemeral NVMe) data is wiped on stop — the EBS root
  volume is unaffected
- Some AWS bare metal instance types have historically not supported stop
  (only reboot/terminate); the script surfaces the AWS API error verbatim if
  a stop/start call is rejected
- Requires `aws` CLI configured with credentials for the account hosting the
  cluster (same convention as every other AWS-touching script here)

**When to use**:
- Pausing/resuming GPU nodes overnight or between demo sessions, especially
  bare metal types where re-provisioning is slow
- As a faster alternative/complement to
  [`setup-node-scheduler.sh`](../docs/guides/NODE-SCHEDULING.md)'s
  CronJob-based scale-to-0 approach

---

### setup-maas.sh
**Purpose**: Set up Model as a Service (MaaS) API infrastructure

**Usage**:
```bash
./scripts/setup-maas.sh
```

**What it does**:
- Installs RHCL/Kuadrant operators (if not present)
- Creates Kuadrant instance
- Configures Authorino with TLS
- Creates GatewayClass
- Deploys MaaS API using kustomize
- Configures audience policy
- Restarts controllers

**When to use**:
- After enabling Dashboard features
- When you want MaaS API endpoints
- For production model serving with authentication
- To enable billing/tracking for models

**Prerequisites**:
- RHOAI installed
- GenAI and Dashboard features enabled
- `jq` installed (`brew install jq`)

**Note**: MaaS API pods may take 2-3 minutes to be ready after deployment.

---

---

### install-rhoai-34.sh
**Purpose**: Full RHOAI 3.4 installation — NFD, GPU, Kueue, cert-manager, RHCL, MaaS, llm-d, observability, dashboards

**Usage**:
```bash
./scripts/install-rhoai-34.sh
./scripts/install-rhoai-34.sh --channel stable-3.4
./scripts/install-rhoai-34.sh --deploy-grafana --setup-users --num-users 10
```

**What it does**: Installs all prerequisites, RHOAI operator, MaaS with PostgreSQL, observability stack (COO + Perses + Observe tab dashboards), MLflow (auto-detects PostgreSQL), hardware profiles, and optional Grafana/users/pipelines.

---

### setup-letsencrypt-tls.sh
**Purpose**: Automated TLS certificate setup (Let's Encrypt via Route53 DNS-01 or self-signed)

**Usage**:
```bash
./scripts/setup-letsencrypt-tls.sh              # Interactive menu
./scripts/setup-letsencrypt-tls.sh letsencrypt  # Direct Let's Encrypt setup
./scripts/setup-letsencrypt-tls.sh selfsigned   # Direct self-signed setup
./scripts/setup-letsencrypt-tls.sh status       # Show TLS status
```

---

### deploy-dashboards.sh
**Purpose**: Deploy GPU/vLLM monitoring dashboards to OpenShift Observe tab or standalone Grafana

**Usage**:
```bash
./scripts/deploy-dashboards.sh                        # All dashboards to Observe tab
./scripts/deploy-dashboards.sh --method grafana       # Deploy via Grafana Operator
./scripts/deploy-dashboards.sh --dashboard vllm       # Only vLLM dashboard
./scripts/deploy-dashboards.sh --delete               # Remove all dashboards
```

---

### deploy-demo-environment.sh
**Purpose**: Deploy all 17 demo components on an existing RHOAI 3.4 cluster

**Usage**:
```bash
./scripts/deploy-demo-environment.sh --skip-core
./scripts/deploy-demo-environment.sh --components feast,pipeline,open-webui
./scripts/deploy-demo-environment.sh --list
```

---

### setup-node-scheduler.sh
**Purpose**: Deploy CronJob-based worker node scheduling — scale workers/GPU up at 8 AM and down at 6 PM (Mon-Fri, Asia/Singapore) to save AWS costs. Control-plane nodes keep the cluster alive 24/7.

**Usage**:
```bash
./scripts/setup-node-scheduler.sh                   # deploy CronJobs
./scripts/setup-node-scheduler.sh --trigger down     # manually scale down now
./scripts/setup-node-scheduler.sh --trigger up       # manually scale up now
./scripts/setup-node-scheduler.sh --status           # show CronJob state + MachineSets
./scripts/setup-node-scheduler.sh --remove           # tear down
```

**See**: `docs/guides/NODE-SCHEDULING.md`

---

### create-restricted-client-admin.sh
**Purpose**: Give a client/customer a `cluster-admin` login that cannot change worker/control-plane node counts (MachineSet/Machine/ControlPlaneMachineSet/MachineHealthCheck/MachineAutoscaler/ClusterAutoscaler, or delete Nodes) — enforced via `ValidatingAdmissionPolicy`, not RBAC (RBAC can't subtract from `cluster-admin`'s wildcard rule)

**Usage**:
```bash
./scripts/create-restricted-client-admin.sh --client-user client-admin --client-password '<pw>' --owner-user admin
./scripts/create-restricted-client-admin.sh --test --client-user client-admin     # verify the deny policy works
./scripts/create-restricted-client-admin.sh --remove --client-user client-admin   # revoke their cluster-admin binding
```

**See**: `docs/guides/RESTRICTED-CLIENT-ADMIN-ACCESS.md` for the full design/rationale

---

## Typical Usage Flow

### Fresh Installation (Recommended)
```bash
# 1. Install RHOAI 3.4 (includes GPU, MaaS, observability)
./scripts/install-rhoai-34.sh

# 2. Create GPU nodes (if not auto-scaled)
./scripts/create-gpu-machineset.sh

# 3. Deploy a model
./scripts/serve-model.sh s3 my-model Qwen/Qwen3-8B-Instruct
```

### Existing RHOAI Installation
```bash
# 1. Set up MaaS platform (RHCL, Gateway, PostgreSQL, DSC flags)
./scripts/setup-maas.sh

# 2. Create GPU nodes if needed
./scripts/create-gpu-machineset.sh
```

### Cleanup
```bash
# Clean up all AWS resources
./scripts/cleanup-all.sh
```

## Notes

- All scripts are designed to be idempotent (safe to run multiple times)
- Scripts check for existing resources before creating
- Most scripts provide detailed output and error messages
- Scripts are meant to be run from the repository root directory

## See Also

- **Main Scripts**: `rhoai-toolkit.sh` (root), `scripts/integrated-workflow-v2.sh`
- **Diagnostics** (in diagnostics/): Tools for troubleshooting
- **Tests** (in tests/): Test scripts for validation
- **Documentation** (in docs/): Detailed guides and troubleshooting

