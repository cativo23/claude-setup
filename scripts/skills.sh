#!/usr/bin/env bash
# skills.sh - Copy custom skills to ~/.claude/skills/

# Load utils only when running standalone
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
    source "${SCRIPT_DIR}/utils.sh"
fi

SKILLS_SRC="${ROOT_DIR}/skills"
SKILLS_DEST="${HOME}/.claude/skills"

install_skills() {
    print_header "CUSTOM SKILLS"

    # Find available skills dynamically
    local skill_files=()
    local menu_items=()

    if [[ -d "$SKILLS_SRC" ]]; then
        while IFS= read -r -d '' file; do
            skill_files+=("$file")
            local basename
            basename=$(basename "$file")
            menu_items+=("${basename}|Custom skill")
        done < <(find "$SKILLS_SRC" -type f -name "*.md" -print0 2>/dev/null | sort -z)
    fi

    if [[ ${#skill_files[@]} -eq 0 ]]; then
        print_info "No custom skills found in ${SKILLS_SRC}/"
        print_info "Add .md files to skills/ and re-run to install them"
        SKIPPED_SECTIONS+=("Custom Skills (none available)")
        return 0
    fi

    local selected=""
    multi_select selected "Select skills to install" "${menu_items[@]}"

    if [[ -z "$selected" ]]; then
        print_warning "Skipped custom skills"
        SKIPPED_SECTIONS+=("Custom Skills")
        return 0
    fi

    # Ensure destination exists
    mkdir -p "$SKILLS_DEST"

    for idx in $selected; do
        local src="${skill_files[$idx]}"
        local name
        name=$(basename "$src")

        if cp "$src" "${SKILLS_DEST}/${name}"; then
            print_success "$name"
            INSTALLED_ITEMS+=("Skill: $name")
            track_installation "SKILL" "$name" "${SKILLS_DEST}/${name}"
        else
            print_error "$name"
            FAILED_ITEMS+=("Skill: $name")
        fi
    done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_skills
fi
