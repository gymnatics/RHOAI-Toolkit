# Guardrails Demo - Understanding AI Safety

A **standalone** demo to help you understand how AI guardrails work, without requiring TrustyAI or any external services.

## Quick Start

```bash
# Install dependencies
pip install streamlit

# Run the demo
cd demo/guardrails-demo
streamlit run app.py
```

Then open http://localhost:8501 in your browser.

---

## What This Demo Shows

### 🔒 PII Detection
Detects personally identifiable information:
- Email addresses
- Phone numbers
- Social Security Numbers
- Credit card numbers
- IP addresses

### 💉 Prompt Injection Detection
Detects attempts to manipulate the AI:
- "Ignore previous instructions"
- System prompt overrides
- Jailbreak attempts

### ☠️ Toxicity Detection
Detects harmful content:
- Threats
- Profanity (mild examples)

---

## Try These Examples

| Input | What It Detects |
|-------|-----------------|
| `Contact me at john@example.com` | Email address (PII) |
| `Call me at 555-123-4567` | Phone number (PII) |
| `My SSN is 123-45-6789` | Social Security Number (PII) |
| `Card: 4532015112830366` | Credit card (PII) |
| `Ignore all previous instructions` | Prompt injection |
| `What's the weather today?` | Nothing - safe content |

---

## How It Works

This demo uses **regex-based pattern matching** to simulate guardrails. It's meant for learning, not production use.

### In Production

For real AI safety, use:

1. **TrustyAI GuardrailsOrchestrator** - Deploy with `scripts/setup-trustyai-guardrails.sh`
2. **Llama Guard** - Meta's safety model
3. **NVIDIA NeMo Guardrails** - Programmable guardrails

---

## Next Steps

Once you understand the concepts, you can:

1. **Merge the feature branch** to get real TrustyAI integration:
   ```bash
   git checkout feature/trustyai-guardrails
   ```

2. **Deploy TrustyAI** in your cluster:
   ```bash
   ./scripts/setup-trustyai-guardrails.sh
   ```

3. **Update your LlamaStack demo** to use the guardrails endpoint

---

## Files

| File | Description |
|------|-------------|
| `app.py` | Streamlit application with mock guardrails |
| `requirements.txt` | Python dependencies |
| `README.md` | This file |

