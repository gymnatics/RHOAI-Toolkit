---
name: manual-setup-configs
description: >-
  Retrieve (and optionally refresh) the manual RHOAI cluster setup checklist with
  copy-paste commands: prerequisite operators and channels, DSCInitialization,
  DataScienceCluster component states (Managed/Removed/Unmanaged), OdhDashboardConfig
  flags labelled GA / Technology Preview / Developer Preview, hardware profiles, object
  storage (SeaweedFS/MinIO/ODF/S3), model source URLs (registry.redhat.io modelcars,
  quay.io), and model deployment (InferenceService vs LLMInferenceService, MaaS).
  Trigger on "/manual-setup-configs", "manual setup", "set up a new cluster by hand",
  "what DSC components to enable", "which dashboard flags", "what operators do I need",
  "S3 / object storage setup", "modelcar / quay URL".
argument-hint: "[section: operators|dsc|dashboard|storage|models|maas|no-maas|all] [--refresh]"
---

# Manual Setup Configs

Canonical doc: `docs/guides/rhoai-3.5/RHOAI-35-MANUAL-SETUP-CONFIGS.md`. Its header has a `Last verified` date.

The doc is **standalone**: users may not have the toolkit repo, so every resource appears as full inline YAML (`oc apply -f - <<'EOF'`). It's **generated**:
- Source: `.claude/skills/manual-setup-configs/template.md`. Prose and commands go here, and `{{file:lib/manifests/...}}` markers mark where YAML is inlined.
- Renderer: `python3 .claude/skills/manual-setup-configs/render.py`. It copies each referenced manifest verbatim into the doc. `--check` exits 1 if the doc is stale against the template or manifests.
- **Never edit the generated doc directly.** Edit `template.md`, then re-render.

## Workflow

### 1. Retrieve (default)
1. Read the doc.
2. If the user named a section (operators, dsc, dashboard, storage, models, maas), return only that section's table and commands. Otherwise give a short overview of steps 0–12 and offer the sections.
   - **Ask or infer which workflow applies:** A (with MaaS, steps 0–12) or **B (without MaaS)**, the "Workflow B" section, which gives substitutions for steps 1, 2, 5, 6, 10 and 12 plus B.9 "Adding MaaS later". `no-maas` = return Workflow B. Never hand Workflow B users the step 2 / 10b MaaS commands.
3. Always surface these caveats when they're relevant to what was asked:
   - Channel `stable-3.5`, never `fast-3.x` (frozen at 3.3.1).
   - Developer Preview flags (`agentsCatalog`, `agentConfigManagement`) are unsupported.
   - Kueue `Managed` is rejected (use Unmanaged); Kueue 1.3 is not available on OCP 4.22.
   - `maasAuthPolicies` must not be set on 3.5.
   - RHCL 1.4.x rate-limit bug (RHOAIENG-76586).
4. If the user has a live cluster and asks for it, you may run read-only checks (`oc get packagemanifest`, `oc get dsc -o json`, `oc get odhdashboardconfig`). Never apply or patch without explicit go-ahead.
5. If the user's cluster runs a different RHOAI version than the doc covers, say so before giving commands. 3.4 uses `kserve.modelsAsService` and `llamastackoperator`, has `maasAuthPolicies` required, and has no `aigateway`/`ogx`/`mcplifecycleoperator`. 3.6 uses DSC v3 and is not yet covered.

### 2. Refresh (`--refresh`, or when `Last verified` is >30 days old, or a new RHOAI z/y release is out)
1. Read `docs/COMPATIBILITY-TRACKER.md` for open items affecting setup (channels, images, flags, DSC fields, operator versions).
2. Verify against sources. These are independent, so run them in parallel:
   - Repo: re-read the manifests the doc cites (`lib/manifests/operators/*`, `lib/manifests/rhoai/datasciencecluster-v3-35.yaml`, `odh-dashboard-config-*.yaml`, `hardware-profile-gpu.yaml`, `lib/manifests/storage/*`, `lib/manifests/maas/models/*/llm/model.yaml`) and check that paths, channels, and images still match.
   - Official/upstream (a `general-purpose` agent with WebFetch): RHOAI release notes (TP/DP/removals/known issues), Supported Configurations, and odh-dashboard `rhoai-X.Y` flag definitions (`frontend/src/concepts/areas/const.ts`), plus rhods-operator DSC types.
3. Run `render.py --check` first. If it reports STALE, the manifests changed since the last render; re-render and review the diff of the inlined YAML.
4. Edit `template.md`: tables, prose, commands, `{{file:...}}` markers (add a marker for any new manifest; never hand-copy YAML), and bump `Last verified`. Then run `render.py`, and validate that every inlined YAML block parses (`yq`). For bulk mechanical edits from a verified digest, you may delegate to `sonnet-scribe` (template only), then review its diff.
5. Record any new divergence in `docs/COMPATIBILITY-TRACKER.md` (`compat-tracker` skill, mode A).
6. When a new RHOAI minor version GAs, copy `template.md` to `template-X.Y.md`, point it at the new version's manifests, and give `render.py` an output path per template (e.g. `docs/guides/rhoai-X.Y/RHOAI-XY-MANUAL-SETUP-CONFIGS.md`). Keep the old doc for clusters still on that version.

## Rules
- The doc is the single source. Answer from it, not from memory. If the doc and the repo disagree, say so and fix the doc.
- Label every dashboard flag and DSC component with its support tier (GA / TP / DP / Deprecated).
- Inline YAML for repo-backed resources must come from `{{file:...}}` markers, so `lib/manifests/` stays the source of truth. Hand-written YAML is only for user-specific resources (InferenceService examples, secrets).
- Toolkit scripts may appear only as optional "Toolkit shortcut" notes. Every step must be completable with `oc`, `jq`, `yq`, `envsubst` and `openssl` alone.
- Never put real credentials in the doc. Use placeholders or `openssl rand`.
