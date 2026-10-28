# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveBasisOpen`: a cubic basis spline that does not touch the first and last points.
#
# @api private
class Chadcn::Chart::Shape::Curve::BasisOpen < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @return [void]
  def line_end
    close_path_if(point_count == 3)
    toggle_line
  end

  private

  def add_point(x, y)
    case point_count
    when 0 then self.point_count = 1
    when 1 then self.point_count = 2
    when 2
      self.point_count = 3
      start_subpath((x0 + (4 * x1) + x) / 6, (y0 + (4 * y1) + y) / 6)
    else
      self.point_count = 4
      basis_segment(x, y)
    end
    shift_window(x, y)
  end
end

# rubocop:enable Naming/MethodParameterName
