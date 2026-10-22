# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::SwitchTest < Chadcn::TestCase
  def render_switch(**props)
    Chadcn::Switch.new(**props).call
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
    assert_includes html, 'data-action="click->x#y click->chadcn--switch#toggle"'
  end

  test "stringifies boolean aria values" do
    assert_includes render_switch(aria: { invalid: true }), 'aria-invalid="true"'
  end

  test "controlled state, name, value, form and required reach the bubble input" do
    html = render_switch(checked: true, default_checked: false, name: "n", value: "yes", form: "f1", required: true)
    input = Nokogiri::HTML5.fragment(html).at_css("input")

    assert_includes html, 'data-chadcn--switch-controlled-value="true"'
    assert_includes html, 'aria-required="true"'
    assert_equal %w[n yes f1], [ input["name"], input["value"], input["form"] ]
    assert input.key?("checked")
    assert input.key?("required")
  end
end
