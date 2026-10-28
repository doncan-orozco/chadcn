# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveLinear`: straight segments between the points.
#
# @api private
class Chadcn::Chart::Shape::Curve::Linear < Chadcn::Chart::Shape::Curve::Interpolator
  private

  def add_point(x, y)
    if point_count.zero?
      self.point_count = 1
      start_subpath(x, y)
    else
      self.point_count = 2
      draw_line_to(x, y)
    end
  end
end

# rubocop:enable Naming/MethodParameterName
