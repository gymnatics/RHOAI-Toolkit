# Attribution

The notebooks and web application in this directory are adapted from:

- **Repository:** [cbtham/micro-financial-loan](https://github.com/cbtham/micro-financial-loan)
- **Author:** [cbtham](https://github.com/cbtham)
- **License:** See the original repository for license terms

## Changes from Original

### Notebooks
- Hardcoded MinIO endpoint URLs replaced with environment variable auto-detection
- Hardcoded S3 credentials replaced with configurable defaults
- Added setup cell that loads `.env` for cluster-specific configuration
- Namespace references updated to match this toolkit's conventions
- Hardcoded `Qwen/Qwen3-4B-Instruct-2507` model ID replaced with `HF_MODEL_ID` env var

### Web Application (`../web-application/`)
- Hardcoded LLM model name `qwen3-4b-ft-microloan` replaced with `LLM_MODEL_NAME` env var
- Added optional `SKLEARN_API_TOKEN` and `LLM_API_TOKEN` for Bearer token authentication
- Headers dynamically include `Authorization: Bearer` when tokens are configured

## Vendored Components

| Vendored | Original |
|---|---|
| `predictive-model-development.ipynb` | [predictive-model-development.ipynb](https://github.com/cbtham/micro-financial-loan/blob/main/predictive-model-development.ipynb) |
| `llm-model-fine-tuning.ipynb` | [llm-model-fine-tuning.ipynb](https://github.com/cbtham/micro-financial-loan/blob/main/llm-model-fine-tuning.ipynb) |
| `../web-application/` | [web-application/](https://github.com/cbtham/micro-financial-loan/tree/main/web-application) |
