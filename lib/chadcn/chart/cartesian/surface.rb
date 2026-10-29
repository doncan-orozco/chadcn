# frozen_string_literal: true

# The `svg.recharts-surface` of a cartesian chart, drawn from a {Chadcn::Chart::Cartesian::Layout}: recharts' markup after the browser
# has settled it (dev/port/specs/chart.md, "Structure"). The svg holds one `g` per z-index layer, every layer present whether or not it
# has content, in recharts' order; what a declaration draws goes to the layer recharts draws it in, in order of declaration.
#
# @api private
class Chadcn::Chart::Cartesian::Surface < Phlex::SVG
  # recharts' `DefaultZIndexes` (zIndex/DefaultZIndexes.js), in drawing order.
  Z_LAYERS = [ -100, -50, 100, 200, 300, 400, 500, 600, 1000, 1100, 1200, 2000 ].freeze
  Number = Chadcn::Chart::Shape::Number
  # The data row keys recharts lets through to a bar (`svgPropertiesAndEvents` of the entry).
  ROW_ATTRIBUTES = %i[fill stroke name opacity].freeze

  private_constant :Z_LAYERS, :Number, :ROW_ATTRIBUTES

  # @api private
  # @param layout [Chadcn::Chart::Cartesian::Layout]
  # @param declared [Chadcn::Chart::Cartesian::Declared]
  # @param markup [String] what the chart's block wrote itself; placed after the clip path
  # @param tooltip_entry [Chadcn::Chart::Cartesian::TooltipPlan::Entry, nil] the category a `default_index:` shows: its cursor and active dots
  # @param uid [String] prefix of the ids this chart writes
  # @param title [String, nil]
  # @param desc [String, nil]
  # @param accessibility_layer [Boolean]
  # @param role [String, nil]
  # @param tab_index [Integer, nil]
  # @param attrs [Hash] attributes of the svg
  def initialize(layout:, declared:, markup:, tooltip_entry:, uid:, title:, desc:, accessibility_layer:, role:, tab_index:, attrs:)
    @layout = layout
    @declared = declared
    @markup = markup
    @tooltip_entry = tooltip_entry
    @uid = uid
    @title = title
    @desc = desc
    @accessibility_layer = accessibility_layer
    @role = role
    @tab_index = tab_index
    @attrs = attrs
    @placed = layout.placed.to_h { |placed| [ placed.series, placed ] }
    super()
  end

  # @return [void]
  def view_template
    svg(**svg_attributes) do
      title { plain(@title.to_s) }
      desc { plain(@desc.to_s) }
      Z_LAYERS.each do |z|
        g(tabindex: "-1", class: "recharts-zIndex-layer_#{z}") { @declared.items.each { |item| draw(item, z) } }
        clip_path_and_markup if z == -50
      end
    end
  end

  private

  def format_number(value) = Number.format(value)

  def format_rounded(value) = format_number(Chadcn::Chart::Cartesian::Rectangle.round(value))

  def svg_attributes
    own = { class: "recharts-surface", width: format_number(@layout.width), height: format_number(@layout.height), viewBox: "0 0 #{format_number(@layout.width)} #{format_number(@layout.height)}",
            style: "width: 100%; height: 100%; display: block;" }
    own = { role: @role || "application", tabindex: (@tab_index || 0).to_s }.merge(own) if @accessibility_layer
    own.merge(@attrs).merge(data: { chadcn__chart_target: "surface" }.merge(@attrs[:data] || {}))
  end

  def clip_path_and_markup
    plot = @layout.plot
    defs do
      clipPath(id: "#{@uid}-clip") do
        rect(x: format_number(plot[:x]), y: format_number(plot[:y]), height: format_number(plot[:height]), width: format_number(plot[:width]))
      end
    end
    raw(safe(@markup)) unless @markup.empty?
  end

  # Presentation attributes of a shape: nil and false values dropped, the `class` values joined, later hashes winning.
  def attrs(*hashes)
    hashes.compact.each_with_object({}) do |hash, result|
      hash.each do |key, value|
        next if value.nil? || value == false

        key = key.to_sym
        key = :class if key == :class_name
        result[key] = key == :class && result[:class] ? "#{result[:class]} #{value}" : value
      end
    end
  end

  def draw(item, layer)
    case item
    when Chadcn::Chart::CartesianGrid then grid(item) if layer == -100
    when Chadcn::Chart::Cartesian::Series then draw_series(item, layer)
    when Chadcn::Chart::XAxis, Chadcn::Chart::YAxis then draw_axis(item, layer)
    when Chadcn::Chart::ReferenceLine then reference_line(item) if layer == 400
    when Chadcn::Chart::Label then standalone_label(item) if layer == 2000
    when Chadcn::Chart::Tooltip then tooltip_cursor(layer)
    end
  end

  def draw_series(series, layer)
    placed = @placed[series] or return
    case series.kind
    when :bar then bar_series(placed, layer)
    when :line then line_series(placed, layer)
    else area_series(placed, layer)
    end
    label_lists(placed) if layer == 2000
  end

  # --- grid ---------------------------------------------------------------------------------------------------------------

  def grid(grid)
    plot = @layout.plot
    return unless plot[:width].positive? && plot[:height].positive?

    options = grid.options
    points = @layout.grid_points(grid)
    g(class: "recharts-cartesian-grid") do
      grid_background(options, plot)
      stripes(options[:horizontal_fill], points[:horizontal], :horizontal) if options[:horizontal] && options[:horizontal_fill].any?
      stripes(options[:vertical_fill], points[:vertical], :vertical) if options[:vertical] && options[:vertical_fill].any?
      grid_lines(grid, points[:horizontal], :horizontal) if options[:horizontal] && points[:horizontal].any?
      grid_lines(grid, points[:vertical], :vertical) if options[:vertical] && points[:vertical].any?
    end
  end

  def grid_background(options, plot)
    return if [ nil, "none" ].include?(options[:fill])

    rect(x: format_number(plot[:x]), y: format_number(plot[:y]), width: format_number(plot[:width]), height: format_number(plot[:height]),
         stroke: "none", fill: options[:fill], class: "recharts-cartesian-grid-bg")
  end

  def grid_lines(grid, coordinates, direction)
    options = grid.options
    plot = @layout.plot
    look = { stroke: options[:stroke], stroke_dasharray: options[:stroke_dasharray] }
    box = { x: format_number(plot[:x]), y: format_number(plot[:y]), width: format_number(plot[:width]), height: format_number(plot[:height]) }
    base = attrs(look, box, options[:attrs])
    g(class: "recharts-cartesian-grid-#{direction}") do
      coordinates.each do |coordinate|
        ends = if direction == :horizontal
          { x1: format_number(plot[:x]), y1: format_number(coordinate), x2: format_number(plot[:x] + plot[:width]), y2: format_number(coordinate) }
        else
          { x1: format_number(coordinate), y1: format_number(plot[:y]), x2: format_number(coordinate), y2: format_number(plot[:y] + plot[:height]) }
        end
        line(**base, fill: "none", **ends)
      end
    end
  end

  # `HorizontalStripes` / `VerticalStripes`: bands between the grid lines, painted with the fills in turn.
  def stripes(fills, coordinates, direction)
    plot = @layout.plot
    origin = direction == :horizontal ? plot[:y] : plot[:x]
    extent = direction == :horizontal ? plot[:height] : plot[:width]
    rounded = coordinates.map { |coordinate| Chadcn::Chart::Shape::JsMath.round(coordinate + origin - origin) }.sort
    rounded.unshift(0.0) if origin != rounded.first
    g(class: "recharts-cartesian-gridstripes-#{direction}") do
      rounded.each_with_index do |start, index|
        following = rounded[index + 1]
        length = following.nil? ? origin + extent - start : following - start
        next if length <= 0

        fill = fills[index % fills.size]
        if direction == :horizontal
          rect(y: format_number(start), x: format_number(plot[:x]), height: format_number(length), width: format_number(plot[:width]), stroke: "none",
               fill: fill, class: "recharts-cartesian-grid-bg")
        else
          rect(x: format_number(start), y: format_number(plot[:y]), width: format_number(length), height: format_number(plot[:height]), stroke: "none",
               fill: fill, class: "recharts-cartesian-grid-bg")
        end
      end
    end
  end

  # --- series -------------------------------------------------------------------------------------------------------------

  # The caller's attributes of a series, without the ones that belong to its group.
  def series_attrs(series) = series.options[:attrs].except(:class, :class_name, :id)

  def group_class(series, name) = attrs({ class: "recharts-layer recharts-#{name}" }, { class: series.options[:attrs][:class] })[:class]

  def series_id(series, name, index) = series.options[:attrs][:id] || "recharts-#{name}-#{@uid}-#{index}"

  def plot_size
    plot = @layout.plot
    { height: format_number(plot[:height]), width: format_number(plot[:width]) }
  end

  # The clip rectangle of a series whose axis allows data overflow (`GraphicalItemClipPath`), nil when nothing is clipped.
  def clip(series)
    x = @layout.axis(:x, series.options[:x_axis_id]).settings.allow_data_overflow
    y = @layout.axis(:y, series.options[:y_axis_id]).settings.allow_data_overflow
    return unless x || y

    plot = @layout.plot
    { x: x ? plot[:x] : plot[:x] - (plot[:width] / 2), y: y ? plot[:y] : plot[:y] - (plot[:height] / 2),
      width: x ? plot[:width] : plot[:width] * 2, height: y ? plot[:height] : plot[:height] * 2 }
  end

  def clip_defs(id, clip, dots: nil)
    defs do
      clipPath(id: "clipPath-#{id}") { rect(**clip.transform_values { |value| format_number(value) }) }
      clipPath(id: "clipPath-dots-#{id}") { rect(**dots.transform_values { |value| format_number(value) }) } if dots
    end
  end

  # The rectangle dots are clipped to when the dot asks for it with `clip_dot: false` (otherwise they are clipped with the line).
  def dots_clip(series)
    dot = series.options[:dot]
    return unless dot.is_a?(Hash) && dot[:clip_dot] == false

    size = ((dot[:r] || 3) * 2) + (dot[:stroke_width] || 2)
    plot = @layout.plot
    { x: plot[:x] - (size / 2), y: plot[:y] - (size / 2), width: plot[:width] + size, height: plot[:height] + size }
  end

  def clip_attribute(id, clip) = clip ? { "clip-path": "url(#clipPath-#{id})" } : nil

  # The dots are clipped with the line, unless the dot asks to be clipped to its own rectangle (`clip_dot: false`).
  def dots_clip_attribute(series, id)
    return unless clip(series)

    { "clip-path": "url(#clipPath-#{'dots-' if dots_clip(series)}#{id})" }
  end

  # --- bars ---------------------------------------------------------------------------------------------------------------

  def bar_series(placed, layer)
    case layer
    when -50 then bar_background(placed)
    when 300 then bar_rectangles(placed)
    end
  end

  def bar_background(placed)
    background = placed.series.options[:background]
    return unless background

    custom = background.is_a?(Hash) ? background : {}
    plot = @layout.plot
    placed.rects.each do |rect|
      box = if @layout.direction == :horizontal
        { x: rect.x, y: plot[:y], width: rect.width, height: plot[:height] }
      else
        { x: plot[:x], y: rect.y, width: plot[:width], height: rect.height }
      end
      g(class: "recharts-layer recharts-inactive-bar") do
        rectangle_path(box, nil, attrs({ fill: "#eee" }, custom, { class: "recharts-rectangle recharts-bar-background-rectangle" }))
      end
    end
  end

  def bar_rectangles(placed)
    series = placed.series
    id = series_id(series, "bar", placed.index)
    clip = clip(series)
    g(class: group_class(series, "bar"), id: id) do
      clip_defs(id, clip) if clip
      g(**attrs({ class: "recharts-layer recharts-bar-rectangles" }, clip_attribute(id, clip))) do
        g(class: "recharts-layer") do
          placed.rects.each do |rect|
            g(class: "recharts-layer recharts-bar-rectangle") do
              g(class: "recharts-layer recharts-inactive-bar") { bar_rectangle(series, rect, series.cells[rect.index]) }
            end
          end
        end
      end
    end
  end

  def bar_rectangle(series, rect, cell)
    options = series.options
    row = rect.row.is_a?(Hash) ? ROW_ATTRIBUTES.to_h { |key| [ key, Chadcn::Chart::Cartesian::Value.read(rect.row, key) ] } : {}
    row[:name] = row[:name].to_s unless row[:name].nil?
    base = attrs({ fill: options[:fill], stroke: options[:stroke], name: (options[:name] || "undefined").to_s }, series_attrs(series),
                 { class: "recharts-rectangle" }, row, cell&.shape_attributes)
    rectangle_path({ x: rect.x, y: rect.y, width: rect.width, height: rect.height }, options[:radius], base)
  end

  # A bar's `path`: the box rounded to four decimals, the radius when it is a number, and the `d`.
  def rectangle_path(box, radius, base)
    shown_radius = radius.nil? ? "0" : (format_number(radius) if radius.is_a?(Numeric))
    outline = Chadcn::Chart::Cartesian::Rectangle.path(box[:x], box[:y], box[:width], box[:height], radius.nil? ? 0 : radius)
    path(**base, x: format_rounded(box[:x]), y: format_rounded(box[:y]), width: format_rounded(box[:width]), height: format_rounded(box[:height]),
                 radius: shown_radius, d: outline)
  end

  # --- lines --------------------------------------------------------------------------------------------------------------

  def line_series(placed, layer)
    case layer
    when 400 then line_curve(placed)
    when 600 then dots(placed, "line")
    when 1200 then active_dot(placed)
    end
  end

  def line_curve(placed)
    series = placed.series
    options = series.options
    id = series_id(series, "line", placed.index)
    clip = clip(series)
    g(class: group_class(series, "line")) do
      clip_defs(id, clip, dots: dots_clip(series)) if clip
      next unless placed.points.size > 1

      g(class: "recharts-layer recharts-shape") do
        look = { stroke: options[:stroke], stroke_width: format_number(options[:stroke_width]), stroke_dasharray: options[:stroke_dasharray],
                 name: options[:name], id: id }
        shape = attrs(look, plot_size, series_attrs(series), clip_attribute(id, clip))
        path(**shape, fill: "none", class: "recharts-curve recharts-line-curve", d: curve_path(placed, options))
      end
    end
  end

  def curve_path(placed, options) = curve_through(placed.points, options)

  def curve_through(points, options)
    Chadcn::Chart::Shape::Curve.line(points.map(&:xy), type: options[:type], layout: @layout.direction, connect_nulls: options[:connect_nulls])
  end

  # The dots of a line or an area (layer 600): `dot: true`, or a Hash of attributes, or a lone point.
  def dots(placed, name)
    series = placed.series
    dot = series.options[:dot]
    return unless dot || placed.points.size == 1

    custom = dot.is_a?(Hash) ? dot.except(:clip_dot) : {}
    base = attrs({ r: 3 }, dot_base(series), { class: "recharts-dot recharts-#{name}-dot" }, custom)
    g(**attrs({ class: "recharts-layer recharts-#{name}-dots" }, dots_clip_attribute(series, series_id(series, name, placed.index)))) do
      placed.points.each do |point|
        next unless point.x && point.y

        circle(**base, r: format_number(base[:r]), cx: format_number(point.x), cy: format_number(point.y))
      end
    end
  end

  def dot_base(series)
    options = series.options
    look = { stroke: options[:stroke], stroke_width: format_number(options[:stroke_width]), fill: options[:fill], stroke_dasharray: options[:stroke_dasharray],
             name: options[:name], fill_opacity: (format_number(options[:fill_opacity]) if options[:fill_opacity]) }
    attrs(look, plot_size, series_attrs(series))
  end

  # --- tooltip ------------------------------------------------------------------------------------------------------------

  # The cursor of the category `default_index:` shows, in the layer recharts draws it in (200 behind the bars, 1100 for a line).
  def tooltip_cursor(layer)
    cursor = @tooltip_entry&.cursor
    path(**cursor.attrs, data: { chadcn__chart_target: "cursor" }) if cursor && cursor.layer == layer
  end

  # The dot on the point of the category `default_index:` shows (component/ActivePoints.js:19-56).
  def active_dot(placed)
    dot = @tooltip_entry&.dots&.find { |candidate| candidate.series.equal?(placed.series) }
    return unless dot

    g(class: "recharts-layer recharts-active-dot", data: { chadcn__chart_target: "activeDots" }) { circle(**dot.attrs, class: "recharts-dot") }
  end

  # --- areas --------------------------------------------------------------------------------------------------------------

  def area_series(placed, layer)
    case layer
    when 100 then area_shapes(placed)
    when 600 then dots(placed, "area")
    when 1200 then active_dot(placed)
    end
  end

  def area_shapes(placed)
    series = placed.series
    id = series_id(series, "area", placed.index)
    clip = clip(series)
    g(class: group_class(series, "area")) do
      clip_defs(id, clip, dots: dots_clip(series)) if clip
      g(class: "recharts-layer") do
        g(class: "recharts-layer", "clip-path": "url(#animationClipPath-#{id})") do
          next unless placed.points.size > 1

          g(**attrs({ class: "recharts-layer" }, clip_attribute(id, clip))) { area_paths(placed, id) }
        end
      end
    end
  end

  def area_paths(placed, id)
    series = placed.series
    options = series.options
    shared = attrs({ stroke_width: format_number(options[:stroke_width]), fill_opacity: format_number(options[:fill_opacity]), name: options[:name] },
                   plot_size, series_attrs(series))
    path(**shared, fill: options[:fill], stroke: "none", id: id, class: "recharts-curve recharts-area-area", d: area_fill_path(placed, options))
    return if options[:stroke].to_s == "none"

    path(**shared, stroke: options[:stroke], fill: "none", class: "recharts-curve recharts-area-curve", d: curve_path(placed, options))
    return unless placed.area.range && placed.area.baseline.is_a?(Array)

    lower = curve_through(placed.area.baseline, options)
    path(**shared, stroke: options[:stroke], fill: "none", class: "recharts-curve recharts-area-curve", d: lower)
  end

  def area_fill_path(placed, options)
    baseline = placed.area.baseline
    baseline = baseline.map(&:xy) if baseline.is_a?(Array)
    curve = { type: options[:type], layout: @layout.direction, connect_nulls: options[:connect_nulls] }
    Chadcn::Chart::Shape::Area.path(placed.points.map(&:xy), baseline: baseline, **curve)
  end

  # --- axes ---------------------------------------------------------------------------------------------------------------

  def draw_axis(declaration, layer)
    return unless [ 500, 2000 ].include?(layer)

    settings = declaration.settings
    return if settings.hide

    drawn = @layout.drawn_axes.find { |entry| entry[:axis].settings.kind == settings.kind && entry[:axis].settings.id == settings.id }
    return unless drawn && drawn[:width].positive? && drawn[:height].positive?

    layer == 500 ? axis_group(drawn) : axis_labels(drawn)
  end

  def axis_class(settings) = "recharts-#{settings.kind}Axis"

  def axis_group(drawn)
    axis = drawn[:axis]
    settings = axis.settings
    geometry = geometry_attributes(settings, drawn)
    ticks = @layout.visible_ticks(axis)
    g(class: attrs({ class: "recharts-layer recharts-cartesian-axis #{axis_class(settings)} #{settings.kind}Axis" }, { class: settings.attrs[:class] })[:class]) do
      axis_line(settings, drawn, geometry) if settings.axis_line
      g(class: "recharts-cartesian-axis-ticks #{axis_class(settings)}-ticks") do
        next if ticks.empty?

        g(class: "recharts-cartesian-axis-tick-lines #{axis_class(settings)}-tick-lines") do
          ticks.each do |tick|
            g(class: "recharts-layer recharts-cartesian-axis-tick") do
              next unless settings.tick_line

              coordinates = tick_coordinates(settings, drawn, tick)[:line].transform_values { |value| format_number(value) }
              line(**attrs(geometry, { fill: "none" }, (settings.tick_line if settings.tick_line.is_a?(Hash)), coordinates, { class: "recharts-cartesian-axis-tick-line" }))
            end
          end
        end
      end
    end
  end

  # The attributes recharts spreads on the axis line and the tick lines: `svgPropertiesNoEvents` of the axis props.
  def geometry_attributes(settings, drawn)
    box = { x: format_number(drawn[:x]), y: format_number(drawn[:y]), width: format_number(drawn[:width]), height: format_number(drawn[:height]) }
    attrs({ angle: format_number(settings.angle), orientation: settings.orientation.to_s, stroke: settings.stroke, name: settings.name&.to_s }, box,
          settings.attrs.except(:class, :class_name))
  end

  def axis_line(settings, drawn, geometry)
    x = drawn[:x]
    y = drawn[:y]
    if %i[top bottom].include?(settings.orientation)
      need = (settings.orientation == :top && !settings.mirror) || (settings.orientation == :bottom && settings.mirror) ? 1 : 0
      ends = { x1: format_number(x), y1: format_number(y + (need * drawn[:height])), x2: format_number(x + drawn[:width]),
               y2: format_number(y + (need * drawn[:height])) }
    else
      need = (settings.orientation == :left && !settings.mirror) || (settings.orientation == :right && settings.mirror) ? 1 : 0
      ends = { x1: format_number(x + (need * drawn[:width])), y1: format_number(y), x2: format_number(x + (need * drawn[:width])),
               y2: format_number(y + drawn[:height]) }
    end
    line(**attrs(geometry, (settings.axis_line if settings.axis_line.is_a?(Hash)), { fill: "none" }, ends, { class: "recharts-cartesian-axis-line" }))
  end

  # `getTickLineCoord`: the tick line, and where its label sits.
  def tick_coordinates(settings, drawn, tick)
    mirror = settings.mirror
    sign = mirror ? -1 : 1
    size = settings.tick_size
    coordinate = tick.coordinate
    label = tick.tick_coord.nil? ? coordinate : tick.tick_coord
    x = drawn[:x]
    y = drawn[:y]
    case settings.orientation
    when :top
      y2 = y + ((mirror ? 0 : 1) * drawn[:height])
      y1 = y2 - (sign * size)
      { line: { x1: coordinate, y1: y1, x2: coordinate, y2: y2 }, label: { x: label, y: y1 - (sign * settings.tick_margin) } }
    when :left
      x2 = x + ((mirror ? 0 : 1) * drawn[:width])
      x1 = x2 - (sign * size)
      { line: { x1: x1, y1: coordinate, x2: x2, y2: coordinate }, label: { x: x1 - (sign * settings.tick_margin), y: label } }
    when :right
      x2 = x + ((mirror ? 1 : 0) * drawn[:width])
      x1 = x2 + (sign * size)
      { line: { x1: x1, y1: coordinate, x2: x2, y2: coordinate }, label: { x: x1 + (sign * settings.tick_margin), y: label } }
    else
      y2 = y + ((mirror ? 1 : 0) * drawn[:height])
      y1 = y2 + (sign * size)
      { line: { x1: coordinate, y1: y1, x2: coordinate, y2: y2 }, label: { x: label, y: y1 + (sign * settings.tick_margin) } }
    end
  end

  def axis_labels(drawn)
    axis = drawn[:axis]
    settings = axis.settings
    return unless settings.tick

    ticks = @layout.visible_ticks(axis)
    return if ticks.empty?

    geometry = geometry_attributes(settings, drawn).except(:angle, :stroke)
    custom = settings.tick.is_a?(Hash) ? settings.tick : {}
    g(class: "recharts-cartesian-axis-tick-labels #{axis_class(settings)}-tick-labels") do
      ticks.each_with_index do |tick, index|
        g(class: "recharts-layer recharts-cartesian-axis-tick-label") do
          content = settings.tick_formatter ? settings.tick_formatter.call(tick.value, index) : tick.value
          text_node("#{Chadcn::Chart::Cartesian::Value.text(content)}#{settings.unit}", tick_coordinates(settings, drawn, tick)[:label],
                    anchor: tick_anchor(settings), vertical: tick_vertical_anchor(settings), width: drawn[:width], angle: settings.angle,
                    base: attrs(geometry, { stroke: "none", fill: settings.stroke }, custom.except(:class, :class_name)),
                    class_name: attrs({ class: "recharts-text recharts-cartesian-axis-tick-value" }, { class: custom[:class] || custom[:class_name] })[:class])
        end
      end
    end
  end

  def tick_anchor(settings)
    case settings.orientation
    when :left then settings.mirror ? :start : :end
    when :right then settings.mirror ? :end : :start
    else :middle
    end
  end

  def tick_vertical_anchor(settings)
    case settings.orientation
    when :left, :right then :middle
    when :top then settings.mirror ? :start : :end
    else settings.mirror ? :end : :start
    end
  end

  # recharts' `Text`: the label broken into lines for `width`, the first line hung on the anchor.
  def text_node(content, at, anchor:, vertical:, width:, angle:, base:, class_name:)
    lines = @layout.text.lines(content.to_s, line_width: width)
    fill = base[:fill].to_s.include?("url") ? "#808080" : base[:fill]
    left = format_number(at[:x])
    top = format_number(at[:y])
    rotation = angle.to_f.zero? ? nil : "rotate(#{format_number(angle)}, #{left}, #{top})"
    text(**base.except(:fill, :class), x: left, y: top, class: class_name, "text-anchor": anchor.to_s, fill: fill, transform: rotation) do
      lines.each_with_index do |line, index|
        tspan(x: left, dy: index.zero? ? @layout.text.first_dy(vertical, lines.size) : "1em") { plain(line) }
      end
    end
  end

  # --- reference lines ----------------------------------------------------------------------------------------------------

  def reference_line(reference)
    options = reference.options
    ends = reference_ends(options) or return
    own = { x: options[:x], y: options[:y] }.compact.transform_values { |value| Chadcn::Chart::Cartesian::Value.text(value) }
    look = { stroke: options[:stroke], stroke_dasharray: options[:stroke_dasharray], fill: options[:fill], fill_opacity: format_number(options[:fill_opacity]),
             stroke_width: format_number(options[:stroke_width]) }
    g(class: group_class(reference, "reference-line")) do
      line(**attrs(own, look, options[:attrs].except(:class), ends.transform_values do |value|
        format_number(value)
      end, { class: "recharts-reference-line-line" }))
    end
  end

  # `getEndPoints`: the two ends of the line, nil when it is not drawn (outside the axis range with `if_overflow: :discard`).
  def reference_ends(options)
    plot = @layout.plot
    if options[:y]
      axis = @layout.axis(:y, options[:y_axis_id])
      coordinate = reference_coordinate(axis, options[:y], options) or return
      points = [ [ plot[:x] + plot[:width], coordinate ], [ plot[:x], coordinate ] ]
      points.reverse! if axis.settings.orientation == :left
    elsif options[:x]
      axis = @layout.axis(:x, options[:x_axis_id])
      coordinate = reference_coordinate(axis, options[:x], options) or return
      points = [ [ coordinate, plot[:y] + plot[:height] ], [ coordinate, plot[:y] ] ]
      points.reverse! if axis.settings.orientation == :top
    else
      return
    end
    { x1: points[0][0], y1: points[0][1], x2: points[1][0], y2: points[1][1] }
  end

  def reference_coordinate(axis, value, options)
    return unless axis.scaled?

    coordinate = axis.position_of(value)
    return unless coordinate&.finite?

    coordinate += axis.bandwidth / 2 if axis.category? && axis.bandwidth
    low, high = axis.range_bounds
    return if options[:if_overflow] == :discard && !coordinate.between?(low, high)

    coordinate
  end

  # --- labels -------------------------------------------------------------------------------------------------------------

  def label_lists(placed)
    placed.series.label_lists.each do |list|
      entries = label_entries(placed, list)
      next if entries.empty?

      g(class: "recharts-layer recharts-label-list") { entries.each { |entry| label_text(list.options, entry) } }
    end
  end

  # One entry per shape: its box, the box labels are clamped to, and the value the label shows.
  def label_entries(placed, list)
    key = list.options[:data_key]
    if placed.series.kind == :bar
      parent = @layout.view_box
      placed.rects.map do |rect|
        { box: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }, parent: parent, value: label_value(key, rect.row, rect.value) }
      end
    else
      placed.points.map do |point|
        { box: { x: point.x || 0.0, y: point.y || 0.0, width: 0.0, height: 0.0 }, parent: nil, value: label_value(key, point.row, point.value) }
      end
    end
  end

  def label_value(key, row, value)
    return Chadcn::Chart::Cartesian::Value.read(row, key) unless key.nil?

    last = value.is_a?(Array) ? value.last : value
    last if last.nil? || last.is_a?(String) || last.is_a?(Numeric) || last == true || last == false
  end

  def label_text(options, entry)
    value = entry[:value]
    return if value.nil?

    position = Chadcn::Chart::Cartesian::LabelPosition.call(box: entry[:box], position: options[:position], offset: options[:offset], parent: entry[:parent])
    label_element(value, position, options, { width: position.width || entry[:box][:width], height: position.height || entry[:box][:height] })
  end

  # The `text` of a `Label` (component/Label.js): a custom `class:` replaces `recharts-label`.
  def label_element(value, position, options, size)
    custom = options[:attrs]
    formatter = options[:formatter]
    anchor = %w[start middle end inherit].include?(custom[:text_anchor].to_s) ? custom[:text_anchor].to_sym : position.horizontal_anchor
    box = { width: (format_number(size[:width]) if size[:width]), height: (format_number(size[:height]) if size[:height]) }
    base = attrs(box, { offset: format_number(options[:offset]), fill: options[:fill] || "#808080" }, custom.except(:class, :class_name, :text_anchor, :fill))
    class_name = "recharts-text #{custom[:class] || custom[:class_name] || 'recharts-label'}"
    text = Chadcn::Chart::Cartesian::Value.text(formatter ? formatter.call(value) : value)
    style = { anchor: anchor, vertical: position.vertical_anchor, width: size[:width], angle: options[:angle], base: base, class_name: class_name }
    text_node(text, { x: position.x, y: position.y }, **style)
  end

  # A `Chart::Label` written in the chart: a label placed around the plot.
  def standalone_label(label)
    options = label.options
    return if options[:value].nil?

    position = Chadcn::Chart::Cartesian::LabelPosition.call(box: @layout.plot, position: options[:position], offset: options[:offset])
    label_element(options[:value], position, options, { width: position.width, height: position.height })
  end
end
