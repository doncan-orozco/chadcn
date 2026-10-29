# frozen_string_literal: true

# A `PolarGrid` (polar/PolarGrid.js:120-207): `g.recharts-polar-grid` in the lowest layer, a concentric ring for every tick of the radius
# axis (circles or polygons through the angle ticks, plus a filled one behind them when the grid has a `fill:`) and a line from the inner
# to the outer radius for every tick of the angle axis. `class:` and every other attribute land on every ring and line, not on the group.
#
# @api private
class Chadcn::Chart::Polar::Drawer::Grid < Chadcn::Chart::Polar::Drawer
  LAYERS = [ -100 ].freeze

  # @return [void]
  def view_template
    return unless layout.axes? && box.outer_radius.positive?

    angles = angles_of(options[:polar_angles], :angle_axis, options[:angle_axis_id]) or return
    radii = angles_of(options[:polar_radius], :radius_axis, options[:radius_axis_id]) or return
    g(class: "recharts-polar-grid") do
      concentric(radii, angles)
      radial_lines(angles) if options[:radial_lines] && angles.any?
    end
  end

  private

  def options = subject.options

  def box = layout.view_box

  # The angles (or radii) the grid is drawn at: the ones it was given, else the tick coordinates of its axis; nil when there is no scale.
  def angles_of(given, axis_reader, id)
    return given if given

    axis = layout.public_send(axis_reader, id)
    axis.scaled? ? axis.all_ticks.map(&:coordinate) : nil
  end

  # `svgPropertiesNoEvents(props)` of the grid: the stroke, the fill, the center and everything the caller gave.
  def common
    attrs({ stroke: options[:stroke], fill: options[:fill], cx: box.cx, cy: box.cy }, shape_attrs(options[:attrs]), { class: user_class(options[:attrs]) })
  end

  def concentric(radii, angles)
    return if radii.empty?

    g(class: "recharts-polar-grid-concentric") do
      ring(radii.max, angles, background: true) if options[:fill] && options[:fill].to_s != "none"
      radii.each { |radius| ring(radius, angles) }
    end
  end

  # `ConcentricCircle` / `ConcentricPolygon`. A ring has no fill; the background keeps the grid's.
  def ring(radius, angles, background: false)
    base = attrs({ stroke: "#ccc", fill: "none" }, common, (background ? {} : { fill: "none" }), { radius: radius })
    if options[:grid_type] == :circle
      circle(**base, class: classes("recharts-polar-grid-concentric-circle", user_class(options[:attrs])), r: format_number(radius))
    else
      path(**base, class: classes("recharts-polar-grid-concentric-polygon", user_class(options[:attrs])), d: polygon_path(radius, angles))
    end
  end

  # `getPolygonPath`: the points are not rounded.
  def polygon_path(radius, angles)
    corners = angles.each_with_index.map do |angle, index|
      x, y = box.point(radius, angle)
      "#{index.zero? ? 'M' : 'L'} #{format_number(x)},#{format_number(y)}"
    end
    "#{corners.join}Z"
  end

  def radial_lines(angles)
    g(class: "recharts-polar-grid-angle") do
      angles.each do |angle|
        from = box.point(box.inner_radius, angle)
        to = box.point(box.outer_radius, angle)
        line(**attrs({ stroke: "#ccc" }, common, { x1: from[0], y1: from[1], x2: to[0], y2: to[1] }))
      end
    end
  end
end
