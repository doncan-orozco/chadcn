# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::CheckboxTest < Chadcn::TestCase
  include Chadcn::FormSupport

  Part = Chadcn::Form::Field::Checkbox

  def render_box(errors: {}, object: { email: true }, **) = render_part(Part, errors:, object:, **)

  test "renders the hidden unchecked input before a bound checkbox" do
    html = doc(render_box)
    hidden = html.at_css("input[type=hidden]")
    button = html.at_css("button[data-slot=checkbox]")

    assert_equal "user[email]", hidden["name"]
    assert_equal "0", hidden["value"]
    assert_equal "off", hidden["autocomplete"]
    assert_nil hidden["id"]
    assert_equal "user_email-form-item", button["id"]
    assert_equal "1", button["value"]
    assert_equal "checked", button["data-state"]
    assert_equal "false", button["aria-invalid"]
    assert_equal "user_email-form-item-description", button["aria-describedby"]
    assert_same hidden, html.css("input[type=hidden], button").first
  end

  test "errors mark the button invalid" do
    button = doc(render_box(errors: { email: [ "x" ] })).at_css("button")

    assert_equal "true", button["aria-invalid"]
    assert_equal "user_email-form-item-description user_email-form-item-message", button["aria-describedby"]
  end

  test "unchecked_value nil omits the hidden input and a custom one is used" do
    assert_nil doc(render_box(unchecked_value: nil)).at_css("input[type=hidden]")
    assert_equal "no", doc(render_box(unchecked_value: "no")).at_css("input[type=hidden]")["value"]
  end

  test "values that mean checked" do
    [ true, 1, "1", "true", "t", "on", "yes", "TRUE" ].each do |value|
      assert_equal "checked", doc(render_box(object: { email: value })).at_css("button")["data-state"], value.inspect
    end
  end

  test "values that mean unchecked" do
    [ nil, false, 0, "0", "false", "f", "off", "no", "" ].each do |value|
      assert_equal "unchecked", doc(render_box(object: { email: value })).at_css("button")["data-state"], value.inspect
    end
  end

  test "a string equal to the checkbox value is checked" do
    html = doc(render_box(object: { email: "agree" }, value: "agree"))

    assert_equal "checked", html.at_css("button")["data-state"]
    assert_equal "agree", html.at_css("button")["value"]
    assert_raises(ArgumentError) { render_box(object: { email: "other" }, value: "agree") }
  end

  test "anything else raises with the attribute" do
    [ [ 1 ], { a: 1 }, :maybe, 2 ].each do |value|
      error = assert_raises(ArgumentError) { render_box(object: { email: value }) }

      assert_includes error.message, "Chadcn::Form::Field::Checkbox"
      assert_includes error.message, ":email"
    end
  end

  test "caller attrs win" do
    html = doc(render_box(id: "mine", name: "custom", form: "f1", default_checked: false, disabled: true, class: "x"))
    button = html.at_css("button")

    assert_equal "mine", button["id"]
    assert_equal "unchecked", button["data-state"]
    assert button.key?("disabled")
    assert_includes button["class"], "x"
    assert_equal "custom", html.at_css("input[type=hidden]")["name"]
    assert_equal "f1", html.at_css("input[type=hidden]")["form"]
  end

  test "the helper renders the same HTML as the explicit part" do
    assert_equal(render_box(unchecked_value: "n"), field_for(object: { email: true }).call { |field| field.checkbox(unchecked_value: "n") })
  end
end
