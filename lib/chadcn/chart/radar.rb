# frozen_string_literal: true

# recharts' `Radar` (polar/Radar.js): one series drawn as a polygon through a point on each angle category, at the radius its value
# gives. Declared in a {Chadcn::Chart::RadarChart}; it renders nothing where it is written. A {Chadcn::Chart::LabelList} in its block
# labels the points. A row without a value for the `data_key` puts its point at the center.
#
# `class:` lands on the group and on the polygon; every other attribute lands on the polygon, and on the dots (where `dot:` has the last
# word). A range (`[low, high]` values, which recharts draws as a band) is not ported and raises.
#
# @example
#   chart.radar(data_key: :desktop, fill: "var(--color-desktop)", fill_opacity: 0.6, dot: { r: 4, fill_opacity: 1 })
class Chadcn::Chart::Radar < Chadcn::Chart::Declaration
  include Chadcn::Chart::Polar::Series

  # @api private
  KIND = :radar

  # @param data_key [Symbol, String, #call] the key of each data row whose value is the point's radius, or a callable that receives the row
  # @param fill [String, nil] fill of the polygon (none by default, as in recharts)
  # @param fill_opacity [Numeric, nil]
  # @param stroke [String, nil]
  # @param stroke_width [Numeric, nil]
  # @param dot [Boolean, Hash] a dot on every point; a Hash gives its attributes (`r:`, `fill:`, `fill_opacity:` ...)
  # @param active_dot [Boolean, Hash] the dot of the hovered category (drawn with the tooltip); a Hash gives its attributes
  # @param label [Boolean, Hash] `true` (or a Hash of {Chadcn::Chart::LabelList} keywords) is a label list on the radar
  # @param legend_type [Symbol] the legend icon
  # @param tooltip_type [Symbol, nil] `:none` drops the series from the tooltip
  # @param hide [Boolean] draws nothing; the series stays in the legend
  # @param name [String, nil] the name in the tooltip and the legend (the data key by default)
  # @param angle_axis_id [Object] the angle axis the points are placed on
  # @param radius_axis_id [Object] the radius axis the points are placed on
  # @param is_animation_active [Boolean, Symbol, nil] accepted for parity with recharts and ignored: the settled chart is drawn
  # @param attrs [Hash] attributes of the polygon and the dots; `class:` and `id:` of the group and the polygon
  # @raise [ArgumentError] on an invalid `legend_type:` or `tooltip_type:`, or a missing `data_key:`
  def initialize(data_key:, fill: nil, fill_opacity: nil, stroke: nil, stroke_width: nil, dot: false, active_dot: true, label: false, legend_type: :rect,
                 tooltip_type: nil, hide: false, name: nil, angle_axis_id: 0, radius_axis_id: 0, is_animation_active: nil, **attrs)
    @options = { data_key: data_key, fill: fill, fill_opacity: fill_opacity, stroke: stroke, stroke_width: stroke_width, dot: dot, active_dot: active_dot,
                 label: label, legend_type: choice(:legend_type, legend_type, LEGEND_TYPES), tooltip_type: tooltip_type_choice(tooltip_type), hide: hide,
                 name: name, angle_axis_id: angle_axis_id, radius_axis_id: radius_axis_id, attrs: attrs }.freeze
    initialize_series
    super()
  end

  # The color the legend and the tooltip show for the radar (`getLegendItemColor`, polar/Radar.js:24): its `stroke` unless that is absent or
  # `none`, else its `fill`.
  #
  # @api private
  # @return [String, nil]
  def legend_color
    stroke = options[:stroke]
    stroke && stroke.to_s != "none" ? stroke : options[:fill]
  end

  private

  def tooltip_type_choice(value)
    return value if value.nil?

    choice(:tooltip_type, value, %i[none])
  end
end
