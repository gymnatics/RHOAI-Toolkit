---
name: compat-tracker
description: >-
  Review, update, or add entries to docs/COMPATIBILITY-TRACKER.md -- the tracker of
  where the rhoai-toolkit diverges from official Red Hat / upstream state: what works,
  what is broken or mislabelled now (GA vs Technology Preview vs Developer Preview),
  and what will break on a future date or release (EOL, deprecations, new RHOAI
  versions, DSC/API changes). Trigger when the user says "compat tracker", "update
  the tracker", "what will break", "check against official docs", "review support
  tiers", "TP/DP check", "is the toolkit still current", "new RHOAI release", or after
  a deep repo/doc retrieval that surfaced gaps worth tracking.
---

# Compatibility Tracker Skill

Maintains `docs/COMPATIBILITY-TRACKER.md` (tracked in git). `TOOLKIT-CONTEXT.md`
(gitignored, `toolkit-context` skill) explains *what the repo is*; this tracker
records *how it lines up with reality over time*. Keep them consistent: if a review
changes a fact that TOOLKIT-CONTEXT also states, update both.

## Modes

Pick the lightest mode that satisfies the request.

### A. Add / update a single item (most common)
Use when a finding came up in conversation (bug hit on a live cluster, a doc read, a fix landed).
1. Read the tracker.
2. Search for an existing item covering it (grep the ID table for the file path, Jira ID, or flag name). Update in place rather than duplicate.
3. New item → next free ID in the right section: `TRK-0xx` open/monitoring (§2), `TRK-1xx` future breakage (§3). IDs are never reused.
4. Fill every column. Cite a verification tag (`[live]`, `[src]`, `[RN]`, `[repo]`, `[unverified]`) and the concrete source (URL, file:line, Jira ID, cluster + date).
5. Bump `Last reviewed` only for a full review (mode C); for single edits, add a row to §7 Review Log with scope "single item".

### B. Resolve items
Use after a fix is committed, or when upstream fixes a bug.
1. Verify the fix: grep the code at the cited `file:line`, or confirm the upstream release notes/known-issue status. Don't resolve on a guess.
2. Move the row to §6 Resolved Log with date, how, and commit hash. Remove it from §2/§3.
3. If a fix was verified on a cluster, add a row to §4 Verified Working.

### C. Full review
Use when asked for a full check, when a new RHOAI z/y-stream ships, or if `Last reviewed` is >30 days old.

1. **Read the tracker** and note `Last reviewed` + baseline commit.
2. **Repo delta** (yourself, cheap): `git log --oneline <baseline>..HEAD`, `git status --short`, `git diff --stat`. Note which tracked files changed.
3. **Launch 3 agents in parallel** (single message). Each prompt must be self-contained -- they share no context. Tell each to report a dense factual digest with a verification tag + source per fact, and to flag anything unverified.
   - **Agent 1, Official lifecycle & tiers** (`general-purpose`; needs WebFetch/WebSearch, load via ToolSearch `select:WebSearch,WebFetch`):
     - Lifecycle API: `https://access.redhat.com/product-life-cycles/api/v1/products?name=Red%20Hat%20OpenShift%20AI%20Self-Managed`
     - Supported configurations: `https://access.redhat.com/articles/rhoai-supported-configs` (raw HTML is better than WebFetch summaries)
     - Release notes for every supported version plus any new one, especially these chapters: **Technology Preview features**, **Developer Preview features**, **Support removals** (deprecated/removed), **Known issues**. URL pattern: `https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/<ver>/html/release_notes/{technology-preview-features_relnotes,developer-preview-features_relnotes,support-removals_relnotes,known-issues_relnotes}`
     - RHCL and OCP compatibility for MaaS.
   - **Agent 2, Upstream source** (`general-purpose`): on the newest `rhoai-X.Y` branches (including EA branches) of these repos:
     - `red-hat-data-services/rhods-operator` `api/datasciencecluster/*/datasciencecluster_types.go` and `api/components/v1alpha1/*_types.go`: DSC components and fields, deprecations, CEL rules
     - `red-hat-data-services/odh-dashboard` `frontend/src/concepts/areas/const.ts` and `backend/src/utils/constants.ts`: dashboard flags, defaults, and their group (`techPreviewFlags` = TP, `devTemporaryFeatureFlags` = DP, feature groups = GA)
     - `red-hat-data-services/RHOAI-Build-Config` `catalog/rhoai-*/v4.*/rhods-operator/catalog.yaml`: channels, latest z-streams, EA builds
     - `opendatahub-io/models-as-a-service` CRDs per release
   - **Agent 3, Repo cross-check** (`Explore`, "very thorough"): give it the current §2/§3/§5 rows (file paths, flags, CRDs, channels) and ask, for each, whether the cited code still exists, still has the problem, or has changed. Also ask it to list every place the toolkit sets an OdhDashboardConfig flag, DSC component, operator channel, or CRD apiVersion.
4. **Reconcile** yourself. The agents only gather; you decide and edit.
   - Update §1 Platform Snapshot.
   - For each open item: still true → keep; fixed → mode B; changed → edit the row.
   - For each §3 future item: has the trigger date passed or the release shipped? If yes, promote it to §2 (now broken) or resolve it.
   - Add new items for any of these: a feature the toolkit enables changed tier (especially to **DP**, or deprecated/removed); a new EOL date; a new release with API/DSC/flag changes; a known issue that affects a toolkit path; an official-doc conflict.
   - Update the §5 Support-Tier Usage Map columns, adding a column for each new version.
   - When sources conflict, record both in a TRK row tagged with each source, and recommend the conservative tier.
5. **Write** the tracker. Bump `Last reviewed` and `Baseline commit`, and add a §7 Review Log row with scope and counts (open/future/resolved).
6. If facts in `TOOLKIT-CONTEXT.md` (lifecycle table, flag tiers, known issues) changed, update those sections too.
7. Report to the user: new items, resolved items, promoted future→open items, and the top 3 actions by severity.

## What counts as trackable

| Track | Don't track |
|---|---|
| Toolkit enables/labels a feature at the wrong support tier (GA/TP/DP) | Generic product feature lists with no toolkit touchpoint |
| Code path that breaks or will break on a known version/date | Style nits, refactors |
| Known issue (Jira ID) affecting a toolkit script/demo, with or without a workaround | Bugs already fully fixed with no regression risk (resolve them instead) |
| Deprecated API/CRD/field/annotation the toolkit still writes | One-off cluster flakiness without a root cause |
| Official docs contradicting each other or the toolkit | |
| Things verified working on a live cluster (§4), as a regression baseline | |

## Rules
- Each item is one row. Keep rows dense and factual; link out to `docs/bugs/` or `docs/reference/` for long investigations.
- Always give `file:line` (or file + function) for repo touchpoints, so someone can act without searching.
- Use absolute dates (`2026-11-16`), never "in three weeks".
- Mark estimates explicitly: `est. Nov–Dec 2026 [unverified]`.
- Never delete history: resolved items go to §6, and the review log is append-only.
- Don't change toolkit code from this skill. It only records findings; fixes are separate tasks the user approves.
- Agents never write to the tracker directly.
