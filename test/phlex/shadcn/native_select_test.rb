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
    assert_equal 1, html(value: "a", default_value: "b").scan("selected").size
    assert_includes html(value: "a"), 'value="a" selected'
  end

  test "helpers render the same as explicit classes" do
    helper = NS.new.call { |s| s.option(value: "a") { "A" } }
    explicit = NS.new.call { |s| s.render NS::Option.new(value: "a") { "A" } }
    grouped = NS.new.call { |s| s.opt_group(label: "G") { "x" } }

    assert_equal explicit, helper
    assert_includes grouped, '<optgroup class="bg-[Canvas] text-[CanvasText]" data-slot="native-select-optgroup" label="G">'
  end
end
