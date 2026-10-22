# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::InputTest < Chadcn::TestCase
  def render_input(**attrs) = Chadcn::Input.new(**attrs).call

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
    input = Nokogiri::HTML5.fragment(html).at_css("input")

    assert input.key?("disabled")
    assert input.key?("readonly")
    assert_includes html, 'aria-invalid="true"'
    assert_includes html, 'data-x="1"'
  end

  test "caller data-slot overrides" do
    assert_includes render_input(data: { slot: "custom" }), 'data-slot="custom"'
  end

  test "default_value renders the value attribute and an explicit value wins" do
    assert_includes render_input(default_value: "hi"), 'value="hi"'
    html = render_input(default_value: "hi", value: "yo")

    assert_includes html, 'value="yo"'
    refute_includes html, 'value="hi"'
  end

  test "focus and invalid style constants are part of the class" do
    html = render_input

    assert_includes html, Chadcn::Input::FOCUS.split.first
    assert_includes html, Chadcn::Input::INVALID.split.first
  end
end
