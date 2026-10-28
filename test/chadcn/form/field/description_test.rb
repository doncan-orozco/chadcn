# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::DescriptionTest < Chadcn::TestCase
  include Chadcn::FormSupport

  def render_part(errors: {}, **, &) = super(Chadcn::Form::Field::Description, errors:, **, &)

  test "renders the description with the bound id" do
    node = doc(render_part { "Hint" }).at_css("[data-slot=field-description]")

    assert_equal "user_email-form-item-description", node["id"]
    assert_equal "Hint", node.text.strip
  end

  test "caller class is merged" do
    assert_includes doc(render_part(class: "mine") { "x" }).at_css("[data-slot=field-description]")["class"], "mine"
  end

  test "caller id wins" do
    assert_equal "mine", doc(render_part(id: "mine") { "x" }).at_css("[data-slot=field-description]")["id"]
  end
end
