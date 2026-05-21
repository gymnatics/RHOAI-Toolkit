# RHOAI 3.4 Installation Guide

## Prerequisites

- OpenShift Container Platform 4.19+ (4.20+ recommended for llm-d)
- `oc` CLI logged in with cluster-admin privileges
- AWS infrastructure (for GPU MachineSet creation)

## Quick Start

```bash
# Full automated install (recommended)
./scripts/install-rhoai-34.sh

# With specific channel
./scripts/install-rhoai-34.sh --channel stable-3.4

# Skip prerequisites if already installed
./scripts/install-rhoai-34.sh --skip-prerequisites

# Enable vLLM runtime for MaaS (Technology Preview)
./scripts/install-rhoai-34.sh --enable-vllm-maas
```

## Installation Steps

The `install-rhoai-34.sh` script performs these steps in order:

### 1. Prerequisites Check
- Verifies `oc` CLI, cluster login, cluster-admin
- Checks OCP version >= 4.19 (warns if < 4.20 for llm-d)

### 2. Node Scaling
- Scales workers to >= 2
- Creates GPU MachineSet (g6e.xlarge) if none exists

### 3. Prerequisite Operators
- **NFD** (Node Feature Discovery)
- **GPU Operator** (NVIDIA)
- **Kueue** (workload scheduling)
- **cert-manager**
- **LWS** (Leader Worker Set — for llm-d multi-node)

### 4. RHCL / MaaS Infrastructure
- **Service Mesh 3** (auto-installed as OLM dependency; uses manual InstallPlan approval)
- **Istio** + IstioCNI (for EnvoyFilter / gateway TLS bootstrap)
- **RHCL v1.2+** operator — Subscription in `openshift-operators`, Kuadrant CR in `kuadrant-system`
  (per [RHOAI 3.4 MaaS docs §1.2](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/govern_llm_access_with_models-as-a-service);
  RHCL's own docs put everything in `kuadrant-system` but both work — AllNamespaces mode)
- **Inference Gateways**:
  - `maas-default-gateway` with annotations:
    - `opendatahub.io/managed: "false"` — lets MaaS controller manage auth policies
    - `security.opendatahub.io/authorino-tls-bootstrap: "true"` — enables TLS to Authorino
  - `openshift-ai-inference` for direct llm-d model access
- **Gateway TLS** (`default-gateway-tls` secret):
  - The gateways reference a TLS secret that is NOT auto-created by RHOAI or RHCL
  - The toolkit auto-creates it using: cert-manager Certificate CR (preferred), existing wildcard cert copy, or router-ca signed cert
  - Without this secret, the gateway's Envoy proxy never starts port 443 and all MaaS traffic returns 503
- **Gateway Passthrough Routes**:
  - `*.apps.<cluster>` DNS wildcard points to the default OpenShift Router, not to the gateway's LoadBalancer
  - The toolkit creates OpenShift Routes with TLS passthrough to bridge traffic from the Router to each gateway service

### 5. User Workload Monitoring
- Enables Prometheus user workload monitoring (required for MaaS Tenant to report Ready)

### 6. RHOAI Operator
- Interactive channel selection (or `--channel stable-3.4`)
- Creates operator subscription

### 7. DataScienceCluster
- Applies `datasciencecluster-v3-34.yaml` (API v2) with all components enabled
- Components: dashboard, workbenches, aipipelines, kserve (with MaaS + NIM), kueue, ray, modelregistry, trustyai, feastoperator, llamastackoperator, mlflowoperator

### 8. Post-Installation
- **Dashboard features**: Model Registry, Model Catalog, GenAI Studio, MaaS, maasAuthPolicies, KServe Metrics, LM-Eval
- **Hardware profile**: Default GPU profile in `redhat-ods-applications`

### 9. MaaS TLS Configuration (New in 3.4)
Uses OpenShift service-ca instead of cert-manager Certificate:
1. Annotate `authorino-authorino-authorization` service for service-ca cert generation
2. Patch Authorino CR to enable TLS listener with the generated cert
3. Set `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` env vars on Authorino deployment
4. Annotate `maas-default-gateway` with `security.opendatahub.io/authorino-tls-bootstrap: "true"`

### 10. MaaS PostgreSQL Setup
MaaS requires PostgreSQL 14+ for API key validation. The script handles this automatically:
- **No `--postgres-connection` flag**: Deploys a POC PostgreSQL (5Gi PVC, not production-grade) in `redhat-ods-applications`
- **With `--postgres-connection`**: Creates the secret from your external database URL
- **With `--skip-maas-db`**: Skips entirely (you manage the secret yourself)

The secret format is a single connection URL:
```bash
oc create secret generic maas-db-config \
  --from-literal=DB_CONNECTION_URL='postgresql://user:pass@host:5432/db?sslmode=require' \
  -n redhat-ods-applications
```

For production, use AWS RDS, Crunchy Postgres Operator, or Azure Database for PostgreSQL.

### 11. MaaS Verification
- Checks MaaS CRDs (MaaSSubscription, MaaSAuthPolicy, MaaSModelRef, Tenant, ExternalModel)
- Verifies Tenant CR status in `models-as-a-service` namespace
- Validates gateway annotations and Authorino TLS configuration

## Script Flags

| Flag | Description |
|------|-------------|
| `--skip-prerequisites` | Skip NFD, GPU, Kueue, cert-manager |
| `--skip-rhcl` | Skip RHCL/Kuadrant (no MaaS/llm-d auth) |
| `--skip-maas` | Skip MaaS configuration |
| `--skip-node-scaling` | Skip worker/GPU node scaling |
| `--no-llmd` | Don't install LWS or configure llm-d Gateway |
| `--enable-vllm-maas` | Enable vLLM runtime for MaaS (Technology Preview) |
| `--enable-observability` | Enable MaaS observability dashboard (Technology Preview) |
| `--postgres-connection <url>` | External PostgreSQL URL for MaaS (format: `postgresql://user:pass@host:5432/db?sslmode=require`) |
| `--skip-maas-db` | Skip MaaS PostgreSQL setup entirely |
| `--channel <channel>` | RHOAI channel (e.g., `stable-3.4`, `fast-3.x`) |
| `--domain <domain>` | Cluster domain |
| `--timeout <seconds>` | Operator wait timeout (default: 600) |
| `--setup-users` | Create demo users (user1..userN) with htpasswd + groups |
| `--num-users <N>` | Number of demo users (default: 5, implies `--setup-users`) |
| `--admin-group <name>` | Admin group name (default: `rhods-admins`). user1 goes here. |
| `--user-group <name>` | Regular user group name (default: `rhods-users`). user2+ go here. |
| `--user-password <pw>` | Password for all demo users (default: `openshift`) |

## DataScienceCluster Components

| Component | State | Notes |
|-----------|-------|-------|
| `dashboard` | Managed | Web interface |
| `workbenches` | Managed | Jupyter/IDE, Red Hat Python index |
| `aipipelines` | Managed | Kubeflow Pipelines (required for AutoML/AutoRAG) |
| `kserve` | Managed | Model serving (RawDeployment + Headed) |
| `kserve.nim` | Managed | NVIDIA NIM support |
| `kserve.modelsAsService` | Managed | MaaS (core GA in 3.4; vLLM/OIDC/observability/egress still TP) |
| `kueue` | Unmanaged | Using standalone Kueue Operator |
| `ray` | Managed | Distributed computing |
| `trainer` | Removed | Enable if JobSet operator installed |
| `trainingoperator` | Removed | Deprecated, use `trainer` |
| `modelregistry` | Managed | OCI storage, PostgreSQL backend |
| `trustyai` | Managed | NeMo Guardrails (GA in 3.4) |
| `feastoperator` | Managed | Feature Store (Technology Preview) |
| `llamastackoperator` | Managed | Llama Stack 0.6.0 |
| `mlflowoperator` | Managed | MLflow (officially managed DSC component) |

## Verification

```bash
# Check DSC status
oc get datasciencecluster

# Check operator
oc get csv -n redhat-ods-operator

# Check hardware profiles
oc get hardwareprofiles -n redhat-ods-applications

# Check dashboard (RHOAI 3.4 uses rh-ai route)
oc get route rh-ai -n redhat-ods-applications

# Check MaaS CRDs
oc get crd | grep maas.opendatahub.io

# Check MaaS Tenant status
oc get tenant -n models-as-a-service
oc get tenant default-tenant -n models-as-a-service -o jsonpath='{.status.conditions}'

# Check MaaS gateway annotations
oc get gateway maas-default-gateway -n openshift-ingress -o yaml | head -20

# Check Authorino TLS
oc get authorino authorino -n kuadrant-system -o jsonpath='{.spec.listener.tls}'
oc get secret authorino-server-cert -n kuadrant-system

# Check MaaS subscriptions and policies
oc get maassubscriptions -n models-as-a-service
oc get maasauthpolicies -n models-as-a-service

# Check components
oc get pods -n redhat-ods-applications
oc get pods -n redhat-ods-operator
```

## User Management

The toolkit can create demo users with htpasswd authentication and organize them into groups for MaaS access.

### During Installation
```bash
./scripts/install-rhoai-34.sh --setup-users --num-users 10 --user-password demo123
```

### Standalone (after installation)
```bash
# Basic: 5 users, default groups
./scripts/setup-users.sh

# Custom: 10 users, custom groups
./scripts/setup-users.sh --num-users 10 --admin-group team-leads --user-group developers

# With MaaS subscription creation
./scripts/setup-users.sh --num-users 5 --create-subscription --model-name qwen3-8b --model-namespace 0-demo
```

### How It Works
- Creates `user1` through `userN` in htpasswd
- `user1` → admin group (`rhods-admins`) + cluster-admin role
- `user2`..`userN` → regular user group (`rhods-users`)
- Configures htpasswd identity provider on OAuth if not present
- Optionally creates MaaS Subscriptions + Auth Policies per group

### MaaS Subscription + API Keys Workflow
1. Admin creates a Subscription (dashboard Settings > Subscriptions or via CLI)
2. The subscription's `owner.groups` must match the user's OpenShift group
3. Users go to Gen AI studio > API keys, select their subscription, generate a key
4. Use the key: `curl -H "Authorization: Bearer <key>" https://maas.apps.<cluster>/...`

> **Important**: The user generating an API key must be a member of the subscription's owner group. If the user is `kube:admin`, add them directly to `spec.owner.users` (group membership doesn't work for virtual users with `:` in the name).

## Troubleshooting

### Gateway Returns 503 / API Keys Page Shows "Error loading components"
**Cause**: The `default-gateway-tls` secret doesn't exist, so the gateway's Envoy proxy never starts the HTTPS listener on port 443.

**Fix**: The toolkit now auto-creates this secret. If running manually:
```bash
# Option 1: Copy from existing wildcard cert
oc get secret cert-manager-ingress-cert -n openshift-ingress -o yaml \
  | sed 's/name: cert-manager-ingress-cert/name: default-gateway-tls/' \
  | oc apply -f -

# Option 2: Create via cert-manager
oc apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: default-gateway-tls
  namespace: openshift-ingress
spec:
  secretName: default-gateway-tls
  dnsNames: ["*.apps.<cluster-domain>"]
  issuerRef:
    name: <your-cluster-issuer>
    kind: ClusterIssuer
EOF
```

### "No subscriptions available" When Creating API Keys
**Cause**: The logged-in user is not in the subscription's owner group/users list.

**Fix**: Either add the user to the group, or patch the subscription:
```bash
oc patch maassubscription <name> -n models-as-a-service \
  --type=merge -p '{"spec":{"owner":{"users":["<username>"]}}}'
```

### Dashboard Missing "Publish as MaaS" Option
**Cause**: The `vLLMDeploymentOnMaaS` flag is not set in `OdhDashboardConfig`.

**Fix**: The toolkit sets this automatically. To set manually:
```bash
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
  --type=merge -p '{"spec":{"dashboardConfig":{"vLLMDeploymentOnMaaS":true}}}'
```

## Changes from 3.3

| Area | 3.3 | 3.4 |
|------|-----|-----|
| MaaS | Tech Preview (tier-based ConfigMaps) | **Core GA** (subscription CRDs, API keys, llm-d). Sub-features still TP: vLLM, OIDC, observability, external egress |
| MaaS TLS | cert-manager Certificate | **OpenShift service-ca** (annotate service, patch Authorino CR) |
| MaaS CRDs | N/A | MaaSSubscription, MaaSAuthPolicy, MaaSModelRef, Tenant, ExternalModel |
| MaaS Gateway | Basic | Requires `opendatahub.io/managed: "false"` + `authorino-tls-bootstrap: "true"` annotations |
| Dashboard flags | `modelAsService` | + `maasAuthPolicies`, `observabilityDashboard` (TP), `vLLMDeploymentOnMaaS` (TP) |
| RHCL | v1.1+ | **v1.2+** required (Subscription→`openshift-operators`, Kuadrant CR→`kuadrant-system` per RHOAI MaaS docs) |
| NeMo Guardrails | Tech Preview | **GA** |
| MLflow | Dashboard flag | **DSC component** (`mlflowoperator`) |
| MLServer | Tech Preview | **GA** |
| AutoML | N/A | **Tech Preview** |
| AutoRAG | N/A | **Tech Preview** |
| Install script | `install-rhoai-33.sh` | `install-rhoai-34.sh` |
| DSC manifest | `datasciencecluster-v3.yaml` | `datasciencecluster-v3-34.yaml` (API v2) |
| Channel | `stable-3.3` / `fast-3.x` | `stable-3.4` / `fast-3.x` |
