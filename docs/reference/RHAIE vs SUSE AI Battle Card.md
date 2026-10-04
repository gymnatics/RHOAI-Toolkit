# Battle Card: Red Hat AI Enterprise (RHAIE) vs. SUSE AI

**For internal sales/SE use.** Quick-reference companion to the full [RHAIE vs SUSE AI Feature Comparison](<./RHAIE vs SUSE AI Feature Comparison.md>) (read that for sourcing/citations on every claim below). Last updated September 22, 2026.

---

## 30-second positioning

> **Both platforms are built almost entirely on open source — this is not an open-vs-proprietary story, don't ever position it that way.** SUSE AI is a Helm-chart shrink-wrap of open-source components (Ollama, vLLM, Milvus, Kubeflow) on top of Rancher, none of which SUSE itself authors. **RHAIE is also open source top to bottom** — the dashboard, the operator/CRDs, KServe, TrustyAI, Model Registry, and even the MaaS controller are all Apache-2.0 under the Open Data Hub project — but Red Hat is the company that **co-maintains the inference engine (vLLM)**, **founded the distributed-inference project (llm-d)**, **co-leads KServe's governance**, and **authored TrustyAI/Kuadrant/Open Data Hub itself**. SUSE assembles other people's open-source software; Red Hat is on the maintainer/committer list for a lot more of the open-source software everyone (including SUSE) actually runs — and has already integrated, tested, and support-covered far more of that ecosystem as one product.

**One-liner**: *"Both of us are open source shops — that's not the difference. The difference is Red Hat is on the design team for way more of the bricks (vLLM, KServe, llm-d, TrustyAI), and we've already pre-assembled, tested, and put a support contract behind way more of them than SUSE has."*

---

## Head-to-head snapshot

| | RHAIE | SUSE AI | Why it matters |
|---|---|---|---|
| Distributed/disaggregated inference at scale | ✅ llm-d, GA, integrated + supported | ⚠️ DIY only — llm-d is open source/CNCF Sandbox and self-installable on RKE2, but SUSE doesn't package, test, or support it | Still the #1 practical gap — self-support risk if they try it themselves |
| Multi-tenant model gateway | ✅ GA, K8s-native CRDs, GitOps + dashboard-integrated | ⚠️ LiteLLM (Teams/Virtual Keys/budgets) is real at the app layer — but not CRD-native, not GitOps-managed, and multi-org tiers need paid LiteLLM Enterprise | Narrower gap than it looks — argue integration depth, not "SUSE has nothing" |
| Validated/benchmarked model catalog | ✅ GA, monthly refresh | ❌ none | SUSE customers pick models blind — no perf/safety data |
| Accelerator breadth | ✅ 6 families (NVIDIA/AMD/Gaudi/TPU/Spyre/CPU) | ⚠️ NVIDIA mature, AMD announced 2026, rest absent | Locks SUSE customers to NVIDIA in practice |
| Fine-tuning / model alignment toolkit | ✅ InstructLab + Docling + SDG + training/eval hubs, GA, dashboard-integrated | ⚠️ raw Kubeflow/PyTorch only (InstructLab's CLI is itself open source/pip-installable, but SUSE doesn't package or support it) | Red Hat ships a packaged, supported methodology; SUSE would be self-integrating the same open-source CLI |
| Native guardrails / red-teaming | ✅ NeMo Guardrails + Garak/EvalHub, GA, dashboard/orchestration included | ⚠️ community pipelines + Infosys partner; underlying tools (NeMo Guardrails *library*, Garak) are themselves free/self-installable, just not packaged by SUSE | SUSE's safety story is DIY or a partner's product, not a first-party platform capability |
| Agentic AI + MCP catalog | ✅ OGX (built on Llama Stack) + native MCP Lifecycle Operator, GA, dashboard-integrated | ⚠️ `mcpo` proxy only — Llama Stack itself has an open-source K8s operator SUSE could self-install, but doesn't package it | SUSE can call tools; Red Hat manages the whole agent lifecycle, packaged and supported |
| AI observability | ✅ good | ✅ **genuinely strong** | Give credit — don't contest this one |
| Air-gapped deployment | ✅ mature | ✅ mature | Parity — don't waste time here |
| Upstream leverage across the stack (vLLM, llm-d, KServe, Kubeflow, Kuadrant, TrustyAI, Open Data Hub) | ✅ leading contributor, co-lead, or original author on nearly every layer | ❌ authors/leads none of them (and doesn't even package most — only vLLM/Kubeflow among this list are in SUSE's own Helm catalog) | The single biggest structural edge — see below. Both sides' tech is open source; this row is about who's on the maintainer list, not who "has" it |

---

## Top 5 differentiators to lead with

1. **"We can fix it upstream; they can't — and not just in one project. This isn't open-vs-proprietary, it's who's on the maintainer list."** Both RHAIE and SUSE AI are built on open source — RHAIE's dashboard, CRDs, and MaaS controller are themselves Apache-2.0 (`opendatahub-io`), same as SUSE's Helm charts. The difference is authorship/leadership: Red Hat is the leading *commercial* contributor to vLLM (the engine both products run on), with named engineers holding committer/maintainer status. A Red Hat engineer is **co-Project-Lead of KServe** (the CRDs that define model serving on Kubernetes), Red Hat holds **2 seats on the Kubeflow Steering Committee** plus the maintainer role for Kubeflow Pipelines, Red Hat **created Kuadrant/Authorino** (the engine under Connectivity Link/MaaS) and **created TrustyAI** (the engine under Guardrails/EvalHub), and Red Hat's own **Open Data Hub** is the literal upstream meta-project RHOAI ships from. SUSE doesn't author, lead, or (mostly) even package these specific projects — its Helm catalog covers vLLM and Kubeflow from this list, not KServe/Kuadrant/TrustyAI at all. **Ask the customer: "If you need a new quantization format, a new KServe deployment mode, or a new Guardrails detector 6 months from now, who's going to build it for you?"**

2. **llm-d — distributed inference SUSE doesn't package or support, even though they technically could.** Careful with the phrasing here: llm-d is open source and CNCF Sandbox (vendor-neutral, engine-agnostic), so it's technically self-installable on RKE2 — don't claim SUSE "can't" run it. What's true: it's GA in RHOAI/RHAII 3.5, natively wired into KServe's `LLMInferenceService` CRD with a dashboard topology-selector wizard (four validated topologies, KV-cache-aware routing), founded by Red Hat with Google/NVIDIA. SUSE's own vLLM blueprint is single-GPU, single-node — full stop — and no SUSE product packages, tests, or supports llm-d. **If they push back with "we could just self-install it," pivot: "Sure — and you'd own 100% of that integration, testing, and hardware validation yourselves, with zero SUSE support SLA if it breaks in production."**

3. **Models-as-a-Service — real gap is productization, not presence of tenancy or even openness of the code.** Careful here: SUSE ships **LiteLLM**, which has genuine Teams/Virtual Keys/budgets/rate-limits — don't claim they have "no multi-tenancy." And don't claim MaaS is Red Hat's secret sauce either — the actual MaaS controller and CRDs (`MaaSSubscription`, `MaaSModelRef`, `MaaSAuthPolicy`) are themselves published as an open-source Apache-2.0 project, `opendatahub-io/models-as-a-service`. The real gap: RHAIE ships this **already integrated, tested, GitOps-manageable, dashboard-wired, and support-covered** as part of RHOAI. LiteLLM's tenancy lives in its own app + Postgres database, isn't dashboard-integrated into SUSE AI Factory, and gates multi-org hierarchy behind paid **LiteLLM Enterprise**; the upstream MaaS project itself isn't packaged by SUSE at all. **Ask: "Is your multi-tenant gateway managed the same way as the rest of your Kubernetes platform — as code, one dashboard, one support contract — or is it something you'd have to integrate and support yourselves?"**

4. **A governed model catalog vs. picking blind.** RHAIE's AI hub shows benchmarked performance, min vRAM, safety/security scores, and Pareto-optimal hardware recommendations per model — refreshed monthly. SUSE gives you an NVIDIA NGC app catalog (software, not model weights) and tells you to bring your own model. **Ask: "How do you know which quantized variant fits your GPU before you deploy it?" — SUSE has no answer.**

5. **Safety is a first-party product, not someone else's — but be precise about what's open vs. packaged.** NeMo Guardrails (native, GA, dashboard-configured, built-in PII/regex/prompt-injection detectors) + Garak/EvalHub automated red-teaming (OWASP LLM Top 10, GA, orchestrated) + MiDojo agent-layer adversarial testing (Dev Preview) — all shipped and supported by Red Hat. SUSE's guardrails story routes through a community Guardrails-AI pipeline recipe or an **Infosys partnership**. Caveat: the core **NeMo Guardrails library is itself Apache-2.0 and freely self-hostable**, and **Garak is a free `pip install`** — don't claim SUSE "can't" do safety testing, they can DIY it. What they don't have is the *orchestration, dashboard, multi-tenancy, and support SLA* wrapped around it. **If compliance/safety is a stated priority: "Whose SLA covers your guardrails when SUSE's answer is 'self-integrate it or ask our partner'?"**

---

## Landmines — where SUSE will push back (and how to respond)

| Their claim | Reality check | Your response |
|---|---|---|
| "SUSE Observability is best-in-class, OpenTelemetry-native." | **True — don't dispute it.** It's a real, well-built product with good dashboards. | Concede it, then pivot: *"Agreed, observability is solid — but observability tells you a problem happened. What matters more is whether the platform can prevent it (Guardrails), scale through it (llm-d), and govern it (MaaS). That's where the gap is."* |
| "llm-d is open source — we can just install it ourselves on RKE2." | **True, and don't dispute it** — llm-d is CNCF Sandbox, vendor-neutral, and its Helm charts run on any Kubernetes 1.30+ cluster with Gateway API, including RKE2. | *"Absolutely, you can. That also means you own the entire integration, hardware validation, and testing yourselves — with zero support SLA if it breaks in production. We ship it GA, wired into the dashboard and the model-serving CRDs, tested against our own hardware matrix, under one support contract. That's the value of a platform vs. a Helm chart you self-integrate."* |
| "We have LiteLLM — that gives us teams, budgets, and rate limits. We do have multi-tenancy." | **True — don't dispute it**, LiteLLM's OSS tier genuinely provides this. | *"Fair, and it's a solid tool. Where's that managed, though? It's a separate app with its own Postgres database and REST API — not a Kubernetes CRD your GitOps pipeline manages alongside everything else, and it's not in your AI Factory dashboard. And the moment you need multi-org hierarchy or pre-built rate tiers, that's LiteLLM Enterprise — a new bill. We ship the equivalent GA, CRD-native, dashboard-integrated, no upsell."* |
| "We run standard Kubernetes too — we could self-install Kueue, the actual MaaS controller, Llama Stack, Kubeflow Model Registry, or the NeMo Guardrails library ourselves." | **True across the board — don't dispute any of it.** All of these are genuinely open source and not OpenShift-exclusive (the MaaS controller/CRDs are literally `opendatahub-io/models-as-a-service`, Apache-2.0). | *"You're right, and that's actually the point: everything you just listed is open source precisely because we open-sourced it or the community did — we're not gatekeeping technology. What we sell isn't access to the code, it's the 15+ of these we've already integrated, tested against our hardware matrix, wired into one dashboard, and put a support SLA behind. Self-installing five different open source projects and gluing them together is a real project — with your engineering time and zero vendor backing if it breaks. That's what you're actually buying (or not buying) here."* |
| "We have full freedom — no lock-in, swap any component." | True, but this cuts both ways: it also means **no governance, no unified SLA across components, no integration testing across the stack.** | *"Component freedom is great until something breaks at 2am and you have five different upstream Slack channels to chase instead of one Red Hat support ticket."* |
| "AMD support — we just announced MI350P validation with Rancher Government Solutions." | True and recent (2026), but it's brand new vs. Red Hat's GA AMD ROCm support with published "well-lit paths" (KV-cache offload, scheduling) already shipping. | *"Great that they're starting that journey — we've been GA on AMD, plus Intel Gaudi, Google TPU, and IBM Spyre, for a while now."* |
| "SUSE Edge is more mature than OpenShift for edge AI." | Fair point on the broader Edge portfolio (SLE Micro + K8s for edge) — this is a real SUSE strength outside the AI-specific stack. | Don't contest edge computing generally — redirect: *"For pure edge K8s footprint, sure. But for edge **AI inference specifically** — RHEL AI ships as a bootable, single-server appliance with Granite models and vLLM/llm-d built in, day one. What's their AI-specific edge story beyond running the same Helm charts on a smaller box?"* |
| "SUSE is cheaper / simpler licensing." | Possible on raw subscription cost — not something to dispute on facts without current pricing sheets. | Pivot to TCO: *"Compare total cost of ownership, not just the subscription — factor in the engineering hours it takes to build what's missing yourselves: distributed inference, multi-tenancy, model governance, native guardrails."* |

---

## Discovery questions that expose SUSE gaps

Ask these early — the answers (or lack thereof) do most of the selling for you:

1. "How many GPU nodes/instances will a single large model need to serve your expected concurrent user load?" *(if >1 node → llm-d gap is fatal for SUSE)*
2. "Will more than one team/business unit share this AI platform, with different usage quotas or billing — and do you want that managed as Kubernetes-native, GitOps-able config alongside everything else, or as a separate app with its own database to operate?" *(exposes the integration-depth gap — SUSE's LiteLLM answer is real but lives outside the platform)*
3. "How do you plan to know a model is safe before it goes to production — accuracy, bias, jailbreak resistance?" *(EvalHub/Garak/Guardrails gap)*
4. "Are you deploying agents that call internal tools/APIs? How do you test whether those agents can be hijacked through a compromised tool?" *(MiDojo — SUSE has nothing here)*
5. "What hardware accelerators are on your 18-month roadmap — only NVIDIA, or also AMD/Intel/TPU/Spyre?" *(exposes SUSE's narrower accelerator story)*
6. "If you hit a wall in the platform itself — vLLM, the model-serving CRDs, a guardrails detector, a training pipeline behavior — a missing feature or a bug that blocks your use case — what's your path to getting it fixed?" *(the upstream-leverage killer question, now true across the whole stack, not just vLLM — SUSE has no good answer)*

---

## Proof points / stats to cite (verified, keep accurate)

- Red Hat named as **"leading commercial contributor to vLLM"** by both Red Hat and the vLLM project itself; vLLM's July 2026 contributor acknowledgments list **15 named Red Hat engineers** — more than any single other company (NVIDIA 7, Meta 7, Google 6, Intel 4).
- Red Hat **founded llm-d** (with Google and NVIDIA), now a CNCF Sandbox project — vendor-neutral, engine-agnostic, self-installable on any conformant Kubernetes (including RKE2); GA in RHOAI/RHAII 3.5 (Aug 27, 2026), llm-d 0.9 / vLLM 0.24, natively wired into KServe's `LLMInferenceService`.
- SUSE ships **LiteLLM** (real Teams/Virtual Keys/budgets/rate-limits) — genuine tenancy, but app-layer/own-database, not CRD-native or dashboard-integrated; multi-org hierarchy requires paid LiteLLM Enterprise.
- A Red Hat engineer (Yuan Tang) is **co-Project-Lead of KServe** — the CRDs that define model serving on Kubernetes — and Red Hat holds **6 of KServe's ~15 maintainer seats**, more than any other company.
- Red Hat holds **2 seats on the Kubeflow Steering Committee**; a Red Hat engineer (Matthew Prahl) is the documented maintainer of **both Kubeflow Pipelines and MLflow** — notable since MLflow is also the experiment-tracking tool SUSE ships. Red Hat also **created Kuadrant/Authorino** (engine under Connectivity Link/MaaS) and **created TrustyAI** (engine under Guardrails/EvalHub) outright.
- **Open Data Hub** — the 20+-project upstream meta-project that Red Hat OpenShift AI ships from — is itself a Red Hat-originated project (open-sourced 2018).
- Red Hat and Google are the **top two all-time contributors to Kubernetes**, jointly ~46% of contributions (CNCF Kubernetes Project Journey Report).
- Red Hat AI Inference 3.5 supports **6 accelerator families** (NVIDIA, AMD, Intel Gaudi, Google TPU, IBM Spyre, CPU) with first-party container images and a published compatibility matrix.
- SUSE AI Factory reached its **first GA in 2026** (2.0.0) — a materially younger product than RHOAI (GA since 2021, now on 3.5).

⚠️ **Do NOT claim** Red Hat is the #1 Linux kernel contributor overall — per LWN.net kernel 6.15 stats, Intel/Google/AMD/unaffiliated all rank above Red Hat (~6.1% of changesets, ~5th place). Stick to the vLLM/KServe/Kubeflow/Kuadrant/TrustyAI/Kubernetes/llm-d claims above, which are accurate and far more relevant to an AI platform conversation anyway.

⚠️ **Do NOT claim** Red Hat leads or created Kueue (the GPU fair-share queuing project) — it's a Google-founded Kubernetes SIG Scheduling project. Red Hat is an active contributor and ships a supported "Red Hat build of Kueue," but say exactly that, not "Red Hat leads it."

⚠️ **Do NOT claim SUSE technically "can't" run** llm-d, Kueue, the actual MaaS controller (`opendatahub-io/models-as-a-service`), Llama Stack, Kubeflow Model Registry, or the NeMo Guardrails library — all are open source and self-installable on RKE2. The accurate, durable claim is that Red Hat has already productized, integrated, tested, and support-covered all of these as one platform, while a SUSE customer would be self-integrating each one individually with no vendor SLA. Argue *productization and support*, never *technical availability*.

---

## Do's and Don'ts

**Do:**
- **State upfront, if it comes up, that both platforms are built on open source** — RHAIE's dashboard, CRDs, and even the MaaS controller are Apache-2.0 under Open Data Hub, same license model as SUSE's Helm charts. This is never an open-vs-proprietary conversation; framing it that way is inaccurate and will get corrected in front of the customer. The real conversation is upstream leadership + integration/support depth.
- Lead with llm-d, MaaS, and the model catalog — these are the starkest, easiest-to-verify gaps.
- Concede SUSE Observability and Edge when raised — it builds credibility for everything else you say.
- Frame the upstream-contribution point around specific projects (vLLM, llm-d, KServe, Kubeflow, Kuadrant, TrustyAI, Kubernetes) — name the project and the person/seat, not a vague "Red Hat does open source" claim.
- Ask discovery questions before pitching — let the customer's own answers surface the gaps.

**Don't:**
- Don't oversell the Linux kernel contribution stat — it's not accurate and will backfire if the customer/competitor checks it.
- Don't dismiss SUSE's air-gapped or Observability capabilities — both are genuinely solid and disputing them costs credibility.
- **Don't claim SUSE "can't run llm-d"** — it's open source/CNCF Sandbox and self-installable on RKE2. Argue support/integration depth, not availability.
- **Don't claim SUSE "has no multi-tenancy"** — LiteLLM's Teams/Virtual Keys/budgets are real, and even the actual MaaS controller/CRDs are open source. Argue CRD-native/GitOps/dashboard integration and the LiteLLM Enterprise upsell, not capability presence.
- **Don't claim SUSE "has no guardrails/red-teaming/agent-framework option"** — the NeMo Guardrails library, Garak, and Llama Stack are all freely open source and self-installable on RKE2. Argue packaging, orchestration, dashboard integration, and support SLA, not existence.
- Don't get pulled into a pure list-price argument — reframe to TCO and engineering effort to close the feature gaps.

---

*Source: distilled from [RHAIE vs SUSE AI Feature Comparison](<./RHAIE vs SUSE AI Feature Comparison.md>) — see that document for full citations to Red Hat and SUSE official documentation.*
