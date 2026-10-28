# frozen_string_literal: true

# d3-scale `scalePoint`: a {Chadcn::Chart::Scale::Band} with no bandwidth (inner padding 1), so each category is a single position.
# Only the outer padding and the alignment are configurable, like d3.
#
# @api private
class Chadcn::Chart::Scale::Point
  # @api private
  # @return [Integer] number of categories
  def count = @band.count

  # @api private
  # @return [Array<Float>] the two range values
  def range = @band.range

  # @api private
  # @return [Float] distance between two positions
  def step = @band.step

  # @api private
  # @return [Float] always 0
  def bandwidth = @band.bandwidth

  # @api private
  # @param count [Integer] number of categories
  # @param range [Array<Numeric>] two values
  # @param padding [Numeric] empty space at both ends, in steps
  # @param align [Numeric] 0..1, 0.5 centers the points
  def initialize(count:, range:, padding: 0, align: 0.5)
    @band = Chadcn::Chart::Scale::Band.new(count: count, range: range, padding_inner: 1, padding_outer: padding, align: align)
    freeze
  end

  # Position of a category, in range units.
  #
  # @api private
  # @param index [Integer] 0...count
  # @return [Float, nil] nil outside the categories
  def call(index) = @band.call(index)
end
