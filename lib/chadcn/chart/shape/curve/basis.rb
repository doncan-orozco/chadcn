# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveBasis`: a cubic basis spline through the first and last points.
#
# @api private
class Chadcn::Chart::Shape::Curve::Basis < Chadcn::Chart::Shape::Curve::Interpolator
  # The cubic segment shared by the three basis curves (d3-shape curve/basis.js `point`).
  #
  # @api private
  # @param context [Chadcn::Chart::Shape::Path]
  # @param x0 [Float] previous-previous point
  # @param y0 [Float]
  # @param x1 [Float] previous point
  # @param y1 [Float]
  # @param x [Float] new point
  # @param y [Float]
  # @return [void]
  def self.segment(context, x0, y0, x1, y1, x, y)
    context.bezier_to(
      ((2 * x0) + x1) / 3, ((2 * y0) + y1) / 3,
      (x0 + (2 * x1)) / 3, (y0 + (2 * y1)) / 3,
      (x0 + (4 * x1) + x) / 6, (y0 + (4 * y1) + y) / 6
    )
  end

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
    self.class.segment(@context, @x0, @y0, @x1, @y1, @x1, @y1) if @point == 3
    @context.line_to(@x1, @y1) if [ 2, 3 ].include?(@point)
    close_path_if(@point == 1)
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
    when 1
      @point = 2
    when 2
      @point = 3
      @context.line_to(((5 * @x0) + @x1) / 6, ((5 * @y0) + @y1) / 6)
      self.class.segment(@context, @x0, @y0, @x1, @y1, x, y)
    else
      self.class.segment(@context, @x0, @y0, @x1, @y1, x, y)
    end
    @x0 = @x1
    @x1 = x
    @y0 = @y1
    @y1 = y
  end
end

# rubocop:enable Naming/MethodParameterName
