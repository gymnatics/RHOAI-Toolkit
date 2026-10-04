# Garak + EvalHub in RHOAI 3.5

Source: `docs/reference/RHAIE 3.5 Guide/Red_Hat_OpenShift_AI_Self-Managed-3.5-Evaluating_AI_systems-en-US.pdf.md` (plus the 3.5 release notes and the SDG guide).

## 1. Garak is just another EvalHub *provider*

EvalHub is TrustyAI's evaluation orchestration service (REST API + SDK/CLI + provider adapters, jobs run as Kubernetes Jobs, results optionally logged to MLflow). Garak is registered as one of its built-in providers alongside `lm_evaluation_harness` and `guidellm`:

```yaml
apiVersion: trustyai.opendatahub.io/v1
kind: EvalHub
metadata:
  name: evalhub
spec:
  replicas: 1
  database:
    type: postgresql
    secret: evalhub-db-credentials
  providers:
    - lm-evaluation-harness
    - garak
    - guidellm
  collections:
    - safety-and-fairness-v1
```

Once enabled, Garak shows up as a normal provider with benchmarks you can list/run through the CLI, SDK, or REST API — e.g. `owasp_llm_top_10`, or a fast `quick` DAN-probe smoke test — and you can mix it into a **collection** with other providers (e.g. `lm_evaluation_harness` accuracy benchmarks + Garak vulnerability scans in one `safety-and-fairness-v1` suite).

This path is **GA** in 3.5 and is called **"Automated Red Teaming"** in the release notes — vulnerability scanning against OWASP LLM Top 10 / AVID / CWE taxonomies, with parallelized generator/detector/translator execution and disconnected-cluster support.

## 2. Garak also powers a dedicated "Automated Risk Assessment" pipeline (Chapter 7)

This is a separate, more elaborate feature (still **Technology Preview**) that layers synthetic data generation on top of Garak:

- **Phase 1 – prompt generation**: an SDG flow uses a challenger/judge LLM to generate diverse adversarial prompts per harm category (region, demographic, writing style variation).
- **Phase 2 – security testing**: Garak sends those prompts through progressively aggressive attack strategies (including multilingual translation attacks via Helsinki-NLP models) against your model endpoint (or model + guardrails stack), scoring `attack_success_rate`.

It's triggered either via the EvalHub API (`provider_id: garak-kfp`, `benchmark id: intents`) or directly via the KFP Python SDK, and results land as an evaluation report you can gate deployments on. Config knobs live in guide §7.7 (`garak_config`, `eval_threshold`, `generations`, `kfp_config`, etc.).

So within the guide, "Garak + EvalHub" really means two things:

| | Direct Garak provider (Ch. 2) | Automated Risk Assessment (Ch. 7) |
|---|---|---|
| Status | GA | Technology Preview |
| What it runs | Static Garak benchmarks (e.g. `owasp_llm_top_10`, `quick`) | SDG-generated adversarial prompts → Garak attack strategies |
| Trigger | Normal EvalHub job submission | EvalHub API (`garak-kfp`) or KFP SDK directly |
| Output | Standard EvalHub benchmark score | Vulnerability report w/ per-strategy bypass rates |

## 3. Does it overlap with AI-assisted pen-testing use cases?

Yes — conceptually, Garak-in-EvalHub **is** an automated/AI-assisted penetration-testing tool, just scoped to a single LLM endpoint. The glossary in the "Getting started" guide even defines *red teaming* as "systematically probing AI systems with adversarial inputs... manual or automated," and Garak is explicitly the automated implementation of that for RHOAI.

Where it's *not* fully overlapping is scope/layer — the 3.5 release notes call out a second, complementary Developer Preview feature that fills a gap Garak doesn't cover:

> **MiDojo adversarial testing execution engine**
>
> In OpenShift AI, you can use MiDojo, a man-in-the-middle adversarial testing execution engine for AI agents, available as a Developer Preview feature. MiDojo intercepts communications at the tool layer, injecting attack payloads into tool responses while forwarding legitimate calls upstream...
>
> — `Red_Hat_OpenShift_AI_Self-Managed-3.5-Release_notes-en-US.pdf.md`

So practically:

- **Garak (via EvalHub)** = *model-level* red teaming — sends crafted prompts straight to a chat-completions endpoint and measures whether the model/guardrails stack refuses (jailbreak, toxicity, OWASP LLM Top 10). This is the piece that most overlaps with generic "LLM pen-testing" tooling — if you're already running standalone Garak (or a similar scanner) against your models outside the cluster, RHOAI 3.5's EvalHub integration is largely redundant with that and could replace it (adds MLflow tracking, multi-tenancy, disconnected support, KFP-based SDG for prompt diversity).
- **MiDojo** = *agent/tool-layer* red teaming — a MITM proxy that tampers with tool responses/A2A/MCP/OGX traffic to see if an agent falls for injected instructions, independent of whether the underlying model itself is "safe." This doesn't overlap with Garak; it targets an orthogonal attack surface (multi-step agentic workflows) that a single-endpoint prompt scanner can't reach.

If your existing AI-assisted pen-testing use case is specifically "throw adversarial prompts at the model and see if it breaks," expect meaningful overlap with Garak/EvalHub (and you'd likely consolidate onto it for the tracking/reporting benefits). If your use case is "test whether an agent can be hijacked through its tools/other agents," that's MiDojo's niche and Garak won't cover it — the two are complementary rather than duplicative.

## 4. Where does IBM CLEAR / IBM ARES fit in?

Neither tool appears anywhere in the RHOAI 3.5 guide set — they are not part of Red Hat's shipped toolchain and are not EvalHub providers. There are also two distinct, similarly-branded IBM Research projects worth separating:

| | **IBM CLEAR** | **IBM ARES** |
|---|---|---|
| Full name | Comprehensive LLM Error Analysis and Reporting | AI Robustness Evaluation System |
| Purpose | **Quality/error analysis** — LLM-as-a-judge finds and quantifies *why* a model/agent underperforms | **Automated red-teaming** — orchestrates adversarial attacks against LLMs/agents |
| How it works | Feed it a CSV of prompts+responses (or agent traces from LangGraph/CrewAI via MLflow/Langfuse) → it generates per-instance critiques, clusters them into system-level error categories, and shows them in a dashboard | Config-driven pipeline: define a **target**, **goal** (PII leakage, jailbreak, prompt injection, etc.), **strategy** (built-in attacks like Crescendo, GCG, TAP, or custom), and **evaluator** (keyword match, LLM judge, guardrail) → runs the attack and reports pass/fail |
| Security focus? | No — passive diagnostic/observability tool, not an attacker | Yes — explicitly maps to the OWASP LLM Top 10, built for pre-deployment security testing |
| Garak/EvalHub analog | Closer to CLEAR's LLM-as-judge role inside `lm_evaluation_harness`/evaluation-card generation, or to MiDojo's trace-level analysis (agentic mode) — **not** an attacker | **Direct overlap with Garak** — same idea (pluggable attacks + evaluators, OWASP-mapped, YAML-configured), just IBM's implementation instead of NVIDIA's |
| Links | [github.com/IBM/CLEAR](https://github.com/IBM/CLEAR) | [github.com/IBM/ares](https://github.com/ibm/ares) · [ibm.github.io/ares](https://ibm.github.io/ares/) |

**Takeaways:**

- **CLEAR** doesn't overlap with Garak's pen-testing role — it's an *error-analysis* tool for figuring out why outputs are wrong/low-quality, not for probing safety/security. It's more comparable to the quality side of EvalHub (`lm_evaluation_harness`) or to a richer version of EvalHub's "evaluation cards," and its Agentic mode is conceptually closer to what MiDojo's trace inspection gives you than to Garak.
- **ARES** is the real apples-to-apples competitor to Garak — both are pluggable, OWASP-LLM-Top-10-mapped, automated red-teaming orchestrators. Since neither is wired into EvalHub as a native provider, using ARES on OpenShift AI would mean running it yourself (e.g., as a workbench/pipeline task hitting your model's OpenAI-compatible endpoint) rather than as a first-class EvalHub provider like `garak`/`garak-kfp`.
