# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveBasisClosed`: a closed cubic basis spline.
#
# @api private
class Chadcn::Chart::Shape::Curve::BasisClosed < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @param context [Chadcn::Chart::Shape::Path]
  def initialize(context)
    super
    reset
  end

  # @api private
  # @return [void]
  def area_start; end

  # @api private
  # @return [void]
  def area_end; end

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
    when 1
      @context.move_to(@x2, @y2)
      @context.close
    when 2
      @context.move_to((@x2 + (2 * @x3)) / 3, (@y2 + (2 * @y3)) / 3)
      @context.line_to((@x3 + (2 * @x2)) / 3, (@y3 + (2 * @y2)) / 3)
      @context.close
    when 3
      point(@x2, @y2)
      point(@x3, @y3)
      point(@x4, @y4)
    end
  end

  # @api private
  # @return [void]
  def point(x, y)
    x = x.to_f
    y = y.to_f
    case @point
    when 0
      @point = 1
      @x2 = x
      @y2 = y
    when 1
      @point = 2
      @x3 = x
      @y3 = y
    when 2
      @point = 3
      @x4 = x
      @y4 = y
      @context.move_to((@x0 + (4 * @x1) + x) / 6, (@y0 + (4 * @y1) + y) / 6)
    else
      Chadcn::Chart::Shape::Curve::Basis.segment(@context, @x0, @y0, @x1, @y1, x, y)
    end
    @x0 = @x1
    @x1 = x
    @y0 = @y1
    @y1 = y
  end

  private

  def reset
    @x0 = @x1 = @x2 = @x3 = @x4 = @y0 = @y1 = @y2 = @y3 = @y4 = Float::NAN
  end
end

# rubocop:enable Naming/MethodParameterName
