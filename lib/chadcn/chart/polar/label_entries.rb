# frozen_string_literal: true

# What a label list labels: one entry per shape of the series it is written in (polar/Pie.js:420-450, polar/RadialBar.js:20-40,
# polar/Radar.js:196-226). A pie or radial bar sector is a polar view box; a radar point is a box of no size (the radar provides a
# cartesian label list context).
#
# @api private
module Chadcn::Chart::Polar::LabelEntries
  # `value` is what the shape shows, `fill` its color (nil when the shape has none), `row` the data row, `view_box` the sector or `box` the
  # point the label sits on, `attributes` the SVG attributes the entry gives the label (`svgPropertiesAndEvents(entry)`, component/LabelList.js:97:
  # a radar point is a box of no size, so its labels carry `width="0" height="0"`).
  Entry = Data.define(:value, :fill, :row, :view_box, :box, :attributes)

  class << self
    # @api private
    # @param placed [Chadcn::Chart::Polar::Layout::Placed]
    # @return [Array<Entry>]
    def call(placed)
      series = placed.series
      case series.kind
      when :radar then placed.shapes.map { |point| point_entry(point) }
      else placed.shapes.map { |sector| sector_entry(sector, series) }
      end
    end

    private

    def point_entry(point)
      Entry.new(value: point.value.nil? ? "" : point.value, fill: nil, row: point.row, view_box: nil,
                box: { x: point.x, y: point.y, width: 0.0, height: 0.0 }, attributes: { width: 0.0, height: 0.0 })
    end

    def sector_entry(sector, series)
      # A pie sector falls back to the pie's own fill (polar/Pie.js:399, `presentationProps`); a radial bar sector has the row's and cell's only.
      fill = sector.attributes[:fill] || (series.options[:fill] if series.kind == :pie)
      Entry.new(value: sector.value, fill: fill, row: sector.row, view_box: sector.view_box, box: nil, attributes: {})
    end
  end
end
