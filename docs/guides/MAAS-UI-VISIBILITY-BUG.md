# RHOAI 3.3 MaaS UI Model Visibility Bug Report

## Summary

**Component**: `maas-api` (odh-maas-api-rhel9)  
**Version**: RHOAI 3.3.0 (Tech Preview)  
**Severity**: High - Core functionality broken  
**Status**: Unresolved - Requires Red Hat fix

Models deployed with `LLMInferenceService` and published to MaaS do not appear in the "Models as a service" dashboard tab, even when all configuration requirements are met.

---

## Problem Description

### Expected Behavior

When a model is deployed with:
1. `alpha.maas.opendatahub.io/published: "true"` annotation
2. `alpha.maas.opendatahub.io/tiers` annotation specifying accessible tiers
3. `security.opendatahub.io/enable-auth: "true"` annotation
4. Proper RBAC permissions for tier-based access

The model should appear in:
- The "Models as a service" tab in the RHOAI dashboard
- The `maas-api /v1/models` endpoint response

### Actual Behavior

- The "Models as a service" tab shows "MaaS service is not available" or an empty list
- The `maas-api /v1/models` endpoint returns `{"data":null,"object":"list"}`
- The model IS functional and accessible via direct API calls

---

## Environment

```
OpenShift: 4.19+
RHOAI: 3.3.0
maas-api image: registry.redhat.io/rhoai/odh-maas-api-rhel9@sha256:0c9a170711fd9ae1ce7ae3563446b361a41ed06fc90d570e0096a8229f52de75
```

---

## Reproduction Steps

### 1. Deploy a model with MaaS publishing enabled

```bash
# Deploy via UI with "Publish as MaaS endpoint" selected
# Or apply this LLMInferenceService:
```

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-4b
  namespace: maas-demo
  annotations:
    alpha.maas.opendatahub.io/published: "true"
    alpha.maas.opendatahub.io/tiers: '["free","premium","enterprise"]'
    security.opendatahub.io/enable-auth: "true"
  labels:
    app.opendatahub.io/modelsasservice: "true"
    opendatahub.io/dashboard: "true"
spec:
  model:
    name: qwen3-4b
    uri: oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b
  # ... rest of spec
```

### 2. Verify model is ready

```bash
$ oc get llminferenceservice -n maas-demo
NAME       URL                                                                 READY
qwen3-4b   https://maas-api.apps.cluster.example.com/maas-demo/qwen3-4b       True
```

### 3. Verify annotations are correct

```bash
$ oc get llminferenceservice qwen3-4b -n maas-demo -o jsonpath='{.metadata.annotations}' | jq .
{
  "alpha.maas.opendatahub.io/published": "true",
  "alpha.maas.opendatahub.io/tiers": "[\"free\",\"premium\",\"enterprise\"]",
  "security.opendatahub.io/enable-auth": "true"
}
```

### 4. Test maas-api /v1/models endpoint

```bash
TOKEN=$(oc create token default -n maas-demo --audience="https://kubernetes.default.svc" --duration=1h)

curl -sk "https://maas-api.redhat-ods-applications.svc.cluster.local:8443/v1/models" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-MaaS-Username: system:serviceaccount:maas-demo:default" \
  -H 'X-MaaS-Group: ["system:authenticated","system:serviceaccounts"]'
```

**Expected**: `{"data":[{"id":"qwen3-4b",...}],"object":"list"}`  
**Actual**: `{"data":null,"object":"list"}`

### 5. Verify model IS accessible directly

```bash
curl -sk "https://maas-api.apps.cluster.example.com/maas-demo/qwen3-4b/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3-4b","messages":[{"role":"user","content":"Hi"}],"max_tokens":10}'
```

**Result**: Model responds correctly - proving the model works, just not visible in UI

---

## Investigation Findings

### 1. Tier Resolution Works

```bash
$ curl -sk "https://maas-api.../v1/tiers/lookup" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"groups": ["system:authenticated"]}'

{"tier":"free","displayName":"Free Tier"}
```

### 2. RBAC Permissions Are Correct

```bash
$ oc auth can-i get llminferenceservices/qwen3-4b -n maas-demo --as=system:serviceaccount:maas-demo:default
yes

$ oc auth can-i create llminferenceservices/qwen3-4b -n maas-demo --as=system:serviceaccount:maas-demo:default
yes
```

### 3. Model Has Required Labels

```bash
$ oc get llminferenceservice qwen3-4b -n maas-demo -o jsonpath='{.metadata.labels}'
{
  "app.opendatahub.io/modelsasservice": "true",
  "opendatahub.io/dashboard": "true",
  "opendatahub.io/genai-asset": "true"
}
```

### 4. Namespace Has Required Labels

```bash
$ oc get ns maas-demo -o jsonpath='{.metadata.labels}'
{
  "app.opendatahub.io/modelsasservice": "true",
  "opendatahub.io/dashboard": "true"
}
```

### 5. maas-api Logs Show No Errors

```
[GIN] 2026/03/16 - 07:44:06 | 200 |   37.298647ms | GET "/v1/models"
```

The request succeeds (200) but returns empty data.

---

## Root Cause Analysis

The `maas-api` component performs internal filtering when listing models. Despite:
- Correct annotations on the LLMInferenceService
- Correct tier resolution
- Correct RBAC permissions
- maas-api having ClusterRole permissions to list LLMInferenceServices

The `/v1/models` endpoint returns empty data. The filtering logic inside `maas-api` appears to have a bug that prevents models from being listed.

### Possible Causes (Speculation)

1. **SubjectAccessReview check failure**: The maas-api may be checking permissions with incorrect parameters
2. **Tier matching logic bug**: The comparison between user's tier and model's tiers may have an issue
3. **Namespace filtering**: The maas-api may be filtering to specific namespaces incorrectly
4. **Label selector mismatch**: The maas-api may be looking for labels that don't exist

---

## Workaround

**There is no workaround for the UI visibility issue.**

However, the model IS functional:

1. **Direct API access works**:
   ```bash
   curl -sk "https://maas-api.apps.../maas-demo/qwen3-4b/v1/chat/completions" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"model":"qwen3-4b","messages":[{"role":"user","content":"Hi"}]}'
   ```

2. **Tier-based rate limiting works** (after applying the AuthPolicy fix - see MAAS-TIER-RATE-LIMITING-FIX.md)

3. **Model appears in "Deployments" tab** - just not in "Models as a service" tab

---

## Related Issues

This bug is separate from but related to the tier-based rate limiting issue documented in `MAAS-TIER-RATE-LIMITING-FIX.md`. That issue has a workaround (patching the AuthPolicy), while this UI visibility issue does not.

---

## Diagnostic Commands

```bash
# Check maas-api pod status
oc get pods -n redhat-ods-applications -l app=maas-api

# Check maas-api logs
oc logs -n redhat-ods-applications -l app=maas-api --tail=50

# Check model annotations
oc get llminferenceservice <model> -n <namespace> -o yaml | grep -A10 "annotations:"

# Test tier lookup
oc run tier-test --rm -i --restart=Never --image=curlimages/curl -n <namespace> -- \
  curl -sk "https://maas-api.redhat-ods-applications.svc.cluster.local:8443/v1/tiers/lookup" \
  -H "Authorization: Bearer $(oc create token default -n <namespace> --audience=https://kubernetes.default.svc)" \
  -d '{"groups": ["system:authenticated"]}'

# Test models endpoint
oc run models-test --rm -i --restart=Never --image=curlimages/curl -n <namespace> -- \
  curl -sk "https://maas-api.redhat-ods-applications.svc.cluster.local:8443/v1/models" \
  -H "Authorization: Bearer $(oc create token default -n <namespace> --audience=https://kubernetes.default.svc)" \
  -H "X-MaaS-Username: system:serviceaccount:<namespace>:default" \
  -H 'X-MaaS-Group: ["system:authenticated"]'
```

---

## Recommendation

This appears to be a bug in the `maas-api` component that requires a fix from Red Hat. Consider:

1. Opening a support case with Red Hat
2. Checking for updates to RHOAI 3.3.x that may address this issue
3. Monitoring the [OpenDataHub GitHub](https://github.com/opendatahub-io) for related issues

---

## Files Referenced

- `docs/guides/MAAS-TIER-RATE-LIMITING-FIX.md` - Related tier rate limiting fix
- `demo/maas-demo/manifests/authpolicy-with-tier-lookup.yaml` - AuthPolicy fix for tier resolution
- `demo/maas-demo/manifests/tiers/tokenratelimitpolicy.yaml` - Tier-based rate limits

---

## Version Information

```
Date: 2026-03-16
RHOAI Version: 3.3.0
OpenShift Version: 4.19+
Cluster: AWS (us-east-2)
```
