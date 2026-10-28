# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::LabelTest < Chadcn::TestCase
  include Chadcn::FormSupport

  def render_part(errors: {}, **, &) = super(Chadcn::Form::Field::Label, errors:, **, &)

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
