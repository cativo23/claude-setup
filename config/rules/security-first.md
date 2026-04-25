# Security-First Development

## Principles

1. **Never expose secrets.** No API keys, tokens, passwords, or credentials in code, logs, or error messages.
2. **Validate all external input.** User input, API responses, file contents, environment variables — sanitize at system boundaries.
3. **Explicit error messages.** Errors should help the developer debug without leaking internal state to end users.
4. **Least privilege.** Request only the permissions needed. Don't run as root. Don't grant broad access.
5. **Secure defaults.** HTTPS over HTTP. Parameterized queries over string concatenation. httpOnly cookies over localStorage for tokens.

## When reviewing code

- Check for hardcoded secrets, even in tests or examples
- Verify input validation at every entry point (API endpoints, CLI args, file reads)
- Flag SQL string concatenation, dynamic code execution, and unsafe DOM injection patterns
- Ensure error responses don't leak stack traces, file paths, or internal IDs
