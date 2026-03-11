"""
MaaS Demo - Model as a Service Web Interface

A Streamlit application for demonstrating MaaS capabilities on OpenShift AI.

Features:
- Chat with models via MaaS API
- Model comparison (same prompt, multiple models)
- Response metrics visualization
- Streaming support

Run with: streamlit run app.py
"""

import streamlit as st
import requests
import json
import time
from typing import Optional, Dict, List, Generator

# Page configuration
st.set_page_config(
    page_title="MaaS Demo",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap');
    
    .stApp {
        font-family: 'Plus Jakarta Sans', sans-serif;
    }
    
    .main-header {
        background: linear-gradient(135deg, #0066cc 0%, #004499 50%, #003366 100%);
        padding: 1.5rem 2rem;
        border-radius: 16px;
        margin-bottom: 1.5rem;
        box-shadow: 0 4px 20px rgba(0, 102, 204, 0.3);
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
    
    .metric-card {
        background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1rem;
        margin: 0.5rem 0;
    }
    
    .metric-label {
        color: #94a3b8;
        font-size: 0.85rem;
        margin-bottom: 0.25rem;
    }
    
    .metric-value {
        color: #f1f5f9;
        font-size: 1.5rem;
        font-weight: 600;
    }
    
    .chat-message {
        padding: 1rem;
        border-radius: 12px;
        margin: 0.5rem 0;
    }
    
    .chat-message.user {
        background: #1e40af;
        margin-left: 20%;
    }
    
    .chat-message.assistant {
        background: #1e293b;
        margin-right: 20%;
    }
    
    .model-badge {
        background: #059669;
        color: white;
        padding: 0.25rem 0.75rem;
        border-radius: 20px;
        font-size: 0.8rem;
        font-weight: 500;
    }
    
    .status-connected {
        color: #10b981;
    }
    
    .status-disconnected {
        color: #ef4444;
    }
</style>
""", unsafe_allow_html=True)


def init_session_state():
    """Initialize session state variables."""
    if "messages" not in st.session_state:
        st.session_state.messages = []
    if "endpoint" not in st.session_state:
        st.session_state.endpoint = ""
    if "token" not in st.session_state:
        st.session_state.token = ""
    if "connected" not in st.session_state:
        st.session_state.connected = False
    if "models" not in st.session_state:
        st.session_state.models = []
    if "last_metrics" not in st.session_state:
        st.session_state.last_metrics = {}


def test_connection(endpoint: str, token: str) -> bool:
    """Test connection to MaaS endpoint."""
    try:
        response = requests.get(
            f"https://{endpoint}/v1/models",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
            verify=False
        )
        return response.status_code == 200
    except Exception:
        return False


def get_models(endpoint: str, token: str) -> List[str]:
    """Get list of available models."""
    try:
        response = requests.get(
            f"https://{endpoint}/v1/models",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
            verify=False
        )
        if response.status_code == 200:
            data = response.json()
            return [m.get("id", m.get("name", "unknown")) for m in data.get("data", [])]
    except Exception:
        pass
    return []


def chat_completion(
    endpoint: str,
    token: str,
    model: str,
    messages: List[Dict],
    temperature: float = 0.7,
    max_tokens: int = 500,
    stream: bool = False
) -> Dict:
    """Send chat completion request."""
    try:
        start_time = time.time()
        
        response = requests.post(
            f"https://{endpoint}/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json"
            },
            json={
                "model": model,
                "messages": messages,
                "temperature": temperature,
                "max_tokens": max_tokens,
                "stream": stream
            },
            timeout=120,
            verify=False,
            stream=stream
        )
        
        end_time = time.time()
        latency = int((end_time - start_time) * 1000)
        
        if stream:
            return {"response": response, "latency": latency}
        else:
            data = response.json()
            data["_latency"] = latency
            return data
            
    except Exception as e:
        return {"error": str(e)}


def stream_response(response) -> Generator[str, None, None]:
    """Stream response content."""
    for line in response.iter_lines():
        if line:
            line = line.decode("utf-8")
            if line.startswith("data: "):
                data = line[6:]
                if data == "[DONE]":
                    break
                try:
                    chunk = json.loads(data)
                    content = chunk.get("choices", [{}])[0].get("delta", {}).get("content", "")
                    if content:
                        yield content
                except json.JSONDecodeError:
                    pass


def render_header():
    """Render the main header."""
    st.markdown("""
    <div class="main-header">
        <h1>🤖 MaaS Demo</h1>
        <p>Model as a Service on Red Hat OpenShift AI</p>
    </div>
    """, unsafe_allow_html=True)


def render_sidebar():
    """Render the sidebar with connection settings."""
    with st.sidebar:
        st.header("🔌 Connection")
        
        # Endpoint input
        endpoint = st.text_input(
            "MaaS Endpoint",
            value=st.session_state.endpoint,
            placeholder="inference-gateway.apps.cluster.example.com",
            help="MaaS API endpoint (without https://)"
        )
        
        # Token input
        token = st.text_input(
            "API Token",
            value=st.session_state.token,
            type="password",
            help="Bearer token for authentication"
        )
        
        # Connect button
        if st.button("Connect", type="primary", use_container_width=True):
            if endpoint and token:
                with st.spinner("Testing connection..."):
                    st.session_state.endpoint = endpoint
                    st.session_state.token = token
                    st.session_state.connected = test_connection(endpoint, token)
                    
                    if st.session_state.connected:
                        st.session_state.models = get_models(endpoint, token)
                        st.success("Connected!")
                    else:
                        st.error("Connection failed")
            else:
                st.warning("Enter endpoint and token")
        
        # Connection status
        if st.session_state.connected:
            st.markdown('<p class="status-connected">✓ Connected</p>', unsafe_allow_html=True)
        else:
            st.markdown('<p class="status-disconnected">✗ Not connected</p>', unsafe_allow_html=True)
        
        st.divider()
        
        # Model selection
        st.header("🎯 Model")
        
        models = st.session_state.models if st.session_state.models else ["demo-model"]
        
        # Allow custom model input
        model_input = st.text_input(
            "Model name",
            value=models[0] if models else "demo-model",
            help="Enter model name or select from detected models"
        )
        
        if len(models) > 1:
            selected_model = st.selectbox(
                "Or select detected model",
                options=models,
                index=0
            )
            model = selected_model
        else:
            model = model_input
        
        st.session_state.current_model = model
        
        st.divider()
        
        # Settings
        st.header("⚙️ Settings")
        
        temperature = st.slider(
            "Temperature",
            min_value=0.0,
            max_value=2.0,
            value=0.7,
            step=0.1,
            help="Higher = more creative, Lower = more focused"
        )
        
        max_tokens = st.slider(
            "Max Tokens",
            min_value=50,
            max_value=2000,
            value=500,
            step=50,
            help="Maximum response length"
        )
        
        streaming = st.checkbox(
            "Enable Streaming",
            value=True,
            help="Stream responses in real-time"
        )
        
        st.session_state.temperature = temperature
        st.session_state.max_tokens = max_tokens
        st.session_state.streaming = streaming
        
        st.divider()
        
        # Clear chat button
        if st.button("🗑️ Clear Chat", use_container_width=True):
            st.session_state.messages = []
            st.rerun()


def render_chat_tab():
    """Render the chat interface tab."""
    st.subheader(f"💬 Chat with {st.session_state.get('current_model', 'Model')}")
    
    # Display chat messages
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])
            if "metrics" in message:
                metrics = message["metrics"]
                cols = st.columns(3)
                with cols[0]:
                    st.caption(f"⏱️ {metrics.get('latency', 'N/A')}ms")
                with cols[1]:
                    st.caption(f"📊 {metrics.get('tokens', 'N/A')} tokens")
    
    # Chat input
    if prompt := st.chat_input("Type your message..."):
        if not st.session_state.connected:
            st.warning("Please connect to MaaS endpoint first")
            return
        
        # Add user message
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)
        
        # Get assistant response
        with st.chat_message("assistant"):
            messages = [{"role": m["role"], "content": m["content"]} for m in st.session_state.messages]
            
            if st.session_state.streaming:
                result = chat_completion(
                    st.session_state.endpoint,
                    st.session_state.token,
                    st.session_state.current_model,
                    messages,
                    st.session_state.temperature,
                    st.session_state.max_tokens,
                    stream=True
                )
                
                if "error" in result:
                    st.error(f"Error: {result['error']}")
                else:
                    response_placeholder = st.empty()
                    full_response = ""
                    
                    for chunk in stream_response(result["response"]):
                        full_response += chunk
                        response_placeholder.markdown(full_response + "▌")
                    
                    response_placeholder.markdown(full_response)
                    
                    st.session_state.messages.append({
                        "role": "assistant",
                        "content": full_response,
                        "metrics": {"latency": result["latency"]}
                    })
            else:
                with st.spinner("Thinking..."):
                    result = chat_completion(
                        st.session_state.endpoint,
                        st.session_state.token,
                        st.session_state.current_model,
                        messages,
                        st.session_state.temperature,
                        st.session_state.max_tokens,
                        stream=False
                    )
                
                if "error" in result:
                    st.error(f"Error: {result['error']}")
                else:
                    content = result.get("choices", [{}])[0].get("message", {}).get("content", "No response")
                    usage = result.get("usage", {})
                    latency = result.get("_latency", 0)
                    
                    st.markdown(content)
                    
                    st.session_state.messages.append({
                        "role": "assistant",
                        "content": content,
                        "metrics": {
                            "latency": latency,
                            "tokens": usage.get("total_tokens", "N/A")
                        }
                    })
                    
                    st.session_state.last_metrics = {
                        "latency": latency,
                        "usage": usage
                    }


def render_comparison_tab():
    """Render the model comparison tab."""
    st.subheader("⚖️ Model Comparison")
    
    if not st.session_state.connected:
        st.warning("Please connect to MaaS endpoint first")
        return
    
    col1, col2 = st.columns(2)
    
    with col1:
        model1 = st.text_input("Model 1", value=st.session_state.get("current_model", "demo-model"))
    
    with col2:
        model2 = st.text_input("Model 2", value="")
    
    prompt = st.text_area(
        "Prompt to send to both models",
        value="Explain what Red Hat OpenShift AI is in 2-3 sentences.",
        height=100
    )
    
    if st.button("Compare", type="primary", disabled=not model2):
        if not model2:
            st.warning("Enter a second model name")
            return
        
        messages = [{"role": "user", "content": prompt}]
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown(f"**{model1}**")
            with st.spinner("Querying..."):
                result1 = chat_completion(
                    st.session_state.endpoint,
                    st.session_state.token,
                    model1,
                    messages,
                    st.session_state.temperature,
                    st.session_state.max_tokens,
                    stream=False
                )
            
            if "error" in result1:
                st.error(result1["error"])
            else:
                content = result1.get("choices", [{}])[0].get("message", {}).get("content", "No response")
                st.markdown(content)
                st.caption(f"⏱️ {result1.get('_latency', 'N/A')}ms | 📊 {result1.get('usage', {}).get('total_tokens', 'N/A')} tokens")
        
        with col2:
            st.markdown(f"**{model2}**")
            with st.spinner("Querying..."):
                result2 = chat_completion(
                    st.session_state.endpoint,
                    st.session_state.token,
                    model2,
                    messages,
                    st.session_state.temperature,
                    st.session_state.max_tokens,
                    stream=False
                )
            
            if "error" in result2:
                st.error(result2["error"])
            else:
                content = result2.get("choices", [{}])[0].get("message", {}).get("content", "No response")
                st.markdown(content)
                st.caption(f"⏱️ {result2.get('_latency', 'N/A')}ms | 📊 {result2.get('usage', {}).get('total_tokens', 'N/A')} tokens")


def render_metrics_tab():
    """Render the metrics tab."""
    st.subheader("📊 Response Metrics")
    
    metrics = st.session_state.get("last_metrics", {})
    
    if not metrics:
        st.info("Chat with a model to see metrics")
        return
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric("Response Latency", f"{metrics.get('latency', 'N/A')}ms")
    
    usage = metrics.get("usage", {})
    
    with col2:
        st.metric("Prompt Tokens", usage.get("prompt_tokens", "N/A"))
    
    with col3:
        st.metric("Completion Tokens", usage.get("completion_tokens", "N/A"))
    
    st.divider()
    
    st.markdown("**Token Usage Breakdown**")
    
    if usage:
        data = {
            "Type": ["Prompt", "Completion", "Total"],
            "Tokens": [
                usage.get("prompt_tokens", 0),
                usage.get("completion_tokens", 0),
                usage.get("total_tokens", 0)
            ]
        }
        st.bar_chart(data, x="Type", y="Tokens")


def main():
    """Main application entry point."""
    # Suppress SSL warnings
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
    init_session_state()
    render_header()
    render_sidebar()
    
    # Main content tabs
    tab1, tab2, tab3 = st.tabs(["💬 Chat", "⚖️ Compare Models", "📊 Metrics"])
    
    with tab1:
        render_chat_tab()
    
    with tab2:
        render_comparison_tab()
    
    with tab3:
        render_metrics_tab()


if __name__ == "__main__":
    main()
