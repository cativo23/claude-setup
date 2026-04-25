# GSD (Get Shit Done) Quick Reference

## What is GSD?

GSD is a meta-prompting framework for spec-driven development. It manages fresh 200k token contexts for each task, preventing Claude from "forgetting" context in long sessions.

## When to Use GSD

- **Large projects** with many moving parts
- **Massive refactors** spanning many files
- **When Claude starts losing context** in a long conversation
- **Complex multi-step tasks** that need structured execution

## GSD vs Superpowers

| Aspect | GSD | Superpowers |
|--------|-----|-------------|
| **Focus** | Context management | Methodology/workflow |
| **Strength** | Fresh 200k contexts per task | Brainstorm -> Plan -> Execute |
| **Best for** | Large projects, long sessions | Feature dev, debugging, reviews |
| **Approach** | Spec-driven, milestone-based | Skill-driven, checklist-based |

**They complement each other:** Use GSD for context management and Superpowers for methodology within each context.

## Core Workflow

```
1. /gsd:new-project     Start a new GSD project
2. Discuss              Define scope and requirements
3. Plan                 GSD creates spec + milestones
4. Execute              Each milestone in a fresh context
5. Verify               GSD validates against spec
6. /gsd:complete-milestone  Mark milestone done, move to next
```

## Key Commands

| Command | What it does |
|---------|-------------|
| `/gsd:new-project` | Initialize a new GSD project with spec |
| `/gsd:complete-milestone` | Mark current milestone complete |
| `/gsd:status` | Show project status and progress |
| `/gsd:resume` | Resume work on an existing project |

## How It Works

1. **Spec Phase:** You describe what you want. GSD creates a detailed specification.
2. **Planning Phase:** GSD breaks the spec into milestones with clear deliverables.
3. **Execution Phase:** Each milestone runs in a fresh Claude context with full 200k tokens.
4. **Verification Phase:** GSD checks work against the original spec.

## Installation

GSD runs via npx - no permanent installation needed:

```bash
npx gsd-cli@latest
```

## Tips

- Write detailed specs upfront - GSD works best with clear requirements
- Keep milestones focused - one clear deliverable per milestone
- Use `/gsd:status` to track progress across milestones
- Combine with `superpowers:brainstorming` before starting the spec phase
