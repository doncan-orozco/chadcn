# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::InputTest < Chadcn::TestCase
  include Chadcn::FormSupport

  def render_part(errors: {}, **, &) = super(Chadcn::Form::Field::Input, errors:, **, &)

  test "renders a bound input" do
    input = doc(render_part).at_css("input[data-slot=input]")

    assert_equal "user[email]", input["name"]
    assert_equal "e", input["value"]
    assert_equal "false", input["aria-invalid"]
  end

  test "caller attrs win and invalid state shows" do
    input = doc(render_part(errors: { email: [ "x" ] }, type: "email", placeholder: "p")).at_css("input")

    assert_equal "email", input["type"]
    assert_equal "p", input["placeholder"]
    assert_equal "true", input["aria-invalid"]
  end

  test "non-string values render as strings" do
    {
      Date.new(2026, 1, 2) => "2026-01-02",
      42 => "42",
      false => "false"
    }.each do |value, expected|
      input = doc(render_part(object: { email: value })).at_css("input")

      assert_equal expected, input["value"], value.inspect
    end
  end

  test "a nil value renders no value attribute" do
    assert_nil doc(render_part(object: { email: nil })).at_css("input")["value"]
  end

  test "errors list both describedby ids" do
    input = doc(render_part(errors: { email: [ "x" ] })).at_css("input")

    assert_equal "user_email-form-item-description user_email-form-item-message", input["aria-describedby"]
  end

  test "a field without description still lists the description id (React parity)" do
    assert_equal "user_email-form-item-description", doc(render_part).at_css("input")["aria-describedby"]
  end
end
