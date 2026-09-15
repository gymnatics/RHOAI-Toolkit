# Plan: MaaS Telemetry and Subscription Metadata Integration

Self-contained plan for adding MaaS telemetry auto-configuration and subscription
metadata tagging to the RHOAI toolkit. This document has all the context needed
to implement in a separate chat session.

---

## Background

RHOAI 3.5 introduced `MaasTenantConfig` (replaces the old `Tenant` CRD) with a
`spec.telemetry` section for usage metrics, and `MaaSSubscription` now supports
`spec.tokenMetadata` for cost attribution (costCenter, organizationId). These are
currently applied via manual `oc patch` commands. This plan integrates them into
the toolkit's automated workflows.

### Reference Commands (verified on live RHOAI 3.5.0 cluster)

```bash
# 1. Enable MaaS telemetry (on MaasTenantConfig)
oc patch maastenantconfig default-tenant -n models-as-a-service --type=merge -p '{
  "spec": {
    "telemetry": {
      "enabled": true,
      "metrics": {
        "captureGroup": true,
        "captureModelUsage": true,
        "captureOrganization": true,
        "captureUser": true
      }
    }
  }
}'

# 2. Tag a subscription with cost attribution metadata
oc patch maassubscription <name> -n models-as-a-service --type=merge -p '{
  "spec": {
    "tokenMetadata": {
      "costCenter": "101",
      "organizationId": "APAC AI"
    }
  }
}'
```

### Sources

- Liming Tsai (Red Hat) shared these patches as the correct way to configure
  telemetry and subscription metadata on RHOAI 3.5
- `rh-aiservices-bu/rhoai-maas-guide` (https://github.com/rh-aiservices-bu/rhoai-maas-guide)
  — Red Hat's reference MaaS deployment guide, `scripts/setup-maas.sh` creates
  simulator subscriptions with both `gpt-oss-20b-premium` and free-tier subs
- Verified on live cluster: `MaasTenantConfig` accepts the telemetry patch,
  stays `READY=True, REASON=Reconciled` after patching
- MaaS 3.5 docs: `docs/reference/RHAIE 3.5 Guide/Red_Hat_OpenShift_AI_Self-Managed-3.5-Govern_LLM_access_with_Models-as-a-Service-en-US.pdf.md`

---

## Integration Point 1: Auto-Enable Telemetry During Install

### File: `scripts/install-rhoai-35.sh`

### Location

After the `verify_maas_deployment()` call in `main()`, around line ~2900 (the MaaS
setup section):

```bash
    if [ "$SKIP_RHCL" = false ] && [ "$SKIP_MAAS" = false ]; then
        ...
        configure_maas_tls
        configure_maas_rate_limiting
        verify_maas_deployment
        # >>> ADD HERE: configure_maas_telemetry
    fi
```

### New Function: `configure_maas_telemetry`

Add this function near the existing `configure_maas_tls` and `configure_maas_rate_limiting`
functions (around line ~1260):

```bash
configure_maas_telemetry() {
    print_step "Enabling MaaS telemetry metrics..."

    # Wait for MaasTenantConfig to exist (created by maas-controller)
    local elapsed=0
    while [ $elapsed -lt 120 ]; do
        if oc get maastenantconfig default-tenant -n models-as-a-service &>/dev/null; then
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    if ! oc get maastenantconfig default-tenant -n models-as-a-service &>/dev/null; then
        print_warning "MaasTenantConfig not found — skipping telemetry configuration"
        return 0
    fi

    # Check if telemetry is already enabled
    local telemetry_enabled=$(oc get maastenantconfig default-tenant -n models-as-a-service \
        -o jsonpath='{.spec.telemetry.enabled}' 2>/dev/null)
    if [ "$telemetry_enabled" = "true" ]; then
        print_success "MaaS telemetry already enabled"
        return 0
    fi

    # Enable all telemetry capture flags
    if oc patch maastenantconfig default-tenant -n models-as-a-service --type=merge -p '{
        "spec": {
            "telemetry": {
                "enabled": true,
                "metrics": {
                    "captureGroup": true,
                    "captureModelUsage": true,
                    "captureOrganization": true,
                    "captureUser": true
                }
            }
        }
    }' 2>/dev/null; then
        print_success "MaaS telemetry enabled (group, model usage, organization, user metrics)"
    else
        print_warning "Could not enable MaaS telemetry — apply manually:"
        echo "  oc patch maastenantconfig default-tenant -n models-as-a-service --type=merge \\"
        echo "    -p '{\"spec\":{\"telemetry\":{\"enabled\":true,\"metrics\":{\"captureGroup\":true,\"captureModelUsage\":true,\"captureOrganization\":true,\"captureUser\":true}}}}'"
    fi
}
```

### Also Update: `verify_maas_deployment()`

Add a telemetry status check in the existing verification function:

```bash
    # Check MaaS telemetry
    local telemetry_enabled=$(oc get maastenantconfig default-tenant -n models-as-a-service \
        -o jsonpath='{.spec.telemetry.enabled}' 2>/dev/null)
    if [ "$telemetry_enabled" = "true" ]; then
        print_success "MaaS telemetry is enabled"
    else
        print_info "MaaS telemetry not enabled (optional — run configure_maas_telemetry)"
    fi
```

---

## Integration Point 2: Subscription tokenMetadata During Model Publish

### File: `lib/functions/model-deployment.sh`

### Location

Inside `publish_model_to_maas()` function (starts around line 128), after the
`MaaSSubscription` is created (around line ~210):

```bash
    # Step 2: Create MaaSSubscription
    print_step "Creating MaaSSubscription '$model_name-subscription' in models-as-a-service..."
    cat <<EOF | oc apply -f -
    ...
    EOF

    # >>> ADD HERE: prompt for optional tokenMetadata
```

### New Logic

```bash
    # Optional: Tag subscription with cost attribution metadata
    echo ""
    read -p "Add cost attribution metadata to this subscription? (y/N): " add_metadata
    if [[ "$add_metadata" =~ ^[Yy]$ ]]; then
        read -p "  Cost Center (e.g., 101): " cost_center
        read -p "  Organization ID (e.g., APAC AI): " org_id

        if [ -n "$cost_center" ] || [ -n "$org_id" ]; then
            local metadata_patch='{"spec":{"tokenMetadata":{}'
            [ -n "$cost_center" ] && metadata_patch='{"spec":{"tokenMetadata":{"costCenter":"'"$cost_center"'"}'
            [ -n "$org_id" ] && metadata_patch='{"spec":{"tokenMetadata":{"costCenter":"'"${cost_center:-}"'","organizationId":"'"$org_id"'"}'
            metadata_patch="${metadata_patch}}}"

            if oc patch maassubscription "${model_name}-subscription" \
                -n models-as-a-service --type=merge \
                -p "$metadata_patch" 2>/dev/null; then
                print_success "Subscription tagged: costCenter=$cost_center, organizationId=$org_id"
            else
                print_warning "Could not apply metadata — add manually:"
                echo "  oc patch maassubscription ${model_name}-subscription -n models-as-a-service \\"
                echo "    --type=merge -p '{\"spec\":{\"tokenMetadata\":{\"costCenter\":\"$cost_center\",\"organizationId\":\"$org_id\"}}}'"
            fi
        fi
    fi
```

### Note on Subscription Naming

The current `publish_model_to_maas()` function creates a subscription named
`${model_name}-subscription` in `models-as-a-service`. If the naming convention
changes (e.g., the `rh-aiservices-bu/rhoai-maas-guide` setup-maas.sh creates
subscriptions named `gpt-oss-20b-premium`, `gpt-oss-20b-free`, etc.), the
metadata function should discover the subscription name dynamically rather than
assuming the naming pattern. The menu option (Integration Point 3) handles this
by listing all subscriptions and letting the user pick.

---

## Integration Point 3: Interactive Menu Options

### File: `lib/menus/rhoai-management.sh`

### Location

In the "AI Services & Infrastructure" submenu (the section containing MaaS setup,
LlamaStack/OGX setup, Feature Store, etc.). This submenu starts around line ~340
in the `services_submenu()` function.

### New Menu Items

Add two new options after the existing MaaS/LlamaStack/Feature Store items:

```
    echo -e "${MAGENTA}MaaS Configuration:${NC}"
    echo -e "${YELLOW}6)${NC} Configure MaaS Telemetry"
    echo "    Enable usage metrics (group, model, organization, user capture)"
    echo ""
    echo -e "${YELLOW}7)${NC} Tag MaaS Subscription Metadata"
    echo "    Add costCenter/organizationId to a subscription for cost attribution"
```

### New Handler Functions (in `lib/functions/rhoai.sh` or new file)

#### Function 1: `configure_maas_telemetry_interactive`

```bash
configure_maas_telemetry_interactive() {
    print_header "Configure MaaS Telemetry"

    if ! oc get maastenantconfig default-tenant -n models-as-a-service &>/dev/null; then
        print_error "MaasTenantConfig not found — MaaS may not be configured yet"
        return 1
    fi

    # Show current state
    local current=$(oc get maastenantconfig default-tenant -n models-as-a-service \
        -o jsonpath='{.spec.telemetry}' 2>/dev/null)
    echo -e "${CYAN}Current telemetry configuration:${NC}"
    if [ -n "$current" ] && [ "$current" != "{}" ]; then
        echo "$current" | python3 -m json.tool 2>/dev/null || echo "  $current"
    else
        echo "  Not configured"
    fi
    echo ""

    echo -e "${CYAN}Available telemetry metrics:${NC}"
    echo "  captureGroup         — Track usage by OpenShift group"
    echo "  captureModelUsage    — Track per-model token consumption"
    echo "  captureOrganization  — Track usage by organization"
    echo "  captureUser          — Track usage by individual user"
    echo ""

    read -p "Enable all telemetry metrics? (Y/n): " enable_all
    if [[ "$enable_all" =~ ^[Nn]$ ]]; then
        print_info "Telemetry unchanged"
        return 0
    fi

    configure_maas_telemetry  # reuse the function from install-rhoai-35.sh
}
```

#### Function 2: `configure_maas_subscription_metadata_interactive`

```bash
configure_maas_subscription_metadata_interactive() {
    print_header "Tag MaaS Subscription Metadata"

    # List all subscriptions
    local subs
    subs=$(oc get maassubscription -n models-as-a-service --no-headers \
        -o custom-columns='NAME:.metadata.name' 2>/dev/null)

    if [ -z "$subs" ]; then
        print_error "No MaaS subscriptions found in models-as-a-service"
        print_info "Deploy a model and publish to MaaS first"
        return 1
    fi

    echo -e "${CYAN}Available MaaS Subscriptions:${NC}"
    echo ""
    local idx=1
    local sub_array=()
    while IFS= read -r sub; do
        [ -z "$sub" ] && continue
        local current_meta=$(oc get maassubscription "$sub" -n models-as-a-service \
            -o jsonpath='{.spec.tokenMetadata}' 2>/dev/null)
        local meta_display="(no metadata)"
        if [ -n "$current_meta" ] && [ "$current_meta" != "{}" ]; then
            meta_display="$current_meta"
        fi
        echo -e "  ${YELLOW}$idx)${NC} $sub  $meta_display"
        sub_array+=("$sub")
        ((idx++))
    done <<< "$subs"
    echo ""

    read -p "Select subscription (1-${#sub_array[@]}): " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#sub_array[@]}" ]; then
        print_error "Invalid selection"
        return 1
    fi

    local selected="${sub_array[$((choice - 1))]}"
    echo ""
    print_info "Selected: $selected"
    echo ""

    read -p "Cost Center (e.g., 101, leave empty to skip): " cost_center
    read -p "Organization ID (e.g., APAC AI, leave empty to skip): " org_id

    if [ -z "$cost_center" ] && [ -z "$org_id" ]; then
        print_info "No metadata provided — skipping"
        return 0
    fi

    local patch='{"spec":{"tokenMetadata":{'
    local fields=()
    [ -n "$cost_center" ] && fields+=("\"costCenter\":\"$cost_center\"")
    [ -n "$org_id" ] && fields+=("\"organizationId\":\"$org_id\"")
    patch+=$(IFS=,; echo "${fields[*]}")
    patch+='}}}'

    if oc patch maassubscription "$selected" -n models-as-a-service \
        --type=merge -p "$patch" 2>/dev/null; then
        print_success "Subscription '$selected' tagged"
        echo "  costCenter: ${cost_center:-<not set>}"
        echo "  organizationId: ${org_id:-<not set>}"
    else
        print_error "Failed to patch subscription"
    fi
}
```

---

## File: `lib/menus/display.sh`

Update the AI Services submenu display to include the new options. Find the
`show_services_submenu()` function (around line 165) and add:

```
    echo -e "${MAGENTA}MaaS Telemetry & Metadata:${NC}"
    echo -e "${YELLOW}6)${NC} Configure MaaS Telemetry"
    echo "    Enable usage metrics capture (group, model, organization, user)"
    echo ""
    echo -e "${YELLOW}7)${NC} Tag MaaS Subscription Metadata"
    echo "    Add costCenter/organizationId for cost attribution"
```

---

## File: `lib/functions/rhoai.sh`

Add the reusable `configure_maas_telemetry` function (non-interactive version)
near the existing `configure_maas_tls_34` / `verify_maas_34` functions (~line 2070+).
This function is called by both the install script and the interactive menu.

Also add the `configure_maas_subscription_metadata_interactive` function here or
in a new `lib/functions/maas-telemetry.sh` file (to keep `rhoai.sh` from growing
further).

---

## Also Consider: `lib/utils/rhoai-version.sh`

Add a helper to `print_rhoai_info()` to show current telemetry status:

```bash
    if is_rhoai_35_or_higher; then
        local telemetry=$(oc get maastenantconfig default-tenant -n models-as-a-service \
            -o jsonpath='{.spec.telemetry.enabled}' 2>/dev/null || echo "N/A")
        echo -e "    Telemetry:     $([ "$telemetry" = "true" ] && echo "${GREEN}Enabled${NC}" || echo "${YELLOW}${telemetry}${NC}")"
    fi
```

---

## Implementation Status

All integration points have been implemented and pass `bash -n` syntax validation:

| Integration Point | Status |
|---|---|
| `configure_maas_telemetry()` in `scripts/install-rhoai-35.sh` | ✅ Done |
| `configure_maas_telemetry` call in `main()` | ✅ Done |
| Telemetry check in `verify_maas_deployment()` | ✅ Done |
| tokenMetadata prompt in `publish_model_to_maas()` | ✅ Done |
| Menu items 8/9 in `show_ai_services_submenu()` | ✅ Done |
| Menu handlers 8/9 in `ai_services_submenu()` | ✅ Done |
| `configure_maas_telemetry_interactive()` in `lib/functions/rhoai.sh` | ✅ Done |
| `configure_maas_subscription_metadata_interactive()` in `lib/functions/rhoai.sh` | ✅ Done |
| Telemetry in `print_rhoai_info()` | ✅ Done |

## Testing Checklist

1. Fresh install (`scripts/install-rhoai-35.sh`):
   - [ ] Telemetry auto-enabled after MaaS verification
   - [ ] `oc get maastenantconfig default-tenant -n models-as-a-service -o jsonpath='{.spec.telemetry.enabled}'` returns `true`

2. Model publish flow (`publish_model_to_maas`):
   - [ ] After subscription creation, user is prompted for tokenMetadata
   - [ ] Answering "N" skips cleanly
   - [ ] Answering "Y" with values applies the patch
   - [ ] `oc get maassubscription <name> -n models-as-a-service -o jsonpath='{.spec.tokenMetadata}'` shows values

3. Interactive menu:
   - [ ] "Configure MaaS Telemetry" shows current state and patches correctly
   - [ ] "Tag MaaS Subscription Metadata" lists subscriptions, applies metadata
   - [ ] Both handle missing CRDs gracefully (no subscriptions yet, no MaasTenantConfig)

4. Re-run idempotency:
   - [ ] Running telemetry config twice doesn't error (already-enabled check)
   - [ ] Running subscription metadata twice merges/overwrites cleanly

---

## CRD Field Reference (confirmed on live RHOAI 3.5.0)

### MaasTenantConfig.spec.telemetry

```
oc explain maastenantconfig.spec.telemetry
```

Fields (to confirm before implementing — run on live cluster):
- `enabled` (boolean)
- `metrics.captureGroup` (boolean)
- `metrics.captureModelUsage` (boolean)
- `metrics.captureOrganization` (boolean)
- `metrics.captureUser` (boolean)

### MaaSSubscription.spec.tokenMetadata

```
oc explain maassubscription.spec.tokenMetadata
```

Fields (to confirm before implementing):
- `costCenter` (string)
- `organizationId` (string)
- Possibly more — check `oc explain` output
