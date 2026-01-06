# MaaS (Model as a Service) - Serving Runtime Compatibility

## Summary

According to the CAI guide to RHOAI 3.0, **only `llm-d` serving runtime works with MaaS through the UI**.

## Key Quote from CAI Guide

> "When you enable MaaS for a model served using **llm-d (only type available through the UI)**, the direct HTTPRoute to the model stays valid."

## Serving Runtime Compatibility

### ✅ **llm-d** - WORKS with MaaS

- **Status**: Fully supported for MaaS through the UI
- **How to enable**: 
  1. Deploy model using `llm-d` as the serving runtime
  2. Check the "Enable Model as a Service" checkbox
  3. (Optional) Check "Require authentication" for additional security

### ❌ **vLLM** - Does NOT work with MaaS through UI

- **Status**: Not supported for MaaS through the UI
- **Use case**: Direct model deployment without MaaS
- **Note**: vLLM is used for:
  - Direct model serving (without MaaS)
  - GenAI Playground backend
  - Custom deployments via YAML

## Important Security Notes

### MaaS + Authentication

When deploying with MaaS, you have TWO authentication options:

1. **MaaS checkbox only** (NOT RECOMMENDED)
   - Creates MaaS gateway route
   - BUT: Direct HTTPRoute to model stays valid
   - ⚠️ **Security Risk**: Model is freely accessible via direct route, bypassing MaaS

2. **MaaS + "Require authentication" checkboxes** (RECOMMENDED)
   - Creates MaaS gateway route with authentication
   - Protects direct HTTPRoute with authentication
   - ✅ **Secure**: Both routes require authentication

### Route Behavior

When MaaS is enabled for an `llm-d` model:

| Route Type | URL Pattern | Behavior |
|------------|-------------|----------|
| **MaaS Gateway** | `https://maas.apps<domain>/maas-api/v1/models` | Goes through MaaS Gateway Pod |
| **Direct Route** | `https://maas.apps<domain>/<namespace>/<model-id>/v1/models` | Goes directly to LLM-D instance, **bypassing MaaS** |

**Important**: Even with both checkboxes set, direct access to the model is possible if you have the right token.

## Deployment Examples

### Through UI (llm-d with MaaS)

1. Navigate to: Data Science Project → Deploy model
2. Select model from catalog
3. **Serving runtime**: Choose `llm-d`
4. ✅ Check: "Enable Model as a Service"
5. ✅ Check: "Require authentication" (recommended)
6. Specify ServiceAccount name (or use default)

### Through UI (vLLM without MaaS)

1. Navigate to: Data Science Project → Deploy model
2. Select model from catalog
3. **Serving runtime**: Choose `vLLM`
4. MaaS checkbox will NOT be available
5. Deploy as standard inference service

## Technical Details

### Why llm-d for MaaS?

`llm-d` (LLM Distributed) is specifically designed to work with:
- Leader Worker Set (LWS) operator
- Multi-replica distributed serving
- MaaS gateway integration
- Built-in authentication support

### Why not vLLM for MaaS?

`vLLM` is designed for:
- Direct, high-performance inference
- GenAI Playground integration
- Custom deployments
- Does not integrate with MaaS gateway infrastructure

## Prerequisites for llm-d + MaaS

1. ✅ Red Hat Build of Leader Worker Set Operator (required for llm-d)
2. ✅ Red Hat Connectivity Link (RHCL) Operator (required for MaaS)
3. ✅ Kuadrant (AuthPolicy, RateLimitPolicy)
4. ✅ Authorino (authentication)
5. ✅ MaaS API infrastructure deployed

All of these are automatically installed by our `rhoai-toolkit.sh` script.

## Verification

### Check llm-d is available

```bash
# Check if llm-d serving runtime exists
oc get servingruntime -A | grep llm-d
```

### Check MaaS is deployed

```bash
# Check MaaS namespace
oc get pods -n maas-api

# Check MaaS gateway
oc get gateway -n maas-api

# Check AuthPolicy
oc get authpolicy -n maas-api
```

### Test MaaS endpoint

```bash
# Generate token
./demo/generate-maas-token.sh

# Test API
./demo/test-maas-api.sh
```

## Known Issues

From the CAI guide:

1. **Models served with LLM-D and authentication don't work in the playground** (RHOAIENG-36372)
   - Workaround: Manually add the token to make it work

2. **llm-d models should be stoppable** (RHOAIENG-38579)
   - Currently, llm-d models cannot be stopped like other runtimes

3. **User need to migrate serverless ISVC to rawDeployment ISVC before RHOAI 3.0** (RHOAIENG-31645)
   - If upgrading from RHOAI 2.x

## References

- CAI's guide to RHOAI 3.0 (Section 3 - llm-d, Section 4 - MaaS)
- MaaS Documentation: https://opendatahub-io.github.io/maas-billing/latest/quickstart/
- Our demo scripts: `demo/README.md`

---

**Last Updated**: November 2025  
**RHOAI Version**: 3.0  
**Source**: CAI's guide to RHOAI 3.0.pdf

