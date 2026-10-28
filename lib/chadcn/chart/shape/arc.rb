# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# Circular sectors and pie angles of recharts: the path of shape/Sector.js (`getSectorPath`, `getSectorWithCorner`,
# `getTangentCircle`) and the angle layout of polar/Pie.js `computePieSectors`. Angles are degrees, counterclockwise from 3 o'clock,
# as in recharts.
#
# @api private
module Chadcn::Chart::Shape::Arc
  # recharts util/PolarUtils.js RADIAN.
  RADIAN = Math::PI / 180
  # recharts clamps a full turn so the start and end points of an arc do not coincide (Sector.js `getDeltaAngle`).
  MAX_SECTOR_ANGLE = 359.999
  # Decimals of every number in a sector path (recharts util/round.js default).
  PATH_DIGITS = 4

  # The pieces of the `d` strings, copied from recharts shape/Sector.js including the whitespace of the source template literals
  # (React DOM prints it as is, so the strings must match character for character).
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

  private_constant :OUTER_ARC, :INNER_ARC, :CENTER_CLOSE, :FORCED_CORNERS, :OUTER_CORNERS, :INNER_CORNERS, :CENTER_CORNERS

  class << self
    # The `d` attribute of a sector (recharts `Sector`), or nil when it draws nothing (outer radius below the inner one, or equal
    # start and end angles).
    #
    # @api private
    # @param cx [Numeric] center x
    # @param cy [Numeric] center y
    # @param inner_radius [Numeric]
    # @param outer_radius [Numeric]
    # @param start_angle [Numeric] degrees
    # @param end_angle [Numeric] degrees
    # @param corner_radius [Numeric, String] pixels, or a percentage of the ring width ("50%"); rounded corners need a positive value
    # @param force_corner_radius [Boolean] draw the corner circles even when the arc is too short for them
    # @param corner_is_external [Boolean] corners bulge outwards instead of being cut into the sector
    # @return [String, nil]
    def sector_path(cx: 0, cy: 0, inner_radius: 0, outer_radius: 0, start_angle: 0, end_angle: 0, corner_radius: 0,
                    force_corner_radius: false, corner_is_external: false)
      return nil if outer_radius < inner_radius || start_angle == end_angle

      delta_radius = outer_radius - inner_radius
      radius = percent_value(corner_radius, delta_radius)
      if radius.positive? && (start_angle - end_angle).abs < 360
        sector_with_corner(cx.to_f, cy.to_f, inner_radius.to_f, outer_radius.to_f, [ radius, delta_radius / 2.0 ].min,
                           force_corner_radius, corner_is_external, start_angle.to_f, end_angle.to_f)
      else
        plain_sector(cx.to_f, cy.to_f, inner_radius.to_f, outer_radius.to_f, start_angle.to_f, end_angle.to_f)
      end
    end

    # The angle layout of a pie (recharts `computePieSectors`): consecutive sectors sized by value, each at least `min_angle` wide,
    # separated by `pad_angle`. Non-numeric values count as 0; with no positive total there is nothing to lay out.
    #
    # @api private
    # @param values [Array<Numeric, nil>]
    # @param start_angle [Numeric] degrees
    # @param end_angle [Numeric] degrees; below `start_angle` the pie runs clockwise
    # @param pad_angle [Numeric] gap between sectors (ignored for a single value)
    # @param min_angle [Numeric] minimum width of every non-zero sector
    # @return [Array<Hash>] one `{ start_angle:, end_angle:, mid_angle:, percent: }` per value, [] when the total is not positive
    def pie(values, start_angle: 0, end_angle: 360, pad_angle: 0, min_angle: 0)
      numbers = values.map { |value| number_or_zero(value) }
      min = min_angle.abs
      delta = delta_angle(start_angle, end_angle, 360)
      direction = math_sign(delta)
      padding = numbers.size <= 1 ? 0 : pad_angle
      non_zero = numbers.count { |value| value != 0 }
      total_padding = (delta.abs >= 360 ? non_zero : non_zero - 1) * padding
      real_total = delta.abs - (non_zero * min) - total_padding
      sum = numbers.sum
      return [] unless sum.positive?

      layout_sectors(numbers, sum, start_angle, direction, padding, min, real_total)
    end

    # recharts util/PolarUtils.js `polarToCartesian`.
    #
    # @api private
    # @return [Array(Float, Float)] x and y
    def polar_to_cartesian(cx, cy, radius, angle)
      [ cx + (Math.cos(-RADIAN * angle) * radius), cy + (Math.sin(-RADIAN * angle) * radius) ]
    end

    private

    # recharts counts what `isNumber` rejects (not a number, NaN) as 0.
    def number_or_zero(value)
      return 0 unless value.is_a?(Numeric)

      value.respond_to?(:nan?) && value.nan? ? 0 : value
    end

    def layout_sectors(numbers, sum, start_angle, direction, padding, min, real_total)
      previous_end = nil
      numbers.each_with_index.map do |value, index|
        percent = value.to_f / sum
        present = value.zero? ? 0 : 1
        sector_start = index.zero? ? start_angle : previous_end + (direction * padding * present)
        sector_end = sector_start + (direction * ((present * min) + (percent * real_total)))
        previous_end = sector_end
        { start_angle: sector_start, end_angle: sector_end, mid_angle: (sector_start + sector_end) / 2, percent: percent }
      end
    end

    def plain_sector(cx, cy, inner, outer, start_angle, end_angle)
      angle = delta_angle(start_angle, end_angle, MAX_SECTOR_ANGLE)
      temp_end = start_angle + angle
      outer_start = polar_to_cartesian(cx, cy, outer, start_angle)
      outer_end = polar_to_cartesian(cx, cy, outer, temp_end)
      large = flag(angle.abs > 180)
      path = fill(OUTER_ARC, *outer_start, outer, outer, large, flag(start_angle > temp_end), *outer_end)
      return path + fill(CENTER_CLOSE, cx, cy) unless inner.positive?

      inner_start = polar_to_cartesian(cx, cy, inner, start_angle)
      inner_end = polar_to_cartesian(cx, cy, inner, temp_end)
      path + fill(INNER_ARC, *inner_end, inner, inner, large, flag(start_angle <= temp_end), *inner_start)
    end

    def sector_with_corner(cx, cy, inner, outer, corner, force, external, start_angle, end_angle)
      sign = math_sign(end_angle - start_angle)
      common = { cx: cx, cy: cy, corner_radius: corner, corner_is_external: external }
      start_outer = tangent_circle(radius: outer, angle: start_angle, sign: sign, **common)
      end_outer = tangent_circle(radius: outer, angle: end_angle, sign: -sign, **common)
      span = (start_angle - end_angle).abs
      outer_arc_angle = external ? span : span - start_outer[:theta] - end_outer[:theta]
      if outer_arc_angle.negative?
        return fill(FORCED_CORNERS, *start_outer[:line_tangency], corner, corner, corner * 2, corner, corner, -corner * 2) if force

        return plain_sector(cx, cy, inner, outer, start_angle, end_angle)
      end

      reverse = flag(sign.negative?)
      path = fill(OUTER_CORNERS, *start_outer[:line_tangency], corner, corner, reverse, *start_outer[:circle_tangency], outer, outer,
                  flag(outer_arc_angle > 180), reverse, *end_outer[:circle_tangency], corner, corner, reverse, *end_outer[:line_tangency])
      return path + fill(CENTER_CORNERS, cx, cy) unless inner.positive?

      path + inner_corners(inner, sign, [ start_angle, end_angle ], common, reverse)
    end

    def inner_corners(inner, sign, angles, common, reverse)
      start_inner = tangent_circle(radius: inner, angle: angles[0], sign: sign, external: true, **common)
      end_inner = tangent_circle(radius: inner, angle: angles[1], sign: -sign, external: true, **common)
      span = (angles[0] - angles[1]).abs
      inner_arc_angle = common[:corner_is_external] ? span : span - start_inner[:theta] - end_inner[:theta]
      corner = common[:corner_radius]
      return degenerate_inner(common) if inner_arc_angle.negative? && corner.zero?

      fill(INNER_CORNERS, *end_inner[:line_tangency], corner, corner, reverse, *end_inner[:circle_tangency], inner, inner,
           flag(inner_arc_angle > 180), flag(sign.positive?), *start_inner[:circle_tangency], corner, corner, reverse,
           *start_inner[:line_tangency])
    end

    # Sector.js closes a ring too narrow for its corners on the center with the coordinates unrounded.
    def degenerate_inner(common)
      "L#{Chadcn::Chart::Shape::Number.format(common[:cx])},#{Chadcn::Chart::Shape::Number.format(common[:cy])}Z"
    end

    # recharts Sector.js `getTangentCircle`: the corner circle tangent to the arc and to the radius line.
    def tangent_circle(cx:, cy:, radius:, angle:, sign:, corner_radius:, corner_is_external:, external: false)
      center_radius = (corner_radius * (external ? 1 : -1)) + radius
      theta = js_asin(corner_radius / center_radius) / RADIAN
      center_angle = corner_is_external ? angle : angle + (sign * theta)
      line_angle = corner_is_external ? angle - (sign * theta) : angle
      {
        circle_tangency: polar_to_cartesian(cx, cy, radius, center_angle),
        line_tangency: polar_to_cartesian(cx, cy, center_radius * Math.cos(theta * RADIAN), line_angle),
        theta: theta
      }
    end

    # Sector.js `getDeltaAngle` (limit 359.999) and Pie.js `parseDeltaAngle` (limit 360).
    def delta_angle(start_angle, end_angle, limit)
      math_sign(end_angle - start_angle) * [ (end_angle - start_angle).abs, limit ].min
    end

    # recharts util/DataUtils.js `getPercentValue(percent, total, 0, true)`.
    def percent_value(percent, total)
      value =
        case percent
        when Numeric then percent.to_f
        when String then percent_string(percent, total)
        else return 0.0
        end
      return 0.0 if value.nan?

      [ value, total ].min.to_f
    end

    def percent_string(text, total)
      number = Float(text.end_with?("%") ? text.chomp("%") : text, exception: false)
      return Float::NAN unless number

      text.end_with?("%") ? total * number / 100 : number
    end

    def math_sign(value)
      return 0 if value.zero?

      value.positive? ? 1 : -1
    end

    def js_asin(value) = value.abs > 1 || value.nan? ? Float::NAN : Math.asin(value)

    def flag(condition) = condition ? 1 : 0

    # Interleaves template pieces and values, rounding the numbers like recharts' `roundTemplateLiteral`.
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
