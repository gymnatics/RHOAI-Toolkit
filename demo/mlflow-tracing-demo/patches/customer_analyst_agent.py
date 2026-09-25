"""Customer Analyst Agent -- retrieves customer data via MongoDB MCP.

Demonstrates MCP tool calls with automatic traceparent propagation.
The trace chain: Orchestrator -> Customer Analyst -> MongoDB MCP -> MongoDB
"""

import json
import os
import sys
from typing import Any

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

import mlflow

from shared.mlflow_bootstrap import is_mock_mode

MONGODB_MCP_URL = os.environ.get("MONGODB_MCP_URL", "http://mongodb-mcp:8090")

MOCK_CUSTOMERS = {
    "C-1001": {
        "customer_id": "C-1001", "name": "Alice Tan", "tier": "platinum", "age": 42,
        "occupation": "CFO", "annual_income": 280000, "credit_score": 780,
        "account_balance": 125000, "risk_category": "low",
    },
    "C-1006": {
        "customer_id": "C-1006", "name": "Frank Lee", "tier": "silver", "age": 45,
        "occupation": "Restaurant Owner", "annual_income": 95000, "credit_score": 580,
        "account_balance": 8500, "risk_category": "high",
    },
    "C-1004": {
        "customer_id": "C-1004", "name": "David Lim", "tier": "silver", "age": 28,
        "occupation": "Marketing Manager", "annual_income": 75000, "credit_score": 650,
        "account_balance": 12000, "risk_category": "medium",
    },
    "C-1007": {
        "customer_id": "C-1007", "name": "Grace Ho", "tier": "diamond", "age": 60,
        "occupation": "Retired Banker", "annual_income": 350000, "credit_score": 830,
        "account_balance": 720000, "risk_category": "low",
    },
}

MOCK_LOANS = {
    "C-1001": [
        {"loan_id": "L-2001", "type": "mortgage", "amount": 800000, "outstanding": 420000, "interest_rate": 3.2, "status": "active"},
        {"loan_id": "L-2002", "type": "auto", "amount": 45000, "outstanding": 12000, "interest_rate": 4.5, "status": "active"},
    ],
    "C-1006": [
        {"loan_id": "L-2008", "type": "business", "amount": 200000, "outstanding": 185000, "interest_rate": 8.0, "status": "delinquent"},
        {"loan_id": "L-2009", "type": "personal", "amount": 30000, "outstanding": 28000, "interest_rate": 12.0, "status": "active"},
    ],
    "C-1004": [
        {"loan_id": "L-2005", "type": "personal", "amount": 15000, "outstanding": 14200, "interest_rate": 9.5, "status": "active"},
        {"loan_id": "L-2006", "type": "credit_line", "amount": 10000, "outstanding": 8500, "interest_rate": 18.0, "status": "active"},
    ],
    "C-1007": [
        {"loan_id": "L-2010", "type": "mortgage", "amount": 1200000, "outstanding": 0, "interest_rate": 2.8, "status": "paid_off"},
    ],
}


class CustomerAnalystAgent:

    async def handle_skill(self, skill: str, params: dict) -> dict:
        dispatch = {
            "get_customer_profile": self._get_customer_profile,
            "search_customers": self._search_customers,
        }
        handler = dispatch.get(skill, self._get_customer_profile)
        return await handler(params)

    @mlflow.trace(name="customer_analyst.get_profile", span_type="AGENT")
    async def _get_customer_profile(self, params: dict) -> dict:
        customer_id = params.get("customer_id", "C-1001")

        if is_mock_mode():
            return self._mock_profile(customer_id)

        profile = await self._call_mcp_tool("get_customer", {"customer_id": customer_id})
        loans = await self._call_mcp_tool("get_loan_history", {"customer_id": customer_id})

        return {
            "customer_id": customer_id,
            "profile": profile,
            "loans": loans if isinstance(loans, list) else [],
            "total_outstanding": sum(
                l.get("outstanding", 0) for l in (loans if isinstance(loans, list) else []) if isinstance(l, dict)
            ),
        }

    @mlflow.trace(name="customer_analyst.search", span_type="AGENT")
    async def _search_customers(self, params: dict) -> dict:
        if is_mock_mode():
            tier = params.get("tier", "")
            results = [v for v in MOCK_CUSTOMERS.values() if not tier or v["tier"] == tier]
            return {"customers": results, "count": len(results)}

        customers = await self._call_mcp_tool("search_customers", {
            "tier": params.get("tier", ""),
            "min_credit_score": params.get("min_credit_score", 0),
            "min_balance": params.get("min_balance", 0),
            "limit": params.get("limit", 10),
        })

        return {"customers": customers if isinstance(customers, list) else [], "count": len(customers) if isinstance(customers, list) else 0}

    @mlflow.trace(name="customer_analyst.mcp_call", span_type="TOOL")
    async def _call_mcp_tool(self, tool_name: str, arguments: dict) -> Any:
        """Call a MongoDB MCP tool.

        FastMCP automatically propagates trace context via MCP _meta fields --
        no manual header injection needed. The FastMCP client reads the active
        OTel span (created by @mlflow.trace above) and injects traceparent
        into the MCP request's _meta.

        suppress_fastmcp_telemetry() prevents noisy tools/list spans during
        client initialization while preserving context propagation on call_tool.
        """
        from fastmcp import Client

        # RHOAI-toolkit patch: requirements.txt pins `fastmcp>=3.0.0,<4`, but
        # `suppress_fastmcp_telemetry` was removed/renamed within the 3.x line
        # itself (present when this demo was authored, gone by fastmcp 3.4.7)
        # -- a real upstream dependency-drift bug, not a cluster/config issue.
        # Fall back to a no-op context manager if it's unavailable; this only
        # loses the tools/list-span-suppression optimization, not correctness
        # or trace-context propagation on call_tool. See
        # docs/TODO-next-session.md "Cluster-sclg6 Session" and
        # demo/mlflow-tracing-demo/deploy.sh (this file is a runtime-mounted
        # patch overlay, not upstream code).
        try:
            from fastmcp.telemetry import suppress_fastmcp_telemetry
        except ImportError:
            from contextlib import nullcontext as suppress_fastmcp_telemetry

        with suppress_fastmcp_telemetry():
            async with Client(f"{MONGODB_MCP_URL}/mcp") as mcp_client:
                result = await mcp_client.call_tool(tool_name, arguments)

        if hasattr(result, "structuredContent") and result.structuredContent is not None:
            return result.structuredContent

        if result.content:
            text = result.content[0].text if hasattr(result.content[0], "text") else str(result.content[0])
            try:
                return json.loads(text)
            except (json.JSONDecodeError, TypeError):
                return text

        return {}

    @staticmethod
    def _mock_profile(customer_id: str) -> dict:
        profile = MOCK_CUSTOMERS.get(customer_id, MOCK_CUSTOMERS["C-1001"])
        loans = MOCK_LOANS.get(customer_id, [])
        return {
            "customer_id": customer_id,
            "profile": profile,
            "loans": loans,
            "total_outstanding": sum(l.get("outstanding", 0) for l in loans),
        }
