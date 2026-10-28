# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveMonotoneY`: {Chadcn::Chart::Shape::Curve::MonotoneX} with x and y swapped, for vertical layouts.
#
# @api private
class Chadcn::Chart::Shape::Curve::MonotoneY < Chadcn::Chart::Shape::Curve::MonotoneX
  # @api private
  # @return [void]
  def point(x, y) = super(y, x)

  private

  def move(x, y) = super(y, x)
  def line(x, y) = super(y, x)
  def bezier(x1, y1, x2, y2, x, y) = super(y1, x1, y2, x2, y, x)
end

# rubocop:enable Naming/MethodParameterName
