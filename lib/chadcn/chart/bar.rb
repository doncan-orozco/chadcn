# frozen_string_literal: true

# recharts' `Bar` (cartesian/Bar.js): one series of rectangles. Declared in a {Chadcn::Chart::BarChart}; it renders nothing where it is
# written. Bars with the same `stack_id` are stacked; every other bar has a slot of its own inside the category band. A
# {Chadcn::Chart::Cell} in its block styles the rectangle at the same index, a {Chadcn::Chart::LabelList} labels the rectangles.
#
# Every attribute other than `class:` lands on each rectangle (`fill:`, `stroke:` and `radius:` are keywords for the common ones); `class:`
# and `id:` land on the group. A data row's own `fill`, `stroke`, `name` and `opacity` override the series' on its rectangle.
#
# @example
#   chart.bar(data_key: :desktop, stack_id: "a", fill: "var(--color-desktop)", radius: [ 0, 0, 4, 4 ]) { |bar| bar.label_list(position: :top, offset: 12) }
class Chadcn::Chart::Bar < Chadcn::Chart::Declaration
  include Chadcn::Chart::Cartesian::Series

  # @api private
  KIND = :bar
  # recharts' `LegendType`.
  LEGEND_TYPES = %i[line plainline square rect circle cross diamond star triangle wye none].freeze

  # @param data_key [Symbol, String, #call] the key of each data row whose value is the bar, or a callable that receives the row
  # @param stack_id [String, Symbol, Integer, nil] bars with the same id are stacked, in order of declaration
  # @param fill [String, nil]
  # @param stroke [String, nil]
  # @param radius [Numeric, Array<Numeric>, nil] corner radius, or `[top-left, top-right, bottom-right, bottom-left]`
  # @param bar_size [Numeric, String, nil] width of the bar, px or a percent of the band
  # @param max_bar_size [Numeric, nil] the widest the bar may be
  # @param min_point_size [Numeric] the least a bar's length is drawn at, px
  # @param background [Boolean, Hash] draws a rectangle behind every bar, filling the band (`#eee`); a Hash gives its attributes
  # @param label [Boolean, Hash] `true` (or a Hash of {Chadcn::Chart::LabelList} keywords) is a label list on the bar
  # @param active_bar [Boolean] only `false` is ported (the active bar needs the tooltip); anything else raises
  # @param hide [Boolean] draws nothing; the series stays in the legend
  # @param legend_type [Symbol] the legend icon: `:rect`, `:line`, `:square`, `:circle`, ... or `:none`
  # @param tooltip_type [Symbol, nil] `:none` drops the series from the tooltip
  # @param x_axis_id [Object] the x axis the bar is drawn against
  # @param y_axis_id [Object] the y axis the bar is drawn against
  # @param name [String, nil] the name in the tooltip and the legend (the data key by default)
  # @param unit [String, nil] appended to the value in the tooltip
  # @param is_animation_active [Boolean, Symbol, nil] accepted for parity with recharts and ignored: the settled chart is drawn
  # @param attrs [Hash] attributes of every rectangle; `class:` and `id:` of the group
  # @raise [ArgumentError] on an invalid `radius:`, `legend_type:`, `tooltip_type:` or `active_bar:`, or no `data_key:`
  def initialize(data_key:, stack_id: nil, fill: nil, stroke: nil, radius: nil, bar_size: nil, max_bar_size: nil, min_point_size: 0, background: false, label: false,
                 active_bar: false, hide: false, legend_type: :rect, tooltip_type: nil, x_axis_id: 0, y_axis_id: 0, name: nil, unit: nil,
                 is_animation_active: nil, **attrs)
    raise ArgumentError, "active_bar: only false is ported (got #{active_bar.inspect})" unless active_bar == false
    unless radius.nil? || radius.is_a?(Numeric) || (radius.is_a?(Array) && radius.size <= 4 && radius.all?(Numeric))
      raise ArgumentError, "radius: must be a number or an Array of up to four numbers (got #{radius.inspect})"
    end

    @options = { data_key: data_key, stack_id: stack_id, fill: fill, stroke: stroke, radius: radius, bar_size: bar_size, max_bar_size: max_bar_size,
                 min_point_size: min_point_size, background: background, label: label, hide: hide, legend_type: choice(:legend_type, legend_type, LEGEND_TYPES),
                 tooltip_type: tooltip_type_choice(tooltip_type), x_axis_id: x_axis_id, y_axis_id: y_axis_id, name: name, unit: unit, attrs: attrs }.freeze
    initialize_series
    super()
  end

  private

  def tooltip_type_choice(value)
    return value if value.nil?

    choice(:tooltip_type, value, %i[none])
  end
end
