# RHOAI 3.3 MaaS Tier-Based Rate Limiting - Issue and Solution

## Executive Summary

This document describes a critical issue with RHOAI 3.3 MaaS (Models as a Service) where tier-based rate limiting was not working, and the step-by-step solution to fix it.

**Problem**: Tier-based rate limiting (free/premium/enterprise) was not being enforced despite correct `TokenRateLimitPolicy` configuration.

**Root Cause**: The `odh-model-controller` creates an AuthPolicy that overrides the original `gateway-auth-policy` which contains the tier lookup logic.

**Solution**: Patch the enforced AuthPolicy to include the tier lookup metadata section.

---

## Table of Contents

1. [Background: How MaaS Tier System Works](#background-how-maas-tier-system-works)
2. [The Problem](#the-problem)
3. [Investigation Process](#investigation-process)
4. [Root Cause Analysis](#root-cause-analysis)
5. [The Solution](#the-solution)
6. [Verification](#verification)
7. [Permanent Fix](#permanent-fix)

---

## Background: How MaaS Tier System Works

### RHOAI 3.3 MaaS Architecture

RHOAI 3.3 introduces Models as a Service (MaaS), which provides:
- Centralized API gateway for model serving
- Authentication via Kubernetes tokens
- Authorization via RBAC
- **Tier-based rate limiting** (the focus of this document)

### The Three Gateways

RHOAI 3.3 creates three Gateway API gateways:

| Gateway | Purpose | Used By |
|---------|---------|---------|
| `data-science-gateway` | General RHOAI services | Dashboard, OAuth, Notebooks |
| `maas-default-gateway` | MaaS API | LLMInferenceService models |
| `openshift-ai-inference` | Standard KServe | InferenceService (non-MaaS) |

### Tier System Design

**1. User Tier Assignment (based on OpenShift groups)**

Configured in `tier-to-group-mapping` ConfigMap:

```yaml
# oc get configmap tier-to-group-mapping -n redhat-ods-applications -o yaml
data:
  tiers: |
    - name: free
      displayName: Free Tier
      groups:
        - system:authenticated      # All authenticated users
        - tier-free-users
      level: 0
    - name: premium
      displayName: Premium Tier
      groups:
        - tier-premium-users
        - premium-group
      level: 1
    - name: enterprise
      displayName: Enterprise Tier
      groups:
        - tier-enterprise-users
        - enterprise-group
        - admin-group
      level: 2
```

Users get the **highest tier** they qualify for based on group membership.

**2. Model Tier Assignment (which tiers can access the model)**

Set via annotation on `LLMInferenceService`:

```yaml
metadata:
  annotations:
    alpha.maas.opendatahub.io/tiers: '["free","premium","enterprise"]'
```

**3. Rate Limiting (tokens per hour per tier)**

Configured via `TokenRateLimitPolicy`:

| Tier | Token Limit | Window |
|------|-------------|--------|
| Free | 10,000 | 1 hour |
| Premium | 50,000 | 1 hour |
| Enterprise | 100,000 | 1 hour |

### Expected Flow

```
User Request
    ↓
1. Authentication (Kubernetes TokenReview)
    ↓
2. Get user's groups from token
    ↓
3. Call maas-api /v1/tiers/lookup with groups
    ↓
4. maas-api returns user's tier (e.g., "free")
    ↓
5. Tier injected into auth.identity.tier
    ↓
6. TokenRateLimitPolicy evaluates: auth.identity.tier == "free"
    ↓
7. Rate limit applied (10,000 tokens/hour for free tier)
```

---

## The Problem

### Symptoms

1. **Rate limiting not enforced**: Users could make unlimited requests without hitting rate limits
2. **MaaS UI not showing models**: The "Models as a service" tab showed "MaaS service is not available"
3. **Tier predicates not matching**: `TokenRateLimitPolicy` with `auth.identity.tier == "free"` never triggered

### Initial Observations

```bash
# TokenRateLimitPolicy was configured correctly
$ oc get tokenratelimitpolicy -n openshift-ingress
NAME                          AGE
maas-tier-token-rate-limits   2h

# Policy showed as "Enforced"
$ oc get tokenratelimitpolicy maas-tier-token-rate-limits -n openshift-ingress -o yaml
status:
  conditions:
  - type: Enforced
    status: "True"
```

But rate limits were never applied - requests always succeeded regardless of token count.

---

## Investigation Process

### Step 1: Verify Limitador Configuration

Checked if rate limits were configured in Limitador (the rate limiting component):

```bash
$ oc exec -n kuadrant-system deploy/limitador-limitador -- \
    cat /home/limitador/etc/limitador-config.yaml
```

**Finding**: Limits were configured correctly with conditions like:
```yaml
- conditions:
  - descriptors[0]["tokenlimit.free_tokens__b1c0e086"] == "1"
  max_value: 10000
  name: free-tokens
  seconds: 3600
```

The condition `tokenlimit.free_tokens__b1c0e086 == "1"` is set when the `when` predicate in `TokenRateLimitPolicy` matches.

### Step 2: Check AuthPolicy Configuration

```bash
$ oc get authpolicy -n openshift-ingress
NAME                           ENFORCED   MESSAGE
gateway-auth-policy            False      Overridden by [maas-default-gateway-authn]
maas-default-gateway-authn     True       Partially enforced
```

**Critical Finding**: `gateway-auth-policy` was being **overridden**!

### Step 3: Compare the Two AuthPolicies

**gateway-auth-policy** (NOT enforced - has tier lookup):
```yaml
spec:
  rules:
    authentication:
      service-accounts:
        kubernetesTokenReview:
          audiences: [maas-default-gateway-sa]
    authorization:
      tier-access:
        kubernetesSubjectAccessReview: {...}
    metadata:
      matchedTier:                              # ← TIER LOOKUP
        http:
          url: https://maas-api.../v1/tiers/lookup
          method: POST
          body:
            expression: '{ "groups": auth.identity.user.groups }'
    response:
      success:
        filters:
          identity:
            json:
              properties:
                tier:
                  expression: auth.metadata.matchedTier["tier"]  # ← TIER INJECTION
```

**maas-default-gateway-authn** (ENFORCED - NO tier lookup):
```yaml
spec:
  rules:
    authentication:
      kubernetes-user:
        kubernetesTokenReview:
          audiences: [https://kubernetes.default.svc]
    authorization:
      inference-access:
        kubernetesSubjectAccessReview: {...}
    # NO metadata section - NO tier lookup!
    # NO response section - NO tier injection!
```

### Step 4: Verify Tier Lookup Works

Tested the `maas-api` tier lookup endpoint directly:

```bash
$ TOKEN=$(oc create token default -n maas-demo --audience="https://kubernetes.default.svc")
$ curl -sk https://maas-api.../v1/tiers/lookup \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"groups": ["system:authenticated"]}'

{"tier":"free","displayName":"Free Tier"}
```

**Finding**: The tier lookup endpoint works! The problem is that it's never being called.

---

## Root Cause Analysis

### The Override Problem

When you deploy an `LLMInferenceService`, the `odh-model-controller` automatically creates an AuthPolicy named `maas-default-gateway-authn`. This policy:

1. Targets the same gateway (`maas-default-gateway`)
2. Has a **later creation timestamp**
3. **Overrides** the original `gateway-auth-policy`

```bash
$ oc get authpolicy -n openshift-ingress -o custom-columns='NAME:.metadata.name,CREATED:.metadata.creationTimestamp'
NAME                           CREATED
gateway-auth-policy            2026-03-11T09:13:46Z   # Original (has tier lookup)
maas-default-gateway-authn     2026-03-16T06:19:54Z   # Created by odh-model-controller
```

### Why This Happens

The `odh-model-controller` creates the AuthPolicy to handle:
- Authentication (Kubernetes TokenReview)
- Authorization (SubjectAccessReview for model access)

But it does **NOT** include:
- Tier lookup (metadata section)
- Tier injection (response section)

### The Missing Piece

Without the metadata and response sections, the tier is never resolved:

```
TokenRateLimitPolicy predicate: auth.identity.tier == "free"
                                        ↑
                                   This is NULL!
                                   (tier never injected)
                                        ↓
                               Predicate never matches
                                        ↓
                               Rate limit never applied
```

---

## The Solution

### Patch the Enforced AuthPolicy

Add the tier lookup metadata and response sections to `maas-default-gateway-authn`:

```yaml
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: maas-default-gateway-authn
  namespace: openshift-ingress
  labels:
    app.kubernetes.io/component: llminferenceservice-policies
    app.kubernetes.io/managed-by: odh-model-controller
    app.kubernetes.io/name: llminferenceservice-auth
    app.kubernetes.io/part-of: llminferenceservice
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: maas-default-gateway
  rules:
    authentication:
      kubernetes-user:
        kubernetesTokenReview:
          audiences:
          - https://kubernetes.default.svc
        credentials: {}
        defaults:
          userid:
            expression: auth.identity.user.username
    authorization:
      inference-access:
        kubernetesSubjectAccessReview:
          authorizationGroups:
            expression: auth.identity.user.groups
          resourceAttributes:
            group:
              value: serving.kserve.io
            name:
              expression: request.path.split("/")[2]
            namespace:
              expression: request.path.split("/")[1]
            resource:
              value: llminferenceservices
            verb:
              value: get
          user:
            expression: auth.identity.user.username
        priority: 1
    # ============ ADDED SECTION: Tier Lookup ============
    metadata:
      matchedTier:
        http:
          url: https://maas-api.redhat-ods-applications.svc.cluster.local:8443/v1/tiers/lookup
          method: POST
          contentType: application/json
          body:
            expression: '{ "groups": auth.identity.user.groups }'
        cache:
          key:
            selector: auth.identity.user.username
          ttl: 300
    # ============ ADDED SECTION: Tier Injection ============
    response:
      success:
        filters:
          identity:
            json:
              properties:
                tier:
                  expression: auth.metadata.matchedTier["tier"]
                userid:
                  expression: auth.identity.user.username
```

### Apply the Fix

```bash
# Apply the patched AuthPolicy
$ oc apply -f demo/maas-demo/manifests/authpolicy-with-tier-lookup.yaml

# Verify it's enforced
$ oc get authpolicy maas-default-gateway-authn -n openshift-ingress
NAME                         ENFORCED
maas-default-gateway-authn   True
```

### Configure TokenRateLimitPolicy

```yaml
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

---

## Verification

### Test Rate Limiting

```bash
# Create a token
TOKEN=$(oc create token default -n maas-demo --audience="https://kubernetes.default.svc" --duration=1h)

# Make requests until rate limited
for i in {1..5}; do
  echo "Request $i:"
  curl -sk --resolve "maas-api.apps...:443:$(oc get svc -n openshift-ingress maas-default-gateway-openshift-gateway-controller -o jsonpath='{.spec.clusterIP}')" \
    "https://maas-api.apps.../maas-demo/qwen3-4b/v1/chat/completions" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"model":"qwen3-4b","messages":[{"role":"user","content":"Hi"}],"max_tokens":30}' \
    -w "\nHTTP Status: %{http_code}\n"
done
```

### Expected Results

With free tier (100 tokens/min for testing):
```
Request 1: HTTP Status: 200 (41 tokens)
Request 2: HTTP Status: 200 (41 tokens)
Request 3: HTTP Status: 200 (41 tokens)
Request 4: HTTP Status: 429 *** RATE LIMITED ***
```

### Verify Tier Resolution

Check Authorino logs to see tier being resolved:
```bash
$ oc logs -l app=authorino -n kuadrant-system | grep -i tier
```

---

## Additional Issues Discovered

### Issue 2: TokenReview Doesn't Return OpenShift Groups

**Problem**: Kubernetes TokenReview only returns system groups (`system:serviceaccounts`, `system:authenticated`), NOT OpenShift groups like `tier-premium-users`.

**Impact**: The tier lookup receives groups like `["system:serviceaccounts", "system:serviceaccounts:maas-demo", "system:authenticated"]`, which always matches the Free tier (since `system:authenticated` is in Free tier).

**Root Cause**: OpenShift groups are a separate concept from Kubernetes RBAC groups. When you create an OpenShift group and add a user, that membership is NOT reflected in the Kubernetes TokenReview response.

**Solution**: Update `tier-to-group-mapping` ConfigMap to use ServiceAccount usernames as "groups":

```yaml
# Instead of OpenShift group names, use SA usernames
# The maas-api will match the username against these "groups"
data:
  tiers: |
    # Enterprise tier - check first (highest level)
    - name: enterprise
      displayName: Enterprise Tier
      groups:
        - system:serviceaccount:maas-demo:tier-enterprise-sa
      level: 2
    # Premium tier
    - name: premium
      displayName: Premium Tier
      groups:
        - system:serviceaccount:maas-demo:tier-premium-sa
      level: 1
    # Free tier - default (lowest level, checked last)
    - name: free
      displayName: Free Tier
      groups:
        - system:serviceaccount:maas-demo:tier-free-sa
        - system:authenticated  # Fallback for all authenticated users
      level: 0
```

**Important**: The order matters! Higher-level tiers must be listed first because the maas-api returns the first matching tier.

### Issue 3: AuthPolicy Doesn't Send Username to Tier Lookup

**Problem**: The AuthPolicy only sends `auth.identity.user.groups` to the tier lookup, but the username is needed to match SA-specific tier mappings.

**Why This Happens**: The default AuthPolicy body expression is:
```
{ "groups": auth.identity.user.groups }
```

This sends groups like `["system:serviceaccounts", "system:serviceaccounts:maas-demo", "system:authenticated"]` but NOT the username `system:serviceaccount:maas-demo:tier-premium-sa`.

**Solution**: Patch AuthPolicy to include username in the groups array:

```bash
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
```

**Better Solution**: Use the pre-configured AuthPolicy manifest that includes this fix:

```bash
oc apply -f demo/maas-demo/manifests/authpolicy-with-tier-lookup.yaml
```

This manifest includes:
1. Metadata section for tier lookup
2. Response section for tier injection
3. Username included in groups array

### Issue 4: UI Creates Conflicting TokenRateLimitPolicies

**Problem**: The RHOAI Dashboard UI creates individual `TokenRateLimitPolicy` per tier (e.g., `tier-free-token-rate-limits`, `tier-premium-token-rate-limits`). When multiple policies target the same gateway, only one is enforced.

**Impact**: Only the last-created tier policy works; other tiers have no rate limiting.

**Solution**: Delete UI-created policies and use a single combined policy:

```bash
# Delete conflicting policies
oc delete tokenratelimitpolicy tier-free-token-rate-limits tier-premium-token-rate-limits tier-enterprise-token-rate-limits -n openshift-ingress --ignore-not-found

# Apply combined policy
oc apply -f demo/maas-demo/manifests/tiers/tokenratelimitpolicy.yaml
```

---

## Complete Fix Procedure

After a cluster restart or when rate limiting stops working, apply all fixes in order:

### Step-by-Step Commands

```bash
# Step 1: Apply AuthPolicy with tier lookup
oc apply -f demo/maas-demo/manifests/authpolicy-with-tier-lookup.yaml

# Step 2: Patch AuthPolicy to include username in groups
oc patch authpolicy maas-default-gateway-authn -n openshift-ingress --type=merge -p '{"spec":{"rules":{"metadata":{"matchedTier":{"http":{"body":{"expression":"{ \"groups\": auth.identity.user.groups + [auth.identity.user.username] }"}}}}}}}'

# Step 3: Fix tier-to-group-mapping ConfigMap
cat <<'EOF' | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: tier-to-group-mapping
  namespace: redhat-ods-applications
  labels:
    app: maas-api
    app.kubernetes.io/component: api
    app.kubernetes.io/name: maas-api
    app.kubernetes.io/part-of: models-as-a-service
    app.opendatahub.io/modelsasservice: "true"
    component: tier-mapping
    platform.opendatahub.io/part-of: modelsasservice
data:
  tiers: |
    - name: enterprise
      displayName: Enterprise Tier
      groups:
        - system:serviceaccount:maas-demo:tier-enterprise-sa
      level: 2
    - name: premium
      displayName: Premium Tier
      groups:
        - system:serviceaccount:maas-demo:tier-premium-sa
      level: 1
    - name: free
      displayName: Free Tier
      groups:
        - system:serviceaccount:maas-demo:tier-free-sa
        - system:authenticated
      level: 0
EOF

# Step 4: Delete any UI-created conflicting policies
oc delete tokenratelimitpolicy tier-free-token-rate-limits tier-premium-token-rate-limits tier-enterprise-token-rate-limits -n openshift-ingress --ignore-not-found

# Step 5: Apply combined TokenRateLimitPolicy
oc apply -f demo/maas-demo/manifests/tiers/tokenratelimitpolicy.yaml

# Step 6: Restart maas-api to pick up ConfigMap changes
oc rollout restart deployment/maas-api -n redhat-ods-applications
oc rollout status deployment/maas-api -n redhat-ods-applications --timeout=120s

# Step 7: Restart Authorino to clear auth cache
oc rollout restart deployment/authorino -n kuadrant-system
oc rollout status deployment/authorino -n kuadrant-system --timeout=120s

# Step 8: Restart Limitador to clear rate limit counters
oc rollout restart deployment/limitador-limitador -n kuadrant-system
oc rollout status deployment/limitador-limitador -n kuadrant-system --timeout=120s

# Step 9: Restart Gateway to reload Wasm plugin
oc rollout restart deployment/maas-default-gateway-openshift-gateway-controller -n openshift-ingress
oc rollout status deployment/maas-default-gateway-openshift-gateway-controller -n openshift-ingress --timeout=120s
```

### Why All Restarts Are Required

| Component | Why Restart? |
|-----------|--------------|
| `maas-api` | Picks up changes to `tier-to-group-mapping` ConfigMap |
| `authorino` | Clears cached tier lookup results and auth decisions |
| `limitador` | Resets rate limit counters to zero |
| `gateway` | Reloads Wasm plugin configuration for rate limiting |

**Important**: If you skip any restart, the system may be in an inconsistent state where:
- Tier lookup works but rate limiting doesn't trigger
- Old cached tier values are used
- Rate limit counters from previous sessions persist

### Verification After Fix

```bash
# Test with Free tier (1,000 tokens/min limit)
FREE_TOKEN=$(oc create token tier-free-sa -n maas-demo --duration=1h --audience=https://kubernetes.default.svc)
ENDPOINT="maas-api.apps.<cluster-domain>"

for i in {1..5}; do
    echo -n "Request $i: "
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${ENDPOINT}/maas-demo/qwen3-4b/v1/chat/completions" \
        -H "Authorization: Bearer $FREE_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"model": "qwen3-4b", "messages": [{"role": "user", "content": "Write a story"}], "max_tokens": 500}')
    echo "HTTP $HTTP_CODE"
    sleep 1
done
```

**Expected Results:**
```
Request 1: HTTP 200
Request 2: HTTP 200
Request 3: HTTP 429  ← Rate limited after ~1000 tokens
Request 4: HTTP 429
Request 5: HTTP 429
```

### Test Tier Differentiation

```bash
# Test with Premium tier (5,000 tokens/min limit) - should allow more requests
PREMIUM_TOKEN=$(oc create token tier-premium-sa -n maas-demo --duration=1h --audience=https://kubernetes.default.svc)

for i in {1..5}; do
    echo -n "Request $i: "
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${ENDPOINT}/maas-demo/qwen3-4b/v1/chat/completions" \
        -H "Authorization: Bearer $PREMIUM_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"model": "qwen3-4b", "messages": [{"role": "user", "content": "Write a story"}], "max_tokens": 500}')
    echo "HTTP $HTTP_CODE"
    sleep 1
done
```

**Expected Results:**
```
Request 1: HTTP 200
Request 2: HTTP 200
Request 3: HTTP 200
Request 4: HTTP 200
Request 5: HTTP 200  ← All succeed (only ~2500 tokens used, limit is 5000)
```

---

## Permanent Fix

### Important Caveats

The `odh-model-controller` will **recreate** the AuthPolicy if:
- The model is redeployed
- The LLMInferenceService is deleted and recreated
- The controller is restarted

The RHOAI Dashboard UI will **recreate** individual TokenRateLimitPolicies if:
- You edit tiers in the UI
- You save tier configuration changes

### Recommended Approach

1. **Use the demo scripts** - They automatically apply all fixes:
   ```bash
   ./demo/maas-demo/demo.sh -n maas-demo -m qwen3-4b
   ```

2. **For manual deployments**, apply all fixes in order:
   ```bash
   # 1. Apply AuthPolicy with tier lookup
   oc apply -f demo/maas-demo/manifests/authpolicy-with-tier-lookup.yaml
   
   # 2. Patch to include username
   oc patch authpolicy maas-default-gateway-authn -n openshift-ingress --type=merge -p '{"spec":{"rules":{"metadata":{"matchedTier":{"http":{"body":{"expression":"{ \"groups\": auth.identity.user.groups + [auth.identity.user.username] }"}}}}}}}'
   
   # 3. Fix tier-to-group-mapping (see lib/tiers.sh fix_tier_to_group_mapping)
   
   # 4. Delete UI-created policies
   oc delete tokenratelimitpolicy tier-free-token-rate-limits tier-premium-token-rate-limits tier-enterprise-token-rate-limits -n openshift-ingress --ignore-not-found
   
   # 5. Apply combined TokenRateLimitPolicy
   oc apply -f demo/maas-demo/manifests/tiers/tokenratelimitpolicy.yaml
   
   # 6. Clear caches
   oc rollout restart deployment/authorino -n kuadrant-system
   oc rollout restart deployment/limitador-limitador -n kuadrant-system
   ```

3. **Monitor for overrides**:
   ```bash
   # Check TokenRateLimitPolicy enforcement
   oc get tokenratelimitpolicy -n openshift-ingress -o custom-columns='NAME:.metadata.name,ENFORCED:.status.conditions[?(@.type=="Enforced")].status'
   ```

### File Locations

The fixes are implemented in:
- `demo/maas-demo/manifests/authpolicy-with-tier-lookup.yaml` - The patched AuthPolicy
- `demo/maas-demo/manifests/tiers/tokenratelimitpolicy.yaml` - Combined tier-based rate limits
- `demo/maas-demo/lib/tiers.sh` - Tier configuration and fix functions:
  - `fix_tier_to_group_mapping()` - Updates ConfigMap with SA usernames
  - `fix_authpolicy_username_in_groups()` - Patches AuthPolicy body expression
  - `cleanup_ui_tier_policies()` - Deletes conflicting UI policies
  - `clear_rate_limit_caches()` - Restarts Authorino and Limitador
  - `apply_all_tier_fixes()` - Applies all fixes in one call

---

## Summary

| Issue | Symptom | Fix |
|-------|---------|-----|
| AuthPolicy override | Tier lookup never called | Patch `maas-default-gateway-authn` with metadata section |
| TokenReview limitation | All users get Free tier | Use SA usernames in `tier-to-group-mapping` |
| Missing username | Tier lookup can't match SA | Patch AuthPolicy body to include username |
| UI policy conflicts | Only one tier works | Delete individual policies, use combined policy |

### Key Takeaways

1. RHOAI 3.3 MaaS has multiple design issues that prevent tier-based rate limiting from working out of the box

2. The tier lookup endpoint (`maas-api/v1/tiers/lookup`) works correctly - the issues are in how it's called and what data it receives

3. **Four fixes are required**:
   - Patch AuthPolicy with tier lookup metadata
   - Update tier-to-group-mapping to use SA usernames
   - Patch AuthPolicy to include username in groups
   - Delete conflicting UI-created TokenRateLimitPolicies

4. **All four components must be restarted** after applying fixes:
   - `maas-api` - to pick up ConfigMap changes
   - `authorino` - to clear auth cache
   - `limitador` - to reset rate limit counters
   - `gateway` - to reload Wasm plugin

5. These fixes may need to be reapplied after:
   - Cluster restart
   - Model redeployments
   - UI tier edits

6. The demo scripts (`demo.sh`, `setup-demo-model.sh`) automatically apply all fixes and restarts

---

## Related Documentation

- [RHOAI 3.3 Installation Guide](./RHOAI-33-INSTALLATION.md)
- [MaaS Demo Setup](../../demo/maas-demo/README.md)
- [Kuadrant AuthPolicy Documentation](https://docs.kuadrant.io/latest/kuadrant-operator/doc/auth/)
- [Kuadrant TokenRateLimitPolicy Documentation](https://docs.kuadrant.io/latest/kuadrant-operator/doc/rate-limiting/)
