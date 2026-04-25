#!/usr/bin/env bash
# commands.sh - Copy custom slash commands to ~/.claude/commands/

# Load utils only when running standalone
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
    source "${SCRIPT_DIR}/utils.sh"
fi

COMMANDS_SRC="${ROOT_DIR}/commands"
COMMANDS_DEST="${HOME}/.claude/commands"

install_commands() {
    print_header "CUSTOM COMMANDS"

    # Find available commands dynamically
    local command_files=()
    local menu_items=()

    if [[ -d "$COMMANDS_SRC" ]]; then
        while IFS= read -r -d '' file; do
            command_files+=("$file")
            local basename
            basename=$(basename "$file")
            menu_items+=("${basename}|Custom slash command")
        done < <(find "$COMMANDS_SRC" -type f -name "*.md" -print0 2>/dev/null | sort -z)
    fi

    if [[ ${#command_files[@]} -eq 0 ]]; then
        print_info "No custom commands found in ${COMMANDS_SRC}/"
        print_info "Add .md files to commands/ and re-run to install them"
        SKIPPED_SECTIONS+=("Custom Commands (none available)")
        return 0
    fi

    local selected=""
    multi_select selected "Select commands to install" "${menu_items[@]}"

    if [[ -z "$selected" ]]; then
        print_warning "Skipped custom commands"
        SKIPPED_SECTIONS+=("Custom Commands")
        return 0
    fi

    # Ensure destination exists
    mkdir -p "$COMMANDS_DEST"

    for idx in $selected; do
        local src="${command_files[$idx]}"
        local name
        name=$(basename "$src")

        if cp "$src" "${COMMANDS_DEST}/${name}"; then
            print_success "$name"
            INSTALLED_ITEMS+=("Command: $name")
            track_installation "COMMAND" "$name" "${COMMANDS_DEST}/${name}"
        else
            print_error "$name"
            FAILED_ITEMS+=("Command: $name")
        fi
    done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_commands
fi
