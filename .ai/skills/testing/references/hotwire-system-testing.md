# Hotwire System Testing (Capybara)

> Merged from the former `system-testing` skill.

# System Testing (Rails + Capybara + Selenium)

Use this skill for browser-level tests that exercise critical user flows end to end.

## Non-Negotiable Rules

- Never use `sleep` in a system test.
- Let Capybara wait implicitly through semantic UI assertions (`assert_text`, `assert_selector`, `assert_current_path`).
- Assert async UI completion before asserting database state.
- Prefer backend state setup over driving long prerequisite flows through the browser.
- Use `data-testid` hooks for critical or asynchronous UI elements whose structure or text may drift. Do NOT attach `data-testid` to every element — only containers, dynamic state, and unlabeled async surfaces.
- Do not test validation matrices in system tests; cover one visible UI error path and keep detailed validation coverage in contract/operation tests.
- For cross-subdomain auth/session behavior, prefer at least one real browser navigation flow across host and studio domains; host-switch integration tricks alone are not sufficient to prove cookie-scope behavior.

## Capybara `test_id` Configuration

In `test/application_system_test_case.rb` we configure two things:

1. `Capybara.test_id = "data-testid"` — makes standard finders also match by `data-testid`.
2. A custom `:testid` selector registered with `Capybara.add_selector` — this is what enables the clean API below.

> **Note:** `Capybara.test_id=` alone does NOT register a `:testid` selector type in Capybara 3.x. The `add_selector` call is required.

```ruby
# test/application_system_test_case.rb
Capybara.test_id = "data-testid"
Capybara.add_selector(:testid) do
  css { |value| "[data-testid='#{value}']" }
end
```

This unlocks the `:testid` strategy everywhere:

```ruby
# Find
find(:testid, "autosave-status")

# Assert presence / text
assert_selector :testid, "autosave-status", text: "Saving..."
```

Never write raw CSS attribute selectors (`"[data-testid='...']"`) when `:testid` is available.

## Practical Workflow

1. Set up exact state in Ruby first.
2. Authenticate with the system-test session helper instead of exercising login unless login itself is the behavior under test.
3. Visit the narrowest page that owns the user flow.
4. Interact through labels, buttons, and links first; fall back to `:testid` for async or structurally unstable elements.
5. After a Turbo or Stimulus action, wait on a visible UI signal.
6. Only then assert persisted state.

## Preferred Selector Order

1. Label text (`fill_in "Title"`)
2. Button or link text (`click_button "Save"`)
3. Stable test hooks (`find(:testid, "autosave-status")`)

## When to Add `data-testid`

- **DO**: Autosave status badge, create-draft trigger, any container whose content changes asynchronously.
- **DO NOT**: Buttons with readable text (`click_button "Publish"` is better), standard labelled inputs (`fill_in "Title"`).

## Anti-Patterns

- `sleep 1`
- `find('div:nth-child(3) > button').click`
- `find("[data-testid='foo']")` — use `:testid` instead when `Capybara.test_id` is configured
- database assertions immediately after async UI actions
- broad browser coverage for every backend validation rule
- manual JavaScript triggering when Capybara interaction methods can express the intent

## Reference Map

- **[references/hotwire-system-tests.md](hotwire-system-tests-examples.md)**
  Use for repo-specific guidance on Selenium auth, Turbo/Stimulus waits, and the create-article flow pattern.
