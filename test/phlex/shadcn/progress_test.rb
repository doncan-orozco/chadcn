# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::ProgressTest < Phlex::Shadcn::TestCase
  def html(**) = Phlex::Shadcn::Progress.new(**).call

  test "renders the indeterminate progressbar" do
    out = html(value: 13)

    assert_includes out, 'role="progressbar"'
    assert_includes out, 'data-slot="progress"'
    assert_includes out, 'data-slot="progress-indicator"'
    assert_includes out, 'data-state="indeterminate"'
    assert_includes out, 'aria-valuemax="100"'
    assert_includes out, "translateX(-87%)"
    assert_not_includes out, "aria-valuenow"
  end

  test "value edge cases" do
    assert_includes html, "translateX(-100%)"
    assert_includes html(value: 100), "translateX(-0%)"
    assert_includes html(value: 33.3), "translateX(-66.7%)"
    assert_not_includes html(value: 150), "style="
  end

  test "max only counts when a positive number" do
    assert_includes html(max: 50.0), 'aria-valuemax="50"'
    assert_includes html(max: "50"), 'aria-valuemax="100"'
    assert_includes html(max: 0), 'data-max="100"'
  end

  test "class merged last and attrs pass through" do
    out = html(class: "h-4", id: "p", data: { foo: "1" })

    assert_includes out, "h-4"
    assert_not_includes out, "h-2"
    assert_includes out, 'id="p"'
    assert_includes out, 'data-foo="1"'
  end
end
