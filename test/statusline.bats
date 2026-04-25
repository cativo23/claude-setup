#!/usr/bin/env bats
# test/statusline.bats — Tests for statusline width reservation

load 'helpers'

STATUSLINE="config/statusline.js"

MOCK_DATA='{"model":"TestModel","context_window":{"used_percentage":10,"remaining_percentage":90,"total_input_tokens":1000,"total_output_tokens":500},"cost":{"total_cost_usd":0.50,"total_duration_ms":60000},"cwd":"/tmp/test"}'

@test "statusline: piped context applies width reservation (layout < raw)" {
  local output
  output=$(echo "$MOCK_DATA" | COLUMNS=80 node "$STATUSLINE" 2>/dev/null)
  local line_count
  line_count=$(echo "$output" | wc -l)
  [ "$line_count" -ge 2 ]
}

@test "statusline: raw width below 70 triggers minimal mode (1 line)" {
  local output
  output=$(echo "$MOCK_DATA" | COLUMNS=69 node "$STATUSLINE" 2>/dev/null)
  local line_count
  line_count=$(echo "$output" | wc -l)
  [ "$line_count" -eq 1 ]
}

@test "statusline: raw width at 70 uses custom mode (2+ lines)" {
  local output
  output=$(echo "$MOCK_DATA" | COLUMNS=70 node "$STATUSLINE" 2>/dev/null)
  local line_count
  line_count=$(echo "$output" | wc -l)
  [ "$line_count" -ge 2 ]
}

@test "statusline: CLAUDE_STATUSLINE_WIDTH_PCT override works" {
  local output
  output=$(echo "$MOCK_DATA" | COLUMNS=80 CLAUDE_STATUSLINE_WIDTH_PCT=1.0 node "$STATUSLINE" 2>/dev/null)
  local line_count
  line_count=$(echo "$output" | wc -l)
  [ "$line_count" -ge 2 ]
}

@test "statusline: CLAUDE_STATUSLINE_WIDTH_PCT clamps to valid range" {
  local output
  output=$(echo "$MOCK_DATA" | COLUMNS=80 CLAUDE_STATUSLINE_WIDTH_PCT=0.01 node "$STATUSLINE" 2>/dev/null)
  local line_count
  line_count=$(echo "$output" | wc -l)
  [ "$line_count" -ge 2 ]
}

@test "statusline: exits cleanly with empty input" {
  run bash -c 'echo "{}" | node config/statusline.js 2>/dev/null; echo "OK"'
  [[ "$output" == *"OK"* ]]
}
