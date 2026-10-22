# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::CheckboxTest < Chadcn::TestCase
  def render_checkbox(**props)
    Chadcn::Checkbox.new(**props).call
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
    assert_includes html, 'data-action="click->x#y click->shadcn--checkbox#toggle'
  end

  test "controlled false stays unchecked and flags the controller as controlled" do
    html = render_checkbox(checked: false)

    assert_includes html, 'data-state="unchecked"'
    assert_includes html, 'data-shadcn--checkbox-controlled-value="true"'
    assert_includes render_checkbox, 'data-shadcn--checkbox-controlled-value="false"'
  end

  test "default_checked indeterminate renders mixed" do
    assert_includes render_checkbox(default_checked: "indeterminate"), 'aria-checked="mixed"'
  end

  test "form fields go to the hidden input" do
    html = render_checkbox(name: "terms", value: "yes", form: "signup", default_checked: true)

    assert_includes html, 'type="checkbox"'
    assert_includes html, 'name="terms"'
    assert_includes html, 'value="yes"'
    assert_includes html, 'form="signup"'
    assert Nokogiri::HTML5.fragment(html).at_css("input[type=checkbox]").key?("checked")
  end

  test "the form value defaults to on" do
    assert_includes render_checkbox, 'value="on"'
  end
end
