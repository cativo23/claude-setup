# Security Considerations

This document explains what `claude-setup` does, how it handles your data, and security best practices.

---

## 🔍 What This Script Does

The installer performs the following operations on your local machine:

### 1. Directory Creation
```bash
~/.claude/plugins/      # Plugin configurations
~/.claude/rules/        # Rule files
~/.claude/skills/       # Custom skills
~/.claude/commands/     # Custom commands
~/.claude/md/           # CLAUDE.md configurations
```

### 2. Plugin Installation
- Clones plugin repositories from GitHub using `claude plugin install`
- All plugins are public, open-source repositories
- No private code is downloaded

### 3. Configuration Files
- Writes `CLAUDE.md` with your name and optional modules
- Copies rule files to `~/.claude/rules/`
- Installs statusline configuration (`statusline.js`)
- Creates `settings.json` from template (preserves user config on updates)

### 4. MCP Server Setup
- Prompts for API secrets interactively (GitHub, Tavily)
- Stores secrets in `~/.env.secrets` with `chmod 600` permissions
- Secrets are **never** logged, echoed, or sent externally

### 5. Shell Configuration (Optional)
- May add statusline sourcing to `~/.bashrc` or `~/.zshrc`
- Only modifies if you explicitly approve

---

## 🚫 What This Script Does NOT Do

| Action | Status |
|--------|--------|
| Collect personal data | ❌ **Never** |
| Send data to external servers (except cloning public plugins from GitHub) | ❌ **Never** |
| Modify system files | ❌ **Never** |
| Run as root or with sudo | ❌ **Never** |
| Download or execute binaries | ❌ **Never** (only shell scripts and markdown files) |
| Access your Claude API keys | ❌ **Never** |
| Modify existing configurations without permission | ❌ **Never** |
| Install telemetry or analytics | ❌ **Never** |

---

## 🔐 Secrets Management

### How Secrets Are Handled

1. **Interactive Prompt**: Secrets are entered via `read -rsp` (hidden input, no echo)
2. **Storage**: Stored in `~/.env.secrets` with `chmod 600` (owner read/write only)
3. **Usage**: Only accessed by MCP servers locally
4. **Logging**: Never logged, echoed, or displayed in output

### File Permissions

| File/Directory | Permissions | Why |
|----------------|-------------|-----|
| `~/.env.secrets` | `600` | Contains API keys and tokens |
| `~/.claude/` | `755` | Plugin configs (no secrets stored here) |
| `install.sh` | `755` | Executable script |
| `quickinstall.sh` | `755` | Bootstrap script |

### Secret Validation

The installer validates secret formats before accepting:

| Secret Type | Format | Validation |
|-------------|--------|------------|
| GitHub Token | `ghp_*`, `github_pat_*`, `gho_*`, `ghu_*`, `ghs_*` | Prefix check |
| Tavily API Key | `tvly-*` + 15+ alphanumeric chars | Prefix + length check |

Invalid secrets are rejected with clear error messages.

---

## 🔎 Review Before Running

We **strongly recommend** reviewing the script before running:

### Option 1: Quick Review
```bash
# Preview the installer without running
curl -fsSL https://raw.githubusercontent.com/cativo23/claude-setup/main/install.sh | less
```

### Option 2: Full Local Review
```bash
# Clone and review locally
git clone https://github.com/cativo23/claude-setup.git
cd claude-setup

# Review main installer
cat install.sh | less

# Review all scripts
ls -la scripts/
cat scripts/*.sh | less
```

### Option 3: Dry Run (Coming Soon)
```bash
# TODO: Add --dry-run flag to show what would be done without executing
bash install.sh --dry-run
```

---

## 📋 Installation Checklist

Before running the installer, verify:

- [ ] You have reviewed the script (`install.sh` or via `curl | less`)
- [ ] You understand what will be installed (plugins, MCP servers, rules)
- [ ] You have Claude Code CLI installed (`claude --version`)
- [ ] You have Node.js installed (for MCP servers and statusline)
- [ ] You have Bash 5.0+ (`bash --version`)
- [ ] You are running on a supported OS (Linux, macOS, WSL)

---

## 🛡️ Security Best Practices

### 1. Use Personal Access Tokens (Not Main Credentials)

For GitHub MCP server:
- Create a **fine-grained personal access token**
- Grant only necessary permissions (repo, issues, workflows)
- Set expiration date (30-90 days)
- Never use your main GitHub password

### 2. Rotate Secrets Regularly

```bash
# Update secrets in ~/.env.secrets
nano ~/.env.secrets
chmod 600 ~/.env.secrets
```

### 3. Review Installed Plugins

After installation, review what was installed:
```bash
ls ~/.claude/plugins/
cat ~/.claude/plugins/*/README.md
```

### 4. Monitor MCP Server Usage

Check what MCP servers are configured:
```bash
cat ~/.env.secrets
# Review which servers have secrets set
```

---

## 📜 Security Audit Log

| Version | Date | Security Changes |
|---------|------|------------------|
| v1.5.0 | 2026-04-08 | Statusline: path traversal protection in GSD/transcript, atomic cache writes (wx flag), session ID sanitization |
| v1.4.0 | 2026-03-16 | Settings template with secure defaults, merge_settings() preserves user config |
| v1.2.2 | 2026-03-15 | 🔒 Fixed Node.js injection in statusline (use `process.argv`), bridge file written with `0o600` permissions |
| v1.2.2 | 2026-03-15 | Secret file permissions secured with `0o600` |
| v0.2.6 | 2026-03-09 | Added `check_secrets_permissions()` for 600 permissions validation |
| v0.2.5 | 2026-03-09 | Added secret format validation (GitHub token, Tavily key prefixes) |
| v0.1.0 | 2026-03-07 | Initial secure secrets handling with hidden input |

---

## 🚨 Reporting a Security Vulnerability

**Do not open a public issue for security vulnerabilities.**

### How to Report

1. **Email**: security@cativo.dev (if available)
2. **GitHub Security Advisories**: Use private reporting (preferred)
3. **Direct Message**: Contact @cativo23 on GitHub

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)
- Your contact information

### Response Time

- **Critical** (data loss, remote code execution): 24-48 hours
- **High** (privilege escalation, secret exposure): 1 week
- **Medium** (information disclosure): 2 weeks
- **Low** (best practices): Next release cycle

---

## 🧪 Security Testing

The project includes automated security tests:

```bash
# Run all tests (includes security validations)
bats test/

# Run specific security tests
bats test/mcp-servers.bats  # Secret prompting and validation
bats test/utils.bats        # Permission checks
```

### Security Test Coverage

- ✅ Secret format validation (GitHub, Tavily)
- ✅ File permissions (600 for secrets)
- ✅ No secrets in logs or output
- ✅ Safe file handling (no injection)
- ✅ Rollback on failure (transactional install)

---

## 📚 Additional Resources

- [Claude Code Security](https://docs.anthropic.com/en/docs/claude-code/security)
- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [Tavily API Security](https://docs.tavily.com/docs/security)
- [Bash Security Best Practices](https://github.com/koalaman/shellcheck/wiki/Security)

---

## 📞 Contact

For security-related questions:

- **Email**: security@cativo.dev
- **GitHub**: @cativo23
- **Twitter**: @cativo23 (if available)

---

*Last updated: March 16, 2026*
