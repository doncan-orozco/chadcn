# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveLinearClosed`: straight segments and a closing segment back to the first point.
#
# @api private
class Chadcn::Chart::Shape::Curve::LinearClosed < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @return [void]
  def area_start; end

  # @api private
  # @return [void]
  def area_end; end

  # @api private
  # @return [void]
  def line_end = (close_subpath if point_count == 1)

  private

  def add_point(x, y)
    if point_count == 1
      draw_line_to(x, y)
    else
      self.point_count = 1
      move_to_point(x, y)
    end
  end
end

# rubocop:enable Naming/MethodParameterName
