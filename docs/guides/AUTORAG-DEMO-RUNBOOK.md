# AutoRAG / OGX on RHOAI 3.5 — Bugs, Errors, and Manual Debugging

Failures seen bringing up AutoRAG against OGX on RHOAI **3.5.0** and **3.5.1**. Listed in the order they appeared. All workarounds below are **manual `oc` steps** — no scripts.

Upstream ticket for the OCI 401: **RHOAIENG-96724** (still open as of writing; re-check on newer z-streams).

Replace `<ns>` with your project (e.g. `autorag-demo`) and `<ogx-name>` with your `OGXServer` name (e.g. `autorag-ogx`).

---

## Quick map

| # | Symptom | Cause |
|---|---|---|
| 1 | `OGXServer` Phase `Failed`, `ConfigGenerationFailed`, HTTP **401** fetching OCI labels | Operator fetches registry labels anonymously |
| 2 | “Secret not found” / ConfigMap not found though the object exists | Operator only watches resources labeled `ogx.io/watch=true` |
| 3 | OGX pod CrashLoopBackOff — `EnvVarError` | Empty `VLLM_*_API_TOKEN` env vars |
| 4 | CrashLoop after config generates — Milvus / pydantic missing fields | CRD `providers` + `baseConfig` merge strips runtime-required fields |
| 5 | AutoRAG pipeline fails at **search-space-preparation** | `nomic-embed-text` registered while OGX runs `HF_HUB_OFFLINE=1` |
| 6 | `OGXServer` (or related objects) land in namespace **`default`** | Empty namespace in apply / wrong context |
| — | Model calls 401/403/404 from OGX | Config points at MaaS gateway instead of in-cluster InferenceService |

**Critical:** Clearing bug 1 with `spec.baseConfig` alone is **not** enough. You will hit bugs 2–5 next. The working end state is **`overrideConfig` + `rh-dev` + no CRD `providers`** (bug 4).

---

## Collect evidence first

```bash
NS=<ns>
NAME=<ogx-name>

oc get ogxserver -n "$NS" -o wide
oc describe ogxserver "$NAME" -n "$NS"
oc get ogxserver "$NAME" -n "$NS" -o jsonpath='{.status.conditions}' | jq .

oc get pods -n "$NS"
oc logs -l app.kubernetes.io/instance="$NAME" -n "$NS" --tail=200

oc get secret,configmap -n "$NS" --show-labels
oc get dsc default-dsc -o jsonpath='{.status.conditions}' | jq .
```

For a failed AutoRAG **pipeline run**:

```bash
oc get pods -n "$NS" | grep -iE 'pipeline|wf|autorag'
oc logs <failing-pod> -n "$NS" --all-containers --tail=300
```

---

## Bug 1 — OCI label fetch HTTP 401 (RHOAIENG-96724)

### Symptom

```text
Phase: Failed
Type: ConfigGenerated
Reason: ConfigGenerationFailed
Message: failed to reconcile generated config: failed to resolve base config from OCI labels:
  failed to fetch OCI labels for
  "registry.redhat.io/rhoai/odh-ogx-core-rhel9@sha256:<digest>":
  failed to fetch manifest for "...": HTTP 401
```

`DataScienceCluster` may also show `ogx` degraded / `ModulesReady: False`.

Two digests were seen across 3.5.0 → 3.5.1; **both** returned the same 401:

- `registry.redhat.io/rhoai/odh-ogx-core-rhel9@sha256:dc941e03121ee07ccc0540e598b11d24e97c125a3455ad66b4f0532f567e046e`
- `registry.redhat.io/rhoai/odh-ogx-core-rhel9@sha256:7eeac2aa61faf264084df755c9c1575526371b46ec63acc1985598b644882cfb`

### Root cause

The OGX operator makes a **second, in-process** HTTP call to `registry.redhat.io` to read OCI image **config labels** (the `com.ogx.config.config.yaml` label used for “generated config”). That call is **anonymous / incorrectly authenticated**.

It is **not** the same path as a normal image pull. A throwaway Pod using the **exact same digest** pulls successfully via kubelet/CRI-O with the cluster pull secret (~5.3GB image). So registry credentials and egress are fine for pulls; only the operator’s label-fetch client is broken.

### What was ruled out (do not re-litigate)

| Hypothesis | Result |
|---|---|
| Operator RBAC cannot read pull secrets | Ruled out — manager ClusterRoles already have cluster-wide get/list/watch on Secrets |
| Stale credential cache in the operator process | Ruled out — restarting `ogx-k8s-operator-controller-manager` and `opendatahub-ogx-operator` did not help |
| `rh` vs `rh-dev` distribution → different images | Ruled out for this 401 — both resolve via the same `RELATED_IMAGE_ODH_OGX_CORE_IMAGE` env on the operator Deployment |
| Mounting pull secret as `$HOME/.docker/config.json` on the operator | Ruled out — operator’s registry client does not honor that path for this feature |
| CRD field to pass registry creds for OCI-label fetch | Ruled out — only provider API-key style secret refs exist, not registry auth for labels |
| 3.5.0 → 3.5.1 point release | Ruled out — identical 401 after auto-upgrade |

### Debug

```bash
oc get ogxserver "$NAME" -n "$NS" -o jsonpath='{.status.conditions}' | jq .
# Look for "HTTP 401" and "OCI labels"

DIGEST=$(oc get deployment -n redhat-ods-applications \
  -l app.kubernetes.io/name=ogx-k8s-operator \
  -o jsonpath='{.items[0].spec.template.spec.containers[0].env[?(@.name=="RELATED_IMAGE_ODH_OGX_CORE_IMAGE")].value}')
echo "$DIGEST"
```

### Partial workaround (`baseConfig`) — clears 401 only

This stops the operator from calling the registry for labels. **It does not produce a working AutoRAG stack by itself** — continue through bugs 2–5, or jump to the **complete manual fix** at the end of this document.

```bash
# 1) Extract com.ogx.config.config.yaml from the pinned image using the cluster pull secret
DIGEST=$(oc get deployment -n redhat-ods-applications \
  -l app.kubernetes.io/name=ogx-k8s-operator \
  -o jsonpath='{.items[0].spec.template.spec.containers[0].env[?(@.name=="RELATED_IMAGE_ODH_OGX_CORE_IMAGE")].value}')

oc get secret pull-secret -n openshift-config \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > /tmp/ps.json

# Prefer authenticated image inspect. Label value may be raw YAML or base64 — try both.
oc image info "$DIGEST" --registry-config=/tmp/ps.json --filter-by-os=linux/amd64 -o json > /tmp/ogx-image.json
rm -f /tmp/ps.json

python3 <<'PY'
import json, base64, sys
d = json.load(open("/tmp/ogx-image.json"))
labels = d["config"]["config"]["Labels"]
raw = labels.get("com.ogx.config.config.yaml") or ""
if not raw:
    sys.exit("label com.ogx.config.config.yaml missing")
try:
    text = base64.b64decode(raw).decode()
except Exception:
    text = raw
open("/tmp/ogx-config.yaml", "w").write(text)
print("wrote /tmp/ogx-config.yaml (%d bytes)" % len(text))
PY

# 2) ConfigMap + label (label is mandatory — see bug 2)
oc create configmap rh-ogx-base-config \
  --from-file=config.yaml=/tmp/ogx-config.yaml -n "$NS" \
  --dry-run=client -o yaml | oc apply -f -
oc label configmap rh-ogx-base-config ogx.io/watch=true -n "$NS" --overwrite

# 3) Point OGXServer at it
oc patch ogxserver "$NAME" -n "$NS" --type=merge \
  -p '{"spec":{"baseConfig":{"name":"rh-ogx-base-config","key":"config.yaml"}}}'
```

**Expected after this alone:** `ConfigGenerated` succeeds (often “13 providers”), Phase moves off Failed toward Initializing. Pod may still CrashLoop — that is bugs 3–4, not a regression of this step.

Delete `/tmp/ogx-config.yaml` / `/tmp/ogx-image.json` when done (config may embed environment-specific endpoints).

---

## Bug 2 — Secret / ConfigMap “not found” (object exists)

### Symptom

Operator reports Secret (or ConfigMap) not found. Meanwhile:

```bash
oc get secret <secret-name> -n "$NS"   # exists
```

RBAC on the operator is fine.

### Root cause

The OGX operator’s namespace-scoped informer cache **only watches** objects labeled:

```text
ogx.io/watch=true
```

Unlabeled Secrets/ConfigMaps are invisible even when they exist and RBAC allows access. Separate bug from the OCI 401.

### Debug

```bash
oc get secret,configmap -n "$NS" --show-labels
oc get ogxserver "$NAME" -n "$NS" -o yaml | grep -iE 'secret|configmap|baseConfig|overrideConfig'
```

### Manual fix

Label **every** Secret and ConfigMap the `OGXServer` references (credentials, `llama-stack-config`, `rh-ogx-base-config`, CA bundles, etc.):

```bash
oc label secret <secret-name> ogx.io/watch=true -n "$NS" --overwrite
oc label configmap <configmap-name> ogx.io/watch=true -n "$NS" --overwrite
```

Then force reconcile if needed (annotation bump or trivial no-op patch on the `OGXServer`).

---

## Bug 3 — CrashLoopBackOff: `EnvVarError` (empty API tokens)

### Symptom

OGX pod restarts. Logs show `EnvVarError` (or equivalent) for empty:

- `VLLM_API_TOKEN` / `VLLM_API_TOKEN_1`
- `VLLM_EMBEDDING_API_TOKEN` / similar

### Root cause

OGX rejects **empty-string** env vars. In-cluster vLLM / embedding endpoints often need no auth, so people set `""` and the process crashes on start.

### Debug

```bash
oc logs -l app.kubernetes.io/instance="$NAME" -n "$NS" --tail=100
oc get ogxserver "$NAME" -n "$NS" -o yaml | grep -A2 -E 'TOKEN|API_KEY'
# If a Deployment already exists:
oc set env deployment/"$NAME" -n "$NS" --list 2>/dev/null | grep -i token
```

### Manual fix

Set a non-empty placeholder (internal services ignore it), e.g. `unused`:

```bash
oc patch ogxserver "$NAME" -n "$NS" --type=json -p '[
  {"op":"add","path":"/spec/workload/overrides/env/-","value":{"name":"VLLM_API_TOKEN_1","value":"unused"}},
  {"op":"add","path":"/spec/workload/overrides/env/-","value":{"name":"VLLM_EMBEDDING_API_TOKEN","value":"unused"}}
]'
```

If those keys already exist with `""`, edit the CR and replace the values, or remove the empty entries and re-add. Confirm:

```bash
oc get ogxserver "$NAME" -n "$NS" -o yaml | grep -A1 'VLLM_API_TOKEN'
```

---

## Bug 4 — CrashLoop after config OK: CRD merge strips Milvus fields

### Symptom

Bug 1 is cleared (`ConfigGenerated` succeeded) but the pod still CrashLoopBackOff. Logs / startup errors mention `MilvusVectorIOConfig`, pydantic `ValidationError`, missing:

- `token` (string)
- `persistence.backend`

### Root cause

With `distribution.name: rh` + `spec.baseConfig` + `spec.providers`, the operator **merges** config and **strips** fields the Python runtime’s pydantic models require. The GenAI Playground working pattern avoids that path entirely by using **`spec.overrideConfig`**: the ConfigMap **is** the config; the operator does not regenerate/merge providers.

### Debug

```bash
oc get ogxserver "$NAME" -n "$NS" -o yaml
# Bad:  distribution.name: rh  +  providers: {...}  +  only baseConfig
# Good: distribution.name: rh-dev  +  overrideConfig: {...}  +  NO providers block

oc logs -l app.kubernetes.io/instance="$NAME" -n "$NS" --tail=200 | \
  grep -iE 'MilvusVectorIO|pydantic|ValidationError|persistence|\.token'
```

### Manual fix (required for AutoRAG)

1. Obtain a full working `llama-stack-config` ConfigMap (copy from a Ready Playground / OGX namespace, or extract OCI label YAML as in bug 1 and expand it with working provider blocks).
2. Apply it in `<ns>`, label `ogx.io/watch=true`.
3. Ensure pgvector (or whatever `vector_io` the config expects) is running; inject `PGVECTOR_*` via `workload.overrides.env`.
4. Reshape the `OGXServer`:
   - `distribution.name: **rh-dev**`
   - `overrideConfig.name: llama-stack-config`, `overrideConfig.key: config.yaml`
   - **Remove** `spec.providers`
   - Prefer removing reliance on `baseConfig` once `overrideConfig` is in place
   - Non-empty `VLLM_API_TOKEN_*` (bug 3)
   - Offline HF flags are normal on the rh-dev image (`HF_HUB_OFFLINE=1`) — see bug 5

Example shape (adjust names/hosts/passwords):

```yaml
apiVersion: ogx.io/v1beta1
kind: OGXServer
metadata:
  name: <ogx-name>
  namespace: <ns>
spec:
  distribution:
    name: rh-dev
  network:
    port: 8321
    externalAccess:
      enabled: true
  overrideConfig:
    name: llama-stack-config
    key: config.yaml
  workload:
    overrides:
      command:
        - /bin/sh
        - -c
        - ogx run /etc/ogx/config.yaml --insecure
      env:
        - name: VLLM_TLS_VERIFY
          value: "false"
        - name: HF_HUB_OFFLINE
          value: "1"
        - name: TRANSFORMERS_OFFLINE
          value: "1"
        - name: HF_DATASETS_OFFLINE
          value: "1"
        - name: VLLM_MAX_TOKENS_1
          value: "4096"
        - name: VLLM_API_TOKEN_1
          value: "unused"
        - name: PGVECTOR_HOST
          value: "genai-pgvector.<ns>.svc.cluster.local"
        - name: PGVECTOR_PORT
          value: "5432"
        - name: PGVECTOR_DB
          value: vectordb
        - name: PGVECTOR_USER
          value: vectoruser
        - name: PGVECTOR_PASSWORD
          valueFrom:
            secretKeyRef:
              name: genai-pgvector-credentials
              key: password
      replicas: 1
```

Do **not** go back to `rh` + `baseConfig` + CRD `providers` on 3.5.0/3.5.1 for AutoRAG.

---

## Bug 5 — Pipeline fails at `search-space-preparation` (nomic offline)

### Symptom

AutoRAG optimization run starts, then fails in **search-space-preparation** (or an early pipeline step). Logs mention **nomic** / `nomic-embed-text` / `nomic-ai/...` / Hugging Face download errors.

### Root cause

The base OGX config often **registers** `nomic-ai/nomic-embed-text` (shown as an embedding choice in AutoRAG). The OGX workload typically runs with:

```text
HF_HUB_OFFLINE=1
TRANSFORMERS_OFFLINE=1
```

so models not already in the image **cannot** be downloaded. AutoRAG still offers nomic → pipeline dies when it tries to load it.

### Debug

```bash
oc get configmap llama-stack-config -n "$NS" \
  -o jsonpath='{.data.config\.yaml}' | grep -i nomic

oc logs <pipeline-pod> -n "$NS" --all-containers --tail=300 | \
  grep -iE 'nomic|search.space|HF_HUB|offline|embedding'
```

### Manual fix

**A. Strip nomic from the ConfigMap** (recommended):

```bash
oc get configmap llama-stack-config -n "$NS" \
  -o jsonpath='{.data.config\.yaml}' > /tmp/llama-stack-config.yaml

python3 <<'PY'
import yaml
cfg = yaml.safe_load(open("/tmp/llama-stack-config.yaml"))
models = cfg.get("registered_resources", {}).get("models", [])
cfg.setdefault("registered_resources", {})["models"] = [
    m for m in models
    if "nomic-ai" not in str(m.get("provider_model_id", ""))
    and "nomic-ai" not in str(m.get("model_id", ""))
]
yaml.dump(cfg, open("/tmp/llama-stack-config.yaml", "w"), default_flow_style=False, sort_keys=False)
print("models left:", len(cfg["registered_resources"]["models"]))
PY

oc create configmap llama-stack-config \
  --from-file=config.yaml=/tmp/llama-stack-config.yaml -n "$NS" \
  --dry-run=client -o yaml | oc apply -f -
oc label configmap llama-stack-config ogx.io/watch=true -n "$NS" --overwrite
```

Restart the OGX pod if it does not reload config automatically:

```bash
oc delete pod -l app.kubernetes.io/instance="$NAME" -n "$NS"
```

**B. In the AutoRAG UI**, do not select nomic. Prefer a remote embedding InferenceService you actually deployed (e.g. CPU **bge-m3**) or a model pre-cached in the OGX image (e.g. granite embedding, if present in config).

---

## Bug 6 — Objects created in `default`

### Symptom

You intended project `<ns>`, but:

```bash
oc get ogxserver -A
# shows <ogx-name> in namespace "default"
```

### Root cause

`oc apply` without `-n` / with empty namespace substitution falls back to the current context namespace, often `default`. Common after partial re-applies when templates leave `namespace:` blank.

### Debug / fix

```bash
oc get ogxserver,configmap,secret -A | grep -i ogx
# Delete misplaced objects from default, recreate in the correct project:
oc delete ogxserver "$NAME" -n default --ignore-not-found
oc apply -n "$NS" -f <your-ogxserver.yaml>
```

Always pass `-n "$NS"` explicitly on every apply/patch.

---

## Related — MaaS URL as OGX inference endpoint

### Symptom

OGX Ready, but chat / RAG / pipeline steps get **401 / 403 / 404** talking to the model.

### Cause

`llama-stack-config` (often copied from Playground) has vLLM `base_url` pointing at the **MaaS / inference-gateway** external route. MaaS needs a real bearer token. Placeholder tokens like `unused` work only against **unauthenticated in-cluster** InferenceService / LLMInferenceService URLs.

### Debug

```bash
oc get configmap llama-stack-config -n "$NS" \
  -o jsonpath='{.data.config\.yaml}' | grep -iE 'base_url|maas|inference'
```

### Manual fix

Find a Ready in-cluster LLM service and rewrite `base_url`:

```bash
# Example discovery — pick a Ready LLMInferenceService workload Service
oc get llminferenceservice -A
# Build internal URL, e.g.:
#   https://<svc>.<model-ns>.svc.cluster.local:8000/v1
# or the InferenceService predictor URL your cluster uses.

# Then edit /tmp/llama-stack-config.yaml and replace maas / apps.* base_url values,
# re-apply the ConfigMap, label ogx.io/watch=true, restart the OGX pod.
```

---

## Complete manual recovery (bugs 1–5 in one pass)

Use this when AutoRAG OGX is broken end-to-end. Adjust names/hosts.

### 1) Namespace and watch-label discipline

```bash
NS=<ns>
NAME=<ogx-name>
oc project "$NS"   # optional; still always pass -n
```

### 2) pgvector (if config expects PGVECTOR_*)

Deploy a Postgres+pgvector instance in `$NS`, create Secret `genai-pgvector-credentials` with key `password`, Service DNS `genai-pgvector.$NS.svc.cluster.local:5432`, DB/user matching the env you will set on the OGXServer. Label the Secret:

```bash
oc label secret genai-pgvector-credentials ogx.io/watch=true -n "$NS" --overwrite
```

### 3) Build `llama-stack-config`

**Preferred:** copy from a namespace that already has a **Ready** OGX / Playground config:

```bash
SRC=<namespace-with-working-llama-stack-config>
oc get configmap llama-stack-config -n "$SRC" -o json \
  | jq "del(.metadata.uid,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.managedFields,.metadata.ownerReferences)
        | .metadata.namespace=\"$NS\" | .metadata.name=\"llama-stack-config\"" \
  | oc apply -f -
```

**Fallback:** extract OCI label YAML (bug 1 commands) into the ConfigMap.

Then:

- Strip nomic (bug 5 python snippet)
- Rewrite any `base_url: https://maas...` to the in-cluster LLM URL (MaaS section)
- Label:

```bash
oc label configmap llama-stack-config ogx.io/watch=true -n "$NS" --overwrite
```

### 4) Apply / reshape OGXServer

Apply an `OGXServer` matching the **bug 4 example** (`rh-dev`, `overrideConfig`, no `providers`, non-empty tokens, PGVECTOR env). Label any other Secrets it references with `ogx.io/watch=true`.

### 5) Verify

```bash
oc get ogxserver "$NAME" -n "$NS"
# PHASE Ready

oc get pods -n "$NS" | grep "$NAME"
# Running, not CrashLoopBackOff

oc logs -l app.kubernetes.io/instance="$NAME" -n "$NS" --tail=50
```

### 6) AutoRAG run

In the dashboard, create the optimization run using your S3 + OGX connections. **Do not** select nomic embeddings. If search-space-preparation still fails, re-check ConfigMap for `nomic` and pipeline pod logs (bug 5).

---

## What “good” looks like

```text
oc get ogxserver <ogx-name> -n <ns>
→ Phase: Ready

oc get pods -n <ns> | grep <ogx-name>
→ 1/1 Running

AutoRAG run progresses past search-space-preparation without nomic/HF download errors.
```

Milvus, embedding InferenceService, S3, and the pipeline server can all be healthy while OGX is still Failed — fix the OGX cascade above before blaming those components.
