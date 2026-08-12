# Lemonade Stand Assistant — TrustyAI / FMS Orchestr8 Edition

Deploys the **upstream** [rh-ai-quickstart/lemonade-stand-assistant](https://github.com/rh-ai-quickstart/lemonade-stand-assistant)
demo as-is (vendored Helm chart, no local image builds — everything is pre-built on quay.io).

> This is a **different** demo from `demo/lemonade-stand-demo/`. That one proxies chat
> through **NeMo Guardrails**. This one uses the **TrustyAI Guardrails Orchestrator
> (FMS Orchestr8)** wired to three independent detector models. They deploy to different
> namespaces and can coexist.

## What gets deployed

| Component | Kind | Compute |
|---|---|---|
| Llama 3.2 3B Instruct | KServe `InferenceService` (vLLM) | 1 GPU (or bring your own endpoint) |
| IBM HAP Detector (Granite Guardian) | KServe `InferenceService` | CPU |
| Prompt Injection Detector (DeBERTa v3) | KServe `InferenceService` | CPU |
| Lingua Language Detector | `Deployment` | CPU |
| Chunker (sentence chunker for FMS Orchestr8) | `Deployment` | CPU |
| MinIO | `Deployment` + PVC | Downloads/serves the two HF detector models |
| `GuardrailsOrchestrator` (TrustyAI) | CR | Wires model + HAP + prompt-injection + language + built-in regex-competitor detector |
| `lemonade-stand` chat app | `Deployment` + `Route` | FastAPI, family-friendly lemon-only chatbot |
| `shiny-dashboard` | `Deployment` + `Route` | R Shiny live metrics dashboard |

## Prerequisites

- RHOAI 3.4 with KServe RawDeployment mode configured (default on this toolkit's installs)
- TrustyAI component — `deploy.sh` enables it automatically if it's `Removed`
- Helm 3 CLI
- 1 free GPU (unless you pass `--model-name`/`--model-endpoint` to use an existing model)

## Deploy

```bash
# Deploy own Llama 3.2 3B (requires 1 GPU)
./demo/lemonade-trustyai-demo/deploy.sh

# Custom namespace
./demo/lemonade-trustyai-demo/deploy.sh -n my-namespace

# Point at an existing model endpoint instead (e.g. MaaS) -- no GPU needed
./demo/lemonade-trustyai-demo/deploy.sh \
  --model-name my-model \
  --model-endpoint my-model-predictor.my-namespace.svc \
  --model-port 8080

# Enable GPU for a detector (needs an extra GPU)
./demo/lemonade-trustyai-demo/deploy.sh --set detectors.hap.useGpu=true

# Remove everything
./demo/lemonade-trustyai-demo/deploy.sh --delete
```

## Validate

```bash
oc get pods -n lemonade-trustyai-demo
oc get inferenceservice -n lemonade-trustyai-demo
oc get guardrailsorchestrator -n lemonade-trustyai-demo

echo https://$(oc get route lemonade-stand -n lemonade-trustyai-demo -o jsonpath='{.spec.host}')
echo https://$(oc get route shiny-dashboard -n lemonade-trustyai-demo -o jsonpath='{.spec.host}')
```

Ask about lemons (should answer), try mentioning a competitor fruit or a prompt
injection attempt (should be blocked) — watch the counters move on both `/metrics`
and the Shiny dashboard.

## Known upstream issue (auto-fixed by `deploy.sh`)

The upstream chart's `fms-orchestr8-config-nlp` ConfigMap hardcodes each backend's
**container** port (`8080` for the model, `8000` for the HAP/prompt-injection detector
runtimes). But KServe RawDeployment `InferenceService`s always expose their ClusterIP
`Service` on port **80** (mapping to the container's `targetPort`) -- so those hardcoded
ports don't exist on the Service and every chat/detection call hangs for 60s before
failing with a connect timeout (the LLM never even gets called). `deploy.sh` detects the
real Service port after `helm install` and patches the ConfigMap + restarts the
orchestrator automatically. If you ever see chat requests hang for exactly ~60s, check:

```bash
oc get cm fms-orchestr8-config-nlp -n lemonade-trustyai-demo -o jsonpath='{.data.config\.yaml}'
oc get svc -n lemonade-trustyai-demo llama-32-predictor guardrails-detector-ibm-hap-predictor prompt-injection-detector-predictor
```

The `port:` values in the ConfigMap must match each Service's `spec.ports[0].port` (80),
not the container's internal port.

## Notes

- The chart is vendored via `lib/external-repos.conf` (`lemonade-stand-assistant` entry)
  and cloned to `~/.rhoai-demos/lemonade-stand-assistant` on first run, then deployed
  with `helm upgrade --install` unmodified from `chart/`.
- Detector models (Granite Guardian HAP 125M, DeBERTa v3 prompt-injection) are downloaded
  from Hugging Face into a MinIO PVC on first deploy — this can take a few minutes.
- Full upstream docs (architecture diagrams, resource sizing, GPU options for detectors):
  see the [upstream README](https://github.com/rh-ai-quickstart/lemonade-stand-assistant#readme).
