# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveBasis`: a cubic basis spline through the first and last points.
#
# @api private
class Chadcn::Chart::Shape::Curve::Basis < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @return [void]
  def line_end
    basis_segment(x1, y1) if point_count == 3
    draw_line_to(x1, y1) if point_count.between?(2, 3)
    super
  end

  private

  def add_point(x, y)
    case point_count
    when 0
      self.point_count = 1
      start_subpath(x, y)
    when 1
      self.point_count = 2
    when 2
      self.point_count = 3
      draw_line_to(((5 * x0) + x1) / 6, ((5 * y0) + y1) / 6)
      basis_segment(x, y)
    else
      basis_segment(x, y)
    end
    shift_window(x, y)
  end
end

# rubocop:enable Naming/MethodParameterName
