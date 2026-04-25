# Minimalist Development

## Principles

1. **YAGNI** — You Aren't Gonna Need It. Don't build features, abstractions, or flexibility for hypothetical future requirements.
2. **Smallest viable solution** — Three similar lines of code are better than a premature abstraction.
3. **Ask before expanding scope** — If a task seems to require more than what was asked, check with the user first.
4. **No speculative error handling** — Only validate at system boundaries (user input, external APIs). Trust internal code.
5. **Delete freely** — If code is unused, remove it. No backwards-compatibility shims for internal code.

## When implementing

- Start with the simplest approach. Add complexity only when the simple approach demonstrably fails.
- Don't add configuration, feature flags, or plugin systems unless explicitly requested.
- Don't refactor surrounding code unless it's blocking the current task.
- A bug fix doesn't need the surrounding code cleaned up.
