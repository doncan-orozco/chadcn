# frozen_string_literal: true

# The rectangles of one bar series: recharts' `computeBarRectangles` (cartesian/Bar.js:556-686) with `getCateCoordinateOfBar`,
# `getBaseValueOfBar` and `truncateByDomain` (util/ChartUtils.js). A rectangle is dropped when it has no width or height, or when its
# value cannot be placed on the axes; the index of a rectangle is the index of its data row (that is what a `Cell` is matched by).
#
# @api private
module Chadcn::Chart::Cartesian::BarShapes
  # One bar: the pixel box, the value the label shows, the data row and its index.
  Rect = Data.define(:x, :y, :width, :height, :value, :row, :index)

  class << self
    # @api private
    # @param bar [#options] the series
    # @param layout [Symbol] :horizontal or :vertical
    # @param position [Chadcn::Chart::Cartesian::BarPositions::Position] the slot of the bar inside its band
    # @param axes [Hash{Symbol => Chadcn::Chart::Cartesian::Axis}] `:x` and `:y`
    # @param rows [Array<Hash>] the chart data
    # @param pairs [Array<Array(Float, Float)>, nil] the stacked `[lower, upper]` of every row, nil when the bar is not stacked
    # @return [Array<Rect>]
    def rectangles(bar, layout:, position:, axes:, rows:, pairs:)
      numeric = layout == :horizontal ? axes[:y] : axes[:x]
      base = base_value(numeric)
      min_point = bar.options[:min_point_size].to_f
      rows.each_with_index.filter_map do |row, index|
        value = value_pair(bar, row, index, pairs, numeric, base) or next
        placement = { axes: axes, position: position, row: row, index: index, value: value, shown: pairs ? value : value[1], min_point: min_point }
        rect = layout == :horizontal ? horizontal(**placement) : vertical(**placement)
        next if rect.nil? || rect.width.zero? || rect.height.zero?

        rect
      end
    end

    private

    def value_pair(bar, row, index, pairs, numeric, base)
      if pairs
        pair = pairs[index] or return
        truncate(pair, numeric.domain)
      else
        value = Chadcn::Chart::Cartesian::Value.read(row, bar.options[:data_key])
        value.is_a?(Array) ? value : [ base, value ]
      end
    end

    # `getBaseValueOfBar`: where bars start (the zero line, or the nearest end of the domain).
    def base_value(numeric)
      domain = numeric.domain
      return domain&.first unless numeric.settings.type == :number && domain

      low, high = domain.minmax
      return 0.0 if 0.0.between?(low, high)

      high.negative? ? high : low
    end

    # `truncateByDomain`: a stacked value kept inside the domain.
    def truncate(pair, domain)
      return pair unless domain && domain.size == 2 && domain.all? { |bound| Chadcn::Chart::Cartesian::Value.numeric?(bound) }

      low, high = domain.minmax
      lower = Chadcn::Chart::Cartesian::Value.numeric?(pair[0]) && pair[0] >= low ? pair[0] : low
      upper = Chadcn::Chart::Cartesian::Value.numeric?(pair[1]) && pair[1] <= high ? pair[1] : high
      lower = high if lower > high
      upper = low if upper < low
      [ lower, upper ]
    end

    def horizontal(axes:, position:, row:, index:, value:, shown:, min_point:)
      base = axes[:y].position_of(value[0])
      current = axes[:y].position_of(value[1])
      return if base.nil? || current.nil?

      x = category_coordinate(axes[:x], row, index, position.offset) or return
      height = base - current
      height = 0.0 if height.nan?
      y = current
      if min_point.abs.positive? && height.abs < min_point.abs
        delta = sign(height.zero? ? min_point : height) * (min_point.abs - height.abs)
        y -= delta
        height += delta
      end
      Rect.new(x: x, y: y, width: position.size, height: height, value: shown, row: row, index: index)
    end

    def vertical(axes:, position:, row:, index:, value:, shown:, min_point:)
      base = axes[:x].position_of(value[0])
      current = axes[:x].position_of(value[1])
      return if base.nil? || current.nil?

      y = category_coordinate(axes[:y], row, index, position.offset) or return
      width = current - base
      width += sign(width.zero? ? min_point : width) * (min_point.abs - width.abs) if min_point.abs.positive? && width.abs < min_point.abs
      Rect.new(x: base, y: y, width: width, height: position.size, value: shown, row: row, index: index)
    end

    def sign(value)
      return 0 if value.zero?

      value.positive? ? 1 : -1
    end

    # `getCateCoordinateOfBar`
    def category_coordinate(axis, row, index, offset)
      if axis.category?
        tick = axis.item_ticks[index]
        return tick && (tick.coordinate + offset)
      end

      scaled = axis.position_of(Chadcn::Chart::Cartesian::Value.read(row, axis.settings.data_key))
      scaled && (scaled - (axis.band_size(bar: true).to_f / 2) + offset)
    end
  end
end
