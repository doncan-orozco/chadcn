# frozen_string_literal: true

# A `PolarAngleAxis` (polar/PolarAngleAxis.js:150-250): `g.recharts-polar-angle-axis` in the axis layer, the axis line (a polygon through the
# ticks, or a circle), and a tick for every angle: a line from the rim `tick_size` outwards and the label at its end. The class the caller
# gave replaces the class of the axis line and of the tick lines, as recharts spreads the axis props after its own `className`.
#
# @api private
class Chadcn::Chart::Polar::Drawer::AngleAxis < Chadcn::Chart::Polar::Drawer
  include Chadcn::Chart::Polar::Drawer::TextNodes

  LAYERS = [ 500 ].freeze
  # recharts' `eps` and `COS_45` (polar/PolarAngleAxis.js:19-20): where a tick counts as at the side or at the top and bottom.
  SIDE = 1e-5
  DIAGONAL = Math.cos(Math::PI / 4)

  TICK_CLASS = "recharts-text recharts-polar-angle-axis-tick-value"

  private_constant :SIDE, :DIAGONAL, :TICK_CLASS

  # @return [void]
  def view_template
    ticks = axis.ticks
    return if !axis.scaled? || ticks.empty?

    g(class: classes("recharts-layer recharts-polar-angle-axis angleAxis", user_class(settings.attrs))) do
      axis_line(ticks) if settings.axis_line
      g(class: "recharts-layer recharts-polar-angle-axis-ticks") { ticks.each_with_index { |tick, index| tick_group(tick, index) } }
    end
  end

  private

  def settings = subject.settings

  def axis = layout.angle_axis(settings.id)

  def box = layout.view_box

  # The attributes recharts spreads on the axis line, the tick lines and the labels (`svgPropertiesNoEvents` of the axis props).
  def axis_props
    attrs({ angle: settings.angle, cx: box.cx, cy: box.cy, orientation: settings.orientation.to_s, radius: box.outer_radius, stroke: settings.stroke },
          shape_attrs(settings.attrs), { class: user_class(settings.attrs) })
  end

  def hash_of(option) = option.is_a?(Hash) ? option : {}

  def axis_line(ticks)
    look = attrs(axis_props.except(:class), { fill: "none" }, hash_of(settings.axis_line))
    if settings.axis_line_type == :circle
      circle(**attrs(look, { class: classes("recharts-dot", own_class("recharts-polar-angle-axis-line")), cx: box.cx, cy: box.cy, r: box.outer_radius }))
    else
      outline = Chadcn::Chart::Polar::Polygon.path(ticks.map { |tick| box.point(box.outer_radius, tick.coordinate) })
      path(**attrs(look, { class: classes("recharts-polygon", own_class("recharts-polar-angle-axis-line")), d: outline }))
    end
  end

  # The class of the axis line and of the tick lines is the caller's when it has one (recharts spreads the axis props after its own).
  def own_class(default) = user_class(settings.attrs) || default

  def tick_group(tick, index)
    custom = hash_of(settings.tick)
    g(class: classes("recharts-layer recharts-polar-angle-axis-tick", custom[:class])) do
      tick_line(tick) if settings.tick_line
      tick_label(tick, index, custom) if settings.tick
    end
  end

  # `getTickLineCoord`: from the rim, `tick_size` out (in, for an inner axis).
  def tick_line(tick)
    sign = settings.orientation == :inner ? -1 : 1
    size = settings.tick_size.nonzero? || 8
    from = box.point(box.outer_radius, tick.coordinate)
    to = box.point(box.outer_radius + (sign * size), tick.coordinate)
    line(**attrs(axis_props, { class: own_class("recharts-polar-angle-axis-tick-line"), fill: "none" }, hash_of(settings.tick_line),
                 { x1: from[0], y1: from[1], x2: to[0], y2: to[1] }))
  end

  def tick_label(tick, index, custom)
    sign = settings.orientation == :inner ? -1 : 1
    at = box.point(box.outer_radius + (sign * (settings.tick_size.nonzero? || 8)), tick.coordinate)
    value = settings.tick_formatter ? settings.tick_formatter.call(tick.value, index) : tick.value
    base = attrs(axis_props.except(:angle, :class), { stroke: "none", fill: settings.stroke }, custom.except(:class, :class_name))
    where = { anchor: anchor_of(tick), vertical: vertical_anchor_of(tick) }
    text_node(Chadcn::Chart::Cartesian::Value.text(value), { x: at[0], y: at[1] }, **where, base: base, class_name: TICK_CLASS)
  end

  # `getTickTextAnchor`: the side of the center the label is on.
  def anchor_of(tick)
    cos = Math.cos(Chadcn::Chart::Shape::Polar.to_radians(-tick.coordinate))
    return settings.orientation == :outer ? :start : :end if cos > SIDE
    return settings.orientation == :outer ? :end : :start if cos < -SIDE

    :middle
  end

  # `getTickTextVerticalAnchor`: hung from the top above the center, from the bottom below it.
  def vertical_anchor_of(tick)
    radians = Chadcn::Chart::Shape::Polar.to_radians(-tick.coordinate)
    return :middle unless Math.cos(radians).abs <= DIAGONAL

    Math.sin(radians).positive? ? :start : :end
  end
end
