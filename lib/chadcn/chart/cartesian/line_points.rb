# frozen_string_literal: true

# The points of a line or an area series: recharts' `computeLinePoints` (cartesian/Line.js:638-683) and `computeArea`
# (cartesian/Area.js:665-762) with `getCateCoordinateOfLine` and `getBaseValue`. A point is `[x, y]`; a coordinate that could not be
# placed is nil, and the curve breaks there.
#
# @api private
module Chadcn::Chart::Cartesian::LinePoints
  # A point of a series: where it is (nil for a coordinate that could not be placed), the value it shows and the data row it comes from.
  Point = Data.define(:x, :y, :value, :row) do
    # @api private
    # @return [Array] `[x, y]`, the form the curves take
    def xy = [ x, y ]
  end

  # What an area is drawn from: the top points, the baseline (a pixel, or the points of the lower edge of a stacked area) and the
  # values (a `[lower, upper]` pair for every point).
  Area = Data.define(:points, :baseline, :values, :range)

  class << self
    # @api private
    # @param line [#options] the series
    # @param layout [Symbol]
    # @param axes [Hash{Symbol => Chadcn::Chart::Cartesian::Axis}] `:x` and `:y`
    # @param rows [Array<Hash>]
    # @return [Array<Point>] one point per row, or per row that could be placed in a vertical layout
    def line(line, layout:, axes:, rows:)
      horizontal = layout == :horizontal
      category = horizontal ? axes[:x] : axes[:y]
      numeric = horizontal ? axes[:y] : axes[:x]
      band = category.band_size
      rows.each_with_index.filter_map do |row, index|
        value = Chadcn::Chart::Cartesian::Value.read(row, line.options[:data_key])
        along = coordinate(category, row, index, band)
        across = value.nil? ? nil : numeric.map(value)
        point = Point.new(x: horizontal ? along : across, y: horizontal ? across : along, value: value, row: row)
        point if horizontal || (across && along)
      end
    end

    # @api private
    # @param area [#options] the series
    # @param layout [Symbol]
    # @param axes [Hash{Symbol => Chadcn::Chart::Cartesian::Axis}]
    # @param rows [Array<Hash>]
    # @param pairs [Array<Array(Float, Float)>, nil] the stacked pairs, nil when the area is not stacked
    # @param base_value [Numeric, String, Symbol, nil] the chart's `base_value`
    # @return [Area]
    def area(area, layout:, axes:, rows:, pairs:, base_value:)
      horizontal = layout == :horizontal
      category = horizontal ? axes[:x] : axes[:y]
      numeric = horizontal ? axes[:y] : axes[:x]
      band = category.band_size
      base = base_of(area.options[:base_value].nil? ? base_value : area.options[:base_value], numeric)
      values = rows.each_with_index.map do |row, index|
        next pairs[index] if pairs

        raw = Chadcn::Chart::Cartesian::Value.read(row, area.options[:data_key])
        raw.is_a?(Array) ? raw : [ base, raw ]
      end
      range = !pairs && rows.any? { |row| Chadcn::Chart::Cartesian::Value.read(row, area.options[:data_key]).is_a?(Array) }
      points = rows.each_with_index.map do |row, index|
        top = values[index]&.[](1)
        gap = top.nil? || (pairs && !area.options[:connect_nulls] && Chadcn::Chart::Cartesian::Value.read(row, area.options[:data_key]).nil?)
        along = coordinate(category, row, index, band)
        across = gap ? nil : numeric.map(top)
        Point.new(x: horizontal ? along : across, y: horizontal ? across : along, value: values[index], row: row)
      end
      baseline = pairs || range ? lower_edge(points, values, numeric, horizontal) : numeric.map(base) || 0.0
      Area.new(points: points, baseline: baseline, values: values, range: range)
    end

    private

    # `getBaseValue`
    def base_of(requested, numeric)
      return requested.to_f if Chadcn::Chart::Cartesian::Value.numeric?(requested)

      domain = numeric.domain
      named = requested.to_s.delete("_").downcase
      if numeric.settings.type == :number
        low, high = domain.minmax
        return low if named == "datamin"
        return high if named == "datamax"

        return high.negative? ? high : [ low, 0 ].max.to_f
      end
      return domain[0] if named == "datamin"

      named == "datamax" ? domain[1] : domain[0]
    end

    # The lower edge of a stacked or range area: the lower value of every point, at the same position along the category axis.
    def lower_edge(points, values, numeric, horizontal)
      points.each_with_index.map do |point, index|
        lower = values[index]&.first
        if horizontal
          Point.new(x: point.x, y: (!lower.nil? && !point.y.nil? ? numeric.map(lower) : nil), value: nil, row: nil)
        else
          Point.new(x: (lower.nil? ? nil : numeric.map(lower)), y: point.y, value: nil, row: nil)
        end
      end
    end

    # `getCateCoordinateOfLine`
    def coordinate(axis, row, index, band)
      if axis.category?
        key = axis.settings.data_key
        if !axis.settings.allow_duplicated_category && key && !Chadcn::Chart::Cartesian::Value.read(row, key).nil?
          match = axis.item_ticks.find { |tick| tick.value == Chadcn::Chart::Cartesian::Value.read(row, key) }
          return match.coordinate + (band / 2) if match
        end
        tick = axis.item_ticks[index]
        return tick && (tick.coordinate + (band / 2))
      end

      axis.map(Chadcn::Chart::Cartesian::Value.read(row, axis.settings.data_key))
    end
  end
end
