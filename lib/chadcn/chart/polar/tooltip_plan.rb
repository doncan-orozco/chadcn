# frozen_string_literal: true

# What a polar chart's `Tooltip` shows at every index (dev/port/specs/chart.md, "Tooltip"): the payload, the label, where the tooltip
# anchors, and the active dots drawn with it. recharts computes this in the browser from the pointer; the server cannot know which
# index is hovered, so it computes all of them: one {Entry} per sector for a pie (item tooltips, `PieChart` allows only `item`,
# chart/PieChart.js:11), one per category of the angle axis (radar) or of the radius axis (radial bar) for the axis tooltips of the other
# two charts, written as the inert templates `chadcn--chart` swaps and, for `default_index:`, drawn visible. The plan has the interface of
# {Chadcn::Chart::Cartesian::TooltipPlan}, which it extends.
#
# A polar tooltip has no cursor on the server: recharts draws it from the polar coordinate of the pointer (component/Cursor.js:66-94,
# util/cursor/getCursorPoints.js:19), which a `default_index:` does not have, and `Tooltip`'s `shared: false` (item tooltips of a radial bar
# chart) is not ported.
#
# @api private
class Chadcn::Chart::Polar::TooltipPlan < Chadcn::Chart::Cartesian::TooltipPlan
  # @api private
  # @return [Array<Entry>] one per sector or category, in order
  def entries = @entries ||= (@layout.chart_type == :pie ? pie_entries : axis_entries)

  private

  # --- pie ----------------------------------------------------------------------------------------------------------------

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
    item = { name: sector.name.to_s, data_key: options[:data_key].to_s, value: sector.value, color: color, type: options[:tooltip_type], unit: "",
             hide: options[:hide], payload: with_cell(sector.row, series.cells[sector.index]) }
    Entry.new(index: sector.index, label: nil, coordinate: { x: sector.tooltip_position[0], y: sector.tooltip_position[1] }, payload: filtered([ item ]),
              cursor: nil, dots: [])
  end

  # The row the way the pie's entry has it: with what the cell gave (`entryWithCellInfo`, polar/Pie.js:378).
  def with_cell(row, cell) = (row.is_a?(Hash) ? row : {}).merge(cell&.shape_attributes || {})

  # The entries of an item, `filter_null` and hidden series applied (component/Tooltip.js:142).
  def filtered(items)
    options = @tooltip.options
    return items unless options[:filter_null]

    items = items.select { |entry| !entry[:value].nil? && (!entry[:hide] || options[:include_hidden]) }
    options[:payload_uniq_by] ? items.uniq { |entry| entry[:data_key] } : items
  end

  # --- axis ---------------------------------------------------------------------------------------------------------------

  # One entry per category of the tooltip axis. The anchor is `combineCoordinateForDefaultIndex` (state/selectors/combiners/
  # combineCoordinateForDefaultIndex.js:23-37), which recharts itself marks as unsound for the polar layouts: the x is the middle of the chart
  # and the y the angle (or radius) of the tick.
  def axis_entries
    return [] unless @axis&.category?

    @axis.all_ticks.map do |tick|
      row = @rows[tick.index]
      coordinate = { x: (@layout.offset[:left] + @layout.width) / 2.0, y: tick.coordinate }
      Entry.new(index: tick.index, label: tick.value, coordinate: coordinate, payload: payload(row), cursor: nil, dots: dots(row))
    end
  end

  # A radial bar's entry holds the row as the arc has it (the arc spreads the row and its cell, polar/RadialBar.js:407), with the value the row
  # gives; a radar's is the series' own.
  def item(series, row)
    entry = super
    return entry unless series.kind == :radial_bar

    entry.merge(payload: with_cell(row, series.cells[@rows.index { |candidate| candidate.equal?(row) }]))
  end

  # The dot of every radar at this row (component/ActivePoints.js:19-56): `r` 4, white 2px stroke, the series color inside.
  def dots(row)
    @layout.placed.filter_map do |placed|
      next unless placed.series.kind == :radar

      active = placed.series.options[:active_dot]
      point = placed.shapes.find { |candidate| candidate.row.equal?(row) }
      next if active == false || point.nil?

      custom = active.is_a?(Hash) ? shape_attributes(active) : {}
      ActiveDot.new(series: placed.series, attrs: { cx: round(point.x), cy: round(point.y), r: "4", fill: placed.series.legend_color || "none", stroke: "#fff",
                                                    "stroke-width": "2" }.merge(custom))
    end
  end
end
