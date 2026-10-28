# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::StyleTest < Chadcn::TestCase
  def render_style(id: "chart-1", **config) = Chadcn::Chart::Style.new(id: id, config: config).call

  test "renders one rule per theme with the color variables" do
    html = render_style(desktop: { color: "var(--chart-1)" }, mobile: { theme: { light: "#2563eb", dark: "#60a5fa" } })
    css = Nokogiri::HTML.fragment(html).at_css("style").text

    assert_equal "\n [data-chart=chart-1] {\n  --color-desktop: var(--chart-1);\n  --color-mobile: #2563eb;\n}\n\n\n" \
                 ".dark [data-chart=chart-1] {\n  --color-desktop: var(--chart-1);\n  --color-mobile: #60a5fa;\n}\n", css
  end

  test "renders nothing when no entry has a color or a theme" do
    assert_equal "", render_style(desktop: { label: "Desktop" })
    assert_equal "", render_style
  end

  test "an entry without a color for a theme leaves an empty line, like chart.tsx" do
    css = Nokogiri::HTML.fragment(render_style(a: { theme: { light: "#000" } }, b: { color: "red" })).at_css("style").text

    assert_includes css, "\n [data-chart=chart-1] {\n  --color-a: #000;\n  --color-b: red;\n}\n"
    assert_includes css, ".dark [data-chart=chart-1] {\n\n  --color-b: red;\n}\n"
  end

  test "takes no attributes" do
    assert_raises(ArgumentError) { Chadcn::Chart::Style.new(id: "x", config: {}, class: "a") }
  end

  test "an id that is not a plain token raises" do
    [ "x]{", "a b", "", "a\"b", "a;b" ].each do |id|
      assert_raises(ArgumentError, id) { Chadcn::Chart::Style.new(id: id, config: {}) }
    end
  end

  test "accepts a Config object" do
    config = Chadcn::Chart::Config.new(a: { color: "red" })

    assert_includes Chadcn::Chart::Style.new(id: "x", config: config).call, "--color-a: red;"
  end
end
