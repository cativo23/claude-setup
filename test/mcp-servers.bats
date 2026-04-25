#!/usr/bin/env bats

setup() {
    load "$BATS_TEST_DIRNAME/helpers"
    export ROOT_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"
    source "${ROOT_DIR}/scripts/utils.sh"
    source "${ROOT_DIR}/scripts/mcp-servers.sh"
    setup_test_tracking
}

@test "MCP_SERVERS array is defined" {
    [[ ${#MCP_SERVERS[@]} -gt 0 ]]
}

@test "prompt_secret returns empty for empty input" {
    # This test verifies the function handles empty input
    # Full testing requires interactive mocking which is complex
    skip "Requires interactive input mocking"
}

@test "save_secret creates file with correct permissions" {
    local test_file="${BATS_TEST_TMPDIR}/test_secrets"
    SECRETS_FILE="$test_file"

    save_secret "TEST_KEY" "test_value"

    [[ -f "$test_file" ]]
    run stat -c "%a" "$test_file"
    assert_output "600"

    rm -f "$test_file"
}

@test "check_secrets_permissions fixes wrong permissions" {
    local test_file="${BATS_TEST_TMPDIR}/test_secrets"
    SECRETS_FILE="$test_file"

    # Create file with wrong permissions
    echo "TEST=value" > "$test_file"
    chmod 644 "$test_file"

    run check_secrets_permissions
    run stat -c "%a" "$test_file"
    assert_output "600"

    rm -f "$test_file"
}

@test "check_secrets_permissions skips non-existent file" {
    SECRETS_FILE="${BATS_TEST_TMPDIR}/nonexistent_secrets"
    run check_secrets_permissions
    assert_success
}

@test "check_secrets_permissions keeps correct permissions" {
    local test_file="${BATS_TEST_TMPDIR}/test_secrets"
    SECRETS_FILE="$test_file"

    # Create file with correct permissions
    echo "TEST=value" > "$test_file"
    chmod 600 "$test_file"

    run check_secrets_permissions
    run stat -c "%a" "$test_file"
    assert_output "600"

    rm -f "$test_file"
}

# ── GitHub token validation ──────────────────────────────────────────────
@test "validate_github_token accepts classic PAT (ghp_)" {
    run validate_github_token "ghp_abc123DEF456"
    assert_success
}

@test "validate_github_token accepts fine-grained PAT (github_pat_)" {
    run validate_github_token "github_pat_11ABCDEF0123456789abcdef"
    assert_success
}

@test "validate_github_token accepts OAuth token (gho_)" {
    run validate_github_token "gho_abc123DEF456"
    assert_success
}

@test "validate_github_token accepts user token (ghu_)" {
    run validate_github_token "ghu_abc123DEF456"
    assert_success
}

@test "validate_github_token accepts server token (ghs_)" {
    run validate_github_token "ghs_abc123DEF456"
    assert_success
}

@test "validate_github_token rejects random string" {
    run validate_github_token "some-random-token-value"
    assert_failure
}

@test "validate_github_token rejects empty string" {
    run validate_github_token ""
    assert_failure
}

@test "validate_github_token rejects prefix only" {
    run validate_github_token "ghp_"
    assert_failure
}

@test "validate_github_token rejects similar prefix (ghx_)" {
    run validate_github_token "ghx_abc123"
    assert_failure
}

# ── Tavily key validation ────────────────────────────────────────────────
@test "validate_tavily_key accepts valid key" {
    run validate_tavily_key "tvly-abcdef1234567890abc"
    assert_success
}

@test "validate_tavily_key rejects missing prefix" {
    run validate_tavily_key "abcdef1234567890abcdef"
    assert_failure
}

@test "validate_tavily_key rejects too short" {
    run validate_tavily_key "tvly-abc"
    assert_failure
}

@test "validate_tavily_key rejects empty string" {
    run validate_tavily_key ""
    assert_failure
}

@test "validate_tavily_key rejects special characters" {
    run validate_tavily_key "tvly-abc!@#def1234567890"
    assert_failure
}
