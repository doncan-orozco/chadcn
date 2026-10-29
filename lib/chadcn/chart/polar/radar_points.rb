# frozen_string_literal: true

# The points of one radar: recharts' `computeRadarPoints` (polar/Radar.js:100-150). Each row puts a point on the angle of its category, at
# the radius its value gives; a row without a value puts it at the center.
#
# @api private
module Chadcn::Chart::Polar::RadarPoints
  # One point: where it is (`x`, `y`), the `name` of its category, its `value`, the center, its `radius` and `angle`, and its data `row`.
  Point = Data.define(:x, :y, :name, :value, :cx, :cy, :radius, :angle, :row)

  class << self
    # @api private
    # @param series [Chadcn::Chart::Radar]
    # @param rows [Array<Hash>] the data of the chart
    # @param angle_axis [Chadcn::Chart::Polar::Axis]
    # @param radius_axis [Chadcn::Chart::Polar::Axis]
    # @param view_box [Chadcn::Chart::Polar::ViewBox]
    # @return [Array<Point>] one per row
    # @raise [ArgumentError] on a range value (`[low, high]`), which is not ported
    def call(series, rows:, angle_axis:, radius_axis:, view_box:)
      key = series.options[:data_key]
      # A category axis moves every point by a band (`angleBandSize`); a number axis does not.
      band = angle_axis.category? ? (angle_axis.band_size || 0.0) : 0.0
      rows.each_with_index.map do |row, index|
        value = Chadcn::Chart::Cartesian::Value.read(row, key)
        raise ArgumentError, "radar ranges ([low, high] values) are not ported (got #{value.inspect} for #{key.inspect})" if value.is_a?(Array)

        name = angle_name(row, angle_axis, index)
        angle = (angle_axis.position_of(name) || 0.0) + band
        radius = value.nil? ? 0.0 : (radius_axis.position_of(value) || 0.0)
        x, y = view_box.point(radius, angle)
        Point.new(x: x, y: y, name: name, value: value, cx: view_box.cx, cy: view_box.cy, radius: radius, angle: angle, row: row)
      end
    end

    private

    # `getValueByDataKey(entry, angleAxis.dataKey, i)`: the row index stands for a row without a category.
    def angle_name(row, angle_axis, index)
      key = angle_axis.settings.data_key
      found = Chadcn::Chart::Cartesian::Value.read(row, key)
      found.nil? ? index : found
    end
  end
end
