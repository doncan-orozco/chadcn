# frozen_string_literal: true

# recharts' `AreaChart` (chart/AreaChart.js): filled areas over a category axis, on a point scale, stacked by `stack_id`. The block
# declares what is in the chart, as for {Chadcn::Chart::BarChart}.
#
# @example
#   render Chadcn::Chart::AreaChart.new(data: rows, margin: { left: 12, right: 12 }) do |chart|
#     chart.x_axis(data_key: :month)
#     chart.area(data_key: :mobile, type: :natural, stack_id: "a", fill: "var(--color-mobile)", fill_opacity: 0.4, stroke: "var(--color-mobile)")
#     chart.area(data_key: :desktop, type: :natural, stack_id: "a", fill: "var(--color-desktop)", fill_opacity: 0.4, stroke: "var(--color-desktop)")
#   end
class Chadcn::Chart::AreaChart < Chadcn::Chart::Cartesian::Root
  # @api private
  CHART_TYPE = :area

  # @param data [Array<Hash>] one row per category; a series reads `data_key` of each row
  # @param layout [Symbol] `:horizontal` (categories along x) or `:vertical` (categories along y)
  # @param margin [Hash] `top:`, `right:`, `bottom:` and `left:` in px; a side that is not given is 0, as in recharts
  # @param bar_category_gap [Numeric, String] accepted for parity with recharts; an area chart has no bars
  # @param bar_gap [Numeric, String] accepted for parity with recharts
  # @param bar_size [Numeric, String, nil] accepted for parity with recharts
  # @param max_bar_size [Numeric, nil] accepted for parity with recharts
  # @param stack_offset [Symbol] `:none` or `:expand` (every stack normalized to 1)
  # @param reverse_stack_order [Boolean] stack the areas of a stack in reverse order of declaration
  # @param accessibility_layer [Boolean] `role="application"` and `tabindex="0"` on the svg
  # @param title [String, nil] text of the svg `title`
  # @param desc [String, nil] text of the svg `desc`
  # @param role [String, nil] replaces `application`
  # @param tab_index [Integer, nil] replaces `0`
  # @param base_value [Numeric, Symbol, nil] where areas start: a number, `:data_min` or `:data_max` (the zero line by default)
  # @param attrs [Hash] `class:` and `style:` go on `.recharts-wrapper`, every other attribute on the svg
  # @raise [ArgumentError] on a `data:` that is not an Array of Hashes, or a `layout:` or `stack_offset:` outside its values
  def initialize(data: [], layout: :horizontal, margin: { top: 5, right: 5, bottom: 5, left: 5 }, bar_category_gap: "10%", bar_gap: 4, bar_size: nil,
                 max_bar_size: nil, stack_offset: :none, reverse_stack_order: false, accessibility_layer: true, title: nil, desc: nil, role: nil,
                 tab_index: nil, base_value: nil, **attrs) = super
end
