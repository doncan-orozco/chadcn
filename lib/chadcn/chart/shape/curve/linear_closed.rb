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
  def line_end = (@context.close if @point == 1)

  # @api private
  # @return [void]
  def point(x, y)
    x = x.to_f
    y = y.to_f
    if @point == 1
      @context.line_to(x, y)
    else
      @point = 1
      @context.move_to(x, y)
    end
  end
end

# rubocop:enable Naming/MethodParameterName
