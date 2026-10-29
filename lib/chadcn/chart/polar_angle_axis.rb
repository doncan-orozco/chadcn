# frozen_string_literal: true

# recharts' `PolarAngleAxis` (polar/PolarAngleAxis.js): the axis around a radar or radial bar chart, with a tick at every category (or number)
# and the axis line through them. It renders nothing where it is written; the chart draws it, with its ticks and labels, and lets its
# domain and scale shape the series. Declaring one in a radar chart gives the chart its category labels.
#
# `class:` lands on the axis group; every other attribute lands on the axis line, the tick lines and the labels. recharts' polar axes do not
# read `hide`, so it is not a keyword here.
#
# @example
#   chart.polar_angle_axis(data_key: :month)
class Chadcn::Chart::PolarAngleAxis < Chadcn::Chart::Declaration
  # @api private
  # @return [Chadcn::Chart::Polar::AxisSettings]
  attr_reader :settings

  # @param data_key [Symbol, String, #call, nil] the key of each data row that is the category (or the number, for `type: :number`)
  # @param type [Symbol] `:category`, `:number` or `:auto` (by the chart: the angle axis of a radar chart holds the categories)
  # @param tick [Boolean, Hash] draw the labels; a Hash gives their attributes (`fill:`, `font_size:` ...)
  # @param tick_line [Boolean, Hash] draw a line at every tick; a Hash gives its attributes
  # @param axis_line [Boolean, Hash] draw the axis line; a Hash gives its attributes
  # @param axis_line_type [Symbol] `:polygon` (through the ticks) or `:circle`
  # @param tick_size [Numeric] length of a tick line, px
  # @param tick_formatter [#call, Hash, Symbol, nil] `(value, index)` returning the label, or `{ slice: [ start, stop ] }`, `:locale` or `:percent`
  # @param orientation [Symbol] `:outer` (labels outside the ring) or `:inner`
  # @param reversed [Boolean] reverse the direction of the scale
  # @param domain [Array, nil] `[min, max]` of a number axis: a bound is a number, `:auto`, `:data_min`, `:data_max` or `"dataMin - 10"`
  # @param allow_decimals [Boolean] whether the ticks of a number axis may be decimals
  # @param stroke [String, nil] color of the labels (recharts gives the axis line none, so the CSS decides)
  # @param angle_axis_id [Object] the id series refer to with `angle_axis_id:`
  # @param attrs [Hash] attributes of the axis line, the tick lines and the labels; `class:` of the axis group
  # @raise [ArgumentError] on a value outside the supported ones
  def initialize(data_key: nil, type: :auto, tick: true, tick_line: true, axis_line: true, axis_line_type: :polygon, tick_size: 8, tick_formatter: nil,
                 orientation: :outer, reversed: false, domain: nil, allow_decimals: false, stroke: nil, angle_axis_id: 0, **attrs)
    @settings = Chadcn::Chart::Polar::AxisSettings.build(
      :angle, data_key: data_key, type: type, domain: domain, reversed: reversed, allow_decimals: allow_decimals, tick_count: nil,
              tick_formatter: tick_formatter, tick: tick, tick_line: tick_line, axis_line: axis_line, axis_line_type: axis_line_type,
              tick_size: tick_size, orientation: orientation, angle: 0, stroke: stroke, axis_id: angle_axis_id, attrs: attrs
    )
    super()
  end
end
