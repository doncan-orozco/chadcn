# frozen_string_literal: true

# The tooltip and legend wrappers of a polar chart: the same `div`s as a cartesian chart's ({Chadcn::Chart::Cartesian::Overlays}); what
# differs is the legend payload, which is not one entry per series: a pie lists its sectors, a radial bar the rows of the chart.
#
# @api private
class Chadcn::Chart::Polar::Overlays < Chadcn::Chart::Cartesian::Overlays
  private

  # `selectPieLegend` (state/selectors/pieSelectors.js:46-70), `computeLegendPayloadFromRadarSectors` (polar/Radar.js:32-42) and
  # `selectRadialBarLegendPayload` (state/selectors/radialBarSelectors.js:170-182).
  def legend_items
    @declared.series.flat_map do |series|
      case series.kind
      when :pie then pie_items(series)
      when :radar then [ radar_item(series) ]
      else radial_bar_items(series)
      end
    end
  end

  def pie_items(series)
    options = series.options
    rows(series).each_with_index.map do |row, index|
      name = Chadcn::Chart::Cartesian::Value.read(row, options[:name_key])
      name = options[:name] if name.nil?
      { value: tooltip_name(name, options[:data_key]), data_key: nil, color: pie_color(series, row, index), type: options[:legend_type], inactive: false,
        payload: row }
    end
  end

  # The color of a pie's legend entry: the cell's fill, else the row's, else the pie's (pieSelectors.js:55-63).
  def pie_color(series, row, index)
    cell = series.cells[index]&.shape_attributes&.dig(:fill)
    return cell if cell

    row_fill = Chadcn::Chart::Cartesian::Value.read(row, :fill) if row.is_a?(Hash)
    row_fill || series.options[:fill]
  end

  def rows(series)
    own = series.options[:data]
    own.nil? || own.empty? ? @layout.rows : own
  end

  def radar_item(series)
    options = series.options
    { value: tooltip_name(options[:name], options[:data_key]), data_key: options[:data_key].to_s, color: series.legend_color, type: options[:legend_type],
      inactive: options[:hide] }
  end

  def radial_bar_items(series)
    @layout.rows.map do |row|
      { value: Chadcn::Chart::Cartesian::Value.read(row, :name)&.to_s, data_key: nil, color: Chadcn::Chart::Cartesian::Value.read(row, :fill),
        type: series.options[:legend_type], inactive: false, payload: row }
    end
  end

  # `getTooltipNameProp`: the name when it is not blank, else a string data key.
  def tooltip_name(name, data_key)
    return name.to_s if name && name != ""

    data_key.to_s if data_key.is_a?(String) || data_key.is_a?(Symbol)
  end
end
