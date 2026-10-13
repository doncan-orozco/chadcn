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

  test "unknown orientation yields no orientation classes and class merges last" do
    html = render_group(orientation: "x", class: "w-full", id: "g")

    assert_not_includes html, "rounded-l-none"
    assert_includes html, "w-full"
    assert_includes html, 'id="g"'
  end

  test "variants class helper" do
    assert_equal Phlex::Shadcn::ButtonGroup.variants, Phlex::Shadcn::ButtonGroup.variants(orientation: :horizontal)
  end

  test "text has no data-slot and supports as_child" do
    html = Phlex::Shadcn::ButtonGroup::Text.new(as_child: :label, for: "a").call { "t" }

    assert_includes html, "<label"
    assert_includes html, "bg-muted"
    assert_not_includes html, "data-slot"
  end

  test "separator defaults and helpers match explicit classes" do
    explicit = Phlex::Shadcn::ButtonGroup::Separator.new(class: "x").call
    html = render_group { |g| g.separator(class: "x") }

    assert_includes explicit, 'data-slot="button-group-separator"'
    assert_includes explicit, 'data-orientation="vertical"'
    assert_includes explicit, "bg-input"
    assert_not_includes explicit, "bg-border"
    assert_includes html, explicit

    text = Phlex::Shadcn::ButtonGroup::Text.new(class: "y").call { "t" }

    assert_includes render_group { |g| g.text(class: "y") { "t" } }, text
  end
end
