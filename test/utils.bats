#!/usr/bin/env bats

# Load helpers (use absolute path for bats load)
load "$BATS_TEST_DIRNAME/helpers"

# Source the script under test
source "$BATS_TEST_DIRNAME/../scripts/utils.sh"

@test "print_success outputs with checkmark" {
    run print_success "test message"
    assert_success
    assert_output --regexp '✓.*test message'
}

@test "print_error outputs with cross" {
    run print_error "test error"
    assert_success
    assert_output --regexp '✗.*test error'
}

@test "print_warning outputs with arrow" {
    run print_warning "test warning"
    assert_success
    assert_output --regexp '→.*test warning'
}

@test "print_info outputs with bullet" {
    run print_info "test info"
    assert_success
    assert_output --regexp '•.*test info'
}

@test "print_header creates bordered header" {
    run print_header "TEST"
    assert_success
    assert_output --regexp '━.*TEST.*━'
}

@test "check_dependency returns success for existing command" {
    run check_dependency "bash" "Bash" "true"
    assert_success
}

@test "check_dependency returns failure for missing required command" {
    run check_dependency "nonexistent_command_xyz" "Missing" "true"
    assert_failure
}

@test "check_bash_version passes for Bash 5+" {
    run check_bash_version
    assert_success
}

@test "check_bash_version detects non-Bash shell" {
    # This test would require mocking BASH_VERSION which breaks the test environment
    # Skipping because Bats runs under Bash by default
    skip "Cannot mock BASH_VERSION in Bats environment"
}

@test "state tracking functions create and populate file" {
    run init_state_tracking
    assert_success

    run get_state_file
    assert_success
    state_file="$output"

    run track_installation "PLUGIN" "test-plugin" "test-data"
    assert_success

    run grep "PLUGIN|test-plugin|test-data" "$state_file"
    assert_success

    run cleanup_state_file
    assert_success

    run test -f "$state_file"
    assert_failure
}
