# Lint and Test Examples

**For complete guidelines, see:**
- [copilot-instructions.md](/.github/copilot-instructions.md#-lint--code-quality-rubocop)
- [copilot-instructions.md](/.github/copilot-instructions.md#-testing-requirements)

This file provides concrete examples for common lint issues and test patterns.

## RuboCop: Common Lint Errors and Fixes

### 1. Line Length (Max 120 characters)

Wrong:
```ruby
# app/operations/articles/operation/create.rb
class Articles::Operation::Create < Core::Operation
  def self.validate_and_create_with_all_the_business_logic_for_articles_in_this_system
  end
end
```

Correct:
```ruby
# app/operations/articles/operation/create.rb
class Articles::Operation::Create < Core::Operation
  def self.validate_and_create_article
  end
end
```

Fix: Use shorter names, break into multiple methods.

---

### 2. Spacing: Around Operators

Wrong:
```ruby
@article=Article.find_by(slug:params[:slug])
params[:title]=="Featured"
article.published_at = Time.current
```

Correct:
```ruby
@article = Article.find_by(slug: params[:slug])
params[:title] == "Featured"
article.published_at = Time.current
```

Fix: `bin/rubocop --fix-layout` auto-fixes these.

---

### 3. String Quotes (Use Double Quotes)

Wrong:
```ruby
def welcome_message
  'Welcome to Papyro'
end

message = 'User: ' + @user.name
```

Correct:
```ruby
def welcome_message
  "Welcome to Papyro"
end

message = "User: #{@user.name}"
```

Fix: `bin/rubocop --fix-layout` auto-fixes these.

---

### 4. Method Names in snake_case

Wrong:
```ruby
def CreateArticle
  # code
end

def getArticleBySlug(slug)
  # code
end
```

Correct:
```ruby
def create_article
  # code
end

def article_by_slug(slug)
  # code
end
```

---

### 5. No Trailing Whitespace

Wrong:
```ruby
def hello
  puts "Hi"    # <- trailing spaces
end           # <- trailing spaces
```

Correct:
```ruby
def hello
  puts "Hi"
end
```

Fix: `bin/rubocop --fix-layout` auto-fixes these.

---

### 6. Proper Indentation (2 spaces)

Wrong:
```ruby
class Articles::Operation::Create < Core::Operation
    def call
        article = Article.new
            article.title = "Test"
    end
end
```

Correct:
```ruby
class Articles::Operation::Create < Core::Operation
  def call
    article = Article.new
    article.title = "Test"
  end
end
```

Fix: `bin/rubocop --fix-layout` auto-fixes these.

---

### 7. No Commented-Out Code

Wrong:
```ruby
def create_article
  # article = Article.new
  # article.title = params[:title]
  # article.save

  Articles::Operation::Create.new.call(params: params)
end
```

Correct:
```ruby
def create_article
  Articles::Operation::Create.new.call(params: params)
end
```

Fix: Delete commented code. Use git history if you need to see old code.

---

### 8. Block Parameter Formatting

Wrong:
```ruby
articles.map {|article| article.title }
articles.select { |a|a.published? }
```

Correct:
```ruby
articles.map { |article| article.title }
articles.select { |a| a.published? }
```

Fix: `bin/rubocop --fix-layout` auto-fixes these.

---

### 9. No Unnecessary Parentheses

Wrong:
```ruby
render("articles/show")
redirect_to(featured_articles_path)
```

Correct:
```ruby
render "articles/show"
redirect_to featured_articles_path
```

---

### 10. Hash Syntax (Use Modern Syntax)

Wrong:
```ruby
{ :title => "Article", :published => true }
```

Correct:
```ruby
{ title: "Article", published: true }
```

Fix: `bin/rubocop --fix-layout` auto-fixes these.

---

## Testing: Common Patterns and Examples

### 1. Unit Test: Contract Validation

```ruby
# test/concepts/articles/contract_test.rb
require "test_helper"

class Articles::ContractTest < ActiveSupport::TestCase
  def test_validates_title_presence
    result = Articles::Contract::Create.new.call({})

    assert !result.success?
    assert_includes result.errors.to_h[:title], "can't be blank"
  end

  def test_validates_title_minimum_length
    result = Articles::Contract::Create.new.call({ title: "Hi" })

    assert !result.success?
    assert_includes result.errors.to_h[:title], "is too short"
  end

  def test_allows_valid_article_data
    result = Articles::Contract::Create.new.call({ title: "Great Article Title" })

    assert result.success?
  end
end
```

### 2. Unit Test: Operation Logic

```ruby
# test/concepts/articles/operation_test.rb
require "test_helper"

class Articles::Operation::CreateTest < ActiveSupport::TestCase
  def test_creates_article_with_valid_data
    result = Articles::Operation::Create.new.call(
      params: { title: "New Article", body: "Content" }
    )

    assert result.success?
    assert_equal "New Article", result.value![:model].title
    assert_equal "Content", result.value![:model].body
    assert Article.exists?(result.value![:model].id)
  end

  def test_fails_with_invalid_data
    result = Articles::Operation::Create.new.call(
      params: { title: "" }
    )

    assert result.failure?
    assert_match /can't be blank/, result.failure[:errors][:title].first
  end
end
```

### 3. Integration Test: Controller to Operation

```ruby
# test/controllers/articles_controller_test.rb
require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  def test_show_renders_article_with_layout
    article = articles(:published)

    get article_path(article.slug)

    assert_response :success
    assert_select "h1", text: article.title
    assert_select "article .body", text: article.body
  end

  def test_show_returns_404_for_nonexistent_article
    get article_path("nonexistent-slug")

    assert_response :not_found
  end
end
```

### 4. System Test: Full User Workflow with JavaScript

```ruby
# test/system/articles_system_test.rb
require "application_system_test_case"

class ArticlesSystemTest < ApplicationSystemTestCase
  def test_user_can_view_featured_articles
    article1 = articles(:featured_1)
    article2 = articles(:featured_2)

    visit featured_articles_path

    assert_selector "turbo-frame#featured-articles"
    assert_text article1.title
    assert_text article2.title
  end

  def test_user_can_filter_articles_with_stimulus
    article = articles(:published)

    visit articles_path

    # Click filter button (triggered by Stimulus controller)
    click_button "Show Featured Only"

    # Stimulus controller dispatches Turbo request
    assert_selector "article[data-featured=true]"
    assert_no_selector "article[data-featured=false]"
  end

  def test_user_can_edit_article_in_admin
    sign_in_as users(:admin)
    article = articles(:unpublished)

    visit edit_admin_article_path(article)

    fill_in "Title", with: "Updated Title"
    click_button "Save"

    assert_text "Article updated successfully"
    assert_equal "Updated Title", article.reload.title
  end
end
```

### 5. Testing Best Practices

Use fixtures for test data:
```ruby
# test/fixtures/articles.yml
published:
  title: "Published Article"
  body: "Article content"
  published_at: <%= Time.current %>

unpublished:
  title: "Draft Article"
  body: "Draft content"
  published_at: nil

featured_1:
  title: "Featured Article 1"
  featured: true
```

Use proper assertions:
```ruby
# Good assertion structure
def test_article_creation
  article = Article.create!(title: "Test")

  assert_equal "Test", article.title
  assert article.persisted?
  assert_not_nil article.created_at
  assert_includes Article.all, article
end

# Bad: Using generic assert
def test_article_creation
  article = Article.create!(title: "Test")

  assert article
  assert article.title == "Test"
  assert article.created_at.present?
end
```

Test both success and failure:
```ruby
# Good: Test both paths
def test_operation_with_valid_and_invalid_data
  result = CreateArticle.call(params: { title: "Valid" })
  assert result.success?

  result = CreateArticle.call(params: { title: "" })
  assert result.failure?
end

# Bad: Only testing success
def test_operation_succeeds
  result = CreateArticle.call(params: { title: "Valid" })
  assert result.success?
end
```
