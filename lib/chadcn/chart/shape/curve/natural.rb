# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveNatural`: a natural cubic spline (second derivative zero at both ends), computed when the line ends.
#
# @api private
class Chadcn::Chart::Shape::Curve::Natural < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @param context [Chadcn::Chart::Shape::Path]
  def initialize(context)
    super
    @xs = []
    @ys = []
  end

  # @api private
  # @return [void]
  def line_start
    super
    @xs = []
    @ys = []
  end

  # @api private
  # @return [void]
  def line_end
    count = @xs.size
    draw if count.positive?
    close_path_if(count == 1)
    toggle_line
    @xs = []
    @ys = []
  end

  private

  def add_point(x, y)
    @xs << x
    @ys << y
  end

  def draw
    start_subpath(@xs[0], @ys[0])
    draw_line_to(@xs[1], @ys[1]) if @xs.size == 2
    return if @xs.size < 3

    first_x, second_x = ControlPoints.of(@xs)
    first_y, second_y = ControlPoints.of(@ys)
    (1...@xs.size).each do |end_index|
      start_index = end_index - 1
      draw_bezier_to(first_x[start_index], first_y[start_index], second_x[start_index], second_y[start_index], @xs[end_index], @ys[end_index])
    end
  end
end

# rubocop:enable Naming/MethodParameterName
