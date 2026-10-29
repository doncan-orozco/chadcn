# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- cx and cy are the center vocabulary of recharts

# recharts' `RadarChart` (chart/RadarChart.js): a polygon through one point per category around a center, over an angle axis that holds the
# categories and a radius axis that holds the numbers. The block declares what is in the chart (`chart.radar`, `chart.polar_grid`,
# `chart.polar_angle_axis`, `chart.polar_radius_axis`, `chart.tooltip`, `chart.legend`); it is run first, then the chart is laid out in one
# pass and drawn as `div.recharts-wrapper > svg.recharts-surface` in recharts' own markup. Put it inside a {Chadcn::Chart::Container}.
#
# Tooltips of a radar chart are axis tooltips: one per category (chart/RadarChart.js:11).
#
# @example
#   render Chadcn::Chart::Container.new(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }) do
#     render Chadcn::Chart::RadarChart.new(data: [ { month: "January", desktop: 186 }, { month: "February", desktop: 305 } ]) do |chart|
#       chart.tooltip(cursor: false, content: Chadcn::Chart::Tooltip::Content.new)
#       chart.polar_angle_axis(data_key: :month)
#       chart.polar_grid
#       chart.radar(data_key: :desktop, fill: "var(--color-desktop)", fill_opacity: 0.6)
#     end
#   end
class Chadcn::Chart::RadarChart < Chadcn::Chart::Polar::Root
  # @api private
  CHART_TYPE = :radar
  # @api private
  LAYOUT = :centric
  # @api private
  AXES = true

  # @param data [Array<Hash>] one row per category; a radar reads `data_key` of each row
  # @param margin [Hash] `top:`, `right:`, `bottom:` and `left:` in px; a side that is not given is 0, as in recharts
  # @param start_angle [Numeric] where the first category sits, degrees counterclockwise from 3 o'clock (90 is the top)
  # @param end_angle [Numeric] where the last turn ends; below `start_angle` the categories run clockwise
  # @param cx [Numeric, String] center x, px or a percent of the chart width
  # @param cy [Numeric, String] center y, px or a percent of the chart height
  # @param inner_radius [Numeric, String] px or a percent of the largest circle in the plot
  # @param outer_radius [Numeric, String] px or a percent of the largest circle in the plot
  # @param accessibility_layer [Boolean] `role="application"` and `tabindex="0"` on the svg
  # @param title [String, nil] text of the svg `title`
  # @param desc [String, nil] text of the svg `desc`
  # @param role [String, nil] replaces `application`
  # @param tab_index [Integer, nil] replaces `0`
  # @param attrs [Hash] `class:` and `style:` go on `.recharts-wrapper`, every other attribute on the svg
  # @raise [ArgumentError] on a `data:` that is not an Array of Hashes, or an angle, radius or center that is not a number
  def initialize(data: [], margin: { top: 5, right: 5, bottom: 5, left: 5 }, start_angle: 90, end_angle: -270, cx: "50%", cy: "50%", inner_radius: 0,
                 outer_radius: "80%", accessibility_layer: true, title: nil, desc: nil, role: nil, tab_index: nil, **attrs)
    super
  end
end

# rubocop:enable Naming/MethodParameterName
