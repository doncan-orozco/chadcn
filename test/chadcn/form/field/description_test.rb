# frozen_string_literal: true

require "chadcn/test_case"
require "nokogiri"

class Chadcn::Form::Field::DescriptionTest < Chadcn::TestCase
  def render_part(errors: {}, **, &block)
    binding_object = Chadcn::Form::Binding::Plain.new(scope: :user, object: { email: "e", bio: "b" }, errors:)
    Chadcn::Form::Field.new(attribute: :email, binding: binding_object).call do |field|
      field.render(Chadcn::Form::Field::Description.new(**), &block)
    end
  end

  def doc(html) = Nokogiri::HTML5.fragment(html)

  test "renders the description with the bound id" do
    node = doc(render_part { "Hint" }).at_css("[data-slot=field-description]")

    assert_equal "user_email-form-item-description", node["id"]
    assert_equal "Hint", node.text.strip
  end

  test "caller class is merged" do
    assert_includes doc(render_part(class: "mine") { "x" }).at_css("[data-slot=field-description]")["class"], "mine"
  end
end
