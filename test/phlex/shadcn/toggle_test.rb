# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::ToggleTest < Phlex::Shadcn::TestCase
  def html(**opts)
    Phlex::Shadcn::Toggle.new(**opts).call { |_| "Bold" }
  end

  test "renders defaults" do
    out = html

    assert_includes out, 'type="button"'
    assert_includes out, 'aria-pressed="false"'
    assert_includes out, 'data-state="off"'
    assert_includes out, 'data-slot="toggle"'
    assert_includes out, "h-9 min-w-9 px-2"
    assert_not_includes out, "data-disabled"
  end

  test "renders variants and sizes" do
    assert_includes html(variant: :outline), "border-input"
    assert_includes html(size: :sm), "h-8"
    assert_includes html(size: "lg"), "h-10"
  end

  test "pressed and disabled state" do
    out = html(default_pressed: true, disabled: true)

    assert_includes out, 'aria-pressed="true"'
    assert_includes out, 'data-state="on"'
    assert_includes out, 'data-disabled=""'
    assert_includes html(pressed: false, default_pressed: true), 'data-state="off"'
  end

  test "class merged last, attrs pass through, action appended" do
    out = html(class: "h-20", id: "x", type: "submit", data: { action: "click->a#b" })

    assert_includes out, "h-20"
    assert_not_includes out, "h-9"
    assert_includes out, 'id="x"'
    assert_includes out, 'type="submit"'
    assert_includes out, 'data-action="click->a#b click->shadcn--toggle#toggle"'
  end

  test "variants helper" do
    assert_includes Phlex::Shadcn::Toggle.variants(variant: :outline, size: :sm, class: "x"), "h-8"
  end
end
