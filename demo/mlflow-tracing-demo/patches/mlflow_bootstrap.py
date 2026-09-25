"""MLflow bootstrap with automatic tracing for A2A agents.

Compared to manual tracing (start_span + set_inputs + set_outputs + flush),
this module provides:

  1. ensure_mlflow_initialized() -- one-time setup with openai + langchain autolog
  2. TracingMiddleware         -- Starlette middleware that auto-extracts
                                  traceparent from incoming HTTP/A2A requests
  3. traced_a2a_call()         -- helper that auto-injects traceparent into
                                  outbound A2A calls

Agents use @mlflow.trace decorators; all LLM calls are captured by autolog.
No manual span.set_inputs() / set_outputs() / flush needed.
"""

import os
import sys
import logging
from contextlib import nullcontext
from typing import Any, Mapping

import mlflow
from mlflow.tracing import (
    get_tracing_context_headers_for_http_request,
    set_tracing_context_from_http_request_headers,
)

logger = logging.getLogger(__name__)

_initialized: bool = False


def ensure_mlflow_initialized() -> None:
    """Idempotent MLflow setup. Safe to call from every service entry point.

    On RHOAI 3.4, set:
      MLFLOW_TRACKING_URI=https://<dashboard-url>/mlflow
      MLFLOW_TRACKING_AUTH=kubernetes-namespaced
    The kubernetes-namespaced plugin handles SA tokens automatically.
    """
    global _initialized
    if _initialized:
        return
    _initialized = True

    uri = os.environ.get("MLFLOW_TRACKING_URI", "").strip()
    if not uri:
        logger.info("[mlflow_bootstrap] MLFLOW_TRACKING_URI not set; tracing disabled.")
        return

    try:
        if os.environ.get("MLFLOW_TRACKING_INSECURE_TLS", "").lower() in ("true", "1"):
            os.environ["MLFLOW_TRACKING_INSECURE_TLS"] = "true"

        # When FastMCP is present in the same process (e.g., mongodb-mcp),
        # both MLflow and FastMCP use OpenTelemetry. Tell MLflow not to
        # create its own TracerProvider so both share the global OTel context.
        # This ensures FastMCP's _meta trace propagation and MLflow's
        # @mlflow.trace spans end up in the same trace.
        try:
            import fastmcp  # noqa: F401
            os.environ.setdefault("MLFLOW_USE_DEFAULT_TRACER_PROVIDER", "false")
            logger.info("[mlflow_bootstrap] FastMCP detected; sharing OTel provider.")
        except ImportError:
            pass

        mlflow.set_tracking_uri(uri)

        workspace = os.environ.get("MLFLOW_WORKSPACE", "").strip()
        if workspace:
            mlflow.set_workspace(workspace)

        experiment = (
            os.environ.get("MLFLOW_EXPERIMENT_NAME") or "tracing-demo"
        ).strip()
        mlflow.set_experiment(experiment)

        # If we deferred the tracer provider, connect MLflow's span
        # processors to the global OTel provider now.
        if os.environ.get("MLFLOW_USE_DEFAULT_TRACER_PROVIDER", "").lower() == "false":
            try:
                from mlflow.tracing import set_destination
                from mlflow.entities.trace_location import MlflowExperimentLocation

                exp_obj = mlflow.get_experiment_by_name(experiment)
                if exp_obj:
                    set_destination(MlflowExperimentLocation(exp_obj.experiment_id))
                    logger.info("[mlflow_bootstrap] OTel bridge: MLflow spans -> experiment %s", exp_obj.experiment_id)
            except Exception as bridge_exc:
                logger.warning("[mlflow_bootstrap] OTel bridge setup failed: %s", bridge_exc)

        try:
            mlflow.openai.autolog()
        except Exception:
            pass

        try:
            import langchain  # noqa: F401
            mlflow.langchain.autolog(run_tracer_inline=True)
        except ImportError:
            pass

        logger.info(
            "[mlflow_bootstrap] initialized: experiment=%s, uri=%s",
            experiment,
            uri,
        )
    except Exception as exc:
        print(
            f"[mlflow_bootstrap] init failed ({exc}); tracing may be disabled.",
            file=sys.stderr,
        )


# ---------------------------------------------------------------------------
# Starlette middleware -- auto-restores traceparent on every inbound request
# ---------------------------------------------------------------------------

class TracingMiddleware:
    """ASGI middleware that extracts W3C traceparent from incoming requests.

    Drop this into your A2A Starlette app and traceparent propagation is
    handled automatically -- no per-agent code required.

    Usage in __main__.py:
        app = server.build()
        app.add_middleware(TracingMiddleware)
    """

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            raw_headers = scope.get("headers", [])
            decoded = {
                k.decode("latin-1").lower(): v.decode("latin-1")
                for k, v in raw_headers
            }
            if "traceparent" in decoded:
                ctx_mgr = set_tracing_context_from_http_request_headers(decoded)
            else:
                ctx_mgr = nullcontext()

            with ctx_mgr:
                await self.app(scope, receive, send)
        else:
            await self.app(scope, receive, send)


# ---------------------------------------------------------------------------
# Outbound A2A call helper -- auto-injects traceparent
# ---------------------------------------------------------------------------

async def traced_a2a_call(
    agent_url: str,
    skill: str,
    params: dict,
    auth_token: str = "",
    timeout: int = 120,
) -> dict:
    """Call an A2A agent with automatic traceparent propagation.

    Replaces the manual pattern of:
        headers = get_tracing_context_headers_for_http_request()
        headers.update(trace_headers)
        async with httpx.AsyncClient(headers=headers) ...

    Now agents just call:
        result = await traced_a2a_call(url, "skill_name", params)
    """
    import json
    import uuid
    import httpx
    from a2a.client import A2AClient
    from a2a.types import MessageSendParams, SendMessageRequest

    payload = json.dumps({"skill": skill, **params})

    headers: dict[str, str] = {}
    if auth_token:
        tok = auth_token if auth_token.startswith("Bearer") else f"Bearer {auth_token}"
        headers["Authorization"] = tok

    headers.update(get_tracing_context_headers_for_http_request())

    message_params = MessageSendParams(
        message={
            "role": "user",
            "parts": [{"kind": "text", "text": payload}],
            "messageId": uuid.uuid4().hex,
        }
    )
    request = SendMessageRequest(id=str(uuid.uuid4()), params=message_params)

    http_timeout = httpx.Timeout(connect=30.0, read=float(timeout), write=30.0, pool=30.0)
    async with httpx.AsyncClient(timeout=http_timeout, headers=headers) as httpx_client:
        client = A2AClient(httpx_client=httpx_client, url=agent_url)
        response = await client.send_message(request)

    resp = response.root
    if hasattr(resp, "error") and resp.error:
        return {"status": "error", "error": f"A2A error: {resp.error.message}"}

    task_result = resp.result if hasattr(resp, "result") else None
    if task_result and hasattr(task_result, "artifacts") and task_result.artifacts:
        for artifact in task_result.artifacts:
            for part in artifact.parts or []:
                text = None
                if hasattr(part, "root") and hasattr(part.root, "text"):
                    text = part.root.text
                elif hasattr(part, "text"):
                    text = part.text
                if text:
                    try:
                        return json.loads(text)
                    except json.JSONDecodeError:
                        return {"status": "success", "content": text}

    return {"status": "error", "error": "No artifact returned from agent"}


# ---------------------------------------------------------------------------
# Trace metadata helpers
# ---------------------------------------------------------------------------

def update_trace_session(metadata: Mapping[str, Any]) -> None:
    """Attach session/campaign context to the active trace."""
    try:
        mlflow.update_current_trace(metadata=dict(metadata))
    except Exception:
        pass


def get_openai_client():
    """Build an AsyncOpenAI client pointed at vLLM or any compatible endpoint.

    RHOAI-toolkit patch: on clusters where the direct vLLM endpoint is an
    LLMInferenceService's in-cluster workload Service (kserve-workload-svc),
    the serving cert is signed by the cluster's internal service-ca, which is
    not in the pod's public CA trust store -- the default httpx client raises
    `SSL: CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate`.
    Mirrors the existing MLFLOW_TRACKING_INSECURE_TLS pattern already used by
    this same module for the MLflow tracking client. See
    docs/TODO-next-session.md "Cluster-sclg6 Session" for the toolkit-side
    writeup (this file is a runtime-mounted patch overlay, not upstream code --
    see demo/mlflow-tracing-demo/deploy.sh and patches/mlflow_bootstrap.py).
    """
    from openai import AsyncOpenAI

    kwargs = {
        "base_url": os.environ.get("OPENAI_BASE_URL", "http://localhost:8000/v1"),
        "api_key": os.environ.get("OPENAI_API_KEY", "EMPTY"),
    }
    if os.environ.get("OPENAI_INSECURE_TLS", "").lower() in ("true", "1"):
        import httpx
        kwargs["http_client"] = httpx.AsyncClient(verify=False)

    return AsyncOpenAI(**kwargs)


def get_model_name() -> str:
    return os.environ.get("LLM_MODEL", "default-model")


def is_mock_mode() -> bool:
    return os.environ.get("USE_MOCK", "0") == "1"
