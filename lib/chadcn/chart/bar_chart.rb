# frozen_string_literal: true

# recharts' `BarChart` (chart/BarChart.js): bars over a category axis. The block declares what is in the chart (`chart.bar`,
# `chart.x_axis`, `chart.cartesian_grid`, `chart.tooltip` ...); it is run first, then the chart is laid out in one pass and drawn as
# `div.recharts-wrapper > svg.recharts-surface` in recharts' own markup. Put it inside a {Chadcn::Chart::Container}, which gives it the
# colors of the config and its size.
#
# Declaration order is drawing order inside a layer, as in React.
#
# @example
#   render Chadcn::Chart::Container.new(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }) do
#     render Chadcn::Chart::BarChart.new(data: [ { month: "January", desktop: 186 }, { month: "February", desktop: 305 } ]) do |chart|
#       chart.cartesian_grid(vertical: false)
#       chart.x_axis(data_key: :month, tick_line: false, tick_margin: 10, axis_line: false, tick_formatter: { slice: [ 0, 3 ] })
#       chart.bar(data_key: :desktop, fill: "var(--color-desktop)", radius: 4)
#     end
#   end
class Chadcn::Chart::BarChart < Chadcn::Chart::Cartesian::Root
  # What the chart draws bars and gaps with (recharts picks a band scale for the categories).
  #
  # @api private
  CHART_TYPE = :bar

  # @param data [Array<Hash>] one row per category; a series reads `data_key` of each row
  # @param layout [Symbol] `:horizontal` (categories along x, bars grow up) or `:vertical` (categories along y, bars grow right)
  # @param margin [Hash] `top:`, `right:`, `bottom:` and `left:` in px; a side that is not given is 0, as in recharts
  # @param bar_category_gap [Numeric, String] space around the bars of a category, px or a percent of the band
  # @param bar_gap [Numeric, String] space between the bars of a category, px or a percent of the band
  # @param bar_size [Numeric, String, nil] width of a bar, px or a percent of the band; the bands are shared out equally when nil
  # @param max_bar_size [Numeric, nil] the widest a bar may be
  # @param stack_offset [Symbol] `:none` or `:expand` (every stack normalized to 1)
  # @param reverse_stack_order [Boolean] stack the series of a stack in reverse order of declaration
  # @param accessibility_layer [Boolean] `role="application"` and `tabindex="0"` on the svg
  # @param title [String, nil] text of the svg `title`
  # @param desc [String, nil] text of the svg `desc`
  # @param role [String, nil] replaces `application`
  # @param tab_index [Integer, nil] replaces `0`
  # @param attrs [Hash] `class:` and `style:` go on `.recharts-wrapper`, every other attribute on the svg
  # @raise [ArgumentError] on a `data:` that is not an Array of Hashes, or a `layout:` or `stack_offset:` outside its values
  def initialize(data: [], layout: :horizontal, margin: { top: 5, right: 5, bottom: 5, left: 5 }, bar_category_gap: "10%", bar_gap: 4, bar_size: nil,
                 max_bar_size: nil, stack_offset: :none, reverse_stack_order: false, accessibility_layer: true, title: nil, desc: nil, role: nil,
                 tab_index: nil, **attrs)
    super
  end
end
