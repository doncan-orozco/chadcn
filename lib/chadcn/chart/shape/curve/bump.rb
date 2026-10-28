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
  end

  private

  def add_point(x, y)
    if point_count.zero?
      self.point_count = 1
      start_subpath(x, y)
    else
      self.point_count = 2
      bump_to(x, y)
    end
    shift_window(x, y)
  end

  def bump_to(x, y)
    if @horizontal
      middle = (x1 + x) / 2
      draw_bezier_to(middle, y1, middle, y, x, y)
    else
      middle = (y1 + y) / 2
      draw_bezier_to(x1, middle, x, middle, x, y)
    end
  end
end

# rubocop:enable Naming/MethodParameterName
