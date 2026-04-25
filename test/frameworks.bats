#!/usr/bin/env bats

setup() {
    load "$BATS_TEST_DIRNAME/helpers"
    export ROOT_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"
    source "${ROOT_DIR}/scripts/utils.sh"
    source "${ROOT_DIR}/scripts/frameworks.sh"
    setup_test_tracking
}

@test "FRAMEWORKS array is defined" {
    [[ ${#FRAMEWORKS[@]} -gt 0 ]]
}

@test "install_frameworks handles empty selection" {
    multi_select() {
        local _result_var=$1
        local -n _result=$1
        _result=""
    }

    install_frameworks
    # Check that SKIPPED_SECTIONS contains "Frameworks"
    [[ "${SKIPPED_SECTIONS[*]}" == *"Frameworks"* ]]
}
