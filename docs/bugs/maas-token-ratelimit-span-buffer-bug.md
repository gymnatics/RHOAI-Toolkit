# MaaS Token Rate Limiting Bug: WasmPlugin Span Buffer Overflow

## Summary

Token rate limiting in RHOAI 3.4 Models-as-a-Service (MaaS) silently fails to enforce limits under load due to the Kuadrant WasmPlugin's internal span buffer (capacity: 100) being continuously saturated. When the buffer is full, post-response token reports are dropped, causing Limitador to undercount actual token usage. Requests that should be rate-limited (HTTP 429) are instead allowed through.

## Environment

- OpenShift 4.20
- RHOAI 3.4 (DataScienceCluster with `kserve.modelsAsService: Managed`)
- Red Hat Connectivity Link (RHCL) Operator / Kuadrant
- Service Mesh 3 (Sail Operator / Istio 1.26.2)
- Limitador v2.3.0 (in-memory storage)
- Model: Llama 2 7B AWQ via vLLM on MIG 2g.10gb

## Symptom

A `MaaSSubscription` configured with a 10,000 tokens/hour limit is never enforced. The user can consume unlimited tokens without receiving HTTP 429.

```yaml
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSSubscription
metadata:
  name: test
  namespace: models-as-a-service
spec:
  modelRefs:
    - name: llama2-7b-awq
      namespace: models-as-a-service
      tokenRateLimits:
        - limit: 10000
          window: "1h"
```

The `TokenRateLimitPolicy` shows status `Enforced: True` and Limitador's config contains the correct limit definition — yet no 429 responses are ever returned.

## Root Cause

### How token rate limiting works

The Kuadrant WasmPlugin (`phase: STATS`) on the `maas-default-gateway` implements a two-phase rate limit flow:

1. **Pre-request check** (`ratelimit-check-service`): Calls Limitador with `hits_addend: 0` to check if the user is already over the limit.
2. **Post-response report** (`ratelimit-report-service`): Reads `responseBodyJSON("/usage/total_tokens")` from the model response body and calls Limitador with `hits_addend: <actual_tokens>` to increment the counter.

The WasmPlugin maintains an internal **span buffer** to correlate requests with their responses. Each incoming request opens a "span" that stays open until the response completes and the report is sent.

### The bug: span buffer saturation

The gateway continuously receives background traffic (load balancer health probes, Kubernetes readiness checks) that generates HTTP 426 DPE (Downstream Protocol Error) responses. These connections open spans in the WasmPlugin but never produce a response body, so the spans are never properly closed.

```
[2026-06-03T06:29:37.312Z] "- - HTTP/1.1" 426 DPE low_version - "-" 0 0 0 - "-" "-" "-" "-" "-"
```

With a fixed buffer capacity of 100, these "zombie" spans accumulate until the buffer is full. Once full, each new request evicts the oldest span:

```
wasm log openshift-ingress.kuadrant-maas-default-gateway: Span buffer full (100), dropping oldest span
```

When a span is evicted before its response arrives, the `ratelimit-report-service` action for that request **never executes**. The tokens consumed by that request are never reported to Limitador.

### Compounding factor: payload-processing ext_proc

The MaaS controller deploys a `payload-processing` External Processor (ext_proc) with `response_body_mode: FULL_DUPLEX_STREAMED`. This filter is inserted AFTER the WasmPlugin in the HTTP filter chain:

```yaml
processing_mode:
  request_body_mode: FULL_DUPLEX_STREAMED
  response_body_mode: FULL_DUPLEX_STREAMED
```

The streaming ext_proc may further interfere with the WasmPlugin's ability to buffer and parse response bodies, particularly under concurrent load.

### Compounding factor: in-memory Limitador storage

Limitador is configured with in-memory storage (no Redis). Any pod restart resets all counters to zero, effectively removing all accumulated token counts.

## Evidence

### Span buffer warnings flood the gateway logs

Even with near-zero user traffic, 100+ warnings per 5 minutes:

```bash
$ oc logs deployment/maas-default-gateway-data-science-gateway-class \
    -n openshift-ingress --since=5m | grep -c "Span buffer full"
106
```

### Limitador receives correct data when spans are NOT dropped

With debug logging enabled on Limitador, individual requests do produce correct reports:

```
check_rate_limit: RateLimitRequest { domain: "models-as-a-service/llama2-7b-awq-kserve-route",
  descriptors: [Entry { key: "tokenlimit.models_as_a_service_test_llama2_7b_awq_tokens__8d1ccde0", value: "1" },
                Entry { key: "auth.identity.userid", value: "admin" }],
  hits_addend: 0 }

report: RateLimitRequest { domain: "models-as-a-service/llama2-7b-awq-kserve-route",
  descriptors: [Entry { key: "tokenlimit.models_as_a_service_test_llama2_7b_awq_tokens__8d1ccde0", value: "1" },
                Entry { key: "auth.identity.userid", value: "admin" }],
  hits_addend: 7 }
```

### Rate limiting works with low limits

When the limit is reduced to 50 tokens/hour, enforcement works because fewer requests are needed to exceed it:

```
Request 1: HTTP 200 - 15 tokens (cumulative: 15)
Request 2: HTTP 200 - 15 tokens (cumulative: 30)
Request 3: HTTP 429 RATE LIMITED after 30 tokens!
```

### With 10k limit, too many reports are dropped

With ~15 tokens/request, exceeding 10k requires ~666 requests. If the span buffer causes 30-50% of reports to be dropped, you'd need 1,000-1,300 requests — and even then the count may never converge because zombie spans keep displacing real ones.

## Affected Components

| Component | Version | Role |
|-----------|---------|------|
| WasmPlugin `kuadrant-maas-default-gateway` | Kuadrant (RHCL) | Auth + rate limit orchestration |
| Limitador | v2.3.0 | Token counter (in-memory) |
| EnvoyFilter `payload-processing` | MaaS controller | ext_proc for response body streaming |
| Gateway pod | Istio 1.26.2 | Envoy proxy hosting the WasmPlugin |

## Workaround

### Option 1: Reduce the token limit for testing

Lower the limit so fewer requests are needed to trigger enforcement:

```bash
oc patch maassubscription test -n models-as-a-service --type=merge \
  -p '{"spec":{"modelRefs":[{"name":"llama2-7b-awq","namespace":"models-as-a-service","tokenRateLimits":[{"limit":200,"window":"1h"}]}]}}'
```

### Option 2: Disable the payload-processing ext_proc

This removes the streaming response body interference. Note: this may break MaaS model-provider-resolver functionality.

```bash
oc delete envoyfilter payload-processing -n openshift-ingress
oc scale deployment payload-processing -n openshift-ingress --replicas=0
```

After disabling, restart the gateway to clear the span buffer:

```bash
oc rollout restart deployment/maas-default-gateway-data-science-gateway-class -n openshift-ingress
```

### Option 3: Block health check traffic from reaching the WasmPlugin

Add an EnvoyFilter that short-circuits health probes before they reach the WasmPlugin:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: bypass-wasm-healthchecks
  namespace: openshift-ingress
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: maas-default-gateway
  configPatches:
    - applyTo: HTTP_ROUTE
      match:
        context: GATEWAY
      patch:
        operation: INSERT_FIRST
        value:
          name: healthcheck-bypass
          match:
            headers:
              - name: user-agent
                exact_match: ""
            prefix: "/"
          direct_response:
            status: 200
            body:
              inline_string: "OK"
```

> **Note:** This is a simplified example. The actual filter should match the specific health check patterns (empty user-agent, no Host header, HTTP/1.0 or HTTP/1.1 → 426 DPE patterns).

### Option 4: Switch Limitador to Redis-backed storage

This doesn't fix the span buffer issue but prevents counter resets on pod restarts:

```yaml
apiVersion: limitador.kuadrant.io/v1alpha1
kind: Limitador
metadata:
  name: limitador
  namespace: kuadrant-system
spec:
  storage:
    redis:
      url: "redis://redis.kuadrant-system.svc.cluster.local:6379"
```

## Troubleshooting Commands

```bash
# Check span buffer warnings
oc logs deployment/maas-default-gateway-data-science-gateway-class \
  -n openshift-ingress --since=5m | grep -c "Span buffer full"

# Verify Limitador receives reports (enable debug first)
oc set env deployment/limitador-limitador -n kuadrant-system RUST_LOG=debug
# Then send a request and check logs:
oc logs deployment/limitador-limitador -n kuadrant-system --tail=20 | grep "report"

# Check Envoy cluster connectivity to Limitador
oc exec deployment/maas-default-gateway-data-science-gateway-class \
  -n openshift-ingress -- pilot-agent request GET /clusters \
  | grep "kuadrant-ratelimit-service"

# Verify TokenRateLimitPolicy is enforced
oc get tokenratelimitpolicy -n models-as-a-service -o jsonpath='{.items[0].status.conditions}'

# Check the WasmPlugin service config
oc get wasmplugin kuadrant-maas-default-gateway -n openshift-ingress \
  -o jsonpath='{.spec.pluginConfig.services}' | python3 -m json.tool

# Check what's generating 426 DPE responses
oc logs deployment/maas-default-gateway-data-science-gateway-class \
  -n openshift-ingress --since=10m | grep "426 DPE"

# Verify rate limit works with low limit
oc patch maassubscription test -n models-as-a-service --type=merge \
  -p '{"spec":{"modelRefs":[{"name":"llama2-7b-awq","namespace":"models-as-a-service","tokenRateLimits":[{"limit":50,"window":"1h"}]}]}}'
# Send 5+ requests and confirm 429

# Reset Limitador counters (restart in-memory instance)
oc rollout restart deployment/limitador-limitador -n kuadrant-system

# Disable debug logging when done
oc set env deployment/limitador-limitador -n kuadrant-system RUST_LOG-
```

## Applied Fix Combination (2026-06-04)

The following fixes were applied to resolve the rate limiting failure:

### Fix 1: Limitador Redis-Cached Storage (MOST IMPACTFUL)

Deployed Redis and configured Limitador with `redis-cached` storage. This provides:
- **Persistent counters** across Limitador restarts
- **Faster gRPC response times** (local cache + async flush to Redis)
- **Zero gRPC errors** under concurrent load (previously 8 errors per test)

```yaml
apiVersion: limitador.kuadrant.io/v1alpha1
kind: Limitador
metadata:
  name: limitador
  namespace: kuadrant-system
spec:
  storage:
    redis-cached:
      configSecretRef:
        name: limitador-redis-config
      options:
        flush-period: 500    # Flush to Redis every 500ms
        max-cached: 10000    # Cache up to 10k counters locally
        batch-size: 100      # Flush 100 entries per batch
        response-timeout: 500 # 500ms Redis timeout
```

Redis deployment:
```bash
# Deployment + Service in kuadrant-system
oc get pods -n kuadrant-system -l app=limitador-redis
# Secret with connection URL
oc get secret limitador-redis-config -n kuadrant-system
```

### Fix 2: EnvoyFilter — Health Check Interceptor

Intercepts `/healthz` and `/ready` probes before they reach the WasmPlugin filter chain:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: healthcheck-filter
  namespace: openshift-ingress
spec:
  workloadSelector:
    labels:
      gateway.networking.k8s.io/gateway-name: maas-default-gateway
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
      patch:
        operation: INSERT_FIRST
        value:
          name: envoy.filters.http.health_check
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.health_check.v3.HealthCheck
            pass_through_mode: false
            headers:
              - name: ":path"
                string_match:
                  exact: "/healthz"
              - name: ":path"
                string_match:
                  exact: "/ready"
```

### Fix 3: EnvoyFilter — Increased Ratelimit Cluster Timeout

Increases the Envoy cluster `connect_timeout` for the Limitador gRPC service:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: increase-ratelimit-cluster-timeout
  namespace: openshift-ingress
spec:
  workloadSelector:
    labels:
      gateway.networking.k8s.io/gateway-name: maas-default-gateway
  configPatches:
    - applyTo: CLUSTER
      match:
        context: GATEWAY
        cluster:
          name: kuadrant-ratelimit-service
      patch:
        operation: MERGE
        value:
          connect_timeout: 2s
```

### Results After Fix

| Metric | Before Fix | After Fix |
|--------|-----------|-----------|
| Rate limit enforced? | NO (unlimited tokens) | YES (429 at ~10k) |
| gRPC errors during test | 8 | 0 |
| Span buffer warnings | ~2,500 / 5min | ~1,250 / 5min |
| Counter persistence | In-memory (lost on restart) | Redis-backed |
| Tokens at enforcement | Never enforced | 9,801 client / 10,877 Redis |

**Note**: Span buffer warnings still occur (hardcoded 100-span limit in wasm-shim binary) but no longer cause rate limit failure because:
1. Redis-cached Limitador responds faster → spans close quicker
2. Zero gRPC timeouts → reports that DO get through are accurate
3. Redis persistence → counters survive across flushes

### Remaining Upstream Issues

The WasmPlugin span buffer size (100) is still hardcoded in the `wasm-shim-rhel9` binary. The Kuadrant operator also reconciles the WasmPlugin service timeout (100ms) and overrides manual patches. These require upstream fixes:

1. **Make span buffer size configurable** via `pluginConfig` or annotation
2. **Increase default ratelimit-report-service timeout** in the operator
3. **Skip span creation for non-matching traffic** (426 DPE, non-route hosts)

## References

- [RHOAI 3.4 MaaS Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html-single/govern_llm_access_with_models-as-a-service/index)
- [Kuadrant WasmPlugin Architecture](https://docs.kuadrant.io/latest/architecture/rfcs/0004-rlp-primitives/)
- [Limitador Configuration](https://docs.kuadrant.io/latest/limitador/)
- Cluster: `ocp-mig-tokyo.sandbox3967.opentlc.com`
- Namespace: `models-as-a-service`
- Gateway: `maas-default-gateway` in `openshift-ingress`
