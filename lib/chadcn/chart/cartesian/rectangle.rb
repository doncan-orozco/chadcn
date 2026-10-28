# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of SVG paths

# The `d` attribute of a bar: recharts' `getRectanglePath` (shape/Rectangle.js:31-70) with every number rounded to four decimals
# (util/round.js `roundTemplateLiteral`). The text between the numbers, newlines and indentation included, is the template literal's.
#
# @api private
module Chadcn::Chart::Cartesian::Rectangle
  Number = Chadcn::Chart::Shape::Number

  private_constant :Number

  class << self
    # @api private
    # @param x [Float]
    # @param y [Float]
    # @param width [Float] negative for a bar that grows left
    # @param height [Float] negative for a bar that grows up
    # @param radius [Numeric, Array<Numeric>, nil] one radius, or `[top-left, top-right, bottom-right, bottom-left]`
    # @return [String]
    def path(x, y, width, height, radius)
      max_radius = [ round(width).abs / 2, round(height).abs / 2 ].min
      y_sign = round(height) >= 0 ? 1 : -1
      x_sign = round(width) >= 0 ? 1 : -1
      clockwise = (round(height) >= 0 && round(width) >= 0) || (round(height).negative? && round(width).negative?) ? 1 : 0
      geometry = { x: x, y: y, width: width, height: height, x_sign: x_sign, y_sign: y_sign, clockwise: clockwise }
      if max_radius.positive? && radius.is_a?(Array)
        corners_path(geometry, (0...4).map { |index| [ radius[index] || 0, max_radius ].min })
      elsif max_radius.positive? && radius.is_a?(Numeric) && radius.positive?
        uniform_path(geometry, [ max_radius, radius ].min)
      else
        "M #{n(x)},#{n(y)} h #{n(width)} v #{n(height)} h #{n(-width)} Z"
      end
    end

    # `round(value)` of util/round.js: four decimals, never -0.
    #
    # @api private
    # @param value [Numeric]
    # @return [Float]
    def round(value) = Number.round(value, 4)

    private

    def n(value) = Number.format(round(value))

    # An array radius: an arc only for a corner that has a radius; the second to fourth arcs break the line after the sweep flag.
    def corners_path(g, radii)
      x, y, width, height = g.values_at(:x, :y, :width, :height)
      sx = g[:x_sign]
      sy = g[:y_sign]
      cw = g[:clockwise]
      top_left, top_right, bottom_right, bottom_left = radii
      d = "M#{n(x)},#{n(y + (sy * top_left))}"
      d << "A #{n(top_left)},#{n(top_left)},0,0,#{cw},#{n(x + (sx * top_left))},#{n(y)}" if top_left.positive?
      d << "L #{n(x + width - (sx * top_right))},#{n(y)}"
      d << "A #{n(top_right)},#{n(top_right)},0,0,#{cw},\n        #{n(x + width)},#{n(y + (sy * top_right))}" if top_right.positive?
      d << "L #{n(x + width)},#{n(y + height - (sy * bottom_right))}"
      d << "A #{n(bottom_right)},#{n(bottom_right)},0,0,#{cw},\n        #{n(x + width - (sx * bottom_right))},#{n(y + height)}" if bottom_right.positive?
      d << "L #{n(x + (sx * bottom_left))},#{n(y + height)}"
      d << "A #{n(bottom_left)},#{n(bottom_left)},0,0,#{cw},\n        #{n(x)},#{n(y + height - (sy * bottom_left))}" if bottom_left.positive?
      d << "Z"
    end

    # A number radius: the four corners, in the multi-line template of recharts.
    def uniform_path(g, r)
      x, y, width, height = g.values_at(:x, :y, :width, :height)
      sx = g[:x_sign]
      sy = g[:y_sign]
      cw = g[:clockwise]
      arc = "A #{n(r)},#{n(r)},0,0,#{cw},"
      indent = "\n            "
      [ "M #{n(x)},#{n(y + (sy * r))}",
        "#{indent}#{arc}#{n(x + (sx * r))},#{n(y)}",
        "#{indent}L #{n(x + width - (sx * r))},#{n(y)}",
        "#{indent}#{arc}#{n(x + width)},#{n(y + (sy * r))}",
        "#{indent}L #{n(x + width)},#{n(y + height - (sy * r))}",
        "#{indent}#{arc}#{n(x + width - (sx * r))},#{n(y + height)}",
        "#{indent}L #{n(x + (sx * r))},#{n(y + height)}",
        "#{indent}#{arc}#{n(x)},#{n(y + height - (sy * r))} Z" ].join
    end
  end
end

# rubocop:enable Naming/MethodParameterName
