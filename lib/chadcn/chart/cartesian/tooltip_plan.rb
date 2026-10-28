# frozen_string_literal: true

# What a chart's `Tooltip` shows at every category: the payload of the series, the label, where the tooltip anchors, and the cursor and
# active dots drawn with it. recharts computes this in the browser from the pointer; the server cannot know which category is
# hovered, so it computes all of them (dev/port/specs/chart.md, "Tooltip"): one {Entry} per tick of the tooltip axis, written as the
# inert templates `chadcn--chart` swaps and, for `default_index:`, drawn visible.
#
# Sources: the payload is `combineTooltipPayload` (state/selectors/combiners/combineTooltipPayload.js), the entries of each series are
# `SetBarTooltipEntrySettings` and its siblings (cartesian/Bar.js:62-91, Line.js:90-110, Area.js:85-118), the filter is
# component/Tooltip.js:142, the anchor `combineCoordinateForDefaultIndex`, the cursor component/Cursor.js:42-114.
#
# @api private
class Chadcn::Chart::Cartesian::TooltipPlan
  # One category: its `index`, `label` (the tick value), `coordinate` (`x:`, `y:`), the `payload` (one Hash per series, in declaration
  # order), the `cursor` ({Cursor} or nil) and the active `dots` ({ActiveDot}, one per line and area).
  Entry = Data.define(:index, :label, :coordinate, :payload, :cursor, :dots)

  # The cursor of a category: the `layer` recharts draws it in and the SVG `attrs` of its path.
  Cursor = Data.define(:layer, :attrs)

  # The dot of a line or area at a category: its `series` and the SVG `attrs` of the circle.
  ActiveDot = Data.define(:series, :attrs)

  Number = Chadcn::Chart::Shape::Number

  private_constant :Number

  # @api private
  # @return [Chadcn::Chart::Tooltip]
  attr_reader :tooltip

  # @api private
  # @param layout [Chadcn::Chart::Cartesian::Layout]
  # @param declared [Chadcn::Chart::Cartesian::Declared]
  # @param rows [Array<Hash>] the chart's data
  def initialize(layout:, declared:, rows:)
    @layout = layout
    @declared = declared
    @rows = rows
    @tooltip = declared.tooltip
    @axis = layout.tooltip_axis(@tooltip.options[:axis_id])
  end

  # @api private
  # @return [Array<Entry>] one per category, in tick order
  def entries = @entries ||= (@axis&.category? ? @axis.ticks.map { |tick| entry(tick) } : [])

  # The category shown without interaction (`default_index:`), unless the tooltip never shows (`active: false`).
  #
  # @api private
  # @return [Entry, nil]
  def default_entry
    return if @tooltip.options[:active] == false

    index = Integer(@tooltip.options[:default_index].to_s, exception: false)
    entries.find { |entry| entry.index == index } if index
  end

  # The declared content with the payload and label of one category; the `Tooltip`'s own `formatter:` and `label_formatter:` override the
  # content's (recharts clones the content with the props of the `Tooltip`, component/Tooltip.js:170).
  #
  # @api private
  # @param entry [Entry]
  # @return [Chadcn::Chart::Tooltip::Content, nil] nil when the tooltip declares no content
  def content(entry)
    return unless @tooltip.content_element

    options = @tooltip.options
    changes = { payload: entry.payload, label: entry.label }
    changes[:formatter] = options[:formatter] if options[:formatter]
    changes[:label_formatter] = options[:label_formatter] if options[:label_formatter]
    @tooltip.content_element.with(**changes)
  end

  private

  def entry(tick)
    row = @rows[tick.index]
    coordinate = anchor(tick)
    Entry.new(index: tick.index, label: tick.value, coordinate: coordinate, payload: payload(row), cursor: cursor(coordinate), dots: dots(row))
  end

  # `combineCoordinateForDefaultIndex`.
  def anchor(tick)
    offset = @layout.plot
    if @layout.direction == :horizontal
      { x: tick.coordinate, y: ((offset[:y] + @layout.height) / 2.0) }
    else
      { x: ((offset[:x] + @layout.width) / 2.0), y: tick.coordinate }
    end
  end

  # --- payload ------------------------------------------------------------------------------------------------------------

  # The entries of the series at this row, `filter_null` and hidden series applied (component/Tooltip.js:142).
  def payload(row)
    options = @tooltip.options
    items = @declared.series.map { |series| item(series, row) }
    return items unless options[:filter_null]

    items = items.select { |entry| !entry[:value].nil? && (!entry[:hide] || options[:include_hidden]) }
    options[:payload_uniq_by] ? items.uniq { |entry| entry[:data_key] } : items
  end

  def item(series, row)
    options = series.options
    key = options[:data_key]
    value = Chadcn::Chart::Cartesian::Value.read(row, key)
    { name: (options[:name] || (key if key.is_a?(String) || key.is_a?(Symbol)))&.to_s, data_key: key.to_s, value: value,
      color: series.legend_color, type: options[:tooltip_type], unit: options[:unit], hide: options[:hide], payload: row }
  end

  # --- cursor -------------------------------------------------------------------------------------------------------------

  # The cursor of an axis tooltip (component/Cursor.js:42-114): a rectangle behind the bars of a bar chart, a line through the
  # category on a line or area chart. `cursor: <Hash>` adds attributes to it.
  def cursor(coordinate)
    option = @tooltip.options[:cursor]
    return if option.nil? || option == false

    custom = option.is_a?(Hash) ? option : {}
    shape = @layout.chart_type == :bar ? rectangle_cursor(coordinate) : line_cursor(coordinate)
    classes = [ shape.attrs[:class], custom[:class] ].compact.join(" ")
    Cursor.new(layer: shape.layer, attrs: shape.attrs.merge(dashed(custom.except(:class))).merge(class: classes))
  end

  # `getCursorRectangle` (util/cursor/getCursorRectangle.js).
  def rectangle_cursor(coordinate)
    plot = @layout.plot
    half = @axis.band_size / 2
    box = if @layout.direction == :horizontal
      { x: coordinate[:x] - half, y: plot[:y] + 0.5, width: @axis.band_size, height: plot[:height] - 1 }
    else
      { x: plot[:x] + 0.5, y: coordinate[:y] - half, width: plot[:width] - 1, height: @axis.band_size }
    end
    attrs = { stroke: "none", "pointer-events": "none", width: round(box[:width]), height: round(box[:height]), fill: "#ccc", x: round(box[:x]),
              y: round(box[:y]), class: "recharts-rectangle recharts-tooltip-cursor", radius: "0",
              d: Chadcn::Chart::Cartesian::Rectangle.path(box[:x], box[:y], box[:width], box[:height], 0) }
    Cursor.new(layer: 200, attrs: attrs)
  end

  # `getCursorPoints` (util/cursor/getCursorPoints.js) drawn by a `Curve`.
  def line_cursor(coordinate)
    plot = @layout.plot
    points = if @layout.direction == :horizontal
      [ [ coordinate[:x], plot[:y] ], [ coordinate[:x], plot[:y] + plot[:height] ] ]
    else
      [ [ plot[:x], coordinate[:y] ], [ plot[:x] + plot[:width], coordinate[:y] ] ]
    end
    attrs = { stroke: "#ccc", "pointer-events": "none", width: round(plot[:width]), height: round(plot[:height]), class: "recharts-curve recharts-tooltip-cursor",
              d: Chadcn::Chart::Shape::Curve.line(points, type: :linear, layout: @layout.direction) }
    Cursor.new(layer: 1100, attrs: attrs)
  end

  # --- active dots --------------------------------------------------------------------------------------------------------

  # The dot of every line and area at this row (component/ActivePoints.js:19-56): `r` 4, white 2px stroke, the series color inside.
  def dots(row)
    @layout.placed.filter_map do |placed|
      next if placed.series.kind == :bar

      active = placed.series.options[:active_dot]
      point = placed.points.find { |candidate| candidate.row.equal?(row) }
      next if active == false || point.nil? || point.x.nil? || point.y.nil?

      custom = active.is_a?(Hash) ? dashed(active) : {}
      series = placed.series
      ActiveDot.new(series: series,
                    attrs: { cx: round(point.x), cy: round(point.y), r: "4", fill: series.legend_color || "none", stroke: "#fff",
                             "stroke-width": "2" }.merge(custom))
    end
  end

  # A coordinate the way recharts' shapes print it: four decimals.
  def round(value) = Number.format(Chadcn::Chart::Cartesian::Rectangle.round(value))

  # Hash keys written the SVG way (`stroke_dasharray` is `stroke-dasharray`).
  def dashed(attributes) = attributes.to_h { |key, value| [ key.to_s.tr("_", "-").to_sym, value.is_a?(Numeric) ? Number.format(value) : value ] }
end
