#!/usr/bin/env bash
# output-styles.sh - Copy output styles to ~/.claude/output-styles/

# Load utils only when running standalone
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
    source "${SCRIPT_DIR}/utils.sh"
fi

OUTPUT_STYLES_SRC="${ROOT_DIR}/config/output-styles"
OUTPUT_STYLES_DEST="${HOME}/.claude/output-styles"

install_output_styles() {
    print_header "OUTPUT STYLES"

    local style_files=()
    local menu_items=()

    if [[ -d "$OUTPUT_STYLES_SRC" ]]; then
        while IFS= read -r -d '' file; do
            style_files+=("$file")
            local basename
            basename=$(basename "$file" .md)
            menu_items+=("${basename}|Custom output style")
        done < <(find "$OUTPUT_STYLES_SRC" -type f -name "*.md" -print0 2>/dev/null | sort -z)
    fi

    if [[ ${#style_files[@]} -eq 0 ]]; then
        print_info "No output styles found in ${OUTPUT_STYLES_SRC}/"
        print_info "Add .md files to config/output-styles/ and re-run to install them"
        SKIPPED_SECTIONS+=("Output Styles (none available)")
        return 0
    fi

    local selected=""
    multi_select selected "Select output styles to install" "${menu_items[@]}"

    if [[ -z "$selected" ]]; then
        print_warning "Skipped output styles"
        SKIPPED_SECTIONS+=("Output Styles")
        return 0
    fi

    mkdir -p "$OUTPUT_STYLES_DEST"

    for idx in $selected; do
        local src="${style_files[$idx]}"
        local name
        name=$(basename "$src")

        if cp "$src" "${OUTPUT_STYLES_DEST}/${name}"; then
            print_success "$name"
            INSTALLED_ITEMS+=("Output Style: $name")
            track_installation "OUTPUT_STYLE" "$name" "${OUTPUT_STYLES_DEST}/${name}"
        else
            print_error "$name"
            FAILED_ITEMS+=("Output Style: $name")
        fi
    done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_output_styles
fi
