# MaaS API Bug: `/v1/models` Returns `url` With Trailing Slash, Breaking Documented Usage Pattern

## Summary

The RHOAI 3.5 Models-as-a-Service (MaaS) `maas-api`'s `GET /v1/models` discovery endpoint returns each model's `url` field **with a trailing slash**. Following the officially documented client pattern of concatenating `${MODEL_URL}/v1/chat/completions` produces a **double slash** in the request path (`.../com//v1/chat/completions`), which the gateway's HTTPRoute does not match. The request falls through to the backend vLLM pod's own router, which returns a generic `{"detail":"Not Found"}` (404) — a confusing error that gives no indication the problem is a URL-formatting issue.

## Environment

- OpenShift 4.20 (`api.cluster-v5zjc.v5zjc.sandbox583.opentlc.com`)
- RHOAI 3.5.0 (`rhods-operator.3.5.0`)
- Red Hat Connectivity Link (RHCL) v1.4.2 (`rhcl-operator.v1.4.2`)
- MaaS (Models-as-a-Service) — `aigateway.modelsAsAService`, GA in RHOAI 3.5
- `maas-api` deployed in `redhat-ai-gateway-infra` namespace
- Model: `RedHatAI/Qwen3-8B-FP8-dynamic` served via `LLMInferenceService` (llm-d / KServe `serving.kserve.io/v1alpha2`)
- vLLM: `vllm-0.24.0+rhaiv.9`
- Gateway: `maas-default-gateway` (Gateway API, Envoy-based) in `openshift-ingress`
- Auth: Kuadrant `AuthPolicy` (`maas-gateway-auth`) + `TokenRateLimitPolicy`, MaaS API key (`sk-oai-...`) issued via `POST /v1/tokens`

## Symptom

Following the **documented client workflow exactly**:

```bash
CLUSTER_DOMAIN=$(kubectl get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
MAAS_API_URL="https://maas.${CLUSTER_DOMAIN}"
API_KEY="sk-oai-..."  # Valid API key with an active subscription

# Get the first available model
MODELS=$(curl -s "${MAAS_API_URL}/v1/models" \
    -H "Authorization: Bearer ${API_KEY}")
MODEL_URL=$(echo $MODELS | jq -r '.data[0].url')
MODEL_NAME=$(echo $MODELS | jq -r '.data[0].id')

curl -sSk \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"${MODEL_NAME}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello, how are you?\"}], \"max_tokens\": 100}" \
  "${MODEL_URL}/v1/chat/completions"
```

produces:

```
{"detail":"Not Found"}
```

with `HTTP_STATUS:404`, even though:
- The API key is valid and has an active `MaaSSubscription` covering the model
- The model (`LLMInferenceService`) is `Ready: True` and healthy
- The same API key works fine against other URL variants for the same model

This is confusing because the error message gives no indication of a URL malformation — it looks identical to an auth failure, a missing subscription, or a genuinely undeployed model.

## Root Cause

### 1. `maas-api`'s `/v1/models` response includes a trailing slash

```bash
curl -sk "${MAAS_API_URL}/v1/models" -H "Authorization: Bearer ${API_KEY}" | python3 -m json.tool
```

```json
{
    "data": [
        {
            "id": "publishers/monash-university-demo/models/redhataiqwen3-8b-fp8-dynamic",
            "created": 1788327938,
            "object": "model",
            "owned_by": "monash-university-demo/redhataiqwen3-8b-fp8-dynamic",
            "kind": "LLMInferenceService",
            "url": "https://maas.apps.cluster-v5zjc.v5zjc.sandbox583.opentlc.com/",
            "ready": true,
            "modelDetails": {
                "displayName": "RedHatAI/Qwen3-8B-FP8-dynamic"
            },
            "subscriptions": [
                {
                    "name": "subscription-test",
                    "displayName": "Subscription-Test",
                    "description": "Test subscription"
                }
            ]
        }
    ],
    "object": "list"
}
```

Note the trailing `/` in `"url"`.

### 2. The documented client pattern concatenates without normalizing the slash

```bash
MODEL_URL=$(echo $MODELS | jq -r '.data[0].url')
# MODEL_URL = "https://maas.apps.cluster-v5zjc.v5zjc.sandbox583.opentlc.com/"

curl "${MODEL_URL}/v1/chat/completions" ...
# Effective URL: "https://maas.apps.cluster-v5zjc.v5zjc.sandbox583.opentlc.com//v1/chat/completions"
#                                                                            ^^ double slash
```

### 3. The gateway's HTTPRoute does not match the double-slash path

Envoy's Gateway API HTTPRoute path matching (`PathPrefix` / `Exact`) does not normalize the double slash, so the router falls through instead of routing to `maas-api` or the model backend's own HTTPRoute for `/v1/chat/completions`. The request lands on the model's own vLLM pod without going through the expected path-based routing, and vLLM's own FastAPI-based OpenAI server returns its standard 404 for an unregistered path:

```json
{"detail":"Not Found"}
```

This is a genuine vLLM/FastAPI 404 response (confirmed by reproducing the identical double-slash path manually and matching bytes), **not** a Kuadrant `AuthPolicy` rejection (which returns different messages, e.g. `"no matching subscription found for user"`) and **not** an Envoy-level 404 (which would return an empty body).

## Evidence

### Reproduction with the malformed (docs-exact) URL

```bash
$ MODEL_URL="https://maas.apps.cluster-v5zjc.v5zjc.sandbox583.opentlc.com/"
$ MODEL_NAME="publishers/monash-university-demo/models/redhataiqwen3-8b-fp8-dynamic"
$ curl -sSk -w "\nHTTP_STATUS:%{http_code}\n" \
    -H "Authorization: Bearer ${API_KEY}" -H "Content-Type: application/json" \
    -d "{\"model\": \"${MODEL_NAME}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello, how are you?\"}], \"max_tokens\": 100}" \
    "${MODEL_URL}/v1/chat/completions"

{"detail":"Not Found"}
HTTP_STATUS:404
```

### Same request, only difference is stripping the trailing slash — succeeds

```bash
$ MODEL_URL=$(echo $MODELS | jq -r '.data[0].url' | sed 's:/*$::')
$ echo "$MODEL_URL"
https://maas.apps.cluster-v5zjc.v5zjc.sandbox583.opentlc.com

$ curl -sSk -w "\nHTTP_STATUS:%{http_code}\n" \
    -H "Authorization: Bearer ${API_KEY}" -H "Content-Type: application/json" \
    -d "{\"model\": \"${MODEL_NAME}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello, how are you?\"}], \"max_tokens\": 100}" \
    "${MODEL_URL}/v1/chat/completions"

{"id":"chatcmpl-8dc345d2-d5d3-43a2-9c87-89f15ca6e223","object":"chat.completion", ...}
HTTP_STATUS:200
```

### Independently confirmed the double-slash path is the exact failure trigger

Reproduced the identical `{"detail":"Not Found"}` byte-for-byte by manually constructing a double-slash path against a **different** (also valid) route variant for the same model, ruling out any auth/subscription-specific cause:

```bash
$ curl -sSk -w "\nHTTP_STATUS:%{http_code}\n" \
    -H "Authorization: Bearer ${API_KEY}" -H "Content-Type: application/json" \
    -d '{"model":"redhataiqwen3-8b-fp8-dynamic","messages":[{"role":"user","content":"hi"}],"max_tokens":10}' \
    "https://maas.apps.cluster-v5zjc.v5zjc.sandbox583.opentlc.com/monash-university-demo/redhataiqwen3-8b-fp8-dynamic/v1/v1/chat/completions"

{"detail":"Not Found"}
HTTP_STATUS:404
```

(single `/v1` on the same path → `HTTP_STATUS:200` with a valid completion)

## Affected Components

| Component | Role |
|---|---|
| `maas-api` (deployment in `redhat-ai-gateway-infra`) | Returns the malformed (trailing-slash) `url` field from `GET /v1/models` |
| MaaS client documentation | Documents a client-side concatenation pattern (`${MODEL_URL}/v1/chat/completions`) that is not robust to the trailing slash the API itself returns |
| `maas-default-gateway` (Gateway API / Envoy) | Does not normalize/collapse duplicate slashes before HTTPRoute path matching |

## Impact

- **Every** first-time user following the official MaaS quickstart documentation verbatim (using `jq` to extract `url`/`id` from `/v1/models` and concatenating as shown) hits this failure on their very first request.
- The resulting `{"detail":"Not Found"}` gives no actionable signal — it's indistinguishable from a genuinely missing/undeployed model, leading users to suspect their subscription, API key, or model deployment instead of the actual URL-formatting issue.
- This was independently reproduced across two different OpenShift AI users (`user1`, `user2`) with valid, active MaaS subscriptions and a healthy, `Ready: True` model.

## Workaround

Strip the trailing slash from `MODEL_URL` before concatenating, e.g.:

```bash
MODEL_URL=$(echo $MODELS | jq -r '.data[0].url' | sed 's:/*$::')
```

or avoid adding an extra `/` when building the request URL:

```bash
curl "${MODEL_URL}v1/chat/completions" ...   # no slash between MODEL_URL and v1
```

## Suggested Fix (upstream)

Either (preferably both):

1. **`maas-api`**: `GET /v1/models` should return the `url` field **without** a trailing slash, consistent with how a base URL is normally expected to be used (`https://host` not `https://host/`).
2. **Gateway**: Configure the Envoy Gateway API listener/HTTPRoute (or add a URL-normalization filter) to collapse duplicate slashes before path matching, so accidental double slashes from client-side concatenation don't silently fall through to the backend and produce a misleading raw vLLM 404.
3. **Documentation**: Update the MaaS quickstart snippet to either `sed 's:/*$::'` the extracted `url`, or explicitly note that `url` may include a trailing slash and must be normalized before use.

## References

- Cluster: `cluster-v5zjc.v5zjc.sandbox583.opentlc.com`
- Namespace: `models-as-a-service` (subscriptions/tenant config), `redhat-ai-gateway-infra` (`maas-api`), `monash-university-demo` (model)
- Gateway: `maas-default-gateway` in `openshift-ingress`
- Model: `redhataiqwen3-8b-fp8-dynamic` (`RedHatAI/Qwen3-8B-FP8-dynamic`)
