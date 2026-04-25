<div align="center">

<pre>
       __                __                     __           
 _____/ /___ ___  ______/ /__        ________  / /___  ______
/ ___/ / __ `/ / / / __  / _ \______/ ___/ _ \/ __/ / / / __ \
/ /__/ / /_/ / /_/ / /_/ /  __/_____(__  )  __/ /_/ /_/ / /_/ /
\___/_/\__,_/\__,_/\__,_/\___/     /____/\___/\__/\__,_/ .___/
                                                       /_/
</pre>

**Configure Claude Code from scratch with a single command.**

Plugins, MCP servers, CLAUDE.md, rules, output styles, statusline, skills, commands, and frameworks — all interactive, all modular.

[![GitHub release](https://img.shields.io/github/v/release/cativo23/claude-setup?include_prereleases&style=flat-square)](https://github.com/cativo23/claude-setup/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](CONTRIBUTING.md)
[![Bash](https://img.shields.io/badge/Bash-5%2B-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![CI - Test Suite](https://github.com/cativo23/claude-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/cativo23/claude-setup/actions/workflows/ci.yml)

</div>

---

## Table of Contents

- [Quick Start](#quick-start)
- [What Gets Installed](#what-gets-installed)
- [Interactive Installer](#interactive-installer)
- [Customization](#customization)
- [Secrets Management](#secrets-management)
- [Quickstart Docs](#quickstart-docs)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)

---

## Quick Start

**One-liner install:**

```bash
curl -fsSL https://raw.githubusercontent.com/cativo23/claude-setup/main/quickinstall.sh | bash
```

**Or clone manually:**

```bash
git clone https://github.com/cativo23/claude-setup.git
cd claude-setup
bash install.sh
```

The interactive installer guides you through selecting each component.

---

## ⭐ Why Use This?

| Problem | Solution |
|---------|----------|
| Manual Claude Code setup takes 30-60 minutes | **5 minutes with 1 command** |
| Installing plugins one by one is tedious | **All-in-one interactive installer** |
| Forgetting to configure best practices | **GSD framework + TDD + Security rules included** |
| Lost context between Claude sessions | **claude-mem plugin for persistent memory** |
| No idea what plugins are good | **5 curated, production-tested plugins** |
| MCP servers are confusing to set up | **Auto-configured with secure secret handling** |

**Used by developers since March 2026**.


---

## What Gets Installed

### Plugins

| Plugin | Description |
|:-------|:------------|
| **superpowers** | Development framework — brainstorm, plan, execute, TDD, debugging |
| **security-guidance** | Automatic security hook on every Edit/Write |
| **fullstack-dev-skills** | 66 specialized skills by language and framework |
| **feature-dev** | Guided feature development in 7 phases |
| **claude-mem** | Persistent memory between sessions |

> **Note:** The `claude-mem` plugin requires Bun. Install it at: https://bun.sh/install

### MCP Servers

| Server | Description |
|:-------|:------------|
| **GitHub** | Issues, PRs, CI/CD directly from Claude |
| **Tavily** | AI-powered web search during development |

### CLAUDE.md + Rules

| Component | Description |
|:----------|:------------|
| **Name prompt** | Asks your name so Claude addresses you correctly |
| **git-defaults** | Optional module: conventional commits, branch naming, PR format |
| **ipa-methodology** | Rule: Investigate → Plan → Act workflow |
| **security-first** | Rule: Secure defaults, input validation, no exposed secrets |
| **tdd-first** | Rule: Red → Green → Refactor cycle |
| **code-review-mindset** | Rule: Self-review before commit, impact analysis |
| **minimalist** | Rule: YAGNI — simplest solution first |

> Rules are optional and selected via multi-select menu (default: unselected).

### Output Styles

| Style | Description |
|:------|:------------|
| **Jarvis** | Rioplatense voseo, fillers, and tone matching |

### Statusline

| Mode | Description |
|:-----|:------------|
| **Custom** | 3-line: emojis, context bar, git info, cost, duration, tokens |
| **Minimal** | 1-line: colored ASCII compact bar |
| **+ GSD** | Either mode with GSD update check + current task |

### Frameworks

| Framework | Description |
|:----------|:------------|
| **GSD** | Meta-prompting with fresh contexts per task |

---

## Interactive Installer

The installer provides a fully interactive experience with multi-select menus for each category.

```
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    PLUGINS
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Use ↑/↓ to navigate, SPACE to toggle, 'a' toggle all, ENTER to confirm
  5/5 selected

  > [✓] superpowers              Framework de dev: brainstorm > plan > execute
    [✓] security-guidance         Hook automatico de seguridad en Edit/Write
    [✓] fullstack-dev-skills      66 skills por lenguaje/framework
    [✓] feature-dev               Workflow guiado de features (7 fases)
    [✓] claude-mem                Memoria persistente entre sesiones
```

All items are selected by default. Deselect what you don't need.

<details>
<summary><strong>Keyboard controls</strong></summary>

| Key | Action |
|:----|:-------|
| `Up` / `Down` | Navigate items |
| `Space` | Toggle selection |
| `a` | Select / deselect all |
| `Enter` | Confirm selection |

</details>

---

## Customization

**Custom Skills** — Place `.md` files in the `skills/` directory. The installer detects and offers them for installation to `~/.claude/skills/`.

**Custom Commands** — Place `.md` files in the `commands/` directory. They'll be available for installation to `~/.claude/commands/`.

---

## Secrets Management

MCP server secrets are handled securely:

- Prompted interactively with hidden input (`read -sp`)
- Stored in `~/.env.secrets` with `chmod 600` (owner read/write only)
- Permissions automatically fixed if incorrect
- Never logged or displayed

```bash
# Recommended: add to your global gitignore
echo ".env.secrets" >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

**File Permissions:**

The installer ensures `~/.env.secrets` has `600` permissions (owner read/write only). If existing file has different permissions, they are automatically corrected with a warning.

---

## Quickstart Docs

After installation, check the `quickstart/` directory:

| Guide | Topic |
|:------|:------|
| [`plugins.md`](quickstart/plugins.md) | How to use each plugin |
| [`mcp-servers.md`](quickstart/mcp-servers.md) | Managing MCP servers |
| [`skills-and-commands.md`](quickstart/skills-and-commands.md) | Skills vs commands vs hooks |
| [`gsd.md`](quickstart/gsd.md) | GSD framework guide |
| [`claude-md.md`](quickstart/claude-md.md) | CLAUDE.md + rules setup |

---

## Prerequisites

| Dependency | Required | Install |
|:-----------|:--------:|:--------|
| Claude CLI | Yes | [docs.anthropic.com](https://docs.anthropic.com/en/docs/claude-code) |
| Node.js (with npx) | Yes | [nodejs.org](https://nodejs.org) |
| Git | Yes | [git-scm.com](https://git-scm.com) |
| Bun | No (required for claude-mem) | [bun.sh/install](https://bun.sh/install) |
| GitHub CLI | No | [cli.github.com](https://cli.github.com) |

---

<details>
<summary><strong>Project Structure</strong></summary>

```
claude-setup/
  install.sh                # Main orchestrator
  quickinstall.sh           # One-liner bootstrap script
  scripts/
    utils.sh                # Shared functions (colors, multi_select, spinners)
    plugins.sh              # Plugin installation via CLI
    mcp-servers.sh          # MCP server configuration (prompts for secrets)
    skills.sh               # Custom skills -> ~/.claude/skills/
    commands.sh             # Custom commands -> ~/.claude/commands/
    frameworks.sh           # GSD via npx
    output-styles.sh        # Output style installation
    claude-md.sh            # Global CLAUDE.md (name, modules) + rules installer
  quickstart/
    plugins.md              # Plugin usage reference
    mcp-servers.md          # MCP server management
    skills-and-commands.md  # Skills vs commands vs hooks vs plugins
    gsd.md                  # GSD framework guide
    claude-md.md            # CLAUDE.md + rules setup
  skills/                   # Your custom skills (.md files)
  commands/                 # Your custom slash commands (.md files)
  config/
    settings.example.json   # Example Claude Code settings
    CLAUDE.example.md       # Example project instructions
    claude-md/              # CLAUDE.md module files (e.g., git-defaults.md)
    rules/                  # Rule files for ~/.claude/rules/ (5 rules)
    output-styles/
      jarvis.md             # Jarvis output style definition
    statusline.js           # Unified statusline (--minimal, --gsd)
  test/
    README.md               # Test setup and running instructions
    run-tests.sh            # Bats test runner wrapper
    helpers.bash             # Shared test helpers
    *.bats                  # Bats unit tests (plugins, mcp, skills, commands, frameworks, utils)
    jarvis/
      tests.json            # Test definitions (source of truth)
      test-jarvis.sh        # Parallel test runner
    claude-md/
      tests.json            # Test definitions (source of truth)
      test-claude-md.sh     # Parallel test runner
  .github/
    workflows/
      ci.yml                # CI: syntax check + Bats tests on push/PR
      release.yml           # Auto-release on merge to main
    PULL_REQUEST_TEMPLATE.md
    ISSUE_TEMPLATE/
```

</details>

---

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on branching, commit format, and the PR process.

## Security

For security information, see [SECURITY.md](SECURITY.md) - what this script does, secrets management, and best practices.

## License

MIT — see [LICENSE](LICENSE) for details.
