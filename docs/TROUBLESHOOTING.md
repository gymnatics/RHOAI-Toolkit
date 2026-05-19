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
