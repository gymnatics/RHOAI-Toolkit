---
name: toolkit-context
description: >-
  Load, generate, or update the TOOLKIT-CONTEXT.md reference document that gives
  any new conversation full context about the rhoai-toolkit repo. Trigger when
  the user mentions "toolkit context", "get context", "read context", "what does
  this repo do", "update context", "regenerate context", "refresh context", or
  when starting a new conversation that needs repo-wide orientation. Also trigger
  when the user asks to "hand off" or "onboard" someone to the toolkit.
disable-model-invocation: false
---

# Toolkit Context Skill

Manage the `TOOLKIT-CONTEXT.md` reference document at the project root. This
document is the single canonical source of repo-wide context for new
conversations. It is gitignored (not source code).

## When to Use

- A new conversation needs to understand what the repo does and how it is
  structured.
- The user explicitly asks to read, generate, update, or refresh the toolkit
  context.
- The user wants to hand off or onboard someone to the toolkit.

## Workflow

### 1. Read (default -- most common)

If `TOOLKIT-CONTEXT.md` exists at the project root:

1. Read the file in full.
2. Use its contents as background context for the rest of the conversation.
3. Do NOT summarize it back to the user unprompted -- just confirm you have
   loaded it: "Loaded toolkit context (last generated: <date from header>)."

### 2. Generate or Regenerate

If `TOOLKIT-CONTEXT.md` does not exist, or the user asks to regenerate it:

1. Launch **5 Explore agents in parallel** (`Agent` tool, `subagent_type:
   "Explore"`, breadth "very thorough") in a single message, one per area
   below. Each prompt must be self-contained since fresh agents share no
   context with this conversation.

   **Agent 1 -- Scripts:**
   ```
   Explore scripts/ thoroughly. Read every script's header comments, usage/help
   text, and CLI flags. Categorize each script by function (Installation, MaaS,
   Model Deployment, GPU/Hardware, Diagnostics, Cleanup, Security, Observability,
   Storage, Utility, Orchestration). For each script, note: filename, one-line
   purpose, key flags. Report findings as a dense catalog, not prose.
   ```

   **Agent 2 -- Library Functions + Utilities:**
   ```
   Explore lib/functions/ and lib/utils/ thoroughly. For each file, list the key
   exported functions and their one-line purpose. Note which files source which
   other files. Also read lib/menus/ to understand the interactive menu
   structure. Report findings as a dense catalog, not prose.
   ```

   **Agent 3 -- Manifests:**
   ```
   Explore lib/manifests/ thoroughly. Map the full directory tree. For each
   subdirectory, note what Kubernetes resources it contains and their purpose.
   Pay special attention to: rhoai/ (DSC configs), rhcl/ (gateway/Istio),
   maas/ (models, external-models, oidc, platform), operators/, storage/,
   templates/. Report findings as a dense catalog, not prose.
   ```

   **Agent 4 -- Demo Applications:**
   ```
   Explore demo/ thoroughly. For each demo subdirectory, read its README.md and
   deploy.sh (if they exist). Note: demo name, what it demonstrates, deploy
   command, GPU requirements, namespace, key files. Also read demo/lib/ for
   shared utilities. Report findings as a dense catalog, not prose.
   ```

   **Agent 5 -- Docs, Rules, and Architecture:**
   ```
   Explore docs/ and .cursor/rules/ thoroughly (also check .claude/rules/ or
   CLAUDE.md if .cursor/rules/ doesn't exist). Read all rule files to extract
   architecture principles, critical gotchas, version compatibility, and coding
   conventions. Read docs/TROUBLESHOOTING.md for the key issues. List all guides
   in docs/guides/. Note the RHOAI version matrix and MaaS version differences.
   Report findings as a dense catalog, not prose.
   ```

2. Wait for all 5 agents to complete before continuing.

3. Synthesize their reports into `TOOLKIT-CONTEXT.md` using the **Template**
   below. Do the synthesis yourself -- the agents only gather raw data, they
   do not write to the file.

4. Write the file to the project root.

5. Confirm: "Generated TOOLKIT-CONTEXT.md with <N> sections."

### 3. Edit / Update

If the user asks to update a specific section:

1. Read the existing `TOOLKIT-CONTEXT.md`.
2. If the update requires fresh data from the repo (e.g. "update the scripts
   catalog"), launch a single targeted Explore agent for that section.
3. Edit the relevant section in place.
4. Update the `Generated` timestamp in the header.

## Template

The generated `TOOLKIT-CONTEXT.md` must follow this structure. Sections may be
expanded but not removed. Keep content factual and dense -- this is a reference
document, not a tutorial.

```markdown
<!-- Generated: YYYY-MM-DDTHH:MM:SS+TZ -->
<!-- Source: toolkit-context skill -->

# RHOAI Toolkit Context

## Overview

[What the repo is, who it's for, what it automates. One paragraph.]

## Entry Points

[Three ways to use the toolkit: rhoai-toolkit.sh (interactive menu),
scripts/*.sh (direct CLI), Makefile (automation targets). Table format.]

## Directory Layout

[Full directory map with one-line descriptions. Tree or table format.]

## RHOAI Version Support

[Version matrix table (3.3 legacy, 3.4 stable, 3.5 recommended).
Key differences between versions. Component dependency matrix.
Operator channels and packages.]

## Scripts Catalog

[All scripts categorized by function. Table with: script name, one-line
purpose, key flags. Categories: Installation, MaaS Infrastructure, Model
Deployment, GPU/Hardware, Diagnostics, Cleanup, Security, Observability,
Storage, Utility, Orchestration.]

## Library Functions

[All files in lib/functions/ with key functions listed. Table format.
Note which files auto-source others.]

## Manifests Map

[lib/manifests/ directory structure mapped to purpose. Show the hierarchy
and what each directory contains.]

## Utilities

[lib/utils/ files with key functions. Cross-platform compatibility notes.]

## Demo Applications

[All demos with: name, what it demonstrates, deploy command, GPU
requirements, namespace. Table format.]

## Architecture Principles

[Manifests-as-source-of-truth, two-path design (scripted + kustomize),
version gating pattern, cross-platform requirements, secret handling.]

## Critical Gotchas

[Hardware profile annotations, MaaS routing modes, OGX vs LlamaStack,
llm-d flow control breaking change, Feature Store visibility, Trainer
JobSet prerequisite, tool calling parsers.]

## MaaS Deep Dive

[Version-specific MaaS differences (3.2 legacy through 3.5). DSC fields,
namespaces, CRDs, routing modes, TLS, dashboard flags. Deploy/verify/
cleanup script references.]

## Coding Conventions

[Script header pattern, color/print functions, os-compat usage, version
gating functions, error handling, CLI argument parsing pattern.]
```

## Rules

- `TOOLKIT-CONTEXT.md` is gitignored -- never commit it.
- Agents are for data gathering only -- never let them write to
  `TOOLKIT-CONTEXT.md` directly.
- When regenerating, always launch all 5 agents in parallel (single message,
  multiple tool calls) for speed.
- Use `subagent_type: "Explore"` for data-gathering agents; you (the main
  conversation) do the synthesis.
- The document should be self-contained: a reader with zero prior context
  should understand the repo's purpose, structure, and conventions.
- Keep it factual and dense. No marketing language. No tutorials.
- Include exact file paths so the reader can navigate directly.
