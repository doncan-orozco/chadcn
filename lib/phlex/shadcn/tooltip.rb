# frozen_string_literal: true

# shadcn Tooltip (Radix Tooltip). Spec: docs/shadcn-port/specs/tooltip.md. Behavior in controllers/shadcn/tooltip_controller.js.
# Provider and Root render no element: they push their options into the Phlex render context for the parts inside.
using Phlex::Shadcn::Values::Refinements

# Root of the Tooltip family; must be rendered inside a {Tooltip::Provider}. Renders no element.
#
# @example Explicit form
#   render Phlex::Shadcn::Tooltip::Provider.new do
#     render Phlex::Shadcn::Tooltip.new do
#       render Phlex::Shadcn::Tooltip::Trigger.new { "Hover" }
#       render Phlex::Shadcn::Tooltip::Content.new { "Tip" }
#     end
#   end
#
# @example Yielded-root helper form
#   render Phlex::Shadcn::Tooltip::Provider.new do
#     render Phlex::Shadcn::Tooltip.new do |tooltip|
#       tooltip.trigger { "Hover" }
#       tooltip.content { "Tip" }
#     end
#   end
#
# Generated helpers (each forwards `**attrs` and the block to the part): `provider`, `trigger` and `content`.
#
# @!method provider(**attrs, &block)
#   Same as `render Tooltip::Provider.new(**attrs), &block`.
# @!method trigger(**attrs, &block)
#   Same as `render Tooltip::Trigger.new(**attrs), &block`.
# @!method content(**attrs, &block)
#   Same as `render Tooltip::Content.new(**attrs), &block`.
class Phlex::Shadcn::Tooltip < Phlex::Shadcn::Base
  # @api private
  CONTEXT_KEY = :shadcn_tooltip_root
  # @api private
  PROVIDER_KEY = :shadcn_tooltip_provider
  # @api private
  SEQUENCE_KEY = :shadcn_tooltip_sequence

  # `open:` is controlled when not nil. `delay_duration:` / `disable_hoverable_content:` fall back to those of the provider.
  #
  # @param open [Boolean, nil] controlled open state when not nil
  # @param default_open [Boolean] initial open state when uncontrolled
  # @param delay_duration [Integer, nil] ms before opening; falls back to the provider's
  # @param disable_hoverable_content [Boolean, nil] close when the pointer leaves the trigger; falls back to the provider's
  def initialize(open: nil, default_open: false, delay_duration: nil, disable_hoverable_content: nil)
    @open = open
    @default_open = default_open
    @delay_duration = delay_duration
    @disable_hoverable_content = disable_hoverable_content
    super()
  end

  # @raise [ArgumentError] when rendered outside Tooltip::Provider
  # @yieldparam tooltip [Tooltip] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    provider = context[PROVIDER_KEY] or raise ArgumentError, "`Tooltip` must be used within `TooltipProvider`"
    previous = context[CONTEXT_KEY]
    context[CONTEXT_KEY] = {
      key: "tooltip-content-#{next_sequence}",
      controlled: !@open.nil?,
      open: @open.nil? ? @default_open : @open,
      provider_id: provider[:id],
      skip_delay_duration: provider[:skip_delay_duration],
      delay_duration: @delay_duration || provider[:delay_duration],
      disable_hoverable_content: @disable_hoverable_content.nil? ? provider[:disable_hoverable_content] : @disable_hoverable_content
    }
    yield self if block_given?
  ensure
    context[CONTEXT_KEY] = previous
  end

  private

  def next_sequence
    context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1
  end

  # Shares the delay options with the tooltips inside (renders no element).
  #
  # @example
  #   render Phlex::Shadcn::Tooltip::Provider.new(delay_duration: 200) { ... }
  class Provider < Phlex::Shadcn::Base
    # @param delay_duration [Integer] ms before a tooltip opens (default 0)
    # @param skip_delay_duration [Integer] ms during which moving to another tooltip skips the delay (default 300)
    # @param disable_hoverable_content [Boolean] close when the pointer leaves the trigger (default false)
    def initialize(delay_duration: 0, skip_delay_duration: 300, disable_hoverable_content: false)
      @options = { delay_duration:, skip_delay_duration:, disable_hoverable_content: }
      super()
    end

    # @yield the tooltips
    # @return [void]
    def view_template(&)
      previous = context[PROVIDER_KEY]
      context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1
      context[PROVIDER_KEY] = @options.merge(id: "tooltip-provider-#{context[SEQUENCE_KEY]}")
      yield(self) if block_given?
    ensure
      context[PROVIDER_KEY] = previous
    end
  end

  # The element that shows the tooltip on hover/focus (renders a `button` and hosts the controller).
  #
  # @example Explicit form
  #   render Phlex::Shadcn::Tooltip::Trigger.new { "Hover" }
  # @example Yielded-root helper form
  #   tooltip.trigger { "Hover" }
  class Trigger < Phlex::Shadcn::Base
    # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
    # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # @yield the trigger content
    # @return [void]
    # @raise [ArgumentError] when rendered outside Tooltip
    def view_template(&)
      root = context[CONTEXT_KEY] or raise ArgumentError, "`TooltipTrigger` must be used within `Tooltip`"
      attrs = merge_attrs({
                            data: { state: root[:open] ? "instant-open" : "closed", slot: "tooltip-trigger", controller: "shadcn--tooltip" }.merge(values(root))
                          }, @attrs)
      attrs[:aria] = (attrs[:aria] || {}).merge(describedby: describedby(attrs, root[:key])) if root[:open]
      return render_as_child(@as_child, **attrs, &) if @as_child

      button(**attrs, &)
    end

    private

    # Radix concatAriaDescribedby: caller ids first, deduplicated.
    def describedby(attrs, content_id)
      [ attrs.dig(:aria, :describedby), content_id ].reject_blank.flat_map { |ids| ids.to_s.split }.uniq.join(" ")
    end

    def values(root)
      {
        shadcn__tooltip_open_value: root[:open].to_s,
        shadcn__tooltip_controlled_value: root[:controlled].to_s,
        shadcn__tooltip_delay_duration_value: root[:delay_duration],
        shadcn__tooltip_skip_delay_duration_value: root[:skip_delay_duration],
        shadcn__tooltip_disable_hoverable_content_value: root[:disable_hoverable_content].to_s,
        shadcn__tooltip_provider_id_value: root[:provider_id],
        shadcn__tooltip_content_id_value: root[:key]
      }
    end
  end

  # Tooltip bubble (with arrow). Its markup ships in an inert `<template>` that the controller clones on open.
  # An `aria-label` attribute switches to a visually hidden `role=tooltip` span.
  #
  # @example Explicit form
  #   render Phlex::Shadcn::Tooltip::Content.new(side: "right") { "Tip" }
  # @example Yielded-root helper form
  #   tooltip.content(side: "right") { "Tip" }
  class Content < Phlex::Shadcn::Base
    # @api private
    CLASSES = "z-50 w-fit origin-(--radix-tooltip-content-transform-origin) animate-in rounded-md bg-foreground px-3 py-1.5 text-xs text-balance text-background fade-in-0 zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95"
    # @api private
    ARROW_CLASSES = "z-50 size-2.5 translate-y-[calc(-50%_-_2px)] rotate-45 rounded-[2px] bg-foreground fill-foreground"
    # @api private
    STYLE_VARS = {
      "--radix-tooltip-content-transform-origin" => "var(--radix-popper-transform-origin)",
      "--radix-tooltip-content-available-width" => "var(--radix-popper-available-width)",
      "--radix-tooltip-content-available-height" => "var(--radix-popper-available-height)",
      "--radix-tooltip-trigger-width" => "var(--radix-popper-anchor-width)",
      "--radix-tooltip-trigger-height" => "var(--radix-popper-anchor-height)"
    }.freeze
    # @api private
    ARROW_POLYGON = %(<polygon points="0,0 30,0 15,10"></polygon>)
    # @api private
    VISUALLY_HIDDEN = "position: absolute; border: 0px; width: 1px; height: 1px; padding: 0px; margin: -1px; overflow: hidden; clip: rect(0px, 0px, 0px, 0px); white-space: nowrap; overflow-wrap: normal;"

    # `force_mount:` is accepted for API parity only: shadcn does not force-mount the Radix Portal, which is the part
    # that keeps the content out of the DOM while closed, so the oracle never renders a closed content either.
    #
    # @param side [String, Symbol] preferred side: top, right, bottom or left (default top)
    # @param side_offset [Integer] distance from the anchor in px (default 0)
    # @param align [String, Symbol] start, center or end
    # @param align_offset [Integer] offset along the alignment axis in px
    # @param avoid_collisions [Boolean] flip/shift to stay in the viewport
    # @param collision_padding [Integer, Hash] padding from the collision boundary
    # @param collision_boundary [String, nil] CSS selector of the collision boundary
    # @param arrow_padding [Integer] padding between the arrow and the content edges
    # @param sticky [String, Symbol] partial or always
    # @param hide_when_detached [Boolean] hide when the anchor is fully hidden
    # @param update_position_strategy [String, Symbol] optimized or always
    # @param force_mount [Boolean] accepted for API parity only, it has no effect
    # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
    def initialize(side: "top", side_offset: 0, align: "center", align_offset: 0, avoid_collisions: true, collision_padding: 0,
                   collision_boundary: nil, arrow_padding: 0, sticky: "partial", hide_when_detached: false,
                   update_position_strategy: "optimized", force_mount: false, **attrs)
      @options = {
        side: side.to_s, sideOffset: side_offset, align: align.to_s, alignOffset: align_offset, avoidCollisions: avoid_collisions,
        collisionPadding: collision_padding, collisionBoundary: collision_boundary, arrowPadding: arrow_padding, sticky: sticky.to_s,
        hideWhenDetached: hide_when_detached, updatePositionStrategy: update_position_strategy.to_s
      }
      @attrs = attrs
      super()
    end

    # The markup is shipped in an inert <template>: Radix mounts the content (in a body portal) only while open.
    # The controller clones it on open. Deviation: docs/shadcn-port/deviations/tooltip.json.
    #
    # @yield the tooltip content
    # @return [void]
    # @raise [ArgumentError] when rendered outside Tooltip
    def view_template(&)
      root = context[CONTEXT_KEY] or raise ArgumentError, "`TooltipContent` must be used within `Tooltip`"
      attrs = canonical_attrs(@attrs)
      label = attrs.dig(:aria, :label)
      options = @options.merge(dir: attrs[:dir]).compact
      template(data: { shadcn__tooltip_template: root[:key], options: json(options) }) do
        div(**content_attrs(attrs, label)) do
          yield if block_given?
          arrow
          span(id: attrs[:id] || root[:key], role: "tooltip", style: VISUALLY_HIDDEN) { label } if label
        end
      end
    end

    private

    def content_attrs(attrs, label)
      defaults = { class: CLASSES, data: { slot: "tooltip-content" } }
      unless label
        defaults[:role] = "tooltip"
        defaults[:id] = attrs[:id] || context[CONTEXT_KEY][:key]
      end
      aria = attrs.fetch(:aria, {}).except(:label)
      merged = merge_attrs(defaults, attrs.except(:id, :style, :aria).merge(aria:))
      merged.delete(:aria) if merged[:aria].empty?
      merged[:style] = "#{[ STYLE_VARS.map { |name, value| "#{name}: #{value}" }, attrs[:style] ].flatten.compact.join('; ')};"
      merged
    end

    def arrow
      span(style: "position: absolute;") do
        svg(class: ARROW_CLASSES, width: 10, height: 5, viewBox: [ 0, 0, 30, 10 ].join(" "), preserveAspectRatio: "none",
            style: "display: block;") do
          raw(safe(ARROW_POLYGON))
        end
      end
    end
  end
end
