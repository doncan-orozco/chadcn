# frozen_string_literal: true

# recharts' `RadialBar` (polar/RadialBar.js): one series of arcs, each as long as its value along the angle axis and as thick as a bar,
# stacked with the radial bars that share its `stack_id`. Declared in a {Chadcn::Chart::RadialBarChart}; it renders nothing where it is
# written. A {Chadcn::Chart::Cell} in its block styles the arc at the same index, a {Chadcn::Chart::LabelList} labels the arcs.
#
# `class:` lands on the group (`recharts-area`, which is recharts' own name for it); every other attribute lands on each arc, where a data
# row's own `fill`, `stroke`, `name` and `opacity` and its cell win.
#
# @example
#   chart.radial_bar(data_key: :desktop, stack_id: "a", corner_radius: 5, fill: "var(--color-desktop)", class: "stroke-transparent stroke-2")
class Chadcn::Chart::RadialBar < Chadcn::Chart::Declaration
  include Chadcn::Chart::Polar::Series

  # @api private
  KIND = :radial_bar

  # @param data_key [Symbol, String, #call] the key of each data row whose value is the length of the arc, or a callable that receives the row
  # @param stack_id [String, Symbol, Integer, nil] radial bars with the same id are stacked, in order of declaration
  # @param background [Boolean, Hash] draws an arc behind every bar, spanning the whole angle (`#eee`); a Hash gives its attributes
  # @param corner_radius [Numeric, String] rounds the corners of every arc, px (a text keeps its integer part, as `parseInt`)
  # @param corner_is_external [Boolean] the corners bulge outwards instead of being cut into the arc
  # @param force_corner_radius [Boolean] draw the corners even where the arc is too short for them
  # @param min_point_size [Numeric] the least an arc turns, degrees
  # @param bar_size [Numeric, String, nil] thickness of the arc (a share of the band is not ported for polar bars: a number)
  # @param max_bar_size [Numeric, nil] the thickest the arc may be
  # @param fill [String, nil] the fill of an arc whose row and cell give none
  # @param stroke [String, nil]
  # @param stroke_width [Numeric, nil]
  # @param label [Boolean, Hash] `true` (or a Hash of {Chadcn::Chart::LabelList} keywords) is a label list on the radial bar
  # @param legend_type [Symbol] the legend icon
  # @param tooltip_type [Symbol, nil] `:none` drops the series from the tooltip
  # @param hide [Boolean] draws nothing
  # @param name [String, nil] the name in the tooltip (the data key by default)
  # @param angle_axis_id [Object] the angle axis the arcs are measured on
  # @param radius_axis_id [Object] the radius axis the arcs are placed on
  # @param is_animation_active [Boolean, Symbol, nil] accepted for parity with recharts and ignored: the settled chart is drawn
  # @param attrs [Hash] attributes of every arc; `class:` and `id:` of the group
  # @raise [ArgumentError] on an invalid `legend_type:` or `tooltip_type:`, or a missing `data_key:`
  def initialize(data_key:, stack_id: nil, background: false, corner_radius: 0, corner_is_external: false, force_corner_radius: false, min_point_size: 0,
                 bar_size: nil, max_bar_size: nil, fill: nil, stroke: nil, stroke_width: nil, label: false, legend_type: :rect, tooltip_type: nil,
                 hide: false, name: nil, angle_axis_id: 0, radius_axis_id: 0, is_animation_active: nil, **attrs)
    @options = { data_key: data_key, stack_id: stack_id, background: background, corner_radius: corner_radius, corner_is_external: corner_is_external,
                 force_corner_radius: force_corner_radius, min_point_size: min_point_size, bar_size: bar_size, max_bar_size: max_bar_size, fill: fill,
                 stroke: stroke, stroke_width: stroke_width, label: label, legend_type: choice(:legend_type, legend_type, LEGEND_TYPES),
                 tooltip_type: tooltip_type_choice(tooltip_type), hide: hide, name: name, angle_axis_id: angle_axis_id, radius_axis_id: radius_axis_id,
                 attrs: attrs }.freeze
    initialize_series
    super()
  end

  # The color the legend and the tooltip show for the radial bar: its `fill`.
  #
  # @api private
  # @return [String, nil]
  def legend_color = options[:fill]

  private

  def tooltip_type_choice(value)
    return value if value.nil?

    choice(:tooltip_type, value, %i[none])
  end
end
