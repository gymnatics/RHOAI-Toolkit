#!/bin/bash
################################################################################
# External Repository Management
################################################################################
# Functions for cloning, updating, and managing external demo repositories.
# Repos are defined in lib/external-repos.conf.
#
# Usage:
#   source lib/functions/external-repos.sh
#   clone_or_update_repo micro-financial-loan
#   path=$(get_repo_path micro-financial-loan)
################################################################################

_EXTREPO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source colors if not already loaded
if ! type print_step &>/dev/null; then
    source "$_EXTREPO_LIB_DIR/lib/utils/colors.sh"
fi

DEMO_REPOS_DIR="${DEMO_REPOS_DIR:-$HOME/.rhoai-demos}"
EXTERNAL_REPOS_CONF="${EXTERNAL_REPOS_CONF:-$_EXTREPO_LIB_DIR/lib/external-repos.conf}"

_parse_repo_entry() {
    local name="$1"
    local line

    line=$(grep "^${name}|" "$EXTERNAL_REPOS_CONF" 2>/dev/null | head -1)
    if [ -z "$line" ]; then
        print_error "Repository '$name' not found in $EXTERNAL_REPOS_CONF"
        return 1
    fi

    REPO_NAME=$(echo "$line" | cut -d'|' -f1)
    REPO_URL=$(echo "$line" | cut -d'|' -f2)
    REPO_REF=$(echo "$line" | cut -d'|' -f3)
    REPO_DESC=$(echo "$line" | cut -d'|' -f4)
}

clone_or_update_repo() {
    local name="$1"
    local ref_override="${2:-}"

    _parse_repo_entry "$name" || return 1

    local ref="${ref_override:-$REPO_REF}"
    local target_dir="$DEMO_REPOS_DIR/$REPO_NAME"

    mkdir -p "$DEMO_REPOS_DIR"

    if [ -d "$target_dir/.git" ]; then
        print_step "Updating $REPO_NAME (ref: $ref)..."
        (
            cd "$target_dir"
            git fetch origin "$ref" --depth 1 2>/dev/null || git fetch origin --depth 1
            git checkout "$ref" 2>/dev/null || git checkout "origin/$ref"
            git pull origin "$ref" 2>/dev/null || true
        )
        print_success "$REPO_NAME updated"
    else
        print_step "Cloning $REPO_NAME (ref: $ref)..."
        rm -rf "$target_dir"
        git clone --depth 1 --branch "$ref" "$REPO_URL" "$target_dir" 2>/dev/null || \
            git clone --depth 1 "$REPO_URL" "$target_dir"
        print_success "$REPO_NAME cloned to $target_dir"
    fi
}

get_repo_path() {
    local name="$1"
    _parse_repo_entry "$name" || return 1
    echo "$DEMO_REPOS_DIR/$REPO_NAME"
}

list_external_repos() {
    if [ ! -f "$EXTERNAL_REPOS_CONF" ]; then
        print_error "Config not found: $EXTERNAL_REPOS_CONF"
        return 1
    fi

    echo ""
    printf "  %-25s %-10s %-50s %s\n" "NAME" "REF" "REPO URL" "DESCRIPTION"
    printf "  %-25s %-10s %-50s %s\n" "----" "---" "--------" "-----------"

    while IFS='|' read -r name url ref desc; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        local status="not cloned"
        if [ -d "$DEMO_REPOS_DIR/$name/.git" ]; then
            status="cloned"
        fi
        printf "  %-25s %-10s %-50s %s [%s]\n" "$name" "$ref" "$url" "$desc" "$status"
    done < "$EXTERNAL_REPOS_CONF"
    echo ""
}

update_all_repos() {
    if [ ! -f "$EXTERNAL_REPOS_CONF" ]; then
        print_error "Config not found: $EXTERNAL_REPOS_CONF"
        return 1
    fi

    print_step "Updating all external repositories..."

    while IFS='|' read -r name url ref desc; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        clone_or_update_repo "$name"
    done < "$EXTERNAL_REPOS_CONF"

    print_success "All repositories updated"
}
