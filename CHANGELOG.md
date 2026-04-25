# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


## [1.5.1] - 2026-04-21

### Fixed
- **plugins.sh**: Corregir marketplace sources rotos (`superpowers-marketplace` → `obra/superpowers-marketplace`, `@jeffallan` → `@fullstack-dev-skills`)
- **plugins.sh**: Exponer errores silenciados por `2>/dev/null` — stderr ahora se captura y muestra en fallos reales
- **plugins.sh**: Manejo de idempotencia en registro de marketplaces (rama defensiva para re-ejecuciones)
- **plugins.sh**: Cascade-skip de plugins cuyo marketplace falló el registro, evitando errores confusos en cadena
- **plugins.sh**: `declare -A` → `local -A =()` para evitar leak de scope en re-ejecuciones de `install_plugins`
- **plugins.sh**: `plugin_field` reescrito con `read -r -a` para eliminar riesgo de glob expansion

## [1.5.0] - 2026-04-08

### Added
- **statusline.js**: Rate limits display (5h/7d) with color thresholds and reset countdown
- **statusline.js**: Cost burn rate ($/h) alongside session cost
- **statusline.js**: Session name display (`--name` / `/rename`)
- **statusline.js**: Vim mode indicator (`[N]`/`[I]`) in L2
- **statusline.js**: Active task display in L1 (from TaskCreate/TaskUpdate)
- **statusline.js**: Dedicated L4 line for GSD info (conditional)
- **statusline.js**: Tool activity tracking, agent tracking, and todo progress (L3)
- **statusline.js**: TaskCreate and TaskUpdate support in transcript parser
- **statusline.js**: Bats tests for width reservation logic

### Changed
- **statusline.js**: Replace all emojis with Nerd Font glyphs (fa-robot, fa-fire, fa-skull, fa-comment, fa-clock, fa-bolt, fa-hammer, fa-tree, fa-cubes, dev-git-branch, fa-folder-open)
- **statusline.js**: Simplified buffer warnings (skull icon at ≥80% only, no verbose text)
- **statusline.js**: Split getTermCols into raw + layout width functions for piped contexts
- **statusline.js**: Responsive layout with process tree width detection and tput fallback

### Fixed
- **statusline.js**: `remaining` undefined in buildMinimalOutput (crash in minimal mode)
- **statusline.js**: Context bar uses buffer-adjusted percentage
- **statusline.js**: Minimal mode threshold uses raw width at 70 cols
- **statusline.js**: buildMinimalOutput/buildCustomOutput use layout cols for field dropping
- **statusline.js**: Dynamic field truncation for narrow terminals
- **statusline.js**: Security and robustness fixes (path traversal protection, atomic cache writes)

### Removed
- **statusline.js**: Dead code (computeUsedPct, unused agentsLine in minimal mode)


## [1.4.1] - 2026-03-16

### Added
- SECURITY.md with comprehensive security documentation
- Security section in README.md


## [1.4.0] - 2026-03-16

### Added
- **doctor.sh**: New diagnostic command for installation status (`bash scripts/doctor.sh`)
- **update.sh**: Automatic update script with hash comparison (`bash scripts/update.sh`)
- **quickupdate.sh**: One-liner for end users (`curl -fsSL ... | bash`)
- **settings.template.json**: Default settings template for auto-configuration
- **utils.sh**: `needs_update()` - version/hash comparison for file updates
- **utils.sh**: `merge_settings()` - settings.json management preserving user config
- **utils.sh**: `compare_versions()` - semver comparison (major.minor.patch)
- **utils.sh**: `git_remote_status()` - detect commits behind/ahead of origin
- **utils.sh**: `git_is_clean()` - check working directory status
- **utils.sh**: `get_claude_dir()` - resolve CLAUDE_CONFIG_DIR
- **install.sh**: Auto-manage settings.json from template
- **install.sh**: Statusline auto-detection and update prompt
- **Tests**: 30 new Bats tests (doctor.bats, update.bats, settings-merge.bats)

### Changed
- **statusline.js**: Added version comment (v1.4.0) for update detection
- **install.sh**: `setup_settings()` now runs before statusline installation

## [1.3.0] - 2026-03-15

### Added
- **Statusline**: Smart hybrid layout — 2-line base with adaptive 3rd line for contextual info
- **Statusline**: Right-aligned fields using full terminal width (output style, version, lines changed)
- **Statusline**: New fields: `output_style.name`, `version`, `cost.total_lines_added/removed`, `agent.name`, `worktree.name`
- **Statusline**: Git caching with 5-second TTL per directory (MD5 hash keyed)
- **Statusline**: Terminal width degradation — custom→minimal at <80 cols, ultra-narrow at <40 cols
- **Statusline**: Block bar (`█░`) for both custom and minimal modes

### Changed
- **Statusline**: Buffer zone simplified — no more `▒▒▒▒ [buf:17%]`, warning only when remaining ≤20%
- **Statusline**: Minimal mode now shows all new fields (style, version, lines, agent, worktree)

### Fixed
- **Statusline**: Terminal width detection when stdout is piped (falls back to stderr/COLUMNS)
- **Statusline**: Git modified count no longer double-counts staged files
- **Statusline**: Git cache file secured with 0o600 permissions

## [1.2.4] - 2026-03-15

### Fixed
- **Docs**: README missing "What Gets Installed" sections for CLAUDE.md+Rules, Output Styles, and Statusline
- **Docs**: README project structure tree missing test files (*.bats, helpers.bash, run-tests.sh, README.md) and .github/
- **Docs**: AGENTS.md missing standalone commands for `output-styles.sh` and `claude-md.sh`
- **Docs**: AGENTS.md project structure missing Bats test file references
- **Docs**: AGENTS.md testing section missing Bats test suite entry
- **Docs**: test/README.md missing CLAUDE.md + Rules test suite section

## [1.2.3] - 2026-03-15

### Fixed
- **Docs**: README project structure updated with v1.2.x components (claude-md, rules, test suites)
- **Docs**: README quickstart table missing `claude-md.md` guide
- **Docs**: AGENTS.md incorrect plugin count (6 → 5)
- **Docs**: CONTRIBUTING.md missing commit scopes (claude-md, rules, statusline, output-styles)
- **Docs**: CONTRIBUTING.md missing CLAUDE.md + Rules test suite instructions
- **Docs**: quickstart/plugins.md removed undocumented trail-of-bits plugin

## [1.2.2] - 2026-03-15

### Fixed
- **Security**: Node.js injection in statusline settings — use `process.argv` instead of string interpolation
- **Security**: Bridge file written with `0o600` permissions instead of world-readable default
- **Portability**: `stat -c` replaced with macOS-compatible fallback (`stat -f`)
- **Portability**: `grep -P` (PCRE) replaced with portable `sed` for name detection
- **Portability**: Test suite shebang `#!/bin/bash` → `#!/usr/bin/env bash`
- **Robustness**: `TMPDIR` variable collision in `quickinstall.sh` — renamed to `CLONE_DIR`
- **Robustness**: `read` without `/dev/tty` in `prompt_secret` — 3 reads fixed for piped execution
- **Robustness**: `nvm use --lts` failure no longer crashes before `utils.sh` is sourced
- **Robustness**: `ROLLBACK_STACK` guard uses `declare -p` instead of invalid `${#array[@]:-0}`
- **Robustness**: JSON injection in test error output — replaced with `jq -n --arg`

### Added
- **Rollback**: `OUTPUT_STYLE` handler in `execute_rollback` (was silently skipped)
- **UX**: TTY check + `NO_COLOR` support for ANSI color output
- **UX**: Cursor restore (`tput cnorm`) in `cleanup_on_exit`

## [1.2.1] - 2026-03-14

### Added
- **Statusline**: Token usage display (input/output) in both custom and minimal modes
  - Custom: `💬 45k↑ 12k↓` on line 1
  - Minimal: `45k^ 12kv` compact ASCII

## [1.2.0] - 2026-03-14

### Added
- Global CLAUDE.md installer — asks for user name (obligatory), offers optional modules (git-defaults)
- Rules installer — 5 optional methodology rules copied to `~/.claude/rules/`
  - IPA Methodology (Investigate→Plan→Act)
  - Security-First
  - TDD-First
  - Code Review Mindset
  - Minimalist
- `multi_select` now supports `--none:` prefix for default-unselected mode
- CLAUDE.md + Rules test suite (13 tests, 7 blocks, parallel execution)
- `quickstart/claude-md.md` — quick reference documentation

### Changed
- Installer order: Name → CLAUDE.md → Rules now run before Plugins
- Jarvis output style trimmed ~50% — methodology extracted to IPA rule, personality stays
- Jarvis test suite updated: tests 2.1 and 3.3 now test personality only

### Removed
- Methodology sections from Jarvis output style (moved to `config/rules/ipa-methodology.md`)

## [1.1.0] - 2026-03-14

### Added
- **Config**: Unified statusline (`config/statusline.js`) with 4 modes via CLI flags:
  - Default: 3-line custom with emojis, context bar, git info, cost, duration, effort
  - `--minimal`: 1-line colored ASCII compact bar
  - `--gsd`: 3-line custom + GSD update check + current task
  - `--gsd --minimal`: 1-line colored ASCII + GSD info
- **Config**: Jarvis output style (`config/output-styles/jarvis.md`) with Rioplatense voseo, fillers, and tone matching
- **Installer**: `install_statusline_variant()` — interactive prompt for custom vs minimal with auto GSD detection
- **Installer**: Output styles module (`scripts/output-styles.sh`)
- **Tests**: Jarvis output style test suite (`test/jarvis/`) — 16 JSON-driven tests with parallel execution, pre-run cost estimates, block filtering, and CI mode

### Changed
- **Installer**: Statusline selection now runs after frameworks install (to detect GSD)
- **Frameworks**: Simplified GSD install — removed `apply_gsd_custom_statusline()`, uses env var signal only

### Removed
- **Config**: `statusline-custom.js` and `gsd-statusline-custom.js` (replaced by unified `statusline.js`)

## [1.0.1] - 2026-03-12

### Fixed
- **MCP**: Tavily API key validation now accepts keys with hyphens and underscores (e.g. `tvly-dev-*`)
- **Plugins**: Corrected marketplace sources for all plugins (`anthropics/claude-plugins-official`, `jeffallan/claude-skills`)
- **Plugins**: `claude-mem` now installs without `@marketplace` suffix per upstream docs
- **Plugins**: Separated `marketplace_add` and `install_arg` fields to handle differing install references

### Added
- **Docs**: AGENTS.md as single source of truth for agent configuration

## [1.0.0] - 2026-03-10

### Added
- **Core**: Transactional installation with rollback mechanism
- **Core**: Error recovery prompts on failure or interruption
- **Docs**: Complete README with all prerequisites
- **Docs**: Comprehensive CONTRIBUTING guide
- **Docs**: PR template for contributors

### Changed
- First stable release with all core features

## [0.3.0] - 2026-03-10

### Added

- **Core**: Transactional installation pattern with rollback mechanism for all modules
- **Core**: Error recovery prompts on failure or interruption (SIGINT/SIGTERM)
- **Core**: Secure state tracking of installed components

## [0.2.7] - 2026-03-10

### Fixed

- **Installer**: Add Bash version check at startup to prevent cryptic errors on older systems
- **Installer**: Display clear upgrade instructions if Bash < 5.0 detected

## [0.2.6] - 2026-03-09

### Fixed

- **Security**: Add `check_secrets_permissions()` to verify and fix 600 permissions on existing secrets files
- **Security**: Display warning when auto-correcting insecure permissions
- **Docs**: Document expected 600 permissions in README

## [0.2.5] - 2026-03-09

### Added

- **Security**: Add `validate_github_token()` supporting `ghp_`, `github_pat_`, `gho_`, `ghu_`, `ghs_` prefixes
- **Security**: Add `validate_tavily_key()` requiring `tvly-` prefix + min 15 alphanumeric chars
- **Security**: Format validation in `prompt_secret()` with retry logic (max 2 attempts)
- **Security**: Clear error messages with regeneration URLs on validation failure
- **Tests**: 14 new validation tests (TDD approach)

### Changed

- **Docs**: Center ASCII art header in README using `<pre>` tag

## [0.2.4] - 2026-03-09

### Added

- **CI**: GitHub Actions workflow for automated testing on push/PR to main/develop
- **Tests**: Bats test suite with 32 tests across all installer modules
- **Docs**: Testing documentation and CI badge

## [0.2.3] - 2026-03-08

### Changed

- **Style**: Updated project banner in README and installer to use figlet `slant` font, centered alignment.

## [0.2.2] - 2026-03-08

### Fixed

- **Interactive installer**: Fixed interactive prompt failure when executing the one-line installer via `curl ... | bash` by explicitly reading from `/dev/tty`

## [0.2.0] - 2026-03-07

### Changed

- **README**: Full redesign — centered ASCII header, flat-square badges (including Bash badge), table of contents, installer UI preview, collapsible project structure and keyboard controls, prerequisites as table with install links, cleaner visual hierarchy with horizontal rules

## [0.1.0] - 2026-03-07

### Added

- **Interactive installer** (`install.sh`): Single-command orchestrator with ASCII banner, colored output, dependency checks, and final summary
- **Multi-select menus** (`scripts/utils.sh`): Arrow keys + space to toggle, select/deselect all, Bash nameref return values
- **5 plugins** via `claude plugin install`:
  - `superpowers` — Development framework: brainstorm, plan, execute, TDD, debugging
  - `security-guidance` — Automatic security hook on every Edit/Write
  - `fullstack-dev-skills` — 66 specialized skills by language/framework
  - `feature-dev` — Guided feature development in 7 phases
  - `claude-mem` — Persistent memory between sessions
- **2 MCP servers** (`scripts/mcp-servers.sh`): GitHub and Tavily with secure secret prompting
- **GSD framework** (`scripts/frameworks.sh`): Meta-prompting with fresh contexts per task via npx
- **Custom skills installer** (`scripts/skills.sh`): Copies `./skills/*.md` to `~/.claude/skills/`
- **Custom commands installer** (`scripts/commands.sh`): Copies `./commands/*.md` to `~/.claude/commands/`
- **Shared utilities** (`scripts/utils.sh`): Colors, spinner, banner, tracking arrays, dependency checker
- **Quickstart documentation**: Usage guides for plugins, MCP servers, skills/commands, and GSD
- **Config examples**: `settings.example.json` and `CLAUDE.example.md` templates
- **Secure secrets handling**: Hidden input with `read -rsp`, stored in `~/.env.secrets` with `chmod 600`
- **Dual-mode scripts**: Every script works standalone (`bash scripts/X.sh`) and as a sourced module

[1.2.4]: https://github.com/cativo23/claude-setup/releases/tag/v1.2.4
[1.2.3]: https://github.com/cativo23/claude-setup/releases/tag/v1.2.3
[1.2.2]: https://github.com/cativo23/claude-setup/releases/tag/v1.2.2
[1.2.1]: https://github.com/cativo23/claude-setup/releases/tag/v1.2.1
[1.2.0]: https://github.com/cativo23/claude-setup/releases/tag/v1.2.0
[1.1.0]: https://github.com/cativo23/claude-setup/releases/tag/v1.1.0
[1.0.1]: https://github.com/cativo23/claude-setup/releases/tag/v1.0.1
[1.0.0]: https://github.com/cativo23/claude-setup/releases/tag/v1.0.0
[0.3.0]: https://github.com/cativo23/claude-setup/releases/tag/v0.3.0
[0.2.7]: https://github.com/cativo23/claude-setup/releases/tag/v0.2.7
[0.2.6]: https://github.com/cativo23/claude-setup/releases/tag/v0.2.6
[0.2.5]: https://github.com/cativo23/claude-setup/releases/tag/v0.2.5
[0.2.4]: https://github.com/cativo23/claude-setup/releases/tag/v0.2.4
[0.2.3]: https://github.com/cativo23/claude-setup/releases/tag/v0.2.3
[0.2.2]: https://github.com/cativo23/claude-setup/releases/tag/v0.2.2
[0.2.0]: https://github.com/cativo23/claude-setup/releases/tag/v0.2.0
[0.1.0]: https://github.com/cativo23/claude-setup/releases/tag/v0.1.0

