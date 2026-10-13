# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::CheckboxTest < Phlex::Shadcn::TestCase
  def render_checkbox(**props)
    Phlex::Shadcn::Checkbox.new(**props).call
  end

  test "renders the unchecked default without indicator" do
    html = render_checkbox

    assert_includes html, 'data-slot="checkbox"'
    assert_includes html, 'role="checkbox"'
    assert_includes html, 'aria-checked="false"'
    assert_includes html, 'data-state="unchecked"'
    assert_not_includes html, "</span></button>"
    assert_includes html, "></button>"
  end

  test "checked renders the indicator and indeterminate maps to mixed" do
    html = render_checkbox(default_checked: true)

    assert_includes html, 'data-slot="checkbox-indicator"'
    assert_includes html, "lucide-check"

    mixed = render_checkbox(checked: :indeterminate)

    assert_includes mixed, 'aria-checked="mixed"'
    assert_includes mixed, 'data-state="indeterminate"'
  end

  test "rejects invalid state" do
    assert_raises(ArgumentError) { render_checkbox(checked: "maybe") }
  end

  test "disabled, required and passthrough attrs" do
    html = render_checkbox(disabled: true, required: true, class: "bg-red-500", id: "c1", name: "terms",
                           data: { action: "click->x#y" }, aria: { invalid: true })

    assert_includes html, 'data-disabled=""'
    assert_includes html, 'aria-required="true"'
    assert_includes html, 'aria-invalid="true"'
    assert_includes html, "bg-red-500"
    assert_includes html, 'id="c1"'
    assert_includes html, 'name="terms"'
    assert_includes html, 'data-action="click->x#y click->v2--checkbox#toggle'
  end
end
