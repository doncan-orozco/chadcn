# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::SelectTest < Chadcn::TestCase
  include Chadcn::FormSupport

  Part = Chadcn::Form::Field::Select

  def body
    proc do |select|
      select.trigger { select.value(placeholder: "Pick") }
      select.content do
        select.item(value: "a") { "A" }
        select.item(value: "b") { "B" }
      end
    end
  end

  def render_select(errors: {}, object: { email: "b" }, **) = render_part(Part, errors:, object:, **, &body)

  test "binds name, default value and the field id and aria on the trigger" do
    html = doc(render_select)
    trigger = html.at_css("button[data-slot=select-trigger]")

    assert_equal "user_email-form-item", trigger["id"]
    assert_equal "false", trigger["aria-invalid"]
    assert_equal "user_email-form-item-description", trigger["aria-describedby"]
    assert_equal "b", trigger["data-chadcn--select-value-value"]
    assert_equal "false", trigger["data-chadcn--select-controlled-value-value"]
    assert_equal "user[email]", trigger["data-chadcn--select-name-value"]
    assert_equal "user[email]", html.at_css("select")["name"]
  end

  test "errors mark the trigger invalid and list both describedby ids" do
    trigger = doc(render_select(errors: { email: [ "x" ] })).at_css("button")

    assert_equal "true", trigger["aria-invalid"]
    assert_equal "user_email-form-item-description user_email-form-item-message", trigger["aria-describedby"]
  end

  test "a nil value leaves the placeholder and a Symbol or Integer value is stringified" do
    assert_equal "", doc(render_select(object: { email: nil })).at_css("button")["data-placeholder"]
    assert_equal "a", doc(render_select(object: { email: :a })).at_css("button")["data-chadcn--select-value-value"]
    assert_equal "3", doc(render_select(object: { email: 3 })).at_css("button")["data-chadcn--select-value-value"]
  end

  test "caller kwargs reach the select root and the caller wins" do
    html = doc(render_select(name: "custom", disabled: true, required: true, form: "f1", default_value: "a"))
    trigger = html.at_css("button")

    assert_equal "custom", html.at_css("select")["name"]
    assert_equal "f1", html.at_css("select")["form"]
    assert_equal "a", trigger["data-chadcn--select-value-value"]
    assert_equal "true", trigger["aria-required"]
    assert trigger.key?("disabled")
  end

  test "attributes given to select.trigger win over the bound ones" do
    out = render_part(Part) { |select| select.trigger(id: "mine", aria: { invalid: "maybe" }) { select.value } }
    trigger = doc(out).at_css("button")

    assert_equal "mine", trigger["id"]
    assert_equal "maybe", trigger["aria-invalid"]
    assert_equal "user_email-form-item-description", trigger["aria-describedby"]
  end

  test "a value the select cannot express raises with the attribute" do
    [ [ "a" ], { a: 1 } ].each do |value|
      error = assert_raises(ArgumentError) { render_select(object: { email: value }) }

      assert_includes error.message, "Chadcn::Form::Field::Select"
      assert_includes error.message, ":email"
      assert_includes error.message, value.class.name
    end
  end

  test "the helper renders the same HTML as the explicit part" do
    helper = field_for(object: { email: "b" }).call { |field| field.select(&body) }

    assert_equal render_select, helper
  end
end
