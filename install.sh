#!/usr/bin/env bash
# install.sh - Claude Code setup orchestrator
# Usage: bash install.sh

set -euo pipefail

# ── Signal Handlers ────────────────────────────────────────────────────────
cleanup_on_exit() {
    local exit_code=$?
    # Restore cursor in case spinner was interrupted
    tput cnorm 2>/dev/null || true
    if [[ $exit_code -eq 0 ]]; then
        cleanup_state_file 2>/dev/null || true
    elif [[ -f "${STATE_FILE:-}" ]] && declare -p ROLLBACK_STACK &>/dev/null && [[ ${#ROLLBACK_STACK[@]} -gt 0 ]]; then
        echo ""
        print_warning "Installation incomplete. State file: $STATE_FILE"
    fi
}

handle_interrupt() {
    # Disable trap inside handler to prevent loops
    trap - SIGINT SIGTERM ERR
    echo ""

    if declare -p ROLLBACK_STACK &>/dev/null && [[ ${#ROLLBACK_STACK[@]} -gt 0 ]]; then
        prompt_error_recovery "Interrupted by user"
    else
        echo "  Installation interrupted by user"
        exit 1
    fi
}

handle_error() {
    local line_num=$1
    local exit_code=$2

    # Disable trap inside handler to prevent loops
    trap - SIGINT SIGTERM ERR

    if [[ $exit_code -ne 0 ]]; then
        if declare -p ROLLBACK_STACK &>/dev/null && [[ ${#ROLLBACK_STACK[@]} -gt 0 ]]; then
            prompt_error_recovery "Error at line $line_num (code $exit_code)"
        else
            echo "  Error at line $line_num (exit code: $exit_code)"
            exit 1
        fi
    fi
}

trap cleanup_on_exit EXIT
trap handle_interrupt SIGINT SIGTERM
trap 'handle_error ${LINENO} $?' ERR

# Load nvm if available (non-interactive shells don't source profile)
# nvm uses unbound variables internally, so temporarily relax -u
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    set +u
    source "$NVM_DIR/nvm.sh"
    nvm use --lts --silent || true
    set -u
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

# Source utils (provides colors, multi_select, tracking arrays, etc.)
source "${ROOT_DIR}/scripts/utils.sh"

# ── Pre-flight checks ──────────────────────────────────────────────────────
check_dependencies() {
    print_step "Checking dependencies..."
    echo ""

    local critical_missing=0

    check_dependency "claude" "Claude CLI" "true" || critical_missing=1
    check_dependency "node" "Node.js" "true" || critical_missing=1
    check_dependency "npx" "npx" "true" || critical_missing=1
    check_dependency "git" "Git" "true" || critical_missing=1
    check_dependency "gh" "GitHub CLI" "false"

    echo ""

    if [[ $critical_missing -eq 1 ]]; then
        print_error "Missing critical dependencies. Please install them and try again."
        echo ""
        echo -e "  ${DIM}Install Claude CLI: https://docs.anthropic.com/en/docs/claude-code${RESET}"
        echo -e "  ${DIM}Install Node.js:    https://nodejs.org${RESET}"
        echo -e "  ${DIM}Install Git:        https://git-scm.com${RESET}"
        echo ""
        exit 1
    fi
}

# ── Source sub-scripts (functions only, don't execute) ──────────────────────
load_modules() {
    # Each module defines an install_* function and uses shared tracking arrays
    source "${ROOT_DIR}/scripts/plugins.sh"
    source "${ROOT_DIR}/scripts/mcp-servers.sh"
    source "${ROOT_DIR}/scripts/skills.sh"
    source "${ROOT_DIR}/scripts/commands.sh"
    source "${ROOT_DIR}/scripts/frameworks.sh"
    source "${ROOT_DIR}/scripts/output-styles.sh"
    source "${ROOT_DIR}/scripts/claude-md.sh"
}

# ── Post-install: statusline variant selection ──────────────────────────
install_statusline_variant() {
    local hooks_dir="${HOME}/.claude/hooks"
    local settings_file="${HOME}/.claude/settings.json"
    local src="${ROOT_DIR}/config/statusline.js"
    local dest="${hooks_dir}/statusline.js"

    if [[ ! -f "$src" ]]; then
        print_warning "Statusline source not found: $src"
        return 0
    fi

    print_header "STATUSLINE"

    # Detect GSD
    local gsd_flag=""
    if [[ -n "${CLAUDE_SETUP_GSD_STATUSLINE:-}" ]] || [[ -f "${HOME}/.claude/hooks/gsd-statusline.js" ]]; then
        gsd_flag="--gsd"
        print_info "GSD detected — statusline will include GSD features"
    fi

    # Ask for variant
    echo ""
    echo "  Statusline variant:"
    echo "    [1] Custom  (3 lines, emojis, full context bar)"
    echo "    [2] Minimal (1 line, ASCII, compact)"
    echo ""
    printf "  Choose [1/2]: "
    read -r variant_choice

    local flags="$gsd_flag"
    case "$variant_choice" in
        2) flags="--minimal${gsd_flag:+ $gsd_flag}" ;;
        *) flags="$gsd_flag" ;;
    esac

    mkdir -p "$hooks_dir"
    cp "$src" "$dest"
    print_success "Statusline installed"

    # Update settings.json
    if [[ -f "$settings_file" ]] && command -v node &>/dev/null; then
        local cmd="node $dest${flags:+ $flags}"
        node -e "
const fs = require('fs');
const settingsFile = process.argv[1];
const cmd = process.argv[2];
const s = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
s.statusLine = { type: 'command', command: cmd, padding: 0 };
fs.writeFileSync(settingsFile, JSON.stringify(s, null, 2) + '\n');
" -- "$settings_file" "$cmd"
        print_success "Settings updated → statusLine: $cmd"
    fi
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    # Check Bash version before any operations
    check_bash_version

    print_banner
    check_dependencies
    load_modules

    init_state_tracking

    # Name + CLAUDE.md + Rules (before plugins, per installer order)
    prompt_user_name
    install_claude_md
    install_rules

    # Run each installer section in order
    install_plugins
    install_mcp_servers
    install_skills
    install_commands
    install_frameworks
    install_output_styles

    install_statusline_variant

    # Copy example configs if they don't exist
    print_header "CONFIG FILES"
    local config_dir="${ROOT_DIR}/config"

    if [[ -f "${config_dir}/settings.example.json" ]]; then
        print_info "Example settings: ${config_dir}/settings.example.json"
    fi
    if [[ -f "${config_dir}/CLAUDE.example.md" ]]; then
        print_info "Example CLAUDE.md: ${config_dir}/CLAUDE.example.md"
    fi
    echo -e "  ${DIM}Copy these to your projects as needed${RESET}"

    # Final summary
    print_summary
}

main "$@"
