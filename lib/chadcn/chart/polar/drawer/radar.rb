# frozen_string_literal: true

# The polygon and the dots of a radar (polar/Radar.js): the polygon in the area layer (`g.recharts-radar > g.recharts-radar-polygon > path`)
# and the dots in the scatter layer (`g.recharts-radar-dots`, component/Dots.js).
#
# @api private
class Chadcn::Chart::Polar::Drawer::Radar < Chadcn::Chart::Polar::Drawer
  LAYERS = [ 100, 600, 1200 ].freeze

  # @return [void]
  def view_template
    case @layer
    when 100 then polygon
    when 600 then dots
    else active_dot
    end
  end

  private

  def options = subject.series.options

  def points = subject.shapes

  def item_id = options[:attrs][:id] || "recharts-radar-#{canvas.uid}-#{subject.index}"

  def polygon
    g(class: classes("recharts-layer recharts-radar", user_class(options[:attrs]))) do
      g(class: "recharts-layer recharts-radar-polygon") do
        outline = Chadcn::Chart::Polar::Polygon.path(points.map { |point| [ point.x, point.y ] })
        path(**polygon_attributes, d: outline) if outline
      end
    end
  end

  # `svgPropertiesAndEvents(props)` of the radar, `fill` is none for a polygon that is not closed.
  def polygon_attributes
    attrs(look, shape_attrs(options[:attrs]), { id: item_id, class: classes("recharts-polygon", user_class(options[:attrs])) })
  end

  def look
    { fill: options[:fill], fill_opacity: options[:fill_opacity], stroke: options[:stroke], stroke_width: options[:stroke_width], name: options[:name] }
  end

  # The dot on the point of the category `default_index:` shows (component/ActivePoints.js:19-56).
  def active_dot
    dot = canvas.tooltip_entry&.dots&.find { |candidate| candidate.series.equal?(subject.series) }
    return unless dot

    g(class: "recharts-layer recharts-active-dot") { circle(**dot.attrs, class: "recharts-dot") }
  end

  # `Dots`: `dot: true`, or a Hash of attributes, or a lone point.
  def dots
    dot = options[:dot]
    return unless dot || points.size == 1

    custom = dot.is_a?(Hash) ? dot : {}
    base = attrs({ r: 3 }, look, shape_attrs(options[:attrs]), custom.except(:class, :class_name))
    g(class: "recharts-layer recharts-radar-dots") do
      points.each do |point|
        next unless point.x.is_a?(Numeric) && point.y.is_a?(Numeric)

        circle(**base, class: classes("recharts-dot recharts-radar-dot", user_class(custom)), cx: format_number(point.x), cy: format_number(point.y))
      end
    end
  end
end
