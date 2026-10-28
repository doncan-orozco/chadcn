# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveBasisOpen`: a cubic basis spline that does not touch the first and last points.
#
# @api private
class Chadcn::Chart::Shape::Curve::BasisOpen < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @param context [Chadcn::Chart::Shape::Path]
  def initialize(context)
    super
    @x0 = @x1 = @y0 = @y1 = Float::NAN
  end

  # @api private
  # @return [void]
  def line_start
    @x0 = @x1 = @y0 = @y1 = Float::NAN
    @point = 0
  end

  # @api private
  # @return [void]
  def line_end
    close_path_if(@point == 3)
    toggle_line
  end

  # @api private
  # @return [void]
  def point(x, y)
    x = x.to_f
    y = y.to_f
    case @point
    when 0 then @point = 1
    when 1 then @point = 2
    when 2
      @point = 3
      start_subpath((@x0 + (4 * @x1) + x) / 6, (@y0 + (4 * @y1) + y) / 6)
    else
      @point = 4
      Chadcn::Chart::Shape::Curve::Basis.segment(@context, @x0, @y0, @x1, @y1, x, y)
    end
    @x0 = @x1
    @x1 = x
    @y0 = @y1
    @y1 = y
  end
end

# rubocop:enable Naming/MethodParameterName
