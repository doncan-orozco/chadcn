# frozen_string_literal: true

# shadcn/ui Chart: shadcn's `chart.tsx` (`ChartContainer`, `ChartStyle`, `ChartTooltip`, `ChartTooltipContent`, `ChartLegend`,
# `ChartLegendContent` and the `ChartConfig` type) and the recharts charts it wraps, as Phlex. recharts is not shipped: the chart roots
# {Chadcn::Chart::BarChart}, {Chadcn::Chart::LineChart}, {Chadcn::Chart::AreaChart}, {Chadcn::Chart::PieChart}, {Chadcn::Chart::RadarChart}
# and {Chadcn::Chart::RadialBarChart} draw the SVG recharts produces, over the parts a chart's block declares
# ({Chadcn::Chart::Declaration}), and the `chadcn--chart` Stimulus controller adds the tooltip, the cursor and the keyboard. Guide:
# docs/charts.md. Spec: dev/port/specs/chart.md, decision record: dev/decisions/chart.md.
#
# The family root: `Chart.new { |chart| ... }` yields itself, and `Base` generates one helper per nested class (`container`, `style`,
# `bar_chart`, `xaxis`, ...). Only `container` and `style` render on their own: the chart roots go inside a container, and the parts
# (`tooltip`, `legend`, `bar`, ...) are declarations ({Chadcn::Chart::Declaration}) that raise outside a chart root's block, where the
# root's own helpers apply (`chart.x_axis`, `chart.tooltip`).
#
# @example Container with a config and the shadcn tooltip content
#   render Chadcn::Chart.new do |chart|
#     chart.container(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }) do |container|
#       render Chadcn::Chart::Tooltip::Content.new(payload: [ { name: "desktop", value: 186, color: "var(--color-desktop)" } ])
#     end
#   end
#
# Generated helpers (each forwards `**attrs` and the block to the part): one per nested class; see docs/charts.md.
#
# @!method container(**attrs, &block)
#   Same as `render Chart::Container.new(**attrs), &block`.
# @!method style(**attrs, &block)
#   Same as `render Chart::Style.new(**attrs), &block`.
# @!method tooltip(**attrs, &block)
#   Same as `render Chart::Tooltip.new(**attrs), &block`.
# @!method legend(**attrs, &block)
#   Same as `render Chart::Legend.new(**attrs), &block`.
class Chadcn::Chart < Chadcn::Base
  # @yieldparam chart [Chart] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    yield self if block_given?
  end
end
