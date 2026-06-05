# Micro Financial Loan Demo

Predictive ML + LLM-powered explanation for loan approval decisions.

Based on [cbtham/micro-financial-loan](https://github.com/cbtham/micro-financial-loan).

## What It Does

1. **Predictive Model** (scikit-learn) -- classifies loan applications as approved/rejected based on credit score, income, DTI ratio, etc.
2. **LLM Explanation** (Qwen3 via MaaS) -- explains the prediction in natural language, helping loan officers understand why
3. **Web Application** -- Flask app that combines both models into a single interface

## Deploy

```bash
./deploy.sh                         # Deploy to 'financial-loan-demo' namespace
./deploy.sh --llm-url URL           # Specify LLM endpoint manually
./deploy.sh --delete                # Remove
```

The deploy script:
- Clones the repo from GitHub
- Deploys a workbench for notebook development
- Sets up MinIO for model storage
- Auto-detects the MaaS gateway or InferenceService endpoint for LLM inference
- Configures the web app with both model endpoints

## Architecture

```
User → Web App (Flask) ──→ scikit-learn InferenceService (CPU, v2 protocol)
                        └─→ Qwen3-4B via MaaS gateway (GPU, OpenAI protocol)
```

The LLM is shared across all demos via the MaaS inference gateway. No dedicated GPU needed for this demo alone.

## Model Endpoints

| Model | Protocol | GPU | Purpose |
|-------|----------|-----|---------|
| scikit-learn classifier | KServe v2 inference | No | Loan approval prediction |
| Qwen3-4B (or fine-tuned) | OpenAI-compatible | Yes (shared) | Explain prediction results |

## Notebooks

Vendored in `notebooks/` with auto-configured environment (no hardcoded cluster URLs):

1. `notebooks/predictive-model-development.ipynb` -- train the scikit-learn classifier
2. `notebooks/llm-model-fine-tuning.ipynb` -- fine-tune Qwen3 on custom loan data (optional, improves explanations)

The deploy script creates a `demo-config-env` ConfigMap with cluster-specific values.
Mount it as `.env` in your workbench, or the notebooks auto-detect defaults.

Original notebooks: [cbtham/micro-financial-loan](https://github.com/cbtham/micro-financial-loan) (see `notebooks/ATTRIBUTION.md`)

## Prerequisites

- RHOAI 3.4 with a model deployed (e.g. Qwen3-4B via MaaS)
- MinIO or S3-compatible storage for the trained classifier
