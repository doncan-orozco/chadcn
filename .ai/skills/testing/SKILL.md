---
name: testing
description: "Minitest testing for Papyro, including system tests. Use when writing or fixing anything under `test/` — operations, contracts, queries, presenters, components, controllers, jobs, channels, Capybara/Cuprite system tests for Hotwire flows — or running the CI verification pipeline (`bin/ci`)."
---

# Testing (Minitest + dry-rb)

## Quick Rules

Cite as `testing R<n>`. Detail and examples follow below / in references/.

R1. **Mirror concept tests.** Every new file under `app/concepts/**/{operation,query,presenter,service}/` has a matching `test/concepts/**/<same layer>/*_test.rb`. → detail: Concept Coverage Policy
R2. **Core abstractions tested.** Changes to `app/concepts/core/` come with lightweight contract tests locking base behavior. → detail: Concept Coverage Policy
R3. **Success plus failure.** Each concept test file asserts at least one success path and one failure/edge path (where applicable). → detail: Concept Coverage Policy
R4. **Payload shape asserted.** Operation and query tests check the result payload shape, not just success/failure. → detail: Concept Coverage Policy
R5. **Fixtures by default.** Test data comes from fixtures; FactoryBot is added only when fixtures become unmanageable. → detail: Suggestions
R6. **Semantic component assertions.** Component and view tests assert key sections, variants and data attributes, without snapshots or brittle class-level checks. → detail: UI Components (Phlex) / Views
R7. **SEO coverage on public routes.** Each new indexable public URL has an integration test asserting canonical, locale alternates, `x-default` hreflang and title/description/og tags. → detail: SEO Integration Coverage
R8. **Engine tests run from host.** PapyroStudio engine tests load the host environment/fixtures and run from the host app root; no duplicate suite ownership across host and engine. → detail: Host-Coupled Engine Harness
R9. **No sleep in system tests.** System tests never call `sleep`; they wait via `assert_text`, `assert_selector` or `assert_current_path`. → detail: references/hotwire-system-testing.md
R10. **UI before database.** After a Turbo/Stimulus action, assert a visible UI signal before asserting persisted state. → detail: references/hotwire-system-testing.md
R11. **Selector order and `:testid`.** Use labels/button text first; `data-testid` only for async or unstable elements, queried via `find(:testid, ...)`, never raw `[data-testid=...]` CSS or nth-child selectors. → detail: references/hotwire-system-testing.md
R12. **Thin system tests.** System tests set up state in Ruby, cover one visible UI error path, and leave validation matrices to contract/operation tests. → detail: references/hotwire-system-testing.md
R13. **Wait before asserting in browser.** Playwright/system tests wait for elements before asserting, cover critical flows, and test behavior rather than implementation details. → detail: references/system-testing-playwright.md
R14. **Cross-domain session flow.** Cross-subdomain auth/session changes include at least one real browser navigation test across host and studio domains. → detail: references/hotwire-system-testing.md
R15. **Green CI pipeline.** New code has tests, no undocumented skipped tests, and `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit`, `bin/rubocop` and `rake test` pass before push. → detail: references/ci-verification.md

## Dependencies
- minitest
- dry-monads
- dry-validation

## File Structure
```
test/
  operations/
    game/
      operation/
        move_player_test.rb
    player/
      operation/
        create_test.rb
  contracts/
    game/
      contract/
        move_player_test.rb
  channels/
    game_channel_test.rb
  fixtures/
```

## Coverage Examples
- Operations in isolation (happy + failure paths)
- Contracts for validation
- Channels for WebSocket authorization
- Broadcast assertions for realtime features
- Fixtures for test data
- Small, explicit tests

## Concept Coverage Policy (Required)

For concept-layer coverage, enforce a mirrored test structure:

1. Every file under `app/concepts/**/operation/*.rb` must have a corresponding test under `test/concepts/**/operation/*_test.rb`.
2. Every file under `app/concepts/**/query/*.rb` must have a corresponding test under `test/concepts/**/query/*_test.rb`.
3. Every file under `app/concepts/**/presenter/*.rb` must have a corresponding test under `test/concepts/**/presenter/*_test.rb`.
4. Every file under `app/concepts/**/service/*.rb` must have a corresponding test under `test/concepts/**/service/*_test.rb`.
5. Core abstractions under `app/concepts/core/` must have lightweight contract tests to lock base behavior.

Minimum expectation per concept test file:

1. At least one success-path assertion.
2. At least one failure/edge-path assertion (where applicable).
3. Result payload shape checks for operation/query contracts.

## Suggestions
- Framework: Minitest (Rails-native, fast, minimal)
- Test data: fixtures by default; add FactoryBot if fixtures become unmanageable
- System tests: Playwright (more reliable than Selenium) with Capybara driver

## Host-Coupled Engine Harness (PapyroStudio)

Use this pattern when engine code depends on host models, DB schema, and authentication:

1. Engine test helper boots the host environment (for this workspace, via sibling host app path).
2. Engine tests run from host app root (not inside engine directory) to ensure one source of truth for boot/runtime.
3. Keep fixtures sourced from host app fixture paths in the engine test helper.

### Coverage Ownership Split

1. Engine test suite should own studio request/policy/presenter depth tests.
2. Host test suite should keep a small smoke boundary for mount/subdomain/session integration.
3. Avoid duplicate suite ownership across host and engine; remove migrated host duplicates after parity is confirmed.

### Commands

From host app root:

1. `bin/rails test`
2. `bin/rails test ../papyro_studio/test`
3. `bin/rails test:with_studio`

See [references/tests.md](references/tests.md) for concrete examples.

## UI Components (Phlex)
- Render components and assert HTML output.
- Verify variant/size classes and data attributes.
- Keep assertions semantic (avoid brittle class-level expectations when possible).

## Views
- Treat views as integration units: render and assert key sections.
- Avoid snapshot noise; assert only critical content.

> **Flash and Toast Test Examples:** controller, component and system tests → [references/flash-and-toast-tests.md](references/flash-and-toast-tests.md)

## SEO Integration Coverage
- For every public URL that should be indexable, add an integration test for head metadata.
- Assert the canonical URL, locale alternates, and `x-default` hreflang tag.
- Assert the base social tags as well: `title`, `meta[name='description']`, `og:title`, `og:description`, `og:locale`, and `og:locale:alternate`.
- Cover at least the home page, public index pages, public show pages, and public profile pages when they exist.
- Treat missing SEO assertions on a new public route as missing required coverage, not optional follow-up work.

> **System Testing with Playwright:** setup, patterns, scenarios, debugging → [references/system-testing-playwright.md](references/system-testing-playwright.md)

## Test Organization

```
test/
  application_system_test_case.rb
  test_helper.rb
  
  concepts/
    articles/
      operation/
        create_test.rb
      contract/
        create_contract_test.rb
    
  controllers/
    articles_controller_test.rb
  
  components/
    article_card_test.rb
  
  system/
    articles/
      create_article_test.rb
      edit_article_test.rb
      sort_articles_test.rb
    
  fixtures/
    articles.yml
    users.yml
```

## Coverage Checklist

- [ ] Operations: happy path + all failure cases
- [ ] Contracts: all validation rules
- [ ] Components: rendering + variants
- [ ] System tests: critical user flows
- [ ] Real-time: broadcasts + WebSocket updates
- [ ] Error handling: validation errors, network errors
- [ ] Accessibility: keyboard navigation, ARIA labels

> **CI/CD Verification Pipeline:** what CI checks, local pre-push, troubleshooting → [references/ci-verification.md](references/ci-verification.md)

