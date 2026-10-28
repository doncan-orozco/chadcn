# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# SVG path builder with the output of d3-path 3.1 (`Path` with `digits`): move, line and cubic segments, every number rounded
# to `digits` decimals and printed the way JavaScript prints it. The curves of {Chadcn::Chart::Shape::Curve} draw on it.
#
# @api private
class Chadcn::Chart::Shape::Path
  # d3-shape's default (`withPath`): three decimals.
  DEFAULT_DIGITS = 3

  # @api private
  # @param digits [Integer, nil] decimals kept in every number; nil prints them unrounded
  def initialize(digits: DEFAULT_DIGITS)
    raise ArgumentError, "invalid digits: #{digits.inspect}" if digits && !(digits.is_a?(Integer) && digits >= 0)

    @digits = digits
    @start = nil
    @current = nil
    @out = +""
  end

  # Starts a subpath (`M`).
  #
  # @api private
  # @return [void]
  def move_to(x, y)
    @start = @current = [ x.to_f, y.to_f ]
    @out << "M#{number(x)},#{number(y)}"
  end

  # Straight segment to a point (`L`).
  #
  # @api private
  # @return [void]
  def line_to(x, y)
    @current = [ x.to_f, y.to_f ]
    @out << "L#{number(x)},#{number(y)}"
  end

  # Cubic Bezier segment (`C`) with two control points.
  #
  # @api private
  # @return [void]
  def bezier_to(x1, y1, x2, y2, x, y)
    @current = [ x.to_f, y.to_f ]
    @out << "C#{[ x1, y1, x2, y2, x, y ].map { |value| number(value) }.join(',')}"
  end

  # Closes the current subpath (`Z`); nothing happens before the first `move_to`, as in d3.
  #
  # @api private
  # @return [void]
  def close
    return unless @current

    @current = @start
    @out << "Z"
  end

  # @api private
  # @return [Boolean] true while nothing has been drawn
  def empty? = @out.empty?

  # @api private
  # @return [String] the path data so far ("" when empty)
  def to_s = @out.dup

  # The path data the way d3 `line()`/`area()` return it: nil rather than an empty string.
  #
  # @api private
  # @return [String, nil]
  def d = empty? ? nil : to_s

  private

  def number(value)
    float = value.to_f
    Chadcn::Chart::Shape::Number.format(@digits ? Chadcn::Chart::Shape::Number.round(float, @digits) : float)
  end
end

# rubocop:enable Naming/MethodParameterName
