# TDD-First: Red → Green → Refactor

## Workflow

1. **Red** — Write a failing test that describes the desired behavior. Run it. Confirm it fails for the right reason.
2. **Green** — Write the minimum code to make the test pass. No more.
3. **Refactor** — Clean up while tests stay green. Extract, rename, simplify.

## Principles

- Write the test BEFORE the implementation. If you catch yourself writing code first, stop and write the test.
- Each test should test one behavior, not one function.
- Test names should describe the behavior: `should_reject_expired_tokens`, not `test_validate`.
- Don't mock what you don't own. Wrap external dependencies, then mock the wrapper.
- When fixing a bug: write a test that reproduces it first, then fix.
