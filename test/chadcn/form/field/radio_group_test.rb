# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::RadioGroupTest < Chadcn::TestCase
  include Chadcn::FormSupport

  Part = Chadcn::Form::Field::RadioGroup

  def body
    proc do |group|
      group.item(value: "a", id: "x-a")
      group.item(value: "b", id: "x-b")
    end
  end

  def render_group(errors: {}, object: { email: "b" }, **) = render_part(Part, errors:, object:, **, &body)

  test "binds the group id, aria, name and checked item" do
    html = doc(render_group)
    group = html.at_css("[data-slot=radio-group]")

    assert_equal "user_email-form-item", group["id"]
    assert_equal "false", group["aria-invalid"]
    assert_equal "user_email-form-item-description", group["aria-describedby"]
    assert_equal "radiogroup", group["role"]
    assert_equal "checked", html.at_css("#x-b")["data-state"]
    assert_equal "unchecked", html.at_css("#x-a")["data-state"]
    assert_equal "user[email]", html.at_css("input[type=radio], input[name]")["name"]
  end

  test "errors mark the group invalid" do
    group = doc(render_group(errors: { email: [ "x" ] })).at_css("[data-slot=radio-group]")

    assert_equal "true", group["aria-invalid"]
    assert_equal "user_email-form-item-description user_email-form-item-message", group["aria-describedby"]
  end

  test "a Symbol or Integer value is stringified, nil checks nothing" do
    assert_equal "checked", doc(render_group(object: { email: :a })).at_css("#x-a")["data-state"]
    assert_empty doc(render_group(object: { email: nil })).css("[data-state=checked]")
  end

  test "caller attrs win" do
    group = doc(render_group(id: "mine", name: "custom", disabled: true, orientation: "horizontal")).at_css("[data-slot=radio-group]")

    assert_equal "mine", group["id"]
    assert_equal "horizontal", group["aria-orientation"]
    assert group.key?("data-disabled")
  end

  test "a value the group cannot express raises with the attribute" do
    [ [ "a" ], { a: 1 } ].each do |value|
      error = assert_raises(ArgumentError) { render_group(object: { email: value }) }

      assert_includes error.message, "Chadcn::Form::Field::RadioGroup"
      assert_includes error.message, ":email"
    end
  end

  test "the helper renders the same HTML as the explicit part" do
    assert_equal(render_group, field_for(object: { email: "b" }).call { |field| field.radio_group(&body) })
  end
end
