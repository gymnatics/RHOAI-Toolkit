#!/bin/bash
################################################################################
# user-management.sh — General-purpose user management with role picker
################################################################################
# Provides:
#   create_users              — Create htpasswd users with OAuth IdP
#   discover_cluster_roles    — Query cluster for ClusterRoles (curated + dynamic)
#   pick_cluster_roles        — Interactive multi-select role picker
#   bind_cluster_roles        — Create ClusterRoleBindings for users
#   manage_users_interactive  — Full interactive flow: create users + pick roles
#   add_roles_interactive     — Add roles to existing users
#   list_user_bindings        — Show ClusterRoleBindings for a user
#   remove_user_bindings      — Remove selected ClusterRoleBindings for a user
################################################################################

_USER_MGMT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_USER_MGMT_DIR/lib/utils/colors.sh" 2>/dev/null || true

################################################################################
# Curated common ClusterRoles with descriptions
################################################################################

declare -a _COMMON_ROLES=(
    "cluster-admin"
    "admin"
    "edit"
    "view"
    "self-provisioner"
    "cluster-reader"
    "cluster-monitoring-view"
    "sudoer"
    "registry-viewer"
    "registry-editor"
)

# Bash 3.x-compatible role description lookup (declare -A requires bash 4+,
# which is not available on stock macOS /bin/bash 3.2).
_get_role_description() {
    case "$1" in
        cluster-admin)             echo "Full cluster access (superuser)" ;;
        admin)                     echo "Namespace admin (all resources incl. RBAC)" ;;
        edit)                      echo "Edit most resources (no RBAC changes)" ;;
        view)                      echo "Read-only access to most resources" ;;
        self-provisioner)          echo "Create new projects/namespaces" ;;
        cluster-reader)            echo "Read-only cluster-wide (all namespaces)" ;;
        cluster-monitoring-view)   echo "View monitoring metrics and dashboards" ;;
        sudoer)                    echo "Impersonate any user (privilege escalation)" ;;
        registry-viewer)           echo "Pull images from internal registry" ;;
        registry-editor)           echo "Push and pull images in internal registry" ;;
        *)                         echo "" ;;
    esac
}

################################################################################
# create_users — Create htpasswd users with OAuth IdP
#   Usage: create_users <usernames_csv> <password> [idp_name] [group_name]
#   usernames_csv: comma-separated list of usernames, OR "pattern:N" (e.g. "user:5")
################################################################################
create_users() {
    local usernames_input="$1"
    local password="$2"
    local idp_name="${3:-htpasswd}"
    local group_name="${4:-}"
    local secret_name="${idp_name}-secret"

    if [ -z "$usernames_input" ] || [ -z "$password" ]; then
        print_error "Usage: create_users <usernames> <password> [idp_name] [group_name]"
        return 1
    fi

    # Expand pattern (e.g. "user:5" -> "user1,user2,user3,user4,user5")
    local -a usernames=()
    if [[ "$usernames_input" == *":"* ]]; then
        local prefix="${usernames_input%%:*}"
        local count="${usernames_input##*:}"
        for i in $(seq 1 "$count"); do
            usernames+=("${prefix}${i}")
        done
    else
        IFS=',' read -ra usernames <<< "$usernames_input"
    fi

    local user_count=${#usernames[@]}
    print_header "Creating $user_count Users (IdP: $idp_name)"

    # Build htpasswd file, preserving existing entries
    print_step "Building htpasswd file..."
    local tmpdir
    tmpdir=$(mktemp -d)
    local htpasswd_file="${tmpdir}/htpasswd"
    touch "$htpasswd_file"

    if oc get secret "$secret_name" -n openshift-config &>/dev/null 2>&1; then
        oc get secret "$secret_name" -n openshift-config \
            -o jsonpath='{.data.htpasswd}' 2>/dev/null \
            | base64 -d > "$htpasswd_file" 2>/dev/null || true
        print_info "Loaded existing htpasswd data from $secret_name"
    fi

    local created=0
    for username in "${usernames[@]}"; do
        username=$(echo "$username" | xargs)  # trim whitespace
        if grep -q "^${username}:" "$htpasswd_file" 2>/dev/null; then
            print_info "$username already exists — skipping"
        else
            if command -v htpasswd &>/dev/null; then
                htpasswd -bB "$htpasswd_file" "$username" "$password" 2>/dev/null
            else
                local hash
                hash=$(openssl passwd -apr1 "$password" 2>/dev/null)
                echo "${username}:${hash}" >> "$htpasswd_file"
            fi
            created=$((created + 1))
        fi
    done
    print_success "Created $created new users ($user_count total)"

    # Update or create the htpasswd secret
    print_step "Updating htpasswd secret ($secret_name)..."
    oc create secret generic "$secret_name" \
        --from-file=htpasswd="$htpasswd_file" \
        -n openshift-config --dry-run=client -o yaml | oc apply -f -
    print_success "htpasswd secret updated"

    # Ensure the OAuth IdP exists
    print_step "Ensuring OAuth identity provider '$idp_name'..."
    local has_idp
    has_idp=$(oc get oauth cluster -o jsonpath="{.spec.identityProviders[?(@.name==\"${idp_name}\")].name}" 2>/dev/null || true)
    if [ -z "$has_idp" ]; then
        oc patch oauth cluster --type=json -p "[{
            \"op\": \"add\",
            \"path\": \"/spec/identityProviders/-\",
            \"value\": {
                \"name\": \"${idp_name}\",
                \"type\": \"HTPasswd\",
                \"mappingMethod\": \"claim\",
                \"htpasswd\": {
                    \"fileData\": {
                        \"name\": \"${secret_name}\"
                    }
                }
            }
        }]" 2>/dev/null || {
            oc patch oauth cluster --type=merge -p "{
                \"spec\": {
                    \"identityProviders\": [{
                        \"name\": \"${idp_name}\",
                        \"type\": \"HTPasswd\",
                        \"mappingMethod\": \"claim\",
                        \"htpasswd\": {
                            \"fileData\": {
                                \"name\": \"${secret_name}\"
                            }
                        }
                    }]
                }
            }" 2>/dev/null
        }
        print_success "Added '$idp_name' identity provider (OAuth pods will restart)"
    else
        print_info "Identity provider '$idp_name' already configured"
    fi

    # Optionally add users to a group
    if [ -n "$group_name" ]; then
        print_step "Adding users to group '$group_name'..."
        if ! oc get group "$group_name" &>/dev/null 2>&1; then
            oc adm groups new "$group_name" 2>/dev/null
            print_info "Created group '$group_name'"
        fi
        for username in "${usernames[@]}"; do
            username=$(echo "$username" | xargs)
            oc adm groups add-users "$group_name" "$username" 2>/dev/null || true
        done
        print_success "All users added to group '$group_name'"
    fi

    rm -rf "$tmpdir"

    # Return the usernames for downstream use
    _CREATED_USERNAMES=("${usernames[@]}")

    print_success "User creation complete!"
    echo ""
    echo -e "  ${CYAN}Users:${NC}    ${usernames[*]}"
    echo -e "  ${CYAN}Password:${NC} $password"
    echo -e "  ${CYAN}IdP:${NC}      $idp_name"
    [ -n "$group_name" ] && echo -e "  ${CYAN}Group:${NC}    $group_name"
    echo ""
    echo -e "  ${YELLOW}Note:${NC} Users may take 1-2 minutes to be available after OAuth restart"
    echo ""
}

################################################################################
# discover_cluster_roles — Query cluster for ClusterRoles
#   Populates _DISCOVERED_ROLES array and _RHOAI_ROLES array
################################################################################
discover_cluster_roles() {
    local search_pattern="${1:-}"

    # Get all ClusterRole names from the cluster
    local all_roles
    all_roles=$(oc get clusterroles -o name 2>/dev/null | sed 's|^clusterrole.rbac.authorization.k8s.io/||' | sort)

    if [ -z "$all_roles" ]; then
        print_error "Could not retrieve ClusterRoles. Are you logged in?"
        return 1
    fi

    # Filter RHOAI-specific roles
    _RHOAI_ROLES=()
    while IFS= read -r role; do
        if [[ "$role" =~ (datahub|odh|rhods|kserve|opendatahub|rhoai|datasciencecluster|modelmesh|trustyai|codeflare|kuberay|feast) ]]; then
            _RHOAI_ROLES+=("$role")
        fi
    done <<< "$all_roles"

    # If searching, filter all roles
    if [ -n "$search_pattern" ]; then
        _SEARCH_RESULTS=()
        while IFS= read -r role; do
            if [[ "$role" == *"$search_pattern"* ]]; then
                _SEARCH_RESULTS+=("$role")
            fi
        done <<< "$all_roles"
        return 0
    fi

    _ALL_CLUSTER_ROLES=()
    while IFS= read -r role; do
        _ALL_CLUSTER_ROLES+=("$role")
    done <<< "$all_roles"
}

################################################################################
# pick_cluster_roles — Interactive multi-select role picker
#   Sets _SELECTED_ROLES array with chosen role names
################################################################################
pick_cluster_roles() {
    _SELECTED_ROLES=()

    # Build the numbered display list
    local -a display_roles=()
    local -a display_descriptions=()
    local idx=1

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Select ClusterRoleBindings                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Common roles section
    echo -e "  ${MAGENTA}Common Roles:${NC}"
    for role in "${_COMMON_ROLES[@]}"; do
        # Verify the role actually exists on the cluster
        if oc get clusterrole "$role" &>/dev/null 2>&1; then
            local desc="$(_get_role_description "$role")"
            printf "    ${YELLOW}%2d)${NC} %-28s %s\n" "$idx" "$role" "$desc"
            display_roles+=("$role")
            idx=$((idx + 1))
        fi
    done

    # RHOAI roles section (discover from cluster)
    discover_cluster_roles
    if [ ${#_RHOAI_ROLES[@]} -gt 0 ]; then
        echo ""
        echo -e "  ${MAGENTA}RHOAI / AI Roles (discovered from cluster):${NC}"
        for role in "${_RHOAI_ROLES[@]}"; do
            # Skip if already in common list
            local skip=false
            for cr in "${_COMMON_ROLES[@]}"; do
                if [ "$role" = "$cr" ]; then skip=true; break; fi
            done
            [ "$skip" = true ] && continue

            printf "    ${YELLOW}%2d)${NC} %s\n" "$idx" "$role"
            display_roles+=("$role")
            idx=$((idx + 1))
        done
    fi

    echo ""
    echo -e "  ${GREEN}s)${NC}  Search all ClusterRoles by keyword"
    echo -e "  ${GREEN}a)${NC}  Show ALL ClusterRoles (paginated)"
    echo -e "  ${GREEN}n)${NC}  Skip — don't assign any roles"
    echo ""

    while true; do
        read -p "Enter selections (comma-separated, e.g. 1,3,5) or s/a/n: " input
        input=$(echo "$input" | xargs)  # trim

        if [ "$input" = "n" ] || [ "$input" = "N" ]; then
            print_info "No roles selected"
            return 0
        fi

        if [ "$input" = "s" ] || [ "$input" = "S" ]; then
            _pick_roles_by_search display_roles idx
            continue
        fi

        if [ "$input" = "a" ] || [ "$input" = "A" ]; then
            _pick_roles_show_all display_roles idx
            continue
        fi

        # Parse comma-separated numbers
        local valid=true
        IFS=',' read -ra selections <<< "$input"
        for sel in "${selections[@]}"; do
            sel=$(echo "$sel" | xargs)
            if ! [[ "$sel" =~ ^[0-9]+$ ]]; then
                print_error "Invalid input: '$sel' — enter numbers separated by commas"
                valid=false
                break
            fi
            if [ "$sel" -lt 1 ] || [ "$sel" -gt ${#display_roles[@]} ]; then
                print_error "Number $sel is out of range (1-${#display_roles[@]})"
                valid=false
                break
            fi
        done

        if [ "$valid" = true ]; then
            for sel in "${selections[@]}"; do
                sel=$(echo "$sel" | xargs)
                local role_name="${display_roles[$((sel - 1))]}"
                # Avoid duplicates
                local already=false
                for existing in "${_SELECTED_ROLES[@]}"; do
                    if [ "$existing" = "$role_name" ]; then already=true; break; fi
                done
                if [ "$already" = false ]; then
                    _SELECTED_ROLES+=("$role_name")
                fi
            done
            break
        fi
    done

    if [ ${#_SELECTED_ROLES[@]} -gt 0 ]; then
        echo ""
        print_success "Selected roles:"
        for role in "${_SELECTED_ROLES[@]}"; do
            echo -e "  ${GREEN}•${NC} $role"
        done
        echo ""
    fi
}

# Internal: search all ClusterRoles by keyword and add to display list
_pick_roles_by_search() {
    local -n _display_ref=$1
    local -n _idx_ref=$2

    echo ""
    read -p "Enter search keyword: " keyword
    keyword=$(echo "$keyword" | xargs)

    if [ -z "$keyword" ]; then
        print_warning "Empty search — returning to picker"
        return
    fi

    discover_cluster_roles "$keyword"

    if [ ${#_SEARCH_RESULTS[@]} -eq 0 ]; then
        print_warning "No ClusterRoles matching '$keyword'"
        return
    fi

    echo ""
    echo -e "  ${MAGENTA}Search results for '${keyword}':${NC}"
    for role in "${_SEARCH_RESULTS[@]}"; do
        # Skip if already in display list
        local skip=false
        for existing in "${_display_ref[@]}"; do
            if [ "$existing" = "$role" ]; then skip=true; break; fi
        done
        if [ "$skip" = false ]; then
            printf "    ${YELLOW}%2d)${NC} %s\n" "$_idx_ref" "$role"
            _display_ref+=("$role")
            _idx_ref=$((_idx_ref + 1))
        else
            # Show the existing index
            for i in "${!_display_ref[@]}"; do
                if [ "${_display_ref[$i]}" = "$role" ]; then
                    printf "    ${YELLOW}%2d)${NC} %s ${CYAN}(already listed)${NC}\n" "$((i + 1))" "$role"
                    break
                fi
            done
        fi
    done
    echo ""
}

# Internal: show all ClusterRoles paginated and add to display list
_pick_roles_show_all() {
    local -n _display_ref=$1
    local -n _idx_ref=$2

    discover_cluster_roles

    echo ""
    echo -e "  ${MAGENTA}All ClusterRoles (${#_ALL_CLUSTER_ROLES[@]} total):${NC}"

    local page_size=20
    local total=${#_ALL_CLUSTER_ROLES[@]}
    local offset=0

    while [ $offset -lt $total ]; do
        local end=$((offset + page_size))
        [ $end -gt $total ] && end=$total

        for ((i = offset; i < end; i++)); do
            local role="${_ALL_CLUSTER_ROLES[$i]}"
            # Check if already in display list
            local found=false
            local found_idx=0
            for j in "${!_display_ref[@]}"; do
                if [ "${_display_ref[$j]}" = "$role" ]; then
                    found=true
                    found_idx=$((j + 1))
                    break
                fi
            done
            if [ "$found" = true ]; then
                printf "    ${YELLOW}%2d)${NC} %s\n" "$found_idx" "$role"
            else
                printf "    ${YELLOW}%2d)${NC} %s\n" "$_idx_ref" "$role"
                _display_ref+=("$role")
                _idx_ref=$((_idx_ref + 1))
            fi
        done

        offset=$end
        if [ $offset -lt $total ]; then
            echo ""
            read -p "  -- Press Enter for next page, or 'q' to stop -- " page_input
            [ "$page_input" = "q" ] && break
        fi
    done
    echo ""
}

################################################################################
# bind_cluster_roles — Create ClusterRoleBindings for user+role pairs
#   Usage: bind_cluster_roles <usernames_array_name> <roles_array_name>
################################################################################
bind_cluster_roles() {
    local -n _users_ref=$1
    local -n _roles_ref=$2

    if [ ${#_users_ref[@]} -eq 0 ] || [ ${#_roles_ref[@]} -eq 0 ]; then
        print_info "No users or roles to bind — skipping"
        return 0
    fi

    local total_bindings=$(( ${#_users_ref[@]} * ${#_roles_ref[@]} ))
    print_step "Creating $total_bindings ClusterRoleBinding(s)..."

    local created=0
    local skipped=0
    for username in "${_users_ref[@]}"; do
        username=$(echo "$username" | xargs)
        for role in "${_roles_ref[@]}"; do
            local crb_name="${username}-${role}"
            # Truncate to 253 chars (k8s name limit)
            crb_name="${crb_name:0:253}"

            if oc get clusterrolebinding "$crb_name" &>/dev/null 2>&1; then
                skipped=$((skipped + 1))
            else
                oc create clusterrolebinding "$crb_name" \
                    --clusterrole="$role" \
                    --user="$username" \
                    --dry-run=client -o yaml 2>/dev/null | oc apply -f - 2>/dev/null
                created=$((created + 1))
            fi
        done
    done

    print_success "ClusterRoleBindings: $created created, $skipped already existed"
}

################################################################################
# list_user_bindings — Show ClusterRoleBindings for a given user
################################################################################
list_user_bindings() {
    local username="${1:-}"

    if [ -z "$username" ]; then
        read -p "Enter username to inspect: " username
        username=$(echo "$username" | xargs)
    fi

    if [ -z "$username" ]; then
        print_error "Username required"
        return 1
    fi

    print_header "ClusterRoleBindings for '$username'"

    local bindings
    bindings=$(oc get clusterrolebindings -o json 2>/dev/null \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for item in data.get('items', []):
    for subj in item.get('subjects', []):
        if subj.get('kind') == 'User' and subj.get('name') == '${username}':
            role = item.get('roleRef', {}).get('name', 'unknown')
            name = item.get('metadata', {}).get('name', 'unknown')
            results.append((name, role))
            break
if results:
    print(f'Found {len(results)} binding(s):')
    for name, role in sorted(results):
        print(f'  {name:50s} -> {role}')
else:
    print('No ClusterRoleBindings found for this user.')
" 2>/dev/null)

    if [ -z "$bindings" ]; then
        print_info "No ClusterRoleBindings found for '$username'"
    else
        echo "$bindings"
    fi
    echo ""
}

################################################################################
# remove_user_bindings — Remove selected ClusterRoleBindings for a user
################################################################################
remove_user_bindings() {
    local username="${1:-}"

    if [ -z "$username" ]; then
        read -p "Enter username: " username
        username=$(echo "$username" | xargs)
    fi

    if [ -z "$username" ]; then
        print_error "Username required"
        return 1
    fi

    print_header "Remove ClusterRoleBindings for '$username'"

    # Discover bindings
    local -a binding_names=()
    local -a binding_roles=()
    while IFS='|' read -r bname brole; do
        binding_names+=("$bname")
        binding_roles+=("$brole")
    done < <(oc get clusterrolebindings -o json 2>/dev/null \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    for subj in item.get('subjects', []):
        if subj.get('kind') == 'User' and subj.get('name') == '${username}':
            role = item.get('roleRef', {}).get('name', 'unknown')
            name = item.get('metadata', {}).get('name', 'unknown')
            print(f'{name}|{role}')
            break
" 2>/dev/null)

    if [ ${#binding_names[@]} -eq 0 ]; then
        print_info "No ClusterRoleBindings found for '$username'"
        return 0
    fi

    echo -e "  ${MAGENTA}Current bindings:${NC}"
    for i in "${!binding_names[@]}"; do
        printf "    ${YELLOW}%2d)${NC} %-50s -> %s\n" "$((i + 1))" "${binding_names[$i]}" "${binding_roles[$i]}"
    done
    echo ""
    echo -e "  ${GREEN}all)${NC} Remove all bindings"
    echo -e "  ${GREEN}n)${NC}   Cancel"
    echo ""

    read -p "Enter bindings to remove (comma-separated, e.g. 1,3): " input
    input=$(echo "$input" | xargs)

    if [ "$input" = "n" ] || [ "$input" = "N" ] || [ -z "$input" ]; then
        print_info "Cancelled"
        return 0
    fi

    local -a to_remove=()
    if [ "$input" = "all" ]; then
        to_remove=("${binding_names[@]}")
    else
        IFS=',' read -ra selections <<< "$input"
        for sel in "${selections[@]}"; do
            sel=$(echo "$sel" | xargs)
            if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#binding_names[@]} ]; then
                to_remove+=("${binding_names[$((sel - 1))]}")
            else
                print_warning "Skipping invalid selection: $sel"
            fi
        done
    fi

    if [ ${#to_remove[@]} -eq 0 ]; then
        print_info "Nothing to remove"
        return 0
    fi

    echo ""
    echo -e "${RED}About to remove ${#to_remove[@]} ClusterRoleBinding(s):${NC}"
    for name in "${to_remove[@]}"; do
        echo -e "  ${RED}•${NC} $name"
    done
    echo ""
    read -p "Confirm removal? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        return 0
    fi

    local removed=0
    for name in "${to_remove[@]}"; do
        if oc delete clusterrolebinding "$name" 2>/dev/null; then
            removed=$((removed + 1))
        else
            print_warning "Failed to remove: $name"
        fi
    done

    print_success "Removed $removed ClusterRoleBinding(s)"
}

################################################################################
# manage_users_interactive — Full interactive flow: create + assign roles
################################################################################
manage_users_interactive() {
    print_header "Create Users + Assign Roles"

    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift. Run 'oc login' first."
        return 1
    fi
    print_success "Connected to cluster: $(oc whoami --show-server 2>/dev/null)"
    echo ""

    # Step 1: Get usernames
    echo -e "${CYAN}How would you like to specify users?${NC}"
    echo -e "  ${YELLOW}1)${NC} Numbered pattern (e.g. user1, user2, ... userN)"
    echo -e "  ${YELLOW}2)${NC} Custom usernames (comma-separated)"
    echo ""
    read -p "Choice [1]: " user_mode
    user_mode=${user_mode:-1}

    local usernames_input=""
    if [ "$user_mode" = "2" ]; then
        read -p "Enter usernames (comma-separated): " usernames_input
        if [ -z "$usernames_input" ]; then
            print_error "No usernames provided"
            return 1
        fi
    else
        read -p "Username prefix [user]: " prefix
        prefix=${prefix:-user}
        read -p "Number of users [5]: " count
        count=${count:-5}
        usernames_input="${prefix}:${count}"
    fi

    # Step 2: Password
    read -p "Password for all users [openshift]: " password
    password=${password:-openshift}

    # Step 3: IdP name
    read -p "OAuth IdP name [htpasswd]: " idp_name
    idp_name=${idp_name:-htpasswd}

    # Step 4: Optional group
    read -p "Add users to a group? (enter group name or leave blank): " group_name

    # Step 5: Create the users
    echo ""
    create_users "$usernames_input" "$password" "$idp_name" "$group_name"

    # Step 6: Ask about roles
    echo ""
    read -p "Assign ClusterRoleBindings to these users? (Y/n): " assign_roles
    assign_roles=${assign_roles:-Y}

    if [[ "$assign_roles" =~ ^[Yy]$ ]]; then
        pick_cluster_roles

        if [ ${#_SELECTED_ROLES[@]} -gt 0 ]; then
            bind_cluster_roles _CREATED_USERNAMES _SELECTED_ROLES
        fi
    fi

    # Summary
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              User Setup Complete                               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Users:${NC}     ${_CREATED_USERNAMES[*]}"
    echo -e "  ${CYAN}Password:${NC}  $password"
    echo -e "  ${CYAN}IdP:${NC}       $idp_name"
    [ -n "$group_name" ] && echo -e "  ${CYAN}Group:${NC}     $group_name"
    if [ ${#_SELECTED_ROLES[@]} -gt 0 ]; then
        echo -e "  ${CYAN}Roles:${NC}     ${_SELECTED_ROLES[*]}"
    fi
    echo ""
    echo -e "  ${CYAN}Login:${NC}     oc login -u ${_CREATED_USERNAMES[0]} -p $password"
    echo ""
}

################################################################################
# add_roles_interactive — Add roles to existing users (skip user creation)
################################################################################
add_roles_interactive() {
    print_header "Add Roles to Existing Users"

    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift. Run 'oc login' first."
        return 1
    fi

    echo -e "${CYAN}Enter usernames (comma-separated):${NC}"
    read -p "> " usernames_input

    if [ -z "$usernames_input" ]; then
        print_error "No usernames provided"
        return 1
    fi

    # Parse usernames
    local -a usernames=()
    if [[ "$usernames_input" == *":"* ]]; then
        local prefix="${usernames_input%%:*}"
        local count="${usernames_input##*:}"
        for i in $(seq 1 "$count"); do
            usernames+=("${prefix}${i}")
        done
    else
        IFS=',' read -ra usernames <<< "$usernames_input"
        for i in "${!usernames[@]}"; do
            usernames[$i]=$(echo "${usernames[$i]}" | xargs)
        done
    fi

    echo ""
    echo -e "  ${CYAN}Users:${NC} ${usernames[*]}"
    echo ""

    pick_cluster_roles

    if [ ${#_SELECTED_ROLES[@]} -gt 0 ]; then
        bind_cluster_roles usernames _SELECTED_ROLES
    fi
}
