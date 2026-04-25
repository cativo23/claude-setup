#!/usr/bin/env bats

setup() {
    load "$BATS_TEST_DIRNAME/helpers"
    export ROOT_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"
    source "${ROOT_DIR}/scripts/utils.sh"
    source "${ROOT_DIR}/scripts/commands.sh"
    setup_test_tracking
}

@test "COMMANDS_SRC and COMMANDS_DEST are defined" {
    [[ -n "$COMMANDS_SRC" ]]
    [[ -n "$COMMANDS_DEST" ]]
}

@test "install_commands handles no command files" {
    # Temporarily rename commands dir
    local commands_backup=""
    if [[ -d "${ROOT_DIR}/commands" ]]; then
        commands_backup="${ROOT_DIR}/commands.bak"
        mv "${ROOT_DIR}/commands" "${commands_backup}"
        mkdir -p "${ROOT_DIR}/commands"
    fi

    install_commands
    assert_array_contains "none available" "${SKIPPED_SECTIONS[@]}"

    # Restore
    if [[ -n "$commands_backup" ]]; then
        rm -rf "${ROOT_DIR}/commands"
        mv "${commands_backup}" "${ROOT_DIR}/commands"
    fi
}
