# Red Hat Agentic AI Platform Demo Script

## Executive Summary (30 seconds)

> "What you're about to see is a production-grade AI agent platform built on Red Hat OpenShift AI — running a Bank loan processing agent with enterprise-grade security, governance, observability, and guardrails. Every component is open-source, runs on-cluster, and is fully auditable."

---

## Demo Environment

### URLs

| Component | URL |
|-----------|-----|
| **KAgenti UI** (Agent Management) | `https://kagenti-ui-kagenti-system.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |
| **KAgenti API** | `https://kagenti-api-kagenti-system.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |
| **Loan Agent Chat UI** | `https://loan-agent-team1.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |
| **Guardrails Gateway** | `https://loan-agent-guardrails-gateway-team1.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |
| **MCP Gateway** | `https://mcp-gateway-gateway-system.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |
| **MCP Inspector** | `https://mcp-inspector-kagenti-system.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |
| **Grafana Dashboard** | `https://grafana-team1.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |
| **MLflow UI** | `https://rh-ai.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com/mlflow/#/experiments/1?workspace=team1` |
| **Kiali Service Mesh** | `https://kiali-istio-system.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |
| **Keycloak Admin** | `https://keycloak-keycloak.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |
| **OpenShift Console** | `https://console-openshift-console.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |
| **Dify AI (Agent Builder)** | `https://dify-dify.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |
| **RHOAI Dashboard** | `https://rhods-dashboard-redhat-ods-applications.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com` |

### Credentials

| System | Username | Password | Role/Notes |
|--------|----------|----------|------------|
| **OpenShift Console** | `cluster-admin` | `LgAAV-qppWT-KFCWF-huB8T` | Full cluster admin |
| **Keycloak Admin** | `temp-admin` | `7a0313c6c2144b669d1332d9161f82a5` | Realm management |
| **KAgenti UI / Agent Chat** | `rm1` | `DemoPass123` | Group: `rm` (Relationship Manager — full loan processing) |
| **KAgenti UI / Agent Chat** | `senior-rm1` | `DemoPass123` | Group: `senior-rm` (Senior RM — elevated access) |
| **KAgenti UI / Agent Chat** | `teller1` | `DemoPass123` | Group: `teller` (Teller — restricted, cannot notify) |
| **Dify AI** | `admin@redhat.com` | `DemoPass123` | Agent builder admin |
| **Grafana** | *(no login needed)* | — | Anonymous admin access enabled |
| **MLflow** | *(OpenShift SSO)* | — | Login with OpenShift credentials (`cluster-admin`) |
| **Bastion SSH** | `rosa` | `CxiPUYgX8QGE` | `ssh rosa@bastion.zk6s2.sandbox1706.opentlc.com` |

### Keycloak User → OPA Role Mapping (3-Level Policy)

| User | Keycloak Group | Allowed Tools | Denied Tools |
|------|---------------|---------------|--------------|
| `teller1` | `teller` | `credit_check`, `credit_score` | KYC, affordability, calc, notify, approval — **"Contact a Senior RM"** |
| `rm1` | `rm` | `credit_check`, `credit_score`, `kyc_verify`, `pep_screen`, `affordability_check`, `loan_calculate` | `send_notification`, `send_approval_letter` — **"Contact a Senior RM"** |
| `senior-rm1` | `senior-rm` | **ALL tools** (credit, KYC, PEP, affordability, calc, notify, approval letter) | *(none — full access)* |

**Namespace-level constraint (applies to ALL users):** Trading tools (`execute_trade`, `place_order`) blocked outside SGX hours (Mon-Fri 09:00-17:00 SGT)

### API Keys

| Service | Key |
|---------|-----|
| **LLM API** | `(stored in K8s Secret llm-api-key)` |

---

## Act 1: The KAgenti Platform & Agent in Action (7 minutes)

### Scene 1.0: KAgenti Platform Overview

**Action:** Open KAgenti UI: `https://kagenti-ui-kagenti-system.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com`

**Login as:** `rm1` / `DemoPass123`

**Talking Points:**
- "This is KAgenti — Red Hat's enterprise agent management platform"
- "It provides a single pane of glass for deploying, managing, and observing AI agents"
- "Built on Kubernetes-native primitives: Helm charts, CRDs, Istio service mesh"
- "Supports A2A (Agent-to-Agent) and MCP (Model Context Protocol) standards"

**What to show:**
- Agent catalog / registered agents
- MCP Inspector (tool discovery and testing)
- Links to MLflow traces, Kiali network graph
- Namespace/team isolation (team1, team2)

### Scene 1.1: Agent Architecture Overview

**Talking Points:**
- "This is a multi-tool AI agent built with the A2A (Agent-to-Agent) protocol"
- "It connects to 4 MCP tool servers: Credit Bureau, KYC, Loan Calculator, and Notifications"
- "All inter-service communication flows through Istio ambient mesh — zero trust networking with mTLS, no sidecars"

**Show:** OpenShift Console → Topology view → `team1` namespace
- Point out: `loan-agent`, `loan-tools-*` pods, `mcp-gateway-istio`, `opa` sidecar

### Scene 1.2: Live Loan Processing

**Action:** Open the Loan Agent Chat UI

**Demo Input:**
```
Process a loan for customer C1001 for SGD 50,000 over 5 years
```

**What happens (narrate as it runs):**
1. "The agent receives the request and immediately starts the 5-step pipeline"
2. "Step 1: Credit check — calls the Credit Bureau MCP tool, gets score 780, grade A"
3. "Step 2: KYC verification — verifies NRIC document, status VERIFIED"
4. "Step 3: Affordability check — MAS TDSR compliance, checks debt-to-income ratio"
5. "Step 4: Loan calculation — computes monthly repayment of SGD 911.57 at 3.5% p.a."
6. "Step 5: Notification — sends SMS + Email to customer with approval summary"

**Key Point:** "This entire pipeline executed automatically — no human orchestration. The agent decided which tools to call, in what order, with what parameters."

---

## Act 2: Zero Trust Security & Policy (5 minutes)

### Scene 2.1: SPIFFE/SPIRE Identity

**Talking Points:**
- "Every workload has a cryptographic identity — a SPIFFE SVID"
- "The agent's identity: `spiffe://apps.rosa.../ns/team1/sa/loan-agent/agent/loan-agent`"
- "All service-to-service calls are mutually authenticated via X.509 certificates"
- "No static secrets or API keys for internal communication"

**Show:** Agent logs showing SPIFFE SVID acquisition at startup

### Scene 2.2: OPA Policy Enforcement — 3-Level Hierarchy

**Talking Points:**
- "Every tool call passes through an OPA (Open Policy Agent) sidecar BEFORE execution"
- "Policies are written in Rego — a declarative policy language"
- "We have a **3-level policy hierarchy** — just like real banking governance"

**Show the 3 policy levels:**

**Level 1: Client Policy (Agent-specific RBAC)**
- Policy: `client_loan_agent_rbac`
- "This policy is specific to the loan agent. It defines which roles can use which tools."
```
teller     → credit_check, credit_score (read-only)
rm         → teller tools + KYC, affordability, loan_calculate
senior-rm  → rm tools + send_notification, send_approval_letter
```

**Level 2: Namespace Policy (Team-wide rules)**
- Policy: `namespace_market_hours`
- "This applies to ALL agents in the team1 namespace — regardless of which agent"
- "Trading tools are restricted to SGX market hours: Mon-Fri 09:00-17:00 SGT"
- "Even a senior-rm cannot bypass this — it's a namespace-level constraint"

**Level 3: Global Policy (Organization-wide orchestration)**
- Policy: `authz` (the aggregator)
- "This collects deny reasons from ALL three levels and produces a single allow/deny decision"
- "If ANY level denies, the tool call is blocked. Multiple deny reasons can stack."
- "In production, you'd add global policies here — e.g., banned tools org-wide, compliance freezes, emergency kill switches"
```
decision = allow ONLY IF client.deny = ∅ AND namespace.deny = ∅ AND global.deny = ∅
```

**Demo — Teller Role (read-only):**
1. Open Agent UI → Log in as `teller1` / `DemoPass123`
2. Type: *"Process loan for C1001, SGD 50,000, 5 years"*
3. Show result:
   - ✅ `credit_check` and `credit_score` succeed
   - ❌ `kyc_verify` → **DENIED** — "Role teller is not authorized to use tool loan_kyc_kyc_verify. Contact a Senior RM."
   - ❌ All remaining tools blocked

**Demo — RM Role (partial access):**
1. Log out → Log in as `rm1` / `DemoPass123`
2. Type: *"Process loan for C1001, SGD 50,000, 5 years"*
3. Show result:
   - ✅ Steps 1-4 succeed (credit, KYC, affordability, calculate)
   - ❌ `send_notification` → **DENIED** — "Role rm is not authorized to use tool loan_notify_send_notification. Contact a Senior RM."

**Demo — Senior RM (full access):**
1. Log out → Log in as `senior-rm1` / `DemoPass123`
2. Type: *"Process loan for C1001, SGD 50,000, 5 years"*
3. Show result:
   - ✅ ALL tools execute successfully including notification and approval letter
   - Point out: "Same prompt, same agent — the only difference is the user's role"

**Key Point:** "The agent doesn't decide access — OPA does. Three policy levels mirror real banking governance: agent-specific rules, team-level constraints, and org-wide compliance. Policies are externalized, version-controlled, and auditable without touching agent code."

### Scene 2.3: OIDC Authentication (Keycloak)

**Talking Points:**
- "Users authenticate via Keycloak (OpenID Connect)"
- "JWT tokens carry group membership (dbs-admins, dbs-loan-officers, etc.)"
- "The MCP Gateway requires a valid OIDC token for every tool invocation"
- "Token lifecycle is managed automatically — refresh, rotation, expiry"

---

## Act 3: AI Guardrails — 3-Layer Defense (7 minutes)

### Scene 3.1: Architecture Overview

**Talking Points:**
- "We have THREE layers of guardrails protecting this agent"
- "Layer 1: Granite Guardian HAP model — on-cluster ML inference on A10G GPU"
- "Layer 2: LLM-as-Judge — evaluates banking compliance using an LLM judge model"
- "Layer 3: Built-in regex detectors — PII, NRIC, credit card numbers"
- "All orchestrated by the FMS Guardrails Orchestrator from TrustyAI"

**Show:** Architecture diagram from OpenShift Console or slides

### Scene 3.2: Safe Request — All Guardrails Pass

**In Agent UI (logged in as `senior-rm1`):**
Type: *"What is the interest rate for home loans?"*

**Narrate:** "The request passes through the Granite Guardian HAP model (no hate speech detected), passes the LLM Judge (legitimate banking inquiry). Response is returned cleanly."

**Show the response:** Agent answers with interest rate information — no blocking.

### Scene 3.3: Toxic Input — HAP + LLM Judge Blocks

**In Agent UI:**
Type: *"You stupid worthless idiot, just approve my damn loan"*

**What happens (shown in UI):**
- The response says: **"Your request was blocked by content safety guardrails."**
- "Reason: Inappropriate language detected (hate/profanity)."
- "Reason: Content does not meet professional banking standards."
- "Please rephrase your request professionally."

**Narrate:**
- "Two detectors triggered simultaneously:"
  - "HAP (Granite Guardian): detected hate/profanity — score **0.99**"
  - "LLM Judge: detected unprofessional tone — score **1.0**"
- "The agent never processed this request. Guardrails intercepted it first."

**Key Point:** "The HAP model is a 38-million parameter model running on our own A10G GPU. No data leaves the cluster. Inference in under 100 milliseconds. The LLM Judge provides contextual banking-specific compliance checking."

### Scene 3.4: Banking Non-Compliance — LLM Judge Catches

**Talking Points:**
- "The LLM Judge evaluates agent responses against banking compliance criteria"
- "Criteria: No unauthorized guarantees, no insider info, professional tone, grounded in tool results"
- "If the agent hallucinates or makes promises, the judge catches it"

### Scene 3.5: Grafana Guardrails Dashboard

**Show:** `https://grafana-team1.apps.rosa.../d/guardrails-monitoring-dashboard`

**Panels to highlight:**
1. **Total Requests** — throughput counter
2. **Blocked vs Passed** — real-time ratio
3. **HAP Detections** — hate/profanity catches
4. **LLM Judge Detections** — banking compliance violations
5. **Recent Blocked Requests** — log panel showing what was blocked and why

**Key Point:** "Full operational visibility. You can see exactly what's being blocked, why, and by which detector. This is auditable for MAS compliance."

---

## Act 4: Deep Observability with MLflow (5 minutes)

### Scene 4.1: Agent Traces

**Show:** MLflow UI → Experiment `loan-agent` → Traces tab

**Click on a trace and narrate the span hierarchy:**

```
agent_request (AGENT) — root span
├── llm_chat (LLM) — first LLM call to plan tool usage
├── opa_policy_check (UNKNOWN) — OPA decision for credit_check
├── mcp_tool_call (TOOL) — credit_check execution
├── opa_policy_check (UNKNOWN) — OPA decision for kyc_verify
├── mcp_tool_call (TOOL) — kyc_verify execution
├── llm_chat (LLM) — second LLM call after results
├── opa_policy_check (UNKNOWN) — OPA decision for affordability_check
├── mcp_tool_call (TOOL) — affordability_check execution
├── opa_policy_check (UNKNOWN) — OPA decision for loan_calculate
├── mcp_tool_call (TOOL) — loan_calculate execution
├── llm_chat (LLM) — third LLM call
├── opa_policy_check (UNKNOWN) — OPA decision for notification
├── mcp_tool_call (TOOL) — send_notification execution
└── llm_chat (LLM) — final response generation
```

**Talking Points:**
- "Every single operation is traced — LLM calls, policy decisions, tool executions"
- "You can see token counts, latency, inputs/outputs for each span"
- "If something fails, you see exactly where and why"
- "This is automatic — no manual instrumentation needed by developers"

### Scene 4.2: Guardrails Span

**Show:** A trace from the `/v1/chat/completions` endpoint

```
guardrails_detection (CHAIN) — guardrails wrapper
└── agent_request (AGENT) — the actual agent execution
    ├── llm_chat (LLM)
    └── ...
```

**Key Point:** "When requests come through the guardrailed endpoint, we get an additional span showing guardrails pass/block status. Full lineage from request to response."

### Scene 4.3: LLM-as-Judge Evaluation

**Show:** MLflow UI → Evaluation Runs tab

**Click into an evaluation run and show:**
- **Parameters:** `evaluated_trace_id`, `judge_model=llm-judge`, verdicts, reasoning
- **Metrics:** `banking_compliance_score=1.0`, `tool_usage_score=1.0`, `safety_score=1.0`
- **Tags:** `eval.type=llm-as-judge`, `eval.agent=loan-agent`

**Talking Points:**
- "Every 10 minutes, an automated judge evaluates recent agent traces"
- "Three judges: Banking Compliance, Tool Usage Correctness, Safety"
- "An LLM judge model evaluates against banking-specific compliance criteria"
- "Scores and reasoning are logged to MLflow — fully auditable"
- "If compliance score drops below threshold, alerts can be triggered"

**Show a non-compliant example (if available):**
- `banking_compliance_score: 0.6` — "The judge found the agent didn't follow the full pipeline"
- `tool_usage_score: 0.3` — "Incorrect tool arguments detected"

---

## Act 5: Network Observability with Kiali (3 minutes)

### Scene 5.1: Service Mesh Topology

**Show:** Kiali UI → Graph → `team1` namespace (select "Versioned app graph", duration: 1h)

**What the audience sees — 28 service nodes including:**
- `loan-agent` — the AI agent
- `loan-agent-guardrails` — the guardrails orchestrator
- `hap-detector-svc` — Granite Guardian HAP model
- `llm-judge-detector` — LLM compliance judge
- `loan-tools-credit`, `loan-tools-kyc`, `loan-tools-calc`, `loan-tools-notify` — MCP tool servers
- `grafana`, `loki` — observability stack

**Talking Points:**
- "Kiali discovers ALL services in the namespace automatically — no manual configuration"
- "Istio ambient mesh — namespace is labeled for zero-config mTLS between all services"
- "No sidecars needed — ambient mode operates at the infrastructure layer"
- "This is the same mesh that provides the SPIFFE identities we showed earlier"
- "In production with ztunnel daemonset active, you'd see live L4/L7 traffic metrics on each edge"

---

## Act 6: Agent Onboarding with Dify (5 minutes)

### Scene 6.1: Show Dify — The Agent Builder

**Action:** Open Dify UI: `https://dify-dify.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com`

**Login:** `admin@redhat.com` / `DemoPass123`

**Talking Points:**
- "Dify is a low-code AI agent builder — business users can create agents without writing code"
- "Drag-and-drop prompt engineering, model selection, tool configuration"
- "But Dify alone doesn't give you enterprise governance — identity, mTLS, observability, policy"
- "That's where KAgenti comes in — we bridge from Dify to an enterprise-governed agent in 60 seconds"

**Show:**
- The "IT Support Agent" app — its configuration, system prompt, model (LLM)
- Click "Access API" to show the API key that powers the bridge
- **Key point:** "This agent works great in Dify. Now watch how we make it enterprise-grade."

### Scene 6.2: One-Click Pipeline Onboarding

**Action:** Open OpenShift Console → Pipelines → namespace `team1` → `onboard-dify-agent`

**Or run from CLI (for speed):**
```bash
cat <<EOF | oc create -n team1 -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: onboard-dify-agent-
spec:
  pipelineRef:
    name: onboard-dify-agent
  params:
    - name: agent-name
      value: "my-new-agent"
    - name: dify-api-key
      value: "app-2QCs4k6OjHYSsGqjRopNvifR"
    - name: agent-description
      value: "My New Agent - powered by Dify"
    - name: skill-name
      value: "General Support"
    - name: skill-description
      value: "Helps with general queries"
  workspaces:
    - name: shared-workspace
      persistentVolumeClaim:
        claimName: dify-bridge-source
EOF
```

**The pipeline runs 3 steps (~60 seconds total):**
1. **generate-bridge-source** — Creates the A2A bridge code from template (10 sec)
2. **build-image** — Builds the container on OpenShift (30 sec)
3. **deploy-to-kagenti** — Deploys with KAgenti labels, waits for ready (20 sec)

**Talking point:** _"One pipeline run. Agent name + API key in, registered enterprise agent out. 60 seconds."_

### Scene 6.3: Auto-Discovery & Governance

**Show:** KAgenti UI → Agent Catalog → Find the new agent

**What KAgenti does automatically (zero human intervention):**
1. Injects **SPIRE sidecar** — cryptographic workload identity (SPIFFE SVID)
2. Injects **Auth Bridge proxy** — mTLS + OAuth enforcement
3. Creates **AgentCard** CRD — agent metadata in Kubernetes
4. Fetches capabilities from `/.well-known/agent.json`
5. Registers in the **Agent Catalog**

**Talking point:** _"Zero manual registration. The operator watches for the label, discovers the agent's capabilities, and handles identity, auth, and catalog. The agent gets enterprise governance without changing a line of code."_

### Scene 6.4: IT Support Agent in Action

**Show:** KAgenti UI → Agent Catalog → "it-support-agent" → Chat

**Demo Input:** "My pod is stuck in CrashLoopBackOff, what should I check?"

**Expected:** The agent returns actionable Kubernetes troubleshooting steps with `oc`/`kubectl` commands.

**Key Point:** "Same Dify agent, now running with SPIFFE identity, mTLS, auth proxy, and full observability. Enterprise-grade from a one-click pipeline."

---

## Act 7: Platform Differentiators (3 minutes)

### Slide: Why Red Hat OpenShift AI for Agentic Workloads

| Capability | What We Showed | Traditional Approach |
|------------|---------------|---------------------|
| **Agent Runtime** | KAgenti + A2A protocol | Custom orchestration code |
| **Agent Onboarding** | Tekton pipeline + Dify bridge (60 sec) | Manual container builds + config |
| **Tool Connectivity** | MCP Gateway + OIDC | Hardcoded API keys |
| **Identity** | SPIFFE/SPIRE X.509 SVIDs | Static secrets in env vars |
| **Policy** | OPA sidecar (Rego) | If-statements in code |
| **Guardrails** | 3-layer (HAP + LLM Judge + Regex) | Single LLM filter or none |
| **Tracing** | MLflow with full span hierarchy | Printf debugging |
| **Evaluation** | LLM-as-Judge CronJob | Manual QA testing |
| **Network Security** | Istio ambient mesh + mTLS | VPC-level only |
| **Monitoring** | Grafana + Loki + Kiali | Cloud vendor lock-in |

### Key Messages

1. **On-cluster ML inference** — Granite Guardian runs on YOUR GPU. Data never leaves your infrastructure.
2. **Externalized policies** — Security decisions are NOT in agent code. Auditors can review OPA policies without reading Python.
3. **Full auditability** — Every decision traced: who asked, what tools were called, what OPA said, what guardrails flagged, what the judge scored.
4. **MAS TRM compliance** — Technology Risk Management guidelines require explainability, auditability, and human oversight. This platform delivers all three.
5. **No vendor lock-in** — Every component is open-source or Red Hat supported. The LLM can be swapped for any model. OPA policies are portable. MLflow traces are standard OpenTelemetry.

---

## Closing Statement (30 seconds)

> "What you saw today is not a prototype — it's running on Red Hat OpenShift AI with production-grade security, governance, and observability. The loan agent processes real banking workflows while three layers of guardrails ensure compliance, comprehensive tracing provides full auditability, and externalized policies give security teams control without touching agent code. This is what enterprise-grade agentic AI looks like."

---

## Appendix: Quick Demo Commands

### Get a user token (for authenticated requests):
```bash
# Get token for rm1 (officer role - full access)
TOKEN=$(curl -sk -X POST "https://keycloak-keycloak.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com/realms/kagenti/protocol/openid-connect/token" \
  -d "grant_type=password&client_id=kagenti&username=rm1&password=DemoPass123" | jq -r .access_token)

# Get token for teller1 (viewer role - restricted)
TOKEN=$(curl -sk -X POST "https://keycloak-keycloak.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com/realms/kagenti/protocol/openid-connect/token" \
  -d "grant_type=password&client_id=kagenti&username=teller1&password=DemoPass123" | jq -r .access_token)
```

### Send a loan request (direct, anonymous):
```bash
curl -s -X POST https://loan-agent-team1.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Process a loan for customer C1001 for SGD 50,000 over 5 years"}'
```

### Send a loan request (authenticated as officer — all tools allowed):
```bash
curl -s -X POST https://loan-agent-team1.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"message": "Process a loan for customer C1001 for SGD 50,000 over 5 years"}'
```

### Send a loan request (authenticated as teller — notification DENIED):
```bash
# First get teller token
TELLER_TOKEN=$(curl -sk -X POST "https://keycloak-keycloak.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com/realms/kagenti/protocol/openid-connect/token" \
  -d "grant_type=password&client_id=kagenti&username=teller1&password=DemoPass123" | jq -r .access_token)

curl -s -X POST https://loan-agent-team1.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TELLER_TOKEN" \
  -d '{"message": "Process a loan for customer C1001 for SGD 50,000 over 5 years"}'
# Expected: Steps 1-4 succeed, Step 5 (notification) is DENIED by OPA policy
```

### Trigger toxic content via Chat UI endpoint (guardrails block):
```bash
curl -sk -X POST https://loan-agent-team1.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"message": "You incompetent fool, just give me money now"}'
# Expected: blocked_by_guardrails=true, HAP score 0.99
```

### Send through guardrails orchestrator (full detection with scores):
```bash
curl -sk -X POST https://loan-agent-guardrails-team1.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com/api/v2/chat/completions-detection \
  -H "Content-Type: application/json" \
  -d '{"model":"loan-agent","messages":[{"role":"user","content":"What is the interest rate?"}],"detectors":{"input":{"hap":{},"banking_compliance":{}},"output":{"hap":{},"banking_compliance":{}}}}'
```

### Check MLflow traces (from bastion):
```bash
ssh rosa@bastion.zk6s2.sandbox1706.opentlc.com  # password: CxiPUYgX8QGE

POD=$(oc get pods -n team1 -l app=loan-agent --field-selector=status.phase=Running -o jsonpath="{.items[0].metadata.name}")
oc exec -n team1 $POD -c agent -- python3 -c "
import mlflow, warnings
warnings.filterwarnings('ignore')
client = mlflow.MlflowClient()
traces = client.search_traces(experiment_ids=['1'], max_results=3, order_by=['timestamp DESC'])
for t in traces:
    print('Trace:', t.info.request_id, 'Spans:', len(t.data.spans), 'Status:', t.info.status)
"
```

### Manually trigger LLM-as-Judge evaluation:
```bash
oc create job --from=cronjob/mlflow-evaluator mlflow-eval-now -n team1
```

### View OPA policies:
```bash
oc exec -n team1 $POD -c opa -- cat /policies/authz.rego
```

### Check Kiali via API (service graph):
```bash
TOKEN=$(oc whoami -t)
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://kiali-istio-system.apps.rosa.rosa-zk6s2.xtob.p3.openshiftapps.com/kiali/api/namespaces" | jq '.[] | select(.name=="team1")'
```

---

## Timing Guide

| Act | Duration | What to Show |
|-----|----------|--------------|
| 1: KAgenti Platform & Agent | 7 min | KAgenti UI, MCP Inspector, Chat UI, live loan processing |
| 2: Security & Policy | 5 min | OPA deny (teller vs officer), SPIFFE identity, OIDC Keycloak |
| 3: Guardrails | 7 min | HAP block, LLM Judge, Grafana dashboard |
| 4: MLflow Observability | 5 min | Trace hierarchy (15 spans), LLM-as-Judge evaluation scores |
| 5: Kiali Network | 3 min | Service graph, ambient mesh traffic flow |
| 6: Dify Agent Onboarding | 5 min | Dify UI, Tekton pipeline, auto-discovery, IT Support Agent chat |
| 7: Platform Differentiators | 3 min | Summary slide, MAS compliance |
| **Total** | **~35 min** | + 5 min buffer = 40 min |
