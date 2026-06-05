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

---

## Installation Steps

The `install-rhoai-34.sh` script performs these steps in order. Each section includes the manual CLI commands if you need to run them by hand.

### 1. Prerequisites Check

- Verifies `oc` CLI, cluster login, cluster-admin
- Checks OCP version >= 4.19 (warns if < 4.20 for llm-d)

### 2. Node Scaling

- Scales workers to >= 2
- Creates GPU MachineSet (g6e.xlarge) if none exists

### 3. Prerequisite Operators

These operators must be installed before RHOAI. They provide GPU scheduling, certificate management, and multi-node inference support.

| Operator | Namespace | Purpose for MaaS |
|----------|-----------|-------------------|
| Node Feature Discovery (NFD) | `openshift-nfd` | Detects GPU hardware on nodes |
| NVIDIA GPU Operator | `nvidia-gpu-operator` | GPU drivers, device plugin, monitoring |
| Kueue | `openshift-operators` | Workload scheduling and quota management |
| cert-manager | `cert-manager-operator` | TLS certs for Kueue, LWS, and gateway HTTPS listener |
| LeaderWorkerSet (LWS) | `openshift-lws-operator` | Multi-node inference for llm-d |

<details>
<summary><b>Manual Commands</b></summary>

```bash
# Each operator: create Namespace, OperatorGroup, Subscription
# Example for cert-manager:
oc create namespace cert-manager-operator
oc apply -f lib/manifests/operators/certmanager-operatorgroup.yaml
oc apply -f lib/manifests/operators/certmanager-subscription.yaml

# Wait for each operator CSV to reach Succeeded:
oc get csv -n cert-manager-operator -w
```
</details>

### 4. RHCL (Red Hat Connectivity Link) + Service Mesh

RHCL provides Authorino (authentication) and rate limiting for the MaaS gateway. Service Mesh 3.x (Sail/Istio) is auto-installed as an OLM dependency of the RHOAI operator.

| Resource | Namespace | Why |
|----------|-----------|-----|
| RHCL Subscription | `openshift-operators` | AllNamespaces install mode (OLM requirement) |
| Kuadrant CR | `kuadrant-system` | Creates Authorino, Limitador in dedicated ns |
| Authorino | `kuadrant-system` | Auto-created by Kuadrant CR |
| Service Mesh (Sail) | `openshift-ingress` | Auto-installed as RHOAI OLM dependency |

> **Warning:** OLM may set InstallPlan approval to Manual for RHCL dependencies. The toolkit auto-approves pending InstallPlans for RHCL, Service Mesh, and Sail operators.

<details>
<summary><b>Manual Commands</b></summary>

```bash
# 1. Install RHCL operator
oc apply -f lib/manifests/rhcl/rhcl-operator-34.yaml

# 2. Approve any pending InstallPlans
oc get installplan -n openshift-operators
oc patch installplan <name> -n openshift-operators \
  --type=merge -p '{"spec":{"approved":true}}'

# 3. Wait for RHCL CSV
oc get csv -n openshift-operators | grep rhcl

# 4. Create Kuadrant CR in kuadrant-system
oc create namespace kuadrant-system
oc apply -f - <<EOF
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
spec: {}
EOF

# Wait for Authorino:
oc get pods -n kuadrant-system -w
```
</details>

### 5. Inference Gateways + TLS

Two gateways are created: one for MaaS API traffic and one for direct model inference. Both need a TLS secret and passthrough Routes.

| Gateway | Hostname | Purpose |
|---------|----------|---------|
| `maas-default-gateway` | `maas.apps.<cluster>` | MaaS API + model endpoints (Authorino auth) |
| `openshift-ai-inference` | `inference-gateway.apps.<cluster>` | Direct llm-d model access |

> **Warning — `default-gateway-tls` Secret:**
> The gateways reference a TLS secret that is **NOT auto-created** by any operator. Without it, Envoy never starts port 443 and all traffic returns 503. The toolkit uses cert-manager to issue a proper wildcard Certificate CR (auto-renewed). Fallback: copy an existing wildcard cert or use router-ca.

> **Note — Passthrough Routes:**
> `*.apps.<cluster>` DNS points to the default OpenShift Router, not to the gateway LoadBalancers. Passthrough Routes bridge the two.

<details>
<summary><b>Manual Commands</b></summary>

```bash
# 1. Create GatewayClass
oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-gateway-controller
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF

# 2. Create maas-default-gateway (with required annotations)
oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: maas-default-gateway
  namespace: openshift-ingress
  annotations:
    opendatahub.io/managed: "false"
    security.opendatahub.io/authorino-tls-bootstrap: "true"
spec:
  gatewayClassName: openshift-gateway-controller
  listeners:
    - allowedRoutes:
        namespaces:
          from: All
      hostname: maas.apps.CLUSTER_DOMAIN
      name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - kind: Secret
            name: default-gateway-tls
        mode: Terminate
EOF

# 3. Create TLS secret via cert-manager Certificate CR (recommended)
#    Requires cert-manager operator + a ClusterIssuer (e.g. letsencrypt, selfsigned)
oc apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: default-gateway-tls
  namespace: openshift-ingress
spec:
  secretName: default-gateway-tls
  duration: 2160h    # 90 days
  renewBefore: 360h  # renew 15 days before expiry
  commonName: "apps.CLUSTER_DOMAIN"
  dnsNames:
    - "apps.CLUSTER_DOMAIN"
    - "*.apps.CLUSTER_DOMAIN"
  issuerRef:
    name: YOUR_CLUSTER_ISSUER   # e.g. letsencrypt-prod
    kind: ClusterIssuer
  usages:
    - server auth
    - client auth
EOF

# Wait for cert-manager to issue the cert and create the secret:
oc get certificate default-gateway-tls -n openshift-ingress -w
oc get secret default-gateway-tls -n openshift-ingress

# Fallback: if no cert-manager ClusterIssuer, copy existing wildcard cert:
# oc get secret cert-manager-ingress-cert -n openshift-ingress -o yaml \
#   | sed 's/name: cert-manager-ingress-cert/name: default-gateway-tls/' \
#   | oc apply -f -

# 4. Create passthrough Route
GW_SVC=$(oc get svc -n openshift-ingress \
  -l gateway.networking.k8s.io/gateway-name=maas-default-gateway \
  -o jsonpath='{.items[0].metadata.name}')
oc create route passthrough maas-default-gateway-passthrough \
  --service=$GW_SVC --port=443 \
  --hostname=maas.apps.CLUSTER_DOMAIN \
  -n openshift-ingress

# 5. Test gateway
curl -sk https://maas.apps.CLUSTER_DOMAIN/health
```
</details>

### 6. User Workload Monitoring

- Enables Prometheus user workload monitoring (required for MaaS Tenant to report Ready)

### 7. RHOAI Operator

- Interactive channel selection (or `--channel stable-3.4`)
- Creates operator subscription

<details>
<summary><b>Manual Commands</b></summary>

```bash
# Install RHOAI operator (channel: stable-3.4)
oc apply -f lib/manifests/rhoai/rhoai-subscription.yaml

# Wait for CSV
oc get csv -n redhat-ods-operator -w
```
</details>

### 8. DataScienceCluster

Applies `datasciencecluster-v3-34.yaml` (API v2) with all components enabled.

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

<details>
<summary><b>Manual Commands</b></summary>

```bash
# Create DataScienceCluster (API v2)
oc apply -f lib/manifests/rhoai/datasciencecluster-v3-34.yaml
# Key: spec.components.kserve.modelsAsService.managementState: Managed
```
</details>

### 9. MaaS TLS Configuration (Authorino)

RHOAI 3.4 uses OpenShift service-ca for Authorino TLS (not cert-manager). This configures internal auth filter TLS between the gateway Envoy and Authorino.

| Step | What It Does |
|------|-------------|
| Annotate Authorino service | Triggers service-ca to generate `authorino-server-cert` secret |
| Patch Authorino CR | Enables TLS listener with the generated cert |
| Set env vars on Authorino | `SSL_CERT_FILE` + `REQUESTS_CA_BUNDLE` for CA validation |
| Annotate gateway | `authorino-tls-bootstrap=true` creates EnvoyFilter for TLS |

<details>
<summary><b>Manual Commands</b></summary>

```bash
# 1. Annotate Authorino service for service-ca cert
oc annotate service authorino-authorino-authorization \
  -n kuadrant-system \
  service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
  --overwrite

# 2. Patch Authorino CR for TLS listener
oc patch authorino authorino -n kuadrant-system --type=merge --patch '{
  "spec": {
    "listener": {
      "tls": {
        "enabled": true,
        "certSecretRef": {"name": "authorino-server-cert"}
      }
    }
  }
}'

# 3. Set TLS env vars
oc -n kuadrant-system set env deployment/authorino \
  SSL_CERT_FILE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt \
  REQUESTS_CA_BUNDLE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt

# 4. Annotate gateway
oc annotate gateway maas-default-gateway -n openshift-ingress \
  security.opendatahub.io/authorino-tls-bootstrap="true" --overwrite
```
</details>

### 10. MaaS PostgreSQL Setup

MaaS requires PostgreSQL 14+ for API key validation. The script handles this automatically:
- **No `--postgres-connection` flag**: Deploys a POC PostgreSQL (5Gi PVC, not production-grade) in `redhat-ods-applications`
- **With `--postgres-connection`**: Creates the secret from your external database URL
- **With `--skip-maas-db`**: Skips entirely (you manage the secret yourself)

The secret format is a single connection URL:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: maas-db-config
  namespace: redhat-ods-applications
type: Opaque
stringData:
  DB_CONNECTION_URL: "postgresql://user:pass@host:5432/db?sslmode=require"
```

For production, use AWS RDS, Crunchy Postgres Operator, or Azure Database for PostgreSQL.

<details>
<summary><b>Manual Commands (POC PostgreSQL)</b></summary>

```bash
oc new-app postgresql:14 \
  -e POSTGRESQL_USER=maas \
  -e POSTGRESQL_PASSWORD=maas \
  -e POSTGRESQL_DATABASE=maas \
  -n redhat-ods-applications

oc create secret generic maas-db-config \
  --from-literal=DB_CONNECTION_URL='postgresql://maas:maas@postgresql:5432/maas?sslmode=disable' \
  -n redhat-ods-applications
```
</details>

### 11. Dashboard Configuration

Several feature flags in `OdhDashboardConfig` must be enabled for MaaS features to appear in the UI.

| Flag | Value | What It Enables |
|------|-------|-----------------|
| `modelAsService` | `true` | MaaS section in Gen AI studio |
| `maasAuthPolicies` | `true` | Authorization Policies page |
| `vLLMDeploymentOnMaaS` | `true` | Non-legacy deployment + Publish as MaaS |
| `genAiStudio` | `true` | Gen AI studio top-level menu |
| `disableModelCatalog` | `false` | Model Catalog page |

> **Warning —** `vLLMDeploymentOnMaaS`**:** This flag is critical. Without it, the dashboard only shows the legacy InferenceService path, and there is no option to publish models to MaaS.

<details>
<summary><b>Manual Command</b></summary>

```bash
oc patch odhdashboardconfig odh-dashboard-config \
  -n redhat-ods-applications --type=merge -p '{
  "spec": {
    "dashboardConfig": {
      "genAiStudio": true,
      "modelAsService": true,
      "maasAuthPolicies": true,
      "vLLMDeploymentOnMaaS": true,
      "disableModelRegistry": false,
      "disableModelCatalog": false,
      "disableKServeMetrics": false,
      "disableLMEval": false
    }
  }
}'
```
</details>

### 12. Deploy a Model + Publish to MaaS

Deploy using `LLMInferenceService` (NOT legacy `InferenceService`), then register it with MaaS via `MaaSModelRef`.

| CRD | API Group | Use |
|-----|-----------|-----|
| `LLMInferenceService` | `serving.kserve.io/v1alpha2` | MaaS-compatible (llm-d) |
| `InferenceService` | `serving.kserve.io/v1beta1` | Legacy (NOT MaaS compatible) |
| `MaaSModelRef` | `maas.opendatahub.io/v1alpha1` | Registers model with gateway |

<details>
<summary><b>Manual Commands</b></summary>

```bash
# 1. Deploy model with LLMInferenceService
oc apply -f - <<EOF
apiVersion: serving.kserve.io/v1alpha2
kind: LLMInferenceService
metadata:
  name: qwen3-8b
  namespace: 0-demo
spec:
  model:
    uri: oci://registry.redhat.io/rhelai/modelcar-qwen3-8b-fp8-dynamic:15
  replicas: 1
EOF

# 2. Wait for model to be Ready
oc get llminferenceservices -n 0-demo -w

# 3. Publish to MaaS
oc apply -f - <<EOF
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSModelRef
metadata:
  name: qwen3-8b
  namespace: 0-demo
spec:
  modelRef:
    kind: LLMInferenceService
    name: qwen3-8b
EOF

oc get maasmodelrefs -n 0-demo -w
```
</details>

<details>
<summary><b>Toolkit Automation</b></summary>

The interactive deployment wizard handles MaaS publishing automatically:

```bash
# Interactive wizard — prompts for MaaS mode + publish on RHOAI 3.4+
source lib/functions/model-deployment.sh
deploy_model_interactive

# Or use serve-model.sh with MAAS_PUBLISH flag
MAAS_PUBLISH=true ./scripts/serve-model.sh oci qwen3-4b \
  oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b

# Publish an already-deployed LLMInferenceService to MaaS
source lib/functions/model-deployment.sh
publish_model_to_maas <model-name> <namespace>
```

The `publish_model_to_maas` function creates all three required CRs:
1. `MaaSModelRef` — registers model with the MaaS gateway
2. `MaaSSubscription` — defines group access + token rate limits
3. `MaaSAuthPolicy` — grants gateway authorization

</details>

### 13. Subscriptions, Auth Policies, and API Keys

Users belong to groups, groups get subscriptions with token limits, and API keys are scoped to subscriptions.

**Request Flow:**

| Step | Component | What Happens |
|------|-----------|-------------|
| 1 | Client | `curl` with `Authorization: Bearer <api-key>` |
| 2 | OpenShift Router | Passthrough Route forwards to gateway |
| 3 | Gateway Envoy | TLS termination, ext_authz to Authorino |
| 4 | Authorino | Validates API key via PostgreSQL, checks MaaSAuthPolicy |
| 5 | Gateway Envoy | TokenRateLimitPolicy enforces limits |
| 6 | Model Pod | Request routed via HTTPRoute |

<details>
<summary><b>Manual Commands</b></summary>

```bash
# 1. Create user group
oc adm groups new rhods-users
oc adm groups add-users rhods-users user1 user2 user3

# 2. Create MaaS Subscription
oc apply -f - <<EOF
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSSubscription
metadata:
  name: team-sub
  namespace: models-as-a-service
spec:
  modelRefs:
    - name: qwen3-8b
      namespace: 0-demo
      tokenRateLimits:
        - limit: 10000
          window: 5m
  owner:
    groups:
      - name: rhods-users
  priority: 1
EOF

# 3. Create MaaS Authorization Policy
oc apply -f - <<EOF
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSAuthPolicy
metadata:
  name: team-auth
  namespace: models-as-a-service
spec:
  modelRefs:
    - name: qwen3-8b
      namespace: 0-demo
  subjects:
    groups:
      - name: rhods-users
EOF

# 4. Generate API Key via dashboard:
#    Gen AI studio > API keys > Create API key
#    Select subscription, set expiration

# 5. Test
curl -sk https://maas.apps.CLUSTER/0-demo/qwen3-8b/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3-8b","messages":[{"role":"user","content":"Hello"}]}'
```
</details>

### 14. MaaS Rate Limiting Fixes

Token rate limiting in MaaS silently fails under load due to the Kuadrant WasmPlugin's internal span buffer (capacity: 100) being saturated by health check traffic. The toolkit applies three fixes automatically:

| Fix | What It Does |
|-----|-------------|
| Redis-cached Limitador storage | Persistent counters (survive restarts), faster gRPC responses |
| Health check interceptor EnvoyFilter | Prevents `/healthz` and `/ready` probes from filling the span buffer |
| Ratelimit cluster timeout EnvoyFilter | Increases Limitador gRPC timeout from ~100ms to 2s |

> **Warning:** Without these fixes, `MaaSSubscription` token rate limits (e.g. 10,000 tokens/hour) are never enforced — requests that should return HTTP 429 are allowed through indefinitely.

<details>
<summary><b>Manual Commands</b></summary>

```bash
# 1. Deploy Redis
oc apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: limitador-redis
  namespace: kuadrant-system
  labels:
    app: limitador-redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: limitador-redis
  template:
    metadata:
      labels:
        app: limitador-redis
    spec:
      containers:
      - name: redis
        image: registry.redhat.io/rhel9/redis-7:latest
        ports:
        - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: limitador-redis
  namespace: kuadrant-system
spec:
  selector:
    app: limitador-redis
  ports:
  - port: 6379
    targetPort: 6379
EOF

# 2. Create Redis secret and patch Limitador
oc create secret generic limitador-redis-config \
  --from-literal=URL="redis://limitador-redis.kuadrant-system.svc.cluster.local:6379" \
  -n kuadrant-system

oc patch limitador limitador -n kuadrant-system --type=merge -p '{
  "spec": {
    "storage": {
      "redis-cached": {
        "configSecretRef": {"name": "limitador-redis-config"},
        "options": {"flush-period": 500, "max-cached": 10000, "batch-size": 100, "response-timeout": 500}
      }
    }
  }
}'

# 3. Health check interceptor
oc apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: healthcheck-filter
  namespace: openshift-ingress
spec:
  workloadSelector:
    labels:
      gateway.networking.k8s.io/gateway-name: maas-default-gateway
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
      patch:
        operation: INSERT_FIRST
        value:
          name: envoy.filters.http.health_check
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.health_check.v3.HealthCheck
            pass_through_mode: false
            headers:
              - name: ":path"
                string_match:
                  exact: "/healthz"
              - name: ":path"
                string_match:
                  exact: "/ready"
EOF

# 4. Ratelimit cluster timeout
oc apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: increase-ratelimit-cluster-timeout
  namespace: openshift-ingress
spec:
  workloadSelector:
    labels:
      gateway.networking.k8s.io/gateway-name: maas-default-gateway
  configPatches:
    - applyTo: CLUSTER
      match:
        context: GATEWAY
        cluster:
          name: kuadrant-ratelimit-service
      patch:
        operation: MERGE
        value:
          connect_timeout: 2s
EOF

# 5. Restart gateway
oc rollout restart deployment/maas-default-gateway-openshift-gateway-controller -n openshift-ingress

# 6. Verify
oc logs deployment/maas-default-gateway-openshift-gateway-controller \
  -n openshift-ingress --since=5m | grep -c "Span buffer full"
# Should be 0 or very low
```
</details>

> **See also:** `docs/maas-token-ratelimit-span-buffer-bug.md` for the full root cause analysis.

### 15. MaaS Verification

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

---

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

---

## Troubleshooting

| Problem | Root Cause | Fix |
|---------|-----------|-----|
| Gateway returns 503 | `default-gateway-tls` secret missing | Create TLS secret via cert-manager or copy wildcard cert |
| API Keys page: Error loading | maas-ui can't reach gateway URL | Create passthrough Route from Router to gateway |
| No "Publish as MaaS" option | `vLLMDeploymentOnMaaS` not set | Patch `OdhDashboardConfig` |
| No subscriptions for API key | User not in owner group | Add user to group or patch `spec.owner.users` |
| RHCL operator stuck | OLM set InstallPlan to Manual | Auto-approve pending InstallPlans |
| MLflow unavailable | No MLflow CR created | Create MLflow CR with sqlite + PVC |


### API Keys Page Shows "Error loading components"
**Cause**: When no subscriptions are created, there is a bug that shows Error rather than the API Keys page. To fix this, add a subscription.

### Gateway Returns 503 / API Keys Page Shows "Error loading components"
**Cause**: The `default-gateway-tls` secret doesn't exist, so the gateway's Envoy proxy never starts the HTTPS listener on port 443.

**Fix**: The toolkit now auto-creates this secret using cert-manager (preferred). If running manually:
```bash
# Recommended: Create via cert-manager Certificate CR (auto-renewed)
oc apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: default-gateway-tls
  namespace: openshift-ingress
spec:
  secretName: default-gateway-tls
  duration: 2160h
  renewBefore: 360h
  commonName: "apps.<cluster-domain>"
  dnsNames:
    - "apps.<cluster-domain>"
    - "*.apps.<cluster-domain>"
  issuerRef:
    name: <your-cluster-issuer>
    kind: ClusterIssuer
  usages:
    - server auth
    - client auth
EOF

# Verify cert is issued:
oc get certificate default-gateway-tls -n openshift-ingress
oc get secret default-gateway-tls -n openshift-ingress

# Fallback: Copy from existing wildcard cert (no auto-renewal)
# oc get secret cert-manager-ingress-cert -n openshift-ingress -o yaml \
#   | sed 's/name: cert-manager-ingress-cert/name: default-gateway-tls/' \
#   | oc apply -f -
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

---

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
