# Flash and Toast Test Examples

## Flash & Toast Notifications

### Integration Tests (Controller Flash)
Flash messages render as toasts in the layout. Test by asserting the toast container and message text:

```ruby
# test/controllers/articles_controller_test.rb
test "create action redirects with success flash" do
  post articles_path, params: { article: valid_params }
  
  assert_redirected_to article_path(@article)
  follow_redirect!
  
  # Toast renders as div[role=status] with the flash message
  assert_select "div[role=status]", /#{I18n.t("articles.operations.create.success")}/
end

test "create action with invalid data shows error flash" do
  post articles_path, params: { article: invalid_params }
  
  assert_response :unprocessable_entity
  
  # Error toast is destructive variant with alert message
  assert_select "div[role=status][class*='destructive']", /Error/
end
```

### Component Unit Tests
Test the Toast and Flash components in isolation:

```ruby
# test/components/shared/flash_test.rb
test "flash renders notice as success toast" do
  flash = { notice: "Article saved" }
  
  render_inline Components::Shared::Flash.new(flash: flash)
  
  assert_text "Success"
  assert_text "Article saved"
  assert_selector "[data-controller='toast']"
  assert_selector "[data-state='open']"
end

test "flash renders alert as destructive toast" do
  flash = { alert: "Error occurred" }
  
  render_inline Components::Shared::Flash.new(flash: flash)
  
  assert_text "Error"
  assert_text "Error occurred"
  assert_selector "[class*='destructive']"
end

test "toast auto-dismisses after duration" do
  render_inline Components::Ui::Toast.new do |toast|
    toast.description { "Test message" }
  end
  
  assert_selector "[data-toast-duration-value='4000']"
end
```

### System Tests (Full User Flow)
Verify toast visibility and behavior in rendered pages:

```ruby
# test/system/articles/create_article_flow_test.rb
test "user sees success toast after creating article" do
  visit new_article_path
  fill_in "Title", with: "New Article"
  fill_in "Excerpt", with: "Test excerpt"
  click_button "Create"
  
  assert_current_path article_path(@article)
  
  # Toast is visible and accessible
  assert_selector "[role='status'][aria-live='polite']", text: "Success"
end

test "toast closes when user clicks close button" do
  visit new_article_path
  fill_in "Title", with: "Test"
  click_button "Create"
  
  assert_selector "[role='status']", text: "Success"
  
  click_button I18n.t("app.toasts.close")
  
  assert_no_selector "[role='status']"
end
```

**Key Assertions for Toast Testing**:
- Use `div[role=status]` selector (not `p#notice`)
- Assert `aria-live="polite"` for accessibility
- Verify `[data-controller='toast']` for Stimulus wiring
- Check `[data-state='open']` for visibility state
- For destructive (error) toasts, assert `[class*='destructive']` variant
