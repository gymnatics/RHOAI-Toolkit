---
name: toolkit-ops
description: >-
  Operate the rhoai-toolkit end to end and verify that every layer actually works: infrastructure
  (cluster, nodes, GPU, storage, identity), platform (operators, channels, DSC/DSCI, components,
  dashboard flags incl. TP/DP labelling, hardware profiles, gateway), model serving, MaaS, each demo,
  and the Jupyter notebooks inside RHOAI workbenches (env injection, repo clone, imports, endpoint
  reachability, optional headless execution). Failures are debugged against official Red Hat docs
  with the rhoai-knowledge skill. Trigger on "/toolkit-ops", "check the cluster", "verify the
  install", "is the demo working", "did X deploy properly", "check the notebooks/workbench",
  "health check", "smoke test", "set up a cluster with the toolkit", "debug <demo/component>".
---

# toolkit-ops

Run the toolkit and prove each step worked. The checks are read-only bash scripts in `checks/`. Every
FAIL comes with a hint and a playbook row, and gets fact-checked against official docs before any fix.

`$SKILL` = `.claude/skills/toolkit-ops` (relative to the repo root). Run everything from the repo root.

## Rules

1. **Read-only by default.** The `checks/*.sh` scripts only run `oc get/describe/auth can-i/whoami`,
   `oc get --raw` (service proxy GET), and `oc exec` for `env`, `test`, `git log`, and `python3` probes.
   `tests/run-tests.sh` asserts this.
2. **Ask before anything that changes the cluster or runs code**, and say what it will do:
   install scripts, `demo/*/deploy.sh`, `scripts/verify-maas.sh` (deploys a simulator, creates API keys),
   `scripts/diagnose-maas.sh --fix`, `scripts/refresh-notebook-env.sh` (deletes workbench pods),
   restarting workbenches, `oc patch/apply/delete`, and `check-notebooks.sh --execute` (runs notebook
   code that may call models or write to S3/MLflow/EvalHub). Approval covers that one action only.
3. **Never acknowledge upgrade gates in bulk** (`odh-upgrade-acks`). Do the remediation first.
4. **Facts come from official docs.** When a check fails or something is missing, use the
   `rhoai-knowledge` skill (live red-hat-docs MCP) to confirm the expected state before calling it a
   bug or "fixing" it. The toolkit's own docs can be wrong (e.g. TOOLKIT-CONTEXT says Kueue `Managed`
   is "rejected"; the docs say deprecated, and it stops reconciliation alongside the Kueue operator).
5. **Always pass `-n <namespace>` to demo deploy scripts** (8 scripts mis-parse a leading flag).
6. Set the cluster context first: `export KUBECONFIG=<path>` (or `scripts/manage-kubeconfig.sh`).

## Modes

| Mode | What to do |
|---|---|
| `preflight` | `checks/check-infra.sh [--aws]`. Before an install, or when nothing works. |
| `install` | Follow "Operate" below, running the matching check after each step. |
| `verify` (default) | `checks/run-all.sh --report docs/test-reports/toolkit-ops-$(date +%F).md`, then triage. |
| `demo <name>` | `checks/check-demos.sh --demo <name>`, then `checks/check-notebooks.sh --demo <name>` if it has notebooks. |
| `notebooks` | `checks/check-notebooks.sh [--demo X] [--all-workbenches]`. Add `--execute` only with approval. |
| `debug <symptom/check-id>` | "Debug loop" below. |
| `full` | preflight → verify all phases → debug every FAIL → write back findings → report. |

All check scripts accept `--json`, `--quiet`, `--timeout N`. Results accumulate in `$TOOLKIT_OPS_RESULTS`
(TSV), so several scripts in one shell produce one summary. Exit code 1 means at least one FAIL.

## Check scripts

| Script | Covers |
|---|---|
| `check-infra.sh` | tools, reachability, identity/IdP/cluster-admin, OCP version window (+ llm-d 4.20, MCP LCO 4.22), ClusterVersion/ClusterOperators, CSRs, node capacity, GPU allocatable/taints/MachineSets, default StorageClass, no ODH, no OSSM2, UWM |
| `check-platform.sh` | operator Subscriptions/CSVs/channels (fast-3.x, RHCL 1.4.x, Kueue 1.3), InstallPlans, lifecycle, DSCI, DSC phase/ReconcileComplete/upgrade gates, every component vs `datasciencecluster-v3-3X.yaml`, MCP LCO vs OCP, Kueue/JobSet rules, unhealthy pods, dashboard flags (DP warnings, removed flags, drift vs patch manifest), dashboard URL, Gateways, HardwareProfiles (GPU toleration, Kueue namespaces), S3 backends |
| `check-serving.sh [-n ns] [--probe]` | InferenceService / LLMInferenceService Ready, pods, hardware-profile annotations, `/v1/models` via API service proxy |
| `check-maas.sh [--no-diagnose]` | DSC field + conditions, CRDs, maas-api, DB secret, tenant, gateway (+hostname), Kuadrant, Authorino TLS, MaaSModelRefs, auth enforced on `/v1/models`, plus `diagnose-maas.sh --json` |
| `check-demos.sh [--demo X] [--list]` | per-demo resources from `checks/demo-specs.conf`. Undeployed demos are SKIP, unless requested with `--demo`, then FAIL |
| `check-notebooks.sh` | workbench Ready/stopped/image tag/repo clone/env drift/MLflow env, then per notebook from `checks/notebook-specs.conf`: file present, env vars, URLs reachable from the pod, imports, run class. `--execute` runs notebooks with `jupyter nbconvert` into `/tmp/toolkit-ops/` in the pod; `--force` also runs long/needs-data notebooks |
| `run-all.sh [--phases ...] [--demo X] [--report F]` | all phases in order; stops if the cluster is unreachable |

## Operate: install from scratch with a check after each step

Use `/manual-setup-configs` for the by-hand equivalent of any step.

| # | Step (toolkit command) | Then verify |
|---|---|---|
| 0 | Cluster: `scripts/check-aws-prerequisites.sh`, then `scripts/openshift-installer-master.sh` (or `scripts/integrated-workflow-v2.sh` end to end) | `check-infra.sh --aws` |
| 1 | Users/IdP (kubeadmin is not allowed for RHOAI): `scripts/setup-users.sh` | `check-infra.sh` (identity rows) |
| 2 | GPU nodes: `scripts/create-gpu-machineset.sh --instance-type ... --apply`; `scripts/manage-gpu-nodes.sh start` | `check-infra.sh` (gpu rows; allocatable needs NFD + GPU operator from step 3) |
| 3 | RHOAI + prerequisites: `scripts/install-rhoai-35.sh --channel stable-3.5 [--skip-maas] [--enable-tp-features] [--enable-observability]` | `check-platform.sh` |
| 4 | Storage: `scripts/setup-model-storage.sh --backend seaweedfs` | `check-platform.sh` (storage) |
| 5 | Hardware profiles: `scripts/create-hardware-profile-quick.sh --all` | `check-platform.sh` (hwprofile) |
| 6 | Dashboard flags: `scripts/enable-dashboard-features.sh` (tell the user which flags are DP) | `check-platform.sh` (dashboard) |
| 7 | MaaS (OCP 4.20+): `scripts/setup-maas.sh`; model `scripts/deploy-maas-model.sh --model simulator` | `check-maas.sh`, `check-serving.sh --probe`; with approval: `scripts/verify-maas.sh` |
| 8 | Demos: `demo/<name>/deploy.sh -n <ns>` (or `scripts/deploy-demo-environment.sh --components ...`) | `check-demos.sh --demo <name>` |
| 9 | Workbench demos: after deploy, check env drift; restart the workbench if needed (approval) | `check-notebooks.sh --demo <name>`; with approval: `--execute` |
| 10 | Report | `run-all.sh --report docs/test-reports/toolkit-ops-<date>.md` |

On OCP < 4.22, step 3 enables `mcplifecycleoperator`, which the docs require 4.22+ for: expect
`dsc/mcplifecycleoperator-ocp` FAIL and offer to set it `Removed`.

## Debug loop (for every FAIL, and every WARN the user cares about)

1. **Read the result**: message plus `->` hint. Find the row in `reference/debug-playbook.md`.
2. **Collect evidence (read-only)**: the commands in the playbook row (`oc describe`, events, logs,
   `oc exec ... env`). Also check `docs/TROUBLESHOOTING.md`, `docs/bugs/`, `docs/COMPATIBILITY-TRACKER.md`,
   and `graphify query "<symptom>"` / `graphify explain "<path>::<fn>()"` for the code involved.
3. **Fact-check with `rhoai-knowledge`** (invoke the skill; live MCP first): what do the official docs
   say the state should be? Prerequisites, supported versions, tier (GA/TP/DP), known issues and
   workarounds for this component. Cite URL + `lastModified`. If docs and toolkit disagree, the docs win
   for product facts. `reference/expected-state.md` lists the facts already verified, so re-check only
   when stale or disputed.
4. **Classify**: cluster/environment problem, toolkit bug (script/manifest/notebook), product known
   issue (Jira), or doc conflict.
5. **Propose the fix**: the toolkit command or patch, its effect, and the source. Wait for approval if it
   changes the cluster or the repo.
6. **Re-run the failing check** (same script, `--demo`/`-n` to narrow) and show before/after.
7. **Write back** (see the end of the playbook): compat tracker for toolkit-vs-docs gaps,
   TROUBLESHOOTING for new symptom/fix pairs, `docs/bugs/` for upstream bugs, `checks/` + `tests/`
   when a check was wrong.

## Report format

Start with totals (PASS/WARN/FAIL/SKIP) and OCP/RHOAI versions. Then one line per FAIL:
`check id → cause → fix (source)`. Then WARNs grouped (DP features in use, stale images, drift).
Say what was not checked (SKIP, notebooks not executed, no approval for E2E). Save reports under
`docs/test-reports/`.

## Known toolkit defects the checks will surface

Details and file:line in `reference/demo-checks.md` ("Defects found"):
- workbench env not applied on first deploy (env-drift FAIL)
- `${1:-ns}` flag parsing in 8 demo scripts
- autorag `local` at top level (3.5 OGX path aborts)
- `:3.4` workbench image tags on 3.5
- MCP LCO enabled on OCP < 4.22
- DP dashboard flags labelled TP (TRK-001)
- several notebooks that cannot run headless (missing pip cell, `input()`, bucket mismatches, keys never injected)

## Maintaining this skill

- New/changed demo: edit `checks/demo-specs.conf` (and `notebook-specs.conf`), then update
  `reference/demo-checks.md`.
- New RHOAI version: re-verify `reference/expected-state.md` with rhoai-knowledge, add the
  `datasciencecluster-v3-3X.yaml` case in `check-platform.sh`, and extend the version gates. See
  `/rhoai-version-bump`, which should call `checks/run-all.sh` for its test phase.
- Test offline after any change: `bash $SKILL/tests/run-tests.sh` (fake `oc`/`curl` + fixture cluster,
  asserts results and that no mutating `oc` verb was attempted). Add a fixture + assertion for new rules.
