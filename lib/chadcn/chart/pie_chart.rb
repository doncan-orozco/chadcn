# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- cx and cy are the center vocabulary of recharts

# recharts' `PieChart` (chart/PieChart.js): a pie (or a donut) of sectors sized by value. The block declares what is in the chart
# (`chart.pie`, `chart.tooltip`, `chart.legend`, `chart.label`); it is run first, then the chart is laid out in one pass and drawn as
# `div.recharts-wrapper > svg.recharts-surface` in recharts' own markup. Put it inside a {Chadcn::Chart::Container}, which gives it the
# colors of the config and its size.
#
# Tooltips of a pie are item tooltips: one per sector (`PieChart` allows only `item`, chart/PieChart.js:11).
#
# @example A donut with the total in the middle
#   render Chadcn::Chart::Container.new(config: { chrome: { label: "Chrome", color: "var(--chart-1)" } }) do
#     render Chadcn::Chart::PieChart.new do |chart|
#       chart.tooltip(cursor: false, content: Chadcn::Chart::Tooltip::Content.new(hide_label: true))
#       chart.pie(data: [ { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" } ], data_key: :visitors, name_key: :browser,
#                 inner_radius: 60, stroke_width: 5) { |pie| pie.label(value: "Visitors", position: :center) }
#     end
#   end
class Chadcn::Chart::PieChart < Chadcn::Chart::Polar::Root
  # @api private
  CHART_TYPE = :pie
  # @api private
  LAYOUT = :centric
  # @api private
  AXES = false

  # @param data [Array<Hash>] the rows a pie without its own `data:` shows
  # @param margin [Hash] `top:`, `right:`, `bottom:` and `left:` in px; a side that is not given is 0, as in recharts
  # @param start_angle [Numeric] degrees, counterclockwise from 3 o'clock (the angle a `Label` placed by the chart starts at)
  # @param end_angle [Numeric] degrees
  # @param cx [Numeric, String] center x of the chart, px or a percent of its width
  # @param cy [Numeric, String] center y of the chart, px or a percent of its height
  # @param inner_radius [Numeric, String] inner radius of the chart (a `Label` placed by the chart), px or a percent of the largest circle in the plot
  # @param outer_radius [Numeric, String] outer radius of the chart, px or a percent of the largest circle in the plot
  # @param accessibility_layer [Boolean] `role="application"` and `tabindex="0"` on the svg
  # @param title [String, nil] text of the svg `title`
  # @param desc [String, nil] text of the svg `desc`
  # @param role [String, nil] replaces `application`
  # @param tab_index [Integer, nil] replaces `0`
  # @param attrs [Hash] `class:` and `style:` go on `.recharts-wrapper`, every other attribute on the svg
  # @raise [ArgumentError] on a `data:` that is not an Array of Hashes, or an angle, radius or center that is not a number
  def initialize(data: [], margin: { top: 5, right: 5, bottom: 5, left: 5 }, start_angle: 0, end_angle: 360, cx: "50%", cy: "50%", inner_radius: 0,
                 outer_radius: "80%", accessibility_layer: true, title: nil, desc: nil, role: nil, tab_index: nil, **attrs)
    super
  end
end

# rubocop:enable Naming/MethodParameterName
