# NeMo Guardrails Demo (RHOAI 3.4)

Deploy NeMo Guardrails via the TrustyAI operator CRD.

## Deploy

```bash
./deploy.sh                        # Basic (built-in detectors only, no LLM)
./deploy.sh --selfcheck            # With LLM self-check rails (auto-detects the chat model)
./deploy.sh --selfcheck --model-url URL --model-name SERVED_ID   # explicit model
./deploy.sh -n my-project          # Custom namespace
./deploy.sh --delete               # Remove
```

## Modes

### Basic (default)
- Presidio PII detection (email, person, phone)
- Regex pattern detection (passwords, SSN)
- No LLM required

### Self-Check (`--selfcheck`)
- Everything in basic mode
- LLM-powered input/output validation
- Requires a deployed chat model. By default the script auto-detects one with
  `detect_direct_llm_endpoint` (`lib/functions/notebook-env.sh`), preferring a
  plain-http vLLM `InferenceService` (NeMo does not trust the service-CA
  certificate of `LLMInferenceService` https endpoints), and resolves its
  served model id with `resolve_served_model_id`. Pass `--model-url URL
  --model-name SERVED_ID` to use a specific model instead; the deploy warns
  if the resulting endpoint is https.
- No GPU on hand to deploy a real model just to test this flow? Apply
  `lib/manifests/guardrails/internal-model-llmisvc.yaml` (CPU-only,
  ~30s to start, uses the same `llm-d-inference-sim` image as the MaaS
  `simulator` model) into your namespace first, then pass its direct
  predictor Service (`<name>-kserve-workload-svc.<ns>.svc.cluster.local:8000`)
  as `--model-url` (with `--model-name`). Note: in `--mode=echo`, the simulator
  just echoes the self-check prompt back rather than reasoning about it, so it
  will verify the wiring (config loads, the LLM call succeeds, no errors) but
  can't demonstrate correct allow/block *discrimination* -- for that, wrap
  a real instruction-following model.

## What's Deployed

- ServiceAccount + RoleBinding
- API token Secret `api-token-secret` (1-year duration; re-minted on every deploy, so a lemonade-stand
  or university-safeguard-demo deployment using the same token never sees it expire)
- ConfigMap with guardrails config
- NemoGuardrails CR (managed by TrustyAI operator)

## Testing

After deployment, the script prints curl commands and runs automated tests by default (the "Run
automated tests?" prompt only blocks when run interactively; it defaults to yes when stdin is not a
TTY). Test prompts and sample commands use `model_name` from the `<name>-config` ConfigMap (the
served model id in selfcheck mode, or `test` in basic mode, which has no LLM).

## Next: Lemonade Stand Demo

`demo/lemonade-stand-demo` chats through this demo's NeMo Guardrails endpoint. Deploy NeMo Guardrails
with `--selfcheck` first (it needs an LLM configured), then deploy lemonade-stand:
```bash
./demo/nemo-guardrails-demo/deploy.sh -n nemo-guardrails-demo --selfcheck
./demo/lemonade-stand-demo/deploy.sh
```

## References

- [RHOAI 3.4 Guardrails Docs](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html-single/enabling_ai_safety_with_guardrails/index)
- [JPishikawa/demo-guardrail](https://github.com/JPishikawa/demo-guardrail)
