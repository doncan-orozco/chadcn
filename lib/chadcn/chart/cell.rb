# frozen_string_literal: true

# recharts' `Cell` (component/Cell.js): per-shape attributes for the series it is written in. Like recharts' `Cell`, it renders nothing
# itself; the bar reads it, and the n-th cell styles the rectangle of the n-th data row (its `fill:`, `stroke:`, `stroke_width:`, `class:`
# and any other attribute).
#
# @example
#   chart.bar(data_key: :visitors) { |bar| rows.each { |row| bar.cell(fill: row[:fill]) } }
class Chadcn::Chart::Cell < Chadcn::Chart::Declaration
  # @param fill [String, nil]
  # @param stroke [String, nil]
  # @param stroke_width [Numeric, nil]
  # @param attrs [Hash] any attribute of the shape; `class:` is added to the shape's class
  def initialize(fill: nil, stroke: nil, stroke_width: nil, **attrs)
    @shape_attributes = { fill: fill, stroke: stroke, stroke_width: stroke_width, **attrs }.compact.freeze
    super()
  end

  # @api private
  # @return [Hash{Symbol => Object}] the attributes the shape takes from this cell
  attr_reader :shape_attributes
end
