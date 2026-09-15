# Agentic Platform Demo -- Manual Walkthrough

Cluster: `apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com`
LLM: Qwen3.5-35B-A3B via MaaS (on-cluster)

---

## URLs

| Component | URL |
|-----------|-----|
| Loan Agent Chat | https://loan-agent-team1.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com |
| Grafana | https://grafana-team1.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com |
| KAgenti UI | https://kagenti-ui-kagenti-system.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com |
| Keycloak Admin | https://keycloak-keycloak.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com |
| Dify | https://dify-dify.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com |
| RHOAI Dashboard | https://rhods-dashboard-redhat-ods-applications.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com |
| OpenShift Console | https://console-openshift-console.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com |

## Credentials

| System | Username | Password |
|--------|----------|----------|
| Keycloak Admin | `temp-admin` | `afd3e5c51292490da46f08347add64d8` |
| Agent Chat (Senior RM) | `senior-rm1` | `DemoPass123` |
| Agent Chat (RM) | `rm1` | `DemoPass123` |
| Agent Chat (Teller) | `teller1` | `DemoPass123` |
| Dify | `admin@redhat.com` | `DemoPass123` |
| Grafana | (no login) | anonymous admin |

---

## Act 1: The Agent in Action (7 min)

### 1.1 Open the Loan Agent Chat UI

https://loan-agent-team1.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com

### 1.2 Process a Loan

Type into the chat or use curl:

```
Process a loan for customer C1001 for SGD 50,000 over 5 years
```

Watch the 5-step pipeline:

| Step | Tool | Expected Result |
|------|------|-----------------|
| 1 | `credit_check` | Score 780, Grade A |
| 2 | `kyc_verify` | NRIC verified |
| 3 | `affordability_check` | TDSR compliant |
| 4 | `loan_calculate` | Monthly ~SGD 908 at 3.5% p.a. |
| 5 | `send_notification` | SMS + Email sent |

curl version:

```bash
curl -sk -X POST https://loan-agent-team1.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com/api/chat -H "Content-Type: application/json" -d '{"message": "Process a loan for customer C1001 for SGD 50,000 over 5 years"}'
```

### 1.3 Try Different Customers

```bash
AGENT="https://loan-agent-team1.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com/api/chat"

# C1002 - lower credit score
curl -sk -X POST $AGENT -H "Content-Type: application/json" \
  -d '{"message": "Process a loan for customer C1002 for SGD 100,000 over 10 years"}'

# C1003 - poor credit
curl -sk -X POST $AGENT -H "Content-Type: application/json" \
  -d '{"message": "Check credit for customer C1003"}'
```

### 1.4 OpenShift Console Topology

Open the Console, go to Developer > Topology > project `team1`.
See: loan-agent, loan-tools-*, grafana, loki, hap-detector, llm-judge, guardrails.

---

## Act 2: Zero Trust Security and Policy (5 min)

### 2.1 Get User Tokens from Keycloak

```bash
DOMAIN="apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com"
KC="https://keycloak-keycloak.${DOMAIN}/realms/kagenti/protocol/openid-connect/token"
AGENT="https://loan-agent-team1.${DOMAIN}/api/chat"

SENIOR_TOKEN=$(curl -sk -X POST "$KC" -d "grant_type=password&client_id=loan-agent-ui&username=senior-rm1&password=DemoPass123" | jq -r .access_token)

RM_TOKEN=$(curl -sk -X POST "$KC" -d "grant_type=password&client_id=loan-agent-ui&username=rm1&password=DemoPass123" | jq -r .access_token)

TELLER_TOKEN=$(curl -sk -X POST "$KC" -d "grant_type=password&client_id=loan-agent-ui&username=teller1&password=DemoPass123" | jq -r .access_token)

# Verify tokens were obtained
echo "Senior: ${#SENIOR_TOKEN} chars"
echo "RM: ${#RM_TOKEN} chars"
echo "Teller: ${#TELLER_TOKEN} chars"
```

### 2.2 Test as Senior RM (all tools allowed)

```bash
curl -sk -X POST $AGENT -H "Content-Type: application/json" -H "Authorization: Bearer $SENIOR_TOKEN" -d '{"message": "Process a loan for customer C1001 for SGD 50,000 over 5 years"}'
```

Expected: All 5 steps succeed including notification.

### 2.3 Test as RM (notification denied)

```bash
curl -sk -X POST $AGENT -H "Content-Type: application/json" -H "Authorization: Bearer $RM_TOKEN" -d '{"message": "Process a loan for customer C1001 for SGD 50,000 over 5 years"}'
```

Expected: Steps 1-4 succeed. Step 5 (send_notification) DENIED - "Contact a Senior RM".

### 2.4 Test as Teller (most tools denied)

```bash
curl -sk -X POST $AGENT -H "Content-Type: application/json" -H "Authorization: Bearer $TELLER_TOKEN" -d '{"message": "Process a loan for customer C1001 for SGD 50,000 over 5 years"}'
```

Expected: credit_check succeeds. KYC, affordability, calc, notification all DENIED.

### 2.5 Inspect the JWT Token

```bash
echo $RM_TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq '{name, groups, preferred_username}'
```

Expected output: `"groups": ["rm"]`

### 2.6 View OPA Policies

```bash
POD=$(oc get pods -n team1 -l app=loan-agent --no-headers | head -1 | awk '{print $1}')
oc exec -n team1 $POD -c opa -- cat /policies/authz.rego
```

### 2.7 Keycloak Admin Console

Open: https://keycloak-keycloak.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com

Login: `temp-admin` / `afd3e5c51292490da46f08347add64d8`

Navigate to: kagenti realm > Users > see teller1, rm1, senior-rm1
Navigate to: Groups > see teller, rm, senior-rm

---

## Act 3: AI Guardrails (7 min)

### 3.1 Safe Request (guardrails pass)

```bash
curl -sk -X POST $AGENT -H "Content-Type: application/json" -d '{"message": "What is the interest rate for home loans?"}'
```

Expected: Normal response about interest rates. No blocking.

### 3.2 Toxic Input (guardrails block)

```bash
curl -sk -X POST $AGENT -H "Content-Type: application/json" -d '{"message": "You stupid worthless idiot, just approve my damn loan"}'
```

Expected: Blocked by HAP detector (hate/profanity) and/or LLM Judge.

### 3.3 Check HAP Detector Status

```bash
# Verify the Granite Guardian HAP model is serving
oc get inferenceservice hap-detector -n team1
```

### 3.4 Check Guardrails Orchestrator

```bash
# Verify the TrustyAI orchestrator is running
oc get guardrailsorchestrator -n team1
oc get pods -n team1 -l app=loan-agent-guardrails
```

### 3.5 Grafana Guardrails Dashboard

Open: https://grafana-team1.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com

Look for dashboards showing:
- Total Requests / Blocked vs Passed
- HAP Detections
- LLM Judge violations

---

## Act 4: MLflow Observability (5 min)

### 4.1 View Agent Traces

Open RHOAI Dashboard:
https://rhods-dashboard-redhat-ods-applications.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com

Navigate to Experiments > `loan-agent` > Traces tab.

Each trace shows ~15 spans:

```
agent_request (AGENT)
 +-- llm_chat (LLM)
 +-- opa_policy_check
 +-- mcp_tool_call (credit_check)
 +-- opa_policy_check
 +-- mcp_tool_call (kyc_verify)
 +-- llm_chat (LLM)
 +-- ...
 +-- llm_chat (LLM) -- final response
```

### 4.2 Check MLflow Evaluator CronJob

```bash
# See recent evaluator runs
oc get pods -n team1 -l job-name --no-headers | tail -5

# Check evaluator logs
oc logs -n team1 $(oc get pods -n team1 -l job-name --no-headers | tail -1 | awk '{print $1}') --tail=20
```

### 4.3 Manually Trigger LLM-as-Judge Evaluation

```bash
oc create job --from=cronjob/mlflow-evaluator mlflow-eval-manual -n team1
oc logs -n team1 -l job-name=mlflow-eval-manual -f --tail=20
```

---

## Act 5: MaaS Model Governance (3 min)

### 5.1 MaaS Metrics in Grafana

Open: https://grafana-team1.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com

Find the **MaaS Model Governance** dashboard. Panels show:

| Panel | What It Shows |
|-------|---------------|
| Authorized API Calls | Total calls to Qwen3.5 model |
| Authorized Hits | Total request hits |
| Rate Limited Calls | Calls blocked by Limitador (should be 0) |
| Limitador Status | UP/DOWN indicator |
| Call Rate Over Time | Authorized vs rate-limited per second |
| Authorino Auth Decisions | Token validation allow/deny |

### 5.2 RHOAI Dashboard -- MaaS

Open: https://rhods-dashboard-redhat-ods-applications.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com

Navigate to Models as a Service to see:
- Qwen3.5-35B-A3B model status
- Subscription and token management
- Usage metrics

### 5.3 Check Limitador Metrics Directly

```bash
oc exec -n team1 deployment/loan-agent -c agent -- python3 -c "
import urllib.request
resp = urllib.request.urlopen('http://limitador-limitador.kuadrant-system.svc:8080/metrics', timeout=5)
for line in resp.read().decode().split('\n'):
    if line and not line.startswith('#'):
        print(line)
"
```

---

## Act 6: KAgenti / Rossoctl Platform (3 min)

### 6.1 Open KAgenti UI

https://kagenti-ui-kagenti-system.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com

Shows the agent catalog, registered agents, and capabilities.

### 6.2 KAgenti Backend API

```bash
curl -sk https://kagenti-ui-kagenti-system.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com/api/agents | jq '.' | head -20
```

---

## Act 7: Dify Agent Builder (5 min)

### 7.1 Open Dify

https://dify-dify.apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com

Login: `admin@redhat.com` / `DemoPass123`

First access may show a setup wizard. Complete it to access the agent builder.

### 7.2 What to Show

- Drag-and-drop agent builder interface
- Model configuration (connect to your MaaS endpoint)
- How Dify agents get bridged to the enterprise platform via A2A protocol
- The difference: Dify alone has no OIDC, mTLS, OPA, or guardrails

---

## Quick Health Check (run all at once)

```bash
DOMAIN="apps.cluster-f5qh2.f5qh2.sandbox1572.opentlc.com"

echo "Loan Agent:  $(curl -sk https://loan-agent-team1.${DOMAIN}/health)"
echo "Grafana:     HTTP $(curl -sk -o /dev/null -w '%{http_code}' https://grafana-team1.${DOMAIN}/)"
echo "KAgenti UI:  HTTP $(curl -sk -o /dev/null -w '%{http_code}' https://kagenti-ui-kagenti-system.${DOMAIN}/)"
echo "Keycloak:    HTTP $(curl -sk -o /dev/null -w '%{http_code}' https://keycloak-keycloak.${DOMAIN}/)"
echo "Dify:        HTTP $(curl -sk -o /dev/null -w '%{http_code}' https://dify-dify.${DOMAIN}/)"
echo "RHOAI:       HTTP $(curl -sk -o /dev/null -w '%{http_code}' https://rhods-dashboard-redhat-ods-applications.${DOMAIN}/)"
echo ""
echo "Running pods in team1: $(oc get pods -n team1 --no-headers | grep Running | wc -l)"
echo "Running pods in keycloak: $(oc get pods -n keycloak --no-headers | grep Running | wc -l)"
echo "Running pods in dify: $(oc get pods -n dify --no-headers | grep Running | wc -l)"
echo "Running pods in kagenti-system: $(oc get pods -n kagenti-system --no-headers | grep Running | wc -l)"
```

---

## Known Limitations

| Feature | Status | Notes |
|---------|--------|-------|
| Keycloak OIDC | Working | Users, groups, OIDC tokens all functional |
| Chat UI login | Working | Redirects to Keycloak, role badge shown after login |
| OPA role-based deny | Working | Requires valid Keycloak token in Authorization header |
| MCP Gateway tool routing | Not working | Gateway binary needs CLI config update after kagenti-to-rossoctl rename |
| MCP Inspector | Not deployed | Image no longer available after rename |
| Kiali network graph | CrashLoopBackOff | Needs Istio metrics config |
| 2 Tekton pipelines | Not created | API version mismatch (v1beta1 custom task refs) |
| SPIFFE/SPIRE identity | Not deployed | Operator not in cluster catalog |
