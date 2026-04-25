#!/usr/bin/env bash
# plugins.sh - Install Claude Code plugins via CLI

# Load utils only when running standalone
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
    source "${SCRIPT_DIR}/utils.sh"
fi

# ── Plugin definitions ──────────────────────────────────────────────────────
# Format: "name|description|marketplace_add|install_arg"
# marketplace_add: argument for `claude plugin marketplace add`
# install_arg: full argument for `claude plugin install` (name@ref or just name)
PLUGINS=(
    "superpowers|Framework de dev: brainstorm > plan > execute|obra/superpowers-marketplace|superpowers@superpowers-marketplace"
    "security-guidance|Hook automatico de seguridad en Edit/Write|anthropics/claude-plugins-official|security-guidance@claude-plugins-official"
    "fullstack-dev-skills|66 skills por lenguaje/framework|jeffallan/claude-skills|fullstack-dev-skills@fullstack-dev-skills"
    "feature-dev|Workflow guiado de features (7 fases)|anthropics/claude-plugins-official|feature-dev@claude-plugins-official"
    "claude-mem|Memoria persistente entre sesiones|thedotmack/claude-mem|claude-mem"
)

# Parse plugin field by index (0=name, 1=desc, 2=marketplace_add, 3=install_arg)
plugin_field() {
    local plugin="$1" idx="$2"
    local -a fields
    IFS='|' read -r -a fields <<< "$plugin"
    printf '%s' "${fields[$idx]}"
}

install_plugins() {
    print_header "PLUGINS"

    # Build menu items (name|description only)
    local menu_items=()
    for plugin in "${PLUGINS[@]}"; do
        local name
        name=$(plugin_field "$plugin" 0)
        local desc
        desc=$(plugin_field "$plugin" 1)
        menu_items+=("${name}|${desc}")
    done

    local selected=""
    multi_select selected "Select plugins to install" "${menu_items[@]}"

    if [[ -z "$selected" ]]; then
        print_warning "Skipped plugins"
        SKIPPED_SECTIONS+=("Plugins")
        return 0
    fi

    # Collect unique marketplaces needed
    local -A marketplaces_needed=()
    for idx in $selected; do
        local marketplace_add
        marketplace_add=$(plugin_field "${PLUGINS[$idx]}" 2)
        marketplaces_needed["$marketplace_add"]=1
    done

    # Register marketplaces
    print_step "Registering marketplaces..."
    local -A failed_marketplaces=()
    for marketplace in "${!marketplaces_needed[@]}"; do
        local mp_output
        if mp_output=$(claude plugin marketplace add "$marketplace" 2>&1); then
            print_success "Marketplace: ${marketplace}"
        elif echo "$mp_output" | grep -qi "already\|exists\|registered"; then
            print_info "Marketplace: ${marketplace} (already registered)"
        else
            # Real error — surface it so invalid sources aren't silently skipped
            print_error "Marketplace: ${marketplace}"
            echo "    ${mp_output}"
            FAILED_ITEMS+=("Marketplace: $marketplace")
            failed_marketplaces["$marketplace"]=1
        fi
    done

    # Install selected plugins
    print_step "Installing plugins..."
    for idx in $selected; do
        local plugin="${PLUGINS[$idx]}"
        local name
        name=$(plugin_field "$plugin" 0)
        local install_arg
        install_arg=$(plugin_field "$plugin" 3)
        local marketplace_add
        marketplace_add=$(plugin_field "$plugin" 2)

        # Skip if the required marketplace failed to register
        if [[ -n "${failed_marketplaces[$marketplace_add]:-}" ]]; then
            print_warning "$name - skipped (marketplace ${marketplace_add} not registered)"
            FAILED_ITEMS+=("Plugin: $name (marketplace unavailable)")
            continue
        fi

        # claude-mem requires bun
        if [[ "$name" == "claude-mem" ]] && ! command -v bun &>/dev/null; then
            print_error "$name - requires Bun (install: curl -fsSL https://bun.sh/install | bash)"
            FAILED_ITEMS+=("Plugin: $name (missing bun)")
            continue
        fi

        local install_output
        if install_output=$(claude plugin install "$install_arg" 2>&1); then
            print_success "$name"
            INSTALLED_ITEMS+=("Plugin: $name")
            track_installation "PLUGIN" "$name" "${name}"
        else
            print_error "$name"
            echo "    ${install_output}"
            FAILED_ITEMS+=("Plugin: $name")
        fi
    done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_plugins
fi
