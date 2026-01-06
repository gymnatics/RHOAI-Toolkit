"""
LlamaStack + MCP + Guardrails Demo UI
A demonstration interface showing how LlamaStack orchestrates LLM + MCP tools + AI Safety
"""
import streamlit as st
import requests
import json
import os
import re
from datetime import datetime
from typing import List, Dict, Any, Optional, Tuple

# Configuration from environment or defaults
LLAMASTACK_URL = os.getenv("LLAMASTACK_URL", "http://localhost:8321")
MODEL_ID = os.getenv("MODEL_ID", "llama3")
MCP_SERVER_URL = os.getenv("MCP_SERVER_URL", "http://localhost:8000")
GUARDRAILS_URL = os.getenv("GUARDRAILS_URL", "")  # TrustyAI GuardrailsOrchestrator URL

# UI Customization (optional environment variables)
APP_TITLE = os.getenv("APP_TITLE", "LlamaStack + MCP Demo")
APP_SUBTITLE = os.getenv("APP_SUBTITLE", "Demonstrating AI Agent orchestration with Model Context Protocol tools")
MCP_SERVER_NAME = os.getenv("MCP_SERVER_NAME", "MCP Server")
MCP_SERVER_DESCRIPTION = os.getenv("MCP_SERVER_DESCRIPTION", "Model Context Protocol server exposing tools to the LLM")
CHAT_PLACEHOLDER = os.getenv("CHAT_PLACEHOLDER", "Ask a question...")
SYSTEM_PROMPT = os.getenv("SYSTEM_PROMPT", """You are an intelligent assistant with access to external tools.
Use the available tools to fetch real data when answering user questions.
Always explain the data in a user-friendly way after retrieving it.""")

# Guardrails configuration
ENABLE_GUARDRAILS = os.getenv("ENABLE_GUARDRAILS", "false").lower() == "true"
GUARDRAILS_MODE = os.getenv("GUARDRAILS_MODE", "warn")  # "warn" or "block"

# Page config
st.set_page_config(
    page_title="LlamaStack + MCP + Guardrails Demo",
    page_icon="🦙",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for a modern, distinctive look
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap');
    
    :root {
        --primary: #6366f1;
        --primary-light: #818cf8;
        --secondary: #10b981;
        --background: #0f172a;
        --surface: #1e293b;
        --surface-light: #334155;
        --text: #f1f5f9;
        --text-muted: #94a3b8;
        --border: #475569;
        --accent: #f59e0b;
        --danger: #ef4444;
        --warning: #f59e0b;
    }
    
    .stApp {
        font-family: 'Plus Jakarta Sans', sans-serif;
    }
    
    /* Header styling */
    .main-header {
        background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 50%, #a855f7 100%);
        padding: 1.5rem 2rem;
        border-radius: 16px;
        margin-bottom: 1.5rem;
        box-shadow: 0 4px 20px rgba(99, 102, 241, 0.3);
    }
    
    .main-header h1 {
        color: white;
        font-weight: 700;
        margin: 0;
        font-size: 2rem;
    }
    
    .main-header p {
        color: rgba(255,255,255,0.85);
        margin: 0.5rem 0 0 0;
        font-size: 1rem;
    }
    
    /* Architecture diagram container */
    .architecture-box {
        background: linear-gradient(145deg, #1e293b 0%, #0f172a 100%);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 1rem 0;
    }
    
    .flow-diagram {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        flex-wrap: wrap;
        padding: 1rem;
    }
    
    .flow-box {
        background: linear-gradient(135deg, #334155, #1e293b);
        border: 2px solid #6366f1;
        border-radius: 10px;
        padding: 0.75rem 1rem;
        color: #f1f5f9;
        font-weight: 600;
        font-size: 0.85rem;
        text-align: center;
        min-width: 120px;
    }
    
    .flow-box.mcp {
        border-color: #10b981;
        background: linear-gradient(135deg, #064e3b, #0f172a);
    }
    
    .flow-box.llm {
        border-color: #f59e0b;
        background: linear-gradient(135deg, #451a03, #0f172a);
    }
    
    .flow-box.guardrails {
        border-color: #ef4444;
        background: linear-gradient(135deg, #7f1d1d, #0f172a);
    }
    
    .flow-arrow {
        color: #6366f1;
        font-size: 1.5rem;
        font-weight: bold;
    }
    
    /* Tool call styling */
    .tool-call-box {
        background: linear-gradient(135deg, #064e3b 0%, #022c22 100%);
        border: 1px solid #10b981;
        border-radius: 10px;
        padding: 1rem;
        margin: 0.75rem 0;
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.8rem;
    }
    
    .tool-call-header {
        color: #10b981;
        font-weight: 600;
        margin-bottom: 0.5rem;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    
    .tool-call-content {
        color: #a7f3d0;
        white-space: pre-wrap;
        overflow-x: auto;
    }
    
    /* Tool result styling */
    .tool-result-box {
        background: linear-gradient(135deg, #1e3a5f 0%, #0f172a 100%);
        border: 1px solid #3b82f6;
        border-radius: 10px;
        padding: 1rem;
        margin: 0.75rem 0;
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.8rem;
    }
    
    .tool-result-header {
        color: #60a5fa;
        font-weight: 600;
        margin-bottom: 0.5rem;
    }
    
    .tool-result-content {
        color: #bfdbfe;
        white-space: pre-wrap;
        overflow-x: auto;
        max-height: 300px;
        overflow-y: auto;
    }
    
    /* Guardrails styling */
    .guardrails-box {
        background: linear-gradient(135deg, #7f1d1d 0%, #450a0a 100%);
        border: 1px solid #ef4444;
        border-radius: 10px;
        padding: 1rem;
        margin: 0.75rem 0;
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.8rem;
    }
    
    .guardrails-box.safe {
        background: linear-gradient(135deg, #064e3b 0%, #022c22 100%);
        border-color: #10b981;
    }
    
    .guardrails-box.warning {
        background: linear-gradient(135deg, #78350f 0%, #451a03 100%);
        border-color: #f59e0b;
    }
    
    .guardrails-header {
        font-weight: 600;
        margin-bottom: 0.5rem;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    
    .guardrails-header.blocked {
        color: #ef4444;
    }
    
    .guardrails-header.safe {
        color: #10b981;
    }
    
    .guardrails-header.warning {
        color: #f59e0b;
    }
    
    .guardrails-content {
        color: #fecaca;
        white-space: pre-wrap;
    }
    
    .guardrails-content.safe {
        color: #a7f3d0;
    }
    
    .guardrails-content.warning {
        color: #fde68a;
    }
    
    /* Status indicators */
    .status-badge {
        display: inline-flex;
        align-items: center;
        gap: 0.4rem;
        padding: 0.25rem 0.75rem;
        border-radius: 20px;
        font-size: 0.75rem;
        font-weight: 600;
    }
    
    .status-badge.online {
        background: rgba(16, 185, 129, 0.2);
        color: #10b981;
        border: 1px solid #10b981;
    }
    
    .status-badge.offline {
        background: rgba(239, 68, 68, 0.2);
        color: #ef4444;
        border: 1px solid #ef4444;
    }
    
    .status-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        animation: pulse 2s infinite;
    }
    
    .status-dot.online {
        background: #10b981;
    }
    
    .status-dot.offline {
        background: #ef4444;
    }
    
    @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.5; }
    }
    
    /* Config panel */
    .config-section {
        background: #1e293b;
        border-radius: 10px;
        padding: 1rem;
        margin-bottom: 1rem;
        border: 1px solid #334155;
    }
    
    .config-label {
        color: #94a3b8;
        font-size: 0.75rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        margin-bottom: 0.25rem;
    }
    
    /* Info cards */
    .info-card {
        background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1rem;
        margin: 0.5rem 0;
    }
    
    .info-card h4 {
        color: #f1f5f9;
        margin: 0 0 0.5rem 0;
        font-size: 0.9rem;
    }
    
    .info-card p {
        color: #94a3b8;
        margin: 0;
        font-size: 0.8rem;
    }
    
    /* Metrics row */
    .metrics-row {
        display: flex;
        gap: 1rem;
        margin: 1rem 0;
    }
    
    .metric-card {
        flex: 1;
        background: #1e293b;
        border-radius: 10px;
        padding: 1rem;
        text-align: center;
        border: 1px solid #334155;
    }
    
    .metric-value {
        font-size: 1.5rem;
        font-weight: 700;
        color: #6366f1;
    }
    
    .metric-label {
        font-size: 0.75rem;
        color: #94a3b8;
        text-transform: uppercase;
    }
</style>
""", unsafe_allow_html=True)

# Initialize session state
if "messages" not in st.session_state:
    st.session_state.messages = []
if "mcp_tools" not in st.session_state:
    st.session_state.mcp_tools = []
if "llamastack_status" not in st.session_state:
    st.session_state.llamastack_status = "unknown"
if "mcp_status" not in st.session_state:
    st.session_state.mcp_status = "unknown"
if "guardrails_status" not in st.session_state:
    st.session_state.guardrails_status = "unknown"
if "tool_calls_count" not in st.session_state:
    st.session_state.tool_calls_count = 0
if "guardrails_blocks" not in st.session_state:
    st.session_state.guardrails_blocks = 0
if "show_architecture" not in st.session_state:
    st.session_state.show_architecture = True
if "enable_guardrails" not in st.session_state:
    st.session_state.enable_guardrails = ENABLE_GUARDRAILS
if "guardrails_mode" not in st.session_state:
    st.session_state.guardrails_mode = GUARDRAILS_MODE


def check_llamastack_health() -> bool:
    """Check if LlamaStack is healthy."""
    try:
        response = requests.get(f"{LLAMASTACK_URL}/v1/health", timeout=5)
        return response.status_code == 200
    except:
        return False


def check_mcp_health() -> bool:
    """Check if MCP server is healthy."""
    try:
        response = requests.post(
            f"{MCP_SERVER_URL}/mcp",
            json={
                "jsonrpc": "2.0",
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "healthcheck", "version": "1.0"}
                },
                "id": 1
            },
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json, text/event-stream"
            },
            timeout=5
        )
        return response.status_code == 200
    except:
        return False


def check_guardrails_health() -> bool:
    """Check if GuardrailsOrchestrator is healthy."""
    if not GUARDRAILS_URL:
        return False
    try:
        response = requests.get(f"{GUARDRAILS_URL}/health", timeout=5, verify=False)
        return response.status_code == 200
    except:
        return False


def check_guardrails(text: str, check_type: str = "input") -> Tuple[bool, str, List[Dict]]:
    """
    Check text against guardrails.
    
    Returns:
        Tuple of (is_safe, message, detections)
    """
    if not st.session_state.enable_guardrails:
        return True, "Guardrails disabled", []
    
    if not GUARDRAILS_URL:
        return True, "No guardrails URL configured", []
    
    try:
        # Call TrustyAI GuardrailsOrchestrator API
        response = requests.post(
            f"{GUARDRAILS_URL}/api/v1/text/contents",
            json={"content": text},
            headers={"Content-Type": "application/json"},
            timeout=10,
            verify=False
        )
        
        if response.status_code == 200:
            result = response.json()
            detections = result.get("detections", [])
            
            if detections:
                detection_msgs = [f"- {d.get('type', 'unknown')}: {d.get('text', '')}" for d in detections]
                return False, f"Detected issues:\n" + "\n".join(detection_msgs), detections
            else:
                return True, "Content passed safety checks", []
        else:
            return True, f"Guardrails API error: {response.status_code}", []
            
    except Exception as e:
        return True, f"Guardrails check failed: {str(e)}", []


def get_available_tools() -> List[Dict]:
    """Fetch available MCP tools from LlamaStack."""
    try:
        response = requests.get(f"{LLAMASTACK_URL}/v1/tools", timeout=10)
        if response.status_code == 200:
            data = response.json()
            # Handle both list and dict responses
            if isinstance(data, list):
                return data
            return data.get("data", [])
    except Exception as e:
        st.error(f"Could not fetch tools: {e}")
    return []


def chat_completion_openai(messages: List[Dict], tools: List[Dict] = None) -> Dict:
    """Send chat completion request using OpenAI-compatible endpoint."""
    payload = {
        "model": MODEL_ID,
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": 4096,
    }
    
    if tools:
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
    
    try:
        response = requests.post(
            f"{LLAMASTACK_URL}/v1/openai/v1/chat/completions",
            json=payload,
            timeout=120
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": str(e)}


def format_tools_for_openai(mcp_tools: List[Dict]) -> List[Dict]:
    """Convert MCP tools to OpenAI function calling format."""
    openai_tools = []
    for tool in mcp_tools:
        openai_tool = {
            "type": "function",
            "function": {
                "name": tool.get("name", tool.get("identifier", "")),
                "description": tool.get("description", ""),
                "parameters": tool.get("parameters", tool.get("parameter_definitions", {
                    "type": "object",
                    "properties": {},
                    "required": []
                }))
            }
        }
        openai_tools.append(openai_tool)
    return openai_tools


def execute_tool_call(tool_name: str, tool_args: Dict) -> str:
    """Execute a tool call via LlamaStack."""
    try:
        # Try the tool-runtime invoke endpoint
        response = requests.post(
            f"{LLAMASTACK_URL}/v1/tool-runtime/invoke",
            json={
                "tool_name": tool_name,
                "kwargs": tool_args
            },
            timeout=60
        )
        response.raise_for_status()
        result = response.json()
        
        # Handle various response formats
        if isinstance(result, dict):
            content = result.get("content", result)
            # If content is a list, convert each item to string and join
            if isinstance(content, list):
                return "\n".join(
                    item.get("text", json.dumps(item)) if isinstance(item, dict) else str(item)
                    for item in content
                )
            elif isinstance(content, dict):
                return json.dumps(content, indent=2)
            return str(content)
        elif isinstance(result, list):
            return "\n".join(
                item.get("text", json.dumps(item)) if isinstance(item, dict) else str(item)
                for item in result
            )
        return str(result)
    except Exception as e:
        return f"Tool execution error: {str(e)}"


def render_guardrails_result(is_safe: bool, message: str, check_type: str):
    """Render guardrails check result."""
    if is_safe:
        st.markdown(f"""
        <div class="guardrails-box safe">
            <div class="guardrails-header safe">✅ {check_type.title()} Safety Check: PASSED</div>
            <div class="guardrails-content safe">{message}</div>
        </div>
        """, unsafe_allow_html=True)
    else:
        status_class = "warning" if st.session_state.guardrails_mode == "warn" else "blocked"
        icon = "⚠️" if st.session_state.guardrails_mode == "warn" else "🚫"
        status_text = "WARNING" if st.session_state.guardrails_mode == "warn" else "BLOCKED"
        
        st.markdown(f"""
        <div class="guardrails-box {status_class}">
            <div class="guardrails-header {status_class}">{icon} {check_type.title()} Safety Check: {status_text}</div>
            <div class="guardrails-content {status_class}">{message}</div>
        </div>
        """, unsafe_allow_html=True)


# ============== HEADER ==============
st.markdown(f"""
<div class="main-header">
    <h1>🦙 {APP_TITLE}</h1>
    <p>{APP_SUBTITLE}</p>
</div>
""", unsafe_allow_html=True)

# ============== SIDEBAR ==============
with st.sidebar:
    st.markdown("### 🔧 Configuration")
    
    # Connection settings
    with st.expander("🌐 Endpoints", expanded=False):
        new_llamastack_url = st.text_input(
            "LlamaStack URL",
            value=LLAMASTACK_URL,
            help="LlamaStack service endpoint"
        )
        new_model_id = st.text_input(
            "Model ID", 
            value=MODEL_ID,
            help="Model identifier in LlamaStack"
        )
        new_mcp_url = st.text_input(
            "MCP Server URL",
            value=MCP_SERVER_URL,
            help="MCP Server endpoint"
        )
        new_guardrails_url = st.text_input(
            "Guardrails URL",
            value=GUARDRAILS_URL,
            help="TrustyAI GuardrailsOrchestrator endpoint"
        )
        
        # Update globals if changed
        if new_llamastack_url != LLAMASTACK_URL:
            LLAMASTACK_URL = new_llamastack_url
        if new_model_id != MODEL_ID:
            MODEL_ID = new_model_id
        if new_mcp_url != MCP_SERVER_URL:
            MCP_SERVER_URL = new_mcp_url
        if new_guardrails_url != GUARDRAILS_URL:
            GUARDRAILS_URL = new_guardrails_url
    
    st.markdown("---")
    
    # Guardrails settings
    st.markdown("### 🛡️ Guardrails")
    
    st.session_state.enable_guardrails = st.checkbox(
        "Enable Guardrails",
        value=st.session_state.enable_guardrails,
        help="Enable AI safety checks on inputs and outputs"
    )
    
    if st.session_state.enable_guardrails:
        st.session_state.guardrails_mode = st.radio(
            "Mode",
            options=["warn", "block"],
            index=0 if st.session_state.guardrails_mode == "warn" else 1,
            help="Warn: Show warning but allow. Block: Prevent unsafe content."
        )
    
    st.markdown("---")
    
    # Status checks
    st.markdown("### 📡 Service Status")
    
    col1, col2 = st.columns(2)
    
    with col1:
        if st.button("🔄 Check", key="check_status"):
            st.session_state.llamastack_status = "online" if check_llamastack_health() else "offline"
            st.session_state.mcp_status = "online" if check_mcp_health() else "offline"
            st.session_state.guardrails_status = "online" if check_guardrails_health() else "offline"
    
    # LlamaStack status
    ls_status = st.session_state.llamastack_status
    ls_class = "online" if ls_status == "online" else "offline"
    st.markdown(f"""
    <div class="status-badge {ls_class}">
        <span class="status-dot {ls_class}"></span>
        LlamaStack: {ls_status.upper()}
    </div>
    """, unsafe_allow_html=True)
    
    # MCP status  
    mcp_status = st.session_state.mcp_status
    mcp_class = "online" if mcp_status == "online" else "offline"
    st.markdown(f"""
    <div class="status-badge {mcp_class}">
        <span class="status-dot {mcp_class}"></span>
        MCP Server: {mcp_status.upper()}
    </div>
    """, unsafe_allow_html=True)
    
    # Guardrails status
    gr_status = st.session_state.guardrails_status
    gr_class = "online" if gr_status == "online" else "offline"
    st.markdown(f"""
    <div class="status-badge {gr_class}">
        <span class="status-dot {gr_class}"></span>
        Guardrails: {gr_status.upper()}
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown("---")
    
    # Tools section
    st.markdown("### 🛠️ MCP Tools")
    
    if st.button("🔄 Refresh Tools"):
        st.session_state.mcp_tools = get_available_tools()
        if st.session_state.mcp_tools:
            st.success(f"Found {len(st.session_state.mcp_tools)} tools!")
        else:
            st.warning("No tools found")
    
    if st.session_state.mcp_tools:
        for tool in st.session_state.mcp_tools:
            tool_name = tool.get("name", tool.get("identifier", "Unknown"))
            with st.expander(f"📦 {tool_name}"):
                st.caption(tool.get("description", "No description")[:200])
    else:
        st.info("Click 'Refresh Tools' to load available MCP tools")
    
    st.markdown("---")
    
    # Actions
    st.markdown("### ⚡ Actions")
    
    if st.button("🗑️ Clear Chat", use_container_width=True):
        st.session_state.messages = []
        st.session_state.tool_calls_count = 0
        st.session_state.guardrails_blocks = 0
        st.rerun()
    
    st.checkbox("Show Architecture", value=True, key="show_architecture")

# ============== MAIN CONTENT ==============

# Architecture diagram (collapsible)
if st.session_state.show_architecture:
    with st.expander("🏗️ Architecture Overview", expanded=True):
        # Show different architecture based on guardrails status
        if st.session_state.enable_guardrails:
            st.markdown(f"""
            <div class="architecture-box">
                <div class="flow-diagram">
                    <div class="flow-box">👤 User Query</div>
                    <span class="flow-arrow">→</span>
                    <div class="flow-box guardrails">🛡️ Input<br/>Guardrails</div>
                    <span class="flow-arrow">→</span>
                    <div class="flow-box">🦙 LlamaStack</div>
                    <span class="flow-arrow">→</span>
                    <div class="flow-box llm">🤖 {MODEL_ID}</div>
                    <span class="flow-arrow">→</span>
                    <div class="flow-box mcp">🔧 {MCP_SERVER_NAME}</div>
                </div>
                <div class="flow-diagram">
                    <div class="flow-box mcp">📊 Data Source</div>
                    <span class="flow-arrow">→</span>
                    <div class="flow-box llm">🤖 Response</div>
                    <span class="flow-arrow">→</span>
                    <div class="flow-box guardrails">🛡️ Output<br/>Guardrails</div>
                    <span class="flow-arrow">→</span>
                    <div class="flow-box">👤 User</div>
                </div>
            </div>
            """, unsafe_allow_html=True)
        else:
            st.markdown(f"""
            <div class="architecture-box">
                <div class="flow-diagram">
                    <div class="flow-box">👤 User Query</div>
                    <span class="flow-arrow">→</span>
                    <div class="flow-box">🦙 LlamaStack</div>
                    <span class="flow-arrow">→</span>
                    <div class="flow-box llm">🤖 {MODEL_ID}</div>
                    <span class="flow-arrow">→</span>
                    <div class="flow-box mcp">🔧 {MCP_SERVER_NAME}</div>
                    <span class="flow-arrow">→</span>
                    <div class="flow-box">📊 Data Source</div>
                </div>
            </div>
            """, unsafe_allow_html=True)
        
        cols = st.columns(4 if st.session_state.enable_guardrails else 3)
        
        with cols[0]:
            st.markdown("""
            <div class="info-card">
                <h4>🦙 LlamaStack</h4>
                <p>Orchestrates the AI agent, manages tool calls, and routes requests.</p>
            </div>
            """, unsafe_allow_html=True)
        
        with cols[1]:
            st.markdown(f"""
            <div class="info-card">
                <h4>🔧 {MCP_SERVER_NAME}</h4>
                <p>{MCP_SERVER_DESCRIPTION[:100]}...</p>
            </div>
            """, unsafe_allow_html=True)
        
        with cols[2]:
            st.markdown(f"""
            <div class="info-card">
                <h4>🤖 {MODEL_ID}</h4>
                <p>LLM with tool-calling support. Decides when to use tools.</p>
            </div>
            """, unsafe_allow_html=True)
        
        if st.session_state.enable_guardrails:
            with cols[3]:
                st.markdown("""
                <div class="info-card">
                    <h4>🛡️ Guardrails</h4>
                    <p>TrustyAI safety checks for PII, toxicity, and harmful content.</p>
                </div>
                """, unsafe_allow_html=True)

# Metrics
col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric("💬 Messages", len(st.session_state.messages))
with col2:
    st.metric("🔧 Tool Calls", st.session_state.tool_calls_count)
with col3:
    st.metric("🛠️ Available Tools", len(st.session_state.mcp_tools))
with col4:
    st.metric("🛡️ Blocked", st.session_state.guardrails_blocks)

st.markdown("---")

# System message for the model
SYSTEM_MESSAGE = SYSTEM_PROMPT

# Display chat messages
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])
        
        # Show guardrails check if present
        if "guardrails_check" in message:
            gc = message["guardrails_check"]
            render_guardrails_result(gc["is_safe"], gc["message"], gc["type"])
        
        # Show tool calls if present
        if "tool_calls" in message and message["tool_calls"]:
            for tc in message["tool_calls"]:
                st.markdown(f"""
                <div class="tool-call-box">
                    <div class="tool-call-header">🔧 Tool Call: {tc.get('name', 'unknown')}</div>
                    <div class="tool-call-content">{json.dumps(tc.get('args', {}), indent=2)}</div>
                </div>
                """, unsafe_allow_html=True)
        
        # Show tool results if present
        if "tool_result" in message and message["tool_result"]:
            result_preview = message["tool_result"][:500] + "..." if len(message["tool_result"]) > 500 else message["tool_result"]
            st.markdown(f"""
            <div class="tool-result-box">
                <div class="tool-result-header">📊 Tool Result</div>
                <div class="tool-result-content">{result_preview}</div>
            </div>
            """, unsafe_allow_html=True)

# Chat input
if prompt := st.chat_input(CHAT_PLACEHOLDER):
    # Check input with guardrails
    input_safe = True
    input_message = ""
    
    if st.session_state.enable_guardrails:
        input_safe, input_message, input_detections = check_guardrails(prompt, "input")
        
        if not input_safe and st.session_state.guardrails_mode == "block":
            st.session_state.guardrails_blocks += 1
            st.session_state.messages.append({
                "role": "user",
                "content": prompt,
                "guardrails_check": {"is_safe": False, "message": input_message, "type": "input"}
            })
            with st.chat_message("user"):
                st.markdown(prompt)
                render_guardrails_result(False, input_message, "input")
            
            st.session_state.messages.append({
                "role": "assistant",
                "content": "🚫 Your message was blocked by safety guardrails. Please rephrase your question without sensitive information."
            })
            with st.chat_message("assistant"):
                st.markdown("🚫 Your message was blocked by safety guardrails. Please rephrase your question without sensitive information.")
            st.rerun()
    
    # Add user message
    user_msg = {"role": "user", "content": prompt}
    if st.session_state.enable_guardrails:
        user_msg["guardrails_check"] = {"is_safe": input_safe, "message": input_message, "type": "input"}
    st.session_state.messages.append(user_msg)
    
    with st.chat_message("user"):
        st.markdown(prompt)
        if st.session_state.enable_guardrails:
            render_guardrails_result(input_safe, input_message, "input")
    
    # Build messages for API
    api_messages = [{"role": "system", "content": SYSTEM_MESSAGE}]
    for msg in st.session_state.messages:
        api_messages.append({"role": msg["role"], "content": msg["content"]})
    
    # Get tools in OpenAI format
    tools = format_tools_for_openai(st.session_state.mcp_tools) if st.session_state.mcp_tools else None
    
    # Call LlamaStack
    with st.chat_message("assistant"):
        with st.spinner("🤔 Thinking..."):
            response = chat_completion_openai(api_messages, tools)
        
        if "error" in response:
            st.error(f"Error: {response['error']}")
            st.session_state.messages.append({
                "role": "assistant",
                "content": f"Sorry, I encountered an error: {response['error']}"
            })
        else:
            choice = response.get("choices", [{}])[0]
            message = choice.get("message", {})
            
            # Check for tool calls
            if message.get("tool_calls"):
                tool_calls_info = []
                tool_results = []
                
                for tool_call in message["tool_calls"]:
                    func = tool_call.get("function", {})
                    tool_name = func.get("name", "")
                    try:
                        tool_args = json.loads(func.get("arguments", "{}"))
                    except:
                        tool_args = {}
                    
                    tool_calls_info.append({
                        "name": tool_name,
                        "args": tool_args
                    })
                    
                    st.session_state.tool_calls_count += 1
                    
                    st.markdown(f"""
                    <div class="tool-call-box">
                        <div class="tool-call-header">🔧 Calling: {tool_name}</div>
                        <div class="tool-call-content">{json.dumps(tool_args, indent=2)}</div>
                    </div>
                    """, unsafe_allow_html=True)
                    
                    # Execute tool
                    with st.spinner(f"⚙️ Executing {tool_name}..."):
                        result = execute_tool_call(tool_name, tool_args)
                        tool_results.append(result)
                    
                    result_preview = result[:500] + "..." if len(result) > 500 else result
                    st.markdown(f"""
                    <div class="tool-result-box">
                        <div class="tool-result-header">📊 Result from {tool_name}</div>
                        <div class="tool-result-content">{result_preview}</div>
                    </div>
                    """, unsafe_allow_html=True)
                
                # Add tool call message to history
                st.session_state.messages.append({
                    "role": "assistant",
                    "content": "Using tools to fetch data...",
                    "tool_calls": tool_calls_info,
                    "tool_result": "\n".join(tool_results)
                })
                
                # Now get the final response with tool results
                api_messages.append({
                    "role": "assistant",
                    "content": None,
                    "tool_calls": message["tool_calls"]
                })
                
                for i, tool_call in enumerate(message["tool_calls"]):
                    api_messages.append({
                        "role": "tool",
                        "tool_call_id": tool_call["id"],
                        "content": tool_results[i]
                    })
                
                with st.spinner("✨ Generating response..."):
                    final_response = chat_completion_openai(api_messages, tools)
                
                if "error" not in final_response:
                    final_content = final_response.get("choices", [{}])[0].get("message", {}).get("content", "")
                    
                    # Check output with guardrails
                    output_safe = True
                    output_message = ""
                    if st.session_state.enable_guardrails:
                        output_safe, output_message, output_detections = check_guardrails(final_content, "output")
                        
                        if not output_safe and st.session_state.guardrails_mode == "block":
                            st.session_state.guardrails_blocks += 1
                            final_content = "🚫 The response was blocked by safety guardrails due to potentially sensitive content."
                    
                    st.markdown(final_content)
                    if st.session_state.enable_guardrails:
                        render_guardrails_result(output_safe, output_message, "output")
                    
                    final_msg = {"role": "assistant", "content": final_content}
                    if st.session_state.enable_guardrails:
                        final_msg["guardrails_check"] = {"is_safe": output_safe, "message": output_message, "type": "output"}
                    st.session_state.messages.append(final_msg)
                else:
                    st.error(f"Error generating final response: {final_response['error']}")
            else:
                # No tool calls, just display the response
                content = message.get("content", "")
                
                # Check output with guardrails
                output_safe = True
                output_message = ""
                if st.session_state.enable_guardrails:
                    output_safe, output_message, output_detections = check_guardrails(content, "output")
                    
                    if not output_safe and st.session_state.guardrails_mode == "block":
                        st.session_state.guardrails_blocks += 1
                        content = "🚫 The response was blocked by safety guardrails due to potentially sensitive content."
                
                st.markdown(content)
                if st.session_state.enable_guardrails:
                    render_guardrails_result(output_safe, output_message, "output")
                
                assistant_msg = {"role": "assistant", "content": content}
                if st.session_state.enable_guardrails:
                    assistant_msg["guardrails_check"] = {"is_safe": output_safe, "message": output_message, "type": "output"}
                st.session_state.messages.append(assistant_msg)

# Footer
st.markdown("---")
st.markdown(f"""
<div style="text-align: center; color: #64748b; font-size: 0.8rem;">
    <p>🦙 LlamaStack + 🔧 MCP + 🛡️ Guardrails Demo | Powered by {MODEL_ID}</p>
    <p>AI Safety powered by TrustyAI</p>
</div>
""", unsafe_allow_html=True)
