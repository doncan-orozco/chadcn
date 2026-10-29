# frozen_string_literal: true

# recharts' `Text` (component/Text.js) for the drawers that write text: the string broken into lines for a width, the first line hung on
# the anchor with the `dy` of its vertical anchor, a `fill` of `url(...)` replaced by `#808080`, a rotation when the text has an angle.
#
# @api private
module Chadcn::Chart::Polar::Drawer::TextNodes
  DEFAULT_FILL = "#808080"

  private_constant :DEFAULT_FILL

  private

  # @param content [String] the text
  # @param at [Hash] `x:` and `y:` of the anchor
  # @param anchor [Symbol] :start, :middle or :end (the SVG `text-anchor`)
  # @param vertical [Symbol] :start, :middle or :end, how the text hangs on `y`
  # @param base [Hash] the attributes of the `text` (`fill:` among them)
  # @param class_name [String]
  # @param width [Numeric, nil] the width the text is broken to; no breaking without one
  # @param angle [Numeric] rotation, degrees
  def text_node(content, at, anchor:, vertical:, base:, class_name:, width: nil, angle: 0)
    lines = layout.text.lines(content.to_s, line_width: width)
    fill = base[:fill].to_s.include?("url") ? DEFAULT_FILL : (base[:fill] || DEFAULT_FILL)
    left = format_number(at[:x])
    top = format_number(at[:y])
    rotation = angle.to_f.zero? ? nil : "rotate(#{format_number(angle)}, #{left}, #{top})"
    shown = base.except(:fill, :class, :transform)
    text(**shown, x: left, y: top, class: class_name, "text-anchor": anchor.to_s, fill: fill, transform: rotation || base[:transform]) do
      lines.each_with_index do |line, index|
        tspan(x: left, dy: index.zero? ? layout.text.first_dy(vertical, lines.size) : "1em") { plain(line) }
      end
    end
  end
end
