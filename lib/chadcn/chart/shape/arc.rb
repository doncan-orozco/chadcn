# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- cx and cy are the center vocabulary of recharts

# Circular sectors of recharts: the path of shape/Sector.js (`getSectorPath`, `getSectorWithCorner`, `getTangentCircle`). Angles are
# degrees, counterclockwise from 3 o'clock, as in recharts. The pie angle layout is {Chadcn::Chart::Shape::Pie}, the polar geometry
# {Chadcn::Chart::Shape::Polar}, the path strings {Chadcn::Chart::Shape::Arc::Templates}.
#
# @api private
module Chadcn::Chart::Shape::Arc
  Polar = Chadcn::Chart::Shape::Polar
  JsMath = Chadcn::Chart::Shape::JsMath

  # recharts clamps a full turn so the start and end points of an arc do not coincide (Sector.js `getDeltaAngle`).
  MAX_SECTOR_ANGLE = 359.999

  # A sector of `sector_path` with every number a Float and the corner radius already limited to half the ring width.
  Sector = Data.define(:cx, :cy, :inner_radius, :outer_radius, :start_angle, :end_angle, :corner_radius, :corner_is_external,
                       :force_corner_radius) do
    # 1 when the sector runs counterclockwise (the end angle is above the start), -1 clockwise.
    #
    # @api private
    # @return [Integer]
    def direction = JsMath.sign(end_angle - start_angle)

    # The angle between the radius lines, in degrees.
    #
    # @api private
    # @return [Float]
    def span = (start_angle - end_angle).abs

    # @api private
    # @return [Boolean] true when the sector has a hole
    def ring? = inner_radius.positive?
  end

  # The corner circle of Sector.js `getTangentCircle`: tangent to the arc (at `circle`) and to the radius line (at `line`); `theta` is
  # the angle in degrees between the corner and the radius line.
  Tangent = Data.define(:circle, :line, :theta)

  private_constant :Polar, :JsMath, :MAX_SECTOR_ANGLE, :Sector, :Tangent

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

      ring_width = outer_radius - inner_radius
      corner = corner_radius_in_pixels(corner_radius, ring_width)
      sector = Sector.new(cx: cx.to_f, cy: cy.to_f, inner_radius: inner_radius.to_f, outer_radius: outer_radius.to_f,
                          start_angle: start_angle.to_f, end_angle: end_angle.to_f, corner_radius: [ corner, ring_width / 2.0 ].min,
                          corner_is_external: corner_is_external, force_corner_radius: force_corner_radius)
      corner.positive? && sector.span < 360 ? rounded_sector(sector) : plain_sector(sector)
    end

    private

    def plain_sector(sector)
      angle = Polar.delta_angle(sector.start_angle, sector.end_angle, limit: MAX_SECTOR_ANGLE)
      clamped_end = sector.start_angle + angle
      large_arc = angle.abs > 180
      path = Templates.outer_arc(from: point_on(sector, sector.outer_radius, sector.start_angle),
                                 to: point_on(sector, sector.outer_radius, clamped_end), radius: sector.outer_radius,
                                 large_arc: large_arc, sweep: sector.start_angle > clamped_end)
      return path + Templates.center_close(sector.cx, sector.cy) unless sector.ring?

      path + Templates.inner_arc(from: point_on(sector, sector.inner_radius, clamped_end),
                                 to: point_on(sector, sector.inner_radius, sector.start_angle), radius: sector.inner_radius,
                                 large_arc: large_arc, sweep: sector.start_angle <= clamped_end)
    end

    def rounded_sector(sector)
      start_outer = tangent_circle(sector, radius: sector.outer_radius, angle: sector.start_angle, direction: sector.direction)
      end_outer = tangent_circle(sector, radius: sector.outer_radius, angle: sector.end_angle, direction: -sector.direction)
      outer_arc_angle = sector.corner_is_external ? sector.span : sector.span - start_outer.theta - end_outer.theta
      return corners_too_big(sector, start_outer) if outer_arc_angle.negative?

      path = Templates.outer_corners(start_line: start_outer.line, start_circle: start_outer.circle, end_circle: end_outer.circle,
                                     end_line: end_outer.line, corner: sector.corner_radius, radius: sector.outer_radius,
                                     large_arc: outer_arc_angle > 180, corner_sweep: sector.direction.negative?)
      return path + Templates.center_corners(sector.cx, sector.cy) unless sector.ring?

      path + inner_corners(sector)
    end

    # The corners do not fit on the arc: the forced corner circles alone, or the plain sector.
    def corners_too_big(sector, start_outer)
      return plain_sector(sector) unless sector.force_corner_radius

      Templates.forced_corners(start_line: start_outer.line, corner: sector.corner_radius)
    end

    def inner_corners(sector)
      start_inner = tangent_circle(sector, radius: sector.inner_radius, angle: sector.start_angle, direction: sector.direction,
                                           center_outside: true)
      end_inner = tangent_circle(sector, radius: sector.inner_radius, angle: sector.end_angle, direction: -sector.direction,
                                         center_outside: true)
      inner_arc_angle = sector.corner_is_external ? sector.span : sector.span - start_inner.theta - end_inner.theta
      corner = sector.corner_radius
      return Templates.center_corners_unrounded(sector.cx, sector.cy) if inner_arc_angle.negative? && corner.zero?

      Templates.inner_corners(end_line: end_inner.line, end_circle: end_inner.circle, start_circle: start_inner.circle,
                              start_line: start_inner.line, corner: corner, radius: sector.inner_radius,
                              large_arc: inner_arc_angle > 180, corner_sweep: sector.direction.negative?,
                              arc_sweep: sector.direction.positive?)
    end

    # recharts Sector.js `getTangentCircle`: the corner circle tangent to the arc and to the radius line. The circle centers inside the
    # outer arc (`center_outside` false) and outside the inner one (true).
    def tangent_circle(sector, radius:, angle:, direction:, center_outside: false)
      corner = sector.corner_radius
      center_radius = (corner * (center_outside ? 1 : -1)) + radius
      theta = Polar.to_degrees(JsMath.asin(corner / center_radius))
      circle_angle = sector.corner_is_external ? angle : angle + (direction * theta)
      line_angle = sector.corner_is_external ? angle - (direction * theta) : angle
      Tangent.new(circle: point_on(sector, radius, circle_angle),
                  line: point_on(sector, center_radius * Math.cos(Polar.to_radians(theta)), line_angle), theta: theta)
    end

    def point_on(sector, radius, angle) = Polar.polar_to_cartesian(sector.cx, sector.cy, radius, angle)

    # recharts util/DataUtils.js `getPercentValue(percent, total, 0, true)`: a number of pixels, or a percentage of the ring width,
    # never more than the ring width; anything else is 0.
    def corner_radius_in_pixels(corner_radius, ring_width)
      pixels =
        case corner_radius
        when Numeric then corner_radius.to_f
        when String then pixels_of_text(corner_radius, ring_width)
        else return 0.0
        end
      pixels.nan? ? 0.0 : [ pixels, ring_width ].min.to_f
    end

    def pixels_of_text(text, ring_width)
      number = Float(text.chomp("%"), exception: false)
      return Float::NAN unless number

      text.end_with?("%") ? ring_width * number / 100 : number
    end
  end
end

# rubocop:enable Naming/MethodParameterName
