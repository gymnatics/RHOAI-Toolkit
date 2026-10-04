# Restricted Client Admin Access

Give a client/customer a `cluster-admin` login they can use freely (projects,
workloads, operators, RBAC, cluster config) **without** letting them change
worker or control-plane node counts — i.e. no editing MachineSets, Machines,
ControlPlaneMachineSets, MachineHealthChecks, MachineAutoscalers,
ClusterAutoscalers, or deleting Node objects. Useful when handing off a
sandbox/demo cluster where node count controls the AWS bill.

## Why this needs more than RBAC

Kubernetes RBAC is **additive only** — there is no "deny" rule. The built-in
`cluster-admin` ClusterRole is a single wildcard rule
(`apiGroups: ["*"], resources: ["*"], verbs: ["*"]`), so you cannot grant
"cluster-admin minus a few resource types" with RBAC alone.

Two ways to actually restrict it:

| Approach | What they lose | What they keep |
|---|---|---|
| Bind `admin` (cluster-wide) + `cluster-reader` instead of `cluster-admin` | Machine API (by omission) **and** operator installs, cluster-wide config, storage classes, etc. | Full control within every namespace, read-only cluster view |
| Grant real `cluster-admin` + a `ValidatingAdmissionPolicy` that denies Machine API mutations (this guide) | Only Machine API / node-count changes | Everything else — this is genuinely "admin except X" |

This toolkit uses the second approach: a `ValidatingAdmissionPolicy` runs at
the **admission** layer, *after* RBAC authorization succeeds, and can
unconditionally deny a request no matter how permissive the caller's RBAC is.
Requires Kubernetes 1.30+ / OpenShift 4.17+ (GA `admissionregistration.k8s.io/v1`
`ValidatingAdmissionPolicy`).

## What gets deployed

- `lib/manifests/rbac/restricted-admin/validatingadmissionpolicy.yaml` — denies
  `CREATE`/`UPDATE`/`DELETE` (including the `machinesets/scale` subresource) on
  `machine.openshift.io` and `autoscaling.openshift.io` resources, and `DELETE`
  on `Node`, for any request that is not a `system:` service account and not
  in the `infra-owners` group.
- `lib/manifests/rbac/restricted-admin/validatingadmissionpolicybinding.yaml` —
  binds the policy with `validationActions: [Deny]`.
- An `infra-owners` OpenShift `Group` — the break-glass exemption. Add your
  own account(s) here; this group is never bound to any role — it only
  exists to be checked in the policy's `matchConditions`.

## Usage

```bash
# 1. Create the client's cluster-admin login, restricted from Machine API,
#    and add yourself as the exempt break-glass owner
./scripts/create-restricted-client-admin.sh \
  --client-user client-admin \
  --client-password '<generated-password>' \
  --owner-user admin

# 2. Verify the policy actually blocks the client but not you
./scripts/create-restricted-client-admin.sh --test --client-user client-admin

# 3. (Optional) revoke the client's cluster-admin binding later
./scripts/create-restricted-client-admin.sh --remove --client-user client-admin
```

Direct Kustomize path also works (manifests are the source of truth):

```bash
oc apply -k lib/manifests/rbac/restricted-admin/
oc adm groups new infra-owners
oc adm groups add-users infra-owners <your-username>
oc create clusterrolebinding client-admin-cluster-admin --clusterrole=cluster-admin --user=client-admin
```

## Verifying manually

```bash
# As the client (real login, not `oc --as` impersonation — see caveat below):
oc login -u client-admin -p '<password>' https://api.<cluster>:6443
oc scale machineset <name> -n openshift-machine-api --replicas=5
# -> denied by ValidatingAdmissionPolicy 'protect-machine-infrastructure'

oc new-project client-smoke-test   # -> still works, still cluster-admin
```

### `oc --as` impersonation caveat

`oc <verb> --as=<user>` only sets `system:authenticated` as the impersonated
user's groups **unless you also pass `--as-group`**. It does not re-resolve
OpenShift `Group` CR membership the way a real OAuth/OIDC login does. If you
test the exemption via impersonation, you must add
`--as-group=infra-owners --as-group=system:authenticated` or the owner will
appear to be incorrectly blocked. The `--test` flag in
`create-restricted-client-admin.sh` tests the client (who has no exemption,
so this doesn't matter for them); always verify the owner exemption with a
real `oc login`, not impersonation.

## Notes / limitations

- Exemption is by OpenShift `Group` membership, not username, so you can add
  multiple break-glass owners: `oc adm groups add-users infra-owners <user>`.
- `system:` service accounts (machine-api-operator, cluster-autoscaler,
  machine-config-controller, etc.) are excluded from the policy so normal
  cluster operation (autoscaling, machine health remediation) is unaffected.
- This does **not** stop the client from installing their own autoscaler-like
  controller in a different namespace — it only governs the standard Machine
  API/autoscaling.openshift.io resources and Node deletion. It's meant as
  guardrails against accidental/normal-UI resizing, not a hostile-tenant
  sandbox boundary.
- `failurePolicy: Fail` — if the API server can't evaluate the policy, the
  request is denied (fail-closed) rather than silently allowed.
- **The policy cannot self-protect.** Kubernetes excludes
  `admissionregistration.k8s.io` from `ValidatingAdmissionPolicy` enforcement
  (by design, to prevent permanent cluster lockout). A determined client with
  `cluster-admin` could discover and delete the policy via
  `oc delete validatingadmissionpolicybinding`. This is a known Kubernetes
  design limitation — RBAC also can't subtract from `cluster-admin`'s
  wildcard rule. The guardrail effectively blocks accidental/console-based
  resizing (the OpenShift console doesn't surface VAP management), but is
  not a hostile-tenant isolation boundary.
