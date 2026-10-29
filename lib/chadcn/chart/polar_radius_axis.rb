# frozen_string_literal: true

# recharts' `PolarRadiusAxis` (polar/PolarRadiusAxis.js): the axis that runs from the center of a radar or radial bar chart outwards at
# `angle`, with a tick at every radius. It renders nothing where it is written; the chart draws it. In a radar chart its scale decides
# the radius of every point and of every ring of the grid. recharts' polar axes do not read `hide`, so it is not a keyword here.
#
# `class:` lands on the axis group; every other attribute lands on the axis line and the labels.
#
# @example
#   chart.polar_radius_axis(angle: 90, domain: [ 0, 400 ], tick_count: 4)
class Chadcn::Chart::PolarRadiusAxis < Chadcn::Chart::Declaration
  # @api private
  # @return [Chadcn::Chart::Polar::AxisSettings]
  attr_reader :settings

  # @param data_key [Symbol, String, #call, nil] the key of each data row that is the category (or the number, for `type: :number`)
  # @param type [Symbol] `:category`, `:number` or `:auto` (by the chart: the radius axis of a radial bar chart holds the categories)
  # @param angle [Numeric] where the axis runs, degrees counterclockwise from 3 o'clock
  # @param tick_count [Integer] about this many ticks on a number axis
  # @param tick [Boolean, Hash] draw the labels; a Hash gives their attributes (`fill:`, `font_size:` ...)
  # @param axis_line [Boolean, Hash] draw the axis line; a Hash gives its attributes
  # @param tick_formatter [#call, Hash, Symbol, nil] `(value, index)` returning the label, or `{ slice: [ start, stop ] }`, `:locale` or `:percent`
  # @param orientation [Symbol] `:left`, `:right` or `:middle`, the side of the axis the labels hang on
  # @param reversed [Boolean] reverse the direction of the scale
  # @param domain [Array, nil] `[min, max]` of a number axis: a bound is a number, `:auto`, `:data_min`, `:data_max` or `"dataMin - 10"`
  # @param allow_decimals [Boolean] whether the ticks of a number axis may be decimals
  # @param stroke [String] color of the axis line and the labels
  # @param radius_axis_id [Object] the id series refer to with `radius_axis_id:`
  # @param attrs [Hash] attributes of the axis line and the labels; `class:` of the axis group
  # @raise [ArgumentError] on a value outside the supported ones
  def initialize(data_key: nil, type: :auto, angle: 0, tick_count: 5, tick: true, axis_line: true, tick_formatter: nil, orientation: :right,
                 reversed: false, domain: nil, allow_decimals: false, stroke: "#ccc", radius_axis_id: 0, **attrs)
    @settings = Chadcn::Chart::Polar::AxisSettings.build(
      :radius, data_key: data_key, type: type, domain: domain, reversed: reversed, allow_decimals: allow_decimals, tick_count: tick_count,
               tick_formatter: tick_formatter, tick: tick, tick_line: false, axis_line: axis_line, axis_line_type: :polygon, tick_size: 0,
               orientation: orientation, angle: angle, stroke: stroke, axis_id: radius_axis_id, attrs: attrs
    )
    super()
  end
end
