#!/bin/bash
################################################################################
# Model Catalog Management Functions
################################################################################
# CRUD operations for the RHOAI Model Catalog ConfigMap.
################################################################################

_CATALOG_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! type print_step &>/dev/null; then
    source "$_CATALOG_LIB_DIR/lib/utils/colors.sh"
fi

CATALOG_NAMESPACE="${CATALOG_NAMESPACE:-rhoai-model-registries}"
CATALOG_CONFIGMAP="${CATALOG_CONFIGMAP:-model-catalog-sources}"

catalog_list() {
    print_step "Listing model catalog entries..."

    local data
    data=$(oc get configmap "$CATALOG_CONFIGMAP" -n "$CATALOG_NAMESPACE" \
        -o jsonpath='{.data.sample-catalog\.yaml}' 2>/dev/null)

    if [ -z "$data" ]; then
        print_warning "No catalog ConfigMap found or it is empty"
        return 1
    fi

    echo ""
    echo "$data" | grep -E "^  - name:|^    description:|^    provider:" | \
        while read -r line; do
            if echo "$line" | grep -q "^  - name:"; then
                local name
                name=$(echo "$line" | sed 's/.*name: //')
                printf "\n  %-40s" "$name"
            elif echo "$line" | grep -q "provider:"; then
                local provider
                provider=$(echo "$line" | sed 's/.*provider: //')
                printf "  [%s]" "$provider"
            fi
        done
    echo ""
    echo ""
}

catalog_add() {
    local model_name="${1:-}"
    local description="${2:-}"
    local provider="${3:-}"
    local license="${4:-apache-2.0}"
    local artifact_uri="${5:-}"

    if [ -z "$model_name" ]; then
        read -rp "Model name (e.g. Qwen/Qwen3-8B): " model_name
    fi
    if [ -z "$description" ]; then
        read -rp "Description: " description
    fi
    if [ -z "$provider" ]; then
        read -rp "Provider: " provider
    fi
    if [ -z "$license" ]; then
        read -rp "License [apache-2.0]: " license
        license="${license:-apache-2.0}"
    fi
    if [ -z "$artifact_uri" ]; then
        read -rp "Artifact URI (hf:// or oci://): " artifact_uri
    fi

    if [ -z "$model_name" ] || [ -z "$artifact_uri" ]; then
        print_error "Model name and artifact URI are required"
        return 1
    fi

    print_step "Adding $model_name to catalog..."

    local current_yaml
    current_yaml=$(oc get configmap "$CATALOG_CONFIGMAP" -n "$CATALOG_NAMESPACE" \
        -o jsonpath='{.data.sample-catalog\.yaml}' 2>/dev/null)

    if echo "$current_yaml" | grep -q "name: $model_name"; then
        print_warning "$model_name already exists in catalog"
        return 0
    fi

    local new_entry
    new_entry=$(cat <<ENTRY
    - name: ${model_name}
      description: ${description}
      readme: |-
        # ${model_name}

        ${description}
      provider: ${provider}
      license: ${license}
      licenseLink: https://www.apache.org/licenses/LICENSE-2.0.txt
      libraryName: transformers
      artifacts:
        - uri: ${artifact_uri}
ENTRY
)

    local updated_yaml
    updated_yaml="${current_yaml}
${new_entry}"

    oc patch configmap "$CATALOG_CONFIGMAP" -n "$CATALOG_NAMESPACE" \
        --type merge -p "{\"data\":{\"sample-catalog.yaml\":$(echo "$updated_yaml" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"$updated_yaml\"")}}"

    print_success "$model_name added to catalog"
    print_info "Restart model-catalog pods to pick up changes:"
    echo "  oc delete pods -l app.kubernetes.io/name=model-catalog -n $CATALOG_NAMESPACE"
}

catalog_remove() {
    local model_name="${1:-}"

    if [ -z "$model_name" ]; then
        catalog_list
        read -rp "Model name to remove: " model_name
    fi

    if [ -z "$model_name" ]; then
        print_error "Model name is required"
        return 1
    fi

    print_step "Removing $model_name from catalog..."

    local current_yaml
    current_yaml=$(oc get configmap "$CATALOG_CONFIGMAP" -n "$CATALOG_NAMESPACE" \
        -o jsonpath='{.data.sample-catalog\.yaml}' 2>/dev/null)

    if ! echo "$current_yaml" | grep -q "name: $model_name"; then
        print_warning "$model_name not found in catalog"
        return 1
    fi

    local updated_yaml
    updated_yaml=$(echo "$current_yaml" | python3 -c "
import sys, yaml
data = yaml.safe_load(sys.stdin.read())
if data and 'models' in data:
    data['models'] = [m for m in data['models'] if m.get('name') != '$model_name']
    yaml.dump(data, sys.stdout, default_flow_style=False)
" 2>/dev/null)

    if [ -z "$updated_yaml" ]; then
        print_error "Failed to parse catalog YAML (python3 + PyYAML required)"
        return 1
    fi

    oc patch configmap "$CATALOG_CONFIGMAP" -n "$CATALOG_NAMESPACE" \
        --type merge -p "{\"data\":{\"sample-catalog.yaml\":$(echo "$updated_yaml" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}}"

    print_success "$model_name removed from catalog"
    print_info "Restart model-catalog pods to pick up changes:"
    echo "  oc delete pods -l app.kubernetes.io/name=model-catalog -n $CATALOG_NAMESPACE"
}

catalog_rename() {
    local new_name="${1:-}"

    if [ -z "$new_name" ]; then
        read -rp "New catalog source name: " new_name
    fi

    if [ -z "$new_name" ]; then
        print_error "Catalog name is required"
        return 1
    fi

    print_step "Renaming catalog source to '$new_name'..."

    local current_yaml
    current_yaml=$(oc get configmap "$CATALOG_CONFIGMAP" -n "$CATALOG_NAMESPACE" \
        -o jsonpath='{.data.sample-catalog\.yaml}' 2>/dev/null)

    local updated_yaml
    updated_yaml=$(echo "$current_yaml" | sed "s/^source: .*/source: $new_name/")

    local sources_yaml
    sources_yaml=$(oc get configmap "$CATALOG_CONFIGMAP" -n "$CATALOG_NAMESPACE" \
        -o jsonpath='{.data.sources\.yaml}' 2>/dev/null)
    local updated_sources
    updated_sources=$(echo "$sources_yaml" | sed "s/name: .*/name: $new_name/")

    oc patch configmap "$CATALOG_CONFIGMAP" -n "$CATALOG_NAMESPACE" \
        --type merge -p "{\"data\":{\"sample-catalog.yaml\":$(echo "$updated_yaml" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))'),\"sources.yaml\":$(echo "$updated_sources" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}}"

    print_success "Catalog renamed to '$new_name'"
    print_info "Restart model-catalog pods to pick up changes:"
    echo "  oc delete pods -l app.kubernetes.io/name=model-catalog -n $CATALOG_NAMESPACE"
}

catalog_add_from_registry() {
    print_step "Listing models from Model Registry..."

    local registry_url
    registry_url=$(oc get route model-registry -n "$CATALOG_NAMESPACE" -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)

    if [ -z "$registry_url" ]; then
        print_warning "Model Registry route not found. Checking other namespaces..."
        registry_url=$(oc get route -A -l app=model-registry -o jsonpath='{.items[0].status.ingress[0].host}' 2>/dev/null)
    fi

    if [ -z "$registry_url" ]; then
        print_error "No Model Registry route found"
        return 1
    fi

    local models
    models=$(curl -sk "https://$registry_url/api/model_registry/v1alpha3/registered_models" \
        -H "Authorization: Bearer $(oc whoami -t)" 2>/dev/null)

    if [ -z "$models" ]; then
        print_error "Failed to query Model Registry"
        return 1
    fi

    echo "$models" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('items', [])
if not items:
    print('  No models found in registry')
else:
    for i, m in enumerate(items, 1):
        print(f'  {i}) {m.get(\"name\", \"unknown\")} - {m.get(\"description\", \"\")}')
" 2>/dev/null

    read -rp "Select model number to add to catalog (0 to cancel): " choice

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then
        return 0
    fi

    local selected
    selected=$(echo "$models" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('items', [])
idx = int('$choice') - 1
if 0 <= idx < len(items):
    m = items[idx]
    print(f'{m.get(\"name\",\"\")}\t{m.get(\"description\",\"\")}\t{m.get(\"customProperties\",{}).get(\"provider\",{}).get(\"string_value\",\"Custom\")}')
" 2>/dev/null)

    if [ -n "$selected" ]; then
        local name desc provider
        name=$(echo "$selected" | cut -f1)
        desc=$(echo "$selected" | cut -f2)
        provider=$(echo "$selected" | cut -f3)
        catalog_add "$name" "$desc" "$provider" "apache-2.0" "hf://$name"
    fi
}

catalog_apply() {
    print_step "Restarting model-catalog pods to apply changes..."
    oc delete pods -l app.kubernetes.io/name=model-catalog -n "$CATALOG_NAMESPACE" 2>/dev/null || true
    print_success "Model catalog pods restarted"
}
