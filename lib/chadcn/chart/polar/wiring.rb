# frozen_string_literal: true

# What `chadcn--chart` needs from a polar chart (dev/port/specs/chart.md, "Behavior"): the tooltip values, the layout (`centric` for a
# radar and a pie, `radial` for a radial bar chart), the keyboard and the polar view box the pointer is mapped through. On a radar the
# pointer's angle picks the category of the angle axis, on a radial bar chart its radius picks the ring of the radius axis (recharts'
# `combineActivePolarProps`, state/selectors/selectors.js:76-91), so the ticks are those angles or radii. A pie is an `item` tooltip: its
# tagged sectors are the items, and its ticks only count them for the keyboard. Every polar chart with a tooltip carries every action of
# the controller on its `.recharts-wrapper` (`Polar::Root#wrapper_attributes`).
#
# @api private
class Chadcn::Chart::Polar::Wiring < Chadcn::Chart::Cartesian::Wiring
  # @api private
  # @param layout [Chadcn::Chart::Polar::Layout]
  # @param plan [Chadcn::Chart::Polar::TooltipPlan, nil] nil without a tooltip
  # @param accessibility_layer [Boolean] the chart's `accessibility_layer:`
  def initialize(layout:, plan:, accessibility_layer: true)
    super(layout: layout, declared: nil, accessibility_layer: accessibility_layer, plan: plan)
  end

  # @api private
  # @return [Hash{Symbol => String}] the `data-chadcn--chart-*-value` attributes (none without a tooltip), keys written the Phlex way
  def values
    return {} unless @plan

    base = { layout: @layout.direction.to_s, keyboard_step: keyboard_step.to_s, accessibility_layer: @accessibility_layer.to_s, polar: json(polar) }
    base.merge(tooltip_values).transform_keys { |name| :"#{CONTROLLER.tr('-', '_')}_#{name}_value" }
  end

  # `selectChartDirection` (state/selectors/axisSelectors.js:1331-1335): a polar chart is always left-to-right, ArrowRight steps forward.
  #
  # @api private
  # @return [Integer] 1
  def keyboard_step = 1

  private

  # The angle (a radar) or radius (a radial bar chart) of every category, from the entries' anchors; a pie's sectors, which have no axis,
  # by their index: the keyboard only counts them.
  def ticks
    return super unless @layout.chart_type == :pie

    @plan.entries.uniq(&:index).map { |entry| { index: entry.index, coordinate: entry.index } }
  end

  # The polar view box (`selectPolarViewBox`) the pointer must fall in (`inRangeOfSector`), and the tooltip axis whose ticks it is mapped
  # onto: which one, and its range, whose full turn makes the angle ticks wrap around the circle (`calculateActiveTickIndex`).
  def polar
    box = @layout.view_box
    view = { cx: pixel(box.cx), cy: pixel(box.cy), innerRadius: pixel(box.inner_radius), outerRadius: pixel(box.outer_radius),
             startAngle: pixel(box.start_angle), endAngle: pixel(box.end_angle) }
    axis = @plan.axis
    return view unless axis

    view.merge(axis: @layout.direction == :centric ? "angle" : "radius", range: axis.range.map { |value| pixel(value) })
  end
end
