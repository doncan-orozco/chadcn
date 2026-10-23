---
name: testing
description: "Minitest and browser testing for the chadcn gem. Use when writing or fixing anything under `test/` (component tests in `test/chadcn`, the doctor, packaging, the public API snapshot, the engine and generator suite, the browser tests in `test/javascript`), the repository tooling tests in `.claude/scripts/test`, or when running the verification pipeline (`bin/check`, `bin/test-js`, `bin/smoke`)."
---

# Testing (Minitest, no database, no network)

## Quick Rules

Cite as `testing R<n>`. Detail and examples follow below / in references/.

R1. **Mirror tests.** Every component file `lib/chadcn/<name>.rb` has `test/chadcn/<name>_test.rb`; a controller whose behavior a scenario step cannot express has `test/javascript/<name>.test.mjs`; `lib/chadcn/doctor/**`, `lib/generators/**` and `lib/chadcn/engine*` are covered under `test/doctor`, `test/generators` and `test/engine`. → detail: Suites
R2. **Core abstractions tested.** Changes to `Chadcn::Base` (`cn`, `merge_attrs`, `render_as_child`, `normalize_option`, the DX helper generator) come with tests in `test/chadcn/base*_test.rb` locking the merge tables and the helper contract. → detail: Component tests
R3. **Default plus non-default.** Each component test asserts the default render and at least one non-default path (a variant or size, a state, `disabled`, `as_child`, an invalid option raising). → detail: Component tests
R4. (dropped: host-only, payload-shape assertions belonged to the consuming application's operations and queries; the gem has no result objects)
R5. (dropped: host-only, fixtures and FactoryBot need a database; the gem renders components directly and keeps one snapshot fixture, `test/fixtures/public_api.txt`)
R6. **Semantic component assertions.** Tests assert `data-slot`, `data-variant`/`data-size`, `data-state`, `role`/`aria-*`, the merged `class` and attribute passthrough with `assert_includes`, never whole-HTML snapshots or brittle class-order checks; the G1 gate already proves the token set. → detail: Component tests
R7. (dropped: host-only, SEO head metadata belongs to the consuming application's public routes)
R8. (dropped: host-only, the Papyro application's Studio engine suite booted that application; this gem's engine tests boot their own minimal Rails app, see R17)
R9. **No fixed waits in browser tests.** `test/javascript` never sleeps on a timer; it waits for a DOM state (`locator.waitFor`, `data-state`, `networkidle` on open) or a dispatched event. → detail: Browser tests
R10. (dropped: host-only, "UI signal before persisted state" guarded database writes after Turbo actions; the gem persists nothing)
R11. **Select by contract.** Browser and unit tests find elements by `data-slot`, role, accessible name or `data-state`, never by `nth-child`, class strings or tag position. → detail: Browser tests
R12. **Scenarios first, JS tests for the rest.** Anything a scenario step can express is a scenario in `dev/port/scenarios/<name>.json` (compared with React by the parity runner); `test/javascript` covers only what the runner cannot: touch and pen input, cancelable public events, positioner options, nested layers, Turbo navigation and cache restore. → detail: Browser tests
R13. **Wait before asserting in browser.** Browser tests wait for elements and states before asserting, cover the critical flow of the component and test behavior rather than implementation details; every state assertion has a control that proves it can fail. → detail: Browser tests
R14. (dropped: host-only, cross-subdomain session flows belonged to the consuming application's authentication)
R15. **Green pipeline before push.** `bin/check` (plain suite, engine suite, the dev bench and dummy parity tests, RuboCop, bundler-audit, the gem gate) is green, and the change keeps the CI-only jobs green: `bin/test-js`, `bin/smoke --docs`, `bin/smoke --app`, `bundle exec rake test:tooling`, `rake llms:check`, YARD at 100%, `gem build` without warnings. No undocumented skipped tests. → detail: Pipeline
R16. **Public API is a snapshot test.** `test/public_api_test.rb` compares the public constants and methods with `test/fixtures/public_api.txt`; a deliberate API change runs `bundle exec rake public_api:update`, reviews the diff and adds a CHANGELOG entry in the same commit (`ruby-gem-conventions` R5). → detail: Suites
R17. **Engine and generator tests boot Rails in-process.** `rake test:engine` boots one minimal Rails application (`test/engine/engine_helper.rb`), no database, no fixtures; generator tests render into `tmp/generator-destination/` and assert files and messages; the plain suite (`rake test`) never loads Rails. → detail: Suites
R18. **No network, ever.** `test/test_helper.rb` fails any `Net::HTTP.start`; code that fetches (theme import) is tested through a scripted stand-in, and the smoke that needs the network (`bin/smoke --app`) is a separate CI job. → detail: Suites

## Dependencies
- minitest (`~> 6.0`, `Chadcn::TestCase` adds the `test "…" do` DSL and `assert_not_*` spellings)
- nokogiri (DOM assertions where a string include is not enough)
- Playwright of `dev/react-shadcn-catalog` and Node's `node:test` for `test/javascript` (nothing else is installed)

## Suites

| Command | Runs | Loads Rails | Needs |
|---|---|---|---|
| `bundle exec rake test` | `test/**/*_test.rb` except engine and generators: components, `Base`, theme, doctor, packaging, public API snapshot, llms drift, smoke registry | no | nothing |
| `bundle exec rake test:engine` | `test/engine/**`, `test/generators/**` | yes, one minimal app in-process | the `engine` Gemfile group |
| `bundle exec rake test:tooling` | `.claude/scripts/test/**` (audit receipt, epic board, gem gate) | no | a fake `gh` (`fake_gh.rb`) |
| `bin/test-js` | `test/javascript/*.test.mjs` in a real browser against the dummy app and the React catalog | the dummy app, in a server | Playwright, the dev servers (`servers.rb`) |
| `bin/smoke --plain` / `--docs` | the README's plain-Ruby fence; every ```ruby fence of README and docs/ | no | nothing |
| `bin/smoke --app` | `rails new`, the README quick start, HTTP checks, one browser scenario | yes, a generated app | network, Playwright |
| the dummy app's Minitest suite (`bin/check` runs it from `dev/dummy`) | the parity harness and the catalog of the dev kit | yes | the dummy bundle |
| `/shadcn-audit <names>` | the parity gates G1-G4 against the React oracle | the dummy app, in a server | the dev servers |

One file: `bundle exec ruby -Itest -Ilib test/chadcn/switch_test.rb` (or `-n /pattern/`); engine: `bundle exec rake test:engine TEST=test/engine/doctor_test.rb`; browser: start the servers and `node --test --test-reporter=spec test/javascript/popover.test.mjs` (`radix-stimulus` references/js-controller-tests.md). Run everything with `env -u BUNDLE_GEMFILE` and `LANG=en_US.UTF-8` when your shell exports something else.

## Component tests (`test/chadcn`)

```ruby
# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::SwitchTest < Chadcn::TestCase
  def render_switch(**props) = Chadcn::Switch.new(**props).call

  test "renders the unchecked default with thumb and bubble input" do
    html = render_switch

    assert_includes html, 'data-slot="switch"'
    assert_includes html, 'role="switch"'
    assert_includes html, 'aria-checked="false"'
  end

  test "accepts size as symbol or string" do
    assert_includes render_switch(size: :sm), 'data-size="sm"'
    assert_includes render_switch(size: "sm"), 'data-size="sm"'
  end
end
```

- Render with `.call` (plain Phlex, no Rails view context); compound trees render the root with a block.
- Assert the contract: `data-slot` per part, `data-variant`/`data-size`, `data-state`, ARIA, merged `class` (caller wins), `data`/`aria` deep-merge, `data-action` concatenation order, `as_child` merge.
- For compound roots, one test proves every generated DX helper renders the same HTML as the explicit class (`design-system` R4).
- Behavior (open/close, focus, keyboard) is not unit-tested in Ruby: it is a scenario or a browser test.

## Browser tests (`test/javascript`)

`harness.mjs` exports `browserTest(name, fn, { touch })` (one browser per process, a fresh context and page per test, page errors fail the test); `support.mjs` exports `openScenario`, `reconnectWithOptions` and `recordEvents`. A test opens a real parity page of the dummy app, drives it with Playwright and asserts `data-state`, ARIA and the focused element. Detail and conventions: `radix-stimulus` references/js-controller-tests.md. Mutate the controller once to confirm a new test goes red, then revert.

## Pipeline

`bin/check` is the local gate; CI (`.github/workflows/chadcn.yml`) runs the same steps in the `gem` matrix job (plain and engine suites, RuboCop, bundler-audit, YARD coverage, `gem build`, the gem gate, `bin/smoke --plain`), plus `clean-app` and `clean-app-variants` (`bin/smoke --app`), `js-tests` (`bin/test-js`), `docs` (`bin/smoke --docs`) and `tooling` (`rake test:tooling`). A gate that cannot run locally (no browser) is a reason to say so, never to skip it silently.

## Coverage Checklist

- [ ] Component: default render + variants/sizes/states + attrs passthrough + DX helpers
- [ ] `Base` change: merge tables and helper generator tests updated
- [ ] Controller: scenarios cover the state matrix; `test/javascript` covers what scenarios cannot
- [ ] Engine, generator, doctor: `rake test:engine` / `test/doctor` cover the new branch (success and failure)
- [ ] Public API change: `rake public_api:update` + CHANGELOG entry
- [ ] Docs example: renders under `bin/smoke --docs`
- [ ] Tooling script: a test in `.claude/scripts/test`
