# RHOAI Toolkit — Agent Context

Automation toolkit for Red Hat OpenShift AI (RHOAI) on AWS with GPU, MaaS, and GenAI.

## Directory Layout

- `rhoai-toolkit.sh` — Main interactive menu (~315 lines, sources ~14,300 lines from lib/)
- `scripts/` — Standalone entry-point scripts (thin wrappers calling functions)
- `lib/functions/` — Reusable bash functions (`install.sh`, `rhoai.sh`, `operators.sh`, `model-deployment.sh`)
- `lib/versions/` — Version profile configs (`rhoai-34.conf`, `rhoai-33.conf`) for the unified installer
- `lib/manifests/` — Kubernetes YAML templates (envsubst-based, no logic)
- `lib/utils/` — Utility libraries (`os-compat.sh`, `colors.sh`, `common.sh`)
- `demo/` — Demo apps, each with its own `deploy.sh`
- `docs/guides/` — How-to guides; `docs/reference/` — Technical reference
- `Makefile` — CLI automation targets

## Code Conventions

- **Zero inline manifests**: all Kubernetes YAML lives in `lib/manifests/` as files. Scripts use `envsubst < manifest.yaml | oc apply -f -`, never heredocs.
- **Modular functions**: each capability gets its own file in `lib/functions/` (e.g., `nemo-guardrails.sh`, `model-catalog.sh`). Do NOT add to the already-large `rhoai.sh` unless extending existing functionality.
- **Separation of concerns**: `lib/manifests/` = YAML only, `lib/functions/` = bash functions only, `scripts/` = entry points, `demo/*/deploy.sh` = per-demo orchestration.
- **macOS + Linux**: use `lib/utils/os-compat.sh` for `grep_perl`, `base64_encode`, `sed_inplace`, etc.
- **Colors**: source `lib/utils/colors.sh` for terminal output (`print_header`, `print_step`, `print_success`, `print_error`, `print_warning`, `print_info`).
- **Templates**: use `envsubst` for variable substitution — always `export` vars before, `unset` after.
- **Script headers**: use `################################################################################` block with script name, description, and `# Provides:` function listing.
- **Error handling**: `set -e` in standalone scripts; `2>/dev/null || true` for optional/idempotent operations.
- **envsubst pattern**: `export VAR="val"; envsubst < template.yaml | oc apply -f -; unset VAR`.

## Demo Environment (implemented)

Full demo environment with 11 components. See `docs/guides/DEMO-ENVIRONMENT.md` for the guide.

- **Deploy all**: `scripts/deploy-demo-environment.sh --skip-core`
- **Individual**: each `demo/*/deploy.sh` runs standalone
- **External repos**: configured in `lib/external-repos.conf`, cloned via `lib/functions/external-repos.sh`
- **New function files**: `lib/functions/external-repos.sh`, `model-catalog.sh`, `nemo-guardrails.sh`
- **New manifests**: `lib/manifests/demo/n8n.yaml`, `evalhub.yaml`, `lmeval-rbac.yaml`, `pipeline-workbench.yaml`, `financial-loan-workbench.yaml`; `lib/manifests/guardrails/nemo-guardrails-*.yaml`
- Marketing Assistant Demo is standalone only (3x L40S GPUs), not part of deploy-all

## Key Entry Points

| Script | Purpose |
|--------|---------|
| `rhoai-toolkit.sh` | Main interactive menu (start here) |
| `scripts/install-rhoai.sh` | Unified RHOAI 3.x installer (auto-detects version from channel) |
| `scripts/install-rhoai-34.sh` | Thin wrapper → `install-rhoai.sh --channel stable-3.4` |
| `scripts/install-rhoai-33.sh` | Thin wrapper → `install-rhoai.sh --channel stable-3.3` |
| `scripts/serve-model.sh` | Deploy model from S3/OCI with vLLM or llm-d |
| `scripts/deploy-nim.sh` | NVIDIA NIM platform setup + model deploy |
| `scripts/setup-letsencrypt-tls.sh` | Let's Encrypt / self-signed TLS automation |
| `scripts/deploy-dashboards.sh` | GPU/vLLM dashboards (Observe tab + Grafana) |
| `scripts/deploy-demo-environment.sh` | Deploy all demos |

## Critical Gotchas

- Hardware Profiles MUST include GPU tolerations (`nvidia.com/gpu` key) AND all 3 annotations: `hardware-profile-name`, `hardware-profile-namespace`, `hardware-profile-resource-version`
- Model serving CR depends on runtime: llm-d → `LLMInferenceService`, everything else → `InferenceService`
- MaaS 3.4: service-ca TLS (not cert-manager), gateway needs `opendatahub.io/managed: "false"`
- NeMo Guardrails (3.4): CRD-based via TrustyAI operator, requires SA + RoleBinding + API token secret
- NVIDIA NIM: requires NGC API key (`nvapi-...`), `NIM_SERVED_MODEL_NAME` env must match InferenceService name for Playground
- Feature Store dashboard visibility needs label `feature-store-ui: enabled`
- Tool calling parsers: `hermes` (Qwen), `llama3_json` (Llama), `mistral` (Mistral)
- Dashboard URL by version: 3.4+ → `rh-ai.apps.<cluster>`, 3.3 → `data-science-gateway.apps.<cluster>`
- Observability (COO + Perses + Observe dashboards) runs unconditionally in install-rhoai-34.sh
- MLflow auto-detects MaaS PostgreSQL and uses it as backend; falls back to SQLite
- Let's Encrypt TLS: `scripts/setup-letsencrypt-tls.sh` or Strategy 0 auto-trigger in `create_gateway_tls_secret()`
- MCP servers: 8 deployable via `lib/menus/mcp.sh` or `manage-mcp-servers.sh deploy <name>`
