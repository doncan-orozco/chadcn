# frozen_string_literal: true

require "json"

# What `chadcn--chart` needs from the server (dev/port/specs/chart.md, "Behavior", Values and Actions): the Stimulus values for the
# `div[data-slot="chart"]` (Stimulus reads values from the controller element only) and the `data-action` of `.recharts-wrapper`. The
# controller does the interaction in the browser; the server only says where the ticks are and which `Tooltip` options apply.
#
# @api private
class Chadcn::Chart::Cartesian::Wiring
  CONTROLLER = "chadcn--chart"

  # Every action of the controller, on `.recharts-wrapper` (`keydown@document` is the Escape that dismisses the tooltip).
  ACTION = %w[pointermove->move pointerleave->leave click->click focusin->focus focusout->blur keydown->key keydown@document->dismiss]
           .map { |descriptor| descriptor.sub("->", "->#{CONTROLLER}#") }.join(" ").freeze

  # `offset` of recharts' `Tooltip` (component/Tooltip.js:52): the value of a side the caller left out.
  DEFAULT_OFFSET = 10

  Css = Chadcn::Chart::Cartesian::CssStyle

  private_constant :DEFAULT_OFFSET, :Css

  # @api private
  # @param layout [Chadcn::Chart::Cartesian::Layout]
  # @param declared [Chadcn::Chart::Cartesian::Declared]
  # @param accessibility_layer [Boolean]
  # @param plan [Chadcn::Chart::Cartesian::TooltipPlan, nil] nil without a tooltip
  def initialize(layout:, declared:, accessibility_layer:, plan:)
    @layout = layout
    @declared = declared
    @accessibility_layer = accessibility_layer
    @plan = plan
  end

  # @api private
  # @return [Hash{Symbol => String}] `data-chadcn--chart-*-value` attributes, keys written the Phlex way (`chadcn__chart_layout_value`)
  def values
    base = { layout: @layout.direction.to_s, keyboard_step: keyboard_step.to_s, accessibility_layer: @accessibility_layer.to_s }
    base.merge!(tooltip_values) if @plan
    base.transform_keys { |name| :"#{CONTROLLER.tr('-', '_')}_#{name}_value" }
  end

  # `selectChartDirection` (state/selectors/axisSelectors.js:1319-1341) read by the keyboard middleware (state/keyboardEventsMiddleware.js:63-66):
  # +1 only for a horizontal layout with no reversed `XAxis`.
  #
  # @api private
  # @return [Integer] 1 or -1
  def keyboard_step
    reversed = @declared.axes.any? { |settings| settings.x? && settings.reversed }
    @layout.direction == :horizontal && !reversed ? 1 : -1
  end

  private

  def tooltip_values
    options = @plan.tooltip.options
    { ticks: json(ticks), plot: json(plot), pointer_index: "-1", pointer_active: "false", keyboard_index: "-1", keyboard_active: "false",
      default_index: (Integer(options[:default_index].to_s, exception: false) || -1).to_s, tooltip_event_type: "axis",
      trigger: options[:trigger].to_s, tooltip_active: options[:active].nil? ? "" : options[:active].to_s,
      offset: json(pair(options[:offset])), allow_escape: json(flags(options[:allow_escape_view_box])),
      reverse_direction: json(flags(options[:reverse_direction])), position: json(position(options[:position])),
      transition: transition(options), transition_auto: (options[:is_animation_active].to_s == "auto").to_s,
      wrapper_style: json(Css.declarations(options[:wrapper_style])) }
  end

  # `[{index, coordinate}]` of the axis the tooltip follows, along the layout's category direction.
  def ticks
    key = @layout.direction == :horizontal ? :x : :y
    @plan.entries.map { |entry| { index: entry.index, coordinate: pixel(entry.coordinate.fetch(key)) } }
  end

  # The plot rectangle: `isInCartesianRange` (util/getActiveCoordinate.js:78-84) and the view box of the tooltip
  # (state/selectors/selectChartOffsetInternal.js:81-86).
  def plot = @layout.plot.slice(:x, :y, :width, :height).transform_values { |value| pixel(value) }

  def pair(value)
    return { x: value, y: value } if value.is_a?(Numeric)

    hash = value.is_a?(Hash) ? value.transform_keys(&:to_sym) : {}
    { x: hash.fetch(:x, DEFAULT_OFFSET), y: hash.fetch(:y, DEFAULT_OFFSET) }
  end

  def flags(value)
    hash = value.is_a?(Hash) ? value.transform_keys(&:to_sym) : {}
    { x: hash[:x] ? true : false, y: hash[:y] ? true : false }
  end

  # Only a numeric coordinate fixes the tooltip (util/tooltip/translate.js:32-34).
  def position(value)
    hash = value.is_a?(Hash) ? value.transform_keys(&:to_sym) : {}
    hash.slice(:x, :y).select { |_, coordinate| coordinate.is_a?(Numeric) }
  end

  # `transform <duration>ms <easing>` (component/TooltipBoundingBox.js:9-17); empty when the animation is off.
  def transition(options)
    return "" if options[:is_animation_active] == false

    "transform #{Chadcn::Chart::Shape::Number.format(options[:animation_duration])}ms #{options[:animation_easing]}"
  end

  def pixel(value)
    rounded = value.round(4)
    rounded == rounded.to_i ? rounded.to_i : rounded
  end

  def json(value) = JSON.generate(value)
end
