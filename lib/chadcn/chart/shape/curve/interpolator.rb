# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# Base of the curve interpolators: the d3-shape curve protocol (`area_start`, `area_end`, `line_start`, `line_end`, `point`) over a
# {Chadcn::Chart::Shape::Path}-like context. `line` and `area` drive it exactly as d3 `line()` and `area()` do.
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
  end

  # @api private
  # @return [void]
  def area_start = @line = 0

  # @api private
  # @return [void]
  def area_end = @line = nil

  # @api private
  # @return [void]
  def line_start = @point = 0

  # @api private
  # @return [void]
  def line_end = toggle_line

  # @api private
  # @param x [Numeric]
  # @param y [Numeric]
  # @return [void]
  def point(x, y)
    raise NotImplementedError, "#{self.class} must implement point"
  end

  private

  # d3's `if (this._line || (this._line !== 0 && cond)) closePath()`: close on the baseline pass of an area, or a lone point of a line.
  def close_path_if(condition)
    @context.close if @line == 1 || (@line != 0 && condition)
  end

  # `this._line = 1 - this._line` (NaN stays NaN).
  def toggle_line
    @line = 1 - @line if @line
  end

  # On the first point of a line start the subpath; on the baseline pass of an area continue it.
  def start_subpath(x, y)
    @line == 1 ? @context.line_to(x, y) : @context.move_to(x, y)
  end
end

# rubocop:enable Naming/MethodParameterName
