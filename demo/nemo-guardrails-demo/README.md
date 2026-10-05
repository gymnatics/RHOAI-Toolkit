# NeMo Guardrails Demo (RHOAI 3.4)

Deploy NeMo Guardrails via the TrustyAI operator CRD.

## Deploy

```bash
./deploy.sh                        # Basic (built-in detectors only, no LLM)
./deploy.sh --selfcheck            # With LLM self-check rails
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
- Requires a deployed model endpoint (any existing `InferenceService` on the
  cluster -- the script lists them and prompts for namespace/name, then
  wraps it as the self-check judge model)
- No GPU on hand to deploy a real model just to test this flow? Apply
  `lib/manifests/guardrails/internal-model-llmisvc.yaml` (CPU-only,
  ~30s to start, uses the same `llm-d-inference-sim` image as the MaaS
  `simulator` model) into your namespace first, then pass its direct
  predictor Service (`<name>-kserve-workload-svc.<ns>.svc.cluster.local:8000`)
  as the model endpoint. Note: in `--mode=echo`, the simulator just echoes
  the self-check prompt back rather than reasoning about it, so it will
  verify the wiring (config loads, the LLM call succeeds, no errors) but
  can't demonstrate correct allow/block *discrimination* -- for that, wrap
  a real instruction-following model.

## What's Deployed

- ServiceAccount + RoleBinding
- API token Secret (2-week duration)
- ConfigMap with guardrails config
- NemoGuardrails CR (managed by TrustyAI operator)

## Testing

After deployment, the script prints curl commands and optionally runs automated tests.

## References

- [RHOAI 3.4 Guardrails Docs](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html-single/enabling_ai_safety_with_guardrails/index)
- [JPishikawa/demo-guardrail](https://github.com/JPishikawa/demo-guardrail)
