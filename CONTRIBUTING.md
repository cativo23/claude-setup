# Contributing to claude-setup

Thank you for your interest in contributing! This guide explains how to get started.

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork:
   ```bash
   git clone https://github.com/<your-user>/claude-setup.git
   cd claude-setup
   ```
3. **Create a branch** from `develop`:
   ```bash
   git checkout develop
   git checkout -b feature/my-feature
   ```

## Branching Model

We use Gitflow:

| Branch | Purpose |
|--------|---------|
| `main` | Stable releases only |
| `develop` | Integration branch for next release |
| `feature/*` | New features (branch from `develop`) |
| `fix/*` | Bug fixes (branch from `develop`) |
| `release/vX.Y.Z` | Release preparation (maintainers only) |
| `hotfix/*` | Urgent fixes for `main` (maintainers only) |

**All PRs target `develop`**, not `main`.

## Commit Format

```
<gitmoji> <type>(<scope>): <description>
```

### Gitmoji

Use real emoji from [gitmoji.dev](https://gitmoji.dev). Common ones:

| Emoji | Code | When to use |
|-------|------|-------------|
| ✨ | `:sparkles:` | New feature |
| 🐛 | `:bug:` | Bug fix |
| 📝 | `:memo:` | Documentation |
| ♻️ | `:recycle:` | Refactor |
| 🔧 | `:wrench:` | Configuration |
| ⬆️ | `:arrow_up:` | Upgrade dependency |
| 🎉 | `:tada:` | Initial commit |
| 🔒 | `:lock:` | Security fix |
| 🚀 | `:rocket:` | Deploy/release |
| 📦 | `:package:` | Add or update files |
| 📄 | `:page_facing_up:` | Add or update license |
| ✅ | `:white_check_mark:` | Add or update tests |
| 📦 | `:package:` | Add or update compiled assets |
| 🔥 | `:fire:` | Remove code or files |
| 🚑 | `:ambulance:` | Critical hotfix |
| ⚡ | `:zap:` | Improve performance |
| 🎨 | `:art:` | Improve structure/format |
| 🌐 | `:globe_with_meridians:` | Internationalization |
| ✏️ | `:pencil2:` | Fix typos |
| 🏷️ | `:label:` | Add or update types |

### Additional Gitmoji for Releases

| Emoji | Code | When to use |
|-------|------|-------------|
| 🔖 | `:bookmark:` | Release tag |
| 📌 | `:pushpin:` | Pin dependencies |
| ⏪ | `:rewind:` | Revert changes |

### Types

`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`, `style`, `revert`

### Scopes (optional)

`installer`, `plugins`, `mcp`, `skills`, `commands`, `frameworks`, `config`, `claude-md`, `rules`, `statusline`, `output-styles`

### Examples

```
✨ feat(plugins): add new-plugin support
🐛 fix(mcp): handle empty secret gracefully
📝 docs: update quickstart for Tavily setup
♻️ refactor(installer): extract banner to utils
📦 add(commands): add deploy command
🔥 remove(skills): remove deprecated skill
✅ test(core): add validation tests
🚑 fix(security): fix secret validation bypass
⚡ perf(utils): optimize multi_select rendering
🎨 style(banner): improve installer banner alignment
✏️ fix(docs): fix typo in README
🏷️ refactor(types): add strict types to utils
🔖 release: v1.0.0
⏪ revert: revert "feat: add experimental feature"
```

## Creating New Modules

### Required Structure

Every module in `scripts/` must follow this structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source utilities
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Install function (required)
install_<module>() {
    print_info "Installing <module>..."
    # Installation logic here
    INSTALLED_ITEMS+=("<item>")
}

# Standalone/module guard
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_<module>
fi
```

### Required Functions

- `install_*()` - Main installation function (one per installable item)
- Use `print_info()`, `print_success()`, `print_error()` from `utils.sh` for output
- Use color functions from `utils.sh` - never hardcode colors

### Tracking Arrays

Update global tracking arrays for the final summary:

- `INSTALLED_ITEMS+=("<item>")` - Successfully installed items
- `SKIPPED_SECTIONS+=("<section>")` - Skipped by user
- `FAILED_ITEMS+=("<item>")` - Items that failed installation

### Standalone/Module Mode Guard

Every script must include this guard at the end:

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_<module>
fi
```

This allows the script to work both:
- **Standalone**: `bash scripts/<module>.sh`
- **Sourced**: Called from `install.sh`

### Example Module

See `scripts/plugins.sh` for a complete example of a well-structured module.

## Code Review Checklist

Before submitting a PR, ensure:

### Code Quality
- [ ] Syntax check passed: `bash -n install.sh && bash -n scripts/*.sh`
- [ ] Follows Bash conventions (`set -euo pipefail`, `local` keyword, UPPER_CASE globals)
- [ ] Uses functions from `utils.sh` for output (colors, spinner, banner)
- [ ] No hardcoded colors - uses color variables from `utils.sh`
- [ ] Script works in both standalone and sourced modes

### Testing
- [ ] Tests added/updated for new functionality
- [ ] All existing tests pass: `bats test/`
- [ ] Edge cases covered (empty input, validation failures, network errors)

### Security
- [ ] No secrets exposed in logs or output
- [ ] Secrets validated before use (format validation)
- [ ] User input sanitized (no `eval`, no string interpolation in commands)
- [ ] File permissions set correctly (600 for secrets)

### Documentation
- [ ] README.md updated if prerequisites or plugins changed
- [ ] Quickstart docs updated for new installable categories
- [ ] Commit messages follow format with gitmoji
- [ ] CHANGELOG.md updated (for maintainers)

### Gitflow
- [ ] Branch created from `develop`
- [ ] Branch name follows convention: `feature/<description>` or `fix/<description>`
- [ ] PR targets `develop`, not `main`

```bash
# Syntax check all scripts
bash -n install.sh && bash -n scripts/*.sh
```

### Running Bats Test Suite

```bash
# Run all tests
bats test/

# Run specific test file
bats test/plugins.bats

# Run with verbose output
bats --verbose-run test/
```

### Running Jarvis Test Suite

The Jarvis output style has its own integration test suite in `test/jarvis/`.
Test definitions live in `tests.json` (source of truth).

```bash
# Full run (16 tests, parallel)
bash test/jarvis/test-jarvis.sh

# Single test
bash test/jarvis/test-jarvis.sh --test-id 1.1 --yes

# Filter by block
bash test/jarvis/test-jarvis.sh --block 2

# CI mode (no prompt)
bash test/jarvis/test-jarvis.sh --yes
```

### Running CLAUDE.md + Rules Test Suite

The CLAUDE.md and rules have their own integration test suite in `test/claude-md/`.
Test definitions live in `tests.json` (source of truth).

```bash
# Full run (13 tests, parallel)
bash test/claude-md/test-claude-md.sh

# Single test
bash test/claude-md/test-claude-md.sh --test-id 1.1 --yes

# Filter by block
bash test/claude-md/test-claude-md.sh --block 3

# CI mode (no prompt)
bash test/claude-md/test-claude-md.sh --yes
```

### Adding New Tests

1. Create test file in `test/` directory with `.bats` extension
2. Name it after the script being tested (e.g., `plugins.bats` for `scripts/plugins.sh`)
3. Use `@test` blocks for individual test cases
4. Test both standalone mode and sourced mode
5. Mock external dependencies (API calls, file system)

Example test structure:
```bash
#!/usr/bin/env bats

setup() {
    source scripts/utils.sh
}

@test "should do something" {
    run some_function
    [ "$status" -eq 0 ]
    [ "$output" = "expected" ]
}
```

## Validation

Before submitting a PR, run:

```bash
# Syntax check all scripts
bash -n install.sh && bash -n scripts/*.sh

# Test standalone mode
bash scripts/plugins.sh

# Test full installer
bash install.sh
```

## Pull Request Process

1. Branch from `develop`
2. Make your changes following the conventions above
3. Validate with syntax checks
4. Open a PR targeting `develop`
5. Fill out the PR template
6. Wait for review

## Releases

Releases are managed by maintainers only:

1. Create `release/vX.Y.Z` branch from `develop`
2. Update `CHANGELOG.md` with the new version
3. Open PR targeting `main`
4. Merge triggers the auto-release GitHub Actions workflow

## Guidelines

- Keep scripts under 150 lines; extract reusable logic to `utils.sh`
- Every new script needs the `BASH_SOURCE` guard for standalone/module compatibility
- Test both modes: standalone (`bash scripts/new.sh`) and sourced (via `install.sh`)
- Add quickstart docs in `quickstart/` for any new installable category
- Do not add dependencies beyond Bash, Claude CLI, and Node.js
- Never log, echo, or expose secrets in output
