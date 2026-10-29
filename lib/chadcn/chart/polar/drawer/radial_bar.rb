# frozen_string_literal: true

# The arcs of a radial bar (polar/RadialBar.js:140-300): `g.recharts-area` in the bar layer (recharts' own class for it) holding the
# bars in `g.recharts-radial-bar-sectors`, one `g.recharts-shape > path` each, and the arcs behind them (`background:`) in the bar background layer.
# The class of every arc ends in the literal `undefined` when the row and the cell give none: recharts writes `className` of the entry in a
# template literal.
#
# @api private
class Chadcn::Chart::Polar::Drawer::RadialBar < Chadcn::Chart::Polar::Drawer
  LAYERS = [ -50, 300 ].freeze

  # @return [void]
  def view_template
    @layer == -50 ? backgrounds : bars
  end

  private

  def series = subject.series

  def options = series.options

  def sectors = subject.shapes

  def background = options[:background]

  def bars
    g(class: classes("recharts-layer recharts-area", user_class(options[:attrs]))) do
      g(class: "recharts-layer recharts-radial-bar-background") if background
      g(class: "recharts-layer recharts-radial-bar-sectors") { sectors.each { |sector| arc(sector, sector_attributes(sector)) } }
    end
  end

  # `renderBackground`: an arc spanning the whole angle behind every bar that has a place.
  def backgrounds
    return unless background

    custom = background.is_a?(Hash) ? background : {}
    sectors.each do |sector|
      next unless sector.background

      shape = attrs(row_attributes(sector), { fill: "#eee" }, custom.except(:class, :class_name, :z_index), sector.background.slice(:cx, :cy),
                    { class: classes("recharts-sector recharts-radial-bar-background-sector", user_class(custom) || "undefined") })
      arc(sector, shape, geometry: sector.background)
    end
  end

  # `Shape` > `Sector`: the arc in a `g.recharts-shape`; a bar that cannot be drawn is the empty group.
  def arc(sector, shape, geometry: nil)
    g(class: "recharts-layer recharts-shape") do
      outline = Chadcn::Chart::Shape::Arc.sector_path(**outline_geometry(geometry || sector), **corners)
      path(**shape, d: outline) if outline
    end
  end

  def outline_geometry(source)
    values = source.is_a?(Hash) ? source : source.to_h
    return {} unless values.values_at(:inner_radius, :outer_radius, :start_angle, :end_angle).none?(&:nil?)

    values.slice(:cx, :cy, :inner_radius, :outer_radius, :start_angle, :end_angle)
  end

  def corners = { corner_radius: corner_radius, force_corner_radius: options[:force_corner_radius], corner_is_external: options[:corner_is_external] }

  # `parseCornerRadius`: a text keeps its integer part.
  def corner_radius
    value = options[:corner_radius]
    value.is_a?(String) ? value.to_i : value
  end

  def row_attributes(sector) = sector.attributes

  # The path of an arc: the radial bar's own props, then what the row and the cell give, then the center.
  def sector_attributes(sector)
    own = { fill: options[:fill], stroke: options[:stroke], stroke_width: options[:stroke_width] }
    attrs(own, shape_attrs(options[:attrs]), row_attributes(sector).except(:class, :class_name), { cx: sector.cx, cy: sector.cy },
          { class: classes("recharts-sector recharts-radial-bar-sector", sector.attributes[:class] || "undefined") })
  end
end
