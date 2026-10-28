# frozen_string_literal: true

require "chadcn/test_case"
require "nokogiri"

class Chadcn::Form::Field::ErrorTest < Chadcn::TestCase
  def render_part(errors: {}, **, &block)
    binding_object = Chadcn::Form::Binding::Plain.new(scope: :user, object: { email: "e", bio: "b" }, errors:)
    Chadcn::Form::Field.new(attribute: :email, binding: binding_object).call do |field|
      field.render(Chadcn::Form::Field::Error.new(**), &block)
    end
  end

  def doc(html) = Nokogiri::HTML5.fragment(html)

  test "renders nothing without errors and without a block" do
    assert_nil doc(render_part).at_css("[data-slot=field-error]")
  end

  test "renders the block without errors" do
    node = doc(render_part { "Custom" }).at_css("[data-slot=field-error]")

    assert_equal "user_email-form-item-message", node["id"]
    assert_equal "Custom", node.text.strip
  end

  test "errors win over the block" do
    out = render_part(errors: { email: [ "bad" ] }) { "Custom" }

    assert_includes out, "bad"
    assert_not_includes out, "Custom"
  end
end
