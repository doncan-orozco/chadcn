# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveStep` (t = 0.5), `curveStepBefore` (t = 0) and `curveStepAfter` (t = 1): horizontal and vertical segments.
#
# @api private
class Chadcn::Chart::Shape::Curve::Step < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @param context [Chadcn::Chart::Shape::Path]
  # @param position [Numeric] where the step happens between two points: 0 before, 0.5 in the middle, 1 after
  def initialize(context, position)
    super(context)
    @t = position.to_f
    @x = @y = Float::NAN
  end

  # @api private
  # @return [void]
  def line_start
    @x = @y = Float::NAN
    @point = 0
  end

  # @api private
  # @return [void]
  def line_end
    @context.line_to(@x, @y) if @t.positive? && @t < 1 && @point == 2
    close_path_if(@point == 1)
    return unless @line && @line >= 0

    @t = 1 - @t
    toggle_line
  end

  # @api private
  # @return [void]
  def point(x, y)
    x = x.to_f
    y = y.to_f
    case @point
    when 0
      @point = 1
      start_subpath(x, y)
    else
      @point = 2
      step_to(x, y)
    end
    @x = x
    @y = y
  end

  private

  def step_to(x, y)
    if @t <= 0
      @context.line_to(@x, y)
      @context.line_to(x, y)
    else
      x1 = (@x * (1 - @t)) + (x * @t)
      @context.line_to(x1, @y)
      @context.line_to(x1, y)
    end
  end
end

# rubocop:enable Naming/MethodParameterName
