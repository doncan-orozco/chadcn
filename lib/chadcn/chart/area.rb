# frozen_string_literal: true

# recharts' `Area` (cartesian/Area.js): one series drawn as a filled curve down to a baseline. Declared in a {Chadcn::Chart::AreaChart};
# it renders nothing where it is written. Areas with the same `stack_id` are stacked (the lower edge of an area is the upper edge of the
# one below). A value that is a `[lower, upper]` pair draws a range. A {Chadcn::Chart::LabelList} in its block labels the points.
#
# Every attribute other than `class:` lands on the fill, the stroke and the dots; `class:` lands on the group.
#
# @example
#   chart.area(data_key: :desktop, type: :natural, fill: "url(#fillDesktop)", fill_opacity: 0.4, stroke: "var(--color-desktop)", stack_id: "a")
class Chadcn::Chart::Area < Chadcn::Chart::Declaration
  include Chadcn::Chart::Cartesian::Series

  # @api private
  KIND = :area

  # @param data_key [Symbol, String, #call] the key of each data row whose value is the top edge, or a callable that receives the row
  # @param type [Symbol] the curve: `:linear`, `:monotone`, `:natural`, `:step`, ...
  # @param stack_id [String, Symbol, Integer, nil] areas with the same id are stacked, in order of declaration
  # @param fill [String] the fill, e.g. `url(#gradient)`
  # @param fill_opacity [Numeric]
  # @param stroke [String] the line along the top edge; `"none"` draws none
  # @param stroke_width [Numeric]
  # @param dot [Boolean, Hash] a dot on every point; a Hash gives its attributes
  # @param active_dot [Boolean, Hash] accepted for parity with recharts; the dot of the hovered point needs the tooltip
  # @param base_value [Numeric, Symbol, nil] where the area starts: a number, `:data_min` or `:data_max` (the chart's `base_value` by default)
  # @param connect_nulls [Boolean] join the points around a row without a value
  # @param label [Boolean, Hash] `true` (or a Hash of {Chadcn::Chart::LabelList} keywords) is a label list on the area
  # @param legend_type [Symbol] the legend icon
  # @param tooltip_type [Symbol, nil] `:none` drops the series from the tooltip
  # @param hide [Boolean] draws nothing; the series stays in the legend
  # @param name [String, nil] the name in the tooltip and the legend (the data key by default)
  # @param unit [String, nil] appended to the value in the tooltip
  # @param x_axis_id [Object] the x axis the area is drawn against
  # @param y_axis_id [Object] the y axis the area is drawn against
  # @param is_animation_active [Boolean, Symbol, nil] accepted for parity with recharts and ignored
  # @param attrs [Hash] attributes of the shapes and of the dots; `class:` of the group
  # @raise [ArgumentError] on an unknown `type:`, `legend_type:` or `tooltip_type:`, or no `data_key:`
  def initialize(data_key:, type: :linear, stack_id: nil, fill: "#3182bd", fill_opacity: 0.6, stroke: "#3182bd", stroke_width: 1, dot: false, active_dot: true,
                 base_value: nil, connect_nulls: false, label: false, legend_type: :line, tooltip_type: nil, hide: false, name: nil, unit: nil,
                 x_axis_id: 0, y_axis_id: 0, is_animation_active: nil, **attrs)
    @options = { data_key: data_key, type: choice(:type, type, Chadcn::Chart::Shape::Curve::TYPES), stack_id: stack_id, fill: fill, fill_opacity: fill_opacity,
                 stroke: stroke, stroke_width: stroke_width, dot: dot, active_dot: active_dot, base_value: base_value, connect_nulls: connect_nulls, label: label,
                 legend_type: choice(:legend_type, legend_type, Chadcn::Chart::Bar::LEGEND_TYPES),
                 tooltip_type: (choice(:tooltip_type, tooltip_type, %i[none]) unless tooltip_type.nil?), hide: hide, name: name, unit: unit,
                 x_axis_id: x_axis_id, y_axis_id: y_axis_id, attrs: attrs }.freeze
    initialize_series
    super()
  end
end
