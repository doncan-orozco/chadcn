# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveMonotoneX` (curve/monotone.js): a cubic Hermite spline through the points that is monotone in y between them,
# with the tangents of Steffen (1990).
#
# @api private
class Chadcn::Chart::Shape::Curve::MonotoneX < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @param context [Chadcn::Chart::Shape::Path]
  def initialize(context)
    super
    reset
  end

  # @api private
  # @return [void]
  def line_start
    reset
    @point = 0
  end

  # @api private
  # @return [void]
  def line_end
    case @point
    when 2 then line(@x1, @y1)
    when 3 then segment(@t0, slope2(@t0))
    end
    close_path_if(@point == 1)
    toggle_line
  end

  # @api private
  # @return [void]
  def point(x, y)
    x = x.to_f
    y = y.to_f
    return if x == @x1 && y == @y1 # coincident points are ignored

    t1 = Float::NAN
    case @point
    when 0
      @point = 1
      start_subpath(x, y)
    when 1
      @point = 2
    when 2
      @point = 3
      t1 = slope3(x, y)
      segment(slope2(t1), t1)
    else
      t1 = slope3(x, y)
      segment(@t0, t1)
    end
    @x0 = @x1
    @x1 = x
    @y0 = @y1
    @y1 = y
    @t0 = t1
  end

  private

  def reset
    @x0 = @x1 = @y0 = @y1 = @t0 = Float::NAN
  end

  # Drawing hooks, overridden by MonotoneY to reflect the coordinates.
  def start_subpath(x, y) = @line == 1 ? line(x, y) : move(x, y)
  def move(x, y) = @context.move_to(x, y)
  def line(x, y) = @context.line_to(x, y)
  def bezier(x1, y1, x2, y2, x, y) = @context.bezier_to(x1, y1, x2, y2, x, y)

  # Cubic Hermite as a Bezier: p0, p0 + m0 / 3, p1 - m1 / 3, p1.
  def segment(t0, t1)
    dx = (@x1 - @x0) / 3
    bezier(@x0 + dx, @y0 + (dx * t0), @x1 - dx, @y1 - (dx * t1), @x1, @y1)
  end

  # Tangent at the shared point of two segments; JavaScript's `h0 || h1 < 0 && -0` makes a zero width divide as +/-0.
  def slope3(x2, y2)
    h0 = @x1 - @x0
    h1 = x2 - @x1
    s0 = (@y1 - @y0) / divisor(h0, h1)
    s1 = (y2 - @y1) / divisor(h1, h0)
    weighted = ((s0 * h1) + (s1 * h0)) / (h0 + h1)
    value = (sign(s0) + sign(s1)) * js_min(s0.abs, s1.abs, 0.5 * weighted.abs)
    value.nan? ? 0.0 : value # `|| 0`
  end

  # One-sided slope at the ends.
  def slope2(t)
    h = @x1 - @x0
    h.zero? || h.nan? ? t : (((3 * (@y1 - @y0) / h) - t) / 2)
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
