# Statusline Width Reservation Design

## Problem

When Claude Code executes the statusline script, stdout is piped so `process.stdout.columns` is undefined. The script falls back to `tput cols` or proc tree TTY detection, which return the **full terminal width** (e.g., 80). However, Claude Code reserves right-side space for system UI (notifications, keybind hints like "ctrl-g to edit prompt", thinking status). Lines that fill the full width visually wrap, pushing subsequent lines off the status area.

Claude Code counts `\n` characters to determine status height but does not account for visual line wrapping. A 2-line output that wraps becomes 3+ visual lines, and Claude Code clips to its expected height.

## Prior Art

**claude-powerline** (`Owloops/claude-powerline`) solves this by:
1. Walking the process tree to find the parent TTY via `/proc/{pid}/fd` symlinks
2. Reading the real width with `stty size < /dev/pts/N`
3. Applying `Math.floor(width * 0.7)` — reserving 30% for Claude Code's right-side UI

This 70% factor is documented in their source as: "Returns 70% of terminal width to reserve space for Claude Code's right-side UI messages."

## Solution

Split terminal width into two concepts:
- **Raw width** (`getTermCols()`): actual terminal columns, used for mode selection (custom vs minimal)
- **Layout width** (`getLayoutCols()`): effective usable columns after reserving 30% for Claude Code UI when in piped context

### Two-function approach

```javascript
function getTermCols() {
  // Direct TTY — full width, no reservation needed
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

// Effective width for layout calculations.
// Reserves 30% for Claude Code's right-side UI when piped.
// The 0.7 factor matches claude-powerline's approach and can be
// overridden via CLAUDE_STATUSLINE_WIDTH_PCT env var if Claude Code
// changes its UI layout in the future.
function getLayoutCols() {
  const raw = getTermCols();
  const isPiped = !process.stdout.columns && !process.stderr.columns;
  if (!isPiped) return raw;
  const pct = parseFloat(process.env.CLAUDE_STATUSLINE_WIDTH_PCT) || 0.7;
  return Math.floor(raw * pct);
}
```

### Usage mapping

| Function | Used by | Purpose |
|----------|---------|---------|
| `getTermCols()` | Minimal mode threshold (`cols < 70`) | Mode selection based on real terminal size |
| `getLayoutCols()` | `fitSegments()`, `padLine()`, `buildCustomOutput()` line layout, `buildMinimalOutput()` field-dropping thresholds | Content fitting within usable space |

### What stays the same

- **`fitSegments()`** — already drops right-side segments progressively
- **`truncSteps`** — already truncates branch/dir in 5 steps (full → 24 → 16 → 12 → 8)
- **`displayWidth()`** — already counts emojis as 2 cols, variation selectors as 0
- **`getTermColsFromProcTree()`** — TTY detection logic unchanged
- **Layout structure** — 2-line custom + adaptive line 3

### Width calculation examples

| Terminal | Raw | Layout | Mode | Notes |
|----------|-----|--------|------|-------|
| 160 cols | 160 | 112 | custom | Full layout, all fields |
| 120 cols | 120 | 84 | custom | Full layout, all fields |
| 100 cols | 100 | 70 | custom | Branch truncated, fields may drop |
| 80 cols | 80 | 56 | custom | Branch/dir truncated, some fields drop |
| 70 cols | 70 | 49 | custom | Aggressive truncation, minimal fields |
| 69 cols | 69 | — | minimal | Single compressed line |

### Considered and rejected: single-function approach

Applying the 0.7 factor inside `getTermCols()` directly was rejected because 80 * 0.7 = 56 < 70, which would force minimal mode on half-screen terminals where 2-line custom mode works fine. The two-function split allows raw width for mode selection and reserved width for layout.

## Cross-platform behavior

- **Linux**: `getTermColsFromProcTree()` reads `/proc/{pid}/fd` symlinks. Primary detection method.
- **macOS/WSL**: `/proc` unavailable, falls through to `tput cols`. The 0.7 reservation still applies correctly since the issue (piped stdout) is the same.
- **Direct execution** (not via Claude Code): `process.stdout.columns` is defined, so full width is used with no reservation.

## Code paths that need `getLayoutCols()`

1. **`fitSegments(left, right, sep, cols)`** — caller must pass `getLayoutCols()` as `cols`
2. **`padLine(left, right)`** — internal `getTermCols()` call → change to `getLayoutCols()`
3. **`buildCustomOutput()`** — `const cols = getTermCols()` used for truncSteps → change to `getLayoutCols()`
4. **`buildMinimalOutput()`** — field-dropping thresholds (`cols < 60`, `cols < 80`) → change to `getLayoutCols()`
5. **Minimal mode check** in main — `cols < 70` → keep using `getTermCols()` (raw)

## Files changed

- `config/statusline.js` — add `getLayoutCols()`, update all layout code paths to use it

## Testing

### Manual verification
1. Half-screen Kitty (80 cols): both lines visible, no wrap
2. Full-screen Kitty (160+ cols): full layout with all fields
3. Minimal mode at <70 raw cols
4. Direct terminal execution (not via Claude Code): full width used

### Automated (Bats tests)
1. `getLayoutCols()` returns `Math.floor(raw * 0.7)` when `process.stdout.columns` is falsy
2. `getLayoutCols()` returns raw width when `process.stdout.columns` is truthy
3. Minimal mode threshold uses raw width (not layout width)
4. `CLAUDE_STATUSLINE_WIDTH_PCT` override works
