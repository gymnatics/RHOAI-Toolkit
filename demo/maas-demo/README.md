# MaaS Demo - Model as a Service on OpenShift AI

Interactive demos showcasing MaaS (Model as a Service) capabilities on Red Hat OpenShift AI.

## Quick Start - One Command Setup

```bash
# Deploy everything (infrastructure + model + web app)
./demo.sh

# Or non-interactive
./demo.sh -n maas-demo -m qwen3-4b

# Cleanup
./demo.sh --delete -n maas-demo
```

This single command will:
1. Setup infrastructure (LWS operator, TLS certificate)
2. Deploy the model (LLMInferenceService)
3. **Create tier testing resources** (groups, ServiceAccounts, tokens)
4. **Apply AuthPolicy fix for tier-based rate limiting** (automatic)
5. Apply TokenRateLimitPolicy for tier limits
6. Deploy the Streamlit web app with tier tokens injected
7. Print the URL to access the demo

---

## Directory Structure

```
maas-demo/
├── demo.sh                # ⭐ Full setup - run this!
├── setup-demo-model.sh    # Deploy model only
├── deploy-app.sh          # Deploy app only
├── run-demo.sh            # Run Streamlit locally
├── demo-maas.sh           # CLI interactive demo
├── app.py                 # Streamlit web app
├── requirements.txt       # Python dependencies
├── lib/                   # Reusable bash functions
│   ├── common.sh          # Colors, logging, utilities
│   ├── infrastructure.sh  # LWS, TLS, gateway setup
│   ├── model-catalog.sh   # Available models
│   ├── model-discovery.sh # Find deployed models
│   └── tiers.sh           # Tier management (groups, SAs, tokens)
└── manifests/             # Kubernetes YAML templates
    ├── llminferenceservice.yaml  # Model deployment
    ├── lws-operator.yaml         # LeaderWorkerSet operator
    ├── deployment.yaml           # Streamlit app deployment
    ├── service.yaml              # Service
    ├── route.yaml                # OpenShift route
    ├── serviceaccount.yaml       # ServiceAccount
    └── rolebinding.yaml          # RBAC
```

---

## Individual Scripts

### `demo.sh` - Full Setup (Recommended)

```bash
./demo.sh [options]

Options:
  -n, --namespace NS   Namespace (default: maas-demo)
  -m, --model KEY      Model (default: qwen3-4b)
  --app-only           Only deploy app (model must exist)
  --skip-app           Only deploy model
  --delete             Delete entire demo
```

### `setup-demo-model.sh` - Model Only

```bash
./setup-demo-model.sh -n maas-demo -m qwen3-4b
./setup-demo-model.sh --list    # List available models
./setup-demo-model.sh --delete  # Delete model
```

### `deploy-app.sh` - App Only

```bash
./deploy-app.sh -n maas-demo -m maas-demo/qwen3-4b
./deploy-app.sh --delete -n maas-demo
```

### `run-demo.sh` - Run Locally

```bash
./run-demo.sh                    # Auto-detect settings
./run-demo.sh --namespace myns   # Specify namespace
./run-demo.sh --no-auto          # Manual config only
```

---

## Scripts

### `setup-demo-model.sh` - Deploy Model

Deploys an LLMInferenceService model with all infrastructure prerequisites.

```bash
./setup-demo-model.sh [options]

Options:
  -n, --namespace NS   Deploy to namespace NS
  -m, --model KEY      Model from catalog (qwen3-4b, llama-3.2-3b, etc)
  --no-auth            Disable authentication
  --delete             Delete model
  --list               List available models
```

**What it does:**
1. Checks RHOAI installation and LLMInferenceService CRD
2. Ensures LeaderWorkerSet operator is configured
3. Creates TLS certificate for gateway (if missing)
4. Deploys the selected model with GPU tolerations

### `deploy-app.sh` - Deploy Web App

Deploys the Streamlit demo app to your cluster.

```bash
./deploy-app.sh [options]

Options:
  -n, --namespace NS    Deploy to namespace NS
  -m, --model NS/NAME   Use model NS/NAME
  --delete              Remove deployment
```

**What it does:**
1. Creates ConfigMap with app code
2. Creates ServiceAccount with model access
3. Generates long-lived API token
4. Deploys Streamlit container
5. Creates Service and Route

### `run-demo.sh` - Run Locally

Runs the Streamlit app locally with auto-configuration.

```bash
./run-demo.sh [options]

Options:
  --no-auto             Disable auto-detection
  --namespace, -n NS    Specify namespace
  --model, -m NAME      Specify model name
  --no-token            Don't generate token
  --port, -p PORT       Streamlit port (default: 8501)
```

---

## Tier-Based Rate Limiting (RHOAI 3.3)

RHOAI 3.3 includes **built-in tier support** for MaaS access control. Tiers are based on **OpenShift groups**, not ServiceAccounts.

### Built-in Tiers (Demo Mode)

The demo uses **1-minute rate limit windows** for easy testing. Limits reset every minute.

| Tier | Groups | Rate Limit | Level |
|------|--------|------------|-------|
| 🆓 Free | `tier-free-users`, `system:authenticated` | 1,000 tokens/min | 0 |
| ⭐ Premium | `tier-premium-users`, `premium-group` | 5,000 tokens/min | 1 |
| 👑 Enterprise | `tier-enterprise-users`, `enterprise-group`, `admin-group` | 10,000 tokens/min | 2 |

> **Note**: For production, edit `manifests/tiers/tokenratelimitpolicy.yaml` to use `1h0m0s` windows with higher limits.

### How Tiers Work

1. **User Authentication** - Kubernetes TokenReview validates the bearer token
2. **Tier Resolution** - AuthPolicy calls `maas-api/v1/tiers/lookup` with user's groups
3. **Tier Injection** - The resolved tier is injected into `auth.identity.tier`
4. **Rate Limiting** - TokenRateLimitPolicy evaluates predicates like `auth.identity.tier == "free"`

### ⚠️ IMPORTANT: Enabling Tier-Based Rate Limiting

**By default, tier-based rate limiting does NOT work** due to multiple issues:

1. **AuthPolicy Override** - The `odh-model-controller` creates an AuthPolicy that overrides tier lookup
2. **TokenReview Limitation** - Kubernetes TokenReview doesn't return OpenShift groups, only system groups
3. **UI Policy Conflicts** - The RHOAI Dashboard UI creates individual TokenRateLimitPolicies per tier that override each other

**The demo scripts automatically apply ALL fixes**, including:

1. **Patching AuthPolicy** - Adds tier lookup metadata section
2. **Fixing tier-to-group-mapping** - Uses ServiceAccount usernames instead of OpenShift groups
3. **Including username in tier lookup** - Patches AuthPolicy body to send username with groups
4. **Cleaning up UI policies** - Deletes conflicting individual tier policies

If you deploy models manually, you must apply these fixes:

```bash
# 1. Apply the AuthPolicy with tier lookup
oc apply -f manifests/authpolicy-with-tier-lookup.yaml

# 2. Patch AuthPolicy to include username in tier lookup
oc patch authpolicy maas-default-gateway-authn -n openshift-ingress --type=merge -p '
{
  "spec": {
    "rules": {
      "metadata": {
        "matchedTier": {
          "http": {
            "body": {
              "expression": "{ \"groups\": auth.identity.user.groups + [auth.identity.user.username] }"
            }
          }
        }
      }
    }
  }
}'

# 3. Update tier-to-group-mapping to use SA usernames
# (See lib/tiers.sh fix_tier_to_group_mapping function)

# 4. Delete conflicting UI-created policies
oc delete tokenratelimitpolicy tier-free-token-rate-limits tier-premium-token-rate-limits tier-enterprise-token-rate-limits -n openshift-ingress --ignore-not-found

# 5. Apply our combined TokenRateLimitPolicy
oc apply -f manifests/tiers/tokenratelimitpolicy.yaml

# 6. Clear caches
oc rollout restart deployment/authorino -n kuadrant-system
oc rollout restart deployment/limitador-limitador -n kuadrant-system
```

See [MAAS-TIER-RATE-LIMITING-FIX.md](../../docs/guides/MAAS-TIER-RATE-LIMITING-FIX.md) for full details.

### Tier Configuration

Tiers are defined in the `tier-to-group-mapping` ConfigMap. **IMPORTANT**: For tier resolution to work correctly, the ConfigMap must use **ServiceAccount usernames** as group entries (not OpenShift group names), because Kubernetes TokenReview doesn't return OpenShift groups.

```bash
# View current configuration
oc get configmap tier-to-group-mapping -n redhat-ods-applications -o yaml
```

The demo scripts automatically configure this correctly using:
- `system:serviceaccount:<namespace>:tier-enterprise-sa` → Enterprise tier
- `system:serviceaccount:<namespace>:tier-premium-sa` → Premium tier  
- `system:serviceaccount:<namespace>:tier-free-sa` + `system:authenticated` → Free tier

### Tier Testing Setup (Automatic)

The demo scripts **automatically create** tier testing resources:

1. **OpenShift Groups**: `tier-free-users`, `tier-premium-users`, `tier-enterprise-users`
2. **ServiceAccounts**: `tier-free-sa`, `tier-premium-sa`, `tier-enterprise-sa`
3. **RBAC**: RoleBindings for model access
4. **Tokens**: Stored in `maas-tier-tokens` secret
5. **tier-to-group-mapping**: Updated to use SA usernames
6. **AuthPolicy**: Patched to include username in tier lookup

This allows you to test different tiers in the Streamlit app by selecting a tier from the dropdown.

```bash
# View created resources
oc get groups | grep tier
oc get serviceaccounts -n maas-demo | grep tier
oc get secret maas-tier-tokens -n maas-demo

# Generate tokens manually
oc create token tier-free-sa -n maas-demo --duration=1h --audience=https://kubernetes.default.svc
oc create token tier-premium-sa -n maas-demo --duration=1h --audience=https://kubernetes.default.svc
oc create token tier-enterprise-sa -n maas-demo --duration=1h --audience=https://kubernetes.default.svc
```

### Assigning Real Users to Tiers

For production use, add users to tier groups:

```bash
# Create tier groups (if they don't exist)
oc adm groups new tier-premium-users
oc adm groups new tier-enterprise-users

# Add user to Premium tier
oc adm groups add-users tier-premium-users <username>

# Add user to Enterprise tier
oc adm groups add-users tier-enterprise-users <username>

# Check user's groups
oc get groups | grep <username>
```

### Configuring Rate Limits

Rate limits are enforced via `TokenRateLimitPolicy`:

```yaml
apiVersion: kuadrant.io/v1alpha1
kind: TokenRateLimitPolicy
metadata:
  name: maas-tier-token-rate-limits
  namespace: openshift-ingress
spec:
  targetRef:
    kind: Gateway
    name: maas-default-gateway
  limits:
    free-tokens:
      rates:
        - limit: 10000
          window: 1h0m0s
      when:
        - predicate: 'auth.identity.tier == "free" && !request.path.endsWith("/v1/models")'
      counters:
        - expression: auth.identity.userid
    premium-tokens:
      rates:
        - limit: 50000
          window: 1h0m0s
      when:
        - predicate: 'auth.identity.tier == "premium" && !request.path.endsWith("/v1/models")'
      counters:
        - expression: auth.identity.userid
    enterprise-tokens:
      rates:
        - limit: 100000
          window: 1h0m0s
      when:
        - predicate: 'auth.identity.tier == "enterprise" && !request.path.endsWith("/v1/models")'
      counters:
        - expression: auth.identity.userid
```

### Testing Rate Limits

```bash
# Generate a token
TOKEN=$(oc create token default -n maas-demo --audience="https://kubernetes.default.svc" --duration=1h)

# Make requests until rate limited (HTTP 429)
for i in {1..5}; do
  curl -sk "https://inference-gateway.apps.../maas-demo/qwen3-4b/v1/chat/completions" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"model":"qwen3-4b","messages":[{"role":"user","content":"Hi"}],"max_tokens":30}' \
    -w "\nHTTP: %{http_code}\n"
done
```

---

## Model Catalog

Available models in `lib/model-catalog.sh`:

| Key | Model | Tool Parser |
|-----|-------|-------------|
| `qwen3-4b` | Qwen3-4B | hermes |
| `llama-3.2-3b` | Llama 3.2-3B Instruct | llama3_json |
| `mistral-7b` | Mistral-7B Instruct | mistral |
| `granite-3.2-8b` | Granite 3.2-8B Instruct | hermes |

---

## Library Functions

### `lib/common.sh`

Core utilities:
- `print_header`, `print_step`, `print_success`, `print_error`
- `check_oc_login` - Verify OpenShift login
- `get_cluster_domain` - Get cluster domain
- `get_rhoai_version` - Get RHOAI version
- `apply_manifest` - Apply YAML with envsubst
- `generate_maas_token` - Generate token with correct audience

### `lib/infrastructure.sh`

Infrastructure setup:
- `ensure_lws_crd` - Setup LeaderWorkerSet operator
- `ensure_gateway_tls` - Create TLS certificate
- `check_maas_gateway` - Verify gateway status
- `check_gpu_nodes` - Verify GPU nodes
- `check_rhoai` - Verify RHOAI installation

### `lib/model-discovery.sh`

Model discovery:
- `get_all_models` - List all LLMInferenceServices
- `get_ready_models` - List ready models
- `list_models` - Display models with status
- `select_model` - Interactive model selection

### `lib/model-catalog.sh`

Model catalog:
- `list_catalog_models` - Show available models
- `get_model_info` - Get model details
- `parse_model_info` - Parse into variables
- `select_catalog_model` - Interactive selection

---

## Manifests

YAML templates in `manifests/` use `envsubst` for variable substitution:

| Variable | Description |
|----------|-------------|
| `${MODEL_NAME}` | Model name (e.g., qwen3-4b) |
| `${MODEL_DISPLAY_NAME}` | Human-readable name |
| `${MODEL_URI}` | OCI image URI |
| `${MODEL_NAMESPACE}` | Model namespace |
| `${APP_NAMESPACE}` | App deployment namespace |
| `${MAAS_ENDPOINT}` | Gateway endpoint |
| `${AUTH_ENABLED}` | Enable authentication |
| `${TOOL_PARSER}` | vLLM tool parser |

---

## Web Demo Features

### Auto-Configuration

When logged in via `oc`:
- **Auto-Detect Button**: Detects endpoint, namespace, models
- **Gen Token Button**: Generates token with correct audience
- **Model Dropdown**: Shows all ready LLMInferenceServices

### Sidebar
- Connection settings (endpoint, token)
- Model settings (namespace, model, API mode)
- Parameters (temperature, max tokens, streaming)

### Main Area
- **Chat Tab**: Interactive chat interface
- **Comparison Tab**: Multi-model comparison
- **Metrics Tab**: Response time, token usage

---

## API Examples

### RHOAI 3.3+ (Path-Based Routing)

```bash
# Generate token
TOKEN=$(oc create token default -n maas-demo --duration=1h --audience=https://kubernetes.default.svc)

# Chat completion
curl -sk https://inference-gateway.apps.cluster.example.com/maas-demo/qwen3-4b/v1/chat/completions \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen3-4b", "messages": [{"role": "user", "content": "Hello!"}]}'
```

---

## Troubleshooting

### "MaaS endpoint not found"
- Check MaaS is enabled in DataScienceCluster
- Verify gateway exists: `oc get gateway -n openshift-ingress`

### "Unauthorized" errors
- Token may be expired
- Check token audience: must be `https://kubernetes.default.svc` for RHOAI 3.3+

### "Model not found"
- Check model is ready: `oc get llminferenceservice -A`
- Verify namespace/model in API path

### Pod stuck in Pending
- Check GPU tolerations in manifest
- Verify GPU nodes available: `oc get nodes -l nvidia.com/gpu.present=true`

### LeaderWorkerSet errors
- Run `./setup-demo-model.sh` to auto-configure LWS operator
- Or manually: `oc apply -f manifests/lws-operator.yaml`

---

## Cleanup

```bash
# Remove model
./setup-demo-model.sh --delete -n maas-demo

# Remove app
./deploy-app.sh --delete -n maas-demo

# Remove namespace
oc delete project maas-demo
```
