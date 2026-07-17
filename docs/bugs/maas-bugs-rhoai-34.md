# MaaS / RHCL Bugs — RHOAI 3.4.0

## Summary

Two bugs in the MaaS platform on RHOAI 3.4.0 affect the Gen AI Studio experience. Bug 1 causes the API Keys page to break every time the Tenant controller reconciles. Bug 2 causes the Observability Usage dashboard to show zero data despite active traffic, due to a CEL expression parsing failure in Authorino.

## Environment

- OpenShift 4.20
- RHOAI 3.4.0 (`rhods-operator.3.4.0`)
- RHCL v1.3.2 (`rhcl-operator.v1.3.2`)
- Authorino: `registry.redhat.io/rhcl-1/authorino-rhel9@sha256:c2208382e16c501e4ed58aea83f54d108567f36853cf79f7ffdf8ee54ff4ace8`
- MaaS controller: `registry.redhat.io/rhoai/odh-maas-controller-rhel9@sha256:6d314a532b4d8342cd5b41f4aa6857242036a8aa636111adfe482cb5c2a5000f`
- Limitador: `limitador-limitador` in `kuadrant-system`
- Models: 2x LLMInferenceService (maas-gpt-oss-20b, maas-qwen35-8b-a3b-fp8) via llm-d
- MaaS Subscription: `tier1` in `models-as-a-service`
- API key auth working, token rate limiting working

---

## Bug 1: Tenant CR `gatewayRef` causes API Keys page "Error loading components"

### Severity: High

### Description

The Gen AI Studio > API Keys page shows "Error loading components — the server encountered a problem and could not process your request." This is a recurring issue that reappears after every Tenant controller reconciliation.

### Root Cause

The `Tenant` CR (`default-tenant` in `models-as-a-service`) is auto-created with `spec.gatewayRef` pointing to `openshift-ai-inference` instead of `maas-default-gateway`:

```yaml
apiVersion: maas.opendatahub.io/v1alpha1
kind: Tenant
metadata:
  name: default-tenant
  namespace: models-as-a-service
spec:
  gatewayRef:
    name: openshift-ai-inference     # ← WRONG — should be maas-default-gateway
    namespace: openshift-ingress
```

The Tenant controller (inside `maas-controller`) reconciles the `maas-api-route` HTTPRoute in `redhat-ods-applications` using this `gatewayRef`. It sets the HTTPRoute's `parentRefs` to only `openshift-ai-inference`.

However, the `maas-ui` sidecar in the dashboard pod auto-discovers the MaaS URL as `https://maas.apps.<cluster>/maas-api/...`, which routes through `maas-default-gateway` (not `openshift-ai-inference`). Since `maas-default-gateway` is not in the HTTPRoute's `parentRefs`, the `/maas-api/*` path gets a 404 from the gateway, and the API Keys page fails to load.

### Evidence

The `maas-controller` deployment is configured with:

```
GATEWAY_NAME: maas-default-gateway
GATEWAY_NAMESPACE: openshift-ingress
```

And passes `--gateway-name=$(GATEWAY_NAME)` to the `/manager` binary. So the maas-controller knows about `maas-default-gateway` and correctly uses it for per-model HTTPRoutes (e.g. `maas-gpt-oss-20b-kserve-route`). But the **Tenant controller** reconciles `maas-api-route` using the Tenant CR's `gatewayRef` — which points to the wrong gateway.

### Steps to Reproduce

1. Install RHOAI 3.4 with MaaS (creates `default-tenant` with `gatewayRef: openshift-ai-inference`)
2. Create `maas-default-gateway` (as required by the MaaS docs)
3. Navigate to Gen AI Studio > API Keys
4. Observe "Error loading components"
5. Check maas-ui logs:
   ```bash
   oc logs $(oc get pods -n redhat-ods-applications -l app=rhods-dashboard --no-headers | grep Running | head -1 | awk '{print $1}') \
     -n redhat-ods-applications -c maas-ui --tail=20
   ```
6. Logs show: `"unknown error when invoking maas-api (unmarshall)" statusCode=404`

### Expected Behavior

The Tenant auto-creation should use the `maas-controller`'s configured `GATEWAY_NAME` (`maas-default-gateway`) rather than hardcoding `openshift-ai-inference`. Alternatively, the Tenant controller should reconcile the `maas-api-route` HTTPRoute with both gateways in `parentRefs`.

### Workaround

Patch the Tenant CR's `gatewayRef` to point to `maas-default-gateway`:

```bash
oc patch tenant default-tenant -n models-as-a-service --type=merge \
  -p '{"spec":{"gatewayRef":{"name":"maas-default-gateway","namespace":"openshift-ingress"}}}'
```

This is a permanent fix — the Tenant controller then reconciles the HTTPRoute correctly. No CronJob or manual patching needed.

### Impact

The API Keys page is completely unusable until the Tenant is patched. This blocks users from creating API keys for MaaS subscriptions. The bug recurs on every fresh RHOAI 3.4 install with MaaS.

---

## Bug 2: Authorino `metricLabels` CEL parsing failure — Usage dashboard shows zero data

### Severity: High

### Description

The Observability Dashboard > Usage tab shows all zeros (Total Tokens: 0, Total Requests: 0, Active Users: 0) despite active traffic flowing through the MaaS gateway. Limitador counters are incrementing correctly, but the Prometheus metric labels (`user`, `subscription`, `model`) are empty, causing the dashboard's PromQL queries (which filter by `user!=""`) to return no data.

### Root Cause

Authorino's `metricLabels` function (`auth_pipeline.go:542`) attempts to re-parse CEL expressions for Prometheus metric label extraction. However, the expressions stored in the AuthConfig are in **compiled AST format** rather than raw CEL strings:

```
Expression { expression: IdedExpr { id: 3, expr: Select(SelectExpr { operand: IdedExpr { id: 2, expr: Select(SelectExpr { operand: IdedExpr { id: 1, expr: Ident("auth") }, field: "identity", test: false }) }, field: "selected_subscription", test: false }) }, attributes: [...], extended: false }
```

The CEL parser fails with: `undeclared reference to 'Expression'`

This happens for every auth-relevant expression:
- `auth.identity.userid` → fails → `user` label empty
- `auth.identity.selected_subscription` → fails → `subscription` label empty
- `auth.identity.subscription_info.costCenter` → fails
- `auth.identity.subscription_info.organizationId` → fails
- `responseBodyJSON("/model")` → fails → `model` label empty

### Evidence

Authorino logs show repeated CEL parse errors on every authenticated request:

```json
{
  "level": "error",
  "ts": "2026-06-18T07:49:10Z",
  "logger": "authorino.service.auth.authpipeline",
  "msg": "failed to parse CEL expression",
  "expression": "Expression { expression: IdedExpr { ... } }",
  "error": "ERROR: <input>:1:12: undeclared reference to 'Expression'"
}
```

Limitador Prometheus metrics have data but with empty labels:

```
authorized_calls{user="", subscription="tier1", limitador_namespace="a-rh-department/maas-gpt-oss-20b-kserve-route"} = 58
authorized_hits{user="", subscription="tier1", limitador_namespace="a-rh-department/maas-gpt-oss-20b-kserve-route"} = 13820
```

The Usage dashboard (`dashboard-3-maas-usage-admin`) uses PromQL queries that filter `user!=""`:

```promql
count(count by (user) (sum by (user, subscription, limitador_namespace) (increase(authorized_calls{user!=""}[1h]))))
```

Since `user` is always empty, all queries return zero.

### Steps to Reproduce

1. Install RHOAI 3.4 with MaaS + RHCL v1.3.2
2. Deploy a model via MaaS (LLMInferenceService + MaaSModelRef + MaaSSubscription)
3. Generate an API key and send requests:
   ```bash
   curl -sk "https://maas.apps.<cluster>/<ns>/<model>/v1/chat/completions" \
     -H "Authorization: Bearer sk-oai-<key>" \
     -H "Content-Type: application/json" \
     -d '{"model":"<model>","messages":[{"role":"user","content":"hi"}],"max_tokens":10}'
   ```
4. Navigate to Observe & Monitor > Dashboard > Usage tab
5. All metrics show 0

### Expected Behavior

Authorino should correctly extract metric labels from the auth identity for Prometheus counters. The compiled CEL expressions in the AuthConfig should be evaluated directly (not re-parsed from their AST string representation).

### Workaround

None at the user level. The bug is in Authorino's internal `metricLabels` function. The auth flow itself works correctly — only the Prometheus metric labels are affected.

The Perses-based "MaaS Gateway Metrics" dashboard (which uses vLLM/kserve metrics instead of Limitador metrics) works correctly and can be used as an alternative for monitoring request rate, latency, and throughput.

### Impact

The entire Usage tab of the Observability Dashboard is non-functional. Administrators cannot see per-user token consumption, subscription utilization, or active user counts. This undermines the MaaS governance story where cost visibility per subscription/user is a key feature.

### Component

- **Affected:** Authorino (`auth_pipeline.go:542`, `metricLabels` function)
- **Shipped in:** RHCL v1.3.2
- **Fix needed in:** Authorino — either evaluate compiled AST directly, or store the original CEL string alongside the compiled form for metric label extraction

---

## Summary Table

| Bug | Component | Severity | Workaround Available | Fix Level |
|-----|-----------|----------|---------------------|-----------|
| 1. Tenant `gatewayRef` → wrong gateway | maas-controller (Tenant reconciler) | High | Yes — patch Tenant CR | MaaS controller / RHOAI |
| 2. Authorino CEL parsing → empty metric labels | Authorino (RHCL v1.3.2) | High | No | RHCL / Authorino |
