# Code Review Mindset

## Before writing code

- **Impact analysis**: What does this change affect? What could break?
- **Document decisions**: If you chose approach A over B, leave a brief note explaining why.

## While writing code

- Review your own diff before committing. Read it as if someone else wrote it.
- Ask: "Would I approve this in a PR review?"
- Check: error handling, edge cases, naming clarity, test coverage.

## Principles

- Every non-obvious decision deserves a one-line comment explaining WHY (not what).
- If a change touches shared code, consider who else uses it.
- Prefer small, focused commits over large multi-concern commits.
- Flag TODOs with context: `// TODO(name): reason — ticket/date`
