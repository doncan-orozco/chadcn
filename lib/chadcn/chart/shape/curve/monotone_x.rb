# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveMonotoneX` (curve/monotone.js): a cubic Hermite spline through the points that is monotone in y between them,
# with the tangents of Steffen (1990).
#
# @api private
class Chadcn::Chart::Shape::Curve::MonotoneX < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @return [void]
  def line_end
    case point_count
    when 2 then draw_line_to(x1, y1)
    when 3 then hermite_segment(@tangent0, one_sided_slope(@tangent0))
    end
    super
  end

  private

  def add_point(x, y)
    return if x == x1 && y == y1 # coincident points are ignored

    tangent1 = Float::NAN
    case point_count
    when 0
      self.point_count = 1
      start_subpath(x, y)
    when 1
      self.point_count = 2
    when 2
      self.point_count = 3
      tangent1 = shared_point_slope(x, y)
      hermite_segment(one_sided_slope(tangent1), tangent1)
    else
      tangent1 = shared_point_slope(x, y)
      hermite_segment(@tangent0, tangent1)
    end
    shift_window(x, y)
    @tangent0 = tangent1
  end

  def reset_window
    super
    @tangent0 = Float::NAN
  end

  # Cubic Hermite as a Bezier: p0, p0 + m0 / 3, p1 - m1 / 3, p1.
  def hermite_segment(tangent0, tangent1)
    dx = (x1 - x0) / 3
    draw_bezier_to(x0 + dx, y0 + (dx * tangent0), x1 - dx, y1 - (dx * tangent1), x1, y1)
  end

  # Tangent at the shared point of two segments; JavaScript's `h0 || h1 < 0 && -0` makes a zero width divide as +/-0.
  def shared_point_slope(x2, y2)
    h0 = x1 - x0
    h1 = x2 - x1
    s0 = (y1 - y0) / divisor(h0, h1)
    s1 = (y2 - y1) / divisor(h1, h0)
    weighted = ((s0 * h1) + (s1 * h0)) / (h0 + h1)
    value = (sign(s0) + sign(s1)) * js_min(s0.abs, s1.abs, 0.5 * weighted.abs)
    value.nan? ? 0.0 : value # `|| 0`
  end

  # One-sided slope at the ends.
  def one_sided_slope(tangent)
    h = x1 - x0
    h.zero? || h.nan? ? tangent : (((3 * (y1 - y0) / h) - tangent) / 2)
  end

  def divisor(width, other)
    return width unless width.zero? || width.nan?
    return -0.0 if other.negative?

    0.0
  end

  def sign(value) = value.negative? ? -1 : 1

  # Math.min: NaN wins.
  def js_min(*values) = values.any?(&:nan?) ? Float::NAN : values.min
end

# rubocop:enable Naming/MethodParameterName
