# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::SwitchTest < Phlex::Shadcn::TestCase
  def render_switch(**props)
    Phlex::Shadcn::Switch.new(**props).call
  end

  test "renders the unchecked default with thumb and bubble input" do
    html = render_switch

    assert_includes html, 'data-slot="switch"'
    assert_includes html, 'data-slot="switch-thumb"'
    assert_includes html, 'role="switch"'
    assert_includes html, 'aria-checked="false"'
    assert_includes html, 'data-size="default"'
    assert_includes html, 'type="checkbox"'
  end

  test "accepts size as symbol or string" do
    assert_includes render_switch(size: :sm), 'data-size="sm"'
    assert_includes render_switch(size: "sm"), 'data-size="sm"'
  end

  test "checked and disabled state" do
    html = render_switch(default_checked: true, disabled: true)

    assert_includes html, 'aria-checked="true"'
    assert_includes html, 'data-state="checked"'
    assert_includes html, 'data-disabled=""'
  end

  test "merges class and passes attrs through, caller action runs before the toggle" do
    html = render_switch(class: "bg-red-500", id: "s1", aria: { label: "Mode" }, data: { action: "click->x#y" })

    assert_includes html, "bg-red-500"
    assert_includes html, 'id="s1"'
    assert_includes html, 'aria-label="Mode"'
    assert_includes html, 'data-action="click->x#y click->v2--switch#toggle"'
  end

  test "stringifies boolean aria values" do
    assert_includes render_switch(aria: { invalid: true }), 'aria-invalid="true"'
  end
end
