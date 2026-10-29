# frozen_string_literal: true

require "test_helper"

# The chart nodes of a scenario tree in the packaged renderer, the same tree the React Harness.tsx reads (dev/port/specs/chart.md,
# "Oracle driving"). The parity harness reuses this mapping (dev/dummy/test/parity/chart_scope_test.rb runs it through ShadcnParity).
class Chadcn::Catalog::ChartScopeTest < Minitest::Test
  ROWS = [ { "month" => "January", "desktop" => 186 }, { "month" => "February", "desktop" => 305 } ].freeze
  CONFIG = { "desktop" => { "label" => "Desktop", "color" => "red" } }.freeze

  def render_container(*children)
    tree = { "c" => "ChartContainer", "props" => { "id" => "k", "config" => CONFIG }, "children" => children }
    Chadcn::Catalog::TreeRenderer.new(tree: tree, component: "chart").call
  end

  def bar_chart(*children) = { "c" => "_BarChart", "props" => { "data" => ROWS, "margin" => { "left" => 12 } }, "children" => children }

  def test_recharts_parts_named_formatters_and_content_elements_map_to_the_gems_classes
    html = render_container(bar_chart(
                              { "c" => "_XAxis", "props" => { "dataKey" => "month", "tickFormatter" => { "formatter" => "slice", "args" => [ 0, 3 ] } } },
                              { "c" => "ChartTooltip",
                                "props" => { "defaultIndex" => 1, "content" => "ChartTooltipContent", "contentProps" => { "hideLabel" => true } } },
                              { "c" => "ChartLegend", "props" => { "content" => "ChartLegendContent" } },
                              { "c" => "_Bar", "props" => { "dataKey" => "desktop", "fill" => "var(--color-desktop)" } }
                            ))

    assert_includes html, ">Jan</tspan>"
    assert_includes html, 'data-chadcn--chart-target="tooltipTemplate"'
    assert_includes html, "recharts-legend-wrapper"
    refute_includes html, "February</div>", "hideLabel reaches the content"
  end

  def test_the_svg_a_charts_block_writes_is_drawn_inside_the_svg
    gradient = { "c" => "_linearGradient", "props" => { "id" => "g", "x1" => "0" },
                 "children" => [ { "c" => "_stop", "props" => { "offset" => "5%", "stopColor" => "red" } } ] }
    html = render_container(bar_chart({ "c" => "_defs", "children" => [ gradient ] }, { "c" => "_Bar", "props" => { "dataKey" => "desktop" } }))

    assert_includes html, '<linearGradient id="g" x1="0"><stop offset="5%" stop-color="red"></stop></linearGradient>'
  end

  def test_a_content_node_on_its_own_renders_that_content
    payload = [ { "dataKey" => "desktop", "name" => "desktop", "value" => 305, "color" => "var(--color-desktop)",
                  "payload" => { "month" => "February", "desktop" => 305 } } ]
    tooltip = render_container({ "c" => "ChartTooltipContent", "props" => { "active" => true, "payload" => payload, "label" => "February" } })
    legend = render_container({ "c" => "ChartLegendContent",
                                "props" => { "payload" => [ { "value" => "desktop", "dataKey" => "desktop", "type" => "rect", "color" => "red" } ] } })

    assert_includes tooltip, "February"
    assert_includes tooltip, "305"
    refute_includes tooltip, "active=", "active gates the render, it is not an attribute"
    assert_includes legend, "Desktop"
  end

  def test_an_inactive_content_node_renders_nothing
    html = render_container({ "c" => "ChartTooltipContent", "props" => { "active" => false, "payload" => [], "label" => "February" } })

    refute_includes html, "February"
  end

  def test_a_pie_its_cell_and_its_label_map_to_the_gems_classes
    data = [ { "browser" => "a", "visitors" => 5 } ]
    pie = { "c" => "_Pie", "props" => { "data" => data, "dataKey" => "visitors", "nameKey" => "browser", "innerRadius" => 20 },
            "children" => [ { "c" => "_Cell", "props" => { "fill" => "red" } },
                            { "c" => "_Label", "props" => { "value" => "Total", "position" => "center" } } ] }
    html = render_container({ "c" => "_PieChart", "children" => [ pie ] })

    assert_includes html, 'fill="red"'
    assert_includes html, ">Total</tspan>"
  end

  def test_an_unknown_underscore_capital_node_still_raises
    assert_raises(Chadcn::Catalog::TreeRenderer::Error) { render_container({ "c" => "_Probe" }) }
  end
end
