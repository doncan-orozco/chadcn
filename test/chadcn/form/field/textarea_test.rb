# frozen_string_literal: true

require "chadcn/test_case"
require "nokogiri"

class Chadcn::Form::Field::TextareaTest < Chadcn::TestCase
  def render_part(errors: {}, **, &block)
    binding_object = Chadcn::Form::Binding::Plain.new(scope: :user, object: { email: "e", bio: "b" }, errors:)
    Chadcn::Form::Field.new(attribute: :email, binding: binding_object).call do |field|
      field.render(Chadcn::Form::Field::Textarea.new(**), &block)
    end
  end

  def doc(html) = Nokogiri::HTML5.fragment(html)

  test "renders a bound textarea with the value as content" do
    area = doc(render_part).at_css("textarea[data-slot=textarea]")

    assert_equal "user[email]", area["name"]
    assert_equal "e", area.text
    assert_equal "false", area["aria-invalid"]
  end

  test "caller attrs win" do
    area = doc(render_part(rows: 4, name: "mine")).at_css("textarea")

    assert_equal "mine", area["name"]
    assert_equal "4", area["rows"]
  end
end
