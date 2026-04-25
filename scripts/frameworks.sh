#!/usr/bin/env bash
# frameworks.sh - Install development frameworks

# Load utils only when running standalone
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
    source "${SCRIPT_DIR}/utils.sh"
fi

FRAMEWORKS=(
    "GSD (Get Shit Done)|Meta-prompting con contextos frescos"
)

install_frameworks() {
    print_header "FRAMEWORKS"

    local selected=""
    multi_select selected "Select frameworks to install" "${FRAMEWORKS[@]}"

    if [[ -z "$selected" ]]; then
        print_warning "Skipped frameworks"
        SKIPPED_SECTIONS+=("Frameworks")
        return 0
    fi

    for idx in $selected; do
        case $idx in
            0) install_gsd ;;
        esac
    done
}

install_gsd() {
    # Check if already installed (GSD creates hooks in ~/.claude/hooks/)
    if [[ -f "${HOME}/.claude/hooks/gsd-statusline.js" ]]; then
        print_info "GSD already installed"
        INSTALLED_ITEMS+=("Framework: GSD (already installed)")
        export CLAUDE_SETUP_GSD_STATUSLINE=1
        return 0
    fi

    print_step "Installing GSD..."

    if command -v npx &>/dev/null; then
        echo ""
        print_info "GSD is interactive - follow the prompts below"
        echo ""
        if npx get-shit-done-cc@latest; then
            print_success "GSD (Get Shit Done)"
            INSTALLED_ITEMS+=("Framework: GSD")
            track_installation "FRAMEWORK" "GSD" "$HOME/.claude/hooks/gsd-statusline.js"
            export CLAUDE_SETUP_GSD_STATUSLINE=1
        else
            print_error "GSD installation failed"
            FAILED_ITEMS+=("Framework: GSD")
        fi
    else
        print_error "GSD requires npx (install Node.js first)"
        FAILED_ITEMS+=("Framework: GSD")
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_frameworks
fi
