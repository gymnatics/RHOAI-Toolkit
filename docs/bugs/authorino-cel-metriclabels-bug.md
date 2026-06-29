# Bug Report: Authorino `metricLabels` CEL Expression Parsing Failure

## Title

Authorino `metricLabels` fails to parse CEL expressions — Limitador Prometheus counters have empty `user`/`subscription`/`model` labels, breaking MaaS Usage dashboard

## Component

- **Authorino** (`auth_pipeline.go`, `metricLabels` function at line ~542)
- Shipped in: **RHCL v1.3.2** (`rhcl-operator.v1.3.2`)
- Image: `registry.redhat.io/rhcl-1/authorino-rhel9@sha256:c2208382e16c501e4ed58aea83f54d108567f36853cf79f7ffdf8ee54ff4ace8`

## Severity

High — the entire Usage tab of the RHOAI Observability Dashboard is non-functional.

## Environment

- OpenShift 4.20
- RHOAI 3.4.0 (`rhods-operator.3.4.0`)
- RHCL v1.3.2
- Kuadrant CR deployed in `kuadrant-system`
- MaaS enabled with 2 LLMInferenceServices, 1 MaaSSubscription, TokenRateLimitPolicies
- API key authentication working correctly
- Token rate limiting working correctly (429s returned when limits exceeded)

## Description

The `metricLabels` function in Authorino's `auth_pipeline.go:542` attempts to re-parse CEL expressions for Prometheus metric label extraction. However, the expressions stored in the AuthConfig are in their **compiled AST struct representation** rather than raw CEL strings. The CEL parser fails on every authenticated request, resulting in empty metric labels on Limitador's Prometheus counters.

Auth and rate limiting work correctly — only the Prometheus metric labels are affected.

## Symptoms

1. **RHOAI Dashboard → Observe & Monitor → Usage** shows all zeros:
   - Total Tokens: 0
   - Total Requests: 0
   - Total Errors: 0
   - Active Users: 0
   - Token Consumption chart: "No data"

2. **Limitador Prometheus metrics** have data but with empty `user` labels:
   ```
   authorized_calls{user="", subscription="tier1", limitador_namespace="a-rh-department/maas-gpt-oss-20b-kserve-route"} = 58
   authorized_hits{user="", subscription="tier1", limitador_namespace="a-rh-department/maas-gpt-oss-20b-kserve-route"} = 13820
   ```

3. **Usage dashboard PromQL** filters by `user!=""`, returning zero results:
   ```promql
   count(count by (user) (
     sum by (user, subscription, limitador_namespace) (
       increase(authorized_calls{user!=""}[1h])
     )
   ))
   ```

## Root Cause

Authorino logs show repeated CEL parse errors on every authenticated request:

```json
{
  "level": "error",
  "ts": "2026-06-18T07:49:10Z",
  "logger": "authorino.service.auth.authpipeline",
  "msg": "failed to parse CEL expression",
  "request id": "a2426ae2-8595-4ec5-9559-837f4857e369",
  "expression": "Expression { expression: IdedExpr { id: 3, expr: Select(SelectExpr { operand: IdedExpr { id: 2, expr: Select(SelectExpr { operand: IdedExpr { id: 1, expr: Ident(\"auth\") }, field: \"identity\", test: false }) }, field: \"selected_subscription\", test: false }) }, attributes: [Attribute { path: [\"auth\", \"identity\", \"selected_subscription\"] }], extended: false }",
  "error": "ERROR: <input>:1:12: undeclared reference to 'Expression' (in container '')\n | Expression { expression: IdedExpr { ... } }\n | ...........^",
  "stacktrace": "github.com/kuadrant/authorino/pkg/service.(*AuthPipeline).metricLabels\n\tgithub.com/kuadrant/authorino/pkg/service/auth_pipeline.go:542\n..."
}
```

The failing expressions (all in AST format rather than raw CEL):

| Intended CEL Expression | What `metricLabels` receives |
|---|---|
| `auth.identity.userid` | `Expression { expression: IdedExpr { ... Ident("auth") ... "userid" ... } }` |
| `auth.identity.selected_subscription` | `Expression { expression: IdedExpr { ... "selected_subscription" ... } }` |
| `auth.identity.subscription_info.costCenter` | `Expression { expression: IdedExpr { ... "costCenter" ... } }` |
| `auth.identity.subscription_info.organizationId` | `Expression { expression: IdedExpr { ... "organizationId" ... } }` |
| `responseBodyJSON("/model")` | `Expression { expression: IdedExpr { ... Call(CallExpr { func_name: "responseBodyJSON" ... }) } }` |

The `metricLabels` function receives the Go `fmt.Sprintf("%v")` or `.String()` output of the compiled `cel.Ast` struct and tries to parse it as a CEL source string. The CEL parser (correctly) rejects this as invalid CEL syntax.

## Steps to Reproduce

1. Install RHOAI 3.4 with MaaS and RHCL v1.3.2
2. Deploy a model via LLMInferenceService and publish to MaaS
3. Create a MaaSSubscription with a TokenRateLimitPolicy
4. Generate an API key from Gen AI Studio > API Keys
5. Send requests:
   ```bash
   curl -sk "https://maas.apps.<cluster>/<ns>/<model>/v1/chat/completions" \
     -H "Authorization: Bearer sk-oai-<key>" \
     -H "Content-Type: application/json" \
     -d '{"model":"<model>","messages":[{"role":"user","content":"hi"}],"max_tokens":10}'
   ```
6. Check Authorino logs:
   ```bash
   oc logs deploy/authorino -n kuadrant-system --tail=50 2>&1 | grep "failed to parse CEL"
   ```
7. Check Limitador metrics for empty labels:
   ```bash
   curl -s http://localhost:8080/metrics | grep authorized_calls
   # Shows user="" on all counters
   ```
8. Navigate to RHOAI Dashboard → Observe & Monitor → Dashboard → Usage tab
9. All metrics show 0

## Expected Behavior

Authorino should correctly evaluate compiled CEL expressions for metric label extraction. The `metricLabels` function should either:
- Evaluate the already-compiled AST directly (instead of re-parsing it), or
- Store the original CEL source string alongside the compiled form and use that for re-parsing

Limitador counters should have populated `user`, `subscription`, and `model` labels:
```
authorized_calls{user="admin", subscription="tier1", model="maas-gpt-oss-20b", ...} = 58
```

## Impact

- The **entire Usage tab** of the Observability Dashboard is non-functional
- Administrators **cannot see** per-user token consumption, per-subscription utilization, or active user counts
- This undermines the MaaS governance value proposition where cost visibility per subscription/user is a key GA feature in RHOAI 3.4
- The bug affects **every request** — Authorino logs are flooded with CEL parse errors (~10 error lines per request)

## Workaround

**None at the user level.** The bug is internal to Authorino's metric label processing.

**Partial mitigation:** The Perses-based "MaaS Gateway Metrics" dashboard (using vLLM/kserve Prometheus metrics like `kserve_vllm:generation_tokens_total`, `kserve_vllm:e2e_request_latency_seconds_bucket`) works correctly and provides request rate, P90 latency, token throughput, and queue length — but not per-user or per-subscription breakdowns.

## References

- Authorino source: `pkg/service/auth_pipeline.go` — `metricLabels` function (~line 542)
- Kuadrant AuthPolicy → AuthConfig reconciliation stores compiled CEL ASTs in the AuthConfig CR
- RHOAI 3.4 MaaS docs: [Govern LLM access with Models-as-a-Service](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/govern_llm_access_with_models-as-a-service)
