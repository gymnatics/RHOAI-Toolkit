# Bug Report: OGXServer Reconciliation Fails with HTTP 401 Fetching OCI Config Labels

**Status**: Open, unresolved. Recommended action: file a Red Hat support case.

**Component**: OGX Operator (`ogx-k8s-operator`, replaces the Llama Stack Operator in RHOAI 3.5+)

**Affected versions confirmed**: RHOAI 3.5.0 and RHOAI 3.5.1 (auto-upgrade did not fix it)

**Severity**: High — blocks all OGX-based RAG/agent workflows (AutoRAG demo, any RHOAI 3.5+ Llama Stack replacement use case) on affected clusters.

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
   apiVersion: ogx.io/v1alpha1  # exact group/version per installed CRD
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

None found that unblocks `OGXServer` itself. As a partial mitigation, the
non-OGX AutoRAG infrastructure (S3-compatible storage, Milvus, Postgres,
embedding model, sample docs/data connection) deploys and runs healthy
independently — only the OGX-based RAG orchestration layer itself is
blocked.

`redhat-registry-pull-secret` and the `$HOME/.docker/config.json` volume
mounts added to both OGX operator Deployments during investigation (see
ruled-out item #4) were left in place — they are harmless, and in case a
future operator patch changes its credential-resolution logic to honor that
convention, the mount is already there and would "just work" without
further toolkit changes.

## References

- Session notes with full investigation timeline: `docs/TODO-next-session.md`
  (local, gitignored session tracker — search for "OGXServer registry-auth 401")
- Toolkit demo exercising this: `demo/autorag-demo/`
- Version-gating rule for OGX vs Llama Stack: `.cursor/rules/openshift-ai-toolkit.mdc`
