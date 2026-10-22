# System Testing with Playwright

## System Testing with Playwright

### Setup & Configuration
```ruby
# test/application_system_test_case.rb
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400], options: { 
    args: %w[headless] 
  }
  # Or use Playwright:
  # driven_by :playwright, using: :chromium, screen_size: [1400, 1400]
end
```

### Key Patterns

#### Element Discovery
Before interacting with elements, discover them using Playwright:

```ruby
# Take screenshot to inspect current state
page.save_screenshot("screenshot.png")

# Find elements using various selectors
page.find("button", text: "Submit")
page.find("[data-test-id='save-btn']")
page.find(".primary-action")

# Wait for elements to appear
page.find("h1", text: "Dashboard", visible: :all)
page.wait_for_selector(".spinner", timeout: 5000)

# Check element state
button = page.find("button", text: "Submit")
assert button.visible?
assert_not button.disabled?
```

#### Reconnaissance-Then-Action Pattern

For dynamic webapps, inspect first, then interact:

```ruby
# 1. Navigate and wait for JS to execute
page.visit articles_path
page.wait_for_load_state('networkidle')

# 2. Take screenshot or inspect DOM
page.save_screenshot("state.png")
content = page.content
buttons = page.locator("button").all

# 3. Identify selectors from rendered state
form = page.locator("form[data-controller='article-form']")
submit_btn = form.locator("button", text: "Submit")

# 4. Execute actions with discovered selectors
title_input = form.locator("input[name='article[title]']")
title_input.fill("My Article")
submit_btn.click

# 5. Wait for results
page.wait_for_selector(".alert-success", timeout: 5000)
assert page.find(".article-title", text: "My Article")
```

### Common Test Scenarios

#### Testing Forms with Validation
```ruby
def test_article_creation_with_validation
  visit articles_path
  click_link "New Article"
  
  # Verify form elements exist
  assert_text "Create Article"
  assert_selector "input[name='article[title]']"
  
  # Submit empty form
  click_button "Create"
  assert_text "Title can't be blank"
  
  # Fill and submit
  fill_in "article[title]", with: "Great Article"
  fill_in "article[content]", with: "Amazing content..."
  click_button "Create"
  
  # Verify redirect and content
  assert_current_path article_path(Article.last)
  assert_text "Article created successfully"
end
```

#### Testing Turbo Interactions
```ruby
def test_turbo_frame_update
  visit articles_path("sort=newest")
  
  # Wait for Turbo frame to load
  assert_selector "turbo-frame#articles-list"
  
  # Trigger Turbo action
  click_link "Sort by oldest"
  
  # Wait for frame update (Turbo handles this)
  assert_text "Article A" # Should appear in reversed order
  
  # Verify URL didn't change (frame update only)
  assert_current_path articles_path("sort=oldest")
end
```

#### Testing Real-time Features
```ruby
def test_article_broadcast_update
  # Open first browser window
  visit article_path(@article)
  
  # Open second browser window
  using_session("editor") do
    visit article_edit_path(@article)
    fill_in "article[title]", with: "Updated Title"
    click_button "Save"
  end
  
  # First browser receives broadcast
  assert_text "Updated Title"
end
```

#### Testing Stimulus Controllers
```ruby
def test_stimulus_form_validation
  visit articles_path("new")
  
  # Stimulus controller provides real-time validation
  fill_in "article[title]", with: "" # Empty
  assert_selector ".field-error" # Stimulus shows error
  
  fill_in "article[title]", with: "Valid Title"
  assert_no_selector ".field-error" # Stimulus clears error
end
```

### Best Practices

✅ **Do**:
- Wait for `networkidle` before interacting with dynamic elements
- Use semantic selectors: `text=`, `role=`, `data-test-id`
- Take screenshots for debugging
- Use `visible?` to check element visibility
- Test happy path + error cases
- Keep system tests focused on critical user flows

❌ **Don't**:
- Make assertions before waiting for elements to appear
- Use brittle nth-child or complex CSS selectors
- Test implementation details (test behavior, not code)
- Interact with elements before they're fully rendered
- Mix unit tests with integration tests

### Debugging & Inspection

```ruby
# Capture console logs during test
page.on_console_message { |msg| puts "JS: #{msg.text}" }

# Inspect page content
puts page.content
puts page.locator(".article-title").text_content

# Check for errors
network_errors = page.evaluate("window.__errors || []")
puts "Network errors: #{network_errors}"

# Inspect accessibility tree
accessibility = page.evaluate("document.body.outerHTML")
puts accessibility
```

### Performance Considerations

```ruby
# For tests that interact with heavy JS frameworks:
page.set_default_timeout(10000)

# Optimize by reducing screenshot captures
# Take selective screenshots only when needed for debugging

# Use headless mode in CI for speed
ENV['HEADLESS'] = true if ENV['CI']
```

## Playwright Automation (Advanced)

For complex end-to-end testing workflows, use Playwright directly:

```python
# test/support/playwright_automation.py (optional)
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    
    # Navigate and wait
    page.goto("http://localhost:3000/articles")
    page.wait_for_load_state('networkidle')
    
    # Interact
    page.locator("button", text="Create").click()
    page.wait_for_url("**/articles/new")
    
    # Assert
    assert page.locator("h1").text_content() == "Create Article"
    
    browser.close()
```
