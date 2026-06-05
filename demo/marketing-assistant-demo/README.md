# Marketing Assistant Demo

Multi-agent A2A campaign manager with TrustyAI guardrails.

Based on [gymnatics/Marketing-Assistant-Demo](https://github.com/gymnatics/Marketing-Assistant-Demo).

## Requirements

- **3x NVIDIA L40S GPUs** (or equivalent 48GB VRAM each)
- Models: Qwen2.5-Coder-32B, Qwen3-32B, FLUX.2-klein-4B

This demo is NOT included in the deploy-all script due to heavy GPU requirements.

## Deploy

```bash
./deploy.sh            # Interactive deployment
./deploy.sh --delete   # Cleanup
```

The script clones the repo and delegates to its own `deploy.sh`, which auto-detects your cluster and models.

## Features

- AI-generated landing pages (Qwen Coder)
- AI hero images (FLUX.2)
- 4-layer TrustyAI guardrails
- Hyper-personalization via MCP
- Multi-agent A2A protocol
- MLflow GenAI tracing
