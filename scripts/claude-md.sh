#!/usr/bin/env bash
# claude-md.sh - Install global CLAUDE.md and rules

set -euo pipefail

# Load utils only when running standalone
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
    source "${SCRIPT_DIR}/utils.sh"
fi

CLAUDE_MD_SRC="${ROOT_DIR}/config/claude-md"
RULES_SRC="${ROOT_DIR}/config/rules"
CLAUDE_MD_DEST="${HOME}/.claude/CLAUDE.md"
RULES_DEST="${HOME}/.claude/rules"

# ── Step 1: Name (obligatory) ────────────────────────────────────────────────
prompt_user_name() {
    print_header "NAME"

    local existing_name=""

    # Detect existing name
    if [[ -f "$CLAUDE_MD_DEST" ]]; then
        existing_name=$(sed -n 's/.*Call me \*\*\([^*]*\)\*\*.*/\1/p' "$CLAUDE_MD_DEST" 2>/dev/null | head -1 || true)
    fi

    if [[ -n "$existing_name" ]]; then
        echo -e "  Current name: ${BOLD}${existing_name}${RESET}"
        printf "  Keep it? [Y/n] "
        local keep_answer
        if [[ -t 0 ]]; then
            read -r keep_answer
        else
            read -r keep_answer < /dev/tty
        fi
        if [[ ! "$keep_answer" =~ ^[Nn] ]]; then
            print_success "Keeping name: $existing_name"
            INSTALLED_ITEMS+=("Name: $existing_name")
            return 0
        fi
    fi

    local user_name=""
    while [[ -z "$user_name" ]]; do
        printf "  How should Claude address you? "
        if [[ -t 0 ]]; then
            read -r user_name
        else
            read -r user_name < /dev/tty
        fi
        if [[ -z "$user_name" ]]; then
            print_error "Name is required"
        fi
    done

    # Back up existing CLAUDE.md if present
    if [[ -f "$CLAUDE_MD_DEST" ]]; then
        cp "$CLAUDE_MD_DEST" "${CLAUDE_MD_DEST}.bak"
    fi

    # If CLAUDE.md exists, update only the User section; otherwise create new
    if [[ -f "$CLAUDE_MD_DEST" ]] && grep -q '^# User' "$CLAUDE_MD_DEST" 2>/dev/null; then
        # Replace existing User section (from # User to next ## or # heading or EOF)
        local tmp_file
        tmp_file=$(mktemp)
        name="$user_name" awk '
            /^# User/ { printf "# User\n\nCall me **%s**.\n", ENVIRON["name"]; skip=1; next }
            skip && /^#/ { skip=0 }
            skip { next }
            { print }
        ' "$CLAUDE_MD_DEST" > "$tmp_file"
        mv "$tmp_file" "$CLAUDE_MD_DEST"
    else
        mkdir -p "$(dirname "$CLAUDE_MD_DEST")"
        cat > "$CLAUDE_MD_DEST" <<EOF
# User

Call me **${user_name}**.
EOF
    fi

    print_success "Name set: $user_name → $CLAUDE_MD_DEST"
    INSTALLED_ITEMS+=("Name: $user_name")
    track_installation "CLAUDE_MD" "CLAUDE.md" "$CLAUDE_MD_DEST"
}

# ── Step 2: CLAUDE.md modules (optional) ──────────────────────────────────────
install_claude_md() {
    print_header "CLAUDE.MD MODULES"

    local module_files=()
    local menu_items=()

    # Module definitions: "filename|description"
    local MODULE_DEFS=(
        "git-defaults|Conventional commits, PR format, branch naming conventions"
    )

    for def in "${MODULE_DEFS[@]}"; do
        local basename="${def%%|*}"
        local desc="${def#*|}"
        local filepath="${CLAUDE_MD_SRC}/${basename}.md"
        if [[ -f "$filepath" ]]; then
            module_files+=("$filepath")
            menu_items+=("${basename}|${desc}")
        fi
    done

    if [[ ${#module_files[@]} -eq 0 ]]; then
        print_info "No CLAUDE.md modules found in ${CLAUDE_MD_SRC}/"
        SKIPPED_SECTIONS+=("CLAUDE.md Modules (none available)")
        return 0
    fi

    echo -e "  ${DIM}CLAUDE.md is your global instruction file — Claude reads it at the${RESET}"
    echo -e "  ${DIM}start of every session, in every project. Use it for preferences${RESET}"
    echo -e "  ${DIM}that should always apply.${RESET}"
    echo ""

    local selected=""
    multi_select selected "Select CLAUDE.md modules to add" "${menu_items[@]}"

    if [[ -z "$selected" ]]; then
        print_warning "Skipped CLAUDE.md modules"
        SKIPPED_SECTIONS+=("CLAUDE.md Modules")
        return 0
    fi

    for idx in $selected; do
        local src="${module_files[$idx]}"
        local name
        name=$(basename "$src" .md)

        # Extract the section heading from the module (first ## line)
        local section_heading
        section_heading=$(grep -m1 '^## ' "$src" 2>/dev/null || echo "## $name")

        # Idempotency: skip if section already exists in CLAUDE.md
        if grep -qF "$section_heading" "$CLAUDE_MD_DEST" 2>/dev/null; then
            print_info "$name (already in CLAUDE.md, skipping)"
            continue
        fi

        # Append module content to CLAUDE.md
        echo "" >> "$CLAUDE_MD_DEST"
        cat "$src" >> "$CLAUDE_MD_DEST"

        print_success "$name"
        INSTALLED_ITEMS+=("CLAUDE.md Module: $name")
    done
}

# ── Step 3: Rules (optional) ──────────────────────────────────────────────────
install_rules() {
    print_header "RULES"

    local rule_files=()
    local menu_items=()

    # Rule definitions: "filename|description"
    local RULE_DEFS=(
        "ipa-methodology|Investigate→Plan→Act workflow + decision logic"
        "security-first|Never expose secrets, validate inputs"
        "tdd-first|Red→Green→Refactor cycle"
        "code-review-mindset|Impact analysis, document decisions"
        "minimalist|YAGNI, smallest viable solution"
    )

    for def in "${RULE_DEFS[@]}"; do
        local basename="${def%%|*}"
        local desc="${def#*|}"
        local filepath="${RULES_SRC}/${basename}.md"
        if [[ -f "$filepath" ]]; then
            rule_files+=("$filepath")
            menu_items+=("${basename}|${desc}")
        fi
    done

    if [[ ${#rule_files[@]} -eq 0 ]]; then
        print_info "No rules found in ${RULES_SRC}/"
        SKIPPED_SECTIONS+=("Rules (none available)")
        return 0
    fi

    echo -e "  ${DIM}Rules are modular instruction files in ~/.claude/rules/. Claude loads${RESET}"
    echo -e "  ${DIM}them every session alongside CLAUDE.md. Each rule focuses on one${RESET}"
    echo -e "  ${DIM}methodology or practice.${RESET}"
    echo ""

    local selected=""
    multi_select selected "--none:Select rules to install" "${menu_items[@]}"

    if [[ -z "$selected" ]]; then
        print_warning "Skipped rules"
        SKIPPED_SECTIONS+=("Rules")
        return 0
    fi

    mkdir -p "$RULES_DEST"

    for idx in $selected; do
        local src="${rule_files[$idx]}"
        local name
        name=$(basename "$src")

        if cp "$src" "${RULES_DEST}/${name}"; then
            print_success "$name"
            INSTALLED_ITEMS+=("Rule: ${name%.md}")
            track_installation "RULE" "$name" "${RULES_DEST}/${name}"
        else
            print_error "$name"
            FAILED_ITEMS+=("Rule: ${name%.md}")
        fi
    done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    prompt_user_name
    install_claude_md
    install_rules
fi
