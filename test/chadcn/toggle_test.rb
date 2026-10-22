# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::ToggleTest < Chadcn::TestCase
  def html(**opts)
    Chadcn::Toggle.new(**opts).call { |_| "Bold" }
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
    assert Nokogiri::HTML5.fragment(out).at_css("button").key?("disabled")
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
    classes = Chadcn::Toggle.variants(variant: :outline, size: :sm, class: "x").split

    assert_includes classes, "h-8"
    assert_includes classes, "x"
  end

  test "constant tables" do
    assert_equal %w[default outline], Chadcn::Toggle::VARIANTS.keys
    assert_equal %w[default sm lg], Chadcn::Toggle::SIZES.keys
  end

  test "unknown variant or size raises" do
    assert_raises(ArgumentError) { html(variant: :ghost) }
    assert_raises(ArgumentError) { html(size: :huge) }
    assert_raises(ArgumentError) { Chadcn::Toggle.variants(variant: :ghost) }
  end

  test "as_child renders the given tag with the toggle attributes" do
    out = html(as_child: :a, href: "/x")

    assert_includes out, "<a "
    assert_includes out, 'href="/x"'
    assert_includes out, 'data-slot="toggle"'
  end
end
