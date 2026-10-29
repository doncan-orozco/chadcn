# frozen_string_literal: true

# What a polar chart's `Tooltip` shows at every index (dev/port/specs/chart.md, "Tooltip"): the payload, the label, where the tooltip
# anchors, and the cursor and active dots drawn with it. recharts computes this in the browser from the pointer; the server cannot know which
# index is hovered, so it computes all of them: one {Entry} per sector for a pie (item tooltips, `PieChart` allows only `item`,
# chart/PieChart.js:11), one per angle (radar) or radius (radial bar) category for the axis tooltips of the other two charts, written as
# the inert templates `chadcn--chart` swaps and, for `default_index:`, drawn visible. The plan has the interface of
# {Chadcn::Chart::Cartesian::TooltipPlan}, which it extends.
#
# @api private
class Chadcn::Chart::Polar::TooltipPlan < Chadcn::Chart::Cartesian::TooltipPlan
  # @api private
  # @return [Array<Entry>] one per sector or category, in order
  def entries = @entries ||= (@layout.chart_type == :pie ? pie_entries : [])

  private

  # `SetPieTooltipEntrySettings` (polar/Pie.js:90-139): the entry of a sector is the sector alone, anchored at its centroid, with no label.
  def pie_entries
    @declared.series.flat_map do |series|
      next [] if series.options[:hide] && !@tooltip.options[:include_hidden]

      placed = @layout.placed.find { |candidate| candidate.series.equal?(series) } or next []
      placed.shapes.map { |sector| pie_entry(series, sector) }
    end
  end

  def pie_entry(series, sector)
    options = series.options
    shown = Chadcn::Chart::Polar::PieSectors.presentation(series, sector)
    color = shown[:fill].is_a?(String) ? shown[:fill] : options[:fill]
    row = (sector.row.is_a?(Hash) ? sector.row : {}).merge(series.cells[sector.index]&.shape_attributes || {})
    item = { name: sector.name.to_s, data_key: options[:data_key].to_s, value: sector.value, color: color, type: options[:tooltip_type], unit: "",
             hide: options[:hide], payload: row }
    Entry.new(index: sector.index, label: nil, coordinate: { x: sector.tooltip_position[0], y: sector.tooltip_position[1] }, payload: payload([ item ]),
              cursor: nil, dots: [])
  end

  # The entries of an item, `filter_null` and hidden series applied (component/Tooltip.js:142).
  def payload(items)
    options = @tooltip.options
    return items unless options[:filter_null]

    items = items.select { |entry| !entry[:value].nil? && (!entry[:hide] || options[:include_hidden]) }
    options[:payload_uniq_by] ? items.uniq { |entry| entry[:data_key] } : items
  end
end
