# MaaS Policy Enforcement Guide

## Overview

Model as a Service (MaaS) uses **Kuadrant** (part of RHCL - Red Hat Connectivity Link) for policy enforcement, including authentication, rate limiting, and access control.

## Architecture

```
User Request
    ↓
MaaS Gateway (OpenShift Gateway API)
    ↓
Kuadrant Policies (AuthPolicy, RateLimitPolicy)
    ↓
Authorino (Authentication/Authorization)
    ↓
Model Endpoint (llm-d instance)
```

## Key Components

### 1. **OpenShift Gateway API**
- Entry point for all MaaS traffic
- Routes requests to the MaaS API
- Enforces policies via Kuadrant

### 2. **Kuadrant**
- Policy enforcement framework
- Provides `AuthPolicy` and `RateLimitPolicy` CRDs
- Integrates with Authorino and Limitador

### 3. **Authorino**
- Handles authentication and authorization
- Validates Kubernetes service account tokens
- Checks token audiences

### 4. **MaaS API**
- Token generation endpoint
- Model listing and management
- Billing/usage tracking

## Policy Enforcement Flow

### Step 1: MaaS Infrastructure Setup

According to the CAI guide, the cluster administrator must:

#### 1.1 Create GatewayClass
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-default
spec:
  controllerName: openshift.io/gateway-controller/v1
```

#### 1.2 Create MaaS Namespace
```bash
oc create namespace maas-api
```

#### 1.3 Deploy MaaS API Objects
```bash
export CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')

oc apply --server-side=true \
  -f <(kustomize build "https://github.com/opendatahub-io/maas-billing.git/deployment/overlays/openshift?ref=main" | \
       envsubst '$CLUSTER_DOMAIN')
```

This deploys:
- MaaS API deployment
- Gateway and HTTPRoute
- **AuthPolicy** (maas-api-auth-policy)
- Services and ConfigMaps

### Step 2: Configure AuthPolicy Audience

**Critical step**: The AuthPolicy must be configured with the correct token audience.

#### 2.1 Extract Audience from Token
```bash
AUD="$(oc create token default --duration=10m 2>/dev/null | cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.aud[0]' 2>/dev/null)"
echo $AUD
# Output: https://kubernetes.default.svc
```

#### 2.2 Patch AuthPolicy
```bash
oc patch authpolicy maas-api-auth-policy -n maas-api --type=merge --patch-file <(echo "  
spec:
  rules:
    authentication:
      openshift-identities:
        kubernetesTokenReview:
          audiences:
            - $AUD
            - maas-default-gateway-sa")
```

**What this does**:
- Configures Authorino to validate tokens via Kubernetes TokenReview API
- Accepts tokens with audience `https://kubernetes.default.svc`
- Also accepts tokens for `maas-default-gateway-sa` service account

### Step 3: Restart Relevant Pods

After policy configuration, restart:
```bash
# ODH Model Controller
oc delete pod -n redhat-ods-applications -l app=odh-model-controller

# Kuadrant Operator
oc delete pod -n kuadrant-system -l control-plane=kuadrant-operator-controller-manager
```

## How Authentication Works

### Token Generation Flow

1. **User authenticates** to OpenShift (gets OpenShift token)
2. **User requests MaaS token** via MaaS API:
   ```bash
   TOKEN_RESPONSE=$(curl -sSk \
     -H "Authorization: Bearer $(oc whoami -t)" \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{"expiration": "10m"}' \
     "https://maas.${CLUSTER_DOMAIN}/maas-api/v1/tokens")
   
   TOKEN=$(echo $TOKEN_RESPONSE | jq -r .token)
   ```
3. **MaaS API generates** a service account token
4. **User uses MaaS token** to access models:
   ```bash
   curl -sSk https://maas.${CLUSTER_DOMAIN}/maas-api/v1/models \
     -H "Authorization: Bearer $TOKEN"
   ```

### Token Validation Flow

1. **Request arrives** at MaaS Gateway
2. **Gateway applies** AuthPolicy
3. **Authorino validates** token:
   - Extracts token from `Authorization: Bearer` header
   - Calls Kubernetes TokenReview API
   - Checks token audience matches configured audiences
   - Verifies token is valid and not expired
4. **If valid**: Request forwarded to MaaS API
5. **If invalid**: Request rejected with 401 Unauthorized

## AuthPolicy Configuration

### Full AuthPolicy Structure

```yaml
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: maas-api-auth-policy
  namespace: maas-api
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: maas-api
  rules:
    authentication:
      openshift-identities:
        kubernetesTokenReview:
          audiences:
            - https://kubernetes.default.svc
            - maas-default-gateway-sa
```

### Key Fields

- **`targetRef`**: Which HTTPRoute this policy applies to
- **`kubernetesTokenReview`**: Use Kubernetes TokenReview API for validation
- **`audiences`**: List of acceptable token audiences

## Security Considerations

### ⚠️ Critical Security Issue

From the CAI guide:

> "When you enable MaaS for a model served using llm-d, the **direct HTTPRoute to the model stays valid**. This has several impacts:
> - Calling `https://maas.apps<domain>/maas-api/v1/models` leads to the MaaS Gateway Pod.
> - Calling `https://maas.apps<domain>/<namespace>/<model-id>/v1/models` leads to the LLM-D instance **directly, bypassing MaaS**.
> - **This is very important**: if you checked the MaaS checkbox, but did not check the 'Require authentication' one (if you thought MaaS would protect access anyway), **your endpoint is freely accessible**, bypassing other Authentication, Policies... you may have in place on MaaS.
> - Even with both checkboxes set, direct access to the model is possible if you have the right token."

### Two Routes, Two Policies

When you deploy a model with MaaS enabled:

| Route | URL | Goes Through | Authentication |
|-------|-----|--------------|----------------|
| **MaaS Gateway** | `https://maas.apps<domain>/maas-api/v1/models` | MaaS Gateway → AuthPolicy → Model | ✅ MaaS AuthPolicy |
| **Direct Route** | `https://maas.apps<domain>/<namespace>/<model-id>/v1/models` | Directly to llm-d | ⚠️ Model's own AuthPolicy (if enabled) |

### Secure Configuration

**ALWAYS enable BOTH checkboxes when deploying with MaaS**:

1. ✅ **"Enable Model as a Service"** - Creates MaaS gateway route
2. ✅ **"Require authentication"** - Protects direct route with AuthPolicy

If you only check MaaS:
- ❌ MaaS route is protected
- ❌ **Direct route is UNPROTECTED**
- ❌ Anyone can bypass MaaS and hit your model directly

## Rate Limiting (Optional)

MaaS also supports rate limiting via `RateLimitPolicy`:

```yaml
apiVersion: kuadrant.io/v1beta3
kind: RateLimitPolicy
metadata:
  name: maas-api-rate-limit
  namespace: maas-api
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: maas-api
  limits:
    "global":
      rates:
      - limit: 100
        duration: 60
        unit: second
```

This would limit to 100 requests per 60 seconds globally.

## Token Management

### Token Expiration

Tokens generated via MaaS API have configurable expiration:

```bash
# 10 minute token
curl -X POST -d '{"expiration": "10m"}' ...

# 24 hour token
curl -X POST -d '{"expiration": "24h"}' ...
```

### Token Revocation

⚠️ **Known Issue** from CAI guide:
> "All the tokens you create are active (don't know yet how to revoke one…)"

Currently, there's no way to revoke MaaS tokens. They remain valid until expiration.

**Workaround**: Use short expiration times (e.g., 10m, 1h) for better security.

## Verification

### Check AuthPolicy

```bash
# Check if AuthPolicy exists
oc get authpolicy -n maas-api

# Expected output:
# NAME                    AGE
# maas-api-auth-policy    5m

# Check AuthPolicy configuration
oc get authpolicy maas-api-auth-policy -n maas-api -o yaml
```

### Check Gateway

```bash
# Check Gateway status
oc get gateway -n maas-api

# Check HTTPRoute
oc get httproute -n maas-api
```

### Test Authentication

```bash
# Generate token
TOKEN_RESPONSE=$(curl -sSk \
  -H "Authorization: Bearer $(oc whoami -t)" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"expiration": "10m"}' \
  "https://maas.${CLUSTER_DOMAIN}/maas-api/v1/tokens")

TOKEN=$(echo $TOKEN_RESPONSE | jq -r .token)

# Test with valid token (should work)
curl -sSk https://maas.${CLUSTER_DOMAIN}/maas-api/v1/models \
  -H "Authorization: Bearer $TOKEN"

# Test without token (should fail with 401)
curl -sSk https://maas.${CLUSTER_DOMAIN}/maas-api/v1/models
```

## Troubleshooting

### Issue: 401 Unauthorized

**Possible causes**:
1. Token expired
2. Token audience doesn't match AuthPolicy configuration
3. Authorino not running

**Solution**:
```bash
# Check Authorino pods
oc get pods -n kuadrant-system | grep authorino

# Check AuthPolicy audiences
oc get authpolicy maas-api-auth-policy -n maas-api -o jsonpath='{.spec.rules.authentication.openshift-identities.kubernetesTokenReview.audiences}'

# Regenerate token
# (see Token Generation Flow above)
```

### Issue: Policy not applied

**Possible causes**:
1. Kuadrant operator not running
2. AuthPolicy not targeting correct HTTPRoute
3. Gateway not programmed

**Solution**:
```bash
# Check Kuadrant operator
oc get pods -n kuadrant-system

# Check AuthPolicy target
oc get authpolicy maas-api-auth-policy -n maas-api -o jsonpath='{.spec.targetRef}'

# Check Gateway status
oc get gateway -n maas-api -o yaml
```

### Issue: Direct route bypasses MaaS

**Cause**: Model deployed with MaaS but without "Require authentication"

**Solution**:
1. Delete the model
2. Redeploy with BOTH checkboxes:
   - ✅ Enable Model as a Service
   - ✅ Require authentication

Or patch existing deployment:
```bash
oc annotate llmisvc/<model-name> -n <namespace> security.opendatahub.io/enable-auth=true
```

## Summary

### Policy Enforcement Components

1. **OpenShift Gateway API** - Entry point
2. **Kuadrant** - Policy framework
3. **AuthPolicy** - Authentication rules
4. **Authorino** - Authentication engine
5. **Kubernetes TokenReview** - Token validation

### Authentication Flow

```
User → OpenShift Token → MaaS API → MaaS Token → Gateway → AuthPolicy → Authorino → TokenReview → Model
```

### Security Best Practices

1. ✅ Always enable "Require authentication" with MaaS
2. ✅ Use short token expiration times
3. ✅ Configure AuthPolicy with correct audiences
4. ✅ Monitor token usage
5. ⚠️ Be aware of direct route bypass

## References

- CAI's guide to RHOAI 3.0 (Section 4 - MaaS)
- MaaS Documentation: https://opendatahub-io.github.io/maas-billing/
- Kuadrant Documentation: https://docs.kuadrant.io/
- Authorino Documentation: https://docs.kuadrant.io/authorino/

---

**Last Updated**: November 2025  
**RHOAI Version**: 3.0  
**Source**: CAI's guide to RHOAI 3.0, Section 4

