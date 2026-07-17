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
- Requires a deployed model endpoint

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
