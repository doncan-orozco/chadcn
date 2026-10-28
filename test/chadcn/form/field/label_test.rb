# frozen_string_literal: true

require "chadcn/test_case"
require "nokogiri"

class Chadcn::Form::Field::LabelTest < Chadcn::TestCase
  def render_part(errors: {}, **, &block)
    binding_object = Chadcn::Form::Binding::Plain.new(scope: :user, object: { email: "e", bio: "b" }, errors:)
    Chadcn::Form::Field.new(attribute: :email, binding: binding_object).call do |field|
      field.render(Chadcn::Form::Field::Label.new(**), &block)
    end
  end

  def doc(html) = Nokogiri::HTML5.fragment(html)

  test "renders the field label bound to the control id" do
    label = doc(render_part).at_css("[data-slot=field-label]")

    assert_equal "user_email-form-item", label["for"]
    assert_equal "false", label["data-error"]
    assert_equal "Email", label.text.strip
  end

  test "block text and caller class are honored, error state flips data-error" do
    label = doc(render_part(errors: { email: [ "x" ] }, class: "mine") { "Mail" }).at_css("[data-slot=field-label]")

    assert_equal "true", label["data-error"]
    assert_equal "Mail", label.text.strip
    assert_includes label["class"], "mine"
  end
end
