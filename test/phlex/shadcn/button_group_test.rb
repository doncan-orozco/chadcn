# frozen_string_literal: true

require "phlex/test_case"

class ButtonGroupTest < Phlex::Shadcn::TestCase
  def render_group(**attrs, &)
    Phlex::Shadcn::ButtonGroup.new(**attrs).call(&)
  end

  test "renders group without data-orientation by default" do
    html = render_group { |g| g.text { "x" } }

    assert_includes html, 'role="group"'
    assert_includes html, 'data-slot="button-group"'
    assert_not_includes html, "data-orientation"
    assert_includes html, "[&>*:not(:first-child)]:rounded-l-none"
  end

  test "vertical orientation as string or symbol" do
    [ "vertical", :vertical ].each do |o|
      html = render_group(orientation: o)

      assert_includes html, 'data-orientation="vertical"'
      assert_includes html, "flex-col"
    end
  end

  test "unknown orientation is emitted verbatim with no orientation classes" do
    html = render_group(orientation: "x")

    assert_includes html, 'data-orientation="x"'
    assert_not_includes html, "rounded-l-none"
  end

  test "caller class overrides a conflicting base class and attrs reach the root" do
    html = render_group(class: "w-full", id: "g")
    classes = Nokogiri::HTML5.fragment(html).at_css("[data-slot=button-group]")["class"].split

    assert_includes classes, "w-full"
    assert_not_includes classes, "w-fit"
    assert_includes html, 'id="g"'
  end

  test "variants class helper" do
    assert_equal Phlex::Shadcn::ButtonGroup.variants, Phlex::Shadcn::ButtonGroup.variants(orientation: :horizontal)
    assert_equal Phlex::Shadcn::ButtonGroup.variants, Phlex::Shadcn::ButtonGroup.variants(orientation: nil)
  end

  test "text has no data-slot and supports as_child" do
    html = Phlex::Shadcn::ButtonGroup::Text.new(as_child: :label, for: "a").call { "t" }

    assert_includes html, "<label"
    assert_includes html, "bg-muted"
    assert_not_includes html, "data-slot"
  end

  test "separator defaults to a vertical input-colored rule" do
    explicit = Phlex::Shadcn::ButtonGroup::Separator.new(class: "x").call

    assert_includes explicit, 'data-slot="button-group-separator"'
    assert_includes explicit, 'data-orientation="vertical"'
    assert_includes explicit, "bg-input"
    assert_not_includes explicit, "bg-border"
  end

  test "the separator helper renders the same HTML as the explicit class" do
    explicit = Phlex::Shadcn::ButtonGroup::Separator.new(class: "x").call

    assert_includes render_group { |g| g.separator(class: "x") }, explicit
  end

  test "the text helper renders the same HTML as the explicit class" do
    text = Phlex::Shadcn::ButtonGroup::Text.new(class: "y").call { "t" }

    assert_includes render_group { |g| g.text(class: "y") { "t" } }, text
  end

  test "variants class helper merges extra classes and tolerates unknown orientations" do
    assert_includes Phlex::Shadcn::ButtonGroup.variants(orientation: :vertical, class: "w-full"), "w-full"
    assert_not_includes Phlex::Shadcn::ButtonGroup.variants(orientation: "x"), "rounded-l-none"
  end

  test "separator accepts a horizontal orientation" do
    html = Phlex::Shadcn::ButtonGroup::Separator.new(orientation: "horizontal").call

    assert_includes html, 'data-orientation="horizontal"'
  end
end
