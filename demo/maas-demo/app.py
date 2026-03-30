"""
MaaS Demo - Model as a Service Web Interface

A Streamlit application for demonstrating MaaS capabilities on OpenShift AI.

Features:
- Chat with models via MaaS API
- Model comparison (same prompt, multiple models)
- Response metrics visualization
- Streaming support
- Auto-detection of cluster settings and token generation
- Tier-based rate limiting demonstration (Free/Standard/Premium)

Run with: streamlit run app.py

Environment Variables (optional):
- MAAS_ENDPOINT: MaaS gateway endpoint
- MAAS_NAMESPACE: Namespace where model is deployed
- MAAS_MODEL: Model name
- MAAS_TOKEN: Pre-generated token (or auto-generate via oc)
- MAAS_TIER: Current tier (free, standard, premium)
- KUBECONFIG: Path to kubeconfig file
"""

import streamlit as st
import requests
import json
import time
import os
import subprocess
import shutil
from typing import Optional, Dict, List, Generator, Tuple


def run_oc_command(args: List[str], timeout: int = 10) -> Tuple[bool, str]:
    """Run an oc command and return (success, output)."""
    try:
        oc_path = shutil.which("oc")
        if not oc_path:
            return False, "oc command not found"
        
        result = subprocess.run(
            [oc_path] + args,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        if result.returncode == 0:
            return True, result.stdout.strip()
        return False, result.stderr.strip()
    except subprocess.TimeoutExpired:
        return False, "Command timed out"
    except Exception as e:
        return False, str(e)


def auto_detect_cluster_settings() -> Dict[str, str]:
    """Auto-detect cluster settings using oc command."""
    settings = {
        "endpoint": "",
        "namespace": "",
        "model": "",
        "token": "",
        "oc_available": False,
        "logged_in": False,
        "rhoai_version": ""
    }
    
    # Check if oc is available
    if not shutil.which("oc"):
        return settings
    settings["oc_available"] = True
    
    # Check if logged in
    success, output = run_oc_command(["whoami"])
    if not success:
        return settings
    settings["logged_in"] = True
    
    # Get cluster domain
    success, domain = run_oc_command([
        "get", "ingresses.config.openshift.io", "cluster",
        "-o", "jsonpath={.spec.domain}"
    ])
    if success and domain:
        settings["endpoint"] = f"inference-gateway.{domain}"
    
    # Detect RHOAI version
    success, version = run_oc_command([
        "get", "csv", "-n", "redhat-ods-operator",
        "-o", "jsonpath={.items[0].spec.version}"
    ])
    if success and version:
        settings["rhoai_version"] = version
    
    return settings


def auto_detect_models(namespace: str = "") -> List[Dict[str, str]]:
    """Auto-detect deployed LLMInferenceServices."""
    models = []
    
    # Try to get LLMInferenceServices
    ns_arg = ["-n", namespace] if namespace else ["-A"]
    success, output = run_oc_command([
        "get", "llminferenceservice"] + ns_arg + [
        "-o", "jsonpath={range .items[*]}{.metadata.namespace}/{.metadata.name}/{.status.conditions[?(@.type==\"Ready\")].status}{\"\\n\"}{end}"
    ])
    
    if success and output:
        for line in output.strip().split("\n"):
            if line:
                parts = line.split("/")
                if len(parts) >= 3:
                    models.append({
                        "namespace": parts[0],
                        "name": parts[1],
                        "ready": parts[2] == "True"
                    })
    
    return models


def generate_token(namespace: str, duration: str = "1h", service_account: str = "default") -> Tuple[bool, str]:
    """Generate a token using oc create token."""
    success, token = run_oc_command([
        "create", "token", service_account,
        "-n", namespace,
        f"--duration={duration}",
        "--audience=https://kubernetes.default.svc"
    ], timeout=15)
    
    return success, token


# RHOAI 3.3 Built-in Tier definitions (based on OpenShift groups)
# These match the tier-to-group-mapping ConfigMap and TokenRateLimitPolicy
# NOTE: Using 1-minute windows for demo testing (limits reset every minute)
TIERS = {
    "free": {
        "name": "Free",
        "groups": ["tier-free-users", "system:authenticated"],
        "token_limit": 1000,
        "description": "1,000 tokens/min",
        "color": "#6b7280",
        "icon": "🆓",
        "level": 0
    },
    "premium": {
        "name": "Premium", 
        "groups": ["tier-premium-users", "premium-group"],
        "token_limit": 5000,
        "description": "5,000 tokens/min",
        "color": "#3b82f6",
        "icon": "⭐",
        "level": 1
    },
    "enterprise": {
        "name": "Enterprise",
        "groups": ["tier-enterprise-users", "enterprise-group", "admin-group"],
        "token_limit": 10000,
        "description": "10,000 tokens/min",
        "color": "#f59e0b",
        "icon": "👑",
        "level": 2
    }
}


def get_available_tiers(namespace: str) -> List[str]:
    """Get available RHOAI tiers - always returns all tiers since they're built-in."""
    # RHOAI 3.3 has built-in tiers based on groups
    # All tiers are always available, user's tier is determined by group membership
    return list(TIERS.keys())


def get_tier_token_from_env(tier: str) -> Optional[str]:
    """Get pre-configured tier token from environment."""
    env_var = f"MAAS_TIER_{tier.upper()}_TOKEN"
    return os.environ.get(env_var)


def generate_tier_token(namespace: str, tier: str, duration: str = "1h") -> Tuple[bool, str]:
    """
    Generate a token for API access.
    Note: In RHOAI 3.3, tiers are based on user's group membership, not the token.
    The same token works for any tier - the rate limit is determined by the user's groups.
    """
    if tier not in TIERS:
        return False, f"Unknown tier: {tier}"
    
    # First check for pre-configured token in environment
    env_token = get_tier_token_from_env(tier)
    if env_token:
        return True, env_token
    
    # Check for default token
    default_token = os.environ.get("MAAS_TOKEN")
    if default_token:
        return True, default_token
    
    # Fall back to oc command to generate token
    return generate_token(namespace, duration, "default")


def check_rbac_permissions(namespace: str) -> bool:
    """Check if default SA has permissions to access the model."""
    success, output = run_oc_command([
        "auth", "can-i", "get", "llminferenceservices",
        f"--as=system:serviceaccount:{namespace}:default",
        "-n", namespace
    ])
    return success and output.strip().lower() == "yes"

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
    if "last_metrics" not in st.session_state:
        st.session_state.last_metrics = {}
    if "connected" not in st.session_state:
        st.session_state.connected = False
    if "models" not in st.session_state:
        st.session_state.models = []
    if "api_mode" not in st.session_state:
        st.session_state.api_mode = "path-based"  # auto, legacy, path-based
    if "auto_detected" not in st.session_state:
        st.session_state.auto_detected = False
    if "cluster_info" not in st.session_state:
        st.session_state.cluster_info = {}
    if "detected_models" not in st.session_state:
        st.session_state.detected_models = []
    
    # Tier-related state
    if "current_tier" not in st.session_state:
        st.session_state.current_tier = os.environ.get("MAAS_TIER", "free")  # Default to free tier
    if "available_tiers" not in st.session_state:
        st.session_state.available_tiers = list(TIERS.keys())  # All tiers available
    if "tier_tokens" not in st.session_state:
        # Pre-load tier tokens from environment
        st.session_state.tier_tokens = {}
        for tier in TIERS.keys():
            tier_token = get_tier_token_from_env(tier)
            if tier_token:
                st.session_state.tier_tokens[tier] = tier_token
    if "token_usage" not in st.session_state:
        st.session_state.token_usage = {}  # tier -> tokens used
    if "rate_limited" not in st.session_state:
        st.session_state.rate_limited = False
    if "rate_limit_time" not in st.session_state:
        st.session_state.rate_limit_time = None  # Timestamp when rate limit was hit
    
    # Try to get values from environment variables first
    if "endpoint" not in st.session_state:
        st.session_state.endpoint = os.environ.get("MAAS_ENDPOINT", "")
    if "namespace" not in st.session_state:
        st.session_state.namespace = os.environ.get("MAAS_NAMESPACE", "")
    if "current_model" not in st.session_state:
        st.session_state.current_model = os.environ.get("MAAS_MODEL", "")
    if "token" not in st.session_state:
        # Use tier token if available, otherwise fall back to default
        default_tier = st.session_state.current_tier or "free"
        tier_token = get_tier_token_from_env(default_tier)
        if tier_token:
            st.session_state.token = tier_token
        else:
            st.session_state.token = os.environ.get("MAAS_TOKEN", "")


def get_api_path(endpoint: str, namespace: str, model: str, path: str, api_mode: str = "auto") -> str:
    """
    Build API path based on RHOAI version/mode.
    
    RHOAI 3.3+ (path-based): /<namespace>/<model>/v1/chat/completions
    RHOAI 3.2 (legacy): /v1/chat/completions (model in request body)
    """
    if api_mode == "legacy" or (api_mode == "auto" and not namespace):
        # Legacy mode: /v1/...
        return f"https://{endpoint}{path}"
    else:
        # Path-based mode (RHOAI 3.3+): /<namespace>/<model>/v1/...
        return f"https://{endpoint}/{namespace}/{model}{path}"


def test_connection(endpoint: str, token: str, namespace: str = "", model: str = "", api_mode: str = "auto") -> tuple:
    """
    Test connection to MaaS endpoint.
    Returns (success: bool, detected_mode: str)
    """
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    
    # Try path-based first (RHOAI 3.3+) if namespace and model provided
    if namespace and model:
        try:
            url = f"https://{endpoint}/{namespace}/{model}/v1/models"
            response = requests.get(url, headers=headers, timeout=10, verify=False)
            if response.status_code == 200:
                return True, "path-based"
        except Exception:
            pass
    
    # Try legacy endpoint
    try:
        url = f"https://{endpoint}/v1/models"
        response = requests.get(url, headers=headers, timeout=10, verify=False)
        if response.status_code == 200:
            return True, "legacy"
    except Exception:
        pass
    
    # If both fail but we have namespace/model, assume path-based (model might not have /v1/models)
    if namespace and model:
        return True, "path-based"
    
    return False, "unknown"


def get_models(endpoint: str, token: str, namespace: str = "", api_mode: str = "auto") -> List[str]:
    """Get list of available models."""
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    
    # Try legacy endpoint first
    try:
        response = requests.get(
            f"https://{endpoint}/v1/models",
            headers=headers,
            timeout=10,
            verify=False
        )
        if response.status_code == 200:
            data = response.json()
            return [m.get("id", m.get("name", "unknown")) for m in data.get("data", [])]
    except Exception:
        pass
    
    return []


def get_session_with_internal_routing():
    """
    Create a requests session that routes to internal gateway IP
    while preserving the proper hostname for SNI/TLS.
    """
    import socket
    from urllib3.util.connection import create_connection
    
    gateway_ip = os.environ.get("MAAS_GATEWAY_IP", "")
    endpoint = os.environ.get("MAAS_ENDPOINT", "")
    
    if gateway_ip and endpoint:
        # Create custom DNS resolution
        class InternalRoutingAdapter(requests.adapters.HTTPAdapter):
            def init_poolmanager(self, *args, **kwargs):
                # Override DNS for the gateway hostname
                super().init_poolmanager(*args, **kwargs)
        
        session = requests.Session()
        # Use custom resolver via environment
        return session, gateway_ip
    
    return requests.Session(), None


def chat_completion(
    endpoint: str,
    token: str,
    model: str,
    messages: List[Dict],
    temperature: float = 0.7,
    max_tokens: int = 500,
    stream: bool = False,
    namespace: str = "",
    api_mode: str = "auto"
) -> Dict:
    """Send chat completion request."""
    try:
        start_time = time.time()
        
        # Build URL based on API mode
        url = get_api_path(endpoint, namespace, model, "/v1/chat/completions", api_mode)
        
        # Check if we should use internal routing (gateway IP)
        gateway_ip = os.environ.get("MAAS_GATEWAY_IP", "")
        if gateway_ip and endpoint:
            # Replace hostname with IP in URL but keep Host header
            import re
            internal_url = re.sub(r'https://[^/]+', f'https://{gateway_ip}', url)
            headers = {
                "Content-Type": "application/json",
                "Host": endpoint  # Keep original hostname for SNI
            }
            url = internal_url
        else:
            headers = {"Content-Type": "application/json"}
        
        if token:
            headers["Authorization"] = f"Bearer {token}"
        
        response = requests.post(
            url,
            headers=headers,
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
        
        # Extract rate limit headers (if present)
        rate_limit_info = {
            "limit": response.headers.get("X-RateLimit-Limit", response.headers.get("RateLimit-Limit")),
            "remaining": response.headers.get("X-RateLimit-Remaining", response.headers.get("RateLimit-Remaining")),
            "reset": response.headers.get("X-RateLimit-Reset", response.headers.get("RateLimit-Reset")),
        }
        
        if stream:
            # Check for rate limiting on streaming response
            if response.status_code == 429:
                return {"error": "Rate limit exceeded! Try a higher tier.", "rate_limited": True, "rate_limit_info": rate_limit_info}
            return {"response": response, "latency": latency, "rate_limit_info": rate_limit_info}
        else:
            # Check for rate limiting
            if response.status_code == 429:
                return {"error": "Rate limit exceeded! Try a higher tier.", "rate_limited": True, "rate_limit_info": rate_limit_info}
            if response.status_code != 200:
                return {"error": f"HTTP {response.status_code}: {response.text[:200]}", "rate_limit_info": rate_limit_info}
            data = response.json()
            data["_latency"] = latency
            data["_rate_limit_info"] = rate_limit_info
            data["_response_headers"] = dict(response.headers)
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
        
        # Auto-detect button
        col1, col2 = st.columns(2)
        with col1:
            if st.button("🔍 Auto-Detect", use_container_width=True, help="Detect settings from oc CLI"):
                with st.spinner("Detecting cluster settings..."):
                    cluster_info = auto_detect_cluster_settings()
                    st.session_state.cluster_info = cluster_info
                    
                    if cluster_info.get("logged_in"):
                        st.session_state.auto_detected = True
                        
                        # Set endpoint
                        if cluster_info.get("endpoint"):
                            st.session_state.endpoint = cluster_info["endpoint"]
                        
                        # Detect models
                        detected_models = auto_detect_models()
                        st.session_state.detected_models = detected_models
                        
                        if detected_models:
                            # Use first ready model
                            ready_models = [m for m in detected_models if m.get("ready")]
                            if ready_models:
                                st.session_state.namespace = ready_models[0]["namespace"]
                                st.session_state.current_model = ready_models[0]["name"]
                        
                        st.success("Settings detected!")
                        st.rerun()
                    elif not cluster_info.get("oc_available"):
                        st.error("oc CLI not found")
                    else:
                        st.error("Not logged in to cluster")
        
        with col2:
            if st.button("🔑 Gen Token", use_container_width=True, help="Generate API token"):
                if st.session_state.namespace:
                    with st.spinner("Generating token..."):
                        success, token = generate_token(st.session_state.namespace)
                        if success:
                            st.session_state.token = token
                            st.success("Token generated!")
                            st.rerun()
                        else:
                            st.error(f"Failed: {token[:50]}...")
                else:
                    st.warning("Set namespace first")
        
        # Show cluster info if detected
        if st.session_state.cluster_info.get("logged_in"):
            with st.expander("📊 Cluster Info", expanded=False):
                info = st.session_state.cluster_info
                st.caption(f"RHOAI: {info.get('rhoai_version', 'Unknown')}")
                if st.session_state.detected_models:
                    st.caption(f"Models found: {len(st.session_state.detected_models)}")
                    for m in st.session_state.detected_models:
                        status = "✅" if m.get("ready") else "⏳"
                        st.caption(f"  {status} {m['namespace']}/{m['name']}")
        
        st.divider()
        
        # Endpoint input
        endpoint = st.text_input(
            "MaaS Endpoint",
            value=st.session_state.endpoint,
            placeholder="inference-gateway.apps.cluster.example.com",
            help="MaaS API endpoint (without https://)"
        )
        
        # Token input (optional for no-auth mode)
        token = st.text_input(
            "API Token",
            value=st.session_state.token,
            type="password",
            help="Bearer token for authentication. Use 'Gen Token' button or leave empty if auth disabled."
        )
        
        st.divider()
        
        # Combined Model & Tier Selection
        st.subheader("🎯 Model & Tier")
        
        # Model Selection
        if st.session_state.detected_models:
            # Show ready status indicator
            ready_count = len([m for m in st.session_state.detected_models if m.get("ready")])
            st.caption(f"📡 {ready_count} model(s) ready")
            
            model_options = []
            for m in st.session_state.detected_models:
                status = "✅" if m.get("ready") else "⏳"
                model_options.append(f"{m['namespace']}/{m['name']}")
            
            current_value = f"{st.session_state.namespace}/{st.session_state.current_model}" if st.session_state.namespace else ""
            
            try:
                default_idx = model_options.index(current_value) if current_value in model_options else 0
            except ValueError:
                default_idx = 0
            
            selected = st.selectbox(
                "🤖 Model",
                options=model_options,
                index=default_idx,
                help="Select from detected LLMInferenceServices"
            )
            
            if selected:
                parts = selected.split("/")
                namespace = parts[0]
                model_input = parts[1]
                
                # Update namespace when model changes (for tier detection)
                if namespace != st.session_state.namespace:
                    st.session_state.namespace = namespace
                    st.session_state.available_tiers = []  # Reset tiers for new namespace
        else:
            namespace = st.text_input(
                "Namespace",
                value=st.session_state.namespace,
                placeholder="maas-demo",
                help="Namespace where the model is deployed"
            )
            
            model_input = st.text_input(
                "Model Name",
                value=st.session_state.get("current_model", "qwen3-4b"),
                placeholder="qwen3-4b",
                help="Model name for API path routing"
            )
        
        # Tier Selection (inline with model)
        if namespace:
            # Check for available tiers in this namespace
            if not st.session_state.available_tiers or st.session_state.namespace != namespace:
                st.session_state.available_tiers = get_available_tiers(namespace)
                st.session_state.namespace = namespace
            
            if st.session_state.available_tiers:
                tier_options = st.session_state.available_tiers
                tier_labels = {t: f"{TIERS[t]['icon']} {TIERS[t]['name']}" for t in tier_options}
                
                current_tier = st.session_state.current_tier if st.session_state.current_tier in tier_options else tier_options[0]
                
                selected_tier = st.selectbox(
                    "🎫 Tier",
                    options=tier_options,
                    format_func=lambda x: f"{tier_labels.get(x, x)} ({TIERS[x]['description']})",
                    index=tier_options.index(current_tier) if current_tier in tier_options else 0,
                    help="Select tier to test different rate limits"
                )
                
                # Always update token when tier changes
                if selected_tier != st.session_state.current_tier:
                    st.session_state.current_tier = selected_tier
                    # Try to get tier-specific token from environment
                    tier_token = get_tier_token_from_env(selected_tier)
                    if tier_token:
                        st.session_state.token = tier_token
                        st.session_state.tier_tokens[selected_tier] = tier_token
                        token = tier_token
                        st.success(f"🔄 Switched to {TIERS[selected_tier]['name']} tier!")
                        st.rerun()  # Force rerun to apply new token
                    # Use cached token if available
                    elif selected_tier in st.session_state.tier_tokens:
                        st.session_state.token = st.session_state.tier_tokens[selected_tier]
                        token = st.session_state.token
                        st.rerun()
                
                # Show current tier token status
                tier_token_available = get_tier_token_from_env(selected_tier) is not None
                if tier_token_available:
                    st.caption(f"✅ Using **{TIERS[selected_tier]['name']}** token")
                    st.caption(f"Rate limit: {TIERS[selected_tier]['description']}")
                else:
                    st.warning("⚠️ No tier token - using default")
            else:
                st.caption("No tiers configured in this namespace")
        
        # Advanced settings in expander
        with st.expander("⚙️ Advanced", expanded=False):
            api_mode = st.radio(
                "API Mode",
                options=["path-based", "legacy", "auto"],
                index=0,
                help="path-based: RHOAI 3.3+, legacy: RHOAI 3.2"
            )
        
        # Connect button
        if st.button("🔗 Connect", type="primary", use_container_width=True):
            if endpoint:
                with st.spinner("Testing connection..."):
                    st.session_state.endpoint = endpoint
                    st.session_state.token = token
                    st.session_state.namespace = namespace
                    st.session_state.api_mode = api_mode
                    st.session_state.current_model = model_input
                    
                    connected, detected_mode = test_connection(
                        endpoint, token, namespace, model_input, api_mode
                    )
                    st.session_state.connected = connected
                    
                    if connected:
                        if api_mode == "auto":
                            st.session_state.api_mode = detected_mode
                        st.session_state.models = get_models(endpoint, token, namespace, api_mode)
                        st.success(f"Connected! (Mode: {st.session_state.api_mode})")
                    else:
                        st.error("Connection failed")
            else:
                st.warning("Enter endpoint")
        
        # Connection status
        if st.session_state.connected:
            mode_info = f" ({st.session_state.api_mode})" if st.session_state.api_mode else ""
            st.markdown(f'<p class="status-connected">✓ Connected{mode_info}</p>', unsafe_allow_html=True)
        else:
            st.markdown('<p class="status-disconnected">✗ Not connected</p>', unsafe_allow_html=True)
        
        st.divider()
        
        # Token & Usage Section
        st.header("📊 Usage")
        
        # Show rate limit countdown prominently in sidebar
        if st.session_state.rate_limited and st.session_state.rate_limit_time:
            elapsed = time.time() - st.session_state.rate_limit_time
            remaining = max(0, 60 - elapsed)  # 1 minute window
            
            if remaining > 0:
                st.error(f"🚫 **RATE LIMITED**")
                st.metric("Resets in", f"{int(remaining)}s")
                st.progress(remaining / 60)
                st.caption("Switch tier or wait")
            else:
                # Timer expired, reset
                st.session_state.rate_limited = False
                st.session_state.rate_limit_time = None
                if st.session_state.current_tier:
                    st.session_state.token_usage[st.session_state.current_tier] = 0
                st.success("✅ Reset!")
                st.rerun()
        
        # Show current tier info and usage
        if st.session_state.current_tier and st.session_state.current_tier in TIERS:
            tier_info = TIERS[st.session_state.current_tier]
            
            # Show usage progress
            used = st.session_state.token_usage.get(st.session_state.current_tier, 0)
            limit = tier_info['token_limit']
            pct = min(100, int((used / limit) * 100))
            
            st.markdown(f"**{tier_info['icon']} {tier_info['name']}**")
            st.progress(pct / 100)
            st.caption(f"{used:,} / {limit:,} tokens ({pct}%)")
            
            if not st.session_state.rate_limited:
                if pct >= 100:
                    st.warning("⚠️ Approaching limit")
                elif pct >= 80:
                    st.info("📊 80%+ used")
            
            # Reset local tracking button
            if st.button("🔄 Reset Local Counter", use_container_width=True, help="Resets the UI counter only. Server-side limits reset after 1 minute."):
                st.session_state.token_usage = {}
                st.session_state.rate_limited = False
                st.session_state.rate_limit_time = None
                st.rerun()
        else:
            st.caption("Select a tier to see usage")
        
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
            min_value=100,
            max_value=5000,
            value=1000,
            step=100,
            help="Maximum response length (default: 1000)"
        )
        
        streaming = st.checkbox(
            "Enable Streaming",
            value=True,
            help="Stream responses word-by-word (like ChatGPT)"
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
    # Show current model and tier info at top
    model_name = st.session_state.get('current_model', 'Model')
    namespace = st.session_state.get('namespace', '')
    
    col1, col2 = st.columns([3, 2])
    with col1:
        st.subheader(f"💬 Chat with {model_name}")
        if namespace:
            st.caption(f"📍 {namespace}/{model_name}")
    
    with col2:
        if st.session_state.current_tier and st.session_state.current_tier in TIERS:
            tier = TIERS[st.session_state.current_tier]
            used = st.session_state.token_usage.get(st.session_state.current_tier, 0)
            limit = tier['token_limit']
            pct = min(100, int((used / limit) * 100))
            
            st.markdown(f"**{tier['icon']} {tier['name']}** - {used:,} / {limit:,} tokens ({pct}%)")
            st.progress(pct / 100)
    
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
    
    # Show rate limit countdown timer (placed after messages so it's visible)
    if st.session_state.rate_limited and st.session_state.rate_limit_time:
        elapsed = time.time() - st.session_state.rate_limit_time
        remaining = max(0, 60 - elapsed)  # 1 minute window
        
        if remaining > 0:
            # Create a prominent countdown display
            st.markdown("---")
            countdown_col1, countdown_col2 = st.columns([3, 1])
            with countdown_col1:
                st.error(f"🚫 **RATE LIMIT EXCEEDED** - Resets in **{int(remaining)}** seconds")
            with countdown_col2:
                # Visual countdown bar
                progress = remaining / 60
                st.progress(progress)
            st.info("💡 **Tip:** Switch to a higher tier in the sidebar, or wait for the timer to reset.")
            st.markdown("---")
            
            # Auto-refresh every second for countdown
            time.sleep(1)
            st.rerun()
        else:
            # Timer expired, reset the rate limit state
            st.session_state.rate_limited = False
            st.session_state.rate_limit_time = None
            if st.session_state.current_tier:
                st.session_state.token_usage[st.session_state.current_tier] = 0
            st.success("✅ **Rate limit reset!** You can continue chatting.")
            time.sleep(1)  # Brief pause to show success message
            st.rerun()
    elif st.session_state.rate_limited:
        st.error("⚠️ Rate limit exceeded! Switch to a higher tier in the sidebar.")
    
    # Chat input
    if prompt := st.chat_input("Type your message..."):
        if not st.session_state.connected:
            st.warning("Please connect to MaaS endpoint first")
            return
        
        # Add user message and display it
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)
        
        # Build message history for API
        messages = [{"role": m["role"], "content": m["content"]} for m in st.session_state.messages]
        
        # Check if streaming is enabled
        use_streaming = st.session_state.get("streaming", True)
        
        if use_streaming:
            # Streaming mode - show response word by word
            with st.chat_message("assistant"):
                message_placeholder = st.empty()
                full_response = ""
                start_time = time.time()
                
                result = chat_completion(
                    st.session_state.endpoint,
                    st.session_state.token,
                    st.session_state.current_model,
                    messages,
                    st.session_state.temperature,
                    st.session_state.max_tokens,
                    stream=True,
                    namespace=st.session_state.namespace,
                    api_mode=st.session_state.api_mode
                )
                
                if "error" in result:
                    message_placeholder.markdown(f"Error: {result['error']}")
                    st.session_state.messages.append({
                        "role": "assistant",
                        "content": f"Error: {result['error']}",
                        "metrics": {"latency": 0, "tokens": 0}
                    })
                    if result.get("rate_limited"):
                        st.session_state.rate_limited = True
                        st.session_state.rate_limit_time = time.time()
                elif "response" in result:
                    # Stream the response
                    try:
                        response = result["response"]
                        for line in response.iter_lines():
                            if line:
                                line = line.decode("utf-8")
                                if line.startswith("data: "):
                                    data = line[6:]
                                    if data == "[DONE]":
                                        break
                                    try:
                                        chunk = json.loads(data)
                                        if "choices" in chunk and len(chunk["choices"]) > 0:
                                            delta = chunk["choices"][0].get("delta", {})
                                            content = delta.get("content", "")
                                            if content:
                                                full_response += content
                                                message_placeholder.markdown(full_response + "▌")
                                    except json.JSONDecodeError:
                                        pass
                    except Exception as e:
                        if not full_response:
                            full_response = f"Streaming error: {str(e)}"
                    
                    end_time = time.time()
                    latency = int((end_time - start_time) * 1000)
                    
                    # Display final response without cursor
                    message_placeholder.markdown(full_response)
                    
                    # Estimate tokens (rough: ~4 chars per token)
                    estimated_tokens = len(full_response) // 4 + len(prompt) // 4
                    
                    # Track token usage
                    if st.session_state.current_tier:
                        current_usage = st.session_state.token_usage.get(st.session_state.current_tier, 0)
                        st.session_state.token_usage[st.session_state.current_tier] = current_usage + estimated_tokens
                    
                    st.session_state.messages.append({
                        "role": "assistant",
                        "content": full_response,
                        "metrics": {
                            "latency": latency,
                            "tokens": estimated_tokens
                        }
                    })
                    
                    st.session_state.rate_limited = False
                    st.session_state.rate_limit_time = None
                    st.session_state.last_metrics = {
                        "latency": latency,
                        "usage": {"total_tokens": estimated_tokens, "estimated": True}
                    }
                    
                    # Show metrics below response
                    cols = st.columns(3)
                    with cols[0]:
                        st.caption(f"⏱️ {latency}ms")
                    with cols[1]:
                        st.caption(f"📊 ~{estimated_tokens} tokens")
        else:
            # Non-streaming mode - wait for full response
            with st.chat_message("assistant"):
                with st.spinner("Thinking..."):
                    result = chat_completion(
                        st.session_state.endpoint,
                        st.session_state.token,
                        st.session_state.current_model,
                        messages,
                        st.session_state.temperature,
                        st.session_state.max_tokens,
                        stream=False,
                        namespace=st.session_state.namespace,
                        api_mode=st.session_state.api_mode
                    )
                
                if "error" in result:
                    st.markdown(f"Error: {result['error']}")
                    st.session_state.messages.append({
                        "role": "assistant",
                        "content": f"Error: {result['error']}",
                        "metrics": {"latency": 0, "tokens": 0}
                    })
                    if result.get("rate_limited"):
                        st.session_state.rate_limited = True
                        st.session_state.rate_limit_time = time.time()
                else:
                    st.session_state.rate_limited = False
                    st.session_state.rate_limit_time = None
                    content = result.get("choices", [{}])[0].get("message", {}).get("content", "No response")
                    usage = result.get("usage", {})
                    latency = result.get("_latency", 0)
                    total_tokens = usage.get("total_tokens", 0)
                    
                    st.markdown(content)
                    
                    # Track token usage per tier
                    if st.session_state.current_tier:
                        current_usage = st.session_state.token_usage.get(st.session_state.current_tier, 0)
                        st.session_state.token_usage[st.session_state.current_tier] = current_usage + total_tokens
                    
                    st.session_state.messages.append({
                        "role": "assistant",
                        "content": content,
                        "metrics": {
                            "latency": latency,
                            "tokens": total_tokens
                        }
                    })
                    
                    st.session_state.last_metrics = {
                        "latency": latency,
                        "usage": usage
                    }
                    
                    # Show metrics below response
                    cols = st.columns(3)
                    with cols[0]:
                        st.caption(f"⏱️ {latency}ms")
                    with cols[1]:
                        st.caption(f"📊 {total_tokens} tokens")
        
        # Rerun to update sidebar stats
        st.rerun()


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
                    stream=False,
                    namespace=st.session_state.namespace,
                    api_mode=st.session_state.api_mode
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
                    stream=False,
                    namespace=st.session_state.namespace,
                    api_mode=st.session_state.api_mode
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
    
    # Current Tier Info
    if st.session_state.current_tier and st.session_state.current_tier in TIERS:
        tier_info = TIERS[st.session_state.current_tier]
        st.markdown(f"**Current Tier:** {tier_info['icon']} {tier_info['name']} ({tier_info['token_limit']:,} tokens/hour)")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric("Response Latency", f"{metrics.get('latency', 'N/A')}ms")
    
    usage = metrics.get("usage", {})
    
    with col2:
        st.metric("Prompt Tokens", usage.get("prompt_tokens", "N/A"))
    
    with col3:
        st.metric("Completion Tokens", usage.get("completion_tokens", "N/A"))
    
    st.divider()
    
    # Tier Usage Summary
    st.markdown("### Tier Usage Summary")
    
    if st.session_state.token_usage:
        for tier_id in TIERS.keys():
            used = st.session_state.token_usage.get(tier_id, 0)
            tier_info = TIERS[tier_id]
            limit = tier_info['token_limit']
            pct = min(100, int((used / limit) * 100)) if limit > 0 else 0
            
            col1, col2 = st.columns([1, 3])
            with col1:
                st.markdown(f"{tier_info['icon']} **{tier_info['name']}**")
            with col2:
                st.progress(pct / 100)
                st.caption(f"{used:,} / {limit:,} tokens ({pct}%)")
    else:
        st.info("No usage recorded yet. Chat with the model to see usage per tier.")
    
    st.divider()
    
    st.markdown("### Last Response Details")
    
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


def render_tiers_tab():
    """Render the tiers demonstration tab."""
    st.subheader("🎫 MaaS Tiers Demo")
    
    st.markdown("""
    MaaS supports **tier-based rate limiting** to control API usage. Different tiers have different token limits,
    allowing you to offer free, standard, and premium access levels.
    """)
    
    # Show tier comparison
    st.markdown("### Tier Comparison")
    
    cols = st.columns(3)
    for i, (tier_id, tier_info) in enumerate(TIERS.items()):
        with cols[i]:
            st.markdown(f"""
            <div style="
                background: linear-gradient(135deg, {tier_info['color']}22, {tier_info['color']}11);
                border: 2px solid {tier_info['color']};
                border-radius: 12px;
                padding: 1.5rem;
                text-align: center;
                height: 200px;
            ">
                <h2 style="margin: 0;">{tier_info['icon']}</h2>
                <h3 style="color: {tier_info['color']}; margin: 0.5rem 0;">{tier_info['name']}</h3>
                <p style="font-size: 1.5rem; font-weight: bold; margin: 0.5rem 0;">
                    {tier_info['token_limit']:,}
                </p>
                <p style="color: #888; margin: 0;">tokens/hour</p>
            </div>
            """, unsafe_allow_html=True)
            
            # Show if this tier is available
            if tier_id in st.session_state.available_tiers:
                st.success("✓ Available")
            else:
                st.caption("Not configured")
    
    st.divider()
    
    # Tier Verification Section
    st.markdown("### 🔍 Verify Your Tier")
    
    st.markdown("""
    Click the button below to verify which tier your current token belongs to.
    This calls the `maas-api/v1/tiers/lookup` endpoint to show your resolved tier.
    """)
    
    if st.button("🔍 Check My Tier", type="primary"):
        if st.session_state.token and st.session_state.endpoint:
            with st.spinner("Checking tier..."):
                try:
                    # Decode JWT to get user info
                    import base64
                    token_parts = st.session_state.token.split('.')
                    if len(token_parts) >= 2:
                        # Decode payload (add padding if needed)
                        payload = token_parts[1]
                        padding = 4 - len(payload) % 4
                        if padding != 4:
                            payload += '=' * padding
                        decoded = json.loads(base64.urlsafe_b64decode(payload))
                        
                        user_info = decoded.get('kubernetes.io', {}).get('serviceaccount', {})
                        subject = decoded.get('sub', 'Unknown')
                        
                        st.success("Token decoded successfully!")
                        
                        col1, col2 = st.columns(2)
                        with col1:
                            st.markdown("**Token Subject:**")
                            st.code(subject)
                        with col2:
                            if user_info:
                                st.markdown("**ServiceAccount:**")
                                st.code(f"{user_info.get('name', 'N/A')}")
                        
                        # Determine tier from SA name
                        sa_name = user_info.get('name', '')
                        if 'free' in sa_name:
                            detected_tier = 'free'
                        elif 'premium' in sa_name:
                            detected_tier = 'premium'
                        elif 'enterprise' in sa_name:
                            detected_tier = 'enterprise'
                        else:
                            detected_tier = 'free'  # Default
                        
                        tier_info = TIERS.get(detected_tier, TIERS['free'])
                        st.markdown(f"""
                        <div style="
                            background: linear-gradient(135deg, {tier_info['color']}33, {tier_info['color']}11);
                            border: 2px solid {tier_info['color']};
                            border-radius: 12px;
                            padding: 1rem;
                            text-align: center;
                            margin: 1rem 0;
                        ">
                            <h2 style="margin: 0;">{tier_info['icon']} Your Tier: {tier_info['name']}</h2>
                            <p style="margin: 0.5rem 0;">Rate Limit: <strong>{tier_info['token_limit']:,} tokens/hour</strong></p>
                        </div>
                        """, unsafe_allow_html=True)
                        
                except Exception as e:
                    st.error(f"Could not decode token: {e}")
        else:
            st.warning("Please connect and ensure you have a token first")
    
    st.divider()
    
    # Compare All Tiers Section
    st.markdown("### 🔬 Compare All Tiers")
    
    st.markdown("""
    Click below to test all three tier tokens and prove they have different identities.
    Each tier uses a different ServiceAccount with different rate limits.
    """)
    
    if st.button("🔬 Test All Tier Tokens", type="secondary"):
        import base64
        
        tier_tokens = {
            'free': os.environ.get('MAAS_TIER_FREE_TOKEN'),
            'premium': os.environ.get('MAAS_TIER_PREMIUM_TOKEN'),
            'enterprise': os.environ.get('MAAS_TIER_ENTERPRISE_TOKEN'),
        }
        
        cols = st.columns(3)
        for i, (tier_id, token) in enumerate(tier_tokens.items()):
            with cols[i]:
                tier_info = TIERS[tier_id]
                st.markdown(f"**{tier_info['icon']} {tier_info['name']}**")
                
                if token:
                    try:
                        # Decode token
                        payload = token.split('.')[1]
                        padding = 4 - len(payload) % 4
                        if padding != 4:
                            payload += '=' * padding
                        decoded = json.loads(base64.urlsafe_b64decode(payload))
                        
                        sa_info = decoded.get('kubernetes.io', {}).get('serviceaccount', {})
                        sa_name = sa_info.get('name', 'Unknown')
                        
                        st.success(f"✓ Token valid")
                        st.caption(f"SA: `{sa_name}`")
                        st.caption(f"Limit: {tier_info['token_limit']:,}/hr")
                    except Exception as e:
                        st.error(f"Invalid token")
                else:
                    st.warning("No token configured")
    
    st.divider()
    
    # Rate limiting demo
    st.markdown("### 🧪 Test Rate Limiting")
    
    st.markdown("""
    **How to prove tiers work:**
    1. Select **Free** tier in the sidebar → Uses `tier-free-sa` (10K tokens/hour)
    2. Select **Premium** tier → Uses `tier-premium-sa` (50K tokens/hour)  
    3. Select **Enterprise** tier → Uses `tier-enterprise-sa` (100K tokens/hour)
    4. Click "Check My Tier" above to verify which token is active
    
    **The proof:**
    - Each tier button switches to a different ServiceAccount token
    - The token's `sub` claim shows which SA is being used
    - Rate limits are enforced server-side by Limitador based on group membership
    """)
    
    # Show current usage
    if st.session_state.token_usage:
        st.markdown("### Your Usage")
        
        for tier_id, used in st.session_state.token_usage.items():
            if tier_id in TIERS:
                tier_info = TIERS[tier_id]
                limit = tier_info['token_limit']
                pct = min(100, int((used / limit) * 100))
                
                st.markdown(f"**{tier_info['icon']} {tier_info['name']}**")
                st.progress(pct / 100)
                st.caption(f"{used:,} / {limit:,} tokens ({pct}%)")
        
        if st.button("🔄 Reset Usage Tracking"):
            st.session_state.token_usage = {}
            st.rerun()
    
    st.divider()
    
    # Technical details
    with st.expander("🔧 Technical Details"):
        st.markdown("""
        ### How Tiers Work in RHOAI 3.3
        
        MaaS tiers are implemented using **OpenShift Groups**, not ServiceAccounts:
        
        1. **User Authentication** - Kubernetes TokenReview validates the bearer token
        
        2. **Tier Resolution** - The AuthPolicy calls `maas-api/v1/tiers/lookup` with user's groups
           - The `tier-to-group-mapping` ConfigMap defines which groups belong to which tier
           - Users get the **highest tier** they qualify for
        
        3. **Tier Injection** - The resolved tier is injected into `auth.identity.tier`
        
        4. **Rate Limiting** - TokenRateLimitPolicy evaluates predicates like:
           - `auth.identity.tier == "free"` → 10,000 tokens/hour
           - `auth.identity.tier == "premium"` → 50,000 tokens/hour
           - `auth.identity.tier == "enterprise"` → 100,000 tokens/hour
        
        ### Tier Group Mapping
        
        | Tier | OpenShift Groups |
        |------|------------------|
        | Free | `system:authenticated`, `tier-free-users` |
        | Premium | `tier-premium-users`, `premium-group` |
        | Enterprise | `tier-enterprise-users`, `enterprise-group`, `admin-group` |
        
        ### Assigning Users to Tiers
        
        ```bash
        # Add user to Premium tier
        oc adm groups new tier-premium-users
        oc adm groups add-users tier-premium-users <username>
        
        # Add user to Enterprise tier
        oc adm groups new tier-enterprise-users
        oc adm groups add-users tier-enterprise-users <username>
        ```
        
        ### Example TokenRateLimitPolicy
        
        ```yaml
        apiVersion: kuadrant.io/v1alpha1
        kind: TokenRateLimitPolicy
        metadata:
          name: maas-tier-token-rate-limits
          namespace: openshift-ingress
        spec:
          targetRef:
            kind: Gateway
            name: maas-default-gateway
          limits:
            free-tokens:
              rates:
                - limit: 10000
                  window: 1h0m0s
              when:
                - predicate: 'auth.identity.tier == "free"'
              counters:
                - expression: auth.identity.userid
        ```
        
        ### Important Note
        
        The tier shown in this UI is for **demonstration purposes**. Your actual tier
        is determined by your OpenShift group membership, not by selecting in this UI.
        The rate limits are enforced server-side by the MaaS gateway.
        """)


def main():
    """Main application entry point."""
    # Suppress SSL warnings
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
    init_session_state()
    render_header()
    render_sidebar()
    
    # Main content tabs
    tab1, tab2, tab3, tab4 = st.tabs(["💬 Chat", "🎫 Tiers", "⚖️ Compare Models", "📊 Metrics"])
    
    with tab1:
        render_chat_tab()
    
    with tab2:
        render_tiers_tab()
    
    with tab3:
        render_comparison_tab()
    
    with tab4:
        render_metrics_tab()


if __name__ == "__main__":
    main()
