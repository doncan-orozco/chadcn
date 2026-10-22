---
name: linting
description: "RuboCop standards for Papyro. Use when running `bin/rubocop`, fixing lint offenses, editing `.rubocop.yml`, or reviewing Ruby style (guard clauses, performance cops, test clarity)."
---

# Linting (RuboCop)

## Quick Rules

Cite as `linting R<n>`. Detail and examples follow below / in references/.

R1. **Rubocop clean.** `bin/rubocop` passes with no offenses on the changed Ruby files. → detail: Suggested Workflow
R2. **Tests after lint.** Run `bin/rails test` after `bin/rubocop`, including after any `bin/rubocop -A` autocorrect. → detail: Suggested Workflow
R3. **Bang persistence.** Persistence calls follow `Rails/SaveBang` and avoid `Rails/SkipsModelValidations` violations. → detail: Focus Areas
R4. **Guard clauses.** Use guard clauses instead of deep nesting. → detail: Focus Areas
R5. **Performance and Minitest cops.** Collection/string code satisfies rubocop-performance, and tests satisfy rubocop-minitest clarity cops. → detail: Focus Areas
R6. **Style basics.** Lines are at most 120 chars, double-quoted strings, 2-space indent, snake_case methods, no trailing whitespace or commented-out code. → detail: references/lint-and-tests.md
R7. **Required cops available.** Lint config keeps rubocop, rails, performance, minitest and rake (plus capybara/factory_bot when used). → detail: Dependencies

## Dependencies
- rubocop
- rubocop-rails
- rubocop-performance
- rubocop-minitest
- rubocop-rake
- rubocop-capybara (if system tests)
- rubocop-factory_bot (if FactoryBot)

## Focus Areas (Examples)
- Safe Rails patterns (`Rails/SaveBang`, `Rails/SkipsModelValidations`)
- Guard clauses to avoid deep nesting
- Performance cops for collections and string operations
- Minitest cops for test clarity

## Suggested Workflow

```bash
bin/rubocop
bin/rails test
```

See [Lint and test examples](references/lint-and-tests.md) for common fixes.

If style violations exist, try:

```bash
bin/rubocop -A
```

See [Lint and test examples](references/lint-and-tests.md) for common fixes.
