# frozen_string_literal: true

# shadcn Popover (Radix Popover). Spec: docs/shadcn-port/specs/popover.md. Behavior in controllers/chadcn/popover_controller.js.
# The root renders no element: it pushes its options into the Phlex render context for the parts inside.
# Deviations (inert template, controller host): docs/shadcn-port/deviations/popover.json.
#
# Root of the Popover family. Renders no element: the first Trigger or Content inside hosts the Stimulus controller.
#
# @example Explicit form
#   render Chadcn::Popover.new do
#     render Chadcn::Popover::Trigger.new { "Open" }
#     render Chadcn::Popover::Content.new { "Body" }
#   end
#
# @example Yielded-root helper form
#   render Chadcn::Popover.new do |popover|
#     popover.trigger { "Open" }
#     popover.content { "Body" }
#   end
#
# Generated helpers (each forwards `**attrs` and the block to the part): `trigger`, `anchor`, `content`, `header`,
# `title` and `description`, e.g. `popover.header { popover.title { "T" } }`.
#
# @!method trigger(**attrs, &block)
#   Same as `render Popover::Trigger.new(**attrs), &block`.
# @!method anchor(**attrs, &block)
#   Same as `render Popover::Anchor.new(**attrs), &block`.
# @!method content(**attrs, &block)
#   Same as `render Popover::Content.new(**attrs), &block`.
# @!method header(**attrs, &block)
#   Same as `render Popover::Header.new(**attrs), &block`.
# @!method title(**attrs, &block)
#   Same as `render Popover::Title.new(**attrs), &block`.
# @!method description(**attrs, &block)
#   Same as `render Popover::Description.new(**attrs), &block`.
class Chadcn::Popover < Chadcn::Base
  # @api private
  CONTEXT_KEY = :shadcn_popover_root
  # @api private
  SEQUENCE_KEY = :shadcn_popover_sequence

  # `open:` is controlled when not nil.
  #
  # @param open [Boolean, nil] controlled open state when not nil
  # @param default_open [Boolean] initial open state when uncontrolled
  # @param modal [Boolean] modal popover (default false)
  # @param id [String, nil] id of the content (what the trigger controls) and the key of its template, anchor and triggers.
  #   Default `popover-N`, numbered per request with the engine, per render without it
  # @raise [ArgumentError] when id: is empty or contains whitespace, a double quote or a backslash
  def initialize(open: nil, default_open: false, modal: false, id: nil)
    @open = open
    @default_open = default_open
    @modal = modal
    @id = validated_id(id)
    super()
  end

  # @yieldparam popover [Popover] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    previous = context[CONTEXT_KEY]
    base = @id || "popover-#{next_sequence(SEQUENCE_KEY)}"
    context[CONTEXT_KEY] = {
      key: base, content_id: base, controlled: !@open.nil?, modal: @modal,
      open: @open.nil? ? @default_open : @open, host: false
    }
    yield self if block_given?
  ensure
    context[CONTEXT_KEY] = previous
  end

  # What the parts share: the root context and the single controller host.
  #
  # @api private
  module Support
    private

    def root_context
      context[Chadcn::Popover::CONTEXT_KEY] or raise ArgumentError, "#{self.class.name} must be used within Popover"
    end

    # The first of Trigger / Content rendered in the block hosts the controller and its values.
    def claim_host(root)
      return false if root[:host]

      root[:host] = true
    end

    def host_data(root)
      {
        controller: "chadcn--popover",
        chadcn__popover_open_value: root[:open].to_s,
        chadcn__popover_controlled_value: root[:controlled].to_s,
        chadcn__popover_modal_value: root[:modal].to_s,
        chadcn__popover_content_id_value: root[:content_id],
        chadcn__popover_template_key_value: root[:key]
      }
    end

    def render_part(tag_name, as_child, attrs, &)
      return render_as_child(as_child, **attrs, &) if as_child

      tag(tag_name, **attrs, &)
    end
  end

  # Toggles the popover (renders a `button`; the first Trigger/Content hosts the controller).
  #
  # @example Explicit form
  #   render Chadcn::Popover::Trigger.new { "Open" }
  # @example Yielded-root helper form
  #   popover.trigger { "Open" }
  class Trigger < Chadcn::Base
    include Chadcn::Popover::Support

    # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
    # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # @yield the button content
    # @return [void]
    # @raise [ArgumentError] when rendered outside Popover
    def view_template(&)
      root = root_context
      attrs = merge_attrs({
                            type: "button",
                            aria: { haspopup: "dialog", expanded: root[:open].to_s, controls: (root[:content_id] if root[:open]) },
                            data: { state: root[:open] ? "open" : "closed", slot: "popover-trigger" }.merge(host_data_for(root))
                          }, @attrs)
      render_part(:button, @as_child, attrs, &)
    end

    private

    def host_data_for(root)
      return { chadcn__popover_trigger: root[:key] } unless claim_host(root)

      host_data(root).merge(action: "click->chadcn--popover#toggle")
    end
  end

  # Optional positioning anchor (`div`) other than the Trigger.
  #
  # @example
  #   popover.anchor { "Anchor" }
  class Anchor < Chadcn::Base
    include Chadcn::Popover::Support

    # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
    # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # @yield the anchor content
    # @return [void]
    # @raise [ArgumentError] when rendered outside Popover
    def view_template(&)
      attrs = merge_attrs({ data: { slot: "popover-anchor", chadcn__popover_anchor: root_context[:key] } }, @attrs)
      render_part(:div, @as_child, attrs, &)
    end
  end

  # Floating panel of the popover. Its markup ships in an inert `<template>` that the controller mounts while open.
  #
  # @example Explicit form
  #   render Chadcn::Popover::Content.new(side: "top") { "Body" }
  # @example Yielded-root helper form
  #   popover.content(side: "top") { "Body" }
  class Content < Chadcn::Base
    include Chadcn::Popover::Support

    # @api private
    CLASSES = "z-50 w-72 origin-(--radix-popover-content-transform-origin) rounded-md border bg-popover p-4 text-popover-foreground shadow-md outline-hidden data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
    # @api private
    STYLE_VARS = {
      "--radix-popover-content-transform-origin" => "var(--radix-popper-transform-origin)",
      "--radix-popover-content-available-width" => "var(--radix-popper-available-width)",
      "--radix-popover-content-available-height" => "var(--radix-popper-available-height)",
      "--radix-popover-trigger-width" => "var(--radix-popper-anchor-width)",
      "--radix-popover-trigger-height" => "var(--radix-popper-anchor-height)"
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
    #
    # @yield the popover body
    # @return [void]
    # @raise [ArgumentError] when rendered outside Popover
    def view_template(&)
      root = root_context
      attrs = canonical_attrs(@attrs)
      host = claim_host(root) ? host_data(root) : {}
      template(data: { chadcn__popover_template: root[:key], options: json(@options.merge(dir: attrs[:dir]).compact) }.merge(host)) do
        div(**content_attrs(root, attrs), &)
      end
    end

    private

    def content_attrs(root, attrs)
      merged = merge_attrs({
                             id: root[:content_id], role: "dialog", tabindex: "-1", class: CLASSES, data: { slot: "popover-content",
                                                                                                            state: "open" }
                           }, attrs.except(:style))
      merged[:style] = "#{[ attrs[:style], STYLE_VARS.map { |name, value| "#{name}: #{value}" } ].flatten.compact.join('; ')};"
      merged
    end
  end

  # Popover header (`div`). Needs no root context.
  class Header < Chadcn::Base
    # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @yield the header content
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ class: "flex flex-col gap-1 text-sm", data: { slot: "popover-header" } }, @attrs), &)
    end
  end

  # Popover title (`div`). Needs no root context.
  class Title < Chadcn::Base
    # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @yield the title content
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ class: "font-medium", data: { slot: "popover-title" } }, @attrs), &)
    end
  end

  # Popover description (`p`). Needs no root context.
  class Description < Chadcn::Base
    # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @yield the description content
    # @return [void]
    def view_template(&)
      p(**merge_attrs({ class: "text-muted-foreground", data: { slot: "popover-description" } }, @attrs), &)
    end
  end
end
