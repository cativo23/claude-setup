# Skills, Commands, Hooks & Plugins

## Concepts Comparison

| Concept | What it is | When it activates | Example |
|---------|-----------|-------------------|---------|
| **Skill** | Knowledge/methodology for Claude | Auto-invoked by description or manually | `superpowers:brainstorming` |
| **Command** | Custom slash command | Manual: `/my-command` | `/brainstorm`, `/write-plan` |
| **Hook** | Script that runs on events | Automatic (PreToolUse, PostToolUse, etc.) | security-guidance hook |
| **Plugin** | Complete package (skills+hooks+commands) | Installed via marketplace | superpowers plugin |

## Skills

Skills are markdown files that teach Claude how to approach specific tasks.

**Location:** `~/.claude/skills/`

**How they work:**
- Claude auto-detects when a skill is relevant based on its description
- Can also be invoked manually with `skill_namespace:skill_name`
- Skills from plugins are managed by the plugin system

**Creating custom skills:**
1. Create a `.md` file in `~/.claude/skills/`
2. Add frontmatter with `name` and `description`
3. Write the methodology/instructions

## Commands

Slash commands are shortcuts that expand into full prompts.

**Location:** `~/.claude/commands/`

**How they work:**
- Type `/command-name` in Claude Code
- The command's content is expanded as a prompt
- Can accept arguments: `/command-name arg1 arg2`

**Creating custom commands:**
1. Create a `.md` file in `~/.claude/commands/`
2. Write the prompt template
3. Use `$ARGUMENTS` placeholder for user input

## Hooks

Hooks are shell scripts that execute automatically on Claude Code events.

**Events:**
- `PreToolUse` - Before a tool is called
- `PostToolUse` - After a tool completes
- `Notification` - When Claude sends a notification

**Configured in:** `~/.claude/settings.json` under `hooks`

## Built-in Commands

Useful built-in slash commands:

| Command | What it does |
|---------|-------------|
| `/help` | Show help and available commands |
| `/mcp` | Check MCP server status |
| `/clear` | Clear conversation context |
| `/compact` | Compress conversation to save context |
| `/cost` | Show token usage and costs |

## File Locations

```
~/.claude/
  settings.json    # Global settings, hooks config
  skills/          # Custom skills (.md files)
  commands/        # Custom slash commands (.md files)
  projects/        # Project-specific memory
  CLAUDE.md        # Global instructions for Claude
```
