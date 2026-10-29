# frozen_string_literal: true

# A `PolarRadiusAxis` (polar/PolarRadiusAxis.js:100-200): `g.recharts-polar-radius-axis` in the axis layer, the axis line from the lowest to
# the highest tick at `angle`, and a label for every tick, rotated to stand upright on the axis. The class the caller gave replaces the
# class of the axis line, as recharts spreads the axis props after its own `className`.
#
# @api private
class Chadcn::Chart::Polar::Drawer::RadiusAxis < Chadcn::Chart::Polar::Drawer
  include Chadcn::Chart::Polar::Drawer::TextNodes

  LAYERS = [ 500 ].freeze
  # The `text-anchor` of the labels by the side of the axis they hang on (polar/PolarRadiusAxis.js:50-65).
  ANCHORS = { left: :end, right: :start }.freeze

  TICK_CLASS = "recharts-text recharts-polar-radius-axis-tick-value"

  private_constant :ANCHORS, :TICK_CLASS

  # @return [void]
  def view_template
    ticks = axis.ticks
    return if !axis.scaled? || ticks.empty?

    g(class: classes("recharts-layer recharts-polar-radius-axis radiusAxis", user_class(settings.attrs))) do
      axis_line(ticks) if settings.axis_line
      g(class: "recharts-layer recharts-polar-radius-axis-ticks") { ticks.each_with_index { |tick, index| tick_group(tick, index) } } if settings.tick
    end
  end

  private

  def settings = subject.settings

  def axis = layout.radius_axis(settings.id)

  def box = layout.view_box

  def hash_of(option) = option.is_a?(Hash) ? option : {}

  # What recharts spreads on the line and on the labels (`svgPropertiesNoEvents(others)`).
  def axis_props
    attrs({ orientation: settings.orientation.to_s, stroke: settings.stroke }, shape_attrs(settings.attrs), { class: user_class(settings.attrs) })
  end

  # `renderAxisLine`: from the lowest tick to the highest, at the angle of the axis.
  def axis_line(ticks)
    extent = ticks.map(&:coordinate).minmax
    from = box.point(extent[0], settings.angle)
    to = box.point(extent[1], settings.angle)
    own = { class: user_class(settings.attrs) || "recharts-polar-radius-axis-line", fill: "none" }
    line(**attrs(axis_props.except(:class), own, hash_of(settings.axis_line), { x1: from[0], y1: from[1], x2: to[0], y2: to[1] }))
  end

  def tick_group(tick, index)
    custom = hash_of(settings.tick)
    at = box.point(tick.coordinate, settings.angle)
    g(class: classes("recharts-layer recharts-polar-radius-axis-tick", custom[:class])) do
      value = settings.tick_formatter ? settings.tick_formatter.call(tick.value, index) : tick.value
      rotation = "rotate(#{format_number(90 - settings.angle)}, #{format_number(at[0])}, #{format_number(at[1])})"
      base = attrs({ transform: rotation, cx: box.cx, cy: box.cy }, axis_props.except(:class), { stroke: "none", fill: settings.stroke },
                   custom.except(:class, :class_name))
      where = { anchor: ANCHORS.fetch(settings.orientation, :middle), vertical: :end }
      text_node(Chadcn::Chart::Cartesian::Value.text(value), { x: at[0], y: at[1] }, **where, base: base, class_name: TICK_CLASS)
    end
  end
end
