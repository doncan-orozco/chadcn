# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::ButtonTest < Phlex::Shadcn::TestCase
  def html(**opts)
    Phlex::Shadcn::Button.new(**opts).call { |_| "Go" }
  end

  test "renders defaults" do
    out = html

    assert_includes out, 'data-slot="button"'
    assert_includes out, 'data-variant="default"'
    assert_includes out, 'data-size="default"'
    assert_not_includes out, "type="
  end

  test "renders every variant and size, normalizing underscores" do
    Phlex::Shadcn::Button::VARIANTS.each_key { |v| assert_includes html(variant: v), %(data-variant="#{v}") }
    Phlex::Shadcn::Button::SIZES.each_key { |s| assert_includes html(size: s), %(data-size="#{s}") }
    assert_includes html(size: :icon_sm), 'data-size="icon-sm"'
  end

  test "class is merged last and attrs pass through" do
    out = html(class: "rounded-full", id: "x", disabled: true, data: { foo: "1" })

    assert_includes out, "rounded-full"
    assert_not_includes out, "rounded-md"
    assert_includes out, 'id="x"'
    assert_includes out, 'data-foo="1"'
    assert Nokogiri::HTML5.fragment(out).at_css("button").key?("disabled")
  end

  test "unknown options raise" do
    assert_raises(ArgumentError) { html(variant: :nope) }
  end

  test "as_child tag" do
    out = html(as_child: :a, href: "/x")

    assert_match(/<a /, out)
    assert_includes out, 'href="/x"'
  end

  test "variants class method" do
    classes = Phlex::Shadcn::Button.variants(variant: :outline, size: :sm, class: "x").split

    assert_includes classes, "bg-background"
    assert_includes classes, "h-8"
    assert_includes classes, "x"
  end

  test "variants raises on unknown options and defaults nil" do
    assert_raises(ArgumentError) { Phlex::Shadcn::Button.variants(variant: :nope) }
    assert_raises(ArgumentError) { Phlex::Shadcn::Button.variants(size: :huge) }
    assert_equal Phlex::Shadcn::Button.variants, Phlex::Shadcn::Button.variants(variant: nil, size: nil)
  end

  test "unknown size raises and the message lists the allowed values" do
    error = assert_raises(ArgumentError) { html(size: :huge) }

    assert_includes error.message, "unknown size"
    assert_includes error.message, "icon-lg"
  end

  test "as_child merges the button props into a component instance" do
    out = html(as_child: Phlex::Shadcn::Label.new(html_for: "x"), variant: :ghost)

    assert_includes out, "<label"
    assert_includes out, 'for="x"'
    assert_includes out, 'data-variant="ghost"'
  end
end
