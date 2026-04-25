# Running Tests

## Installation Options

### Option 1: Use bundled Bats (recommended for CI, no install needed)

The Bats framework is included as a git submodule. Clone with:

```bash
git clone --recurse-submodules https://github.com/cativo23/claude-setup.git
```

If you already cloned, initialize submodules:

```bash
git submodule update --init --recursive
```

Run tests:
```bash
./test/run-tests.sh
# or directly
./test/libs/bats/bin/bats test/*.bats
```

### Option 2: Install Bats globally via npm (optional, for local dev)

For convenience during local development:

```bash
npm install -g bats
```

Then run tests directly:
```bash
bats test/*.bats
```

**Note:** This is optional. All tests work with the bundled version.

## Updating Bats Version

```bash
# Update to latest submodule version
git submodule update --remote test/libs/bats

# Review changes, then commit
git add test/libs/bats
git commit -m "chore: update bats submodule to latest version"
```

## Writing New Tests

See existing tests in `test/` for examples. Key patterns:
- Use `load "$BATS_TEST_DIRNAME/helpers"` for common utilities
- Mock `multi_select` for testing install_* functions
- Use `setup()` to initialize tracking arrays

## Jarvis Output Style Tests

Integration tests for the Jarvis output style live in `test/jarvis/`.

- `tests.json` — 16 test definitions (source of truth)
- `test-jarvis.sh` — parallel test runner with pre-run cost estimates
- `results/` — generated reports and failures (gitignored)

```bash
# Full suite (parallel, ~34 API calls)
bash test/jarvis/test-jarvis.sh

# Single test
bash test/jarvis/test-jarvis.sh --test-id 1.1 --yes

# Filter by block (1-5)
bash test/jarvis/test-jarvis.sh --block 2

# Options: --eval-model, --test-model, --parallel N, --yes
```

## CLAUDE.md + Rules Tests

Integration tests for the CLAUDE.md installer and rules live in `test/claude-md/`.

- `tests.json` — 13 test definitions (source of truth)
- `test-claude-md.sh` — parallel test runner
- `results/` — generated reports and failures (gitignored)

```bash
# Full suite (parallel)
bash test/claude-md/test-claude-md.sh

# Single test
bash test/claude-md/test-claude-md.sh --test-id 1.1 --yes

# Filter by block (1-7)
bash test/claude-md/test-claude-md.sh --block 3

# CI mode (no prompt)
bash test/claude-md/test-claude-md.sh --yes
```
