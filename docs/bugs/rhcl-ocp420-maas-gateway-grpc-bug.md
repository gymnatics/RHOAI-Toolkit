# MaaS Bug: Gateway HTTP 500 Before First Model Deployed (Missing Authorino TLS EnvoyFilter)

**Date discovered:** 2026-09-03
**Status:** Root cause found, workaround available, RHOAI bug

## Summary

On a fresh RHOAI 3.5 install with MaaS enabled, **all authenticated MaaS gateway requests return HTTP 500** until the first `LLMInferenceService` is deployed. The Kuadrant-managed EnvoyFilter for the auth service cluster is missing the TLS `transport_socket` needed to connect to Authorino's TLS-enabled gRPC endpoint. The TLS config is only created by `odh-model-controller` when a model is deployed.

## Root Cause

### The Auth Pipeline

```
Client → MaaS Gateway (envoy)
  → Kuadrant WASM shim → gRPC call to Authorino (port 50051, TLS)
  → Auth decision → Request forwarded to maas-api
```

### The Bug

Two EnvoyFilters configure the `kuadrant-auth-service` envoy cluster:

| EnvoyFilter | Created by | Includes TLS? | When created |
|---|---|---|---|
| `kuadrant-auth-maas-default-gateway` | Kuadrant operator | ❌ **NO** | Immediately (when Gateway + AuthPolicy exist) |
| `maas-default-gateway-authn-ssl` | `odh-model-controller` | ✅ YES | **Only when first LLMInferenceService is deployed** |

Authorino's gRPC listener has TLS enabled (`service.beta.openshift.io/serving-cert-secret-name: authorino-server-cert`). Without the `transport_socket`, envoy sends plain H2 to a TLS-expecting server → gRPC failure → HTTP 500.

The `maas-default-gateway-authn-ssl` EnvoyFilter has `priority: -1` (applies before the Kuadrant one at priority 0), so when it exists, it overrides the broken cluster definition with one that includes TLS.

### Working Config (with transport_socket)
```json
{
  "name": "kuadrant-auth-service",
  "type": "STRICT_DNS",
  "connect_timeout": "1s",
  "http2_protocol_options": {},
  "transport_socket": {
    "name": "envoy.transport_sockets.tls",
    "typed_config": {
      "@type": "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext",
      "common_tls_context": {
        "validation_context": {
          "trusted_ca": {
            "filename": "/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt"
          }
        }
      }
    }
  },
  "load_assignment": { ... }
}
```

### Broken Config (missing transport_socket)
```json
{
  "name": "kuadrant-auth-service",
  "type": "STRICT_DNS",
  "connect_timeout": "1s",
  "http2_protocol_options": {},
  "load_assignment": { ... }
}
```

## Investigation Trail

Initially suspected OCP 4.20-specific RHCL bug (reported by Tham via Slack). Investigated two clusters:

| Cluster | OCP | RHCL | RHOAI | Models | MaaS Works? |
|---|---|---|---|---|---|
| `cluster-jv9b7` (broken) | 4.20.34 | v1.4.2 | 3.5.0 | None | ❌ HTTP 500 |
| `cluster-v5zjc` (working) | 4.20.34 | v1.4.2 | 3.5.0 | Qwen 3 8B (LLMInferenceService) | ✅ HTTP 200 |

Same OCP/RHCL/RHOAI versions. The **only** difference: the working cluster had a deployed model, which caused `odh-model-controller` to create the `maas-default-gateway-authn-ssl` EnvoyFilter with the TLS transport_socket.

Key evidence from envoy runtime stats:
- **Broken**: `kuadrant-auth-service::rq_success::0, rq_error::2` (all gRPC calls fail)
- **Working**: `kuadrant-auth-service::rq_success::2, rq_error::1` (gRPC calls succeed)

## Fix (Workaround)

Create the missing EnvoyFilter manually:

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

# Restart gateway pod
oc delete pod -n openshift-ingress \
  -l gateway.networking.k8s.io/gateway-name=maas-default-gateway
```

## Proper Fix (for RHOAI team)

The Kuadrant operator should include the `transport_socket` TLS config in the `kuadrant-auth-maas-default-gateway` EnvoyFilter when Authorino has TLS enabled. The auth cluster should not depend on `odh-model-controller` creating a separate EnvoyFilter triggered by model deployment.

## Relation to Tham's Report

Tham reported "RHCL is broken on OCP 4.20." This is partially correct — MaaS doesn't work on a fresh install. But the root cause is NOT OCP 4.20-specific; it affects any RHOAI 3.5 cluster where MaaS is enabled but no models have been deployed yet. The working cluster (also OCP 4.20) worked because it had a model deployed.
