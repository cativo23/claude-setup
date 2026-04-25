#!/usr/bin/env bash
# mcp-servers.sh - Configure MCP servers with interactive secret collection

# Load utils only when running standalone
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
    source "${SCRIPT_DIR}/utils.sh"
fi

SECRETS_FILE="${HOME}/.env.secrets"

# ── Server definitions ──────────────────────────────────────────────────────
MCP_SERVERS=(
    "GitHub|Issues, PRs, CI/CD desde Claude"
    "Tavily|Busqueda web con AI"
)

# ── Secret format validators ─────────────────────────────────────────────
validate_github_token() {
    local token="$1"
    # Classic PATs, fine-grained PATs, OAuth, user, server-to-server tokens
    [[ "$token" =~ ^(ghp_|github_pat_|gho_|ghu_|ghs_)[a-zA-Z0-9_]+ ]]
}

validate_tavily_key() {
    local key="$1"
    # tvly- prefix + at least 15 alphanumeric chars (min ~20 total)
    [[ "$key" =~ ^tvly-[a-zA-Z0-9_-]{15,} ]]
}

# ── Check and fix secrets file permissions ─────────────────────────────────
check_secrets_permissions() {
    if [[ -f "$SECRETS_FILE" ]]; then
        local perms
        if [[ "$(uname)" == "Darwin" ]]; then
            perms=$(stat -f "%Lp" "$SECRETS_FILE" 2>/dev/null)
        else
            perms=$(stat -c "%a" "$SECRETS_FILE" 2>/dev/null)
        fi
        if [[ "$perms" != "600" ]]; then
            print_warning "Secrets file has insecure permissions (${perms}). Fixing to 600." >&2
            chmod 600 "$SECRETS_FILE"
        fi
    fi
}

# ── Secret prompt helper ────────────────────────────────────────────────────
prompt_secret() {
    local name="$1"
    local prompt_msg="$2"
    local help_url="$3"
    local validate_fn="${4:-}"      # Optional: validator function name
    local format_hint="${5:-}"      # Optional: human-readable format hint
    local secret=""

    echo "" >&2
    print_info "${name}" >&2
    echo -e "    ${DIM}${prompt_msg}${RESET}" >&2
    echo -e "    ${DIM}Get it at: ${CYAN}${help_url}${RESET}" >&2
    echo "" >&2

    local attempts=0
    local max_attempts=2

    while true; do
        read -rsp "    Enter ${name}: " secret < /dev/tty
        echo "" >&2

        # Check empty
        if [[ -z "$secret" ]]; then
            attempts=$((attempts + 1))
            if [[ $attempts -ge $max_attempts ]]; then
                read -rp "    Skip ${name}? [y/N] " skip < /dev/tty
                if [[ "$skip" =~ ^[Yy] ]]; then
                    return 1
                fi
                attempts=0
            else
                print_warning "Secret cannot be empty. Try again." >&2
            fi
            continue
        fi

        # Format validation (if validator provided)
        if [[ -n "$validate_fn" ]] && ! "$validate_fn" "$secret"; then
            attempts=$((attempts + 1))
            print_error "Invalid format for ${name}." >&2
            if [[ -n "$format_hint" ]]; then
                echo -e "    ${DIM}Expected: ${format_hint}${RESET}" >&2
            fi
            echo -e "    ${DIM}Generate a new one at: ${CYAN}${help_url}${RESET}" >&2
            if [[ $attempts -ge $max_attempts ]]; then
                read -rp "    Skip ${name}? [y/N] " skip < /dev/tty
                if [[ "$skip" =~ ^[Yy] ]]; then
                    return 1
                fi
                attempts=0
            fi
            secret=""
            continue
        fi

        break
    done

    echo "$secret"
    return 0
}

# ── Save secret to file ────────────────────────────────────────────────────
# Note: chmod 600 is applied on every write operation for security
save_secret() {
    local key="$1"
    local value="$2"

    # Create secrets file if it doesn't exist
    if [[ ! -f "$SECRETS_FILE" ]]; then
        touch "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
    fi

    # Remove existing entry if present
    if grep -q "^${key}=" "$SECRETS_FILE" 2>/dev/null; then
        local tmp
        tmp=$(mktemp)
        grep -v "^${key}=" "$SECRETS_FILE" > "$tmp"
        mv "$tmp" "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
    fi

    # Append new entry
    printf '%s=%s\n' "$key" "$value" >> "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
}

# ── Check if MCP server already exists ─────────────────────────────────────
mcp_exists() {
    claude mcp get "$1" &>/dev/null
}

# ── Install GitHub MCP ──────────────────────────────────────────────────────
install_github_mcp() {
    if mcp_exists "github"; then
        print_info "GitHub MCP server already configured"
        INSTALLED_ITEMS+=("MCP: GitHub (already configured)")
        return 0
    fi

    local secret
    secret=$(prompt_secret \
        "GitHub Personal Access Token (fine-grained)" \
        "Fine-grained PAT with Contents, Issues, Pull requests, Actions permissions" \
        "https://github.com/settings/personal-access-tokens/new" \
        "validate_github_token" \
        "ghp_*, github_pat_*, gho_*, ghu_*, or ghs_* prefix") || {
        print_warning "Skipped GitHub MCP server"
        SKIPPED_SECTIONS+=("MCP: GitHub")
        return 0
    }

    if claude mcp add --transport http github "https://api.githubcopilot.com/mcp/" \
        -H "Authorization: Bearer ${secret}" 2>/dev/null; then
        print_success "GitHub MCP server configured"
        save_secret "GITHUB_TOKEN" "$secret"
        INSTALLED_ITEMS+=("MCP: GitHub")
        track_installation "MCP" "GitHub" "github"
    else
        print_error "Failed to configure GitHub MCP server"
        FAILED_ITEMS+=("MCP: GitHub")
    fi
}

# ── Install Tavily MCP ─────────────────────────────────────────────────────
install_tavily_mcp() {
    if mcp_exists "tavily"; then
        print_info "Tavily MCP server already configured"
        INSTALLED_ITEMS+=("MCP: Tavily (already configured)")
        return 0
    fi

    local secret
    secret=$(prompt_secret \
        "Tavily API Key" \
        "AI-powered web search for development" \
        "https://tavily.com" \
        "validate_tavily_key" \
        "tvly-* prefix, 20+ characters") || {
        print_warning "Skipped Tavily MCP server"
        SKIPPED_SECTIONS+=("MCP: Tavily")
        return 0
    }

    if TAVILY_API_KEY="$secret" claude mcp add tavily \
        -- npx -y tavily-mcp@latest 2>/dev/null; then
        print_success "Tavily MCP server configured"
        save_secret "TAVILY_API_KEY" "$secret"
        INSTALLED_ITEMS+=("MCP: Tavily")
        track_installation "MCP" "Tavily" "tavily"
    else
        print_error "Failed to configure Tavily MCP server"
        FAILED_ITEMS+=("MCP: Tavily")
    fi
}

# ── Main ────────────────────────────────────────────────────────────────────
install_mcp_servers() {
    # Fix permissions on existing secrets file before any operations
    check_secrets_permissions

    print_header "MCP SERVERS"

    local selected=""
    multi_select selected "Select MCP servers to configure" "${MCP_SERVERS[@]}"

    if [[ -z "$selected" ]]; then
        print_warning "Skipped MCP servers"
        SKIPPED_SECTIONS+=("MCP Servers")
        return 0
    fi

    for idx in $selected; do
        case $idx in
            0) install_github_mcp ;;
            1) install_tavily_mcp ;;
        esac
    done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_mcp_servers
fi
