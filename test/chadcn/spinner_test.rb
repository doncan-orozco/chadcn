# frozen_string_literal: true

require "chadcn/test_case"

class SpinnerTest < Chadcn::TestCase
  def render_spinner(**attrs)
    Chadcn::Spinner.new(**attrs).call
  end

  test "renders status svg without data-slot or aria-hidden" do
    html = render_spinner

    assert_includes html, 'role="status"'
    assert_includes html, 'aria-label="Loading"'
    assert_includes html, "lucide-loader-circle"
    assert_includes html, "animate-spin"
    assert_not_includes html, "data-slot"
    assert_not_includes html, "aria-hidden"
  end

  test "merges class and passes attrs" do
    html = render_spinner(class: "size-8", id: "x", role: "img")

    assert_includes html, "size-8"
    assert_not_includes html, "size-4"
    assert_includes html, 'id="x"'
    assert_includes html, 'role="img"'
  end
end
