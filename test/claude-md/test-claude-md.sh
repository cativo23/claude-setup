#!/usr/bin/env bash
# ============================================================================
# CLAUDE.md + Rules — Automated Test Suite
# ============================================================================
# JSON-driven, parallel execution. Tests rules independently of output styles.
#
# Usage: ./test-claude-md.sh [options]
#   --eval-model MODEL   Model for evaluating responses (default: sonnet)
#   --test-model MODEL   Model for generating responses (default: sonnet)
#   --test-id ID         Run only a specific test (e.g., 1.1)
#   --block N            Run only Block N (e.g., --block 3)
#   --parallel N         Max concurrent workers (default: 8, 0=unlimited)
#   --yes                Skip Y/n prompt, auto-confirm (for CI)
#   --user-name NAME     Name to use in CLAUDE.md (default: TestUser)
# ============================================================================

set -euo pipefail

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_JSON="$SCRIPT_DIR/tests.json"
RESULTS_DIR="$SCRIPT_DIR/results"
CONFIG_DIR="$(cd "$SCRIPT_DIR/../../config" && pwd)"

# --- Config ---
EVAL_MODEL="${EVAL_MODEL:-sonnet}"
TEST_MODEL="${TEST_MODEL:-sonnet}"
USER_NAME="TestUser"

# --- Args ---
FILTER_TEST=""
FILTER_BLOCK=""
PARALLEL_N=8
AUTO_YES=0

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# --- State ---
SCRIPT_PID=$$
declare -a TEMP_LOGS=()
declare -a BG_PIDS=()
declare -a TEST_IDS=()
SINGLE_COUNT=0
SEQ_COUNT=0
TOTAL_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
EST_CALLS=0
EST_TOKENS=0
EST_COST="0.00"
CLEANUP_DONE=0

# ============================================================================
# parse_args
# ============================================================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --eval-model) EVAL_MODEL="$2"; shift 2 ;;
      --test-model) TEST_MODEL="$2"; shift 2 ;;
      --test-id)    FILTER_TEST="$2"; shift 2 ;;
      --block)      FILTER_BLOCK="$2"; shift 2 ;;
      --parallel)   PARALLEL_N="$2"; shift 2 ;;
      --yes)        AUTO_YES=1; shift ;;
      --user-name)  USER_NAME="$2"; shift 2 ;;
      -h|--help)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --eval-model MODEL   Model for evaluating responses (default: sonnet)"
        echo "  --test-model MODEL   Model for generating responses (default: sonnet)"
        echo "  --test-id ID         Run only a specific test (e.g., 1.1)"
        echo "  --block N            Run only Block N (e.g., --block 3)"
        echo "  --parallel N         Max concurrent workers (default: 8, 0=unlimited)"
        echo "  --yes                Skip Y/n prompt, auto-confirm"
        echo "  --user-name NAME     Name for CLAUDE.md tests (default: TestUser)"
        exit 0
        ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
}

# ============================================================================
# build_system_prompt — builds system prompt from requires field
# ============================================================================
build_system_prompt() {
  local requires="$1"
  local prompt=""

  # Always include CLAUDE.md name section
  prompt="# User

Call me **${USER_NAME}**."

  case "$requires" in
    claude-md)
      # Name only, already set
      ;;
    git-defaults)
      if [[ -f "$CONFIG_DIR/claude-md/git-defaults.md" ]]; then
        prompt="${prompt}

$(cat "$CONFIG_DIR/claude-md/git-defaults.md")"
      fi
      ;;
    ipa-methodology|security-first|tdd-first|code-review-mindset|minimalist)
      if [[ -f "$CONFIG_DIR/rules/${requires}.md" ]]; then
        prompt="${prompt}

$(cat "$CONFIG_DIR/rules/${requires}.md")"
      fi
      ;;
  esac

  echo "$prompt"
}

# ============================================================================
# load_tests
# ============================================================================
load_tests() {
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required. Install: sudo apt install jq  /  brew install jq" >&2
    exit 1
  fi
  if [[ ! -f "$TESTS_JSON" ]]; then
    echo "Error: tests.json not found at $TESTS_JSON" >&2
    exit 1
  fi
  if ! jq empty "$TESTS_JSON" 2>/dev/null; then
    echo "Error: tests.json is not valid JSON" >&2
    exit 1
  fi
}

# ============================================================================
# build_filter
# ============================================================================
build_filter() {
  local filter=".[]"
  if [[ -n "$FILTER_TEST" ]]; then
    filter="${filter} | select(.id == \"$FILTER_TEST\")"
  elif [[ -n "$FILTER_BLOCK" ]]; then
    filter="${filter} | select(.block_id == $FILTER_BLOCK)"
  fi
  echo "$filter"
}

# ============================================================================
# count_tests
# ============================================================================
count_tests() {
  local filter
  filter=$(build_filter)
  local all_tests
  all_tests=$(jq -c "[$filter]" "$TESTS_JSON")

  SINGLE_COUNT=$(echo "$all_tests" | jq '[.[] | select(.type == "single")] | length')
  SEQ_COUNT=$(echo "$all_tests" | jq '[.[] | select(.type == "sequential")] | length')
  TOTAL_COUNT=$(( SINGLE_COUNT + SEQ_COUNT ))

  mapfile -t TEST_IDS < <(echo "$all_tests" | jq -r '.[].id')
}

# ============================================================================
# estimate_usage
# ============================================================================
estimate_usage() {
  local token_est=$(( SINGLE_COUNT * 2500 + SEQ_COUNT * 4000 ))
  local call_est=$(( SINGLE_COUNT * 2 + SEQ_COUNT * 3 ))
  local cost_cents=$(( token_est / 1250 ))
  local cost_dollars=$(( cost_cents / 100 ))
  local cost_cents_rem=$(( cost_cents % 100 ))

  EST_CALLS=$call_est
  EST_TOKENS=$token_est
  EST_COST=$(printf "%d.%02d" "$cost_dollars" "$cost_cents_rem")
}

# ============================================================================
# print_prerun_summary
# ============================================================================
print_prerun_summary() {
  local filter_note="none"
  [[ -n "$FILTER_TEST" ]] && filter_note="id=$FILTER_TEST"
  [[ -n "$FILTER_BLOCK" ]] && filter_note="block=$FILTER_BLOCK"

  local parallel_note
  if [[ "$PARALLEL_N" -eq 0 ]]; then
    parallel_note="unlimited"
  else
    parallel_note="$PARALLEL_N at a time"
  fi

  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║   📋 CLAUDE.md + Rules Test Suite            ║"
  echo "╚══════════════════════════════════════════════╝"
  echo -e "${NC}"
  printf "  %-16s %s\n" "Tests:" "$TOTAL_COUNT ($SINGLE_COUNT single + $SEQ_COUNT sequential + filter: $filter_note)"
  printf "  %-16s %s\n" "Test model:" "$TEST_MODEL"
  printf "  %-16s %s\n" "Eval model:" "$EVAL_MODEL"
  printf "  %-16s %s\n" "User name:" "$USER_NAME"
  printf "  %-16s %s\n" "Parallel:" "$parallel_note"
  printf "  %-16s ~%s API calls\n" "Est. calls:" "$EST_CALLS"
  printf "  %-16s ~%s tokens  (rough estimate)\n" "Est. tokens:" "$EST_TOKENS"
  printf "  %-16s ~\$%s USD      (rough estimate, prices change)\n" "Est. cost:" "$EST_COST"
  echo ""
}

# ============================================================================
# prompt_confirm
# ============================================================================
prompt_confirm() {
  if [[ "$AUTO_YES" -eq 1 ]] || [[ ! -t 0 ]]; then
    echo "  Auto-confirming (--yes or non-interactive mode)"
    return 0
  fi
  printf "  Run? [Y/n] "
  read -r answer
  case "$answer" in
    [nN]*) echo "Aborted."; exit 0 ;;
    *) return 0 ;;
  esac
}

# ============================================================================
# cleanup
# ============================================================================
cleanup() {
  [[ $CLEANUP_DONE -eq 1 ]] && return
  CLEANUP_DONE=1
  tput cnorm 2>/dev/null || true
  if [[ ${#BG_PIDS[@]} -gt 0 ]]; then
    for pid in "${BG_PIDS[@]}"; do
      kill "$pid" 2>/dev/null || true
    done
    wait "${BG_PIDS[@]}" 2>/dev/null || true
  fi
  if [[ "${INTERRUPTED:-0}" -eq 1 ]]; then
    echo -e "\n${YELLOW}Interrupted — showing partial results${NC}"
    print_block_results || true
  fi
  if [[ ${#TEMP_LOGS[@]} -gt 0 ]]; then
    for log in "${TEMP_LOGS[@]}"; do
      rm -f "$log"
    done
  fi
}

# ============================================================================
# send_prompt
# ============================================================================
send_prompt() {
  local prompt="$1"
  local system_prompt="$2"
  local out_file err_file
  out_file=$(mktemp)
  err_file=$(mktemp)

  local sp_args=()
  [[ -n "$system_prompt" ]] && sp_args=(--system-prompt "$system_prompt")

  timeout 90 claude -p "$prompt" \
    --output-format json \
    --model "$TEST_MODEL" \
    --no-session-persistence \
    "${sp_args[@]}" \
    </dev/null \
    >"$out_file" 2>"$err_file"
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    local err_msg
    err_msg=$(cat "$err_file" 2>/dev/null)
    rm -f "$out_file" "$err_file"
    if [[ $exit_code -eq 124 ]]; then
      echo '{"result": "ERROR: timeout after 90s"}'
    else
      jq -n --arg msg "ERROR (exit $exit_code): $err_msg" '{"result": $msg}'
    fi
    return
  fi

  cat "$out_file"
  rm -f "$out_file" "$err_file"
}

# ============================================================================
# evaluate
# ============================================================================
evaluate() {
  local test_id="$1"
  local response_text="$2"
  local criteria="$3"

  local eval_prompt
  eval_prompt=$(cat <<'HEREDOC'
You are a strict test evaluator. Evaluate the following AI response against the given criteria.
Return ONLY a JSON object: {"pass": true/false, "reason": "brief explanation"}
Be strict. If any criterion fails, the whole test fails.
HEREDOC
)

  eval_prompt="${eval_prompt}

RESPONSE TO EVALUATE:
---
${response_text}
---

CRITERIA:
${criteria}"

  local eval_out_file
  eval_out_file=$(mktemp)

  timeout 90 claude -p "$eval_prompt" \
    --model "$EVAL_MODEL" \
    --output-format json \
    --no-session-persistence \
    --system-prompt "You are a strict JSON-only evaluator. Return ONLY valid JSON: {\"pass\": true/false, \"reason\": \"brief explanation\"}. No other text." \
    </dev/null \
    >"$eval_out_file" 2>/dev/null

  local eval_result
  eval_result=$(cat "$eval_out_file")
  rm -f "$eval_out_file"

  local eval_text
  eval_text=$(echo "$eval_result" | jq -r '.result // .' 2>/dev/null || echo "$eval_result")

  local passed reason
  passed=$(echo "$eval_text" | jq -r '.pass // empty' 2>/dev/null || \
           echo "$eval_text" | grep -oP '"pass"\s*:\s*\K(true|false)' | head -1)
  reason=$(echo "$eval_text" | jq -r '.reason // empty' 2>/dev/null || \
           echo "$eval_text" | grep -oP '"reason"\s*:\s*"\K[^"]*' | head -1)

  local passed_bool="false"
  [[ "$passed" == "true" ]] && passed_bool="true"

  jq -n \
    --arg id "$test_id" \
    --argjson passed "$passed_bool" \
    --arg reason "${reason:-Evaluation could not determine result}" \
    '{"id": $id, "passed": $passed, "reason": $reason}'
}

# ============================================================================
# run_test_worker
# ============================================================================
run_test_worker() {
  local id="$1"
  local type="$2"
  local category="$3"
  local block="$4"
  local block_id="$5"
  local prompt_or_prompt1="$6"
  local criteria="$7"
  local requires="$8"
  local prompt2="${9:-}"

  local safe_id="${id//\./_}"
  local log_file="/tmp/claude_md_test_${SCRIPT_PID}_${safe_id}.log"

  # Build system prompt based on requires
  local system_prompt
  system_prompt=$(build_system_prompt "$requires")

  local response_text

  if [[ "$type" == "sequential" ]]; then
    local raw1
    raw1=$(send_prompt "$prompt_or_prompt1" "$system_prompt")
    local resp1
    resp1=$(echo "$raw1" | jq -r '.result // .' 2>/dev/null || echo "$raw1")

    local contextual_prompt="[Context: The user previously asked and received an answer. Now they ask again.]

Previous exchange:
User: $prompt_or_prompt1
Assistant: $resp1

Current message from user:
$prompt2"

    local raw2
    raw2=$(send_prompt "$contextual_prompt" "$system_prompt")
    response_text=$(echo "$raw2" | jq -r '.result // .' 2>/dev/null || echo "$raw2")
    echo "$resp1" > "$RESULTS_DIR/${id}_context.txt"
  else
    local raw
    raw=$(send_prompt "$prompt_or_prompt1" "$system_prompt")
    response_text=$(echo "$raw" | jq -r '.result // .' 2>/dev/null || echo "$raw")
  fi

  echo "$response_text" > "$RESULTS_DIR/${id}_response.txt"

  local eval_json
  eval_json=$(evaluate "$id" "$response_text" "$criteria")

  jq -n \
    --arg id "$id" \
    --argjson block_id "$block_id" \
    --arg block "$block" \
    --arg category "$category" \
    --argjson eval "$eval_json" \
    '{
      "id": $id,
      "block_id": $block_id,
      "block": $block,
      "category": $category,
      "passed": $eval.passed,
      "reason": $eval.reason
    }' > "$log_file"
}

# ============================================================================
# run_all_parallel
# ============================================================================
run_all_parallel() {
  local filter
  filter=$(build_filter)
  local tests
  tests=$(jq -c "[$filter]" "$TESTS_JSON")
  local count
  count=$(echo "$tests" | jq 'length')

  local spinner_frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local spinner_idx=0

  tput civis 2>/dev/null || true

  local batch_pids=()
  local i=0

  while [[ $i -lt $count ]]; do
    local test_data id type category block block_id criteria requires prompt1 prompt2
    test_data=$(echo "$tests" | jq -c ".[$i]")
    id=$(echo "$test_data" | jq -r '.id')
    type=$(echo "$test_data" | jq -r '.type')
    category=$(echo "$test_data" | jq -r '.category')
    block=$(echo "$test_data" | jq -r '.block')
    block_id=$(echo "$test_data" | jq -r '.block_id')
    criteria=$(echo "$test_data" | jq -r '.criteria')
    requires=$(echo "$test_data" | jq -r '.requires')

    if [[ "$type" == "sequential" ]]; then
      prompt1=$(echo "$test_data" | jq -r '.prompt1')
      prompt2=$(echo "$test_data" | jq -r '.prompt2')
      run_test_worker "$id" "$type" "$category" "$block" "$block_id" "$prompt1" "$criteria" "$requires" "$prompt2" &
    else
      prompt1=$(echo "$test_data" | jq -r '.prompt')
      run_test_worker "$id" "$type" "$category" "$block" "$block_id" "$prompt1" "$criteria" "$requires" &
    fi

    local worker_pid=$!
    batch_pids+=("$worker_pid")
    BG_PIDS+=("$worker_pid")

    local safe_id="${id//\./_}"
    TEMP_LOGS+=("/tmp/claude_md_test_${SCRIPT_PID}_${safe_id}.log")

    i=$(( i + 1 ))

    if [[ $PARALLEL_N -gt 0 && ${#batch_pids[@]} -ge $PARALLEL_N ]]; then
      while [[ ${#batch_pids[@]} -gt 0 ]]; do
        local still_running=()
        for pid in "${batch_pids[@]}"; do
          kill -0 "$pid" 2>/dev/null && still_running+=("$pid") || true
        done
        batch_pids=("${still_running[@]+"${still_running[@]}"}")
        [[ ${#batch_pids[@]} -eq 0 ]] && break
        local completed_count
        completed_count=$(( i - ${#batch_pids[@]} ))
        printf "\r  %s  Running tests... %d/%d" "${spinner_frames[$spinner_idx]}" "$completed_count" "$count"
        spinner_idx=$(( (spinner_idx + 1) % ${#spinner_frames[@]} ))
        sleep 0.1
      done
    fi
  done

  while [[ ${#batch_pids[@]} -gt 0 ]]; do
    local still_running=()
    for pid in "${batch_pids[@]}"; do
      kill -0 "$pid" 2>/dev/null && still_running+=("$pid") || true
    done
    batch_pids=("${still_running[@]+"${still_running[@]}"}")
    [[ ${#batch_pids[@]} -eq 0 ]] && break
    local completed_count
    completed_count=$(( count - ${#batch_pids[@]} ))
    printf "\r  %s  Running tests... %d/%d" "${spinner_frames[$spinner_idx]}" "$completed_count" "$count"
    spinner_idx=$(( (spinner_idx + 1) % ${#spinner_frames[@]} ))
    sleep 0.1
  done

  printf "\r  ✓  All tests complete.              \n"
  tput cnorm 2>/dev/null || true
}

# ============================================================================
# print_block_results
# ============================================================================
print_block_results() {
  local pass_count=0
  local fail_count=0
  local current_block=""

  for id in "${TEST_IDS[@]}"; do
    local safe_id="${id//\./_}"
    local log_file="/tmp/claude_md_test_${SCRIPT_PID}_${safe_id}.log"

    if [[ ! -f "$log_file" ]]; then
      continue
    fi
    if ! jq empty "$log_file" 2>/dev/null; then
      echo "  ⏳  $id  (incomplete)"
      continue
    fi

    local block category passed reason
    block=$(jq -r '.block' "$log_file")
    category=$(jq -r '.category' "$log_file")
    passed=$(jq -r '.passed' "$log_file")
    reason=$(jq -r '.reason' "$log_file")

    if [[ "$block" != "$current_block" ]]; then
      echo ""
      echo -e "${CYAN}${BOLD}━━━ $block ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      current_block="$block"
    fi

    if [[ "$passed" == "true" ]]; then
      echo -e "  ${GREEN}✅${NC}  $id  $category"
      pass_count=$(( pass_count + 1 ))
    else
      echo -e "  ${RED}❌${NC}  $id  $category  →  \"$reason\""
      fail_count=$(( fail_count + 1 ))
    fi
  done

  local total=$(( pass_count + fail_count ))
  local pct=0
  [[ $total -gt 0 ]] && pct=$(( pass_count * 100 / total ))

  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  ${GREEN}✅ $pass_count passed${NC}  ${RED}❌ $fail_count failed${NC}  📊 $total total  •  ${pct}%${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  PASS_COUNT=$pass_count
  FAIL_COUNT=$fail_count
}

# ============================================================================
# write_report
# ============================================================================
write_report() {
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local report_file="$RESULTS_DIR/report_${timestamp}.md"
  local failures_file="$RESULTS_DIR/failures_${timestamp}.txt"

  cat > "$report_file" <<EOF
# CLAUDE.md + Rules Test Report — $(date '+%Y-%m-%d %H:%M:%S')

**Test model:** $TEST_MODEL | **Eval model:** $EVAL_MODEL | **User name:** $USER_NAME

| Test | Result | Category | Reason |
|------|--------|----------|--------|
EOF

  for id in "${TEST_IDS[@]}"; do
    local safe_id="${id//\./_}"
    local log_file="/tmp/claude_md_test_${SCRIPT_PID}_${safe_id}.log"

    if [[ ! -f "$log_file" ]]; then
      echo "| $id | SKIPPED | — | log not found |" >> "$report_file"
      continue
    fi
    if ! jq empty "$log_file" 2>/dev/null; then
      echo "| $id | INCOMPLETE | — | partial write |" >> "$report_file"
      continue
    fi

    local category passed reason
    category=$(jq -r '.category' "$log_file")
    passed=$(jq -r '.passed' "$log_file")
    reason=$(jq -r '.reason' "$log_file")

    if [[ "$passed" == "true" ]]; then
      echo "| $id | PASS | $category | $reason |" >> "$report_file"
    else
      echo "| $id | FAIL | $category | $reason |" >> "$report_file"
      if [[ -f "$RESULTS_DIR/${id}_response.txt" ]]; then
        echo "=== Test $id ===" >> "$failures_file"
        cat "$RESULTS_DIR/${id}_response.txt" >> "$failures_file"
        echo "" >> "$failures_file"
      fi
    fi
  done

  local pct=0
  [[ $TOTAL_COUNT -gt 0 ]] && pct=$(( PASS_COUNT * 100 / TOTAL_COUNT ))

  cat >> "$report_file" <<EOF

## Summary

- **Passed:** $PASS_COUNT / $TOTAL_COUNT
- **Failed:** $FAIL_COUNT / $TOTAL_COUNT
- **Pass rate:** ${pct}%

## Files

- Responses: \`$RESULTS_DIR/*.txt\`
- Failures: \`$failures_file\`
EOF

  echo -e "\nReport: ${CYAN}$report_file${NC}"
  if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "Failures: ${CYAN}$failures_file${NC}"
  fi
}

# ============================================================================
# main
# ============================================================================
main() {
  parse_args "$@"
  load_tests
  mkdir -p "$RESULTS_DIR"

  count_tests
  estimate_usage
  print_prerun_summary
  prompt_confirm

  rm -f "${RESULTS_DIR}"/*_response.txt "${RESULTS_DIR}"/*_context.txt

  echo ""

  INTERRUPTED=0
  trap 'INTERRUPTED=1; cleanup; exit 130' SIGINT SIGTERM
  trap 'cleanup' EXIT

  run_all_parallel

  trap - SIGINT SIGTERM EXIT

  print_block_results
  write_report

  if [[ ${#TEMP_LOGS[@]} -gt 0 ]]; then
    for log in "${TEMP_LOGS[@]}"; do
      rm -f "$log"
    done
  fi

  [[ $FAIL_COUNT -eq 0 ]] && exit 0 || exit 1
}

main "$@"
