# frozen_string_literal: true

# recharts' `LabelList` (component/LabelList.js): a label on every shape of the series it is written in (the value of the shape, or of
# `data_key`). It renders nothing where it is written; the chart draws it in the labels layer.
#
# `fill:` is the list's, else the shape's own, else `#808080`. `class:` replaces `recharts-label` on every label, and every other attribute
# (`font_size:`, `data-*` ...) lands on every label.
#
# @example
#   chart.bar(data_key: :desktop) { |bar| bar.label_list(position: :top, offset: 12, class: "fill-foreground", font_size: 12) }
class Chadcn::Chart::LabelList < Chadcn::Chart::Declaration
  # Where a label sits around its shape. The first group is the rectangles of a bar, the points of a line, an area and a radar; the second
  # is the sectors of a pie and a radial bar (component/Label.js:158-206): `outside` is past the rim, `center`, `center_top` and
  # `center_bottom` the center of the chart, `inside_start`, `inside_end` and `end` follow the arc, and `middle` is the middle of the ring.
  # A position a shape does not know is centered, as in recharts.
  POSITIONS = %i[top bottom left right inside_left inside_right inside_top inside_bottom inside_top_left inside_top_right inside_bottom_left
                 inside_bottom_right center middle outside center_top center_bottom inside_start inside_end end].freeze

  # @api private
  # @return [Hash{Symbol => Object}] the keywords with defaults applied, frozen
  attr_reader :options

  # @param data_key [Symbol, String, #call, nil] the key of the data row to show; the value of the shape by default
  # @param position [Symbol, Hash] one of {POSITIONS}, or `{ x:, y: }` inside the shape
  # @param offset [Numeric] distance from the shape, px
  # @param formatter [#call, Hash, Symbol, nil] receives the value and returns the text, or `{ slice: [ start, stop ] }`, `:locale` or `:percent`
  # @param fill [String, nil]
  # @param angle [Numeric] rotate the text, degrees
  # @param attrs [Hash] attributes of every label; `class:` replaces `recharts-label`
  # @raise [ArgumentError] on a `position:` that is none of {POSITIONS}
  def initialize(data_key: nil, position: :middle, offset: 5, formatter: nil, fill: nil, angle: 0, **attrs)
    unless position.is_a?(Hash) || (position.respond_to?(:to_sym) && POSITIONS.include?(position.to_sym))
      raise ArgumentError, "position: must be one of #{POSITIONS.map(&:inspect).join(', ')} or { x:, y: } (got #{position.inspect})"
    end

    @options = { data_key: data_key, position: position.is_a?(Hash) ? position : position.to_sym, offset: offset,
                 formatter: Chadcn::Chart::Cartesian::Formatter.resolve(formatter), fill: fill, angle: angle, attrs: attrs }.freeze
    super()
  end
end
