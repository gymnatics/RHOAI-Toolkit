# RHOAI 3.3 MaaS UI/CLI Interference Bug Report

## Summary

**Component**: RHOAI Dashboard UI, `odh-model-controller`, Kuadrant Operator  
**Version**: RHOAI 3.3.0 (Tech Preview)  
**Severity**: High - Causes rate limiting to silently fail  
**Status**: Under Investigation - Feedback from Red Hat engineers received

When configuring MaaS tier-based rate limiting, the RHOAI Dashboard UI and CLI/manifest-based configurations interfere with each other, causing rate limiting to silently fail or behave unexpectedly.

---

## Red Hat Engineer Feedback (2026-03-17)

> **Key Insight**: There's a difference between `AuthPolicy`/`TokenRateLimitPolicy` (handled by Kuadrant Operator) and corresponding `AuthConfig` (handled by Authorino) and `Limitador` CR.
>
> Kuadrant Operator should compute "effective policies" by composing multiple policy resources across the Gateway API hierarchy. The downstream services (Authorino, Limitador, etc.) only ever see the final, already-merged result.
>
> Kuadrant's design explicitly supports multiple policies at the same hierarchy level. See: https://github.com/Kuadrant/kuadrant-operator/blob/main/doc/overviews/auth.md#defaults-and-overrides
>
> **The real question is: why aren't the three policies merging?**
>
> The problem may be **implicit defaults with the default atomic strategy**, where one winner takes all. What may be missing is **explicit `strategy: merge`** - which Kuadrant already supports.
>
> **Note**: RHOAI 3.4 has this all re-worked.

---

## SOLUTION: Steps to Get MaaS Tech Preview Functional (from Red Hat Engineer)

**TL;DR** - Follow these steps to get tier-based rate limiting working:

### Step 1: Label the Gateway as NOT managed by RHOAI

```bash
oc label gateway maas-default-gateway -n openshift-ingress \
    opendatahub.io/managed=false --overwrite
```

This prevents RHOAI from overwriting your custom policies.

### Step 2: Remove the conflicting AuthPolicy created by RHOAI

```bash
oc delete authpolicy maas-default-gateway-authn -n openshift-ingress --ignore-not-found
```

This AuthPolicy is created by `odh-model-controller` and overrides the tier lookup.

### Step 3: Verify Authorino TLS Configuration

Ensure Authorino can communicate securely with the MaaS API for tier lookup.

```bash
# Check Authorino is running
oc get pods -n kuadrant-system -l app=authorino

# Check TLS certificates
oc get secret -n kuadrant-system | grep tls
```

### Step 4: Verify AuthPolicies match v0.0.2 tag

Check that `maas-api-auth-policy` and `gateway-auth-policy` are correctly configured:

```bash
# Check gateway-auth-policy has tier lookup
oc get authpolicy gateway-auth-policy -n openshift-ingress -o yaml | grep -A 10 "matchedTier"

# Check maas-api-auth-policy
oc get authpolicy maas-api-auth-policy -n redhat-ods-applications -o yaml | grep -A 10 "matchedTier"
```

### Step 5: Apply TokenRateLimitPolicies for your tiers

Use a combined policy (not individual per-tier policies):

```bash
oc apply -f demo/maas-demo/manifests/tiers/tokenratelimitpolicy.yaml
```

### Step 6: DO NOT use the UI for tier management

> **IMPORTANT**: Do not use the UI to create or manage tiers or their policies. Use the API/CLI for now.

The UI creates conflicting individual policies that override each other.

### Complete Fix Script

```bash
# 1. Label gateway as not managed
oc label gateway maas-default-gateway -n openshift-ingress \
    opendatahub.io/managed=false --overwrite

# 2. Remove conflicting AuthPolicy
oc delete authpolicy maas-default-gateway-authn -n openshift-ingress --ignore-not-found

# 3. Delete any UI-created TokenRateLimitPolicies
oc delete tokenratelimitpolicy tier-free-token-rate-limits \
    tier-premium-token-rate-limits tier-enterprise-token-rate-limits \
    -n openshift-ingress --ignore-not-found

# 4. Apply combined TokenRateLimitPolicy
oc apply -f demo/maas-demo/manifests/tiers/tokenratelimitpolicy.yaml

# 5. Restart components to clear caches
oc rollout restart deployment/authorino -n kuadrant-system
oc rollout restart deployment/limitador-limitador -n kuadrant-system
oc rollout restart deployment/maas-api -n redhat-ods-applications

# 6. Verify
oc get authpolicy -n openshift-ingress
oc get tokenratelimitpolicy -n openshift-ingress
```

---

### Questions to Investigate (Original)

1. **Are the UI-created policies missing `strategy: merge`?** - Check if adding explicit merge strategy resolves the override issue
2. **Why is Limitador empty even with a single combined policy?** - This persists even when using a correctly-structured combined `TokenRateLimitPolicy`
3. **Is this a known issue being addressed in RHOAI 3.4?**

---

## Key Findings (TL;DR)

### Finding 1: UI Creates Separate TokenRateLimitPolicies (Possible Missing Merge Strategy)
- **What happens**: When you configure tiers in the RHOAI Dashboard UI, it creates **separate** `TokenRateLimitPolicy` resources for each tier (e.g., `tier-free-token-rate-limits`, `tier-premium-token-rate-limits`, `tier-enterprise-token-rate-limits`)
- **Observed behavior**: Only ONE policy is enforced; others are marked "Overridden"
- **Possible cause**: Missing explicit `strategy: merge` in the policies, causing default atomic (winner-takes-all) behavior
- **Result**: Only ONE tier has rate limiting; other tiers have UNLIMITED access
- **Evidence**: See [Appendix A1](#a1-tokenratelimitpolicies-ui-created---shows-override-issue)

### Finding 2: WasmPlugin Only Contains One Tier's Rules
- **What happens**: Because only one `TokenRateLimitPolicy` is enforced, the WasmPlugin only contains rate limiting rules for that tier
- **Problem**: Free and Premium tier requests are never rate-limited because their rules aren't in the WasmPlugin
- **Evidence**: See [Appendix A4](#a4-wasmplugin-configuration-shows-only-enterprise-tier)
- **Update**: When using a single combined policy, all three tiers appear in WasmPlugin correctly

### Finding 3: Limitador Has No Limits Configured (CRITICAL - Needs Investigation)
- **What happens**: Despite `TokenRateLimitPolicy` resources existing AND being marked as "Enforced", Limitador shows **empty limits and counters**
- **Problem**: Rate limiting is completely non-functional at the Limitador level
- **Evidence**: See [Appendix A5](#a5-limitador-state-empty)
- **Question from engineer**: "Is it permanent even for the token/user with the right tier?"
- **Answer**: Yes, Limitador remains empty even after:
  - Using a correctly-structured combined `TokenRateLimitPolicy`
  - Restarting Authorino, Limitador, and MaaS API
  - Making multiple requests with valid tier tokens
  - Policy showing as "Enforced" in status

### Finding 4: Token Audience Matters
- **What happens**: The RHOAI-managed `gateway-auth-policy` requires audience `maas-default-gateway-sa`
- **Problem**: Tokens created with audience `https://kubernetes.default.svc` will fail authentication
- **Fix**: Use `oc create token <sa> --audience=maas-default-gateway-sa`

### Potential Fixes to Test

1. **Add explicit `strategy: merge`** to the `TokenRateLimitPolicy` resources
   - Reference: https://github.com/Kuadrant/kuadrant-operator/blob/main/doc/overviews/auth.md#defaults-and-overrides
   - Check if UI-created policies are using implicit defaults with atomic strategy
2. **Check if Kuadrant Operator is correctly pushing limits to Limitador** - The gap between "Enforced" status and empty Limitador suggests a disconnect
3. **Wait for RHOAI 3.4** which has this re-worked

### Investigation Notes

**Re: Finding 3 (Limitador Empty)**

The engineer asked: "Is it permanent even for the token/user with the right tier?"

**Answer**: Yes, we confirmed this is persistent:

```bash
# After applying combined TokenRateLimitPolicy and restarting all components:
$ oc get tokenratelimitpolicy -n openshift-ingress
NAME                          ENFORCED   MESSAGE
maas-tier-token-rate-limits   True       TokenRateLimitPolicy has been successfully enforced

# But Limitador shows nothing:
$ oc exec -n kuadrant-system $LIMITADOR_POD -- curl -s localhost:8080/limits
(empty)

$ oc exec -n kuadrant-system $LIMITADOR_POD -- curl -s localhost:8080/counters
(empty)

# Yet WasmPlugin correctly shows all three tiers:
$ oc get wasmplugin -n openshift-ingress -o yaml | grep -c "auth.identity.tier"
30  # Rules for free, premium, and enterprise tiers are present
```

This suggests a disconnect between:
1. Kuadrant Operator marking the policy as "Enforced"
2. WasmPlugin being correctly configured with tier predicates
3. Limitador actually receiving and storing the rate limits

The rate limiting may be happening at the WasmPlugin/Envoy level with `hits_addend: "0"` for pre-request checks, but the actual token counting (`responseBodyJSON("/usage/total_tokens")`) for post-response reporting doesn't seem to be working.

### Recommended Fix for Red Hat (Original)
The UI should create a **SINGLE combined** `TokenRateLimitPolicy` with all tiers, like this:

```yaml
apiVersion: kuadrant.io/v1alpha1
kind: TokenRateLimitPolicy
metadata:
  name: maas-tier-token-rate-limits
spec:
  targetRef:
    kind: Gateway
    name: maas-default-gateway
  limits:
    free-tokens:
      when:
      - predicate: auth.identity.tier == "free"
      rates:
      - limit: 1000
        window: 1m0s
    premium-tokens:
      when:
      - predicate: auth.identity.tier == "premium"
      rates:
      - limit: 5000
        window: 1m0s
    enterprise-tokens:
      when:
      - predicate: auth.identity.tier == "enterprise"
      rates:
      - limit: 10000
        window: 1m0s
```

---

---

## Problem Description

### Issue 1: Multiple AuthPolicies - Only One Is Enforced

**Symptom**: Tier lookup and rate limiting stop working after model deployment or redeployment.

**Root Cause**: When multiple `AuthPolicy` resources target the same Gateway, Kuadrant only enforces **one** of them based on specificity/priority. The others are marked as "Overridden".

**What Happens**:
1. RHOAI creates `gateway-auth-policy` with tier lookup metadata section
2. When you deploy an `LLMInferenceService`, `odh-model-controller` creates `maas-default-gateway-authn`
3. Both target `maas-default-gateway`
4. `maas-default-gateway-authn` overrides `gateway-auth-policy`
5. The tier lookup (in the overridden policy) never executes
6. `auth.identity.tier` is never set
7. Rate limiting predicates never match

**Evidence**:
```bash
$ oc get authpolicy -n openshift-ingress
NAME                           ENFORCED   MESSAGE
gateway-auth-policy            False      Overridden by [maas-default-gateway-authn]
maas-default-gateway-authn     True       Partially enforced
```

**Impact**: Rate limiting silently fails - all requests succeed regardless of tier limits.

---

### Issue 2: UI Creates Conflicting TokenRateLimitPolicies

**Symptom**: Only one tier's rate limiting works; other tiers have unlimited access.

**Root Cause**: The RHOAI Dashboard UI creates **individual** `TokenRateLimitPolicy` resources per tier, rather than a single combined policy.

**What Happens**:
1. User configures tiers in the RHOAI Dashboard UI
2. UI creates separate policies:
   - `tier-free-token-rate-limits`
   - `tier-premium-token-rate-limits`
   - `tier-enterprise-token-rate-limits`
3. All three target `maas-default-gateway`
4. Kuadrant can only enforce **one** policy per gateway
5. Only the last-created (or highest priority) policy works
6. Other tiers have no rate limiting

**Evidence**:
```bash
$ oc get tokenratelimitpolicy -n openshift-ingress
NAME                              ENFORCED
tier-free-token-rate-limits       False      # Overridden
tier-premium-token-rate-limits    False      # Overridden
tier-enterprise-token-rate-limits True       # Only this one works
```

**Impact**: Users in Free and Premium tiers get unlimited access (Enterprise tier limits).

---

### Issue 3: CLI-Configured Limits Don't Appear in UI

**Symptom**: Rate limits configured via CLI/manifests are not visible in the RHOAI Dashboard.

**Root Cause**: The RHOAI Dashboard reads tier configuration from the `tier-to-group-mapping` ConfigMap, which only stores **group membership**, not rate limits. The actual rate limits are stored in `TokenRateLimitPolicy` resources, which the UI doesn't read.

**What Happens**:
1. User applies `TokenRateLimitPolicy` via CLI with limits (e.g., 1000/5000/10000 tokens)
2. Dashboard shows "No token limits" for all tiers
3. User assumes rate limiting isn't configured
4. User configures limits in UI, creating conflicting policies
5. Rate limiting breaks (see Issue 2)

**Evidence**:
```bash
# CLI shows limits are configured
$ oc get tokenratelimitpolicy maas-tier-token-rate-limits -n openshift-ingress -o yaml
spec:
  limits:
    free-tokens:
      rates:
        - limit: 1000
          window: 1m0s
    # ...

# But UI shows "No token limits" because it reads from:
$ oc get configmap tier-to-group-mapping -n redhat-ods-applications -o yaml
data:
  tiers: |
    - name: free
      groups: [...]
      # No "limit" field - UI can't display it
```

**Impact**: Users are misled into thinking rate limiting isn't configured, leading to accidental overwrites.

---

### Issue 4: UI Overwrites CLI Configuration

**Symptom**: After editing tiers in the UI, CLI-configured rate limiting stops working.

**Root Cause**: When you save tier configuration in the UI, it:
1. Overwrites the `tier-to-group-mapping` ConfigMap
2. Creates new individual `TokenRateLimitPolicy` resources
3. These new policies override any existing combined policy

**What Happens**:
1. Admin configures rate limiting via CLI with a single combined `TokenRateLimitPolicy`
2. Rate limiting works correctly
3. Another user opens the Dashboard and edits tier groups
4. UI creates individual `TokenRateLimitPolicy` resources
5. Combined policy is overridden
6. Rate limiting breaks

**Impact**: Configuration drift between UI and CLI causes unpredictable behavior.

---

## Reproduction Steps

### Reproduce Issue 1 (AuthPolicy Override)

```bash
# 1. Check initial state - gateway-auth-policy should be enforced
oc get authpolicy -n openshift-ingress

# 2. Deploy a model
oc apply -f - <<EOF
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: test-model
  namespace: maas-demo
  annotations:
    alpha.maas.opendatahub.io/published: "true"
spec:
  model:
    name: test-model
    uri: oci://quay.io/example/model:latest
EOF

# 3. Check AuthPolicies again - gateway-auth-policy is now overridden
oc get authpolicy -n openshift-ingress
# gateway-auth-policy shows "Overridden by [maas-default-gateway-authn]"
```

### Reproduce Issue 2 (Conflicting TokenRateLimitPolicies)

```bash
# 1. Apply a combined TokenRateLimitPolicy via CLI
oc apply -f demo/maas-demo/manifests/tiers/tokenratelimitpolicy.yaml

# 2. Verify it's enforced
oc get tokenratelimitpolicy -n openshift-ingress
# maas-tier-token-rate-limits shows ENFORCED=True

# 3. Open RHOAI Dashboard → Models as a Service → Tiers
# 4. Edit any tier and click Save

# 5. Check TokenRateLimitPolicies again
oc get tokenratelimitpolicy -n openshift-ingress
# Now you'll see:
# - tier-free-token-rate-limits
# - tier-premium-token-rate-limits  
# - tier-enterprise-token-rate-limits
# - maas-tier-token-rate-limits (now ENFORCED=False, overridden)
```

### Reproduce Issue 3 (CLI Limits Not in UI)

```bash
# 1. Apply TokenRateLimitPolicy with specific limits
cat <<EOF | oc apply -f -
apiVersion: kuadrant.io/v1alpha1
kind: TokenRateLimitPolicy
metadata:
  name: maas-tier-token-rate-limits
  namespace: openshift-ingress
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: maas-default-gateway
  limits:
    free-tokens:
      rates:
        - limit: 1000
          window: 1m0s
EOF

# 2. Open RHOAI Dashboard → Models as a Service → Tiers
# 3. Observe: UI shows "No token limits" for Free tier
# 4. The actual limit (1000 tokens/min) is not displayed
```

---

## Expected vs Actual Behavior

| Scenario | Expected | Actual |
|----------|----------|--------|
| Deploy model | Existing AuthPolicy remains enforced | New AuthPolicy overrides existing one |
| Configure tiers in UI | Single combined policy created | Individual policies created (conflict) |
| View CLI-configured limits in UI | Limits displayed correctly | "No token limits" shown |
| Edit tiers in UI after CLI config | CLI config preserved | CLI config overwritten |

---

## Workarounds

### Workaround for Issue 1 (AuthPolicy Override)

After every model deployment, re-apply the tier lookup fix:

```bash
# Apply AuthPolicy with tier lookup
oc apply -f demo/maas-demo/manifests/authpolicy-with-tier-lookup.yaml

# Patch to include username
oc patch authpolicy maas-default-gateway-authn -n openshift-ingress --type=merge -p '{"spec":{"rules":{"metadata":{"matchedTier":{"http":{"body":{"expression":"{ \"groups\": auth.identity.user.groups + [auth.identity.user.username] }"}}}}}}}'
```

### Workaround for Issue 2 (Conflicting Policies)

Delete UI-created policies and use only the combined policy:

```bash
# Delete UI-created policies
oc delete tokenratelimitpolicy tier-free-token-rate-limits tier-premium-token-rate-limits tier-enterprise-token-rate-limits -n openshift-ingress --ignore-not-found

# Apply combined policy
oc apply -f demo/maas-demo/manifests/tiers/tokenratelimitpolicy.yaml
```

### Workaround for Issues 3 & 4 (UI/CLI Sync)

**Option A**: Use CLI only, ignore UI tier display
- Configure all rate limiting via CLI
- Accept that UI won't show correct limits
- Document limits elsewhere (README, wiki)

**Option B**: Use UI only, don't use CLI
- Configure all tiers via Dashboard UI
- Don't apply any `TokenRateLimitPolicy` via CLI
- Accept UI's individual policy approach (only one tier works properly)

**Neither option is ideal.**

---

## Root Cause Analysis

### Design Issues

1. **No policy merging**: Kuadrant doesn't merge multiple policies targeting the same resource; it picks one winner
2. **UI creates individual policies**: Should create a single combined policy like CLI approach
3. **UI doesn't read TokenRateLimitPolicy**: Only reads ConfigMap, missing actual limits
4. **No bidirectional sync**: Changes in one interface don't reflect in the other
5. **Silent failures**: Overridden policies don't generate warnings or errors

### Architecture Gap

```
┌─────────────────────────────────────────────────────────────────┐
│                        RHOAI Dashboard UI                        │
│  ┌─────────────────┐                    ┌─────────────────────┐ │
│  │ Reads from:     │                    │ Writes to:          │ │
│  │ - ConfigMap     │                    │ - ConfigMap         │ │
│  │   (groups only) │                    │ - Individual        │ │
│  │                 │                    │   TokenRateLimitPolicy│
│  └─────────────────┘                    └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              ↕ NO SYNC ↕
┌─────────────────────────────────────────────────────────────────┐
│                           CLI / Manifests                        │
│  ┌─────────────────┐                    ┌─────────────────────┐ │
│  │ Reads from:     │                    │ Writes to:          │ │
│  │ - TokenRateLimit│                    │ - Combined          │ │
│  │   Policy        │                    │   TokenRateLimitPolicy│
│  │ - AuthPolicy    │                    │ - AuthPolicy        │ │
│  └─────────────────┘                    └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Recommendations for Red Hat

### Short-term Fixes

1. **UI should create a single combined TokenRateLimitPolicy** instead of individual per-tier policies
2. **UI should read limits from TokenRateLimitPolicy** resources, not just ConfigMap
3. **Warning when policies are overridden**: Alert users when their policy is not being enforced
4. **odh-model-controller should preserve tier lookup**: When creating `maas-default-gateway-authn`, include the metadata section for tier lookup

### Long-term Fixes

1. **Bidirectional sync**: UI and CLI should read/write the same resources
2. **Policy merging**: Kuadrant should support merging multiple policies targeting the same resource
3. **Single source of truth**: All tier configuration (groups AND limits) should be in one place

---

## Diagnostic Commands

```bash
# Check which AuthPolicy is enforced
oc get authpolicy -n openshift-ingress -o custom-columns='NAME:.metadata.name,ENFORCED:.status.conditions[?(@.type=="Enforced")].status,MESSAGE:.status.conditions[?(@.type=="Enforced")].message'

# Check which TokenRateLimitPolicy is enforced
oc get tokenratelimitpolicy -n openshift-ingress -o custom-columns='NAME:.metadata.name,ENFORCED:.status.conditions[?(@.type=="Enforced")].status'

# Check for UI-created policies
oc get tokenratelimitpolicy -n openshift-ingress -o name | grep -E "tier-(free|premium|enterprise)"

# Check tier-to-group-mapping ConfigMap
oc get configmap tier-to-group-mapping -n redhat-ods-applications -o yaml

# Check actual rate limits in Limitador
oc get limitador limitador -n kuadrant-system -o jsonpath='{.spec.limits}' | python3 -m json.tool
```

---

## Related Documentation

- [MAAS-TIER-RATE-LIMITING-FIX.md](./MAAS-TIER-RATE-LIMITING-FIX.md) - Complete fix procedure
- [MAAS-UI-VISIBILITY-BUG.md](./MAAS-UI-VISIBILITY-BUG.md) - Model visibility issue
- [Kuadrant Policy Attachment](https://docs.kuadrant.io/latest/kuadrant-operator/doc/overviews/policy-attachment/) - How policy targeting works

---

## Version Information

```
Date: 2026-03-17
RHOAI Version: 3.3.0
OpenShift Version: 4.19+
Kuadrant Version: 1.3+
Red Hat Connectivity Link: 1.3+
Authorino Operator: 1.3.0
Limitador Operator: 1.3.0
```

---

## Appendix: Collected Configuration Data (2026-03-17 07:41 UTC)

This section contains the actual YAML exports from a live cluster demonstrating the issues.

### A1. TokenRateLimitPolicies (UI-Created - Shows Override Issue)

The RHOAI Dashboard UI created three separate `TokenRateLimitPolicy` resources. Only `tier-enterprise-token-rate-limits` (the last created) is enforced. The other two are overridden.

```yaml
apiVersion: v1
items:
- apiVersion: kuadrant.io/v1alpha1
  kind: TokenRateLimitPolicy
  metadata:
    creationTimestamp: "2026-03-17T07:25:22Z"
    labels:
      opendatahub.io/dashboard: "true"
    name: tier-enterprise-token-rate-limits
    namespace: openshift-ingress
  spec:
    limits:
      enterprise-tokens:
        counters:
        - expression: auth.identity.userid
        rates:
        - limit: 10000
          window: 1m0s
        when:
        - predicate: auth.identity.tier == "enterprise" && !request.path.endsWith("/v1/models")
    targetRef:
      group: gateway.networking.k8s.io
      kind: Gateway
      name: maas-default-gateway
  status:
    conditions:
    - message: TokenRateLimitPolicy has been accepted
      status: "True"
      type: Accepted
    - message: TokenRateLimitPolicy has been successfully enforced
      reason: Enforced
      status: "True"          # <-- ONLY THIS ONE IS ENFORCED
      type: Enforced

- apiVersion: kuadrant.io/v1alpha1
  kind: TokenRateLimitPolicy
  metadata:
    creationTimestamp: "2026-03-17T07:24:36Z"
    labels:
      opendatahub.io/dashboard: "true"
    name: tier-free-token-rate-limits
    namespace: openshift-ingress
  spec:
    limits:
      free-tokens:
        counters:
        - expression: auth.identity.userid
        rates:
        - limit: 1000
          window: 1m0s
        when:
        - predicate: auth.identity.tier == "free" && !request.path.endsWith("/v1/models")
    targetRef:
      group: gateway.networking.k8s.io
      kind: Gateway
      name: maas-default-gateway
  status:
    conditions:
    - message: TokenRateLimitPolicy has been accepted
      status: "True"
      type: Accepted
    - message: "TokenRateLimitPolicy is overridden by [openshift-ingress/tier-free-token-rate-limits openshift-ingress/tier-premium-token-rate-limits openshift-ingress/tier-enterprise-token-rate-limits]"
      reason: Overridden
      status: "False"         # <-- OVERRIDDEN - NOT ENFORCED
      type: Enforced

- apiVersion: kuadrant.io/v1alpha1
  kind: TokenRateLimitPolicy
  metadata:
    creationTimestamp: "2026-03-17T07:24:55Z"
    labels:
      opendatahub.io/dashboard: "true"
    name: tier-premium-token-rate-limits
    namespace: openshift-ingress
  spec:
    limits:
      premium-tokens:
        counters:
        - expression: auth.identity.userid
        rates:
        - limit: 5000
          window: 1m0s
        when:
        - predicate: auth.identity.tier == "premium" && !request.path.endsWith("/v1/models")
    targetRef:
      group: gateway.networking.k8s.io
      kind: Gateway
      name: maas-default-gateway
  status:
    conditions:
    - message: TokenRateLimitPolicy has been accepted
      status: "True"
      type: Accepted
    - message: "TokenRateLimitPolicy is overridden by [openshift-ingress/tier-free-token-rate-limits openshift-ingress/tier-premium-token-rate-limits openshift-ingress/tier-enterprise-token-rate-limits]"
      reason: Overridden
      status: "False"         # <-- OVERRIDDEN - NOT ENFORCED
      type: Enforced
kind: List
```

**Key Observation**: All three policies target the same Gateway (`maas-default-gateway`). Despite having different predicates (`auth.identity.tier == "free"` vs `"premium"` vs `"enterprise"`), Kuadrant only enforces ONE policy. The last-created policy wins.

### A2. AuthPolicies (Shows Multiple Policy Conflict)

```yaml
apiVersion: v1
items:
# RHOAI-managed policy (enforced)
- apiVersion: kuadrant.io/v1
  kind: AuthPolicy
  metadata:
    annotations:
      platform.opendatahub.io/version: 3.3.0
    name: gateway-auth-policy
    namespace: openshift-ingress
    ownerReferences:
    - kind: ModelsAsService
      name: default-modelsasservice
  spec:
    rules:
      authentication:
        service-accounts:
          kubernetesTokenReview:
            audiences:
            - maas-default-gateway-sa    # <-- Requires this audience
      metadata:
        matchedTier:
          http:
            body:
              expression: '{ "groups": auth.identity.user.groups }'
            url: https://maas-api.redhat-ods-applications.svc.cluster.local:8443/v1/tiers/lookup
      response:
        success:
          filters:
            identity:
              json:
                properties:
                  tier:
                    expression: auth.metadata.matchedTier["tier"]
  status:
    conditions:
    - message: AuthPolicy has been partially enforced
      status: "True"
      type: Enforced

# odh-model-controller created policy (overridden)
- apiVersion: kuadrant.io/v1
  kind: AuthPolicy
  metadata:
    labels:
      app.kubernetes.io/managed-by: odh-model-controller
    name: maas-default-gateway-authn
    namespace: openshift-ingress
  spec:
    rules:
      authentication:
        kubernetes-user:
          kubernetesTokenReview:
            audiences:
            - https://kubernetes.default.svc
      metadata:
        matchedTier:
          http:
            body:
              expression: '{ "groups": auth.identity.user.groups + [auth.identity.user.username] }'
            url: https://maas-api.redhat-ods-applications.svc.cluster.local:8443/v1/tiers/lookup
  status:
    conditions:
    - message: "AuthPolicy is overridden by [redhat-ods-applications/maas-api-auth-policy openshift-ingress/gateway-auth-policy]"
      status: "False"
      type: Enforced

# MaaS API policy (enforced for /v1/models and /maas-api routes)
- apiVersion: kuadrant.io/v1
  kind: AuthPolicy
  metadata:
    name: maas-api-auth-policy
    namespace: redhat-ods-applications
  spec:
    rules:
      authentication:
        openshift-identities:
          kubernetesTokenReview:
            audiences:
            - https://kubernetes.default.svc
            - maas-default-gateway-sa
      metadata:
        matchedTier:
          http:
            body:
              expression: '{ "groups": auth.identity.user.groups + [auth.identity.user.username] }'
    targetRef:
      kind: HTTPRoute
      name: maas-api-route
  status:
    conditions:
    - message: AuthPolicy has been successfully enforced
      status: "True"
      type: Enforced
kind: List
```

### A3. tier-to-group-mapping ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tier-to-group-mapping
  namespace: redhat-ods-applications
  labels:
    app.opendatahub.io/modelsasservice: "true"
data:
  tiers: |
    - name: enterprise
      displayName: Enterprise Tier
      groups:
        - enterprise-users
      level: 2
    - name: premium
      displayName: Premium Tier
      groups:
        - premium-users
      level: 1
    - name: free
      displayName: Free Tier
      groups:
        - system:authenticated
      level: 0
    - name: my-dedicated
      displayName: my-dedicated
      groups:
        - enterprise-users
      level: 3
```

**Note**: The ConfigMap only stores group membership, NOT rate limits. This is why the UI cannot display CLI-configured limits.

### A4. WasmPlugin Configuration (Shows Only Enterprise Tier)

The WasmPlugin only contains rate limiting rules for the `enterprise` tier because only `tier-enterprise-token-rate-limits` is enforced:

```yaml
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: kuadrant-maas-default-gateway
  namespace: openshift-ingress
spec:
  pluginConfig:
    actionSets:
    - actions:
      - scope: ...
        service: auth-service
      # ONLY enterprise tier rate limiting is present
      - conditionalData:
        - data:
          - expression:
              key: tokenlimit.enterprise_tokens__46347922
              value: "1"
          - expression:
              key: auth.identity.userid
              value: auth.identity.userid
          - expression:
              key: ratelimit.hits_addend
              value: "0"
          predicates:
          - auth.identity.tier == "enterprise" && !request.path.endsWith("/v1/models")
        service: ratelimit-check-service
        sources:
        - tokenratelimitpolicy.kuadrant.io:openshift-ingress/tier-enterprise-token-rate-limits
      # ... (no free or premium tier rules)
```

**Key Observation**: The WasmPlugin does NOT contain rules for `free` or `premium` tiers because their `TokenRateLimitPolicy` resources are overridden and not enforced.

### A5. Limitador State (Empty)

```bash
$ oc exec -n kuadrant-system $LIMITADOR_POD -- curl -s localhost:8080/limits
# (empty response)

$ oc exec -n kuadrant-system $LIMITADOR_POD -- curl -s localhost:8080/counters
# (empty response)
```

**Key Observation**: Limitador has no limits configured and no counters, indicating that rate limiting is not functioning at all despite the `TokenRateLimitPolicy` resources being created.

### A6. LLMInferenceService (Model Configuration)

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  annotations:
    alpha.maas.opendatahub.io/published: "true"
    alpha.maas.opendatahub.io/tiers: '["free", "premium", "enterprise"]'
    security.opendatahub.io/enable-auth: "true"
  name: qwen3-4b
  namespace: maas-demo
spec:
  model:
    name: qwen3-4b
    uri: oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b
  router:
    gateway:
      refs:
      - name: maas-default-gateway
        namespace: openshift-ingress
status:
  conditions:
  - status: "True"
    type: Ready
  url: https://maas-api.apps.cluster-zhjng.zhjng.sandbox1867.opentlc.com/maas-demo/qwen3-4b
```

### A7. OpenShift Groups

```yaml
apiVersion: v1
items:
- apiVersion: user.openshift.io/v1
  kind: Group
  metadata:
    name: enterprise-users
  users:
  - b64:system:serviceaccount:maas-demo:tier-enterprise-sa
- apiVersion: user.openshift.io/v1
  kind: Group
  metadata:
    name: premium-users
  users:
  - b64:system:serviceaccount:maas-demo:tier-premium-sa
kind: List
```

**Note**: ServiceAccount usernames containing colons must use the `b64:` prefix in OpenShift Groups.

### A8. Test Results Summary

```bash
# All tiers return HTTP 200 - NO rate limiting is applied
=== Test FREE tier ===
Request 1: HTTP 200
Request 2: HTTP 200
Request 3: HTTP 200
Request 4: HTTP 200

=== Test PREMIUM tier ===
Request 1: HTTP 200
Request 2: HTTP 200
Request 3: HTTP 200
Request 4: HTTP 200

=== Test ENTERPRISE tier ===
Request 1: HTTP 200
Request 2: HTTP 200
Request 3: HTTP 200
Request 4: HTTP 200
```

**Conclusion**: Despite having `TokenRateLimitPolicy` resources configured with limits (Free: 1000, Premium: 5000, Enterprise: 10000 tokens/minute), NO rate limiting is being applied to ANY tier.
