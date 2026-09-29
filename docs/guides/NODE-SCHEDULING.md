# Worker Node Scheduling (Cost Saving)

Scale worker and GPU MachineSets up during business hours and down outside
them, saving AWS EC2 costs on sandbox/demo clusters.

## How it works

Two Kubernetes CronJobs in the `node-scheduler` namespace:

| CronJob | Schedule | Action |
|---|---|---|
| `worker-scaleup` | 8:00 AM Mon-Fri (Asia/Singapore) | Scale workers to daytime replica counts |
| `worker-scaledown` | 6:00 PM Mon-Fri (Asia/Singapore) | Scale all workers to 0 |

Weekend: nodes stay scaled down from Friday 6 PM to Monday 8 AM.

### Why the cluster stays healthy off-hours

The 3 control-plane nodes have `mastersSchedulable: true` and the `worker`
role, meaning they can run regular workloads. With all extra workers scaled
to 0 off-hours:

- The cluster API is always reachable
- Control-plane pods (etcd, API server, controller-manager, etc.) are
  unaffected
- Operators continue running on control-plane nodes
- Workload pods that were on worker nodes get evicted; they reschedule to
  control-plane nodes if they fit, or stay Pending until workers return
- GPU workloads (tainted nodes) won't schedule until the GPU MachineSet
  scales back up

### Default replica targets

| MachineSet | Business hours | Off hours |
|---|---|---|
| `*worker*2a*` (m5a.4xlarge) | 2 | 0 |
| `*worker*2b*` (m5a.4xlarge) | 1 | 0 |
| `*worker*2c*` (m5a.4xlarge) | 0 | 0 |
| `*gpu-worker*` (g6e.xlarge) | 1 | 0 |

These are set via env vars in the scale script ConfigMap
(`lib/manifests/node-scheduler/scale-script-configmap.yaml`). Edit and
re-apply to change counts.

## Usage

```bash
# Deploy the CronJobs
./scripts/setup-node-scheduler.sh

# Manually scale down right now
./scripts/setup-node-scheduler.sh --trigger down

# Manually scale up right now
./scripts/setup-node-scheduler.sh --trigger up

# Check status and next scheduled run
./scripts/setup-node-scheduler.sh --status

# Remove everything
./scripts/setup-node-scheduler.sh --remove
```

Direct Kustomize path:

```bash
oc apply -k lib/manifests/node-scheduler/

# Manual trigger:
oc create job --from=cronjob/worker-scaledown manual-down -n node-scheduler
oc create job --from=cronjob/worker-scaleup   manual-up   -n node-scheduler
```

## Changing the schedule

Edit the CronJob manifests directly:

- [`lib/manifests/node-scheduler/cronjob-scaleup.yaml`](../../lib/manifests/node-scheduler/cronjob-scaleup.yaml) — `spec.schedule` and `spec.timeZone`
- [`lib/manifests/node-scheduler/cronjob-scaledown.yaml`](../../lib/manifests/node-scheduler/cronjob-scaledown.yaml) — same

Then re-apply:

```bash
oc apply -k lib/manifests/node-scheduler/
```

## Changing replica targets

Edit the `do_up()` and `do_down()` functions (or the env-var defaults) in
[`lib/manifests/node-scheduler/scale-script-configmap.yaml`](../../lib/manifests/node-scheduler/scale-script-configmap.yaml),
then re-apply. The MachineSet name matching uses suffix patterns
(`*gpu-worker*`, `*worker*2a*`, etc.) to stay cluster-agnostic.

## RBAC

The CronJobs use a dedicated `node-scheduler` ServiceAccount with a narrow
ClusterRole that can only `get`, `list`, `patch`, and `update` MachineSets
in `machine.openshift.io`. It cannot create/delete MachineSets, access
secrets, or touch any other resources.

If the cluster also has the
[restricted client admin](RESTRICTED-CLIENT-ADMIN-ACCESS.md)
`ValidatingAdmissionPolicy`, the CronJob's service account is automatically
exempt (the policy skips all `system:` service accounts).

## Alternative for GPU nodes: AWS stop/start instead of delete/recreate

Scaling a MachineSet to 0 **deletes** the Machine and its EC2 instance;
scaling back up **provisions a brand-new instance from scratch** (full RHCOS
boot, ignition, cluster join, GPU Operator driver/toolkit reinstall). For
virtualized GPU workers (`g6e.xlarge`, etc.) this is a few minutes and is
what the CronJobs above do by default. For **bare metal** GPU nodes (e.g.
`g4dn.metal`), this full re-provisioning can take 15-30+ minutes, and if the
node belongs to a custom MachineConfigPool it can trigger unrelated MCO
churn while it re-renders that pool's config.

[`scripts/manage-gpu-nodes.sh`](../../scripts/manage-gpu-nodes.sh) instead
AWS-stops/starts the *same* EC2 instance, leaving the Machine object alone:

```bash
./scripts/manage-gpu-nodes.sh status   # AWS power state + Node Ready, per GPU machine
./scripts/manage-gpu-nodes.sh stop     # AWS-stop all GPU instances now
./scripts/manage-gpu-nodes.sh start    # AWS-start them, wait for Nodes to rejoin Ready
```

This preserves the EBS root volume, node identity, and any already-installed
GPU drivers, so resuming takes a couple of minutes instead of a full
reprovisioning cycle. It requires `aws` CLI credentials for the account
hosting the cluster (this script talks to AWS directly, unlike the
credential-free, in-cluster CronJob approach above). It is not currently
wired into the CronJob schedule -- run it manually, or swap it in for the
`oc scale machineset` calls in
[`scale-script-configmap.yaml`](../../lib/manifests/node-scheduler/scale-script-configmap.yaml)
if you want it automated (that requires injecting AWS credentials into the
cluster as a Secret, which the default CronJob design deliberately avoids).
