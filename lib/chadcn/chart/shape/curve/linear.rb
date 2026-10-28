# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveLinear`: straight segments between the points.
#
# @api private
class Chadcn::Chart::Shape::Curve::Linear < Chadcn::Chart::Shape::Curve::Interpolator
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
    case @point
    when 0
      @point = 1
      start_subpath(x, y)
    else
      @point = 2
      @context.line_to(x, y)
    end
  end
end

# rubocop:enable Naming/MethodParameterName
