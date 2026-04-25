# Statusline Width Reservation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix statusline line wrapping in Claude Code by reserving 30% of terminal width for Claude Code's right-side UI when running in piped context.

**Architecture:** Split `getTermCols()` into two functions — `getTermCols()` returns raw terminal width for mode selection, `getLayoutCols()` returns effective width (70% of raw when piped) for layout. All layout code paths (`fitSegments`, `padLine`, `buildCustomOutput`, `buildMinimalOutput`) use `getLayoutCols()`. Minimal mode threshold stays on raw width.

**Tech Stack:** Node.js (vanilla), Bats (testing)

**Spec:** `docs/superpowers/specs/2026-03-19-statusline-width-reservation-design.md`

---

## Chunk 1: Core implementation

### Task 1: Add `getLayoutCols()` and refactor `getTermCols()`

**Files:**
- Modify: `config/statusline.js:94-103` (refactor `getTermCols`, add `getLayoutCols`)

- [ ] **Step 1: Refactor `getTermCols()` to separate direct TTY from fallbacks**

Replace lines 94-103 in `config/statusline.js`:

```javascript
function getTermCols() {
  // Direct TTY — full width
  let cols = process.stdout.columns || process.stderr.columns;
  if (cols) return cols;

  // Piped context — detect from env, proc tree, or tput
  cols = parseInt(process.env.COLUMNS, 10);
  if (cols > 0) return cols;

  cols = getTermColsFromProcTree();
  if (!cols) {
    try {
      cols = parseInt(execFileSync('tput', ['cols'],
        { stdio: ['inherit', 'pipe', 'pipe'], timeout: 500 }
      ).toString().trim(), 10);
    } catch {}
  }

  return cols || 120;
}
```

- [ ] **Step 2: Add `getLayoutCols()` right after `getTermCols()`**

Insert after `getTermCols()`:

```javascript
function getLayoutCols() {
  const raw = getTermCols();
  const isPiped = !process.stdout.columns && !process.stderr.columns;
  if (!isPiped) return raw;
  const pct = parseFloat(process.env.CLAUDE_STATUSLINE_WIDTH_PCT) || 0.7;
  return Math.floor(raw * Math.min(Math.max(pct, 0.3), 1.0));
}
```

- [ ] **Step 3: Verify script still parses without errors**

Run: `echo '{}' | node config/statusline.js 2>/dev/null; echo "exit: $?"`
Expected: `exit: 0`

- [ ] **Step 4: Commit**

```bash
git add config/statusline.js
git commit -m "refactor(statusline): split getTermCols into raw + layout width functions"
```

### Task 2: Update `padLine()` to use `getLayoutCols()`

**Files:**
- Modify: `config/statusline.js:105-111` (`padLine` function)

- [ ] **Step 1: Change `padLine` to use `getLayoutCols()`**

Replace `getTermCols()` call in `padLine`:

```javascript
function padLine(left, right) {
  const cols = getLayoutCols();
  const leftW = displayWidth(left);
  const rightW = displayWidth(right);
  const gap = Math.max(1, cols - leftW - rightW);
  return left + ' '.repeat(gap) + right;
}
```

- [ ] **Step 2: Commit**

```bash
git add config/statusline.js
git commit -m "fix(statusline): padLine uses layout cols for width reservation"
```

### Task 3: Update `buildCustomOutput()` to use `getLayoutCols()`

**Files:**
- Modify: `config/statusline.js:322` (`const cols = getTermCols()` in buildCustomOutput)

- [ ] **Step 1: Change `getTermCols()` to `getLayoutCols()` in buildCustomOutput**

At line 322, change:
```javascript
  const cols = getTermCols();
```
to:
```javascript
  const cols = getLayoutCols();
```

This affects the `truncSteps` loop and `fitSegments` calls which all use this `cols` variable.

- [ ] **Step 2: Commit**

```bash
git add config/statusline.js
git commit -m "fix(statusline): buildCustomOutput uses layout cols for width reservation"
```

### Task 4: Update `buildMinimalOutput()` to use `getLayoutCols()`

**Files:**
- Modify: `config/statusline.js:468` (`const cols = getTermCols()` in buildMinimalOutput)

- [ ] **Step 1: Change `getTermCols()` to `getLayoutCols()` in buildMinimalOutput**

At line 468, change:
```javascript
  const cols = getTermCols();
```
to:
```javascript
  const cols = getLayoutCols();
```

This affects the field-dropping thresholds (`cols < 60`, `cols < 80`) inside buildMinimalOutput.

- [ ] **Step 2: Commit**

```bash
git add config/statusline.js
git commit -m "fix(statusline): buildMinimalOutput uses layout cols for field dropping"
```

### Task 5: Update minimal mode threshold to use raw width at 70 cols

**Files:**
- Modify: `config/statusline.js:564` (main entry point threshold check)

- [ ] **Step 1: Change threshold from 80 to 70 and ensure it uses raw `getTermCols()`**

At line 564, change:
```javascript
    const useMinimal = minimal || cols < 80;
```

Verify that line 563 already reads `const cols = getTermCols();` (raw width). Then change the threshold:
```javascript
    const useMinimal = minimal || cols < 70;
```

- [ ] **Step 2: Commit**

```bash
git add config/statusline.js
git commit -m "fix(statusline): minimal mode threshold uses raw width at 70 cols"
```

### Task 6: Update comment at top of file

**Files:**
- Modify: `config/statusline.js:4`

- [ ] **Step 1: Update the header comment**

Change line 4 from:
```javascript
// Auto-degrades to minimal when terminal < 80 columns
```
to:
```javascript
// Auto-degrades to minimal when terminal < 70 columns
// Reserves 30% width for Claude Code UI when running piped (configurable via CLAUDE_STATUSLINE_WIDTH_PCT)
```

- [ ] **Step 2: Commit**

```bash
git add config/statusline.js
git commit -m "docs(statusline): update header comment for width reservation"
```

## Chunk 2: Testing and deployment

### Task 7: Add Bats tests for width functions

**Files:**
- Create: `test/statusline.bats`

- [ ] **Step 1: Create the test file**

```bash
#!/usr/bin/env bats
# test/statusline.bats — Tests for statusline width reservation

load 'helpers'

STATUSLINE="config/statusline.js"

MOCK_DATA='{"model":"TestModel","context_window":{"used_percentage":10,"remaining_percentage":90,"total_input_tokens":1000,"total_output_tokens":500},"cost":{"total_cost_usd":0.50,"total_duration_ms":60000},"cwd":"/tmp/test"}'

@test "statusline: piped context applies width reservation (layout < raw)" {
  # When piped (stdout.columns undefined), layout should be ~70% of detected width
  # We can verify this indirectly: with COLUMNS=80, layout=56, which is < 70 threshold for custom,
  # but the threshold uses raw width (80 >= 70), so we should get 2+ lines (custom mode)
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
  # With 100% width (no reservation), lines might be wider but still 2+ lines
  local output
  output=$(echo "$MOCK_DATA" | COLUMNS=80 CLAUDE_STATUSLINE_WIDTH_PCT=1.0 node "$STATUSLINE" 2>/dev/null)
  local line_count
  line_count=$(echo "$output" | wc -l)
  [ "$line_count" -ge 2 ]
}

@test "statusline: CLAUDE_STATUSLINE_WIDTH_PCT clamps to valid range" {
  # Value below 0.3 should be clamped to 0.3 (not produce absurdly narrow layout)
  # At COLUMNS=80, clamped 0.3 = 24 cols layout. Still < 70 raw, so custom mode.
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
```

- [ ] **Step 2: Run tests**

Run: `bats test/statusline.bats`
Expected: All 5 tests pass

- [ ] **Step 3: Commit**

```bash
git add test/statusline.bats
git commit -m "test(statusline): add Bats tests for width reservation"
```

### Task 8: Manual verification and deployment

**Files:**
- Copy: `config/statusline.js` → `~/.claude/hooks/statusline.js`

- [ ] **Step 1: Install to local hooks**

```bash
cp config/statusline.js ~/.claude/hooks/statusline.js
```

- [ ] **Step 2: Verify in half-screen Kitty (80 cols)**

Check that both statusline lines are visible with no wrapping.

- [ ] **Step 3: Verify in full-screen Kitty (160+ cols)**

Check that full layout renders with all fields.

- [ ] **Step 4: Verify minimal mode**

Shrink terminal to <70 cols, confirm single-line minimal mode.

- [ ] **Step 5: Push and update PR**

```bash
git push
```
