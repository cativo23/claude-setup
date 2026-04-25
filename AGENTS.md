# AGENTS.md – claude-setup

## Agent Role

Installation assistant for Claude Code. Specialist in Bash scripting, CLI tools, and MCP servers.

## Project Overview

**Mission:** Provide modular, secure Claude Code setup with plugins, MCP servers, skills, and commands.

**Philosophy:** Every module is independent, verifiable, and non-destructive. User always has control.

## Tech Stack

- Bash 5+ (installer scripts)
- Claude CLI (plugins, MCP servers)
- Node.js 18+/npx (frameworks like GSD)

## Key Commands

```bash
# Validate syntax
bash -n install.sh && bash -n scripts/*.sh

# Run full installer
bash install.sh

# Run individual modules (standalone)
bash scripts/plugins.sh
bash scripts/mcp-servers.sh
bash scripts/skills.sh
bash scripts/commands.sh
bash scripts/frameworks.sh
bash scripts/output-styles.sh
bash scripts/claude-md.sh

# Verify installation
claude mcp list
claude plugin list
```

## Project Structure

- `install.sh` - Main orchestrator, sources all modules
- `scripts/utils.sh` - Shared functions: colors, `multi_select()`, spinner, banner, summary
- `scripts/plugins.sh` - Install 5 plugins via `claude plugin install`
- `scripts/mcp-servers.sh` - Configure MCP servers with interactive secrets
- `scripts/skills.sh` - Copy skills from `./skills/` to `~/.claude/skills/`
- `scripts/commands.sh` - Copy commands from `./commands/` to `~/.claude/commands/`
- `scripts/claude-md.sh` - Install global CLAUDE.md (name, modules) and rules to `~/.claude/`
- `scripts/frameworks.sh` - Install frameworks via npx
- `scripts/output-styles.sh` - Install output styles to `~/.claude/output-styles/`
- `quickstart/` - Usage documentation by category
- `config/` - Example files (settings.json, CLAUDE.md)
- `config/output-styles/` - Output style definitions (e.g., jarvis.md)
- `config/claude-md/` - CLAUDE.md module files (e.g., git-defaults.md)
- `config/rules/` - Rule files for `~/.claude/rules/` (e.g., ipa-methodology.md)
- `config/statusline.js` - Unified statusline (4 modes: custom/minimal x base/GSD)
- `test/README.md` - Test setup and running instructions
- `test/run-tests.sh` - Bats test runner wrapper
- `test/helpers.bash` - Shared test helpers
- `test/*.bats` - Bats unit tests (plugins, mcp-servers, skills, commands, frameworks, utils)
- `test/jarvis/` - Jarvis output style test suite (JSON-driven, parallel)
- `test/claude-md/` - CLAUDE.md + rules test suite (JSON-driven, parallel)

## Code Conventions

- All scripts use `set -euo pipefail`
- Function prefixes by category: `install_*`, `print_*`, `check_*`
- Globals in UPPER_CASE, locals with `local` keyword
- Colors defined only in `utils.sh`, never hardcoded
- Scripts work standalone AND as sourced modules
- Use `SCRIPT_DIR` pattern for reliable relative paths

## Architecture

- `utils.sh` is the ONLY shared dependency (colors, UI helpers, tracking arrays)
- Sub-scripts define functions that `install.sh` calls in sequence
- `multi_select()` uses Bash nameref (`local -n`) to return values
- Tracking arrays accumulate across modules for final summary

## Boundaries

### Always
- Use `set -euo pipefail` in all scripts
- Validate required commands before execution
- Confirm before modifying existing files in `~/.claude/`
- Use `read -rsp` for secret input (silent, no history)

### Ask First
- Modify user's global configurations
- Add non-Bash dependencies
- Change minimum Bash version requirement

### Never
- `git push` or create commits automatically
- Use `eval` or string interpolation with user input
- Log, echo, or expose secrets in output
- Use `git push --force`, `rm -rf`, or destructive operations
- Modify files without explicit confirmation

## Security Rules

- Secrets stored in `~/.env.secrets` with `chmod 600`
- Empty secrets trigger retry or explicit skip
- Never pass secrets to commands without validation

## Common Pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `source: not found` | Running with `sh` instead of `bash` | Use `bash script.sh` explicitly |
| `permission denied` | Script lacks execute permission | Use `bash script.sh` not `./script.sh` |
| MCP server missing | Secrets not saved correctly | Check `~/.env.secrets` has `chmod 600` |
| Plugin fails | Claude CLI outdated | `npm install -g @anthropic-ai/claude-code` |

## Testing

- Syntax validation: `bash -n install.sh && bash -n scripts/*.sh`
- Post-install verification: `claude mcp list`, `claude plugin list`
- Each module is independently testable
- Bats unit tests: `./test/run-tests.sh` or `bats test/*.bats`
- Jarvis output style: `bash test/jarvis/test-jarvis.sh` (16 tests, parallel, JSON-driven)
- CLAUDE.md + rules: `bash test/claude-md/test-claude-md.sh` (13 tests, parallel, JSON-driven)

## When Stuck

1. Check syntax: `bash -n install.sh`
2. Run individual module to isolate issue
3. Check `~/.claude/` for conflicting configs
4. Review Claude CLI logs for plugin/MCP errors

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for:
- Git workflow (Gitflow branching model)
- Commit format with gitmoji
- Creating new modules
- Code review checklist
- Testing guidelines
- PR process
