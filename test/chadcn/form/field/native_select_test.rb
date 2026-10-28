# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::NativeSelectTest < Chadcn::TestCase
  include Chadcn::FormSupport

  Part = Chadcn::Form::Field::NativeSelect

  def body
    proc do |select|
      select.option(value: "a") { "A" }
      select.option(value: "b") { "B" }
    end
  end

  def render_select(errors: {}, object: { email: "b" }, **) = render_part(Part, errors:, object:, **, &body)

  test "binds name, id, aria and the selected option" do
    html = doc(render_select)
    select = html.at_css("select[data-slot=native-select]")

    assert_equal "user[email]", select["name"]
    assert_equal "user_email-form-item", select["id"]
    assert_equal "false", select["aria-invalid"]
    assert_equal "user_email-form-item-description", select["aria-describedby"]
    assert_equal(%w[b], html.css("option[selected]").map { |option| option["value"] })
  end

  test "errors mark the select invalid" do
    select = doc(render_select(errors: { email: [ "x" ] })).at_css("select")

    assert_equal "true", select["aria-invalid"]
    assert_equal "user_email-form-item-description user_email-form-item-message", select["aria-describedby"]
  end

  test "caller attrs win" do
    select = doc(render_select(name: "custom", id: "mine", class: "w-1", size: "sm", disabled: true)).at_css("select")

    assert_equal "custom", select["name"]
    assert_equal "mine", select["id"]
    assert_includes select["class"], "w-1"
    assert select.key?("disabled")
  end

  test "multiple takes an array, appends [] to the name and selects each value" do
    html = doc(render_select(object: { email: [ "a", :b ] }, multiple: true))
    select = html.at_css("select")

    assert_equal "user[email][]", select["name"]
    assert select.key?("multiple")
    assert_equal(%w[a b], html.css("option[selected]").map { |option| option["value"] })
  end

  test "multiple with a scalar selects it" do
    html = doc(render_select(object: { email: "a" }, multiple: true))

    assert_equal(%w[a], html.css("option[selected]").map { |option| option["value"] })
  end

  test "an array without multiple raises with the attribute" do
    error = assert_raises(ArgumentError) { render_select(object: { email: [ "a" ] }) }

    assert_includes error.message, "Chadcn::Form::Field::NativeSelect"
    assert_includes error.message, ":email"
  end

  test "a hash raises even with multiple" do
    assert_raises(ArgumentError) { render_select(object: { email: { a: 1 } }, multiple: true) }
  end

  test "a nil value selects no option explicitly" do
    assert_empty doc(render_select(object: { email: nil })).css("option[selected]")
  end

  test "the helper renders the same HTML as the explicit part" do
    assert_equal(render_select, field_for(object: { email: "b" }).call { |field| field.native_select(&body) })
  end
end
