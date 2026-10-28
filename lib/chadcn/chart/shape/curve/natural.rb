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
    @xs = @ys = nil
  end

  # @api private
  # @return [void]
  def point(x, y)
    @xs << x.to_f
    @ys << y.to_f
  end

  private

  def draw
    start_subpath(@xs[0], @ys[0])
    @context.line_to(@xs[1], @ys[1]) if @xs.size == 2
    return if @xs.size < 3

    px = control_points(@xs)
    py = control_points(@ys)
    (1...@xs.size).each do |i1|
      i0 = i1 - 1
      @context.bezier_to(px[0][i0], py[0][i0], px[1][i0], py[1][i0], @xs[i1], @ys[i1])
    end
  end

  # Tridiagonal solve for the Bezier control points of one coordinate (https://www.particleincell.com/2012/bezier-splines/, as in
  # d3-shape curve/natural.js). Returns [first control points, second control points].
  def control_points(coords)
    n = coords.size - 1
    a = Array.new(n, 0.0)
    b = Array.new(n, 0.0)
    r = Array.new(n, 0.0)
    a[0] = 0.0
    b[0] = 2.0
    r[0] = coords[0] + (2 * coords[1])
    (1...(n - 1)).each do |i|
      a[i] = 1.0
      b[i] = 4.0
      r[i] = (4 * coords[i]) + (2 * coords[i + 1])
    end
    a[n - 1] = 2.0
    b[n - 1] = 7.0
    r[n - 1] = (8 * coords[n - 1]) + coords[n]
    (1...n).each do |i|
      m = a[i] / b[i - 1]
      b[i] -= m
      r[i] -= m * r[i - 1]
    end
    a[n - 1] = r[n - 1] / b[n - 1]
    (n - 2).downto(0) { |i| a[i] = (r[i] - a[i + 1]) / b[i] }
    b[n - 1] = (coords[n] + a[n - 1]) / 2
    (0...(n - 1)).each { |i| b[i] = (2 * coords[i + 1]) - a[i + 1] }
    [ a, b ]
  end
end

# rubocop:enable Naming/MethodParameterName
