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
        "M #{format_number(x)},#{format_number(y)} h #{format_number(width)} v #{format_number(height)} h #{format_number(-width)} Z"
      end
    end

    # `round(value)` of util/round.js: four decimals, never -0.
    #
    # @api private
    # @param value [Numeric]
    # @return [Float]
    def round(value) = Number.round(value, 4)

    private

    def format_number(value) = Number.format(round(value))

    # An array radius: an arc only for a corner that has a radius; the second to fourth arcs break the line after the sweep flag.
    def corners_path(geometry, radii)
      x, y, width, height = geometry.values_at(:x, :y, :width, :height)
      x_direction = geometry[:x_sign]
      y_direction = geometry[:y_sign]
      sweep = geometry[:clockwise]
      top_left, top_right, bottom_right, bottom_left = radii
      outline = "M#{format_number(x)},#{format_number(y + (y_direction * top_left))}"
      outline << "A #{format_number(top_left)},#{format_number(top_left)},0,0,#{sweep},#{format_number(x + (x_direction * top_left))},#{format_number(y)}" if top_left.positive?
      outline << "L #{format_number(x + width - (x_direction * top_right))},#{format_number(y)}"
      outline << "A #{format_number(top_right)},#{format_number(top_right)},0,0,#{sweep},\n        #{format_number(x + width)},#{format_number(y + (y_direction * top_right))}" if top_right.positive?
      outline << "L #{format_number(x + width)},#{format_number(y + height - (y_direction * bottom_right))}"
      outline << "A #{format_number(bottom_right)},#{format_number(bottom_right)},0,0,#{sweep},\n        #{format_number(x + width - (x_direction * bottom_right))},#{format_number(y + height)}" if bottom_right.positive?
      outline << "L #{format_number(x + (x_direction * bottom_left))},#{format_number(y + height)}"
      outline << "A #{format_number(bottom_left)},#{format_number(bottom_left)},0,0,#{sweep},\n        #{format_number(x)},#{format_number(y + height - (y_direction * bottom_left))}" if bottom_left.positive?
      outline << "Z"
    end

    # A number radius: the four corners, in the multi-line template of recharts.
    def uniform_path(geometry, radius)
      x, y, width, height = geometry.values_at(:x, :y, :width, :height)
      x_direction = geometry[:x_sign]
      y_direction = geometry[:y_sign]
      sweep = geometry[:clockwise]
      arc = "A #{format_number(radius)},#{format_number(radius)},0,0,#{sweep},"
      indent = "\n            "
      [ "M #{format_number(x)},#{format_number(y + (y_direction * radius))}",
        "#{indent}#{arc}#{format_number(x + (x_direction * radius))},#{format_number(y)}",
        "#{indent}L #{format_number(x + width - (x_direction * radius))},#{format_number(y)}",
        "#{indent}#{arc}#{format_number(x + width)},#{format_number(y + (y_direction * radius))}",
        "#{indent}L #{format_number(x + width)},#{format_number(y + height - (y_direction * radius))}",
        "#{indent}#{arc}#{format_number(x + width - (x_direction * radius))},#{format_number(y + height)}",
        "#{indent}L #{format_number(x + (x_direction * radius))},#{format_number(y + height)}",
        "#{indent}#{arc}#{format_number(x)},#{format_number(y + height - (y_direction * radius))} Z" ].join
    end
  end
end

# rubocop:enable Naming/MethodParameterName
