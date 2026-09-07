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

## MaaS / RHOAI 3.5

### MaaS Gateway Returns HTTP 500 Before First Model Is Deployed (Missing Authorino TLS EnvoyFilter)

**Error:** All authenticated requests to the MaaS gateway (`https://maas.apps.<cluster>/...`) return HTTP 500 "Internal Server Error." The health endpoint works, but `/v1/models`, `/v1/api-keys`, `/maas-api/v1/models`, etc. all fail. The Gen AI Studio UI shows errors for API keys, models, and subscriptions. **MaaS starts working once you deploy your first `LLMInferenceService`.**

**Root cause:** The Kuadrant-managed `kuadrant-auth-maas-default-gateway` EnvoyFilter configures the `kuadrant-auth-service` envoy cluster to connect to Authorino's gRPC port (50051) **without TLS**. But Authorino has TLS enabled on its gRPC listener (via `service.beta.openshift.io/serving-cert-secret-name`). The gateway envoy sends plain H2 to a TLS-expecting endpoint → gRPC failure → HTTP 500.

The TLS config is normally provided by a **separate** EnvoyFilter called `maas-default-gateway-authn-ssl`, which is created by `odh-model-controller` **only when an `LLMInferenceService` is deployed**. This EnvoyFilter has `priority: -1` (applies before the Kuadrant one) and includes the `transport_socket` with TLS. Without a model deployed, this EnvoyFilter doesn't exist, and all auth fails.

**Diagnosis:**
```bash
# Gateway proxy logs show WASM gRPC errors for every authenticated request
oc logs -n openshift-ingress \
  -l gateway.networking.k8s.io/gateway-name=maas-default-gateway --tail=50 \
  | grep "gRPC status code is not OK"

# Confirm the authn-ssl EnvoyFilter is MISSING (the bug)
oc get envoyfilter maas-default-gateway-authn-ssl -n openshift-ingress
# "not found" confirms the bug

# Confirm the auth cluster has no TLS transport_socket
GW_POD=$(oc get pods -n openshift-ingress \
  -l gateway.networking.k8s.io/gateway-name=maas-default-gateway \
  -o jsonpath='{.items[0].metadata.name}')
oc exec -n openshift-ingress $GW_POD -- pilot-agent request GET "config_dump" 2>&1 \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
for c in data.get('configs', []):
    for cl in c.get('dynamic_active_clusters', []):
        if 'kuadrant-auth' in cl.get('cluster', {}).get('name', ''):
            has_tls = 'transport_socket' in cl['cluster']
            print(f'transport_socket present: {has_tls}')
"
# If False → missing TLS, confirms the bug
```

**Fix:** Create the missing EnvoyFilter with the Authorino TLS transport socket:
```bash
cat <<'EOF' | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: maas-default-gateway-authn-ssl
  namespace: openshift-ingress
  labels:
    app.kubernetes.io/component: maas-gateway-auth-tls-fix
    app.kubernetes.io/managed-by: rhoai-toolkit
spec:
  configPatches:
  - applyTo: CLUSTER
    match:
      cluster:
        service: authorino-authorino-authorization.kuadrant-system.svc.cluster.local
    patch:
      operation: ADD
      value:
        connect_timeout: 1s
        http2_protocol_options: {}
        lb_policy: ROUND_ROBIN
        load_assignment:
          cluster_name: kuadrant-auth-service
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: authorino-authorino-authorization.kuadrant-system.svc.cluster.local
                    port_value: 50051
        name: kuadrant-auth-service
        transport_socket:
          name: envoy.transport_sockets.tls
          typed_config:
            '@type': type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
            common_tls_context:
              validation_context:
                trusted_ca:
                  filename: /var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt
        type: STRICT_DNS
  priority: -1
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: maas-default-gateway
EOF

# Restart the gateway pod to pick up the new EnvoyFilter
oc delete pod -n openshift-ingress \
  -l gateway.networking.k8s.io/gateway-name=maas-default-gateway
```

Wait ~20 seconds, then verify:
```bash
TOKEN=$(oc whoami -t)
curl -sk -w "\nHTTP_CODE:%{http_code}\n" \
  -H "Authorization: Bearer $TOKEN" \
  "https://maas.apps.<cluster>/v1/models"
# Should return: {"data":[],"object":"list"} HTTP_CODE:200
```

**Note:** Once you deploy your first `LLMInferenceService`, `odh-model-controller` creates its own version of this EnvoyFilter (owned by the Gateway). The manually-created one can coexist or be removed after that point. The install script (`install-rhoai-35.sh`) should apply this fix proactively during `verify_maas_deployment()`.

---

### MaaS API Keys Page — "unknown error when invoking maas-api (unmarshal): invalid character" (Stale WASM shim state)

**Error:** Gen AI Studio > API Keys page shows "Error loading API keys — unknown error when invoking maas-api (unmarshal): invalid character 'I' looking for beginning of value". The MaaS API health endpoint (`/maas-api/health`) may return `{"status":"healthy"}`, but authenticated calls to `/v1/api-keys` or `/maas-api/v1/api-keys/search` return HTTP 500 "Internal Server Error."

**Root cause:** During initial RHOAI 3.5 install, the `maas-api` pod crash-loops while waiting for the PostgreSQL database and other dependencies to become ready. The `maas-default-gateway` pod's Kuadrant WASM shim (`kuadrant_wasm_shim`) caches failed gRPC connection state from those initial auth evaluation attempts. Once `maas-api` stabilizes, the WASM shim continues using the stale (broken) gRPC state, returning 500 for every authenticated request. The "invalid character 'I'" in the error message is the first character of the "Internal Server Error." text that the dashboard tries to parse as JSON.

**Diagnosis:**
```bash
# Gateway logs show WASM gRPC errors
oc logs -n openshift-ingress -l gateway.networking.k8s.io/gateway-name=maas-default-gateway --tail=20 \
  | grep "gRPC status code is not OK"

# Health works but auth calls fail
curl -sk "https://maas.apps.<cluster>/maas-api/health"
# Returns: {"status":"healthy"}

curl -sk -X POST "https://maas.apps.<cluster>/maas-api/v1/api-keys/search" \
  -H "Authorization: Bearer $(oc whoami -t)" -H "Content-Type: application/json" -d '{}'
# Returns: Internal Server Error.
```

**Fix:** Restart the gateway pod to clear the stale WASM shim state:
```bash
oc delete pod -n openshift-ingress \
  -l gateway.networking.k8s.io/gateway-name=maas-default-gateway
```

Wait ~15 seconds for the new pod to start, then retry. The install script (`install-rhoai-35.sh`) now automatically restarts the gateway pod at the end of `verify_maas_deployment()` to prevent this issue.

### Observability Dashboard Missing — "Dashboard" menu item not under "Observe & monitor"

**Error:** After enabling `observabilityDashboard: true` in OdhDashboardConfig, the "Dashboard" menu item does not appear under "Observe & monitor" in the RHOAI dashboard. Only "Workload metrics" and "Infrastructure" are shown.

**Root cause:** Two issues:

1. **NetworkPolicy blocks perses-operator:** The auto-created `NetworkPolicy/perses-operator-access` in `redhat-ods-monitoring` only allows ingress from `openshift-operators`, but the `perses-operator` pod actually runs in `openshift-cluster-observability-operator`. The operator can't reach the Perses server to sync PersesDashboard CRs, so all dashboards stay in `PersesBackendError` state.

2. **Missing `monitoring-prometheus-datasource-secret`:** The PersesDatasource CR references this secret for authenticating to Thanos Querier. Without it, the datasource stays Degraded.

**Diagnosis:**
```bash
# Check PersesDashboard status — all should be True/Reconciled
oc get persesdashboard -n redhat-ods-monitoring \
  -o custom-columns='NAME:.metadata.name,AVAILABLE:.status.conditions[0].status,REASON:.status.conditions[0].reason'

# Check PersesDatasource status
oc get persesdatasource -n redhat-ods-monitoring \
  -o jsonpath='{.items[0].status.conditions}'

# Check if the datasource secret exists
oc get secret monitoring-prometheus-datasource-secret -n redhat-ods-monitoring
```

**Fix:**
```bash
# 1. Fix the NetworkPolicy to allow perses-operator access
oc apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: perses-coo-operator-access
  namespace: redhat-ods-monitoring
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/managed-by: perses-operator
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: openshift-cluster-observability-operator
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: redhat-ods-monitoring
    ports:
    - port: 8080
      protocol: TCP
  policyTypes:
  - Ingress
EOF

# 2. Create the datasource secret
oc create secret generic monitoring-prometheus-datasource-secret \
  --from-literal=token="$(oc create token prometheus-k8s -n openshift-monitoring --duration=87600h)" \
  --from-literal=host="$(oc get route thanos-querier -n openshift-monitoring -o jsonpath='{.spec.host}')" \
  -n redhat-ods-monitoring

# 3. Trigger re-sync of all dashboards
for db in $(oc get persesdashboard -n redhat-ods-monitoring -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
  oc annotate persesdashboard "$db" -n redhat-ods-monitoring --overwrite reconcile-trigger="$(date +%s)"
done

# 4. Restart dashboard pods
oc rollout restart deployment/rhods-dashboard -n redhat-ods-applications
```

---

### Observability Dashboard Panels Show "No datasource found for kind 'PrometheusDatasource'"

**Symptom:** The RHOAI dashboard's **Observe & monitor → Dashboard** page loads, but every panel (System health, Deployed models, GPU utilization, Request success rate, Cluster resource overview) shows a red warning: `No datasource found for kind 'PrometheusDatasource' and name 'cluster-prometheus-datasource'`.

**Root cause:** Two `PersesDatasource` objects both marked `config.default: true` exist in `redhat-ods-monitoring`:
- `cluster-prometheus-datasource` — auto-created by RHOAI 3.5's DSC-managed `Monitoring` component
- `monitoring-prometheus-datasource` — created by this toolkit's `lib/manifests/monitoring/persesdatasource-monitoring.yaml` (a fallback originally written for RHOAI 3.4, which has no native Monitoring component)

Perses only allows **one** default datasource per kind. Whichever one reconciles second gets rejected by the Perses API (`400: cannot be a default "PrometheusDatasource" because there is already one defined named "..."`) and its `PersesDatasource` status stays permanently `Degraded`. Since the RHOAI dashboard specifically looks up `cluster-prometheus-datasource` by name, if *that* one is the one that lost the race, every panel fails.

`install-rhoai-34.sh` / `install-rhoai-35.sh` now check for `cluster-prometheus-datasource` before applying the toolkit's fallback manifest and skip it if RHOAI's native one already exists — this only affects environments set up before that fix, or where the manifest was applied manually.

**Diagnosis:**
```bash
# List all PersesDatasource objects — look for more than one with config.default: true
oc get persesdatasource -n redhat-ods-monitoring -o yaml | grep -E 'name:|default:'

# Check the status of the one RHOAI's dashboard actually uses
oc get persesdatasource cluster-prometheus-datasource -n redhat-ods-monitoring \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status} ({.message}){"\n"}{end}'
```

**Fix:**
```bash
# 1. Delete the toolkit's duplicate (the RHOAI-native one is authoritative)
oc delete persesdatasource monitoring-prometheus-datasource -n redhat-ods-monitoring

# 2. Force RHOAI's Monitoring operator to recreate cluster-prometheus-datasource
#    fresh — its cached Degraded status won't clear on its own
oc delete persesdatasource cluster-prometheus-datasource -n redhat-ods-monitoring

# 3. Wait ~20s, then verify it comes back Available
oc get persesdatasource cluster-prometheus-datasource -n redhat-ods-monitoring \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status} ({.message}){"\n"}{end}'
```

Then refresh the RHOAI dashboard — panels should populate within a minute.

---

### BU Guide Post-Upgrade Issues (3.4 → 3.5) — Quick Reference

The [RHOAI MaaS Guide](https://rh-aiservices-bu.github.io/rhoai-maas-guide/modules/main/10-post-upgrade-troubleshooting.html) documents 10 known post-upgrade issues. Run `./scripts/diagnose-maas.sh --fix` to check all of them automatically (it also codifies the 3 fixes below, validated against a live RHOAI 3.5 cluster on 2026-09-03).

| # | Issue | Jira | Auto-fixed by `diagnose-maas.sh --fix`? |
|---|-------|------|------------------------------------------|
| 1 | MCP Lifecycle Operator OOMKill (blocks DSC Ready) | RHOAIENG-82694 | No — reports only (fix requires setting `mcplifecycleoperator` to `Removed`, which disables MCP server support) |
| 2 | ExternalModel migration — dotted secret names fail on new regex | RHOAIENG-89784 | No — reports only (requires manual secret recreation) |
| 3 | Gateway namespace label missing after upgrade to `from: Selector` | RHOAIENG-83207 | **Yes** — labels `redhat-ods-applications`, the infra namespace, and `models-as-a-service` |
| 4 | Gateway hostname discovery fails on ClusterIP+Route topology | RHOAIENG-89775 | No — reports only (requires setting `spec.listeners[].hostname` explicitly) |
| 5 | payload-processing OOMKill at the 256Mi default | RHOAIENG-88898 | **Yes** — annotates `opendatahub.io/managed=false` + bumps to 1Gi |
| 6 | RHCL 1.4.x rate limiting silently breaks / Gateway OOM | RHOAIENG-76586 | No — reports only (requires the `gateway-resources.yaml` ConfigMap, applied by `setup-maas.sh` on fresh installs) |
| 7 | WASM auth timeout under load (200ms default too low) | RHOAIENG-71638 | **Yes** — sets `AUTH_SERVICE_TIMEOUT=2s` on the RHCL subscription |
| 8 | Envoy ext_proc body corruption (chained filters) | OSSM-15498 | No — no upstream fix exists yet; reports Envoy version only |
| 9 | Token rate limiting default too low (~1000/hr) causes spurious 429s | RHOAIENG-89785 | No — reports only (our own model manifests already ship 100/min free + 100K/min premium tiers, avoiding the default) |
| 10 | Duplicate AI Playground endpoints from leftover `LlamaStackDistribution` | RHOAIENG-89786 | No — reports only (requires `oc delete llamastackdistribution -n <model-ns> --all`) |

**Also fixed by `setup-maas.sh`** (applied proactively on every run, not just diagnosed): DSC field migration from the deprecated `kserve.modelsAsService` to `aigateway.modelsAsAService` on RHOAI 3.5+ — this was validated live: a cluster that had been left on the deprecated 3.4-style DSC field was successfully migrated in place, and its `Ready` condition went from `False (Degraded)` to `True` as a result.

---

### Simulator Model (`llm-d-inference-sim`) — Container Command / TLS / Tokenizer Gotchas

**Context:** `lib/manifests/maas/models/simulator/` deploys a CPU-only LLM simulator for testing MaaS without GPU hardware. Getting this working correctly required discovering three separate, stacked bugs — documented here so they aren't reintroduced. All three were found and fixed by deploying to a live RHOAI 3.5 cluster with `scripts/verify-maas.sh` on 2026-09-03/04.

**Bug 1 — `LLMInferenceService.spec.model` always injects a vLLM-serve wrapper command, ignoring `args`:**

Setting `spec.model.uri`/`spec.model.name` on an `LLMInferenceService` makes KServe **unconditionally** generate `command: ["/bin/bash", "-c", "<script with 'exec vllm serve ...'>", "--"]` for the container, appending any user-supplied `args` as trailing positional arguments to that script — it does **not** let `args` alone override the launch command. This breaks any non-vLLM image:
- If the image has no `vllm` binary on `PATH`, the wrapper's version-detection line (`vllm --version`) fails with `exec: vllm: not found`.
- If the image lacks `/bin/bash` entirely (common in minimal/scratch-based images), pod creation fails outright with `executable file /bin/bash not found`.

```bash
# Confirm what KServe actually generated for your pod:
oc get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].command}'
```

**Fix:** set `spec.template.containers[].command` **explicitly** to the image's real entrypoint. Find it with:
```bash
oc image info <image> --filter-by-os linux/amd64 | grep Entrypoint
# e.g. Entrypoint: /app/llm-d-inference-sim
```
Then in the manifest:
```yaml
template:
  containers:
    - name: main
      image: ghcr.io/llm-d/llm-d-inference-sim:v0.7.1
      command: ["/app/llm-d-inference-sim"]
      args: ["--port=8000", "--model=facebook/opt-125m", "--mode=echo"]
```

**Bug 2 — the MaaS router expects HTTPS on the backend port, even with `command` overridden:**

KServe auto-mounts a self-signed TLS cert Secret (`<name>-kserve-self-signed-certs`) at `/var/run/kserve/tls/` for **every** `LLMInferenceService`, regardless of whether `command` is overridden. The Envoy/HTTPRoute router connects to the backend over HTTPS using that cert. A container serving plain HTTP receives raw TLS ClientHello bytes and logs `"unsupported http request method"` — readiness probes then fail with `MinimumReplicasUnavailable`.

**Fix:** pass the mounted cert/key to the simulator (it supports `--ssl-certfile`/`--ssl-keyfile`) and set the readiness probe to HTTPS:
```yaml
args: ["--ssl-certfile=/var/run/kserve/tls/tls.crt", "--ssl-keyfile=/var/run/kserve/tls/tls.key"]
readinessProbe:
  httpGet: {path: /health, port: 8000, scheme: HTTPS}
```

**Bug 3 — `ghcr.io/llm-d/llm-d-inference-sim:v0.9.0` requires a separate tokenizer "render" sidecar, even in `--mode=echo`:**

Starting in v0.9.0, `/v1/chat/completions` calls out to a vLLM "render" service on `http://localhost:8082` for tokenization/usage counting, **even in `--mode=echo`**. Without a render sidecar deployed, every chat completion fails with `dial tcp [::1]:8082: connect: connection refused`. There is **no flag to disable this** in v0.9.0 — `--force-dummy-tokenizer` does not exist in that version (confirmed via `--help`; it may be a docs-only/future flag).

**Fix:** pin to **v0.7.1**, which uses a self-contained Go tokenizer (`--tokenizers-cache-dir`) with no external render dependency. Do not upgrade this pin to v0.9.0+ without first confirming a render sidecar is deployed alongside it, or that a working `--force-dummy-tokenizer`-equivalent flag exists in that release.

```bash
# Check available flags for any given tag before changing the pin:
oc run debug-sim --image=<image>:<tag> --restart=Never --command -- /app/llm-d-inference-sim --help
oc logs debug-sim; oc delete pod debug-sim
```

**Bug 4 (not a bug — a routing model change) — RHOAI 3.5 uses body-based routing, not per-model URLs:**

`GET /v1/models` on RHOAI 3.5+ returns `{"data":[{"id": "publishers/<ns>/models/<name>", "url": "https://maas.<domain>/"}], ...}` — the `url` field is just the **gateway base URL**, not a per-model path. The model is selected via the `"model"` field in the **request body**, sent to the single shared `${MAAS_HOST}/v1/chat/completions` endpoint:
```bash
MODEL_ID=$(curl -sk -H "Authorization: Bearer $API_KEY" "$MAAS_HOST/v1/models" | jq -r '.data[0].id')
curl -sk "$MAAS_HOST/v1/chat/completions" -H "Authorization: Bearer $API_KEY" \
  -d "{\"model\":\"$MODEL_ID\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}"
```
Constructing a per-model URL manually (e.g. `${MAAS_HOST}/${ns}/${model}/v1/chat/completions`, the 3.4-era pattern) returns HTTP 404 on 3.5+.

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

### MaaS API Keys Page — Times Out After ~10s, "Error loading components" (NetworkPolicy blocks payload-processing ext_proc)

**Error:** The Gen AI Studio > API Keys page hangs for ~10 seconds then shows "Error loading components — the server encountered a problem and could not process your request." Unlike the `gatewayRef` bug above, this affects **every** authenticated MaaS API call (models list, API key search/create), not just `/maas-api/*` paths — requests without an `Authorization` header still fail fast with 401.

**Root cause:** The operator-managed `NetworkPolicy/payload-processing` in `openshift-ingress` only allows ingress on port 9004 (the `payload-processing` ext_proc gRPC service used by the `EnvoyFilter/payload-processing` for model-provider-resolver, API translation, and API-key injection) from pods labeled `gateway.networking.k8s.io/gateway-name: data-science-gateway`. But the MaaS `Tenant`'s `spec.gatewayRef` (correctly) points to `maas-default-gateway`, whose gateway pod carries the label `gateway.networking.k8s.io/gateway-name: maas-default-gateway` — which the policy does **not** allow. Since the `EnvoyFilter` sets `failure_mode_allow: false`, every request that passes auth and reaches the ext_proc filter blocks on the connection until Envoy gives up, surfacing as `ext_proc_error_gRPC_error_14{...connection_timeout}` → HTTP 500 after ~10s.

This is the same class of bug as the `Tenant.spec.gatewayRef` issue documented in [`docs/bugs/maas-bugs-rhoai-34.md`](bugs/maas-bugs-rhoai-34.md) (RHOAI hardcoding `data-science-gateway` assumptions instead of reading the tenant's actual gateway), but it hits the auto-generated `NetworkPolicy` instead of the `HTTPRoute`. It was observed appearing ~4 days after a DSC reconcile on RHOAI 3.4.4.

**Diagnosis:**
```bash
# Gateway controller logs show the ext_proc timeout for any authenticated request
oc logs deployment/maas-default-gateway-openshift-gateway-controller -n openshift-ingress --tail=50 \
  | grep ext_proc_error
# "POST /maas-api/v1/api-keys/search HTTP/2" 500 - ext_proc_error_gRPC_error_14{upstream_connect_error_or_disconnect/reset_before_headers._reset_reason:_connection_timeout} ...

# Confirm the NetworkPolicy selector mismatch
oc get networkpolicy payload-processing -n openshift-ingress \
  -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels}'
# {"gateway.networking.k8s.io/gateway-name":"data-science-gateway"}  <- should include maas-default-gateway

oc get tenant default-tenant -n models-as-a-service -o jsonpath='{.spec.gatewayRef.name}'
# maas-default-gateway  <- confirms the mismatch

# payload-processing pod itself is healthy — this is purely a NetworkPolicy issue
oc get pods -n openshift-ingress -l app=payload-processing
```

**Fix (do NOT edit the `payload-processing` NetworkPolicy directly — the operator reverts it within seconds; confirmed via `resourceVersion`/`generation` jumping after a direct `oc patch`).** Instead, add an **additive** NetworkPolicy targeting the same pods — Kubernetes NetworkPolicies are OR'd together, so this survives operator reconciliation of the original policy:
```bash
cat <<'EOF' | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: payload-processing-maas-gateway-allow
  namespace: openshift-ingress
  labels:
    app.kubernetes.io/part-of: modelsasservice
    app.kubernetes.io/managed-by: rhoai-toolkit
spec:
  podSelector:
    matchLabels:
      app: payload-processing
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: openshift-ingress
          podSelector:
            matchLabels:
              gateway.networking.k8s.io/gateway-name: maas-default-gateway
      ports:
        - port: 9004
          protocol: TCP
EOF
```

**Verify:**
```bash
TOKEN=$(oc whoami -t)
curl -sk -m 15 -H "Authorization: Bearer $TOKEN" -o /dev/null \
  -w "HTTP_CODE:%{http_code} TIME:%{time_total}\n" \
  "https://maas.apps.<cluster>/maas-api/v1/models"
# Should be HTTP_CODE:200 in well under 1s (not 500 after ~10s)
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

## Feature Store (Feast)

### FeatureStore Missing from Dashboard Despite Healthy Pods (RBAC permissions.py Namespace Mismatch)

**Symptom:** The `FeatureStore` CR is `Ready`, all pods (`registry`/`online`/`offline`) are `Running`, the required labels (`feature-store-ui: enabled`, `opendatahub.io/dashboard: "true"`) and `restAPI: true` are all correctly set, and `feast-<name>-registry`/`feast-<name>-registry-rest` services both exist — yet the Feature Store still doesn't appear anywhere in the RHOAI dashboard.

**Root cause:** This is specific to the banking demo (`RHRolun/banking-feature-store`, branch `rbac`) but the pattern applies to any Feast repo using `NamespaceBasedPolicy`. Its `feature_repo/permissions.py` defines:
```python
prod_namespaces = ["banking"]
all_resources = Permission(
    name="all_resources",
    types=ALL_RESOURCE_TYPES,
    policy=NamespaceBasedPolicy(namespaces=prod_namespaces),
    actions=[AuthzedAction.DESCRIBE] + READ,
)
```
`NamespaceBasedPolicy` checks `prod_namespaces` against the **OpenShift namespace** the FeatureStore is deployed into — but `"banking"` here is the **Feast project name**, not a namespace. Unless the target namespace is literally called `banking`, every registry `DESCRIBE`/list call is denied, and the dashboard's feature-store discovery (which queries the registry's REST API) silently gets back an empty list — no error surfaces in the dashboard UI itself.

**Diagnosis:**
```bash
FEAST_POD=$(oc get pods -n <namespace> -l feast.dev/name=<name> -o jsonpath='{.items[0].metadata.name}')

# Look for this exact error in the registry container's logs
oc logs -n <namespace> $FEAST_POD -c registry --tail=100 | grep "permitted namespaces"
# ERROR:feast.permissions.enforcer:Permission denied: Permission all_resources denied
#   execution of ['DESCRIBE'] to Project:<project>: User is not added into the permitted namespaces

# Confirm the mismatch directly in the persisted repo checkout
oc exec -n <namespace> $FEAST_POD -c registry -- \
  grep 'prod_namespaces =' /feast-data/<name>/feature_repo/permissions.py
```

**Fix (no git fork/push required — patches the already-cloned checkout on the `feast-data` PVC in place):**
```bash
FEAST_POD=$(oc get pods -n <namespace> -l feast.dev/name=<name> -o jsonpath='{.items[0].metadata.name}')

oc exec -n <namespace> $FEAST_POD -c registry -- \
  cp /feast-data/<name>/feature_repo/permissions.py /feast-data/<name>/feature_repo/permissions.py.bak

oc exec -n <namespace> $FEAST_POD -c registry -- \
  sed -i 's/prod_namespaces = \[.*\]/prod_namespaces = ["<namespace>"]/' \
  /feast-data/<name>/feature_repo/permissions.py

oc exec -n <namespace> $FEAST_POD -c registry -- \
  sh -c "cd /feast-data/<name>/feature_repo && feast apply"
```
No pod restart is needed — `feast apply` writes directly into `registry.db`, which the running `serve_registry` process reads live.

**This is now automated:** `./rhoai-toolkit.sh` → `deploy_banking_demo` patches this automatically after the Feast pod comes up, and `Diagnose Feature Store`'s automatic-fixes flow (`check_featurestore_rbac_namespace` / `fix_featurestore_rbac_namespace` in `lib/utils/rhoai-version.sh`) detects and fixes it on existing deployments too.

**Caveat:** This patch lives on the PVC-persisted git checkout, not upstream. If `/feast-data` is ever wiped (FeatureStore CR deleted/recreated with a fresh PVC), `feast-init` re-clones from the original repo and the bug reappears. For a fix that survives that, fork the repo, apply the same one-line change, and point `spec.feastProjectDir.git.url` at your fork.

**Verify:**
```bash
curl -sk -H "Authorization: Bearer $(oc whoami -t)" \
  "https://<dashboard-route>/api/featurestores"
# Should list the feature store instead of {"featureStores":[]}
```

---

## Guardrails (NeMo) — University Safeguard Demo

### HAP Detector InferenceService Stuck Not Ready

**Symptom:** `oc get inferenceservice hap-detector -n <namespace>` stays `False`/empty for several minutes after `./demo/university-safeguard-demo/deploy.sh`.

**Cause:** First deploy pulls `ibm-granite/granite-guardian-hap-38m` from the Hugging Face Hub at pod startup (`storageUri: hf://...`) — this can take a few minutes on a cold cluster, even though the model itself is small (38M params).

**Fix:** Just wait — `wait_for_hap_detector` in `lib/functions/university-safeguard.sh` polls for up to 10 minutes. Check progress with:
```bash
oc logs -n <namespace> -l serving.kserve.io/inferenceservice=hap-detector -c kserve-container --tail=50
```

### `hap_alert` Never Appears in Logs Even for Obviously Toxic Input

**Cause:** `check_hap_input`/`check_hap_output` (in the `actions.py` key of the `<name>-config` ConfigMap) call the detector's `/api/v1/text/contents` endpoint directly. If `HAP_DETECTOR_URL` is wrong, or the detector isn't `Ready` yet, the request fails and the action **fails open** (logs a `hap_detector_error` event and returns `False`, so the message is allowed through rather than the pipeline crashing).

**Diagnosis:**
```bash
oc logs -n <namespace> deploy/<guardrails-name> -c nemo-guardrails | grep -E "hap_alert|hap_detector_error"
oc get svc hap-detector-predictor -n <namespace>   # confirm the service name matches HAP_DETECTOR_URL
oc get nemoguardrails <guardrails-name> -n <namespace> -o jsonpath='{.spec.env}'  # confirm HAP_DETECTOR_URL is set
```

**Fix:** Ensure the HAP `InferenceService` is `Ready` before the `NemoGuardrails` CR is applied (the deploy script already sequences this), and that `HAP_DETECTOR_URL` matches the actual predictor service name (`<isvc-name>-predictor.<namespace>.svc.cluster.local`, no path/port suffix needed — the runtime listens on the default KServe port 80/8080 mapping).

### Detection Score/Label Semantics

Verified against a live `granite-guardian-hap-38m` response on `cluster-v5zjc` (2026-09-03): the response shape is `[[{"start", "end", "text", "detection", "detection_type", "score", "evidences", "metadata"}]]`. The actual class label (e.g. `"LABEL_1"` for toxic) is in **`detection_type`** — `detection` is just the algorithm name (`"single_label_classification"`), and `sequence_classification` is not present at all in this runtime's response (despite appearing in some FMS-orchestrator doc examples for other detectors). `_call_hap_detector` in `actions.py` uses `detection_type` accordingly. The `check_hap_*` actions treat any detection with `score >= HAP_THRESHOLD` (default `0.5`) as flagged. If you see false positives/negatives, tune `HAP_THRESHOLD` via the `NemoGuardrails` CR's `spec.env`, or inspect a raw response directly:
```bash
oc run -it --rm debug --image=registry.access.redhat.com/ubi9/ubi-minimal --restart=Never -n <namespace> -- \
  curl -s -X POST "http://hap-detector-predictor.<namespace>.svc.cluster.local/api/v1/text/contents" \
    -H 'Content-Type: application/json' -H 'detector-id: hap-detector' \
    -d '{"contents": ["you are a worthless piece of garbage"], "detector_params": {}}'
```

### `envsubst` Strips Colang `$variable` Syntax (Corrupts `rails.co`)

**Symptom:** `/v1/guardrail/checks` or `/v1/chat/completions` returns `{"status":"error", ..., "details":"Error while parsing Colang file: ... Unknown main token '='..."}` after deploying a custom `rails.co` flow.

**Cause:** `envsubst` with no variable-name argument substitutes **every** `$word`/`${word}` pattern it finds in a file — including Colang's own variable syntax (`$user_message`, `$hap_flagged`, etc.), which aren't shell env vars and so get replaced with empty strings, corrupting the flow definition.

**Fix:** Always call `envsubst` with an explicit, quoted list of only the placeholders you want replaced, e.g. `envsubst '${NAMESPACE} ${GUARDRAILS_NAME} ${MAIN_MODEL_URL}' < file.yaml`. See `deploy_university_guardrails_config()` in `lib/functions/university-safeguard.sh` for the pattern used in this demo.

### NeMo Guardrails Config: `openai_api_base` vs `base_url`

**Symptom:** `{"error":"Could not load guardrails configuration.","details":"Your config uses 0.21-style LangChain conventions ... rename \`openai_api_base\` to \`base_url\`..."}`

**Cause:** The RHOAI 3.5 NeMo Guardrails version (0.23.0+) removed the older LangChain-style `openai_api_base` key. Use `base_url` in `models[*].parameters` instead. (The base `demo/nemo-guardrails-demo/manifests/*-selfcheck-config.yaml` templates still use `openai_api_base` and may need the same fix if used on RHOAI 3.5.)

### External (Non-Cluster) Main Model: `OPENAI_API_KEY` Env Var Alone Doesn't Authenticate

**Symptom:** `/v1/chat/completions` returns a `200` with `"content": "Internal server error"` in the message body; pod logs show `nemoguardrails.exceptions.LLMAuthenticationError: [401] ... Authentication Error, LiteLLM Virtual Key expected. Received=runtime-provided...`.

**Cause:** Omitting `api_key` from `config.yaml`'s `models[main].parameters` and relying solely on the `OPENAI_API_KEY` container env var (sourced from a Secret) did not authenticate correctly against an external LiteLLM/LiteMaaS endpoint on this NeMo Guardrails version.

**Fix:** Set `api_key` explicitly in `config.yaml`, templated via `envsubst` from the same value stored in a Secret at deploy time (see `demo/university-safeguard-demo/manifests/nemo-guardrails-config.yaml`). Known trade-off: the raw key ends up visible via `oc get configmap <name>-config -o yaml` in-cluster (not committed to git).

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

# MaaS diagnostics and E2E verification (see scripts/ for all MaaS tooling)
./scripts/diagnose-maas.sh --fix     # BU guide's 10 post-upgrade issues, with safe auto-fixes
./scripts/verify-maas.sh             # 6-phase E2E: infra health, deploy, API, auth, rate limit, cleanup
./scripts/check-maas-security.sh     # audits models exposed via MaaS gateway with no AuthPolicy/Subscription
./scripts/cleanup-maas.sh --dry-run  # preview full MaaS teardown (reverse-order phases)
```
