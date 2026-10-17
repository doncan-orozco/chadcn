# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::NativeSelectTest < Phlex::Shadcn::TestCase
  NS = Phlex::Shadcn::NativeSelect

  def html(**opts)
    NS.new(**opts).call do |s|
      s.opt_group(label: "G") { s.option(value: "a") { "A" } }
      s.option(value: "b") { "B" }
    end
  end

  test "renders wrapper, select, icon and parts with slots" do
    out = html(size: :sm, class: "rounded-full", id: "x", aria: { invalid: true })

    %w[native-select-wrapper native-select native-select-icon native-select-option native-select-optgroup].each do |slot|
      assert_includes out, %(data-slot="#{slot}")
    end
    assert_includes out, 'data-size="sm"'
    assert_includes out, "rounded-full"
    assert_not_includes out, "rounded-md"
    assert_includes out, 'aria-invalid="true"'
  end

  test "value marks the matching option selected" do
    assert_includes html(default_value: "b"), 'value="b" selected'
    both = html(value: "a", default_value: "b")

    assert_includes both, 'value="a" selected'
    assert_not_includes both, 'value="b" selected'
    assert_includes html(value: "a"), 'value="a" selected'
  end

  test "the option and opt_group helpers render the same as the explicit classes" do
    helper = NS.new.call { |s| s.option(value: "a") { "A" } }
    explicit = NS.new.call { |s| s.render NS::Option.new(value: "a") { "A" } }
    grouped = NS.new.call { |s| s.opt_group(label: "G") { "x" } }
    grouped_explicit = NS.new.call { |s| s.render NS::OptGroup.new(label: "G") { "x" } }

    assert_equal explicit, helper
    assert_equal grouped_explicit, grouped
  end

  test "explicit selected on an option wins and the first match only is selected in single mode" do
    out = NS.new(default_value: "a").call do |s|
      s.option(value: "a", selected: false) { "A" }
      s.option(value: "a") { "A2" }
      s.option(value: "a") { "A3" }
    end

    assert_equal 1, out.scan(" selected").size
    assert_includes out, ">A2</option>"
  end

  test "multiple marks every matching option" do
    out = NS.new(default_value: %w[a b], multiple: true).call do |s|
      s.option(value: "a") { "A" }
      s.option(value: "b") { "B" }
    end

    assert_equal 2, out.scan(" selected").size
  end

  test "size defaults to default" do
    assert_includes html, 'data-size="default"'
  end
end
