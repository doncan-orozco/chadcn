# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- cx and cy are the center vocabulary of recharts

# recharts' `RadialBarChart` (chart/RadialBarChart.js): arcs around a center, one ring per category, each as long as its value. The radius
# axis holds the categories and the angle axis the numbers. The block declares what is in the chart (`chart.radial_bar`, `chart.polar_grid`,
# `chart.polar_angle_axis`, `chart.polar_radius_axis`, `chart.tooltip`, `chart.legend`); it is run first, then the chart is laid out in one pass
# and drawn as `div.recharts-wrapper > svg.recharts-surface` in recharts' own markup. Put it inside a {Chadcn::Chart::Container}.
#
# Tooltips of a radial bar chart are axis tooltips, one per category (chart/RadialBarChart.js:27).
#
# @example
#   render Chadcn::Chart::Container.new(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }) do
#     render Chadcn::Chart::RadialBarChart.new(data: [ { month: "january", desktop: 1260 } ], end_angle: 180, inner_radius: 80, outer_radius: 130) do |chart|
#       chart.radial_bar(data_key: :desktop, stack_id: "a", corner_radius: 5, fill: "var(--color-desktop)")
#     end
#   end
class Chadcn::Chart::RadialBarChart < Chadcn::Chart::Polar::Root
  # @api private
  CHART_TYPE = :radial_bar
  # @api private
  LAYOUT = :radial
  # @api private
  AXES = true

  # @param data [Array<Hash>] one row per ring; a radial bar reads `data_key` of each row
  # @param margin [Hash] `top:`, `right:`, `bottom:` and `left:` in px; a side that is not given is 0, as in recharts
  # @param start_angle [Numeric] where the arcs start, degrees counterclockwise from 3 o'clock
  # @param end_angle [Numeric] where the longest arc ends; below `start_angle` the arcs run clockwise
  # @param cx [Numeric, String] center x, px or a percent of the chart width
  # @param cy [Numeric, String] center y, px or a percent of the chart height
  # @param inner_radius [Numeric, String] the inside of the innermost ring, px or a percent of the largest circle in the plot
  # @param outer_radius [Numeric, String] the outside of the outermost ring, px or a percent of the largest circle in the plot
  # @param bar_category_gap [Numeric, String] space around the arcs of a ring, px or a percent of the ring
  # @param bar_gap [Numeric, String] space between the arcs of a ring, px or a percent of the ring
  # @param bar_size [Numeric, String, nil] thickness of an arc; the ring is shared out equally when nil
  # @param max_bar_size [Numeric, nil] the thickest an arc may be
  # @param accessibility_layer [Boolean] `role="application"` and `tabindex="0"` on the svg
  # @param title [String, nil] text of the svg `title`
  # @param desc [String, nil] text of the svg `desc`
  # @param role [String, nil] replaces `application`
  # @param tab_index [Integer, nil] replaces `0`
  # @param attrs [Hash] `class:` and `style:` go on `.recharts-wrapper`, every other attribute on the svg
  # @raise [ArgumentError] on a `data:` that is not an Array of Hashes, or an angle, radius or center that is not a number
  def initialize(data: [], margin: { top: 5, right: 5, bottom: 5, left: 5 }, start_angle: 0, end_angle: 360, cx: "50%", cy: "50%", inner_radius: 0,
                 outer_radius: "80%", bar_category_gap: "10%", bar_gap: 4, bar_size: nil, max_bar_size: nil, accessibility_layer: true, title: nil,
                 desc: nil, role: nil, tab_index: nil, **attrs)
    super
  end
end

# rubocop:enable Naming/MethodParameterName
