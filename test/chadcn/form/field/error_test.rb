# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::ErrorTest < Chadcn::TestCase
  include Chadcn::FormSupport

  def render_part(errors: {}, **, &) = super(Chadcn::Form::Field::Error, errors:, **, &)

  test "renders an empty hidden alert without errors and without a block" do
    node = doc(render_part).at_css("[data-slot=field-error]")

    assert_equal "user_email-form-item-message", node["id"]
    assert_equal "alert", node["role"]
    assert node.key?("hidden")
    assert_empty node.text.strip
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

  test "caller id wins" do
    assert_equal "mine", doc(render_part(id: "mine", errors: { email: [ "x" ] })).at_css("[data-slot=field-error]")["id"]
  end
end
