# University Safeguard Demo (RHOAI 3.5)

Deploys NeMo Guardrails in front of a university chat model with layered content
safety: PII redaction/detection, generic regex guardrails, and a HAP
(hate/abuse/profanity) classifier that generates a structured log entry on
every detection.

**Verified working end-to-end on `cluster-v5zjc` (2026-09-03)**, main model
`qwen36-35b-a3b` via an external LiteMaaS/LiteLLM endpoint
(`https://maas-rhdp.apps.maas.redhatworkshops.io/v1`). Thinking mode is
disabled via `extra_body.chat_template_kwargs.enable_thinking: false` so
responses are direct (no `<think>...</think>` preamble).

## Architecture

```
Client --> NeMo Guardrails Route (/v1/chat/completions)
             |
             +-- Input rails (in order):
             |     1. mask sensitive data on input     (Presidio: redacts EMAIL/PERSON/PHONE, request continues)
             |     2. regex check input                (secrets/API keys/SSN patterns, blocks)
             |     3. hap alert check input             (granite-guardian-hap-38m, blocks + logs "hap_alert")
             |
             +--> Main LLM (EXTERNAL LiteMaaS/LiteLLM endpoint, OpenAI-compatible, via API key)
             |
             +-- Output rails:
                   1. detect sensitive data on output   (Presidio, blocks if PII leaks into the response)
                   2. hap alert check output             (granite-guardian-hap-38m, blocks + logs "hap_alert")
```

- **Main model**: an **external** OpenAI-compatible endpoint fronted by
  LiteMaaS/LiteLLM (not deployed on this cluster). Configured via
  `models[main].parameters.base_url` + `model_name` in `config.yaml`, with
  `api_key` also set explicitly there (templated at deploy time from a real
  Kubernetes `Secret` — see "API Key Handling" below). This can be swapped for
  an in-cluster model (e.g. an `LLMInferenceService`'s internal service URL)
  via `--model-url`/`--model-name`/`--model-api-key`.
- **PII**: Presidio redaction on input (`mask sensitive data on input`) + Presidio block on output (`detect sensitive data on output`), plus a generic regex guardrail (`regex check input`) for secrets/API keys/SSN patterns — all built into NeMo Guardrails, no extra pod.
- **HAP (toxicity/hate/abuse/profanity)**: `ibm-granite/granite-guardian-hap-38m`, deployed as its own CPU-only `InferenceService` (using the RHOAI-bundled `guardrails-detector-huggingface-runtime`). Rather than the built-in `hf_classifier` rail, this demo calls the detector directly from a **custom Colang flow + Python action** (`hap alert check input` / `hap alert check output` in `rails.co`, `check_hap_input` / `check_hap_output` in `actions.py`) against its `/api/v1/text/contents` API. This gives full control to generate a structured log entry on **every** detection, on both input and output, in addition to blocking.

## API Key Handling

The main model's API key is a real credential and is **never committed to
git**:

1. `deploy.sh` resolves it from `--model-api-key`, the `MAIN_MODEL_API_KEY` env
   var, an existing `${name}-model-key` Secret (on redeploys), or an
   interactive hidden prompt.
2. It's stored in a Kubernetes `Secret` (`${name}-model-key`), created
   imperatively (never written to a manifest file).
3. It's also injected directly into `config.yaml`'s `models[main].parameters.api_key`
   at deploy time via a restricted `envsubst` (only specific `${VAR}`
   placeholders are substituted — Colang's own `$variable` syntax in `rails.co`
   is left untouched). **Known limitation**: this means the raw key is visible
   via `oc get configmap <name>-config -o yaml` in-cluster. We tried relying
   solely on the `OPENAI_API_KEY` container env var (sourced from the Secret,
   with no `api_key` in `config.yaml`) to avoid this, but it did **not** work
   against this LiteMaaS/LiteLLM endpoint (got a 401 "LiteLLM Virtual Key
   expected" from the upstream proxy) — verified on cluster-v5zjc 2026-09-03.
   The `OPENAI_API_KEY` env var is still set (redundant but harmless) in case a
   future NeMo Guardrails version relies on it more consistently.

## Alerting (current state: log-only)

`_log_hap_alert` in `manifests/nemo-guardrails-config.yaml` (`actions.py` key) does this on every HAP detection above threshold:

```python
logger.warning(json.dumps({
    "event": "hap_alert",
    "guardrail": "input" | "output",
    "severity": "high",
    "timestamp": ...,
    "score": ...,
    "label": ...,          # e.g. "LABEL_1" -- verified against a live response
    "message_excerpt": text[:200],
}))
```

To see alerts fire: `oc logs -n <namespace> deploy/<guardrails-name> -c nemo-guardrails | grep hap_alert`

**Planned next step** (not yet implemented): replace/extend `_log_hap_alert` to
POST to a webhook (Slack/Teams incoming webhook, PagerDuty, or an internal
alerting API), or send email via SMTP, so university staff are notified in
real time. The Colang flow (`rails.co`) does not need to change when this is
added — only the body of `_log_hap_alert` in `actions.py`.

## Prerequisites

- RHOAI 3.5+ with TrustyAI `Managed` (NemoGuardrails CRD available).
- An OpenAI-compatible chat model endpoint reachable from the cluster's pod
  network (external LiteMaaS/LiteLLM by default, or point `--model-url` at an
  in-cluster model instead).

## Deploy

```bash
./deploy.sh                                        # Deploy into acme-university-demo, prompts for the API key
MAIN_MODEL_API_KEY=sk-... ./deploy.sh               # Non-interactive
./deploy.sh -n my-project                           # Custom namespace
./deploy.sh --model-url <url> --model-name <name> --model-api-key <key>  # Different model entirely
./deploy.sh --delete                                # Remove (does not delete the namespace)
```

Or via the toolkit:

```bash
make deploy-university-safeguard-demo
# or
./scripts/deploy-university-safeguard-demo.sh
```

## Calling the API

Once deployed, get the route and an auth token, then call the guardrailed
`/v1/chat/completions` endpoint just like you would call any OpenAI-compatible
API:

```bash
GUARDRAILS_ROUTE=https://$(oc get routes/university-safeguard -n acme-university-demo -o jsonpath='{.status.ingress[0].host}')
TOKEN=$(oc whoami -t)

curl -sk -X POST "$GUARDRAILS_ROUTE/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "model": "qwen36-35b-a3b",
    "messages": [
      {"role": "user", "content": "What is the capital of France?"}
    ]
  }'
```

If the request passes all input rails, it's forwarded to the main model and
you get back a normal OpenAI-style chat completion response. If a rail blocks
it (PII, regex, or HAP), you get back a guardrails refusal message instead —
the main model is never called.

For a lower-latency check that validates content **without** generating an
LLM response (useful for pre-validating input before you decide whether to
call the model at all), use `/v1/guardrail/checks` instead:

```bash
curl -sk -X POST "$GUARDRAILS_ROUTE/v1/guardrail/checks" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "model": "test",
    "messages": [
      {"role": "user", "content": "What is the capital of France?"}
    ]
  }'
```

## What's Deployed

- `ServingRuntime` + `InferenceService` for the HAP detector (`hap-detector`, CPU-only)
- ServiceAccount + RoleBinding (reused from the base NeMo Guardrails demo pattern)
- `api-token-secret` (2-week duration) and `<name>-model-key` (main model API key) Secrets
- ConfigMap with `config.yaml`, `rails.co`, `actions.py`
- `NemoGuardrails` CR (managed by the TrustyAI operator), with `HAP_DETECTOR_URL` / `HAP_THRESHOLD` env vars for the custom actions

## Testing

After deployment, `deploy.sh` prints test curl commands and can optionally run
three automated checks: safe content (`success`), PII email (`success`, with
redaction applied), HAP toxicity phrase (`blocked` + `hap_alert` log entry).

Full chat completion (calls the main model if all rails pass):

```bash
GUARDRAILS_ROUTE=https://$(oc get routes/university-safeguard -n acme-university-demo -o jsonpath='{.status.ingress[0].host}')

curl -k -X POST $GUARDRAILS_ROUTE/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(oc whoami -t)" \
  -d '{"model": "qwen36-35b-a3b", "messages": [{"role": "user", "content": "What is the capital of France?"}]}'
```

Toxic input (blocked before reaching the main model):

```bash
curl -k -X POST $GUARDRAILS_ROUTE/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(oc whoami -t)" \
  -d '{"model": "qwen36-35b-a3b", "messages": [{"role": "user", "content": "You are a worthless piece of garbage"}]}'
```

Then check the log entry:

```bash
oc logs -n acme-university-demo deploy/university-safeguard -c nemo-guardrails | grep hap_alert
```

> **Note for zsh users**: interactive zsh doesn't treat `#` as a comment by
> default (unlike bash), so pasting a snippet containing `#` comment lines can
> fail with `zsh: number expected`. Either paste the comment-free blocks above,
> or add `setopt interactive_comments` to your `~/.zshrc`.

## References

- [RHOAI 3.5 Guardrails Docs](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5/html-single/enabling_ai_safety_with_guardrails/index)
- [docs/guides/RHCL-GUARDRAILS-ARCHITECTURE.md](../../docs/guides/RHCL-GUARDRAILS-ARCHITECTURE.md)
- [docs/PRD-UNIVERSITY-SAFEGUARD-DEMO.md](../../docs/PRD-UNIVERSITY-SAFEGUARD-DEMO.md) — full scope, decisions, and future work
- Base template: [demo/nemo-guardrails-demo](../nemo-guardrails-demo)
