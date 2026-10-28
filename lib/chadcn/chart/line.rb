# frozen_string_literal: true

# recharts' `Line` (cartesian/Line.js): one series drawn as a curve through its points. Declared in a {Chadcn::Chart::LineChart}; it renders
# nothing where it is written. A row without a value for the `data_key` breaks the line there unless `connect_nulls` is set. A
# {Chadcn::Chart::LabelList} in its block labels the points.
#
# Every attribute other than `class:` lands on the curve and the dots; `class:` lands on the group.
#
# @example
#   chart.line(data_key: :desktop, type: :monotone, stroke: "var(--color-desktop)", stroke_width: 2, dot: { fill: "var(--color-desktop)" })
class Chadcn::Chart::Line < Chadcn::Chart::Declaration
  include Chadcn::Chart::Cartesian::Series

  # @api private
  KIND = :line

  # @param data_key [Symbol, String, #call] the key of each data row whose value is the point, or a callable that receives the row
  # @param type [Symbol] the curve: `:linear`, `:monotone`, `:natural`, `:step`, `:step_before`, `:step_after`, `:basis`, `:bump`, ...
  # @param stroke [String]
  # @param stroke_width [Numeric]
  # @param stroke_dasharray [String, nil]
  # @param fill [String] the fill of the dots
  # @param dot [Boolean, Hash] a dot on every point; a Hash gives its attributes (`r:`, `fill:`, `stroke:` ...)
  # @param active_dot [Boolean, Hash] accepted for parity with recharts; the dot of the hovered point needs the tooltip
  # @param connect_nulls [Boolean] join the points around a row without a value
  # @param label [Boolean, Hash] `true` (or a Hash of {Chadcn::Chart::LabelList} keywords) is a label list on the line
  # @param legend_type [Symbol] the legend icon
  # @param tooltip_type [Symbol, nil] `:none` drops the series from the tooltip
  # @param hide [Boolean] draws nothing; the series stays in the legend
  # @param name [String, nil] the name in the tooltip and the legend (the data key by default)
  # @param unit [String, nil] appended to the value in the tooltip
  # @param x_axis_id [Object] the x axis the line is drawn against
  # @param y_axis_id [Object] the y axis the line is drawn against
  # @param is_animation_active [Boolean, Symbol, nil] accepted for parity with recharts and ignored
  # @param attrs [Hash] attributes of the curve and of the dots; `class:` of the group
  # @raise [ArgumentError] on an unknown `type:`, `legend_type:` or `tooltip_type:`, or no `data_key:`
  def initialize(data_key:, type: :linear, stroke: "#3182bd", stroke_width: 1, stroke_dasharray: nil, fill: "#fff", dot: true, active_dot: true,
                 connect_nulls: false, label: false, legend_type: :line, tooltip_type: nil, hide: false, name: nil, unit: nil, x_axis_id: 0,
                 y_axis_id: 0, is_animation_active: nil, **attrs)
    @options = { data_key: data_key, type: curve_type(type), stroke: stroke, stroke_width: stroke_width, stroke_dasharray: stroke_dasharray, fill: fill,
                 dot: dot, active_dot: active_dot, connect_nulls: connect_nulls, label: label, legend_type: choice(:legend_type, legend_type, Chadcn::Chart::Bar::LEGEND_TYPES),
                 tooltip_type: (choice(:tooltip_type, tooltip_type, %i[none]) unless tooltip_type.nil?), hide: hide, name: name, unit: unit,
                 x_axis_id: x_axis_id, y_axis_id: y_axis_id, attrs: attrs }.freeze
    initialize_series
    super()
  end

  private

  def curve_type(type) = choice(:type, type, Chadcn::Chart::Shape::Curve::TYPES)
end
