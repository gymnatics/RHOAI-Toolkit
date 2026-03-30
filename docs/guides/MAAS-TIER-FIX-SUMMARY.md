# MaaS Tier-Based Rate Limiting Fix Summary

## Problem

Tier-based rate limiting was not working in RHOAI 3.3 MaaS. All users were getting the same rate limit regardless of their tier (Free/Premium/Enterprise).

## Root Causes

1. **Kubernetes TokenReview doesn't return OpenShift groups**
   - The tier lookup receives only system groups (`system:authenticated`, `system:serviceaccounts`)
   - OpenShift groups like `tier-premium-users` are NOT included
   - Result: All users match `system:authenticated` → Free tier

2. **AuthPolicy doesn't include username in tier lookup**
   - The default body expression: `{ "groups": auth.identity.user.groups }`
   - Missing the username which is needed for SA-specific tier matching

3. **tier-to-group-mapping ConfigMap uses OpenShift groups**
   - Default config maps tiers to OpenShift groups
   - But those groups are never sent to the tier lookup

## Solution

### Fix 1: Update tier-to-group-mapping ConfigMap

Use ServiceAccount usernames instead of OpenShift groups:

```yaml
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
```

### Fix 2: Update AuthPolicy to include username

Change the body expression to include the username:

```yaml
body:
  expression: '{ "groups": auth.identity.user.groups + [auth.identity.user.username] }'
```

### Fix 3: Apply combined TokenRateLimitPolicy

Use a single policy with all tiers (not individual policies per tier):

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
        - limit: 1000
          window: 1m0s
      when:
        - predicate: 'auth.identity.tier == "free"'
      counters:
        - expression: auth.identity.userid
    premium-tokens:
      rates:
        - limit: 5000
          window: 1m0s
      when:
        - predicate: 'auth.identity.tier == "premium"'
      counters:
        - expression: auth.identity.userid
    enterprise-tokens:
      rates:
        - limit: 10000
          window: 1m0s
      when:
        - predicate: 'auth.identity.tier == "enterprise"'
      counters:
        - expression: auth.identity.userid
```

### Fix 4: Clear caches

Restart components to pick up changes:

```bash
oc rollout restart deployment/maas-api -n redhat-ods-applications
oc rollout restart deployment/authorino -n kuadrant-system
oc rollout restart deployment/limitador-limitador -n kuadrant-system
```

## Automated Fix

The `demo.sh` script now applies all fixes automatically:

```bash
./demo/maas-demo/demo.sh -n maas-demo -m qwen3-4b
```

Or apply fixes manually:

```bash
# Apply all tier fixes
source demo/maas-demo/lib/tiers.sh
apply_all_tier_fixes "maas-demo" "demo/maas-demo/manifests"
```

## Verification

Test rate limiting with different tiers:

```bash
# Free tier (1000 tokens/min)
FREE_TOKEN=$(oc create token tier-free-sa -n maas-demo --duration=1h --audience=https://kubernetes.default.svc)
curl -sk "https://maas-api.apps.<cluster>/maas-demo/qwen3-4b/v1/chat/completions" \
  -H "Authorization: Bearer $FREE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3-4b","messages":[{"role":"user","content":"Hello"}],"max_tokens":500}'

# Premium tier (5000 tokens/min)
PREMIUM_TOKEN=$(oc create token tier-premium-sa -n maas-demo --duration=1h --audience=https://kubernetes.default.svc)
curl -sk "https://maas-api.apps.<cluster>/maas-demo/qwen3-4b/v1/chat/completions" \
  -H "Authorization: Bearer $PREMIUM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3-4b","messages":[{"role":"user","content":"Hello"}],"max_tokens":500}'
```

Expected results:
- Free tier: Rate limited after ~2-3 requests (HTTP 429)
- Premium tier: More requests allowed before rate limiting

## Files Modified

| File | Changes |
|------|---------|
| `demo/maas-demo/manifests/authpolicy-with-tier-lookup.yaml` | Added username to groups array |
| `demo/maas-demo/lib/tiers.sh` | Added `apply_authpolicy_with_tier_lookup()`, updated `apply_all_tier_fixes()` |
| `demo/maas-demo/demo.sh` | Updated tier setup to apply all fixes, use correct endpoint |
| `docs/guides/MAAS-TIER-RATE-LIMITING-FIX.md` | Documented the fix |

## Key Takeaways

1. **Kubernetes TokenReview ≠ OpenShift groups** - Don't rely on OpenShift groups for tier resolution
2. **Use SA usernames as "groups"** - The maas-api can match usernames in the groups array
3. **Single TokenRateLimitPolicy** - Multiple policies override each other; use one combined policy
4. **Clear caches after changes** - Restart maas-api, Authorino, and Limitador
