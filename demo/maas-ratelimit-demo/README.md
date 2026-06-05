# MaaS Rate Limiting Demo

Test MaaS API key authentication and token rate limiting enforcement in a workbench.

## What It Demonstrates

1. **API Key auth** -- `sk-oai-` keys generated from Gen AI Studio, validated by Authorino via PostgreSQL
2. **Token rate limits** -- `MaaSSubscription` enforces token budgets per subscription window
3. **HTTP 429 behavior** -- what clients see when they exceed their token quota
4. **Burst vs sustained load** -- how the gateway handles different traffic patterns
5. **Multi-subscription comparison** -- side-by-side testing of premium vs free tier limits

## Deploy

```bash
./deploy.sh                    # Deploys workbench in maas-ratelimit-demo namespace
./deploy.sh --delete           # Remove
```

## Usage

1. Deploy the workbench
2. Generate an API key: **RHOAI Dashboard > Gen AI Studio > API Keys > Create API key**
3. Open the workbench and upload `maas-ratelimit-test.ipynb`
4. Paste your API key into the notebook and run the cells

## What the Notebook Tests

| Test | What It Does |
|------|-------------|
| Test 1 | Single request -- verifies API key, endpoint, model work |
| Test 2 | Reads rate limit headers from response |
| Test 3 | Sustained load -- sends requests until 429 (exhausts token budget) |
| Test 4 | Burst load -- rapid fire with no delay |
| Test 5 | Charts cumulative token usage vs rate limit threshold |
| Test 6 | Compares two API keys with different subscription limits |

## Prerequisites

- Model published to MaaS (`MaaSModelRef` + `MaaSSubscription` + `MaaSAuthPolicy`)
- MaaS rate limiting fixes applied (see `docs/maas-token-ratelimit-span-buffer-bug.md`)
- PostgreSQL configured for API key validation
