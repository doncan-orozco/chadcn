# frozen_string_literal: true

# shadcn Popover (Radix Popover). Spec: docs/shadcn-port/specs/popover.md. Behavior in controllers/v2/popover_controller.js.
# The root renders no element: it pushes its options into the Phlex render context for the parts inside.
# Deviations (inert template, controller host): docs/shadcn-port/deviations/popover.json.
class Phlex::Shadcn::Popover < Phlex::Shadcn::Base
  CONTEXT_KEY = :v2_popover_root
  SEQUENCE_KEY = :v2_popover_sequence

  # `open:` is controlled when not nil.
  def initialize(open: nil, default_open: false, modal: false)
    @open = open
    @default_open = default_open
    @modal = modal
    super()
  end

  def view_template
    previous = context[CONTEXT_KEY]
    base = "popover-#{context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1}"
    context[CONTEXT_KEY] = {
      key: base, content_id: "#{base}-content", controlled: !@open.nil?, modal: @modal,
      open: @open.nil? ? @default_open : @open, host: false
    }
    yield self if block_given?
  ensure
    context[CONTEXT_KEY] = previous
  end

  # What the parts share: the root context and the single controller host.
  module Support
    private

    def root_context
      context[Phlex::Shadcn::Popover::CONTEXT_KEY] or raise ArgumentError, "#{self.class.name} must be used within Popover"
    end

    # The first of Trigger / Content rendered in the block hosts the controller and its values.
    def claim_host(root)
      return false if root[:host]

      root[:host] = true
    end

    def host_data(root)
      {
        controller: "v2--popover",
        v2__popover_open_value: root[:open].to_s,
        v2__popover_controlled_value: root[:controlled].to_s,
        v2__popover_modal_value: root[:modal].to_s,
        v2__popover_content_id_value: root[:content_id],
        v2__popover_template_key_value: root[:key]
      }
    end

    def render_part(tag_name, as_child, attrs, &)
      return render_as_child(as_child, **attrs, &) if as_child

      tag(tag_name, **attrs, &)
    end
  end

  class Trigger < Phlex::Shadcn::Base
    include Phlex::Shadcn::Popover::Support

    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

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
      return { v2__popover_trigger: root[:key] } unless claim_host(root)

      host_data(root).merge(action: "click->v2--popover#toggle")
    end
  end

  class Anchor < Phlex::Shadcn::Base
    include Phlex::Shadcn::Popover::Support

    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    def view_template(&)
      attrs = merge_attrs({ data: { slot: "popover-anchor", v2__popover_anchor: root_context[:key] } }, @attrs)
      render_part(:div, @as_child, attrs, &)
    end
  end

  class Content < Phlex::Shadcn::Base
    include Phlex::Shadcn::Popover::Support

    CLASSES = "z-50 w-72 origin-(--radix-popover-content-transform-origin) rounded-md border bg-popover p-4 text-popover-foreground shadow-md outline-hidden data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
    STYLE_VARS = {
      "--radix-popover-content-transform-origin" => "var(--radix-popper-transform-origin)",
      "--radix-popover-content-available-width" => "var(--radix-popper-available-width)",
      "--radix-popover-content-available-height" => "var(--radix-popper-available-height)",
      "--radix-popover-trigger-width" => "var(--radix-popper-anchor-width)",
      "--radix-popover-trigger-height" => "var(--radix-popper-anchor-height)"
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
    def view_template(&)
      root = root_context
      attrs = canonical_attrs(@attrs)
      host = claim_host(root) ? host_data(root) : {}
      template(data: { v2__popover_template: root[:key], options: @options.merge(dir: attrs[:dir]).compact.to_json }.merge(host)) do
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

  class Header < Phlex::Shadcn::Base
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ class: "flex flex-col gap-1 text-sm", data: { slot: "popover-header" } }, @attrs), &)
    end
  end

  class Title < Phlex::Shadcn::Base
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ class: "font-medium", data: { slot: "popover-title" } }, @attrs), &)
    end
  end

  class Description < Phlex::Shadcn::Base
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      p(**merge_attrs({ class: "text-muted-foreground", data: { slot: "popover-description" } }, @attrs), &)
    end
  end
end
