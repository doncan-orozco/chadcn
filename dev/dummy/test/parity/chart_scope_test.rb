# frozen_string_literal: true

require "test_helper"

# The chart half of the parity harness (ShadcnParity::ChartScope): the same tree the React Harness.tsx reads.
class ShadcnParity::ChartScopeTest < ActiveSupport::TestCase
  ROWS = [ { "month" => "January", "desktop" => 186 }, { "month" => "February", "desktop" => 305 } ].freeze

  def tree(chart_children)
    { "c" => "ChartContainer", "props" => { "id" => "k", "config" => { "desktop" => { "label" => "Desktop", "color" => "red" } } },
      "children" => [ { "c" => "_BarChart", "props" => { "data" => ROWS, "margin" => { "left" => 12 } }, "children" => chart_children } ] }
  end

  def render_tree(chart_children) = ShadcnParity::TreeRenderer.new(tree: tree(chart_children), component: "chart").call

  test "recharts parts, named formatters and content elements map to the gem's classes" do
    html = render_tree([
                         { "c" => "_XAxis", "props" => { "dataKey" => "month", "tickFormatter" => { "formatter" => "slice", "args" => [ 0, 3 ] } } },
                         { "c" => "ChartTooltip", "props" => { "defaultIndex" => 1, "content" => "ChartTooltipContent", "contentProps" => { "hideLabel" => true } } },
                         { "c" => "ChartLegend", "props" => { "content" => "ChartLegendContent" } },
                         { "c" => "_Bar", "props" => { "dataKey" => "desktop", "fill" => "var(--color-desktop)" } }
                       ])

    assert_includes html, ">Jan</tspan>"
    assert_includes html, 'data-chadcn--chart-target="tooltipTemplate"'
    assert_includes html, "recharts-legend-wrapper"
    assert_not_includes html, "February</div>", "hideLabel reaches the content"
  end

  test "the SVG a chart's block writes (defs) is drawn inside the svg" do
    html = render_tree([ { "c" => "_defs", "children" => [ { "c" => "_linearGradient", "props" => { "id" => "g", "x1" => "0" },
                                                             "children" => [ { "c" => "_stop", "props" => { "offset" => "5%", "stopColor" => "red" } } ] } ] },
                         { "c" => "_Bar", "props" => { "dataKey" => "desktop" } } ])

    assert_includes html, '<linearGradient id="g" x1="0"><stop offset="5%" stop-color="red"></stop></linearGradient>'
  end

  def render_chart_node(chart)
    tree = { "c" => "ChartContainer", "props" => { "id" => "k", "config" => { "desktop" => { "label" => "Desktop", "color" => "red" } } }, "children" => [ chart ] }
    ShadcnParity::TreeRenderer.new(tree: tree, component: "chart").call
  end

  test "a pie, its cell and its label map to the gem's classes" do
    pie = { "c" => "_Pie", "props" => { "data" => [ { "browser" => "a", "visitors" => 5 } ], "dataKey" => "visitors", "nameKey" => "browser", "innerRadius" => 20 },
            "children" => [ { "c" => "_Cell", "props" => { "fill" => "red" } }, { "c" => "_Label", "props" => { "value" => "Total", "position" => "center" } } ] }
    html = render_chart_node({ "c" => "_PieChart", "children" => [ pie ] })

    assert_includes html, 'fill="red"'
    assert_includes html, ">Total</tspan>"
  end

  test "a radar with its grid and axes maps to the gem's classes" do
    html = render_chart_node({ "c" => "_RadarChart", "props" => { "data" => ROWS },
                               "children" => [ { "c" => "_PolarAngleAxis", "props" => { "dataKey" => "month" } }, { "c" => "_PolarGrid", "props" => { "gridType" => "circle" } },
                                               { "c" => "_PolarRadiusAxis", "props" => { "angle" => 90 } }, { "c" => "_Radar", "props" => { "dataKey" => "desktop", "dot" => { "r" => 4 } } } ] })

    assert_includes html, "recharts-polar-grid-concentric-circle"
    assert_includes html, "recharts-polar-radius-axis-tick-value"
    assert_includes html, "recharts-radar-dot"
  end

  test "a radial bar maps to the gem's class, its position in camelCase included" do
    bar = { "c" => "_RadialBar", "props" => { "dataKey" => "desktop", "background" => true }, "children" => [ { "c" => "_LabelList", "props" => { "position" => "insideStart", "dataKey" => "month" } } ] }
    html = render_chart_node({ "c" => "_RadialBarChart", "props" => { "data" => ROWS, "innerRadius" => 20, "outerRadius" => 90 }, "children" => [ bar ] })

    assert_includes html, "recharts-radial-bar-background-sector undefined"
    assert_includes html, "recharts-radial-bar-label"
  end
end
