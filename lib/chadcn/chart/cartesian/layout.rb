# frozen_string_literal: true

# The one layout pass of a cartesian chart: from the declarations the chart collected (axes, series, grids, reference lines, legend) to
# every number the renderer writes. It follows recharts' selectors in order (state/selectors/selectChartOffsetInternal.js,
# axisSelectors.js, barSelectors.js, lineSelectors.js, areaSelectors.js): margins and axis sizes give the plot rectangle, each axis gets
# its domain, scale and ticks from the data and the series on it, then each series is placed on its axes.
#
# @api private
class Chadcn::Chart::Cartesian::Layout
  Value = Chadcn::Chart::Cartesian::Value
  BarPositions = Chadcn::Chart::Cartesian::BarPositions
  AxisSettings = Chadcn::Chart::Cartesian::AxisSettings

  # What was placed for one series: its rectangles (a bar) or its points (a line, an area).
  Placed = Data.define(:series, :index, :rects, :points, :area)
  # The axes whose line is on the near side of their box (top and left) take their room before the first axis is placed.
  LEADING_ORIENTATIONS = %i[top left].freeze

  private_constant :Value, :BarPositions, :AxisSettings, :LEADING_ORIENTATIONS

  # @api private
  # @return [Integer, Float] the chart size in px
  attr_reader :width, :height
  # @api private
  # @return [Symbol] :horizontal or :vertical
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
  # @return [Array<Placed>] the series that are drawn, in declaration order
  attr_reader :placed
  # @api private
  # @return [Chadcn::Chart::Cartesian::Text]
  attr_reader :text

  # @api private
  # @param declared [Chadcn::Chart::Cartesian::Declared] what the chart block declared
  # @param chart [Hash] the chart's settings: `:type` (:bar, :line, :area), `:direction`, `:width`, `:height`, `:margin`, `:rows`,
  #   `:text`, `:bar_category_gap`, `:bar_gap`, `:bar_size`, `:max_bar_size`, `:stack_offset`, `:reverse_stack_order`, `:base_value`
  def initialize(declared, chart)
    @declared = declared
    @chart = chart
    @direction = chart.fetch(:direction)
    @width = chart.fetch(:width)
    @height = chart.fetch(:height)
    @rows = chart.fetch(:rows)
    @text = chart.fetch(:text)
    @margin = %i[top right bottom left].to_h { |side| [ side, Value.number(chart[:margin]&.[](side)) || 0.0 ] }
    @offset = legend_offset(axes_offset)
    @plot = plot_rectangle
    @axes = {}
    @stacks = {}
    build_axes
    @placed = place_series
  end

  # @api private
  # @return [Hash{Symbol => Float}] the chart box, the view box of the surface and of the tick collision
  def view_box = { x: 0.0, y: 0.0, width: @width.to_f, height: @height.to_f }

  # The axis of a kind and an id (an axis nobody declared is implicit, and hidden).
  #
  # @api private
  # @param kind [Symbol] :x or :y
  # @param id [Object] the axis id, 0 by default
  # @return [Chadcn::Chart::Cartesian::Axis]
  def axis(kind, id = 0) = @axes.fetch([ kind, id ])

  # The axes the declarations asked for, in declaration order, with the position and size they are drawn at.
  #
  # @api private
  # @return [Array<Hash>] `{ axis:, x:, y:, width:, height: }` for every declared axis that is not hidden
  def drawn_axes
    @declared.axes.reject(&:hide).map do |settings|
      axis = axis(settings.kind, settings.id)
      steps = offset_steps(settings.kind, settings.orientation, settings.mirror)
      position = settings.x? ? { x: @offset[:left], y: steps[settings.id] } : { x: steps[settings.id], y: @offset[:top] }
      size = settings.x? ? { width: @plot[:width], height: settings.size } : { width: settings.size, height: @plot[:height] }
      { axis: axis, **position, **size }
    end
  end

  # The ticks of an axis that are drawn, after the collision pass.
  #
  # @api private
  # @param axis [Chadcn::Chart::Cartesian::Axis]
  # @return [Array<Chadcn::Chart::Cartesian::TickLayout::Tick>]
  def visible_ticks(axis)
    settings = axis.settings
    return [] unless settings.tick

    Chadcn::Chart::Cartesian::TickLayout.visible(axis.ticks, tick_settings(settings), @text)
  end

  # The pixel positions of the grid lines of a `CartesianGrid` (`getCoordinatesOfGrid`).
  #
  # @api private
  # @param grid [#options] the grid declaration
  # @return [Hash{Symbol => Array<Float>}] `:horizontal` and `:vertical` coordinates
  def grid_points(grid)
    options = grid.options
    sync = options[:sync_with_ticks]
    horizontal = options[:horizontal_points]
    vertical = options[:vertical_points]
    horizontal = grid_coordinates(axis(:y, options[:y_axis_id]), @plot[:y], @plot[:y] + @plot[:height], sync) if horizontal.empty?
    vertical = grid_coordinates(axis(:x, options[:x_axis_id]), @plot[:x], @plot[:x] + @plot[:width], sync) if vertical.empty?
    { horizontal: horizontal, vertical: vertical }
  end

  private

  # --- offsets ------------------------------------------------------------------------------------------------------------

  def axes_offset
    sum = lambda do |axes|
      axes.select { |settings| !settings.mirror && !settings.hide }.sum { |settings| settings.size.to_f }
    end
    by_side = ->(side) { @declared.axes.select { |settings| settings.orientation == side } }
    { top: @margin[:top] + sum.call(by_side.call(:top)), bottom: @margin[:bottom] + sum.call(by_side.call(:bottom)),
      left: @margin[:left] + sum.call(by_side.call(:left)), right: @margin[:right] + sum.call(by_side.call(:right)) }
  end

  # `appendOffsetOfLegend`: the legend takes room from the side it sits on.
  def legend_offset(offset)
    legend = @declared.legend&.options
    return offset unless legend

    align = legend[:align]
    vertical_align = legend[:vertical_align]
    legend_layout = legend[:layout]
    box_width = legend[:width].is_a?(Numeric) ? legend[:width] : 0
    box_height = legend[:height].is_a?(Numeric) ? legend[:height] : legend[:legend_height]
    if (legend_layout == :vertical || (legend_layout == :horizontal && vertical_align == :middle)) && align != :center
      offset.merge(align => offset[align] + box_width)
    elsif (legend_layout == :horizontal || (legend_layout == :vertical && align == :center)) && vertical_align != :middle
      offset.merge(vertical_align => offset[vertical_align] + box_height)
    else
      offset
    end
  end

  # `selectAllXAxesOffsetSteps` / `selectAllYAxesOffsetSteps`: where each axis of an orientation starts.
  def offset_steps(kind, orientation, mirror)
    axes = @declared.axes.select { |settings| settings.kind == kind && settings.orientation == orientation && settings.mirror == mirror }
    position = steps_start(orientation)
    leading = LEADING_ORIENTATIONS.include?(orientation)
    axes.each_with_object({}) do |settings, steps|
      needs_space = leading != mirror
      steps[settings.id] = position - (needs_space ? settings.size : 0)
      position += (needs_space ? -1 : 1) * settings.size
    end
  end

  # Where the first axis of an orientation starts: the edge of the plot it sits on.
  def steps_start(orientation)
    return @offset[orientation] if %i[top left].include?(orientation)

    orientation == :bottom ? @height - @offset[:bottom] : @width - @offset[:right]
  end

  def plot_rectangle
    { x: @offset[:left], y: @offset[:top], width: [ @width - @offset[:left] - @offset[:right], 0 ].max,
      height: [ @height - @offset[:top] - @offset[:bottom], 0 ].max }
  end

  # --- axes ---------------------------------------------------------------------------------------------------------------

  def build_axes
    %i[x y].each do |kind|
      ids = (@declared.axes.select { |settings| settings.kind == kind }.map(&:id) + @declared.axis_ids(kind)).uniq
      ids << 0 if ids.empty?
      ids.each { |id| @axes[[ kind, id ]] = build_axis(kind, id) }
    end
  end

  def build_axis(kind, id)
    settings = @declared.axes.find { |candidate| candidate.kind == kind && candidate.id == id } || AxisSettings.implicit(kind, id)
    items = @declared.series.select { |series| series.options[axis_key(kind)] == id && (settings.include_hidden || !series.options[:hide]) }
    stackable = items.select { |series| series.options[:stack_id] && series.kind != :line }
    stacks = Chadcn::Chart::Cartesian::Stacks.new(@rows, stackable, offset: @chart[:stack_offset], reverse: @chart[:reverse_stack_order])
    @stacks[[ kind, id ]] = stacks
    Chadcn::Chart::Cartesian::Axis.new(settings, layout: @direction, chart_type: @chart[:type], rows: @rows, items: items, stacks: stacks,
                                                 references: extending_references(kind, id), range: axis_range(settings), stack_offset: @chart[:stack_offset])
  end

  def axis_key(kind) = kind == :x ? :x_axis_id : :y_axis_id

  # The reference lines that widen the domain of the axis (`if_overflow: :extend_domain`).
  def extending_references(kind, id)
    @declared.references.select { |reference| reference.options[:if_overflow] == :extend_domain && reference.options[axis_key(kind)] == id }
             .map { |reference| { x: reference.options[:x], y: reference.options[:y] } }
  end

  # `selectXAxisRange` / `selectYAxisRange`
  def axis_range(settings)
    padding = settings.padding
    if settings.x?
      [ @offset[:left] + padding[:left], @offset[:left] + @plot[:width] - padding[:right] ]
    elsif @direction == :horizontal
      [ @offset[:top] + @plot[:height] - padding[:bottom], @offset[:top] + padding[:top] ]
    else
      [ @offset[:top] + padding[:top], @offset[:top] + @plot[:height] - padding[:bottom] ]
    end
  end

  def tick_settings(settings)
    Chadcn::Chart::Cartesian::TickLayout::Settings.new(
      orientation: settings.orientation, interval: settings.interval, min_tick_gap: settings.min_tick_gap, formatter: settings.tick_formatter,
      unit: settings.unit, angle: settings.angle, view_box: view_box
    )
  end

  # `getCoordinatesOfGrid`
  def grid_coordinates(axis, minimum, maximum, sync_with_ticks)
    ticks = axis.settings.tick ? Chadcn::Chart::Cartesian::TickLayout.visible(axis.ticks, tick_settings(axis.settings), @text) : []
    coordinates = ticks.map(&:coordinate)
    return coordinates if sync_with_ticks

    coordinates << minimum unless coordinates.include?(minimum)
    coordinates << maximum unless coordinates.include?(maximum)
    coordinates
  end

  # --- series -------------------------------------------------------------------------------------------------------------

  def place_series
    @declared.series.each_with_index.filter_map do |series, index|
      next if series.options[:hide]

      axes = { x: axis(:x, series.options[:x_axis_id]), y: axis(:y, series.options[:y_axis_id]) }
      next unless axes.values.all?(&:scaled?)

      case series.kind
      when :bar then place_bar(series, index, axes)
      when :line then place_line(series, index, axes)
      else place_area(series, index, axes)
      end
    end
  end

  def category_axis(axes) = @direction == :horizontal ? axes[:x] : axes[:y]

  def value_axis_key(series)
    @direction == :horizontal ? [ :y, series.options[:y_axis_id] ] : [ :x, series.options[:x_axis_id] ]
  end

  def place_bar(series, index, axes)
    position = BarPositions.find(bar_positions(series, axes), series)
    return unless position

    pairs = @stacks.fetch(value_axis_key(series)).pairs(series)
    rects = Chadcn::Chart::Cartesian::BarShapes.rectangles(series, layout: @direction, position: position, axes: axes, rows: @rows, pairs: pairs)
    Placed.new(series: series, index: index, rects: rects, points: nil, area: nil)
  end

  # `selectAllBarPositions` for the bars on the category axis of this bar.
  def bar_positions(series, axes)
    category = category_axis(axes)
    key = @direction == :horizontal ? :x_axis_id : :y_axis_id
    bars = @declared.series.select { |other| other.kind == :bar && !other.options[:hide] && other.options[key] == series.options[key] }
    total = @direction == :horizontal ? @plot[:width] : @plot[:height]
    slots = BarPositions.slots(bars, @chart[:bar_size], total)
    max_bar = series.options[:max_bar_size].nil? ? @chart[:max_bar_size] : series.options[:max_bar_size]
    bar_band = category.band_size(bar: true) || max_bar || 0
    BarPositions.positions(slots, @chart[:max_bar_size], @chart[:bar_gap], @chart[:bar_category_gap], bar_band, category.band_size,
                           series.options[:max_bar_size])
  end

  def place_line(series, index, axes)
    return unless axes.values.all? { |axis| axis.item_ticks.any? }

    points = Chadcn::Chart::Cartesian::LinePoints.line(series, layout: @direction, axes: axes, rows: @rows)
    Placed.new(series: series, index: index, rects: nil, points: points, area: nil)
  end

  def place_area(series, index, axes)
    return unless axes.values.all? { |axis| axis.item_ticks.any? }

    pairs = @stacks.fetch(value_axis_key(series)).pairs(series)
    area = Chadcn::Chart::Cartesian::LinePoints.area(series, layout: @direction, axes: axes, rows: @rows, pairs: pairs, base_value: @chart[:base_value])
    Placed.new(series: series, index: index, rects: nil, points: area.points, area: area)
  end
end
