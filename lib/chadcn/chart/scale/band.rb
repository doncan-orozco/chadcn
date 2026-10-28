# frozen_string_literal: true

# d3-scale `scaleBand` over `count` categories (indexes 0...count): equal bands with inner padding between them and outer padding
# around them, aligned inside the range. A reversed range (`[300, 0]`) lays the bands out from the end. Immutable.
#
# @api private
class Chadcn::Chart::Scale::Band
  # @api private
  # @return [Integer] number of categories
  attr_reader :count

  # @api private
  # @return [Array<Float>] the two range values
  attr_reader :range

  # @api private
  # @return [Float] space between two band starts, padding included
  attr_reader :step

  # @api private
  # @return [Float] width of one band
  attr_reader :bandwidth

  # @api private
  # @return [Float] fraction (0..1) of the extra space placed before the first band
  attr_reader :align

  # @api private
  # @return [Float] inner padding, a fraction (0..1) of the step
  attr_reader :padding_inner

  # @api private
  # @return [Float] outer padding, in steps
  attr_reader :padding_outer

  # @api private
  # @param count [Integer] number of categories
  # @param range [Array<Numeric>] two values
  # @param padding [Numeric, nil] d3 `padding`: sets the outer padding and the inner one (capped at 1); the two keywords below win
  # @param padding_inner [Numeric, nil] fraction of the step left empty between bands (capped at 1)
  # @param padding_outer [Numeric, nil] empty space at both ends, in steps
  # @param align [Numeric] 0 packs the bands at the start of the range, 1 at the end, 0.5 centers them (clamped to 0..1)
  def initialize(count:, range:, padding: nil, padding_inner: nil, padding_outer: nil, align: 0.5)
    raise ArgumentError, "range takes two values" unless range.size == 2

    @count = count
    @range = range.map(&:to_f).freeze
    outer = (padding_outer || padding || 0).to_f
    @padding_outer = outer
    @padding_inner = [ 1.0, (padding_inner || padding || 0).to_f ].min
    @align = align.to_f.clamp(0.0, 1.0)
    @first, @step, @bandwidth = layout
    freeze
  end

  # Start of the band of a category, in range units.
  #
  # @api private
  # @param index [Integer] 0...count
  # @return [Float, nil] nil outside the categories
  def call(index)
    return nil unless index.is_a?(Integer) && index >= 0 && index < @count

    position = @range[1] < @range[0] ? @count - 1 - index : index
    @first + (@step * position)
  end

  private

  # d3-scale band.js `rescale` (band.js:19-31), without rounding.
  def layout
    reverse = @range[1] < @range[0]
    start, stop = reverse ? @range.reverse : @range
    step = (stop - start) / [ 1, @count - @padding_inner + (@padding_outer * 2) ].max
    first = start + ((stop - start - (step * (@count - @padding_inner))) * @align)
    [ first, step, step * (1 - @padding_inner) ]
  end
end
