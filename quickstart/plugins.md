# Plugins Quick Reference

## Installed Plugins

### superpowers
**What it does:** Complete development framework with brainstorming, planning, execution, TDD, debugging, and code review workflows.

**When it activates:** Always active - skills are auto-invoked based on context.

**Key commands & skills:**
- `/brainstorm` - Start creative exploration before building features
- `/write-plan` - Create an implementation plan from requirements
- `/execute-plan` - Execute a plan with review checkpoints
- `superpowers:brainstorming` - Must use before any creative work
- `superpowers:test-driven-development` - Use when implementing features
- `superpowers:systematic-debugging` - Use when debugging issues

**Workflow:** `/brainstorm` -> `/write-plan` -> `/execute-plan`

---

### fullstack-dev-skills
**What it does:** 66 specialized skills covering languages, frameworks, and engineering disciplines.

**When it activates:** Auto-invoked by context (language/framework detected in code).

**Key skills (examples):**
- `vue-expert` - Activates when working with Vue files
- `nestjs-expert` - Activates for NestJS projects
- `postgres-pro` - Activates for SQL/database work
- `react-expert` - Activates for React components
- `typescript-pro` - Activates for TypeScript code
- `test-master` - Writing and strategy for tests
- `security-reviewer` - Security audits
- `code-reviewer` - Code quality reviews

**Special:** `fullstack-dev-skills:the-fool` - Challenge ideas and decisions with structured critical reasoning.

---

### security-guidance
**What it does:** Automatic security hook that reviews every Edit/Write operation for vulnerabilities.

**When it activates:** Automatically on every file edit - no action required.

**What it catches:** XSS, SQL injection, command injection, hardcoded secrets, insecure configurations, OWASP Top 10 issues.

---

### feature-dev
**What it does:** Guided feature development workflow with 7 phases and 3 specialized agents (explorer, architect, reviewer).

**When to use:** When creating new features from scratch.

**Command:** `/feature-dev <description>`

**Phases:**
1. Exploration - understand codebase context
2. Requirements - define what to build
3. Design - architect the solution
4. Implementation - write the code
5. Testing - verify correctness
6. Review - code quality check
7. Documentation - update docs

---

### claude-mem
> **Requires:** Bun (https://bun.sh/install)

**What it does:** Persistent memory between Claude Code sessions using SQLite + vector search.

**When it activates:** Always active - automatically injects relevant context from previous sessions.

**Usage:**
- Memory is automatic - Claude remembers past conversations
- Search with `@memory` to find specific past context
- Web UI at `localhost:37777` for browsing memories

## Managing Plugins

```bash
# List installed plugins
claude plugin list

# Install a new plugin
claude plugin install <name>

# Remove a plugin
claude plugin remove <name>

# List available marketplaces
claude plugin marketplace list
```
