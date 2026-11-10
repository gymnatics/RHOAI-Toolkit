---
name: rhoai-version-bump
description: >-
  End-to-end workflow to move the rhoai-toolkit to a new RHOAI version (y-stream like
  3.6, or z-stream like 3.5.3), or to re-validate the current version: research
  changes (GA/TP/DP, removals, DSC/API/flag changes), plan and apply toolkit updates,
  run static tests, check cluster and demo permissions, install on a test cluster,
  deploy and smoke-test every demo, fix failures, update docs, and produce a test
  report. Trigger on "/rhoai-version-bump", "upgrade the toolkit to 3.6", "new RHOAI
  release", "support RHOAI X.Y", "test all demos", "make sure demos still work",
  "regression test the toolkit".
argument-hint: "<target-version e.g. 3.6 | 3.5.3> [--mode plan|update|test|full] [--demos all|core|<list>]"
---

# RHOAI Version Bump

Target: `$ARGUMENTS`

The main thread orchestrates. Subagents can't spawn subagents, so don't fork this skill. Follow the routing in `CLAUDE.md`:
- `general-purpose`: research
- `opus-planner`: plans and failure diagnosis
- `sonnet-executor`: code changes
- `sonnet-scribe`: docs
- `Explore`: repo sweeps

**Modes** (default `full`):

| Mode | Phases |
|---|---|
| `plan` | 1–2 (research and change plan only; no edits) |
| `update` | 1–4 (edit the toolkit and run static tests; no cluster) |
| `test` | 5–8 against the version already supported, for regression or z-stream validation |
| `full` | 1–8 |

Write progress to a run log: `docs/test-reports/rhoai-<target>-<YYYY-MM-DD>.md`, using the report template at the end. If the session is interrupted, read the log and resume from the last completed phase.

---

## Phase 1: Research what changed
1. Run the `compat-tracker` skill in **full review** mode, scoped to `<target>` and the version before it. Release-note chapters must include **Technology Preview**, **Developer Preview**, **Support removals** and **Known issues**, plus Supported Configurations, the lifecycle API, the operator catalog (including the `beta` channel for EA), rhods-operator DSC types, and odh-dashboard flag definitions on the `rhoai-<target>` branch.
2. Produce a **change digest**: new, renamed and removed DSC components and fields; CRD API version changes; dashboard flags (added, removed, tier or default changed); operator channel and minimum version changes (RHCL, Service Mesh, cert-manager, Kueue, LWS, GPU); OCP support window; image and modelcar path changes; deprecations; known issues that hit toolkit paths.

## Phase 2: Impact analysis and plan (approval gate)
1. Run an `Explore` agent ("very thorough") that receives the digest and returns, for every changed item, all repo locations (`file:line`) that reference it: scripts, `lib/functions`, `lib/utils/rhoai-version.sh`, `lib/manifests/**`, `demo/**`, Makefile, menus, docs, `.cursor/rules`.
2. Run `opus-planner` with the digest and the impact list. The plan must cover:
   - **Version plumbing:**
     - Add a version helper. Prefer a generic `rhoai_version_ge X.Y` over a new `is_rhoai_XY_or_higher`. If only the old per-version style exists, add the new one in the same style and note the refactor.
     - Add a new installer, or a profile if `lib/versions/` exists.
     - Add a new DSC manifest or overlay, and new dashboard config, RHCL operator and channel manifests.
   - **Removals:** every code path that writes a removed field or API gets a version gate.
   - **Pins:** image, modelcar and channel bumps, in `lib/versions/images.env` if it exists.
   - **Demos:** demo changes for API or flag changes.
   - **Verification:** the static tests from Phase 4 as verification commands.
3. Show the plan to the user and **wait for approval**. In `plan` mode, stop here and save the plan to the run log.

## Phase 3: Apply updates
1. Run `sonnet-executor` with the approved plan **verbatim**, plus a context digest: user constraints, the tracker items in scope, and the rules from `.cursor/rules/*.mdc`. Those rules are: manifests are the source of truth, use the `os-compat.sh` wrappers, and gate version-specific code with version checks.
2. Escalation follows `planning-workflow` Phase 5. Round 1 retries with the advisor. Round 2 sends the failure to `opus-planner` for a revised plan. Stop after 2 rounds and report.

## Phase 4: Static tests (no cluster)
Run these yourself in the main thread and record the results:
```bash
# Shell syntax for every script
find scripts lib demo rhoai-toolkit.sh -name '*.sh' -print0 | xargs -0 -n1 bash -n
# Lint if available (record, don't block on style-only warnings)
command -v shellcheck && shellcheck -S warning scripts/*.sh lib/functions/*.sh lib/utils/*.sh
# Every kustomization builds
find lib/manifests demo -name kustomization.yaml -exec dirname {} \; | while read d; do oc kustomize "$d" >/dev/null || echo "KUSTOMIZE FAIL: $d"; done
# Every YAML parses
find lib/manifests demo -name '*.yaml' -print0 | xargs -0 -n1 yq e '.' >/dev/null
# Templates render with dummy values (catch unbalanced ${VARS})
for t in $(find lib/manifests -name '*.tmpl'); do envsubst < "$t" | yq e '.' >/dev/null || echo "TEMPLATE FAIL: $t"; done
# Standalone manual guide still in sync with manifests
python3 .claude/skills/manual-setup-configs/render.py --check
# Removed/deprecated identifiers still written ungated (deny-list from the Phase 1 digest)
grep -rnE '<removed-field-1>|<removed-field-2>' scripts lib demo
```
In `update` mode, stop here and report.

## Phase 5: Preflight on the test cluster (permissions gate)
**Never test on a customer or shared cluster.** Use a disposable cluster, for example an RHDP sandbox. For EA targets, install from the `beta` channel.
1. Show the user the target and get explicit confirmation before any mutating command:
   ```bash
   oc whoami --show-server; oc whoami; oc get clusterversion -o jsonpath='{.items[0].status.desired.version}{"\n"}'
   ```
2. Check cluster permissions:
   ```bash
   oc auth can-i '*' '*' --all-namespaces                    # must be yes (cluster-admin)
   oc get nodes -l nvidia.com/gpu.present=true              # GPU capacity for GPU demos
   oc get packagemanifest rhods-operator -n openshift-marketplace -o jsonpath='{.status.channels[*].name}{"\n"}'
   ```
3. Check Claude Code permissions. The project allowlist (`.claude/settings.local.json`) already permits `oc`, `./scripts/*.sh` and `./demo/*/deploy.sh`. **Don't edit permission settings from this skill.** If prompts are excessive, suggest the user run `/fewer-permission-prompts`. Destructive steps (namespace deletion, `--delete`, uninstall, `cleanup-maas.sh`) always need the user's confirmation in this session.
4. Server-side dry run of all static manifests against the target cluster, which catches CEL and schema rejections:
   ```bash
   find lib/manifests -name '*.yaml' ! -path '*/templates/*' | while read f; do oc apply --dry-run=server -f "$f" >/dev/null 2>/tmp/dr.err || echo "DRYRUN FAIL: $f: $(head -1 /tmp/dr.err)"; done
   ```
   CRD-not-found failures for components that aren't installed yet are expected before Phase 6. Re-run the failures after install.

## Phase 6: Platform install and verification
1. Install with the target installer, in tmux, logging to `/tmp/rhoai-bump/install.log`. For 3.5, for example:
   `./scripts/install-rhoai-<XY>.sh --channel <stable-X.Y|beta> --enable-tp-features --enable-observability`
2. Verify:
   ```bash
   oc get csv -A | grep -v Succeeded | grep -v '^NAMESPACE'                     # empty
   oc get dsc default-dsc -o json | jq -r '.status.conditions[]|"\(.type)=\(.status)"'
   oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o jsonpath='{.spec.dashboardConfig}' | jq .
   ./scripts/verify-maas.sh            # MaaS E2E
   ./scripts/diagnose-maas.sh          # known post-upgrade issues (add --fix only with user OK)
   oc get apirequestcounts -o json | jq -r '.items[]|select(.status.removedInRelease!=null and .status.requestCount>0)|.metadata.name'   # deprecated APIs in use
   ```
3. Re-run the failures from Phase 5's dry run.
4. **Upgrade path, y-stream only:** on a second cluster, or after a fresh-install pass, install the previous version, then switch the Subscription channel to the target. Re-run step 2 to validate that upgrades work, not just fresh installs.

## Phase 7: Demo regression (deploy, smoke test, clean up)
Use the test matrix in `demo-test-matrix.md` (next to this file). For each demo, in the matrix order, which respects dependencies (a model first, then consumers):
1. Skip demos whose prerequisites aren't met (GPU count, NGC key, external API keys) and record them as `SKIPPED (<reason>)`, not as failures.
2. Deploy using the matrix command. Run long deploys in tmux with logs at `/tmp/rhoai-bump/demo-<name>.log`.
3. Run the matrix **readiness** checks (pods Ready, CRs Ready, routes respond), then the **functional** check (a real request or job that proves the demo works).
4. Check demo RBAC where the matrix lists a service account: `oc auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <ns>`.
5. Record PASS / FAIL / SKIPPED, timings, and the first error line in the run log.
6. Clean up with the matrix's cleanup command **only if the user chose clean-as-you-go** (ask once at the start of Phase 7). Otherwise leave demos deployed for inspection.

`--demos core` = the demos marked **core** in the matrix. `--demos <list>` = comma-separated matrix names.

## Phase 8: Fix loop, docs, report
1. For each FAIL, send `opus-planner` the demo name, the failing check, the log excerpt and the relevant files. It returns a diagnosis and a fix plan. Get user approval, apply with `sonnet-executor`, and re-test **that demo only**. At most 2 rounds per demo. After that, record it as an open item.
2. Upstream bugs (not toolkit bugs): add a `docs/COMPATIBILITY-TRACKER.md` row (`compat-tracker` mode A), with a Jira ID if known and the workaround.
3. Docs: give `sonnet-scribe` an exact facts digest to update:
   - `scripts/README.md`
   - affected `docs/guides/**`
   - `docs/TROUBLESHOOTING.md`
   - `.cursor/rules/rhoai-versions.mdc`
   - the demo READMEs

   Review its diff before finishing. Then run `/manual-setup-configs --refresh`, which creates the new-version doc for a y-stream, and refresh `TOOLKIT-CONTEXT.md` (`toolkit-context` skill, update mode).
4. Finalise the run log (template below) and summarise for the user: pass/fail matrix, changes made, open items, and recommended next steps.
5. **Never commit or push without the user asking.** Offer a commit message drafted by `sonnet-scribe`.

---

## Run log template (`docs/test-reports/rhoai-<target>-<date>.md`)
```markdown
# RHOAI <target> toolkit validation -- <date>
Mode: <mode> · Cluster: <server> (OCP <ver>, RHOAI <csv>) · Channel: <channel> · GPUs: <type x count>
Baseline commit: <sha> · Phases completed: <n>/8

## Change digest
## Changes applied (file -> summary)
## Static tests (Phase 4): <pass/fail per check>
## Platform verification (Phase 6): CSVs / DSC conditions / dashboard flags / MaaS / deprecated APIs
## Demo matrix (Phase 7)
| Demo | Result | Deploy time | Readiness | Functional | RBAC | Notes / first error |
## Fixes (Phase 8)
## Open items (-> tracker IDs)
```

## Rules
- Approval gates: Phase 2 (plan), Phase 5 (cluster identity), every destructive command, every Phase 8 fix.
- Keep the version facts and the tier labels (GA/TP/DP) consistent across tracker, rules, setup docs and context.
- Don't remove support for a version still in Full Support or EUS. Retire EOL versions only with user approval (move the scripts to `legacy/`).
- If `scripts/check-rhoai-drift.sh` or `scripts/test-demos.sh` exist, use them for Phases 5–7. If they don't, run the checks inline from this file and the matrix, and offer to build those scripts from the run log, so the next run is deterministic.
