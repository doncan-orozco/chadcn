# frozen_string_literal: true

# recharts' `LineChart` (chart/LineChart.js): lines over a category axis, positioned on a point scale (the first and last category sit on
# the edges of the plot). The block declares what is in the chart, as for {Chadcn::Chart::BarChart}.
#
# @example
#   render Chadcn::Chart::LineChart.new(data: rows, margin: { left: 12, right: 12 }) do |chart|
#     chart.cartesian_grid(vertical: false)
#     chart.x_axis(data_key: :month, axis_line: false, tick_margin: 8)
#     chart.line(data_key: :desktop, type: :monotone, stroke: "var(--color-desktop)", stroke_width: 2, dot: false)
#   end
class Chadcn::Chart::LineChart < Chadcn::Chart::Cartesian::Root
  # @api private
  CHART_TYPE = :line

  # @param data [Array<Hash>] one row per category; a series reads `data_key` of each row
  # @param layout [Symbol] `:horizontal` (categories along x) or `:vertical` (categories along y)
  # @param margin [Hash] `top:`, `right:`, `bottom:` and `left:` in px; a side that is not given is 0, as in recharts
  # @param bar_category_gap [Numeric, String] accepted for parity with recharts; a line chart has no bars
  # @param bar_gap [Numeric, String] accepted for parity with recharts
  # @param bar_size [Numeric, String, nil] accepted for parity with recharts
  # @param max_bar_size [Numeric, nil] accepted for parity with recharts
  # @param stack_offset [Symbol] `:none` or `:expand`
  # @param reverse_stack_order [Boolean] accepted for parity with recharts
  # @param accessibility_layer [Boolean] `role="application"` and `tabindex="0"` on the svg
  # @param title [String, nil] text of the svg `title`
  # @param desc [String, nil] text of the svg `desc`
  # @param role [String, nil] replaces `application`
  # @param tab_index [Integer, nil] replaces `0`
  # @param attrs [Hash] `class:` and `style:` go on `.recharts-wrapper`, every other attribute on the svg
  # @raise [ArgumentError] on a `data:` that is not an Array of Hashes, or a `layout:` or `stack_offset:` outside its values
  def initialize(data: [], layout: :horizontal, margin: { top: 5, right: 5, bottom: 5, left: 5 }, bar_category_gap: "10%", bar_gap: 4, bar_size: nil,
                 max_bar_size: nil, stack_offset: :none, reverse_stack_order: false, accessibility_layer: true, title: nil, desc: nil, role: nil,
                 tab_index: nil, **attrs) = super
end
