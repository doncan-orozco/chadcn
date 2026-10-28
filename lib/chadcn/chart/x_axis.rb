# frozen_string_literal: true

# recharts' `XAxis` (cartesian/XAxis.js): the horizontal axis. Declaring one shows it (recharts' implicit axis, the one a chart has when
# none is declared, is hidden). It renders nothing where it is written; the chart draws it, with its ticks and labels, and lets its
# domain, scale and size shape the plot.
#
# `class:` lands on the axis group; every other attribute lands on the axis line, the tick lines and the labels.
#
# @example
#   chart.x_axis(data_key: :month, tick_line: false, tick_margin: 10, axis_line: false, tick_formatter: { slice: [ 0, 3 ] })
class Chadcn::Chart::XAxis < Chadcn::Chart::Declaration
  # @api private
  # @return [Chadcn::Chart::Cartesian::AxisSettings]
  attr_reader :settings

  # @param data_key [Symbol, String, #call, nil] the key of each data row that is the category (or the number, for `type: :number`)
  # @param type [Symbol] `:category`, `:number` or `:auto` (by the chart layout)
  # @param hide [Boolean] declared but not drawn, and takes no room
  # @param height [Numeric] the room the axis takes, px
  # @param orientation [Symbol] `:bottom` or `:top`
  # @param tick [Boolean, Hash] draw the labels; a Hash gives their attributes (`fill:`, `font_size:` ...)
  # @param tick_line [Boolean, Hash] draw a line at every tick; a Hash gives its attributes
  # @param axis_line [Boolean, Hash] draw the axis line; a Hash gives its attributes
  # @param tick_size [Numeric] length of a tick line, px
  # @param tick_margin [Numeric] gap between the tick line and its label, px
  # @param tick_count [Integer] about this many ticks on a number axis
  # @param tick_formatter [#call, Hash, Symbol, nil] `(value, index)` returning the label, or `{ slice: [ start, stop ] }`, `:locale` or `:percent`
  # @param interval [Integer, Symbol] which labels to draw: a number skips that many between two, or `:preserve_end` (the default),
  #   `:preserve_start`, `:preserve_start_end`, `:equidistant_preserve_start`, `:equidistant_preserve_end`
  # @param min_tick_gap [Numeric] the least room between two labels, px
  # @param mirror [Boolean] draw the axis inside the plot
  # @param reversed [Boolean] reverse the direction of the scale
  # @param padding [Hash, nil] `left:` and `right:`, px
  # @param domain [Array, #call, nil] `[min, max]`: a bound is a number, `:auto`, `:data_min`, `:data_max`, `"dataMin - 10"` or a callable; or one callable
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
  # @param x_axis_id [Object] the id series refer to with `x_axis_id:`
  # @param name [String, nil]
  # @param attrs [Hash] attributes of the axis line, the tick lines and the labels; `class:` of the axis group
  # @raise [ArgumentError] on a value outside the supported ones
  def initialize(data_key: nil, type: :category, hide: false, height: 30, orientation: :bottom, tick: true, tick_line: true, axis_line: true, tick_size: 6,
                 tick_margin: 2, tick_count: 5, tick_formatter: nil, interval: :preserve_end, min_tick_gap: 5, mirror: false, reversed: false,
                 padding: { left: 0, right: 0 }, domain: nil, allow_decimals: true, allow_duplicated_category: true, allow_data_overflow: false,
                 include_hidden: false, nice_ticks: :auto, angle: 0, unit: nil, ticks: nil, scale: :auto, stroke: "#666", x_axis_id: 0, name: nil, **attrs)
    @settings = Chadcn::Chart::Cartesian::AxisSettings.build(
      :x,
      data_key: data_key, type: type, hide: hide, size: height, orientation: orientation, tick: tick, tick_line: tick_line, axis_line: axis_line,
      tick_size: tick_size, tick_margin: tick_margin, tick_count: tick_count, tick_formatter: tick_formatter, interval: interval, min_tick_gap: min_tick_gap,
      mirror: mirror, reversed: reversed, padding: padding, domain: domain, allow_decimals: allow_decimals,
      allow_duplicated_category: allow_duplicated_category, allow_data_overflow: allow_data_overflow, include_hidden: include_hidden, nice_ticks: nice_ticks,
      angle: angle, unit: unit, ticks: ticks, scale: scale, stroke: stroke, axis_id: x_axis_id, name: name, attrs: attrs
    )
    super()
  end
end
