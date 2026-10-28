# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- cx and cy are the center vocabulary of recharts

# The `d` strings of a sector, copied from recharts shape/Sector.js including the whitespace of the source template literals (React
# DOM prints it as is, so the strings must match character for character), with the numbers rounded like recharts'
# `roundTemplateLiteral`. SVG arc flags are given as booleans and printed as 0 or 1.
#
# @api private
module Chadcn::Chart::Shape::Arc::Templates
  # Decimals of every number in a sector path (recharts util/round.js default).
  PATH_DIGITS = 4

  OUTER_ARC = [ "M ", ",", "\n    A ", ",", ",0,\n    ", ",", ",\n    ", ",", "\n  " ].freeze
  INNER_ARC = [ "L ", ",", "\n            A ", ",", ",0,\n            ", ",", ",\n            ", ",", " Z" ].freeze
  CENTER_CLOSE = [ "L ", ",", " Z" ].freeze
  FORCED_CORNERS = [ "M ", ",", "\n        a", ",", ",0,0,1,", ",0\n        a", ",", ",0,0,1,", ",0\n      " ].freeze
  OUTER_CORNERS = [
    "M ", ",", "\n    A", ",", ",0,0,", ",", ",", "\n    A", ",", ",0,", ",", ",", ",", "\n    A", ",", ",0,0,", ",", ",", "\n  "
  ].freeze
  INNER_CORNERS = [
    "L", ",", "\n      A", ",", ",0,0,", ",", ",", "\n      A", ",", ",0,", ",", ",", ",", "\n      A", ",", ",0,0,", ",", ",", "Z"
  ].freeze
  CENTER_CORNERS = [ "L", ",", "Z" ].freeze

  private_constant :PATH_DIGITS, :OUTER_ARC, :INNER_ARC, :CENTER_CLOSE, :FORCED_CORNERS, :OUTER_CORNERS, :INNER_CORNERS, :CENTER_CORNERS

  class << self
    # The arc along the outer radius, from `from` to `to`, opening the path.
    #
    # @api private
    # @param from [Array(Float, Float)]
    # @param to [Array(Float, Float)]
    # @param radius [Float]
    # @param large_arc [Boolean]
    # @param sweep [Boolean]
    # @return [String]
    def outer_arc(from:, to:, radius:, large_arc:, sweep:)
      fill(OUTER_ARC, *from, radius, radius, flag(large_arc), flag(sweep), *to)
    end

    # The line to, and the arc along, the inner radius, closing the path.
    #
    # @api private
    # @param from [Array(Float, Float)]
    # @param to [Array(Float, Float)]
    # @param radius [Float]
    # @param large_arc [Boolean]
    # @param sweep [Boolean]
    # @return [String]
    def inner_arc(from:, to:, radius:, large_arc:, sweep:)
      fill(INNER_ARC, *from, radius, radius, flag(large_arc), flag(sweep), *to)
    end

    # The straight edge back to the center, closing a sector without a hole.
    #
    # @api private
    # @return [String]
    def center_close(cx, cy) = fill(CENTER_CLOSE, cx, cy)

    # The two corner arcs of a sector too short for its corners, when they are forced.
    #
    # @api private
    # @param start_line [Array(Float, Float)]
    # @param corner [Float] corner radius
    # @return [String]
    def forced_corners(start_line:, corner:)
      fill(FORCED_CORNERS, *start_line, corner, corner, corner * 2, corner, corner, -corner * 2)
    end

    # The outer edge of a rounded sector: corner, outer arc, corner.
    #
    # @api private
    # @param start_line [Array(Float, Float)] where the start radius line meets its corner circle
    # @param start_circle [Array(Float, Float)] where the start corner circle meets the outer arc
    # @param end_circle [Array(Float, Float)]
    # @param end_line [Array(Float, Float)]
    # @param corner [Float] corner radius
    # @param radius [Float] outer radius
    # @param large_arc [Boolean] the outer arc spans more than half a turn
    # @param corner_sweep [Boolean] direction of the corner arcs
    # @return [String]
    def outer_corners(start_line:, start_circle:, end_circle:, end_line:, corner:, radius:, large_arc:, corner_sweep:)
      fill(OUTER_CORNERS, *start_line, corner, corner, flag(corner_sweep), *start_circle, radius, radius, flag(large_arc),
           flag(corner_sweep), *end_circle, corner, corner, flag(corner_sweep), *end_line)
    end

    # The inner edge of a rounded sector, walked backwards: corner, inner arc, corner.
    #
    # @api private
    # @param end_line [Array(Float, Float)]
    # @param end_circle [Array(Float, Float)]
    # @param start_circle [Array(Float, Float)]
    # @param start_line [Array(Float, Float)]
    # @param corner [Float] corner radius
    # @param radius [Float] inner radius
    # @param large_arc [Boolean] the inner arc spans more than half a turn
    # @param corner_sweep [Boolean] direction of the corner arcs
    # @param arc_sweep [Boolean] direction of the inner arc
    # @return [String]
    def inner_corners(end_line:, end_circle:, start_circle:, start_line:, corner:, radius:, large_arc:, corner_sweep:, arc_sweep:)
      fill(INNER_CORNERS, *end_line, corner, corner, flag(corner_sweep), *end_circle, radius, radius, flag(large_arc),
           flag(arc_sweep), *start_circle, corner, corner, flag(corner_sweep), *start_line)
    end

    # The edge back to the center of a rounded sector without a hole.
    #
    # @api private
    # @return [String]
    def center_corners(cx, cy) = fill(CENTER_CORNERS, cx, cy)

    # Sector.js closes a ring too narrow for its corners on the center with the coordinates unrounded.
    #
    # @api private
    # @return [String]
    def center_corners_unrounded(cx, cy)
      "#{CENTER_CORNERS[0]}#{Chadcn::Chart::Shape::Number.format(cx)},#{Chadcn::Chart::Shape::Number.format(cy)}#{CENTER_CORNERS[2]}"
    end

    private

    def flag(condition) = condition ? 1 : 0

    # Interleaves template pieces and values, rounding the numbers.
    def fill(template, *values)
      out = +template.first
      values.each_with_index do |value, index|
        out << Chadcn::Chart::Shape::Number.format(Chadcn::Chart::Shape::Number.round(value, PATH_DIGITS)) << template[index + 1]
      end
      out
    end
  end
end

# rubocop:enable Naming/MethodParameterName
