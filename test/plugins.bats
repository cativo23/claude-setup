#!/usr/bin/env bats

setup() {
    load "$BATS_TEST_DIRNAME/helpers"
    export ROOT_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"
    source "${ROOT_DIR}/scripts/utils.sh"
    source "${ROOT_DIR}/scripts/plugins.sh"
    setup_test_tracking
}

@test "PLUGINS array is defined with correct format" {
    [[ ${#PLUGINS[@]} -gt 0 ]]
}

@test "install_plugins handles empty selection" {
    # Mock multi_select to return empty
    multi_select() {
        local _result_var=$1
        local -n _result=$1
        _result=""
    }

    install_plugins
    # Check that SKIPPED_SECTIONS contains "Plugins"
    [[ "${SKIPPED_SECTIONS[*]}" == *"Plugins"* ]]
}
