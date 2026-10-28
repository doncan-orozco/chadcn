# frozen_string_literal: true

require "chadcn/test_case"
require "nokogiri"

class Chadcn::Form::Field::ControlTest < Chadcn::TestCase
  def render_part(errors: {}, **, &block)
    binding_object = Chadcn::Form::Binding::Plain.new(scope: :user, object: { email: "e", bio: "b" }, errors:)
    Chadcn::Form::Field.new(attribute: :email, binding: binding_object).call do |field|
      field.render(Chadcn::Form::Field::Control.new(**), &block)
    end
  end

  def doc(html) = Nokogiri::HTML5.fragment(html)

  test "yields the control attrs merged with the part attrs" do
    seen = nil
    render_part(data: { k: "v" }) { |attrs| seen = attrs }

    assert_equal "user[email]", seen[:name]
    assert_equal "user_email-form-item", seen[:id]
    assert_equal "e", seen[:value]
    assert_equal "v", seen[:data][:k]
  end

  test "caller attrs win" do
    seen = nil
    render_part(id: "mine") { |attrs| seen = attrs }

    assert_equal "mine", seen[:id]
  end
end
