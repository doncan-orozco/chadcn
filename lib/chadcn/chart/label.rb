# frozen_string_literal: true

# recharts' `Label` (component/Label.js) written in a chart: a piece of text placed around the plot (`position:`), e.g. a title for a
# reference line's side. It renders nothing where it is written; the chart draws it in the labels layer. For the values of the shapes of
# a series use {Chadcn::Chart::LabelList}.
#
# @example
#   chart.label(value: "Target", position: :top)
class Chadcn::Chart::Label < Chadcn::Chart::Declaration
  # @api private
  # @return [Hash{Symbol => Object}] the keywords with defaults applied, frozen
  attr_reader :options

  # @param value [String, Numeric, nil] the text; nothing is drawn without one
  # @param position [Symbol, Hash] one of {Chadcn::Chart::LabelList::POSITIONS}, or `{ x:, y: }` inside the plot
  # @param offset [Numeric] distance from the edge of the plot, px
  # @param formatter [#call, Hash, Symbol, nil] receives the value and returns the text
  # @param fill [String, nil] `#808080` by default
  # @param angle [Numeric] rotate the text, degrees
  # @param attrs [Hash] attributes of the text; `class:` replaces `recharts-label`
  # @raise [ArgumentError] on a `position:` that is none of the positions
  def initialize(value: nil, position: :middle, offset: 5, formatter: nil, fill: nil, angle: 0, **attrs)
    unless position.is_a?(Hash) || (position.respond_to?(:to_sym) && Chadcn::Chart::LabelList::POSITIONS.include?(position.to_sym))
      raise ArgumentError, "position: must be one of #{Chadcn::Chart::LabelList::POSITIONS.map(&:inspect).join(', ')} or { x:, y: } (got #{position.inspect})"
    end

    @options = { value: value, position: position.is_a?(Hash) ? position : position.to_sym, offset: offset,
                 formatter: Chadcn::Chart::Cartesian::Formatter.resolve(formatter), fill: fill, angle: angle, attrs: attrs }.freeze
    super()
  end
end
