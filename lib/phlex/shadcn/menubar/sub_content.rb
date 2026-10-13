# frozen_string_literal: true

# Radix MenuSubContent. Mounted in place right after its SubTrigger, or in the Portal container when wrapped in
# Menubar::Portal. Side is not an option: it follows the root direction (right for ltr, left for rtl).
class Phlex::Shadcn::Menubar::SubContent < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  CLASSES = "z-50 min-w-[8rem] origin-(--radix-menubar-content-transform-origin) overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-lg data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"

  def initialize(side_offset: 0, align: "start", align_offset: 0, avoid_collisions: true, collision_padding: 0,
                 collision_boundary: nil, sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized",
                 arrow_padding: 0, loop: false, force_mount: false, as_child: false, **attrs)
    @options = position_options(side_offset:, align:, align_offset:, avoid_collisions:, collision_padding:, collision_boundary:,
                                sticky:, hide_when_detached:, update_position_strategy:, arrow_padding:, loop:)
    @force_mount = force_mount
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template
    root = root_context
    sub = context[Phlex::Shadcn::Menubar::SUB_KEY] or raise ArgumentError, "#{self.class.name} must be used within Menubar::Sub"
    portal = context[Phlex::Shadcn::Menubar::PORTAL_KEY]
    options = @options.merge(
      forceMount: @force_mount || portal&.dig(:force_mount) || false, portal: !portal.nil?, container: portal&.dig(:container)
    ).compact
    attrs = menu_content_attrs(classes: CLASSES, slot: "menubar-sub-content", id: sub[:content_id], labelledby: sub[:trigger_id],
                               dir: root[:dir])
    # A Portal reaches only its own SubContent: sub menus nested inside need a Portal of their own.
    context[Phlex::Shadcn::Menubar::PORTAL_KEY] = nil
    template(data: { v2__menubar_template: sub[:content_id], options: options.to_json }) do
      render_part(:div, @as_child, attrs) { yield if block_given? }
    end
  ensure
    context[Phlex::Shadcn::Menubar::PORTAL_KEY] = portal
  end
end
