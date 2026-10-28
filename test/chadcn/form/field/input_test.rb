# frozen_string_literal: true

require "chadcn/test_case"
require "nokogiri"

class Chadcn::Form::Field::InputTest < Chadcn::TestCase
  def render_part(errors: {}, **, &block)
    binding_object = Chadcn::Form::Binding::Plain.new(scope: :user, object: { email: "e", bio: "b" }, errors:)
    Chadcn::Form::Field.new(attribute: :email, binding: binding_object).call do |field|
      field.render(Chadcn::Form::Field::Input.new(**), &block)
    end
  end

  def doc(html) = Nokogiri::HTML5.fragment(html)

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
end
