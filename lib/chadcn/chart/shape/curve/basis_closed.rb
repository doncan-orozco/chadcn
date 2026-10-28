# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveBasisClosed`: a closed cubic basis spline. The first three points are held back and replayed when the line ends.
#
# @api private
class Chadcn::Chart::Shape::Curve::BasisClosed < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @return [void]
  def area_start; end

  # @api private
  # @return [void]
  def area_end; end

  # @api private
  # @return [void]
  def line_end
    case point_count
    when 1
      move_to_point(@x2, @y2)
      close_subpath
    when 2
      move_to_point((@x2 + (2 * @x3)) / 3, (@y2 + (2 * @y3)) / 3)
      draw_line_to((@x3 + (2 * @x2)) / 3, (@y3 + (2 * @y2)) / 3)
      close_subpath
    when 3
      add_point(@x2, @y2)
      add_point(@x3, @y3)
      add_point(@x4, @y4)
    end
  end

  private

  def add_point(x, y)
    case point_count
    when 0
      self.point_count = 1
      @x2 = x
      @y2 = y
    when 1
      self.point_count = 2
      @x3 = x
      @y3 = y
    when 2
      self.point_count = 3
      @x4 = x
      @y4 = y
      move_to_point((x0 + (4 * x1) + x) / 6, (y0 + (4 * y1) + y) / 6)
    else
      basis_segment(x, y)
    end
    shift_window(x, y)
  end

  def reset_window
    super
    @x2 = @x3 = @x4 = @y2 = @y3 = @y4 = Float::NAN
  end
end

# rubocop:enable Naming/MethodParameterName
