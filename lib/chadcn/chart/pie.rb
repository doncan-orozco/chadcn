# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- cx and cy are the center vocabulary of recharts

# recharts' `Pie` (polar/Pie.js): one series of sectors sized by value, each with its share of the turn between `start_angle` and
# `end_angle`. Declared in a {Chadcn::Chart::PieChart}; it renders nothing where it is written. A {Chadcn::Chart::Cell} in its block
# styles the sector at the same index, a {Chadcn::Chart::LabelList} labels the sectors and a {Chadcn::Chart::Label} writes text at the
# center of the chart (the total of a donut).
#
# Every attribute other than `class:` lands on each sector (`fill:`, `stroke:` and `stroke_width:` are keywords for the common ones);
# `class:` lands on the group and on each sector, and `id:` names the pie. A data row's own `fill`, `stroke`, `name` and `opacity`
# override the pie's on its sector.
#
# @example
#   chart.pie(data: rows, data_key: :visitors, name_key: :browser, inner_radius: 60, stroke_width: 5)
class Chadcn::Chart::Pie < Chadcn::Chart::Declaration
  include Chadcn::Chart::Polar::Series

  # @api private
  KIND = :pie

  # @param data [Array<Hash>, nil] the rows of the pie; the chart's `data:` when nil or empty
  # @param data_key [Symbol, String, #call] the key of each row whose value sizes the sector, or a callable that receives the row
  # @param name_key [Symbol, String, #call] the key of each row that names the sector (the row index when it has none)
  # @param name [String, nil] the name of the pie in the tooltip and the legend
  # @param cx [Numeric, String] center x, px or a percent of the plot width
  # @param cy [Numeric, String] center y, px or a percent of the plot height
  # @param inner_radius [Numeric, String] px or a percent of the largest circle in the plot (a donut hole)
  # @param outer_radius [Numeric, String] px or a percent of the largest circle in the plot
  # @param start_angle [Numeric] degrees, counterclockwise from 3 o'clock
  # @param end_angle [Numeric] degrees; below `start_angle` the pie runs clockwise
  # @param padding_angle [Numeric] gap between sectors, degrees (ignored for a single sector)
  # @param corner_radius [Numeric, String, nil] rounds the corners of every sector, px (a text keeps its leading number, as `parseFloat`)
  # @param min_angle [Numeric] the least width of every sector that has a value, degrees
  # @param fill [String] the fill of a sector whose row and cell give none
  # @param stroke [String] the stroke of a sector
  # @param stroke_width [Numeric, nil]
  # @param label [Boolean, Hash] `true` writes the value beside each sector; a Hash adds `offset_radius:` (px past the rim, 20 by default) and the
  #   attributes of the text; a Hash with a `position:` is a {Chadcn::Chart::LabelList} instead
  # @param label_line [Boolean, Hash] the line from a sector to its label; a Hash gives its attributes
  # @param root_tab_index [Integer] the `tabindex` of the group
  # @param legend_type [Symbol] the legend icon
  # @param tooltip_type [Symbol, nil] `:none` drops the pie from the tooltip
  # @param hide [Boolean] draws nothing; the pie stays in the legend
  # @param active_shape [Object] only nil or false is ported (a custom active shape is a React element); anything else raises
  # @param is_animation_active [Boolean, Symbol, nil] accepted for parity with recharts and ignored: the settled chart is drawn
  # @param attrs [Hash] attributes of every sector; `class:` and `id:` of the group
  # @raise [ArgumentError] on an invalid `data:`, angle, radius, `legend_type:`, `tooltip_type:` or `active_shape:`
  def initialize(data: nil, data_key: :value, name_key: :name, name: nil, cx: "50%", cy: "50%", inner_radius: 0, outer_radius: "80%", start_angle: 0,
                 end_angle: 360, padding_angle: 0, corner_radius: nil, min_angle: 0, fill: "#808080", stroke: "#fff", stroke_width: nil, label: false,
                 label_line: true, root_tab_index: 0, legend_type: :rect, tooltip_type: nil, hide: false, active_shape: nil, is_animation_active: nil,
                 **attrs)
    raise ArgumentError, "active_shape: is not ported (got #{active_shape.inspect})" unless active_shape.nil? || active_shape == false
    raise ArgumentError, "data: must be an Array of Hashes (got #{data.class})" unless data.nil? || (data.is_a?(Array) && data.all?(Hash))

    { start_angle: start_angle, end_angle: end_angle, padding_angle: padding_angle, min_angle: min_angle }.each { |key, value| degrees!(key, value) }
    @options = { data: data, data_key: data_key, name_key: name_key, name: name, cx: cx, cy: cy, inner_radius: inner_radius, outer_radius: outer_radius,
                 start_angle: start_angle, end_angle: end_angle, padding_angle: padding_angle, corner_radius: corner_radius, min_angle: min_angle,
                 fill: fill, stroke: stroke, stroke_width: stroke_width, label: label, label_line: label_line, root_tab_index: root_tab_index,
                 legend_type: choice(:legend_type, legend_type, LEGEND_TYPES), tooltip_type: tooltip_type_choice(tooltip_type), hide: hide,
                 attrs: attrs }.freeze
    initialize_series
    super()
  end

  # @api private
  # @return [Boolean] whether the pie writes its own labels (lines and text beside the sectors) instead of a label list
  def own_labels? = options[:label] && !(options[:label].is_a?(Hash) && options[:label].key?(:position))

  private

  def degrees!(name, value)
    raise ArgumentError, "#{name}: must be a number of degrees (got #{value.inspect})" unless value.is_a?(Numeric) && value.real? && value.finite?
  end

  def tooltip_type_choice(value)
    return value if value.nil?

    choice(:tooltip_type, value, %i[none])
  end
end

# rubocop:enable Naming/MethodParameterName
