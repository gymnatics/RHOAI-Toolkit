# Banking Feature Store Demo

A complete Feature Store demo using Feast on OpenShift AI, showcasing banking/financial features for ML models.

## What This Demo Shows

This demo deploys a banking feature store with:
- **Customer Demographics** - Age, income, account tenure
- **Transaction Aggregations** - 7-day, 30-day, 90-day summaries
- **ATM Usage Patterns** - Withdrawal frequency, amounts
- **Branch Performance** - Transaction volumes, wait times
- **Call Center Analytics** - Call frequency, resolution rates
- **Risk Scoring** - On-demand feature computation

---

## Quick Start

### Option 1: Deploy via Toolkit (Recommended)

```bash
./rhoai-toolkit.sh
# Navigate to: RHOAI Management → Demos → Deploy Banking Demo (Feast)
```

The toolkit automatically:
- Detects your RHOAI version (3.2 vs 3.3+)
- Applies correct labels for dashboard visibility
- Enables restAPI for the registry
- Patches the Feast RBAC `permissions.py` namespace mismatch (see [RBAC Gotcha](#rbac-gotcha-permissionspy-namespace-mismatch) below) - no fork needed
- Runs `feast apply` and `feast materialize`

### Option 2: Deploy via Manifest

```bash
# Create namespace with required label
oc new-project feast-demo
oc label namespace feast-demo opendatahub.io/dashboard=true

# Apply the FeatureStore CR
oc apply -f lib/manifests/feast/featurestore-banking-demo.yaml -n feast-demo

# Wait for pod
oc wait --for=condition=Ready pod -l feast.dev/name=banking -n feast-demo --timeout=300s

# Get pod name
FEAST_POD=$(oc get pods -n feast-demo -l feast.dev/name=banking -o jsonpath='{.items[0].metadata.name}')

# Apply feature definitions
oc exec -n feast-demo $FEAST_POD -c registry -- feast apply

# Materialize features (backfill historical data)
oc exec -n feast-demo $FEAST_POD -c registry -- feast materialize 2025-01-01T00:00:00 $(date -u +'%Y-%m-%dT%H:%M:%S')
```

---

## Manual Implementation

### Step 1: Create Namespace with Labels

```bash
# Create namespace
oc new-project feast-demo

# Add required label for RHOAI dashboard visibility
oc label namespace feast-demo opendatahub.io/dashboard=true
```

### Step 2: Enable Feast Operator (if not enabled)

```bash
# Check if Feast operator is enabled
oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.feastoperator.managementState}'

# Enable if needed
oc patch datasciencecluster default-dsc --type=merge \
  -p '{"spec":{"components":{"feastoperator":{"managementState":"Managed"}}}}'
```

### Step 3: Create FeatureStore CR

```yaml
apiVersion: feast.dev/v1alpha1
kind: FeatureStore
metadata:
  name: banking
  labels:
    feature-store-ui: enabled              # Required for RHOAI 3.3+ dashboard
    opendatahub.io/dashboard: "true"       # Required for RHOAI 3.3+ dashboard
spec:
  feastProject: banking
  feastProjectDir:
    git:
      ref: rbac
      url: 'https://github.com/RHRolun/banking-feature-store'
  services:
    offlineStore:
      server:
        logLevel: debug
    onlineStore:
      server:
        logLevel: debug
    registry:
      local:
        server:
          restAPI: true                    # Required for RHOAI 3.3+ dashboard
```

### Step 4: Fix the RBAC Namespace Mismatch, Then Apply Feature Definitions

```bash
# Get the feast pod
FEAST_POD=$(oc get pods -n feast-demo -l feast.dev/name=banking -o jsonpath='{.items[0].metadata.name}')

# Patch permissions.py so its NamespaceBasedPolicy matches your actual
# namespace instead of the upstream repo's hardcoded "banking" project name
# (see "RBAC Gotcha" below for why this is necessary). Skip this if you
# deployed via the toolkit - it does this automatically.
oc exec -n feast-demo $FEAST_POD -c registry -- \
  sed -i 's/prod_namespaces = \[.*\]/prod_namespaces = ["feast-demo"]/' \
  /feast-data/banking/feature_repo/permissions.py

# Apply feature definitions from the git repo
oc exec -n feast-demo $FEAST_POD -c registry -- feast apply
```

### Step 5: Materialize Features

```bash
# Backfill features from historical data
oc exec -n feast-demo $FEAST_POD -c registry -- \
  feast materialize 2025-01-01T00:00:00 $(date -u +'%Y-%m-%dT%H:%M:%S')
```

---

## RHOAI Version Compatibility

### RHOAI 3.2
Works with basic FeatureStore CR. Dashboard visibility is automatic.

### RHOAI 3.3+
Requires additional configuration for dashboard visibility:

| Requirement | How to Set |
|-------------|------------|
| `feature-store-ui: enabled` label | In FeatureStore metadata.labels |
| `opendatahub.io/dashboard: "true"` label | In FeatureStore metadata.labels |
| `restAPI: true` | In spec.services.registry.local.server |
| Namespace label | `oc label ns <ns> opendatahub.io/dashboard=true` |

### Fix Visibility After 3.2→3.3 Upgrade

If your FeatureStore disappears from the dashboard after upgrading:

```bash
# Add required labels
oc label featurestore banking -n feast-demo feature-store-ui=enabled --overwrite
oc label featurestore banking -n feast-demo opendatahub.io/dashboard=true --overwrite

# Enable restAPI
oc patch featurestore banking -n feast-demo --type=merge \
  -p '{"spec":{"services":{"registry":{"local":{"server":{"restAPI":true}}}}}}'

# Label namespace
oc label namespace feast-demo opendatahub.io/dashboard=true --overwrite
```

Or use the toolkit's diagnose feature:
```bash
./rhoai-toolkit.sh
# → RHOAI Management → AI Services & Infrastructure → Feature Store Management → Diagnose Feature Store
```

### RBAC Gotcha: permissions.py Namespace Mismatch

**Symptom:** All the checks above pass (labels correct, `restAPI: true`, namespace labeled, `registry` and `registry-rest` services exist, pod `Running`) but the FeatureStore *still* doesn't show up in the dashboard.

**Root cause:** `feature_repo/permissions.py` in the upstream repo (`RHRolun/banking-feature-store`, branch `rbac`) defines:

```python
prod_namespaces = ["banking"]

all_resources = Permission(
    name="all_resources",
    types=ALL_RESOURCE_TYPES,
    policy=NamespaceBasedPolicy(namespaces=prod_namespaces),
    actions=[AuthzedAction.DESCRIBE] + READ
)
```

`NamespaceBasedPolicy` checks `prod_namespaces` against the **OpenShift namespace** you're deployed into - but `"banking"` here is actually the **Feast project name**, not a namespace. Unless you deploy into a namespace literally named `banking`, every registry `DESCRIBE`/list call gets denied with `Permission all_resources denied ... User is not added into the permitted namespaces`, and the dashboard's feature-store discovery (which calls the registry's REST API) silently returns an empty list.

You can confirm this is the cause by checking the `registry` container's logs for that exact error, or by querying the registry directly:
```bash
FEAST_POD=$(oc get pods -n <namespace> -l feast.dev/name=banking -o jsonpath='{.items[0].metadata.name}')
oc logs -n <namespace> $FEAST_POD -c registry --tail=50 | grep "permitted namespaces"
```

**Fix:** Deploying via the toolkit (`rhoai-toolkit.sh` → `deploy_banking_demo`) or running `Diagnose Feature Store` → automatic fixes now handles this automatically (`check_featurestore_rbac_namespace` / `fix_featurestore_rbac_namespace` in `lib/utils/rhoai-version.sh`) by patching the already-cloned repo checkout on the `feast-data` PVC in place and re-running `feast apply` - no git fork/push required. If you're applying the manifest manually (Option 2), see Step 4 above.

This in-place patch persists across normal pod restarts (it lives on the PVC), but will be reverted if the PVC is ever wiped and `feast-init` re-clones from the upstream repo (it only clones if `feature_repo` doesn't already exist). For a permanent fix that survives that case too, fork the repo, apply the same one-line change to `permissions.py`, and point `spec.feastProjectDir.git.url` at your fork.

---

## Accessing the Feature Store

### Via RHOAI Dashboard

1. Open RHOAI Dashboard
2. Navigate to **Data Science Projects** → Your project
3. Click **Feature Store** tab
4. You should see the "banking" feature store

### Via Feast UI (Direct)

```bash
# Get the Feast UI route
oc get route -n feast-demo | grep feast

# Or create a route if one doesn't exist
oc expose svc/feast-banking-registry -n feast-demo
```

### Via API

```bash
# Get registry service
REGISTRY_SVC=$(oc get svc -n feast-demo -l feast.dev/name=banking | grep registry | awk '{print $1}')

# List feature views
curl -s http://$REGISTRY_SVC.feast-demo.svc.cluster.local:80/feature-views | jq

# Get online features
curl -X POST http://$REGISTRY_SVC.feast-demo.svc.cluster.local:80/get-online-features \
  -H "Content-Type: application/json" \
  -d '{
    "feature_service": "customer_features",
    "entities": {"customer_id": ["C001", "C002"]}
  }'
```

---

## Feature Definitions

The banking demo includes these feature views:

| Feature View | Entity | Features |
|--------------|--------|----------|
| `customer_demographics` | customer_id | age, income, tenure, credit_score |
| `transaction_7d` | customer_id | count, total_amount, avg_amount |
| `transaction_30d` | customer_id | count, total_amount, avg_amount |
| `transaction_90d` | customer_id | count, total_amount, avg_amount |
| `atm_usage` | customer_id | withdrawal_count, total_withdrawn |
| `branch_metrics` | branch_id | transaction_volume, avg_wait_time |
| `call_center` | customer_id | call_count, avg_resolution_time |
| `risk_score` | customer_id | score (on-demand computation) |

---

## Prerequisites

- RHOAI installed with Feast Operator enabled
- Git access to feature repository
- Namespace with `opendatahub.io/dashboard=true` label (for 3.3+)

---

## Troubleshooting

### FeatureStore not appearing in dashboard

```bash
# Check labels
oc get featurestore banking -n feast-demo -o jsonpath='{.metadata.labels}'

# Check restAPI setting
oc get featurestore banking -n feast-demo -o jsonpath='{.spec.services.registry.local.server.restAPI}'

# Check namespace label
oc get namespace feast-demo --show-labels | grep dashboard

# Use toolkit diagnose
./rhoai-toolkit.sh
# → RHOAI Management → AI Services & Infrastructure → Feature Store Management → Diagnose Feature Store
```

### Feast pod not starting

```bash
# Check pod status
oc get pods -n feast-demo -l feast.dev/name=banking

# Check events
oc describe featurestore banking -n feast-demo

# Check operator logs
oc logs -n redhat-ods-applications -l app.kubernetes.io/name=feast-operator
```

### feast apply fails

```bash
# Check git URL is accessible
curl -I https://github.com/RHRolun/banking-feature-store

# Check pod logs
oc logs -n feast-demo -l feast.dev/name=banking -c registry
```

---

## Files

| File | Location | Description |
|------|----------|-------------|
| FeatureStore CR | `lib/manifests/feast/featurestore-banking-demo.yaml` | Main deployment manifest |
| Template | `lib/manifests/feast/featurestore-template.yaml` | Generic template |
| Function | `lib/functions/rhoai.sh` | `deploy_banking_demo()` function |

---

## Source Repository

The feature definitions come from:
- **Repository**: https://github.com/RHRolun/banking-feature-store
- **Branch**: rbac

---

## Learn More

- [Feast Documentation](https://docs.feast.dev/)
- [RHOAI Feature Store Guide](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.3/html/working_with_machine_learning_features)
- [CAI Guide - Feature Store Section](docs/reference/(DRAFTY) CAI's guide to RHOAI 3.2 (and eventually 3.3).md)
