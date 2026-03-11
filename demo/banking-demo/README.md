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

### Step 4: Apply Feature Definitions

```bash
# Get the feast pod
FEAST_POD=$(oc get pods -n feast-demo -l feast.dev/name=banking -o jsonpath='{.items[0].metadata.name}')

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
