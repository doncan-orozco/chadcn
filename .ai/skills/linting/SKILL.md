---
name: linting
description: "RuboCop standards for the chadcn gem. Use when running `bundle exec rubocop`, fixing lint offenses, editing `.rubocop.yml`, or reviewing Ruby style (guard clauses, performance cops, Minitest clarity, the verbatim shadcn class strings)."
---

# Linting (RuboCop)

## Quick Rules

Cite as `linting R<n>`. Detail and examples follow below / in references/.

R1. **Rubocop clean.** `bundle exec rubocop` passes with no offenses on the changed Ruby files (`bin/check` runs it over the whole gem). → detail: Suggested Workflow
R2. **Tests after lint.** Run `bundle exec rake test` (and `rake test:engine` when an integration file changed) after `bundle exec rubocop`, including after any `rubocop -A` autocorrect. → detail: Suggested Workflow
R3. (dropped: host-only, `Rails/SaveBang` and `Rails/SkipsModelValidations` guard ActiveRecord persistence; the gem has no models or database and does not load rubocop-rails)
R4. **Guard clauses.** Use guard clauses instead of deep nesting. → detail: Focus Areas
R5. **Performance and Minitest cops.** Collection/string code satisfies rubocop-performance, and tests satisfy rubocop-minitest clarity cops. → detail: Focus Areas
R6. **Style basics.** `# frozen_string_literal: true` first, double-quoted strings, 2-space indent, snake_case methods, spaces inside array brackets, no trailing whitespace or commented-out code; lines are at most 160 chars except the verbatim shadcn class strings and generated icon paths that `.rubocop.yml` exempts. → detail: references/lint-and-tests.md
R7. **Required cops available.** `.rubocop.yml` keeps the rubocop-minitest, rubocop-performance and rubocop-rake plugins with `NewCops: enable` and `TargetRubyVersion: 3.3`; the dev kit (`dev/**`), the generated icon catalog, `tmp`, `vendor` and `node_modules` stay excluded. → detail: Dependencies

## Dependencies
- rubocop
- rubocop-minitest
- rubocop-performance
- rubocop-rake

They are development dependencies in the `Gemfile`, never runtime dependencies of the gemspec (`ruby-gem-conventions` R3).

## Focus Areas (Examples)
- Guard clauses to avoid deep nesting
- Performance cops for collections and string operations (`filter_map`, `Set` lookups, no `map.compact`)
- Minitest cops for test clarity (`assert_predicate`, `assert_includes`, `refute_*` spelled `assert_not_*` through `Chadcn::TestCase`)
- Verbatim shadcn class strings stay on one line: `Layout/LineLength` allows them (`AllowedPatterns` in `.rubocop.yml`); never re-wrap or split a token string to please a cop

## Suggested Workflow

```bash
bundle exec rubocop
bundle exec rake test
```

Run them with `env -u BUNDLE_GEMFILE` and a UTF-8 locale (`LANG=en_US.UTF-8`) when your shell exports something else.

See [Lint and test examples](references/lint-and-tests.md) for common fixes.

If style violations exist, try:

```bash
bundle exec rubocop -A
```

Never run `-A` over whole directories inside an audit fix (`senior-rails-dev` fixes only the lines it touched); outside an audit, review the autocorrect diff before committing.
