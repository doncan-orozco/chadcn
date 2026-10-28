# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- cx and cy are the center vocabulary of recharts

# The polar geometry of recharts (util/PolarUtils.js and the angle clamp of shape/Sector.js): angles are degrees, counterclockwise from
# 3 o'clock, y grows downwards as in SVG.
#
# @api private
module Chadcn::Chart::Shape::Polar
  # recharts util/PolarUtils.js RADIAN.
  RADIAN = Math::PI / 180

  private_constant :RADIAN

  class << self
    # @api private
    # @param degrees [Numeric]
    # @return [Float] radians
    def to_radians(degrees) = degrees * RADIAN

    # @api private
    # @param radians [Numeric]
    # @return [Float] degrees
    def to_degrees(radians) = radians / RADIAN

    # recharts util/PolarUtils.js `polarToCartesian`.
    #
    # @api private
    # @param cx [Numeric] center x
    # @param cy [Numeric] center y
    # @param radius [Numeric]
    # @param angle [Numeric] degrees
    # @return [Array(Float, Float)] x and y
    def polar_to_cartesian(cx, cy, radius, angle)
      [ cx + (Math.cos(-to_radians(angle)) * radius), cy + (Math.sin(-to_radians(angle)) * radius) ]
    end

    # The signed angle from `start_angle` to `end_angle`, capped at `limit` degrees either way (Sector.js `getDeltaAngle` with a
    # limit of 359.999, Pie.js `parseDeltaAngle` with 360).
    #
    # @api private
    # @param start_angle [Numeric] degrees
    # @param end_angle [Numeric] degrees
    # @param limit [Numeric] degrees
    # @return [Numeric] degrees, negative when the end is below the start
    def delta_angle(start_angle, end_angle, limit:)
      Chadcn::Chart::JsMath.sign(end_angle - start_angle) * [ (end_angle - start_angle).abs, limit ].min
    end
  end
end

# rubocop:enable Naming/MethodParameterName
