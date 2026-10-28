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
end
