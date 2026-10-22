# Hotwire System Tests

## Repository Patterns

- Base class: `test/application_system_test_case.rb`
- Driver: Selenium headless Chrome
- Existing test helper for sessions lives in `test/test_helpers/session_test_helper.rb`, but Selenium system tests need a browser cookie helper in the system test base.

## Async Rules

- Never add `sleep`.
- Wait using UI state changes:
  - `assert_current_path edit_studio_article_path(article)`
  - `assert_selector :testid, "autosave-status", text: "Saving..."`
  - `assert_selector :testid, "autosave-status", text: /Saved at/`
- Do not assert `article.reload` state until one of those UI waits has completed.

## Selector Rules

- Use labels and button text for ordinary form interactions.
- Use `:testid` (not raw CSS attribute strings) for:
  - create-draft triggers
  - autosave status elements
  - editor fields or surfaces that are custom-rendered
- `Capybara.test_id = "data-testid"` is set in `test/application_system_test_case.rb`, which enables standard finders to match by `data-testid`. A custom `Capybara.add_selector(:testid)` call in the same file is also required to enable the `:testid` selector type — `test_id=` alone does not register it in Capybara 3.x.

## State Setup

- Prefer fixtures plus direct model creation.
- Sign in via the system test base helper rather than clicking through the login page when authentication is not the subject of the test.

## First Article Flow Pattern

1. Sign in as `users(:admin)`.
2. Visit `studio_articles_path`.
3. Click the New Article trigger.
4. Assert redirect to the edit route.
5. Fill in editor fields.
6. Assert autosave status transitions in the UI.
7. Assert persisted article state after the final UI confirmation.