# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveBumpX` (horizontal tangents at the points) and `curveBumpY` (vertical tangents): cubic segments with the
# control points halfway between the two points.
#
# @api private
class Chadcn::Chart::Shape::Curve::Bump < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @param context [Chadcn::Chart::Shape::Path]
  # @param horizontal [Boolean] true for bumpX, false for bumpY
  def initialize(context, horizontal:)
    super(context)
    @horizontal = horizontal
    @x0 = @y0 = Float::NAN
  end

  # @api private
  # @return [void]
  def line_end
    close_path_if(@point == 1)
    toggle_line
  end

  # @api private
  # @return [void]
  def point(x, y)
    x = x.to_f
    y = y.to_f
    if @point.zero?
      @point = 1
      start_subpath(x, y)
    else
      @point = 2
      bump_to(x, y)
    end
    @x0 = x
    @y0 = y
  end

  private

  def bump_to(x, y)
    if @horizontal
      middle = (@x0 + x) / 2
      @context.bezier_to(middle, @y0, middle, y, x, y)
    else
      middle = (@y0 + y) / 2
      @context.bezier_to(@x0, middle, x, middle, x, y)
    end
  end
end

# rubocop:enable Naming/MethodParameterName
