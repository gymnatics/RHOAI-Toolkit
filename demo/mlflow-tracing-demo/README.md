# MLflow Tracing Demo (Banking Multi-Agent)

Banking credit risk assessment system with MLflow 3.x distributed tracing on RHOAI 3.4.

Based on [gymnatics/MLFlow-Agent-Observability-Demo](https://github.com/gymnatics/MLFlow-Agent-Observability-Demo).

## Requirements

- RHOAI 3.4 with MLflow operator enabled (`mlflowoperator.managementState: Managed`)
- A vLLM model endpoint with tool-calling (Qwen3-8B or similar)
- 1x GPU for the LLM (can reuse an existing MaaS or InferenceService deployment)

## Deploy

```bash
./deploy.sh                # Interactive deployment
./deploy.sh --build-only   # Rebuild container images only
./deploy.sh --apply-only   # Reapply k8s manifests only
./deploy.sh --delete       # Remove everything
```

The script clones the repo and delegates to its own `deploy.sh`, which builds images via OpenShift BuildConfigs and deploys all services.

## Architecture

Multi-agent A2A system with end-to-end MLflow trace propagation:

| Agent | Role | Tracing |
|-------|------|---------|
| **Orchestrator** | LangGraph workflow coordinator | `@mlflow.trace` + `langchain.autolog` |
| **Customer Analyst** | MongoDB data retrieval via MCP | `@mlflow.trace` + MCP `_meta` propagation |
| **Risk Assessor** | LLM-powered credit risk analysis | `@mlflow.trace` + `openai.autolog` |
| **Compliance Reviewer** | Regulatory compliance checks | `@mlflow.trace` + `openai.autolog` |

## Features

- Distributed tracing across all agents via W3C traceparent
- Multi-turn chat with session tracking
- Built-in evaluators (regulatory compliance, risk grounding, SLA)
- Streamlit banking dashboard
- MongoDB MCP server for customer/loan data

## Demo Flow

1. **Customer Assessment** — Run credit risk assessment for sample banking customers
2. **Trace Exploration** — View nested trace trees in MLflow UI (orchestrator -> agents -> MCP -> LLM)
3. **Multi-Turn Chat** — Banking assistant with session context
4. **Evaluators** — Run MLflow evaluators on traces (compliance, accuracy, latency SLAs)
