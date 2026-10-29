# frozen_string_literal: true

# The room a legend takes from the plot (`appendOffsetOfLegend`, util/ChartUtils.js, read by state/selectors/selectChartOffsetInternal.js):
# a legend beside the plot takes its width from that side, one above or below takes its height.
#
# @api private
module Chadcn::Chart::Polar::LegendOffset
  class << self
    # @api private
    # @param offset [Hash{Symbol => Float}] `top`, `right`, `bottom` and `left`: the margin
    # @param legend [Hash, nil] the options of the declared legend
    # @param height [Numeric, nil] the height of the legend box
    # @return [Hash{Symbol => Float}] the offset with the legend's room added
    def call(offset, legend, height)
      return offset unless legend

      align = legend[:align]
      vertical_align = legend[:vertical_align]
      box_width = legend[:width].is_a?(Numeric) ? legend[:width] : 0
      return offset.merge(align => offset[align] + box_width) if beside?(legend, align, vertical_align)
      return offset.merge(vertical_align => offset[vertical_align] + height) if above_or_below?(legend, align, vertical_align)

      offset
    end

    private

    def beside?(legend, align, vertical_align)
      (legend[:layout] == :vertical || (legend[:layout] == :horizontal && vertical_align == :middle)) && align != :center
    end

    def above_or_below?(legend, align, vertical_align)
      (legend[:layout] == :horizontal || (legend[:layout] == :vertical && align == :center)) && vertical_align != :middle
    end
  end
end
