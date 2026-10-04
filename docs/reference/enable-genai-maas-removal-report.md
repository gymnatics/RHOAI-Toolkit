# Script Overlap Report: `enable-genai-maas.sh` vs `setup-maas.sh`

## Summary

`scripts/enable-genai-maas.sh` is an older, simpler script (~370 lines) that largely duplicates functionality already provided — with better coverage — by `scripts/setup-maas.sh` (~1180 lines). It should be **removed** along with its dedicated `lib/manifests/genai-maas/` directory (7 files).

## What Each Script Does

| Capability | `enable-genai-maas.sh` | `setup-maas.sh` |
|---|:---:|:---:|
| Patch DSC to enable components | ✅ | ✅ |
| Enable dashboard flags (genAiStudio, modelAsService, etc.) | ✅ | ✅ |
| Install RHCL (Kuadrant) operator | ✅ | ✅ |
| Configure Authorino TLS | ✅ (cert-manager) | ✅ (service-ca — correct for 3.4+) |
| Install LWS / Kueue operators | ✅ | ✅ (via installers) |
| Enable User Workload Monitoring | ✅ | ✅ |
| Create GPU HardwareProfile | ✅ | ❌ (handled by installers) |
| Deploy PostgreSQL / `maas-db-config` secret | ❌ | ✅ |
| Create GatewayClass + Gateway + passthrough route | ❌ | ✅ |
| Namespace labels for Selector-based routing | ❌ | ✅ |
| MetalLB for bare-metal platforms | ❌ | ✅ |
| Corporate proxy workaround (OCPBUGS-77457) | ❌ | ✅ |
| `AUTH_SERVICE_TIMEOUT` preventive fix (BU Issue 7) | ❌ | ✅ |
| Phased execution / resume (`--from-phase`) | ❌ | ✅ |
| Idempotent state detection | Minimal | Full (`detect_maas_state()`) |
| Version branching (3.2 / 3.3 / 3.4 / 3.5+) | Basic (3.5 ogx vs legacy) | Full |
| Post-setup verification | ❌ | ✅ (Phase 5) |
| Called by full installers | ❌ | ✅ (`--called-from-installer`) |
| Optional add-ons (Redis, observability, usage logging) | ❌ | ✅ |

## Why Remove

1. **Incomplete for actual MaaS operation** — Running `enable-genai-maas.sh` alone does not produce a working MaaS platform. It's missing PostgreSQL, the Gateway, namespace labels, and passthrough routes. Users would still need to run `setup-maas.sh` afterward.

2. **Duplicate manifests** — It owns `lib/manifests/genai-maas/` (7 YAML files) that duplicate resources already maintained in `lib/manifests/rhcl/` and `lib/manifests/rhoai/`. Two copies = two places to forget to update.

3. **Stale TLS method** — Uses cert-manager Certificates for Authorino TLS, which is the RHOAI 3.3 method. RHOAI 3.4+ uses OpenShift service-ca annotations (what `setup-maas.sh` does).

4. **Minimal references** — Only mentioned in `scripts/README.md`. Not called by `rhoai-toolkit.sh`, not called by any other script, not used by the installers.

## Files to Remove

| Path | Type |
|------|------|
| `scripts/enable-genai-maas.sh` | Script |
| `lib/manifests/genai-maas/datasciencecluster-legacy.yaml` | Manifest |
| `lib/manifests/genai-maas/datasciencecluster-ogx.yaml` | Manifest |
| `lib/manifests/genai-maas/rhcl-operatorgroup-subscription.yaml` | Manifest |
| `lib/manifests/genai-maas/kuadrant-instance.yaml` | Manifest |
| `lib/manifests/genai-maas/authorino-selfsigned-issuer-cert.yaml` | Manifest |
| `lib/manifests/genai-maas/lws-operator.yaml` | Manifest |
| `lib/manifests/genai-maas/kueue-operator.yaml` | Manifest |

**Total: 1 script + 7 manifests (1 directory)**

## Documentation Updates Required

- **`scripts/README.md`** — Remove the `### enable-genai-maas.sh` section and the reference in the "Typical Workflow" section. Replace with a note pointing to `setup-maas.sh` as the single MaaS setup entry point.

## Recommended Action

**Remove** the script and its manifests directory entirely. No wrapper or redirect needed — no other code depends on it, and `setup-maas.sh` is strictly superior in every dimension.
