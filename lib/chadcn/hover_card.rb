# frozen_string_literal: true

# shadcn HoverCard (Radix HoverCard). Spec: docs/shadcn-port/specs/hover-card.md. Behavior in controllers/chadcn/hover_card_controller.js.
# The root renders no element: it pushes its options into the Phlex render context for the parts inside.
#
# Root of the HoverCard family. Renders no element.
#
# @example Explicit form
#   render Chadcn::HoverCard.new do
#     render Chadcn::HoverCard::Trigger.new(href: "/u/1") { "@ada" }
#     render Chadcn::HoverCard::Content.new { "Profile" }
#   end
#
# @example Yielded-root helper form
#   render Chadcn::HoverCard.new do |card|
#     card.trigger(href: "/u/1") { "@ada" }
#     card.content { "Profile" }
#   end
#
# Generated helpers (each forwards `**attrs` and the block to the part): `trigger` and `content`.
#
# @!method trigger(**attrs, &block)
#   Same as `render HoverCard::Trigger.new(**attrs), &block`.
# @!method content(**attrs, &block)
#   Same as `render HoverCard::Content.new(**attrs), &block`.
class Chadcn::HoverCard < Chadcn::Base
  # @api private
  CONTEXT_KEY = :shadcn_hover_card_root
  # @api private
  SEQUENCE_KEY = :shadcn_hover_card_sequence

  # `open:` is controlled when not nil.
  #
  # @param open [Boolean, nil] controlled open state when not nil
  # @param default_open [Boolean] initial open state when uncontrolled
  # @param open_delay [Integer] ms before opening on hover (default 700)
  # @param close_delay [Integer] ms before closing after leaving (default 300)
  def initialize(open: nil, default_open: false, open_delay: 700, close_delay: 300)
    @open = open
    @default_open = default_open
    @open_delay = open_delay
    @close_delay = close_delay
    super()
  end

  # @yieldparam card [HoverCard] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    previous = context[CONTEXT_KEY]
    context[CONTEXT_KEY] = {
      key: "hover-card-content-#{next_sequence}",
      controlled: !@open.nil?,
      open: @open.nil? ? @default_open : @open,
      open_delay: @open_delay,
      close_delay: @close_delay
    }
    yield self if block_given?
  ensure
    context[CONTEXT_KEY] = previous
  end

  private

  def next_sequence
    context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1
  end

  # The link that opens the card on hover/focus (renders an `a` and hosts the controller).
  #
  # @example Explicit form
  #   render Chadcn::HoverCard::Trigger.new(href: "/u/1") { "@ada" }
  # @example Yielded-root helper form
  #   card.trigger(href: "/u/1") { "@ada" }
  class Trigger < Chadcn::Base
    # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
    # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # @yield the link content
    # @return [void]
    # @raise [ArgumentError] when rendered outside HoverCard
    def view_template(&)
      root = context[CONTEXT_KEY] or raise ArgumentError, "`HoverCardTrigger` must be used within `HoverCard`"
      attrs = merge_attrs({
                            data: { state: root[:open] ? "open" : "closed", slot: "hover-card-trigger", controller: "chadcn--hover-card" }.merge(values(root))
                          }, @attrs)
      return render_as_child(@as_child, **attrs, &) if @as_child

      a(**attrs, &)
    end

    private

    def values(root)
      {
        chadcn__hover_card_open_value: root[:open].to_s,
        chadcn__hover_card_controlled_value: root[:controlled].to_s,
        chadcn__hover_card_open_delay_value: root[:open_delay],
        chadcn__hover_card_close_delay_value: root[:close_delay],
        chadcn__hover_card_template_key_value: root[:key]
      }
    end
  end

  # Floating card. Its markup ships in an inert `<template>` that the controller clones on open.
  #
  # @example Explicit form
  #   render Chadcn::HoverCard::Content.new(side: "right") { "Profile" }
  # @example Yielded-root helper form
  #   card.content(side: "right") { "Profile" }
  class Content < Chadcn::Base
    # @api private
    CLASSES = "z-50 w-64 origin-(--radix-hover-card-content-transform-origin) rounded-md border bg-popover p-4 text-popover-foreground shadow-md outline-hidden data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
    # @api private
    STYLE_VARS = {
      "--radix-hover-card-content-transform-origin" => "var(--radix-popper-transform-origin)",
      "--radix-hover-card-content-available-width" => "var(--radix-popper-available-width)",
      "--radix-hover-card-content-available-height" => "var(--radix-popper-available-height)",
      "--radix-hover-card-trigger-width" => "var(--radix-popper-anchor-width)",
      "--radix-hover-card-trigger-height" => "var(--radix-popper-anchor-height)"
    }.freeze

    # `force_mount:` is accepted for API parity only: shadcn does not force-mount the Radix Portal, so the oracle
    # never renders a closed content either.
    #
    # @param side [String, Symbol] preferred side: top, right, bottom or left (default bottom)
    # @param side_offset [Integer] distance from the anchor in px (default 4)
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
    def initialize(side: "bottom", side_offset: 4, align: "center", align_offset: 0, avoid_collisions: true, collision_padding: 0,
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
    # The controller clones it on open. Deviation: docs/shadcn-port/deviations/hover-card.json.
    #
    # @yield the card body
    # @return [void]
    # @raise [ArgumentError] when rendered outside HoverCard
    def view_template(&)
      root = context[CONTEXT_KEY] or raise ArgumentError, "`HoverCardContent` must be used within `HoverCard`"
      attrs = canonical_attrs(@attrs)
      options = @options.merge(dir: attrs[:dir]).compact
      template(data: { chadcn__hover_card_template: root[:key], options: json(options) }) do
        div(**content_attrs(attrs), &)
      end
    end

    private

    def content_attrs(attrs)
      merged = merge_attrs({ class: CLASSES, data: { slot: "hover-card-content" } }, attrs.except(:style))
      merged[:style] = "#{[ STYLE_VARS.map { |name, value| "#{name}: #{value}" }, attrs[:style] ].flatten.compact.join('; ')};"
      merged
    end
  end
end
