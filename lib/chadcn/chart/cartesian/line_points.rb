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

  # The two axes of a layout seen from the series: the one the categories run along, the one the values are measured on, and the
  # width of a category band.
  Sides = Data.define(:category, :numeric, :horizontal, :band)

  private_constant :Sides

  class << self
    # @api private
    # @param series [#options] the line
    # @param layout [Symbol]
    # @param axes [Hash{Symbol => Chadcn::Chart::Cartesian::Axis}] `:x` and `:y`
    # @param rows [Array<Hash>]
    # @return [Array<Point>] one point per row, or per row that could be placed in a vertical layout
    def line(series, layout:, axes:, rows:)
      sides = sides_of(layout, axes)
      rows.each_with_index.filter_map do |row, index|
        value = Chadcn::Chart::Cartesian::Value.read(row, series.options[:data_key])
        along = coordinate(sides.category, row, index, sides.band)
        across = value.nil? ? nil : sides.numeric.position_of(value)
        point = point_at(sides, along, across, value, row)
        point if sides.horizontal || (across && along)
      end
    end

    # @api private
    # @param series [#options] the area
    # @param layout [Symbol]
    # @param axes [Hash{Symbol => Chadcn::Chart::Cartesian::Axis}]
    # @param rows [Array<Hash>]
    # @param pairs [Array<Array(Float, Float)>, nil] the stacked pairs, nil when the area is not stacked
    # @param chart_base_value [Numeric, String, Symbol, nil] the chart's `base_value`
    # @return [Area]
    def area(series, layout:, axes:, rows:, pairs:, chart_base_value:)
      sides = sides_of(layout, axes)
      numeric = sides.numeric
      base = base_of(series.options[:base_value].nil? ? chart_base_value : series.options[:base_value], numeric)
      raws = rows.map { |row| Chadcn::Chart::Cartesian::Value.read(row, series.options[:data_key]) }
      values = raws.each_with_index.map do |raw, index|
        next pairs[index] if pairs

        raw.is_a?(Array) ? raw : [ base, raw ]
      end
      range = !pairs && raws.any?(Array)
      points = rows.each_with_index.map do |row, index|
        top = values[index]&.[](1)
        gap = top.nil? || (pairs && !series.options[:connect_nulls] && raws[index].nil?)
        along = coordinate(sides.category, row, index, sides.band)
        across = gap ? nil : numeric.position_of(top)
        point_at(sides, along, across, values[index], row)
      end
      baseline = pairs || range ? lower_edge(points, values, numeric, sides.horizontal) : numeric.position_of(base) || 0.0
      Area.new(points: points, baseline: baseline, values: values, range: range)
    end

    private

    def sides_of(layout, axes)
      horizontal = layout == :horizontal
      category = horizontal ? axes[:x] : axes[:y]
      Sides.new(category: category, numeric: horizontal ? axes[:y] : axes[:x], horizontal: horizontal, band: category.band_size)
    end

    # A point where `along` the category axis and `across` it (the value axis) meet, as x and y for the layout.
    def point_at(sides, along, across, value, row)
      Point.new(x: sides.horizontal ? along : across, y: sides.horizontal ? across : along, value: value, row: row)
    end

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
          Point.new(x: point.x, y: (!lower.nil? && !point.y.nil? ? numeric.position_of(lower) : nil), value: nil, row: nil)
        else
          Point.new(x: (lower.nil? ? nil : numeric.position_of(lower)), y: point.y, value: nil, row: nil)
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

      axis.position_of(Chadcn::Chart::Cartesian::Value.read(row, axis.settings.data_key))
    end
  end
end
