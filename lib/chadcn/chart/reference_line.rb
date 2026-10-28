# frozen_string_literal: true

# recharts' `ReferenceLine` (cartesian/ReferenceLine.js): a line across the plot at a value of an axis, `y:` for a horizontal line and
# `x:` for a vertical one. It renders nothing where it is written; the chart draws it above the areas and bars (the layer of the lines).
#
# With `if_overflow: :discard` (the default) a line outside the axis range is not drawn; `:extend_domain` widens the axis to include it.
# `class:` lands on the group, every other attribute on the line.
#
# @example
#   chart.reference_line(y: 200, stroke: "var(--color-desktop)", stroke_dasharray: "4 4")
class Chadcn::Chart::ReferenceLine < Chadcn::Chart::Declaration
  # Values of `if_overflow:`.
  OVERFLOWS = %i[discard hidden visible extend_domain].freeze

  # @api private
  # @return [Hash{Symbol => Object}] the keywords with recharts' defaults applied, frozen
  attr_reader :options

  # @param x [Numeric, String, nil] the value on the x axis of a vertical line
  # @param y [Numeric, String, nil] the value on the y axis of a horizontal line
  # @param stroke [String]
  # @param stroke_width [Numeric]
  # @param stroke_dasharray [String, nil]
  # @param fill [String]
  # @param fill_opacity [Numeric]
  # @param if_overflow [Symbol] `:discard`, `:hidden`, `:visible` or `:extend_domain`
  # @param x_axis_id [Object] the x axis the line is drawn against
  # @param y_axis_id [Object] the y axis the line is drawn against
  # @param attrs [Hash] attributes of the line; `class:` of the group
  # @raise [ArgumentError] on an `if_overflow:` outside its values, or without `x:` or `y:`
  def initialize(x: nil, y: nil, stroke: "#ccc", stroke_width: 1, stroke_dasharray: nil, fill: "none", fill_opacity: 1, if_overflow: :discard, x_axis_id: 0,
                 y_axis_id: 0, **attrs)
    raise ArgumentError, "a reference line needs x: or y:" if x.nil? && y.nil?
    raise ArgumentError, "if_overflow: must be one of #{OVERFLOWS.map(&:inspect).join(', ')} (got #{if_overflow.inspect})" unless if_overflow.respond_to?(:to_sym) && OVERFLOWS.include?(if_overflow.to_sym)

    @options = { x: x, y: y, stroke: stroke, stroke_width: stroke_width, stroke_dasharray: stroke_dasharray, fill: fill, fill_opacity: fill_opacity,
                 if_overflow: if_overflow.to_sym, x_axis_id: x_axis_id, y_axis_id: y_axis_id, attrs: attrs }.freeze
    super()
  end
end
