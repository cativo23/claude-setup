#!/usr/bin/env bash
# helpers.bash - Common test utilities for claude-setup

# Load assertion libraries
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

# Mock tracking arrays (used by install_* functions)
setup_test_tracking() {
    INSTALLED_ITEMS=()
    SKIPPED_SECTIONS=()
    FAILED_ITEMS=()
    export INSTALLED_ITEMS SKIPPED_SECTIONS FAILED_ITEMS
}

# Assert array contains element (checks if any array item contains the substring)
assert_array_contains() {
    local element="$1"
    shift
    local arr=("$@")
    local found=0

    for item in "${arr[@]}"; do
        if [[ "$item" == *"$element"* ]]; then
            found=1
            break
        fi
    done

    [[ $found -eq 1 ]]
}

# Assert array contains exact element
assert_array_has() {
    local element="$1"
    shift
    local arr=("$@")
    local found=0

    for item in "${arr[@]}"; do
        if [[ "$item" == "$element" ]]; then
            found=1
            break
        fi
    done

    [[ $found -eq 1 ]]
}
