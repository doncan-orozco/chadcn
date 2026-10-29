# frozen_string_literal: true

# The one layout pass of a polar chart: from the declarations the chart collected (series, axes, grid, legend) to every number the
# renderer writes. It follows recharts' selectors in order (state/selectors/selectChartOffsetInternal.js, polarAxisSelectors.js,
# pieSelectors.js, radarSelectors.js, radialBarSelectors.js): the margin and the legend give the plot rectangle, the largest circle in it
# and the polar view box (center, radii, angles), each axis gets its domain, scale and ticks, then each series is placed.
#
# @api private
class Chadcn::Chart::Polar::Layout
  # What was placed for one series: its `shapes` (the sectors of a pie or a radial bar, the points of a radar).
  Placed = Data.define(:series, :index, :shapes)

  # @api private
  # @return [Integer, Float] the chart size in px
  attr_reader :width, :height
  # @api private
  # @return [Symbol] :centric (pie and radar charts) or :radial (radial bar charts)
  attr_reader :direction
  # @api private
  # @return [Hash{Symbol => Float}] `top`, `right`, `bottom`, `left`: the space around the plot
  attr_reader :offset
  # @api private
  # @return [Hash{Symbol => Float}] `x`, `y`, `width`, `height` of the plot rectangle
  attr_reader :plot
  # @api private
  # @return [Hash{Symbol => Float}] the margin, with a missing side as 0
  attr_reader :margin
  # @api private
  # @return [Chadcn::Chart::Polar::ViewBox] the chart-level center, radii and angles
  attr_reader :view_box
  # @api private
  # @return [Array<Placed>] the series that are drawn, in declaration order
  attr_reader :placed
  # @api private
  # @return [Chadcn::Chart::Cartesian::Text]
  attr_reader :text
  # @api private
  # @return [Symbol] :pie, :radar or :radial_bar
  attr_reader :chart_type

  # @api private
  # @param declared [Chadcn::Chart::Polar::Declared] what the chart block declared
  # @param chart [Chadcn::Chart::Polar::ChartSettings] the chart's settings
  def initialize(declared, chart)
    @declared = declared
    @chart = chart
    @chart_type = chart.type
    @direction = chart.layout
    @width = chart.width
    @height = chart.height
    @text = chart.text
    @margin = %i[top right bottom left].to_h { |side| [ side, Chadcn::Chart::Cartesian::Value.number(Chadcn::Chart::Cartesian::Value.read(chart.margin, side)) || 0.0 ] }
    @offset = Chadcn::Chart::Polar::LegendOffset.call(@margin, declared.legend&.options, legend_box_height)
    @plot = plot_rectangle
    @view_box = polar_view_box
    @axes = {}
    build_axes unless chart.type == :pie
    @placed = place_series
  end

  # The angle axis of an id (an axis nobody declared is implicit, and not drawn).
  #
  # @api private
  # @param id [Object] the axis id, 0 by default
  # @return [Chadcn::Chart::Polar::Axis]
  def angle_axis(id = 0) = @axes.fetch([ :angle, id ])

  # @api private
  # @param id [Object] the axis id, 0 by default
  # @return [Chadcn::Chart::Polar::Axis]
  def radius_axis(id = 0) = @axes.fetch([ :radius, id ])

  # The axis a tooltip follows (`selectTooltipAxis`, state/selectors/selectTooltipAxis.js): the category axis of the layout.
  #
  # @api private
  # @param id [Object] the `axis_id:` of the tooltip
  # @return [Chadcn::Chart::Polar::Axis, nil] nil when the chart has no such axis (a pie chart follows no axis)
  def tooltip_axis(id = 0) = @axes[[ @direction == :centric ? :angle : :radius, id ]]

  # @api private
  # @return [Boolean] whether the chart has axes to read (a pie chart has none)
  def axes? = !@axes.empty?

  # The rows a chart without data on its series draws (the chart's `data:`).
  #
  # @api private
  # @return [Array<Hash>]
  def rows = @chart.rows

  # The height the legend takes: its `height:` when that is a number, else the assumed height of its content (`legend_height:`).
  #
  # @api private
  # @return [Numeric, nil] nil without a legend
  def legend_box_height
    legend = @declared.legend&.options
    return unless legend

    legend[:height].is_a?(Numeric) ? legend[:height] : legend[:legend_height]
  end

  private

  def plot_rectangle
    { x: @offset[:left], y: @offset[:top], width: [ @width - @offset[:left] - @offset[:right], 0 ].max,
      height: [ @height - @offset[:top] - @offset[:bottom], 0 ].max }
  end

  # `selectPolarViewBox` (polarAxisSelectors.js:80): the chart-level center is a share of the whole chart, the radii a share of the largest
  # circle inside the offset.
  def polar_view_box
    value = Chadcn::Chart::Cartesian::Value
    max = [ (@width - @offset[:left] - @offset[:right]).abs, (@height - @offset[:top] - @offset[:bottom]).abs ].min / 2.0
    Chadcn::Chart::Polar::ViewBox.new(
      cx: value.percent(@chart.cx, @width, @width / 2.0), cy: value.percent(@chart.cy, @height, @height / 2.0),
      inner_radius: value.percent(@chart.inner_radius, max, 0.0), outer_radius: value.percent(@chart.outer_radius, max, max * 0.8),
      start_angle: @chart.start_angle, end_angle: @chart.end_angle
    )
  end

  # --- axes ---------------------------------------------------------------------------------------------------------------

  def build_axes
    %i[angle radius].each do |kind|
      declared = kind == :angle ? @declared.angle_axes : @declared.radius_axes
      ids = (declared.map(&:id) + @declared.series.map { |series| series.options[axis_key(kind)] }).uniq
      ids << 0 if ids.empty?
      ids.each { |id| @axes[[ kind, id ]] = build_axis(kind, declared.find { |settings| settings.id == id } || Chadcn::Chart::Polar::AxisSettings.implicit(kind, id)) }
    end
  end

  def axis_key(kind) = kind == :angle ? :angle_axis_id : :radius_axis_id

  def build_axis(kind, settings)
    items = @declared.series.select { |series| series.options[axis_key(kind)] == settings.id && !series.options[:hide] }
    Chadcn::Chart::Polar::Axis.new(settings, layout: @direction, rows: @chart.rows, items: items, range: axis_range(kind))
  end

  # `selectAngleAxisRange` / `selectRadiusAxisRange`: the angles of the chart, or its inner and outer radius.
  def axis_range(kind)
    kind == :angle ? [ @view_box.start_angle.to_f, @view_box.end_angle.to_f ] : [ @view_box.inner_radius, @view_box.outer_radius ]
  end

  # --- series -------------------------------------------------------------------------------------------------------------

  def place_series
    @declared.series.each_with_index.filter_map do |series, index|
      next if series.options[:hide] && series.kind != :pie

      shapes = shapes_of(series)
      Placed.new(series: series, index: index, shapes: shapes) if shapes
    end
  end

  def shapes_of(series)
    case series.kind
    when :pie then pie_sectors(series)
    end
  end

  # A pie shows its own `data:`, else the chart's (pieSelectors.js:14-30).
  def pie_sectors(series)
    own = series.options[:data]
    Chadcn::Chart::Polar::PieSectors.call(series, rows: own.nil? || own.empty? ? @chart.rows : own, plot: @plot)
  end
end
