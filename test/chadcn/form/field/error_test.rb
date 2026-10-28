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
    assert_equal "true", node["data-chadcn-form-message"]
  end

  test "the placeholder merges caller attrs" do
    node = doc(render_part(class: "mt-2", data: { x: "1" })).at_css("[data-slot=field-error]")

    assert_includes node["class"].split, "mt-2"
    assert_includes node["class"].split, "text-destructive"
    assert_equal "1", node["data-x"]
    assert_equal "true", node["data-chadcn-form-message"]
    assert node.key?("hidden")
  end

  test "marks the server error element as managed" do
    node = doc(render_part(errors: { email: [ "bad" ] })).at_css("[data-slot=field-error]")

    assert_equal "true", node["data-chadcn-form-message"]
  end

  test "renders the block without errors" do
    node = doc(render_part { "Custom" }).at_css("[data-slot=field-error]")

    assert_equal "user_email-form-item-message", node["id"]
    assert_equal "Custom", node.text.strip
    assert_not node.key?("data-chadcn-form-message")
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
