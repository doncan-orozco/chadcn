# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::AspectRatioTest < Phlex::Shadcn::TestCase
  def render_ratio(**props, &)
    Phlex::Shadcn::AspectRatio.new(**props).call(&)
  end

  test "renders wrapper and inner element" do
    html = render_ratio(ratio: 16.0 / 9) { "x" }

    assert_includes html, "padding-bottom: 56.25%;"
    assert_includes html, "data-radix-aspect-ratio-wrapper"
    assert_includes html, 'data-slot="aspect-ratio"'
    assert_includes html, "position: absolute"
  end

  test "formats the ratio like JS" do
    assert_includes render_ratio, "padding-bottom: 100%;"
    assert_includes render_ratio(ratio: 2), "padding-bottom: 50%;"
    assert_includes render_ratio(ratio: 16 / 9r), "padding-bottom: 56.25%;"
  end

  test "class is verbatim and attrs pass through" do
    html = render_ratio(class: "rounded-md rounded-lg", id: "a", style: { backgroundColor: "red" })

    assert_includes html, 'class="rounded-md rounded-lg"'
    assert_includes html, 'id="a"'
    assert_includes html, "background-color: red; position: absolute"
  end

  test "as_child renders the child inside the wrapper" do
    html = render_ratio(as_child: :a, href: "/x") { "link" }

    assert_includes html, "<a "
    assert_includes html, 'data-slot="aspect-ratio"'
  end
end
