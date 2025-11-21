# Utility Scripts

This folder contains utility scripts that support the main installation workflows.

## Scripts

### cleanup-all.sh
**Purpose**: Comprehensive cleanup of AWS resources

**Usage**:
```bash
./scripts/cleanup-all.sh
```

**What it does**:
- Runs `openshift-install destroy` if cluster exists
- Releases unassociated Elastic IPs
- Deletes NAT Gateways and waits for deletion
- Cleans up subnets, security groups, network interfaces
- Removes route tables and internet gateways
- Deletes VPCs
- Handles orphaned resources

**When to use**:
- After testing/development
- When decommissioning a cluster
- To clean up failed installations
- To free up AWS resources and reduce costs

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

### enable-genai-maas.sh
**Purpose**: Enable GenAI Playground and MaaS UI features

**Usage**:
```bash
./scripts/enable-genai-maas.sh
```

**What it does**:
- Installs RHCL/Kuadrant operators
- Installs Leader Worker Set (LWS) operator
- Installs Kueue operator
- Updates DataScienceCluster to v2 API
- Enables GenAI Studio in dashboard
- Enables Model as a Service UI
- Creates GPU hardware profile
- Enables user workload monitoring

**When to use**:
- On existing RHOAI installations
- When you want GenAI Playground
- When you want Model as a Service
- To enable llm-d serving runtime

**Prerequisites**:
- RHOAI must already be installed
- Cluster must have GPU nodes (or plan to add them)

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
- After enabling MaaS UI features
- When you want MaaS API endpoints
- For production model serving with authentication
- To enable billing/tracking for models

**Prerequisites**:
- RHOAI installed
- GenAI and MaaS UI features enabled
- `jq` installed (`brew install jq`)

**Note**: MaaS API pods may take 2-3 minutes to be ready after deployment.

---

## Typical Usage Flow

### Fresh Installation
```bash
# 1. Install OpenShift + RHOAI (from root)
./integrated-workflow.sh

# 2. Create GPU nodes
./scripts/create-gpu-machineset.sh

# 3. Set up MaaS
./scripts/setup-maas.sh
```

### Existing RHOAI Installation
```bash
# 1. Enable GenAI and MaaS features
./scripts/enable-genai-maas.sh

# 2. Set up MaaS API
./scripts/setup-maas.sh

# 3. Create GPU nodes if needed
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

- **Main Scripts** (in root): `openshift-installer-master.sh`, `integrated-workflow.sh`, `complete-setup.sh`
- **Diagnostics** (in diagnostics/): Tools for troubleshooting
- **Tests** (in tests/): Test scripts for validation
- **Documentation** (in docs/): Detailed guides and troubleshooting

