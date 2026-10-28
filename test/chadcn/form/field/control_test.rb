# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::ControlTest < Chadcn::TestCase
  include Chadcn::FormSupport

  def render_part(errors: {}, **, &) = super(Chadcn::Form::Field::Control, errors:, **, &)

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

  test "with errors the attrs are invalid and list both ids" do
    seen = nil
    render_part(errors: { email: [ "x" ] }) { |attrs| seen = attrs }

    assert_equal "true", seen[:aria][:invalid]
    assert_equal "user_email-form-item-description user_email-form-item-message", seen[:aria][:describedby]
  end
end
