# Lint and Test Examples

Quick reference for common RuboCop offenses in this gem and the shape of its Minitest files. The rules themselves are the
Quick Rules of `linting` and `testing`.

## RuboCop: Common Lint Errors and Fixes

### 1. Line Length (Max 160 characters, verbatim class strings exempt)

```ruby
# Offense: prose or code wrapped past 160 chars
def initialize(variant: "default", size: "default", as_child: false, show_close_button: true, class: nil, data: {}, aria: {}, **attrs); end

# Fix: break the signature, one kwarg per line
def initialize(variant: "default", size: "default", as_child: false, show_close_button: true,
               class: nil, data: {}, aria: {}, **attrs)
end
```

A shadcn class string copied verbatim from the oracle is allowed to exceed the limit (`AllowedPatterns` in `.rubocop.yml`);
splitting it changes nothing for Tailwind but makes the G1 static gate harder to read, so leave it on one line.

### 2. String Quotes (Use Double Quotes)

```ruby
# Offense
variant = 'outline'

# Fix
variant = "outline"
```

### 3. Frozen String Literal

Every Ruby file starts with `# frozen_string_literal: true` (gem files, tests, scripts, rake tasks).

### 4. Spaces Inside Array Brackets

```ruby
# Offense
SIZES = %w[default sm lg icon]   # fine: %w literal
parts = [Header, Footer]         # offense: Layout/SpaceInsideArrayLiteralBrackets (EnforcedStyle: space)

# Fix
parts = [ Header, Footer ]
```

### 5. Guard Clauses

```ruby
# Offense: nested conditionals
def render_as_child(child, **slot_attrs, &block)
  if child
    if child.is_a?(Chadcn::Base)
      ...
    end
  end
end

# Fix
def render_as_child(child, **slot_attrs, &block)
  return unless child
  return render_tag(child, **slot_attrs, &block) unless child.is_a?(Chadcn::Base)

  ...
end
```

### 6. Performance Cops

```ruby
# Offense: Performance/MapCompact
names = parts.map { |part| part.slot }.compact

# Fix
names = parts.filter_map(&:slot)
```

### 7. No Commented-Out Code, No Trailing Whitespace

Delete dead code; explain non-obvious Radix behavior with a comment that points at the spec section instead.

### 8. Hash Syntax (Modern)

```ruby
# Offense
data: { :state => "open" }

# Fix
data: { state: "open" }
```

## Testing: Common Patterns and Examples

### 1. Component Unit Test (plain suite, `bundle exec rake test`)

```ruby
# test/chadcn/badge_test.rb
# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::BadgeTest < Chadcn::TestCase
  def render_badge(**props, &block)
    Chadcn::Badge.new(**props).call(&block)
  end

  test "renders the default variant with data-slot" do
    html = render_badge { "New" }

    assert_includes html, 'data-slot="badge"'
    assert_includes html, 'data-variant="default"'
    assert_includes html, "New"
  end

  test "accepts the variant as string or symbol" do
    assert_includes render_badge(variant: :outline), 'data-variant="outline"'
    assert_includes render_badge(variant: "outline"), 'data-variant="outline"'
  end

  test "merges class and passes attrs through" do
    html = render_badge(class: "mt-2", id: "b1", data: { testid: "badge" })

    assert_includes html, "mt-2"
    assert_includes html, 'id="b1"'
    assert_includes html, 'data-testid="badge"'
  end
end
```

### 2. Minitest Cops: Clear Assertions

```ruby
# Offense: Minitest/AssertTruthy, Minitest/AssertIncludes
assert html.include?("data-slot")
assert_equal true, component.disabled?

# Fix
assert_includes html, "data-slot"
assert_predicate component, :disabled?
```

### 3. Engine and Generator Tests (`bundle exec rake test:engine`)

```ruby
# test/engine/importmap_test.rb
# frozen_string_literal: true

require_relative "engine_helper"

class EngineTest::Importmap < Minitest::Test
  def app = EngineTest::Application

  test "pins the controllers under controllers/chadcn" do
    assert_includes app.importmap.packages.keys, "controllers/chadcn/dialog_controller"
  end
end
```

The engine suite boots one minimal Rails application in-process (`test/engine/engine_helper.rb`); it has no database and no
fixtures. Generator tests render into a per-process temporary destination under `Dir.tmpdir`.

### 4. Testing Best Practices

```ruby
# Good: test both paths
test "raises on an unknown variant" do
  assert_raises(ArgumentError) { Chadcn::Button.new(variant: "huge") }
end

test "renders a known variant" do
  assert_includes Chadcn::Button.new(variant: "ghost").call, 'data-variant="ghost"'
end
```

- One concern per test, named after the behavior (`test "returns focus to the trigger on close"`).
- Assert the rendered contract (`data-slot`, `role`, `aria-*`, `data-state`, the merged `class`), not private methods.
- No snapshots of whole HTML strings: they break on every oracle update and prove nothing the G1 gate does not already prove.
- No network: `test/test_helper.rb` turns every `Net::HTTP.start` into a failure; stub what you need (see `test/chadcn/theme_import_test.rb`).
