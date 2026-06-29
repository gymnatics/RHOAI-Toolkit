# Troubleshooting Guide

Quick reference for common issues and solutions across OpenShift installation, RHOAI, model deployment, and MaaS.

---

## OpenShift Installation

### Pull Secret Issues

**Error:** Script hangs after pasting pull secret

**Fix:** Use file path instead — when prompted, select Option 2 and enter `~/Openshift-installation/pull-secret.txt`

### SSH Key Errors

**Error:** `syntax error near unexpected token '('`

**Fix:** Fixed in current script. Select Option 1 to generate a new key, or re-download the latest script.

### Domain Errors

**Error:** `no public route53 zone found matching name "example.com"`

**Fix:** Use your actual domain (e.g., `example.opentlc.com`), not just `example.com`.

### Subnet Errors

**Error:** `no private subnets found`

**Fix:** Fixed in current script. If you see this, clean up and re-run:
```bash
./cleanup-failed-install.sh
./openshift-installer-master.sh
```

### AWS Credential Errors

**Error:** `AWS credentials not configured`

**Fix:** Run `./openshift-installer-master.sh` and select option 1 (Configure AWS Credentials).

### Quota Exceeded

**Error:** `Service quota exceeded`

**Fix:** Check quotas via `./openshift-installer-master.sh` option 3, then request increases at https://console.aws.amazon.com/servicequotas/

### macOS Security Warning

**Error:** `Apple could not verify "openshift-install"`

**Fix:** `xattr -rc .` or run `./fix-macos-security.sh`

---

## RHOAI Components

### Cluster Restart — "Could not load component state"

After stopping and restarting your AWS environment, the RHOAI dashboard shows errors and operators show "Unknown" status.

**Quick diagnosis:**
```bash
oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
```

**Common fixes:**

1. **Kueue issues** (most common):
   ```bash
   oc patch datasciencecluster default-dsc --type=merge \
     -p '{"spec":{"components":{"kueue":{"managementState":"Removed"}}}}'
   ```

2. **LWS "Unknown" or multiple OperatorGroups:**
   ```bash
   oc delete operatorgroup --all -n openshift-lws-operator
   # Then recreate a single OperatorGroup matching the namespace name
   ```

3. **Pending InstallPlans:**
   ```bash
   oc get installplan -n openshift-operators
   oc patch installplan <name> -n openshift-operators --type merge --patch '{"spec":{"approved":true}}'
   ```

### Kueue — "Kueue is disabled in this cluster"

Model deployment fails because Kueue is set to `Removed` instead of `Unmanaged`.

**Fix:**
```bash
# Set Kueue to Unmanaged (not Removed, not Managed)
oc patch datasciencecluster default-dsc --type='merge' \
  -p '{"spec":{"components":{"kueue":{"managementState":"Unmanaged","defaultClusterQueueName":"default","defaultLocalQueueName":"default"}}}}'

# Enable in dashboard
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
  --type merge -p '{"spec":{"dashboardConfig":{"disableKueue":false}}}'
```

**Note:** Kueue requires cert-manager. If you see `cert-manager is not installed`, install it first via `./rhoai-toolkit.sh` or `lib/functions/operators.sh`.

**Key gotchas:**
- Package name is `kueue-operator` (not `openshift-kueue-operator`)
- Channel is `stable-v1.3` (not `stable`)

### LWS — "Multiple OperatorGroup" or "Unknown" Status

**Root cause:** Duplicate OperatorGroups in `openshift-lws-operator` namespace.

**Fix:**
```bash
oc delete operatorgroup --all -n openshift-lws-operator
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-lws-operator
  namespace: openshift-lws-operator
spec:
  targetNamespaces:
  - openshift-lws-operator
EOF
```

**Key gotchas:**
- Package name is `leader-worker-set` (not `lws-operator`)
- Channel is `stable-v1.0` (not `stable`)
- OperatorGroup name must match the namespace name

### Authorino Service Not Created (Fresh Clusters)

On fresh clusters (< 1 hour old), Kuadrant may fail to create Authorino due to CRD caching.

**Symptoms:** Installation hangs at "Waiting for Authorino service..."

**Fix:** The scripts handle this automatically. Manual fix:
```bash
oc delete pod -l control-plane=controller-manager -n kuadrant-system
sleep 30
oc get svc/authorino-authorino-authorization -n kuadrant-system
```

### Dashboard Route Not Created

Dashboard pods are running but no route exists. Common on fresh RHOAI installs.

**Fix:** The scripts handle this automatically. Manual fix:
```bash
cat <<'EOF' | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: rhods-dashboard
  namespace: redhat-ods-applications
  labels:
    app: rhods-dashboard
spec:
  port:
    targetPort: https
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: reencrypt
  to:
    kind: Service
    name: rhods-dashboard
    weight: 100
  wildcardPolicy: None
EOF
```

---

## Model Deployment

### Hardware Profile Not Visible in Dashboard

**Common causes (in order):**

1. **Wrong namespace:** Profiles must be in the same namespace where you deploy models, not `redhat-ods-applications`.
   ```bash
   oc get hardwareprofile -n $(oc project -q)
   ```

2. **Missing labels:** Profile needs `app.opendatahub.io/hardwareprofile: "true"`.

3. **Scheduling constraints hiding it:** If profile has `nodeSelector` for GPU and no GPU nodes exist, it's hidden.

**Quick fix:** `./scripts/fix-hardware-profile.sh` or `./scripts/create-hardware-profile.sh <namespace>`

### VLLM_ADDITIONAL_ARGS — "/bin/bash: --: invalid option"

Setting `VLLM_ADDITIONAL_ARGS` via the RHOAI Dashboard UI fails because bash interprets `--` flags before passing them to vLLM.

**Fix:** Deploy via YAML instead of the UI. For `InferenceService` (vLLM), use `args`:
```yaml
spec:
  predictor:
    model:
      args:
        - '--enable-auto-tool-choice'
        - '--tool-call-parser=hermes'
```

For `LLMInferenceService` (llm-d), use the env var in YAML (works when applied via `oc apply`, not via UI):
```yaml
env:
  - name: VLLM_ADDITIONAL_ARGS
    value: "--enable-auto-tool-choice --tool-call-parser=hermes"
```

---

## MaaS / Rate Limiting (RHOAI 3.3 Tech Preview)

### Models Not Visible in "Models as a service" Tab

**Status:** Known bug in `maas-api` component (RHOAI 3.3.0). Models deploy and work via direct API, but don't appear in the MaaS dashboard tab.

**Workaround:** Access models directly via API:
```bash
TOKEN=$(oc create token default -n <namespace> --audience="https://kubernetes.default.svc" --duration=1h)
curl -sk "https://maas-api.apps.<cluster>/<namespace>/<model>/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"<model>","messages":[{"role":"user","content":"Hi"}],"max_tokens":10}'
```

### Tier-Based Rate Limiting Not Working

Multiple interrelated issues prevent tier-based rate limiting from working out of the box:

1. **AuthPolicy override:** `odh-model-controller` creates a new AuthPolicy that overrides the one with tier lookup
2. **TokenReview doesn't return OpenShift groups:** Only system groups are sent to tier lookup
3. **UI creates conflicting individual TokenRateLimitPolicies** instead of one combined policy

**Complete fix (apply in order):**
```bash
# 1. Label gateway as not managed by RHOAI
oc label gateway maas-default-gateway -n openshift-ingress opendatahub.io/managed=false --overwrite

# 2. Remove conflicting AuthPolicy
oc delete authpolicy maas-default-gateway-authn -n openshift-ingress --ignore-not-found

# 3. Delete UI-created policies
oc delete tokenratelimitpolicy tier-free-token-rate-limits \
  tier-premium-token-rate-limits tier-enterprise-token-rate-limits \
  -n openshift-ingress --ignore-not-found

# 4. Apply combined TokenRateLimitPolicy
oc apply -f demo/maas-demo/manifests/tiers/tokenratelimitpolicy.yaml

# 5. Restart components
oc rollout restart deployment/authorino -n kuadrant-system
oc rollout restart deployment/limitador-limitador -n kuadrant-system
oc rollout restart deployment/maas-api -n redhat-ods-applications
```

**Important:** Don't use the Dashboard UI for tier management — use CLI only. This is expected to be fixed in RHOAI 3.4.

### UI and CLI Interference

The RHOAI Dashboard and CLI configurations interfere with each other. Changes in the UI overwrite CLI-configured rate limits, and CLI-configured limits don't appear in the UI.

**Rule of thumb:** Pick one interface (CLI recommended) and stick with it. The `demo/maas-demo/demo.sh` script applies all fixes automatically.

---

## MaaS / RHOAI 3.4

### MaaS API Keys Page — "Error loading components"

**Error:** The Gen AI Studio > API Keys page shows "Error loading components — the server encountered a problem and could not process your request."

**Root cause:** The `Tenant` CR (`default-tenant` in `models-as-a-service`) has `spec.gatewayRef` pointing to `openshift-ai-inference` instead of `maas-default-gateway`. The Tenant controller reconciles the `maas-api-route` HTTPRoute using this gatewayRef, so the route only gets `openshift-ai-inference` in its `parentRefs`. But the `maas-ui` sidecar discovers the MaaS URL as `https://maas.apps.<cluster>/maas-api/...` which routes through `maas-default-gateway`. Since that gateway isn't in the parentRefs, `/maas-api/*` gets a 404.

This typically happens when the Tenant was auto-created before `maas-default-gateway` existed, inheriting `openshift-ai-inference` as the default.

**Diagnosis:**
```bash
# Check maas-ui logs for the 404
oc logs $(oc get pods -n redhat-ods-applications -l app=rhods-dashboard --no-headers | grep Running | head -1 | awk '{print $1}') \
  -n redhat-ods-applications -c maas-ui --tail=20
# Look for: "unknown error when invoking maas-api (unmarshall)" statusCode=404

# Confirm the Tenant gatewayRef is wrong
oc get tenant default-tenant -n models-as-a-service -o jsonpath='{.spec.gatewayRef}'
# If it shows openshift-ai-inference, that's the bug

# Confirm the HTTPRoute parentRefs
oc get httproute maas-api-route -n redhat-ods-applications -o jsonpath='{.spec.parentRefs[*].name}'
```

**Fix (permanent):** Patch the Tenant CR's `gatewayRef` to `maas-default-gateway`. The Tenant controller will automatically reconcile the `maas-api-route` HTTPRoute to use the correct gateway:
```bash
oc patch tenant default-tenant -n models-as-a-service --type=merge \
  -p '{"spec":{"gatewayRef":{"name":"maas-default-gateway","namespace":"openshift-ingress"}}}'
```

This is the proper fix — it changes the source of truth so the controller reconciles correctly, rather than fighting it.

**Verify:**
```bash
# Should show maas-default-gateway
oc get httproute maas-api-route -n redhat-ods-applications -o jsonpath='{.spec.parentRefs[*].name}'

# Should return: {"status":"healthy"}
curl -sk "https://maas.apps.<cluster>/maas-api/health"
```

### Cluster Observability Operator v1.5.0 Breaks MaaS Dashboard

**Error:** The Observe & Monitor > Dashboard page shows "Internal error" or charts fail to load.

**Root cause:** COO v1.5.0 ships a Perses binary that adds `-web.tls-min-version` as a startup flag, but the StatefulSet image and configuration can get into a mismatch state where the binary doesn't recognize the flag, causing CrashLoopBackOff.

**Diagnosis:**
```bash
# Perses pod in CrashLoopBackOff
oc get pods -n redhat-ods-monitoring | grep perses
# Logs show: "flag provided but not defined: -web.tls-min-version"
oc logs data-science-perses-0 -n redhat-ods-monitoring
```

**Fix — Option A: Rollback to COO v1.4.0** (recommended if v1.5.0 causes issues):
```bash
# Delete subscription and CSV
oc delete subscription cluster-observability-operator -n openshift-cluster-observability-operator
oc delete csv cluster-observability-operator.v1.5.0 -n openshift-cluster-observability-operator

# Recreate pinned to v1.4.0 with Manual approval to prevent auto-upgrade
oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cluster-observability-operator
  namespace: openshift-cluster-observability-operator
spec:
  channel: stable
  installPlanApproval: Manual
  name: cluster-observability-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: cluster-observability-operator.v1.4.0
EOF

# Approve the v1.4.0 InstallPlan
IP=$(oc get installplan -n openshift-cluster-observability-operator --no-headers | grep v1.4.0 | awk '{print $1}')
oc patch installplan "$IP" -n openshift-cluster-observability-operator \
  --type='json' -p='[{"op": "replace", "path": "/spec/approved", "value": true}]'

# Wait for CSV, then recreate Perses StatefulSet
sleep 30
oc delete statefulset data-science-perses -n redhat-ods-monitoring
```

**Fix — Option B: Recreate Perses StatefulSet** (if staying on v1.5.0):
```bash
oc delete statefulset data-science-perses -n redhat-ods-monitoring
# The operator will recreate it with the correct image/args
```

**Verify:**
```bash
oc get pods -n redhat-ods-monitoring | grep perses
# Should show 1/1 Running
```

### Observability Dashboard — GPU Metrics Show "No data"

**Error:** The Observe & Monitor > Dashboard shows "No data" for GPU utilization, while CPU and Memory charts work.

**Root cause:** The `gpu-operator` ServiceMonitor in `nvidia-gpu-operator` only monitors the GPU Operator controller pod, not the DCGM exporter (which exposes GPU metrics on port 9400). A separate ServiceMonitor is needed for DCGM.

**Fix:** Create a ServiceMonitor for the DCGM exporter:
```bash
oc apply -f - <<'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nvidia-dcgm-exporter
  namespace: nvidia-gpu-operator
  labels:
    app: nvidia-dcgm-exporter
spec:
  endpoints:
  - path: /metrics
    port: gpu-metrics
    interval: 30s
  namespaceSelector:
    matchNames:
    - nvidia-gpu-operator
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter
EOF
```

**Verify** (wait ~60s for scraping to start):
```bash
TOKEN=$(oc create token prometheus-k8s -n openshift-monitoring)
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://thanos-querier-openshift-monitoring.apps.<cluster>/api/v1/query?query=DCGM_FI_DEV_GPU_UTIL"
# Should return results for each GPU node
```

### HardwareProfile Toleration Error — `value must be empty when operator is Exists`

**Error:** InferenceService stuck at `ReconcileFailed` with: `Deployment is invalid: spec.template.spec.tolerations[0].operator: Invalid value: "True": value must be empty when operator is 'Exists'`

**Root cause:** The HardwareProfile has `operator: Exists` with `value: "True"` in its toleration. When `operator` is `Exists`, `value` must be empty. KServe reads tolerations from the HardwareProfile and applies them to the deployment — fixing the InferenceService alone won't help because KServe keeps overwriting from the HardwareProfile.

**Fix:** Fix the HardwareProfile (not the InferenceService):
```bash
HP_NAME="<hardware-profile-name>"  # e.g. gpu-profile-nvidia-l40s
oc get hardwareprofile "$HP_NAME" -n redhat-ods-applications -o json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for t in data['spec']['scheduling']['node']['tolerations']:
    if t.get('operator') == 'Exists':
        t.pop('value', None)
json.dump(data, sys.stdout)
" | oc replace -f -
```

Then force the InferenceService to reconcile:
```bash
oc get inferenceservice <name> -n <namespace> -o json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for t in data['spec']['predictor']['tolerations']:
    if t.get('operator') == 'Exists':
        t.pop('value', None)
json.dump(data, sys.stdout)
" | oc replace -f -
```

### DSC NotReady — Kueue `Managed` Not Supported

**Error:** DataScienceCluster shows `NotReady` with: `Kueue managementState Managed is not supported, please use Removed or Unmanaged`

**Root cause:** When the standalone Kueue operator is already installed, the DSC's Kueue component must be set to `Unmanaged` to avoid conflicts.

**Fix:**
```bash
oc patch datasciencecluster default-dsc --type='json' \
  -p='[{"op": "replace", "path": "/spec/components/kueue/managementState", "value": "Unmanaged"}]'
```

---

## macOS Compatibility

### grep -P / awk Errors in Model Deployment

**Errors:** `grep: invalid option -- P` or `awk: syntax error at source line 1`

**Status:** Fixed in current scripts. The codebase now uses `lib/utils/os-compat.sh` for cross-platform support (portable `grep`, `sed`, `awk`, `base64` wrappers).

If you see these errors, you may be running an old version of the scripts.

---

## Cleanup

### Quick Cleanup
```bash
./cleanup-failed-install.sh
```

### Manual Cleanup
```bash
./openshift-install destroy cluster --dir=openshift-cluster-install
rm -rf openshift-cluster-install
```

---

## Verification Commands

```bash
# Cluster health
oc get nodes
oc get clusteroperators
oc get clusterversion

# RHOAI status
oc get datasciencecluster
oc get csv -A | grep -E "nfd|gpu|kueue|lws|rhcl|rhods"

# GPU nodes
oc get nodes -l nvidia.com/gpu.present=true

# Hardware profiles
oc get hardwareprofiles -n $(oc project -q)

# MaaS (3.3+)
oc get gateway -n openshift-ingress
oc get authpolicy -n openshift-ingress
oc get tokenratelimitpolicy -n openshift-ingress
```
