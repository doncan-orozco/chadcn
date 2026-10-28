# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveMonotoneY`: {Chadcn::Chart::Shape::Curve::MonotoneX} with x and y swapped, for vertical layouts.
#
# @api private
class Chadcn::Chart::Shape::Curve::MonotoneY < Chadcn::Chart::Shape::Curve::MonotoneX
  private

  def add_point(x, y) = super(y, x)

  def move_to_point(x, y) = super(y, x)

  def draw_line_to(x, y) = super(y, x)

  def draw_bezier_to(x1, y1, x2, y2, x, y) = super(y1, x1, y2, x2, y, x)
end

# rubocop:enable Naming/MethodParameterName
