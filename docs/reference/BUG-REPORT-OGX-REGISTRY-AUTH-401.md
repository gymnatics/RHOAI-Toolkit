# Bug Report: OGXServer Reconciliation Fails with HTTP 401 Fetching OCI Config Labels

**Status**: Open (upstream bug), **workaround available** — see "Workaround / Current State" below. Filed as [RHOAIENG-96724](https://redhat.atlassian.net/browse/RHOAIENG-96724).

**Component**: OGX Operator (`ogx-k8s-operator`, replaces the Llama Stack Operator in RHOAI 3.5+)

**Affected versions confirmed**: RHOAI 3.5.0 and RHOAI 3.5.1 (auto-upgrade did not fix it)

**Severity**: High — blocks all OGX-based RAG/agent workflows (AutoRAG demo, any RHOAI 3.5+ Llama Stack replacement use case) on affected clusters.

**See also:** [docs/bugs/autorag-ogx-3.5-cascade.md](../bugs/autorag-ogx-3.5-cascade.md) for the full AutoRAG bring-up cascade (401 is Issue 1 of six).

---

## Summary

Every `OGXServer` custom resource fails to reconcile with `Phase: Failed`. The
OGX operator's *own* in-process HTTP client — used to fetch OCI image-manifest
labels for its "generated config" feature — receives an `HTTP 401
Unauthorized` from `registry.redhat.io` when resolving the
`odh-ogx-core-rhel9` base image. This happens **even though the exact same
image digest pulls successfully via the normal kubelet/CRI-O pull path**,
proving the image and pull credentials are valid; the 401 is specific to a
second, separate registry-auth code path inside the operator that does not
reuse the node's pull secret.

## Environment

| Field | Value |
|---|---|
| Cluster | `cluster-sclg6` (`ocp.sclg6.sandbox323.opentlc.com`), AWS us-east-2 |
| OpenShift | 4.21.31 |
| RHOAI | 3.5.0 → auto-upgraded to 3.5.1 mid-investigation (`rhods-operator.3.5.1`, replaces `rhods-operator.3.5.0`) |
| OGX operator pods | `ogx-k8s-operator-controller-manager`, `opendatahub-ogx-operator` (namespace `redhat-ods-applications`) |
| Demo exercising the bug | `demo/autorag-demo/` (this toolkit) |

## Steps to Reproduce

1. Install RHOAI 3.5+ with the `ogx` DSC component `Managed`.
2. Deploy the prerequisite infra (Milvus, Postgres, an embedding model, and a
   direct vLLM chat model) — in this toolkit's case via
   `demo/autorag-demo/deploy.sh`.
3. Create an `OGXServer` custom resource pointing at a `remote::vllm`
   inference provider and Postgres-backed storage, e.g.:

   ```yaml
   apiVersion: ogx.io/v1beta1  # toolkit CRD; do not use v1alpha1
   kind: OGXServer
   metadata:
     name: autorag-ogx
     namespace: autorag-demo
   spec:
     distribution:
       name: rh          # also reproduces with rh-dev
     providers:
       inference:
         remote:
           vllm:
             - endpoint: "https://<direct-vllm-endpoint>/v1"
     storage:
       postgres:
         host: llamastack-postgres
         port: 5432
         db: llamastack
         user: llamastack
         passwordSecretRef:
           name: llamastack-postgres-secret
           key: password
     replicas: 1
     resources:
       limits: { cpu: "4", memory: 12Gi }
       requests: { cpu: 250m, memory: 500Mi }
     storageSpec:
       mountPath: /.ogx
       size: 5Gi
   ```

4. Wait for the operator to reconcile.

## Observed Result

```
$ oc get ogxserver autorag-ogx -n autorag-demo
NAMESPACE      NAME          PHASE    PROVIDERS   AVAILABLE   AGE
autorag-demo   autorag-ogx   Failed                           <age>
```

```
$ oc get ogxserver autorag-ogx -n autorag-demo -o jsonpath='{.status.conditions}'
```

```
Status:
  Conditions:
    Last Transition Time:  <timestamp>
    Message:               failed to reconcile generated config: failed to resolve base config from OCI labels: failed to fetch OCI labels for "registry.redhat.io/rhoai/odh-ogx-core-rhel9@sha256:<digest>": failed to fetch manifest for "registry.redhat.io/rhoai/odh-ogx-core-rhel9@sha256:<digest>": HTTP 401
    Reason:                ConfigGenerationFailed
    Status:                False
    Type:                  ConfigGenerated
    Last Transition Time:  <timestamp>
    Message:               Resource reconciliation failed: failed to reconcile generated config: failed to resolve base config from OCI labels: failed to fetch OCI labels for "registry.redhat.io/rhoai/odh-ogx-core-rhel9@sha256:<digest>": failed to fetch manifest for "registry.redhat.io/rhoai/odh-ogx-core-rhel9@sha256:<digest>": HTTP 401
    Reason:                DeploymentFailed
    Status:                False
    Type:                  DeploymentReady
  Phase:  Failed
  Version:
    Last Updated:      <timestamp>
    Operator Version:  "0.13.0"
```

Two distinct image digests were observed across separate investigation
sessions on the same cluster (the operator's `RELATED_IMAGE_ODH_OGX_CORE_IMAGE`
env var changed between RHOAI point releases) — **the 401 reproduced
identically on both**, ruling out a one-off bad digest:

- `registry.redhat.io/rhoai/odh-ogx-core-rhel9@sha256:dc941e03121ee07ccc0540e598b11d24e97c125a3455ad66b4f0532f567e046e`
- `registry.redhat.io/rhoai/odh-ogx-core-rhel9@sha256:7eeac2aa61faf264084df755c9c1575526371b46ec63acc1985598b644882cfb`

This also surfaces as `oc get dsc default-dsc` showing:

```
Ready: False
ModulesReady: False   (message: "Some modules are degraded: ogx")
```

## Expected Result

The `OGXServer` should reconcile to `Phase: Ready` and stand up the OGX
deployment, using the same registry credentials the cluster already has
configured for pulling `odh-ogx-core-rhel9` (which demonstrably work at the
kubelet/CRI-O layer).

## Root-Cause Analysis

The image itself is valid and pullable. A throwaway `Pod` referencing the
**exact same digest** pulled successfully via the node's normal kubelet pull
path in ~2 minutes (5.3GB image), using the cluster's standard
`redhat-registry-pull-secret`. The 401 is therefore **not** a credentials or
network-egress problem in the general sense — it is specific to a second,
separate HTTP call the OGX operator makes *itself*, in-process, to fetch OCI
manifest/config labels from the registry (its "generated config from OCI
labels" feature). This call does not go through kubelet/CRI-O and evidently
does not pick up the same pull secret.

### Things ruled out (in the order investigated)

| # | Hypothesis | Result |
|---|---|---|
| 1 | RBAC — operator lacks permission to read pull secrets | Ruled out. Both `ogx-k8s-operator-manager-role` and `opendatahub-ogx-manager-cluster-role` already have cluster-wide `get/list/watch` on `secrets`. |
| 2 | Stale in-memory credential cache in the operator process | Ruled out. Restarted both `ogx-k8s-operator-controller-manager` and `opendatahub-ogx-operator` pods — no change, identical 401 on next reconcile. |
| 3 | `spec.distribution.name: rh` vs `rh-dev` resolve to different images | Ruled out. Both resolve to the identical image digest via the same `RELATED_IMAGE_ODH_OGX_CORE_IMAGE` env var on the operator Deployment; no behavioral difference. |
| 4 | Operator doesn't have a mounted Docker/Podman-style credential file | Ruled out. Mounted the cluster's real `openshift-config/pull-secret` (copied into `redhat-ods-applications` as `redhat-registry-pull-secret`) as a standard `$HOME/.docker/config.json` (`HOME=/`, container runs as uid 1001) on both OGX operator Deployments, then restarted them. No change — the operator's registry client does not appear to honor the standard Docker/Podman credential-file convention. |
| 5 | A CRD field exists to pass registry credentials for this specific feature | Ruled out. `oc explain ogxserver.spec --recursive` shows the only `secretRefs`-style fields are for **provider auth tokens** (e.g. vLLM/OpenAI API keys), not registry/image-pull credentials. There is no supported way to give this specific "OCI labels" code path its own credentials. |
| 6 | RHOAI point-release update fixes it | Ruled out. RHOAI auto-updated `3.5.0` → `3.5.1` (`rhods-operator.3.5.1`) overnight during the investigation; both OGX operator pods restarted as part of that update. Forced a fresh reconcile via an annotation bump immediately after and got the **identical HTTP 401** on the identical digest. |

### Conclusion

This is an upstream bug in the OGX operator's registry-authentication
handling for its OCI-label-based config-generation feature — the operator
makes an unauthenticated (or incorrectly authenticated) HTTP call to
`registry.redhat.io` from a code path that is independent of the
node-level image pull, and there is no supported CRD field to supply
credentials to it.

## Recommended Next Step

**File a Red Hat support case** against the OGX operator / RHOAI 3.5 for the
`odh-ogx-core-rhel9` OCI-label-fetch registry-auth 401. This is not
addressable from the toolkit side — see the "Ruled out" table above for
everything already attempted at the cluster/manifest level.

## Workaround / Current State

**See also:** [docs/bugs/autorag-ogx-3.5-cascade.md](../bugs/autorag-ogx-3.5-cascade.md) — full AutoRAG bring-up cascade (Issues 1–6).

### Early workaround: `spec.baseConfig` (insufficient alone)

**Workaround found (RHOAIENG-96724, Oct 2026):** Supply the base OGX configuration
via a ConfigMap (`spec.baseConfig`) to bypass the failing anonymous OCI-label fetch.
This gets past `ConfigGenerationFailed` / HTTP 401 but is **not** sufficient for a
working AutoRAG OGX — it leads into Issues 2–5 (watch label, empty tokens, CRD
config strip, nomic offline). Do not stop here for AutoRAG.

1. **Extract the base config from the pinned image digest** using a working
   `registry.redhat.io` credential (the cluster's pull-secret works):
   ```bash
   DIGEST=$(oc get deployment -n redhat-ods-applications -l app.kubernetes.io/name=ogx-k8s-operator \
       -o jsonpath='{.items[0].spec.template.spec.containers[0].env[?(@.name=="RELATED_IMAGE_ODH_OGX_CORE_IMAGE")].value}')
   oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > /tmp/ps.json
   oc image info "$DIGEST" --registry-config=/tmp/ps.json --filter-by-os=linux/amd64 -o json | \
       python3 -c "import json,sys,base64; d=json.load(sys.stdin); print(base64.b64decode(d['config']['config']['Labels']['com.ogx.config.config.yaml']).decode())" \
       > /tmp/ogx-config.yaml
   rm /tmp/ps.json
   ```

2. **Create a ConfigMap and patch the OGXServer:**
   ```bash
   oc create configmap rh-ogx-base-config --from-file=config.yaml=/tmp/ogx-config.yaml -n <namespace>
   oc label configmap rh-ogx-base-config ogx.io/watch=true -n <namespace>
   oc patch ogxserver <name> -n <namespace> --type=merge \
       -p '{"spec":{"baseConfig":{"name":"rh-ogx-base-config","key":"config.yaml"}}}'
   ```

3. **CRITICAL: Label ALL Secrets referenced by the OGXServer with `ogx.io/watch: "true"`:**
   ```bash
   oc label secret ogx-secret ogx.io/watch=true -n <namespace>
   ```
   Without this label, the operator's namespace-scoped cache cannot see the Secret
   and reports "Secret not found" even though it exists and RBAC allows access.
   This is a separate bug from the OCI 401 — the operator only watches resources
   with the `ogx.io/watch` label across namespaces.

**Result of baseConfig alone:** OGXServer moves from
`Phase: Failed (ConfigGenerationFailed: HTTP 401)` to
`Phase: Initializing (ConfigGenerated: succeeded, 13 providers)`. Further
CrashLoop / AutoRAG failures are documented in the cascade doc (Issues 3–5).

### Current toolkit solution: `overrideConfig` + `rh-dev`

Do **not** use `rh` + `baseConfig` + CRD providers — that re-enters the broken
merge path. The toolkit path is:

- `spec.overrideConfig` → `llama-stack-config` ConfigMap
- `distribution.name: rh-dev`
- No providers in the CRD spec; inject `PGVECTOR_*` / `VLLM_*` via `workload.overrides.env`
- Deploy pgvector; strip nomic; patch vLLM to internal InferenceService URL

Manifest: `demo/autorag-demo/manifests/ogxserver.yaml`. Details and remaining
issues: [autorag-ogx-3.5-cascade.md](../bugs/autorag-ogx-3.5-cascade.md).

`demo/autorag-demo/deploy.sh` now applies the **full** cascade workaround
(`overrideConfig` path) automatically when `USE_OGX=true` (RHOAI 3.5+), not only
`baseConfig`.

`redhat-registry-pull-secret` and the `$HOME/.docker/config.json` volume
mounts added to both OGX operator Deployments during the original investigation (see
ruled-out item #4) were left in place — they are harmless.

## References

- Full AutoRAG / OGX cascade (Issues 1–6): [`docs/bugs/autorag-ogx-3.5-cascade.md`](../bugs/autorag-ogx-3.5-cascade.md)
- Session notes with full investigation timeline: `docs/TODO-next-session.md`
  (local, gitignored session tracker — search for "OGXServer registry-auth 401")
- Toolkit demo exercising this: `demo/autorag-demo/`
- Version-gating rule for OGX vs Llama Stack: `.cursor/rules/openshift-ai-toolkit.mdc`
- Tracker: [`docs/COMPATIBILITY-TRACKER.md`](../COMPATIBILITY-TRACKER.md) TRK-004
