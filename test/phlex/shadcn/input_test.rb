# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::InputTest < Phlex::Shadcn::TestCase
  def render_input(**attrs) = Phlex::Shadcn::Input.new(**attrs).call

  test "renders slot, type and base classes" do
    html = render_input(type: :email, name: "e")

    assert_includes html, 'type="email"'
    assert_includes html, 'data-slot="input"'
    assert_includes html, "h-9 w-full"
  end

  test "omits type when nil" do
    refute_includes render_input, "type="
  end

  test "caller class wins and attrs pass through" do
    html = render_input(class: "h-12", disabled: true, read_only: true, aria: { invalid: true }, data: { x: "1" })

    assert_includes html, "h-12"
    refute_includes html, "h-9"
    assert_includes html, "disabled"
    assert_includes html, "readonly"
    assert_includes html, 'aria-invalid="true"'
    assert_includes html, 'data-x="1"'
  end

  test "caller data-slot overrides" do
    assert_includes render_input(data: { slot: "custom" }), 'data-slot="custom"'
  end
end
