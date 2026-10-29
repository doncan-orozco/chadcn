# frozen_string_literal: true

# The labels of a pie (`label:`, polar/Pie.js:218-264): for every sector a line from the rim to a point `offset_radius` out (`label_line:`)
# and the value of the sector beside it, portaled into the label layer.
#
# @api private
class Chadcn::Chart::Polar::Drawer::PieLabels < Chadcn::Chart::Polar::Drawer
  include Chadcn::Chart::Polar::Drawer::TextNodes

  LAYERS = [ 2000 ].freeze
  # `offsetRadius` of a label that does not give one (polar/Pie.js:235).
  OFFSET_RADIUS = 20

  private_constant :OFFSET_RADIUS

  # @return [void]
  def view_template
    series = subject.series
    options = series.options
    label = options[:label]
    custom = label.is_a?(Hash) ? label : {}
    reach = custom[:offset_radius].is_a?(Numeric) && !custom[:offset_radius].zero? ? custom[:offset_radius] : OFFSET_RADIUS
    subject.shapes.each do |sector|
      end_point = point(center(sector), sector.outer_radius + reach, middle_angle(sector))
      g(class: "recharts-layer") do
        label_line(series, sector, end_point) if options[:label_line]
        sector_text(series, sector, end_point, custom)
      end
    end
  end

  private

  # `renderLabelLineItem`: a linear curve whose stroke is the sector's fill.
  def label_line(series, sector, end_point)
    shown = Chadcn::Chart::Polar::PieSectors.presentation(series, sector)
    custom = series.options[:label_line].is_a?(Hash) ? series.options[:label_line] : {}
    start = point(center(sector), sector.outer_radius, middle_angle(sector))
    path(**attrs(shown.except(:class, :class_name), { fill: "none", stroke: shown[:fill] }, custom.except(:class, :class_name),
                 { class: classes("recharts-curve recharts-pie-label-line", user_class(custom)),
                   d: Chadcn::Chart::Shape::Curve.line([ start, end_point ], type: :linear, layout: :horizontal) }))
  end

  # `renderLabelItem`: the value of the sector, anchored to the side of the pie it is on.
  def sector_text(series, sector, end_point, custom)
    shown = Chadcn::Chart::Polar::PieSectors.presentation(series, sector)
    anchor = if end_point[0] > sector.cx then :start
    elsif end_point[0] < sector.cx then :end
    else :middle
    end
    base = attrs(shown.except(:class, :class_name), { stroke: "none" }, custom.except(:offset_radius, :class, :class_name),
                 { "alignment-baseline": "middle" })
    class_name = classes("recharts-text recharts-pie-label-text", user_class(custom))
    content = Chadcn::Chart::Cartesian::Value.text(value_of(series, sector))
    text_node(content, { x: end_point[0], y: end_point[1] }, anchor: anchor, vertical: :end, base: base, class_name: class_name)
  end

  def center(sector) = [ sector.cx, sector.cy ]

  def middle_angle(sector) = (sector.start_angle + sector.end_angle) / 2.0

  # `getValueByDataKey(entry, dataKey)` on the sector, which holds the row and the `value`.
  def value_of(series, sector)
    key = series.options[:data_key]
    found = Chadcn::Chart::Cartesian::Value.read(sector.row, key)
    found.nil? && key.to_s == "value" ? sector.value : found
  end
end
