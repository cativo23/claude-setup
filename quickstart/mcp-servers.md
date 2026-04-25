# MCP Servers Quick Reference

## Configured Servers

### GitHub MCP
**What it does:** Manage GitHub issues, PRs, CI/CD, and repositories directly from Claude Code.

**Transport:** HTTP

**Setup command:**
```bash
claude mcp add --transport http github "https://api.githubcopilot.com/mcp/" \
  -H "Authorization: Bearer <YOUR_GITHUB_TOKEN>"
```

**Token:** Personal Access Token with `repo`, `read:org`, `read:user` scopes.
Get one at: https://github.com/settings/tokens

**Use cases:**
- Create and manage issues without leaving the terminal
- Review and comment on PRs
- Check CI/CD status
- Search repositories and code

---

### Tavily
**What it does:** AI-powered web search for finding up-to-date information during development.

**Transport:** stdio (via npx)

**Setup command:**
```bash
TAVILY_API_KEY="<YOUR_KEY>" claude mcp add tavily -- npx -y tavily-mcp@latest
```

**API Key:** Get one at https://tavily.com

**Use cases:**
- Search for current documentation and API references
- Find solutions to errors and issues
- Research libraries and tools
- Get up-to-date information beyond Claude's training data

## Managing MCP Servers

```bash
# List configured servers
claude mcp list

# Get details for a server
claude mcp get <name>

# Remove a server
claude mcp remove <name>

# Check status inside Claude Code
/mcp
```

## Secrets Management

Secrets are stored in `~/.env.secrets` with `chmod 600` permissions.

**Never commit this file.** Add it to your global gitignore:
```bash
echo ".env.secrets" >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```
