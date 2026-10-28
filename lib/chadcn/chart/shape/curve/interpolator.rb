# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# Base of the curve interpolators: the d3-shape curve protocol (`area_start`, `area_end`, `line_start`, `line_end`, `point`) over a
# {Chadcn::Chart::Shape::Path}-like context. `line` and `area` drive it exactly as d3 `line()` and `area()` do.
#
# A subclass implements `add_point` (called with Floats) and, when it differs from the default, `line_end`. It draws through the
# hooks `move_to_point`, `draw_line_to` and `draw_bezier_to` (a subclass may reflect them, as MonotoneY does) and keeps the last two
# points in the sliding window (`x0`, `y0`, `x1`, `y1`) with `shift_window`.
#
# `@line` is d3's `_line`: nil (undefined or NaN) outside an area, 0 on the top line of an area, 1 on its baseline pass.
#
# @api private
class Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @param context [Chadcn::Chart::Shape::Path]
  def initialize(context)
    @context = context
    @line = nil
    @point = 0
    reset_window
  end

  # @api private
  # @return [void]
  def area_start = @line = 0

  # @api private
  # @return [void]
  def area_end = @line = nil

  # @api private
  # @return [void]
  def line_start
    reset_window
    @point = 0
  end

  # The end of a line: a lone point is closed (or the baseline pass of an area); curves that draw more override it.
  #
  # @api private
  # @return [void]
  def line_end
    close_path_if(point_count == 1)
    toggle_line
  end

  # The next point of the line.
  #
  # @api private
  # @param x [Numeric]
  # @param y [Numeric]
  # @return [void]
  def point(x, y) = add_point(x.to_f, y.to_f)

  private

  # How many points of the current line have been seen, as far as the curve counts (d3 `_point`).
  # @return [Integer]
  def point_count = @point

  def point_count=(count)
    @point = count
  end

  # The curve's own handling of one point.
  # @param x [Float]
  # @param y [Float]
  def add_point(x, y)
    raise NotImplementedError, "#{self.class} must implement add_point"
  end

  # The previous-previous point (x0, y0) and the previous point (x1, y1), NaN until seen.
  # @return [Float]
  attr_reader :x0, :y0, :x1, :y1

  def reset_window
    @x0 = @x1 = @y0 = @y1 = Float::NAN
  end

  def shift_window(x, y)
    @x0 = @x1
    @x1 = x
    @y0 = @y1
    @y1 = y
  end

  def move_to_point(x, y) = @context.move_to(x, y)

  def draw_line_to(x, y) = @context.line_to(x, y)

  def draw_bezier_to(x1, y1, x2, y2, x, y) = @context.bezier_to(x1, y1, x2, y2, x, y)

  def close_subpath = @context.close

  # d3's `if (this._line || (this._line !== 0 && cond)) closePath()`: close on the baseline pass of an area, or a lone point of a line.
  def close_path_if(condition)
    close_subpath if @line == 1 || (@line != 0 && condition)
  end

  # `this._line = 1 - this._line` (NaN stays NaN).
  def toggle_line
    @line = 1 - @line if @line
  end

  # @return [Boolean] true between `area_start` and `area_end`, where d3's `_line` is a number
  def inside_area? = !@line.nil?

  # On the first point of a line start the subpath; on the baseline pass of an area continue it.
  def start_subpath(x, y)
    @line == 1 ? draw_line_to(x, y) : move_to_point(x, y)
  end

  # The cubic segment shared by the three basis curves (d3-shape curve/basis.js `point`): from the previous point towards `x, y`.
  def basis_segment(x, y)
    draw_bezier_to(
      ((2 * x0) + x1) / 3, ((2 * y0) + y1) / 3,
      (x0 + (2 * x1)) / 3, (y0 + (2 * y1)) / 3,
      (x0 + (4 * x1) + x) / 6, (y0 + (4 * y1) + y) / 6
    )
  end
end

# rubocop:enable Naming/MethodParameterName
