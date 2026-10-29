# frozen_string_literal: true

# What `chadcn--chart` needs from a polar chart (dev/port/specs/chart.md, "Behavior"): only the tooltip values, so the controller keeps
# the `default_index:` tooltip the server drew. The controller maps the pointer and the keys for the cartesian charts only, so a polar
# chart publishes no ticks (there is no pointer-to-index mapping), no layout, no keyboard step, no accessibility layer, and its
# `.recharts-wrapper` has no `data-action`: nothing moves the tooltip. A pie is an `item` tooltip (the controller is inert and leaves the
# server-drawn tooltip untouched); a radar and a radial bar are `axis` tooltips (the controller keeps, places and restores it).
#
# @api private
class Chadcn::Chart::Polar::Wiring < Chadcn::Chart::Cartesian::Wiring
  # @api private
  # @param layout [Chadcn::Chart::Polar::Layout]
  # @param plan [Chadcn::Chart::Polar::TooltipPlan, nil] nil without a tooltip
  def initialize(layout:, plan:)
    super(layout: layout, declared: nil, accessibility_layer: false, plan: plan)
  end

  # @api private
  # @return [Hash{Symbol => String}] the tooltip `data-chadcn--chart-*-value` attributes (none without a tooltip), keys written the Phlex way
  def values
    return {} unless @plan

    tooltip_values.transform_keys { |name| :"#{CONTROLLER.tr('-', '_')}_#{name}_value" }
  end

  # Unused: no key reaches the controller of a polar chart.
  #
  # @api private
  # @return [Integer] 1
  def keyboard_step = 1

  private

  # No ticks: the controller cannot map a pointer to an index of a polar chart.
  def ticks = []
end
