# CLAUDE.md + Rules Quick Reference

## What is CLAUDE.md?

`~/.claude/CLAUDE.md` is your global instruction file. Claude reads it at the start of every session, in every project. Use it for preferences that should always apply — like your name and git conventions.

**Location:** `~/.claude/CLAUDE.md`

## What are Rules?

Rules are modular instruction files in `~/.claude/rules/`. Each file focuses on one methodology or practice. Claude loads them every session alongside CLAUDE.md.

**Location:** `~/.claude/rules/*.md`

## CLAUDE.md vs Rules

| | CLAUDE.md | Rules |
|---|---|---|
| **Files** | Single file | One file per topic |
| **Location** | `~/.claude/CLAUDE.md` | `~/.claude/rules/` |
| **Best for** | Identity, preferences | Methodologies, practices |
| **Loaded** | Every session | Every session |

## Installed Modules

### Name (always installed)
Your name, so Claude addresses you correctly across all sessions.

### git-defaults (optional)
Conventional commits (`type(scope): description`), branch naming (`type/short-description`), PR format.

## Installed Rules

### ipa-methodology
**Investigate → Plan → Act** workflow. Claude investigates before forming opinions, plans before coding, and flags risks. Includes decision logic for different question types and response shape guidelines.

### security-first
Security-focused development practices: never expose secrets, validate inputs, use secure defaults (HTTPS, parameterized queries, httpOnly cookies).

### tdd-first
**Red → Green → Refactor** cycle. Write failing test, minimal implementation, then refactor. Test behaviors, not functions.

### code-review-mindset
Review your own code before committing. Impact analysis, document decisions, prefer small focused commits.

### minimalist
YAGNI — don't build what you don't need. Simplest solution first. Ask before expanding scope.

## Customizing

**Edit CLAUDE.md directly:**
```bash
vim ~/.claude/CLAUDE.md
```

**Add/remove rules:**
```bash
# Add a custom rule
echo "# My Rule\n\nAlways use tabs." > ~/.claude/rules/my-rule.md

# Remove a rule
rm ~/.claude/rules/tdd-first.md
```

**Re-running the installer:**
Safe to re-run — detects your existing name and skips duplicate CLAUDE.md modules.

## Testing

```bash
# Run all CLAUDE.md + rules tests
bash test/claude-md/test-claude-md.sh

# Test a specific block
bash test/claude-md/test-claude-md.sh --block 3

# Test a single case
bash test/claude-md/test-claude-md.sh --test-id 3.1
```
