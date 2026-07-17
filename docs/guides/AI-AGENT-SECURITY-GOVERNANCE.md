# AI Agent Security & Governance on Red Hat OpenShift AI

## Overview

This document addresses enterprise security questions for AI agents deployed on Red Hat OpenShift AI (RHOAI) 3.4+, incorporating both current GA capabilities and the upcoming Kagenti agent governance framework.

---

## A. Proposed Guardrails for AI Agents

### Current Implementation (RHOAI 3.4 GA)

RHOAI 3.4 provides **two complementary guardrail systems** under the TrustyAI operator:

#### 1. NeMo Guardrails (GA in 3.4)

CRD-based deployment via `NemoGuardrails` (`trustyai.opendatahub.io/v1alpha1`). Provides:

| Rail Type | Description | LLM Required |
|-----------|-------------|:---:|
| **Presidio PII Detection** | Detects/masks EMAIL, PERSON, PHONE, CREDIT_CARD entities | No |
| **Regex Pattern Detection** | Blocks passwords, secrets, API keys, SSN patterns | No |
| **LLM Self-Check Input** | AI validates user input against policy before processing | Yes |
| **LLM Self-Check Output** | AI validates generated response before returning | Yes |

**Deployment:**
```bash
# Basic (built-in detectors, no LLM needed)
./demo/nemo-guardrails-demo/deploy.sh

# With LLM-powered self-check content filtering
./demo/nemo-guardrails-demo/deploy.sh --selfcheck
```

**API Endpoint:** `POST /v1/guardrail/checks` — standalone policy check that returns `success` or `blocked` with reasons.

**Key features (3.4):**
- Full OpenAI API compatibility (`/v1/models/`, `/v1/chat/completions`)
- Multi-replica support for HA/scalability
- OpenTelemetry observability out of the box
- Automatic redeployment on config changes (zero-downtime)
- Streaming support for output rails

#### 2. Guardrails Orchestrator (Gateway Pipelines)

CRD: `GuardrailsOrchestrator` — provides preset pipeline endpoints:

| Endpoint | Behavior |
|----------|----------|
| `/pii/v1/chat/completions` | Full PII filtering (email, SSN, credit card, phone, IPv4) |
| `/safe/v1/chat/completions` | All safety checks (PII + extensible detectors) |
| `/passthrough/v1/chat/completions` | No filtering — direct to model |

#### 3. MCP Gateway Guardrails (Future — Kagenti Integration)

The MCP Gateway (Kuadrant-based) will integrate with TrustyAI and NeMo to:
- **Inspect traffic payloads** for prompt injection attempts
- **Block safety violations** before they reach tools/databases
- **Rate-limit** agent-driven requests to prevent denial-of-service
- **Audit log** all tool usage for compliance

### Proposed Implementation Architecture

```
User Request → MCP Gateway → NeMo Guardrails → Agent → Tool/DB
                  │                  │                      │
                  ├─ JWT validation  ├─ PII detection       ├─ Read-only enforcement
                  ├─ Rate limiting   ├─ Prompt injection    ├─ Sandboxed execution
                  └─ Audit logging   └─ Topic filtering     └─ Result masking
```

---

## B. Proposed Access Controls for AI Agents

### Current Implementation (RHOAI 3.4 MaaS)

RHOAI 3.4 implements a **multi-layer access control model** for model endpoints:

#### Layer 1: OpenShift RBAC + Groups

```bash
# Create user groups with tiered access
oc adm groups new rhods-admins
oc adm groups new rhods-users
oc adm groups add-users rhods-users user1 user2 user3
```

#### Layer 2: MaaS Subscriptions (Token Rate Limits)

```yaml
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSSubscription
metadata:
  name: team-sub
  namespace: models-as-a-service
spec:
  modelRefs:
    - name: qwen3-8b
      namespace: 0-demo
      tokenRateLimits:
        - limit: 10000
          window: 5m
  owner:
    groups:
      - name: rhods-users
  priority: 1
```

#### Layer 3: MaaS Authorization Policies

```yaml
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSAuthPolicy
metadata:
  name: team-auth
  namespace: models-as-a-service
spec:
  modelRefs:
    - name: qwen3-8b
      namespace: 0-demo
  subjects:
    groups:
      - name: rhods-users
```

#### Layer 4: API Key Authentication (Authorino + PostgreSQL)

Request flow enforced at the gateway:

| Step | Component | Action |
|------|-----------|--------|
| 1 | Client | `Authorization: Bearer <api-key>` |
| 2 | OpenShift Router | Passthrough Route → gateway |
| 3 | Gateway Envoy | TLS termination, ext_authz → Authorino |
| 4 | Authorino | Validates API key via PostgreSQL, checks MaaSAuthPolicy |
| 5 | Limitador | TokenRateLimitPolicy enforcement |
| 6 | Model Pod | Request routed via HTTPRoute |

### Future Implementation (Kagenti — Zero Trust AI Agents)

Kagenti introduces **zero-trust identity** for AI agents themselves, not just users:

#### SPIFFE/SPIRE Workload Identity

Each agent pod receives a **cryptographic workload identity** (SVID) — no static secrets:

- **Automatic injection**: When an `AgentRuntime` CRD is created, pods get 2 sidecars:
  - `spiffe-helper`: Fetches/rotates X.509 SVIDs from SPIRE
  - `kagenti-client-registration`: Registers agent as OAuth2 client in Keycloak
- **No static secrets**: No ConfigMap credentials, no long-lived API keys as env vars
- **Cross-cluster**: SPIFFE IDs work across clusters and cloud providers
- **Auto-rotated**: Short-lived certificates, automatically refreshed

#### OAuth2 Token Exchange (RFC 8693)

```
User authenticates with Keycloak → receives access token
    → Agent receives user context via delegated token
        → Agent identity attested by SPIRE
            → Tool access uses exchanged tokens with minimal scope
```

Key properties:
- **No Static Secrets** — credentials dynamically generated at pod startup
- **Short-Lived Tokens** — JWT tokens expire and must be refreshed
- **Audience Scoping** — tokens scoped to specific services, preventing reuse
- **Transparent to Application** — token exchange handled by sidecar

#### MCP Gateway Policy Enforcement

The Kagenti MCP Gateway (Envoy-based) provides:
- **Identity-based tool filtering** — removes unauthorized tools from `tools/list` discovery entirely
- **Centralized authentication** — OAuth 2.0 with correctly scoped tokens
- **Least-privilege routing** — agents only possess permissions required for a given task
- **Rate limiting** — prevents agent-driven denial-of-service
- **Audit logging** — tracks all tool usage

#### Istio Ambient Mesh (mTLS)

All inter-agent communication encrypted via Istio Ambient:
- **ztunnel** proxy (shared per-node, Rust-based) handles L4 mTLS
- **No sidecar injection** needed — works with LLM inference containers
- TLS 1.3+ enforced for all A2A traffic

### Proposed Combined Access Control Matrix

| Layer | Technology | Scope | Status |
|-------|------------|-------|--------|
| Network mTLS | Istio Ambient Mesh | Pod-to-pod encryption | Kagenti (available now) |
| Workload Identity | SPIFFE/SPIRE | Agent authentication | Kagenti (available now) |
| Token Exchange | Keycloak + OAuth2 | Agent-to-tool authorization | Kagenti (available now) |
| MCP Gateway | Kuadrant/Envoy | Tool access policy | Kagenti (available now) |
| Model Access | MaaSAuthPolicy + Authorino | Model endpoint auth | RHOAI 3.4 GA |
| Rate Limits | MaaSSubscription + Limitador | Token consumption limits | RHOAI 3.4 GA |
| User Groups | OpenShift RBAC | Group-based permissions | RHOAI 3.4 GA |
| API Keys | Authorino + PostgreSQL | Bearer token validation | RHOAI 3.4 GA |

---

## C. Protecting Database Data from AI Agents

### The Risk

AI agents with tool access (via MCP) can potentially:
- Execute destructive SQL (DROP, DELETE, TRUNCATE)
- Exfiltrate sensitive data through crafted prompts
- Overwhelm databases via unbounded queries
- Modify data through prompt injection attacks

### Proposed Multi-Layer Protection

#### Layer 1: Read-Only MCP Server Configuration

The MCP server for OpenShift supports explicit read-only mode:

```yaml
read_only = true
```

**Behavior**: The server denies any write operations regardless of what the AI agent requests. Sandboxing ensures that even if the model attempts undesired actions (e.g., delete data), the server denies based on internal rules.

#### Layer 2: SQL Execution Sandboxing (EDB Data Governance Pattern)

Red Hat's reference architecture with EDB Postgres AI demonstrates:

- **Restricted Mode (default for production)**: AST-level SQL validation that:
  - Limits operations to read-only transactions
  - Globally blocks DROP commands in all modes
  - Imposes resource utilization constraints
  - Prevents schema modification
- **Governance Policy Enforcement**: AI-generated SQL is validated against uploaded governance policies before execution
- **PII Filtering**: Query results are filtered through governance rules — raw PII never reaches the chat interface

#### Layer 3: NeMo Guardrails Input/Output Filtering

Guardrails intercept prompts before they reach tool-calling agents:

```yaml
rails:
  config:
    sensitive_data_detection:
      input:
        entities:
          - EMAIL_ADDRESS
          - CREDIT_CARD
          - PHONE_NUMBER
    regex_detection:
      input:
        patterns:
          - "\\b(DROP|DELETE|TRUNCATE|ALTER)\\b"
          - "\\b(password|secret|api[_-]?key|token)\\b"
```

#### Layer 4: MCP Gateway Rate Limiting & Audit

- **Rate limiting** prevents agents from executing unbounded queries
- **Comprehensive audit logging** tracks every tool invocation
- **Identity-based tool filtering** removes destructive tools from agent discovery

#### Layer 5: Database-Level Permissions

Standard PostgreSQL/database RBAC still applies:

```sql
-- Create a read-only role for AI agent connections
CREATE ROLE ai_agent_readonly;
GRANT CONNECT ON DATABASE mydb TO ai_agent_readonly;
GRANT USAGE ON SCHEMA public TO ai_agent_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ai_agent_readonly;

-- Explicitly deny write operations
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM ai_agent_readonly;
```

#### Layer 6: Network Isolation (OpenShift)

- AI agent pods run in dedicated namespaces
- NetworkPolicies restrict which pods can reach database services
- Service Mesh policies enforce mTLS between agent and database

### Proposed Architecture for Database Protection

```
AI Agent
    │
    ├─ Layer 1: NeMo Guardrails (blocks dangerous prompts)
    │
    ├─ Layer 2: MCP Gateway (identity check, tool filtering, rate limit)
    │
    ├─ Layer 3: MCP Server (read_only=true, sandbox enforcement)
    │
    ├─ Layer 4: SQL Validator (AST-level, governance policy compliance)
    │
    ├─ Layer 5: Database RBAC (read-only role, minimal privileges)
    │
    └─ Layer 6: Network Policy (namespace isolation, mTLS)
```

---

## D. Vector Database Encryption Support

### Current State

RHOAI supports vector databases (Milvus, pgvector, Redis) for RAG workloads via the Llama Stack operator. Encryption is implemented at multiple levels:

### Encryption in Transit (TLS)

| Vector DB | TLS Support | Configuration |
|-----------|:-----------:|---------------|
| Milvus | Yes | `tls.md` — server/client certificate configuration |
| pgvector (PostgreSQL) | Yes | `sslmode=require` in connection string |
| Redis | Yes | TLS-enabled cluster configuration |

All supported within OpenShift via:
- **Service-CA certificates** (internal cluster communication)
- **cert-manager** (external-facing endpoints)
- **Istio Ambient mTLS** (pod-to-pod, transparent)

### Encryption at Rest

#### Option 1: Storage-Level Encryption (Recommended — Available Now)

OpenShift provides transparent encryption at the storage layer:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: encrypted-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:region:account:key/key-id"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

- **AWS EBS**: AES-256 encryption with AWS KMS (CMK or AWS-managed)
- **Azure Disk**: Server-side encryption with platform or customer-managed keys
- **GCP PD**: Default encryption + CMEK option
- All PVCs provisioned from encrypted StorageClass get automatic encryption

#### Option 2: Object Storage Encryption (Milvus with S3)

For Milvus in cluster mode using S3-compatible storage:

- **S3 SSE-S3**: Amazon-managed keys (default)
- **S3 SSE-KMS**: Customer-managed keys via AWS KMS
- **S3 SSE-C**: Customer-provided keys per request
- **MinIO**: Server-side encryption with KES (Key Encryption Service)

Configure in Milvus:
```yaml
minio:
  address: minio.namespace.svc.cluster.local
  port: 9000
  useSSL: true
  # S3 SSE enabled at bucket level
```

#### Option 3: Database-Native Encryption (pgvector)

PostgreSQL with pgvector inherits all PostgreSQL encryption capabilities:

- **Transparent Data Encryption (TDE)** — available via EDB Postgres
- **Column-level encryption** — `pgcrypto` extension for sensitive columns
- **Full-disk encryption** — via encrypted PVCs (Option 1)

#### Option 4: Application-Level Encryption

For maximum control, encrypt vectors before storage:

```python
from cryptography.fernet import Fernet

key = Fernet.generate_key()
f = Fernet(key)

# Encrypt embedding before storing in vector DB
encrypted_embedding = f.encrypt(embedding.tobytes())

# Decrypt after retrieval
decrypted_embedding = np.frombuffer(f.decrypt(encrypted_embedding), dtype=np.float32)
```

> **Note:** Application-level encryption of vectors **breaks similarity search** — encrypted vectors cannot be compared. Use this only for metadata fields, not the vector data itself. For vector data, rely on storage-level or database-level encryption.

### Recommended Encryption Strategy

| Layer | Method | Protects Against |
|-------|--------|-----------------|
| **Transit** | mTLS (Istio Ambient) + TLS (service-ca) | Network sniffing, MITM |
| **At Rest (Storage)** | Encrypted StorageClass (KMS-backed) | Physical disk theft, volume snapshots |
| **At Rest (Object)** | S3 SSE-KMS | Unauthorized S3 access |
| **Access Control** | Milvus RBAC + OpenShift NetworkPolicy | Unauthorized database access |
| **Metadata** | pgcrypto / application encryption | PII in metadata fields |

### Research Context

Recent research ([Text Embeddings Reveal Almost As Much As Text](https://arxiv.org/pdf/2310.06816)) demonstrates that text embeddings can be inverted to reconstruct original text. This makes encryption at rest critical for vector databases containing sensitive content.

Milvus roadmap includes native BYOK (Bring Your Own Key) encryption support. Until then, storage-level encryption via encrypted PVCs/S3 buckets is the recommended approach on OpenShift.

---

## References

- [RHOAI 3.4 Enabling AI Safety with Guardrails](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html-single/enabling_ai_safety_with_guardrails/index)
- [Kagenti — Deploy, Secure, and Govern AI Agents](https://kagenti.github.io/.github/)
- [Kagenti Identity & Authorization Guide](https://github.com/kagenti/kagenti/blob/main/docs/identity-guide.md)
- [Zero Trust AI Agents on Kubernetes (Red Hat Emerging Tech)](https://next.redhat.com/2026/03/05/zero-trust-ai-agents-on-kubernetes-what-i-learned-deploying-multi-agent-systems-on-kagenti/)
- [How Kagenti ADK Simplifies Production AI Agent Management](https://developers.redhat.com/articles/2026/05/04/how-kagenti-adk-simplifies-production-ai-agent-management)
- [MCP Security: Logging and Runtime Security Measures (Red Hat Blog)](https://www.redhat.com/en/blog/mcp-security-logging-and-runtime-security-measures)
- [Safe Data Discovery with EDB Data Governance Co-Pilot](https://www.redhat.com/en/blog/safe-data-discovery-edbs-data-governance-co-pilot-ai-quickstart)
- [MCP Server Overview (OKD Documentation)](https://docs.okd.io/latest/ai_applications/mcp_server/mcp-server-overview.html)
- [Milvus Encryption at Rest Discussion](https://github.com/milvus-io/milvus/issues/33810)
- [Milvus TLS Configuration](https://milvus.io/docs/tls.md)
