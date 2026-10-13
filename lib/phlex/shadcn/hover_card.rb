# frozen_string_literal: true

# shadcn HoverCard (Radix HoverCard). Spec: docs/shadcn-port/specs/hover-card.md. Behavior in controllers/v2/hover_card_controller.js.
# The root renders no element: it pushes its options into the Phlex render context for the parts inside.
class Phlex::Shadcn::HoverCard < Phlex::Shadcn::Base
  CONTEXT_KEY = :v2_hover_card_root
  SEQUENCE_KEY = :v2_hover_card_sequence

  # `open:` is controlled when not nil.
  def initialize(open: nil, default_open: false, open_delay: 700, close_delay: 300)
    @open = open
    @default_open = default_open
    @open_delay = open_delay
    @close_delay = close_delay
    super()
  end

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

  class Trigger < Phlex::Shadcn::Base
    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    def view_template(&)
      root = context[CONTEXT_KEY] or raise ArgumentError, "`HoverCardTrigger` must be used within `HoverCard`"
      attrs = merge_attrs({
                            data: { state: root[:open] ? "open" : "closed", slot: "hover-card-trigger", controller: "v2--hover-card" }.merge(values(root))
                          }, @attrs)
      return render_as_child(@as_child, **attrs, &) if @as_child

      a(**attrs, &)
    end

    private

    def values(root)
      {
        v2__hover_card_open_value: root[:open].to_s,
        v2__hover_card_controlled_value: root[:controlled].to_s,
        v2__hover_card_open_delay_value: root[:open_delay],
        v2__hover_card_close_delay_value: root[:close_delay],
        v2__hover_card_template_key_value: root[:key]
      }
    end
  end

  class Content < Phlex::Shadcn::Base
    CLASSES = "z-50 w-64 origin-(--radix-hover-card-content-transform-origin) rounded-md border bg-popover p-4 text-popover-foreground shadow-md outline-hidden data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
    STYLE_VARS = {
      "--radix-hover-card-content-transform-origin" => "var(--radix-popper-transform-origin)",
      "--radix-hover-card-content-available-width" => "var(--radix-popper-available-width)",
      "--radix-hover-card-content-available-height" => "var(--radix-popper-available-height)",
      "--radix-hover-card-trigger-width" => "var(--radix-popper-anchor-width)",
      "--radix-hover-card-trigger-height" => "var(--radix-popper-anchor-height)"
    }.freeze

    # `force_mount:` is accepted for API parity only: shadcn does not force-mount the Radix Portal, so the oracle
    # never renders a closed content either.
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
    def view_template(&)
      root = context[CONTEXT_KEY] or raise ArgumentError, "`HoverCardContent` must be used within `HoverCard`"
      attrs = canonical_attrs(@attrs)
      options = @options.merge(dir: attrs[:dir]).compact
      template(data: { v2__hover_card_template: root[:key], options: options.to_json }) do
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
