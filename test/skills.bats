#!/usr/bin/env bats

setup() {
    load "$BATS_TEST_DIRNAME/helpers"
    export ROOT_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"
    source "${ROOT_DIR}/scripts/utils.sh"
    source "${ROOT_DIR}/scripts/skills.sh"
    setup_test_tracking
}

@test "SKILLS_SRC and SKILLS_DEST are defined" {
    [[ -n "$SKILLS_SRC" ]]
    [[ -n "$SKILLS_DEST" ]]
}

@test "install_skills handles no skill files" {
    # Temporarily rename skills dir
    local skills_backup=""
    if [[ -d "${ROOT_DIR}/skills" ]]; then
        skills_backup="${ROOT_DIR}/skills.bak"
        mv "${ROOT_DIR}/skills" "${skills_backup}"
        mkdir -p "${ROOT_DIR}/skills"
    fi

    install_skills
    assert_array_contains "none available" "${SKIPPED_SECTIONS[@]}"

    # Restore
    if [[ -n "$skills_backup" ]]; then
        rm -rf "${ROOT_DIR}/skills"
        mv "${skills_backup}" "${ROOT_DIR}/skills"
    fi
}
