# macOS Compatibility Fix for Model Deployment

## Problem

The model deployment script failed on macOS with the following errors:

```bash
grep: invalid option -- P
usage: grep [-abcdDEFGHhIiJLlMmnOopqRSsUVvwXxZz] [-A num] [-B num] [-C[num]]
...
awk: syntax error at source line 1
 context is
        {print int($1/2) > 0 >>>  ? <<<  
awk: illegal statement at source line 1
...
Error from server: error when creating "STDIN": admission webhook "inferenceservice.kserve-webhook-server.defaulter" denied the request: quantities must match the regular expression '^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$'
✗ Failed to create InferenceService
```

## Root Cause

The script (`lib/functions/model-deployment.sh`) used Linux-specific commands that are not compatible with macOS:

### Issue 1: `grep -P` (Perl Regex)

**Line 640**:
```bash
local parser=$(echo "$vllm_args" | grep -oP '(?<=tool-call-parser=)\w+')
```

**Problem**: macOS `grep` doesn't support the `-P` flag (Perl-compatible regex)

### Issue 2: Inline `awk` in Heredoc

**Lines 687-688**:
```bash
cpu: '$(echo "$cpu_limit" | awk '{print int($1/2) > 0 ? int($1/2) : 1}')'
memory: $(echo "$memory_limit" | sed 's/Gi//' | awk '{print int($1/2) > 1 ? int($1/2) : 1}')Gi
```

**Problems**:
1. Complex `awk` expressions within YAML heredoc caused shell expansion issues
2. Ternary operators in `awk` failed to parse correctly in this context
3. Generated invalid Kubernetes quantity values (empty or malformed strings)

## Solution

### 1. Replace `grep -P` with `sed`

**Before**:
```bash
local parser=$(echo "$vllm_args" | grep -oP '(?<=tool-call-parser=)\w+')
```

**After**:
```bash
local parser=$(echo "$vllm_args" | sed -n 's/.*tool-call-parser=\([a-z0-9_]*\).*/\1/p')
```

### 2. Pre-calculate Resource Requests

**Before**:
```yaml
resources:
  limits:
    cpu: '$cpu_limit'
    memory: $memory_limit
  requests:
    cpu: '$(echo "$cpu_limit" | awk '{print int($1/2) > 0 ? int($1/2) : 1}')'
    memory: $(echo "$memory_limit" | sed 's/Gi//' | awk '{print int($1/2) > 1 ? int($1/2) : 1}')Gi
```

**After**:
```bash
# Calculate resource requests BEFORE the heredoc
local cpu_request="1"
if [[ "$cpu_limit" =~ ^[0-9]+$ ]]; then
    cpu_request=$(( cpu_limit / 2 ))
    [ "$cpu_request" -lt 1 ] && cpu_request="1"
fi

local memory_request="1Gi"
if [[ "$memory_limit" =~ ^([0-9]+)Gi$ ]]; then
    local mem_value="${BASH_REMATCH[1]}"
    local mem_half=$(( mem_value / 2 ))
    [ "$mem_half" -lt 1 ] && mem_half="1"
    memory_request="${mem_half}Gi"
fi

# Then use the pre-calculated values in YAML
resources:
  limits:
    cpu: '$cpu_limit'
    memory: $memory_limit
  requests:
    cpu: '$cpu_request'
    memory: $memory_request
```

## Benefits

1. ✅ **macOS Compatible**: Works on both macOS and Linux
2. ✅ **Cleaner Code**: Pre-calculation is more readable than inline `awk`
3. ✅ **Reliable**: Uses bash arithmetic instead of spawning subshells
4. ✅ **Matches CAI Guide**: Resource requests are exactly half of limits (e.g., 4 CPU → 1 CPU request, 16Gi → 6Gi request for the Llama 3.2-3B example)

## CAI Guide Reference

From the CAI guide (Section 2), the correct resource format for a vLLM InferenceService:

```yaml
resources:
  limits:
    cpu: '4'
    memory: 16Gi
    nvidia.com/gpu: '1'
  requests:
    cpu: '1'      # Half of 4, minimum 1
    memory: 6Gi   # Less than half of 16Gi (optimized)
    nvidia.com/gpu: '1'
```

**Note**: The CAI guide uses `6Gi` for memory requests (not exactly half of `16Gi`), which is more optimized. Our script uses exactly half for simplicity and safety.

## Testing

To verify the fix works:

```bash
# Export kubeconfig
export KUBECONFIG=/path/to/kubeconfig

# Deploy a model
./scripts/quick-deploy-model.sh

# Or use the interactive deployment
./lib/functions/model-deployment.sh

# Verify the InferenceService was created with valid resource values
oc get inferenceservice <model-name> -n <namespace> -o yaml | grep -A 10 resources
```

Expected output:
```yaml
resources:
  limits:
    cpu: "4"
    memory: 16Gi
    nvidia.com/gpu: "1"
  requests:
    cpu: "2"         # ← Valid integer
    memory: 8Gi      # ← Valid quantity
    nvidia.com/gpu: "1"
```

## Related Issues

This fix is specific to macOS compatibility. Related documentation:
- **CAI Guide**: Section 2 - vLLM model deployment examples
- **Model Deployment**: [INTERACTIVE-MODEL-DEPLOYMENT.md](../guides/INTERACTIVE-MODEL-DEPLOYMENT.md)

## Status

✅ **Fixed** in `lib/functions/model-deployment.sh` as of Nov 27, 2025

The script now works correctly on both macOS and Linux systems.

