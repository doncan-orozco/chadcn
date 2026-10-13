# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::SeparatorTest < Phlex::Shadcn::TestCase
  def html(**) = Phlex::Shadcn::Separator.new(**).call

  test "decorative horizontal by default" do
    out = html

    assert_includes out, "<div"
    assert_includes out, 'data-slot="separator"'
    assert_includes out, 'data-orientation="horizontal"'
    assert_includes out, 'role="none"'
    assert_not_includes out, "aria-orientation"
  end

  test "non decorative vertical" do
    out = html(orientation: :vertical, decorative: false)

    assert_includes out, 'role="separator"'
    assert_includes out, 'aria-orientation="vertical"'
  end

  test "non decorative horizontal omits aria-orientation" do
    out = html(decorative: false)

    assert_includes out, 'role="separator"'
    assert_not_includes out, "aria-orientation"
  end

  test "invalid orientation falls back" do
    assert_includes html(orientation: "diagonal"), 'data-orientation="horizontal"'
  end

  test "class merged last and attrs win" do
    out = html(class: "bg-red-500", role: "presentation", data: { slot: "x" })

    assert_includes out, "bg-red-500"
    assert_not_includes out, "bg-border"
    assert_includes out, 'role="presentation"'
    assert_includes out, 'data-slot="x"'
  end

  test "as_child tag" do
    assert_includes html(as_child: :span), "<span"
  end
end
