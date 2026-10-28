# frozen_string_literal: true

# shadcn/ui Chart: the wrapper layer of shadcn's `chart.tsx` (`ChartContainer`, `ChartStyle`, `ChartTooltip`, `ChartTooltipContent`,
# `ChartLegend`, `ChartLegendContent` and the `ChartConfig` type) as Phlex. Spec: dev/port/specs/chart.md, decision record:
# dev/decisions/chart.md. recharts is not shipped; the chart roots that draw the SVG (`Chart::BarChart` ...) are separate parts.
#
# The family root: `Chart.new { |chart| ... }` yields itself, so the block can use the generated helpers (`chart.container`,
# `chart.style`, `chart.tooltip`, `chart.legend`).
#
# @example Container with a config and the shadcn tooltip content
#   render Chadcn::Chart.new do |chart|
#     chart.container(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }) do |container|
#       render Chadcn::Chart::Tooltip::Content.new(payload: [ { name: "desktop", value: 186, color: "var(--color-desktop)" } ])
#     end
#   end
#
# Generated helpers (each forwards `**attrs` and the block to the part): `container`, `style`, `tooltip` and `legend`.
#
# @!method container(**attrs, &block)
#   Same as `render Chart::Container.new(**attrs), &block`.
# @!method style(**attrs, &block)
#   Same as `render Chart::Style.new(**attrs), &block`.
# @!method tooltip(**attrs, &block)
#   Same as `render Chart::Tooltip.new(**attrs), &block`.
# @!method legend(**attrs, &block)
#   Same as `render Chart::Legend.new(**attrs), &block`.
class Chadcn::Chart < Chadcn::Base
  # What {Chadcn::Chart::Tooltip::Content} and {Chadcn::Chart::Legend::Content} share: the content is built from one frozen
  # `@options` hash and a validated payload, copied per tooltip index by {#with}, and reads the config of the enclosing
  # {Chadcn::Chart::Container} (React's `useChart()`). Defined here, not in its own file, for the reason the contents are nested in
  # their declarations (see `tooltip.rb`).
  #
  # @api private
  module ContentSupport
    # A copy with other options, e.g. the payload and label of one tooltip index.
    #
    # @api private
    # @return [Chadcn::Base]
    def with(**changes) = self.class.new(**@options.except(:attrs), **@options.fetch(:attrs), payload: @payload, **changes)

    private

    def option(name) = @options.fetch(name)

    # JS truthiness of a payload name: nil, false, "" and 0 are falsy.
    def js_truthy?(value) = ![ nil, false, "", 0 ].include?(value)

    # @param payload [Array<Hash>, nil] nil is an absent payload
    # @return [Array<Hash>]
    # @raise [ArgumentError] unless it is an Array of Hashes
    def validated_payload(payload)
      return [] if payload.nil?
      return payload if payload.is_a?(Array) && payload.all?(Hash)

      raise ArgumentError, "payload: must be an Array of Hashes (got #{payload.class})"
    end

    def chart_config
      container = Chadcn::Chart::Container.current(context)
      raise ArgumentError, "#{self.class.name} has no Chart::Container around it; React's useChart() raises the same" unless container

      container.config
    end

    # A payload item's value by symbol or string key.
    def item_value(item, key)
      item.fetch(key) { item[key.to_s] }
    end

    # Whether the item has the key at all, even with a nil value (JS `!== undefined`).
    def item_key?(item, key) = item.key?(key) || item.key?(key.to_s)

    def render_icon(icon)
      render(icon.is_a?(Phlex::SGML) ? icon : Chadcn::Icon.new(icon))
    end

    def render_node(node)
      case node
      when nil, false then nil
      when Phlex::SGML then render(node)
      else plain(node.to_s)
      end
    end
  end

  # @yieldparam chart [Chart] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    yield self if block_given?
  end
end
