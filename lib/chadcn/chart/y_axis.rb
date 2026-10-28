# frozen_string_literal: true

# recharts' `YAxis` (cartesian/YAxis.js): the vertical axis, with a number scale by default. Declaring one shows it (recharts' implicit axis
# is hidden). It renders nothing where it is written; the chart draws it. See {Chadcn::Chart::XAxis} for the keywords they share.
#
# @example
#   chart.y_axis(tick_line: false, axis_line: false, tick_margin: 8, tick_count: 4)
class Chadcn::Chart::YAxis < Chadcn::Chart::Declaration
  # @api private
  # @return [Chadcn::Chart::Cartesian::AxisSettings]
  attr_reader :settings

  # @param data_key [Symbol, String, #call, nil] the key of each data row that is the category (or the number, for `type: :number`)
  # @param type [Symbol] `:number` (the default), `:category` or `:auto` (by the chart layout)
  # @param hide [Boolean] declared but not drawn, and takes no room
  # @param width [Numeric] the room the axis takes, px
  # @param orientation [Symbol] `:left` or `:right`
  # @param tick [Boolean, Hash] draw the labels; a Hash gives their attributes
  # @param tick_line [Boolean, Hash] draw a line at every tick; a Hash gives its attributes
  # @param axis_line [Boolean, Hash] draw the axis line; a Hash gives its attributes
  # @param tick_size [Numeric] length of a tick line, px
  # @param tick_margin [Numeric] gap between the tick line and its label, px
  # @param tick_count [Integer] about this many ticks on a number axis
  # @param tick_formatter [#call, Hash, Symbol, nil] `(value, index)` returning the label, or `{ slice: [ start, stop ] }`, `:locale` or `:percent`
  # @param interval [Integer, Symbol] which labels to draw, see {Chadcn::Chart::XAxis}
  # @param min_tick_gap [Numeric] the least room between two labels, px
  # @param mirror [Boolean] draw the axis inside the plot
  # @param reversed [Boolean] reverse the direction of the scale
  # @param padding [Hash, nil] `top:` and `bottom:`, px
  # @param domain [Array, #call, nil] `[min, max]`, `[0, :auto]` by default; see {Chadcn::Chart::XAxis}
  # @param allow_decimals [Boolean] whether the ticks of a number axis may be decimals
  # @param allow_duplicated_category [Boolean] whether a category may appear more than once
  # @param allow_data_overflow [Boolean] draw data outside an explicit `domain` (clipped to the plot) instead of widening the domain
  # @param include_hidden [Boolean] let hidden series count toward the domain
  # @param nice_ticks [Symbol] `:auto`, `:adaptive`, `:snap125` or `:none`
  # @param angle [Numeric] rotate the labels, degrees
  # @param unit [String, nil] appended to every label
  # @param ticks [Array, nil] the ticks to draw
  # @param scale [Symbol] `:auto` or `:linear` (the other scales of recharts are not ported)
  # @param stroke [String] color of the axis line, the tick lines and the labels
  # @param y_axis_id [Object] the id series refer to with `y_axis_id:`
  # @param name [String, nil]
  # @param attrs [Hash] attributes of the axis line, the tick lines and the labels; `class:` of the axis group
  # @raise [ArgumentError] on a value outside the supported ones
  def initialize(data_key: nil, type: :number, hide: false, width: 60, orientation: :left, tick: true, tick_line: true, axis_line: true, tick_size: 6,
                 tick_margin: 2, tick_count: 5, tick_formatter: nil, interval: :preserve_end, min_tick_gap: 5, mirror: false, reversed: false,
                 padding: { top: 0, bottom: 0 }, domain: [ 0, :auto ], allow_decimals: true, allow_duplicated_category: true, allow_data_overflow: false,
                 include_hidden: false, nice_ticks: :auto, angle: 0, unit: nil, ticks: nil, scale: :auto, stroke: "#666", y_axis_id: 0, name: nil, **attrs)
    @settings = Chadcn::Chart::Cartesian::AxisSettings.build(
      :y, data_key: data_key, type: type, hide: hide, size: width, orientation: orientation, tick: tick, tick_line: tick_line, axis_line: axis_line,
      tick_size: tick_size, tick_margin: tick_margin, tick_count: tick_count, tick_formatter: tick_formatter, interval: interval, min_tick_gap: min_tick_gap,
      mirror: mirror, reversed: reversed, padding: padding, domain: domain, allow_decimals: allow_decimals,
      allow_duplicated_category: allow_duplicated_category, allow_data_overflow: allow_data_overflow, include_hidden: include_hidden, nice_ticks: nice_ticks,
      angle: angle, unit: unit, ticks: ticks, scale: scale, stroke: stroke, axis_id: y_axis_id, name: name, attrs: attrs
    )
    super()
  end
end
