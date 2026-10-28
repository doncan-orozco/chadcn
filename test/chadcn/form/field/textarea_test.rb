# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::TextareaTest < Chadcn::TestCase
  include Chadcn::FormSupport

  def render_part(errors: {}, **, &) = super(Chadcn::Form::Field::Textarea, errors:, **, &)

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
