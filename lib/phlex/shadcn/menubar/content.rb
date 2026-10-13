# frozen_string_literal: true

# shadcn MenubarContent = Portal + Radix Content. Radix mounts it only while open, so the markup ships in an inert
# <template> (no data-slot, no box) that the controller clones into <body> (spec DOM order and what the server renders).
class Phlex::Shadcn::Menubar::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  CLASSES = "z-50 min-w-[12rem] origin-(--radix-menubar-content-transform-origin) overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-md data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"

  def initialize(side: "bottom", side_offset: 8, align: "start", align_offset: -4, avoid_collisions: true, collision_padding: 0,
                 collision_boundary: nil, sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized",
                 arrow_padding: 0, loop: false, force_mount: false, as_child: false, **attrs)
    @options = position_options(side_offset:, align:, align_offset:, avoid_collisions:, collision_padding:, collision_boundary:,
                                sticky:, hide_when_detached:, update_position_strategy:, arrow_padding:, loop:)
               .merge(side: side.to_s, forceMount: force_mount).compact
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template
    root = root_context
    menu = menu_context
    attrs = menu_content_attrs(classes: CLASSES, slot: "menubar-content", id: menu[:content_id], labelledby: menu[:trigger_id],
                               dir: root[:dir])
    template(data: { v2__menubar_template: menu[:content_id], options: @options.to_json }) do
      render_part(:div, @as_child, attrs) { yield if block_given? }
    end
  end
end
