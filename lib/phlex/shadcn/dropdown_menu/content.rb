# frozen_string_literal: true

# shadcn DropdownMenuContent = Portal + Radix Content. Radix mounts it only while open, so the markup ships in an inert
# <template> (no data-slot, no box) that the controller clones into <body> (spec DOM order and what the server renders).
# The positioning keywords are serialized as-is into the template's +data-options+ JSON; the port does not validate them.
#
# @example
#   menu.content(side: "right", align: "start", loop: true) do
#     menu.item { "Profile" }
#   end
class Phlex::Shadcn::DropdownMenu::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::DropdownMenu::Support

  # Default Tailwind classes of the content element (merged with +class:+).
  #
  # @return [String]
  CLASSES = "z-50 max-h-(--radix-dropdown-menu-content-available-height) min-w-[8rem] origin-(--radix-dropdown-menu-content-transform-origin) overflow-x-hidden overflow-y-auto rounded-md border bg-popover p-1 text-popover-foreground shadow-md data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"

  # All keywords are Radix Popper/Menu content props, passed through to the controller options.
  #
  # @param side ["top", "right", "bottom", "left", Symbol] preferred side, default +"bottom"+ (converted with +to_s+)
  # @param side_offset [Integer] distance from the trigger in px, default +4+
  # @param align ["start", "center", "end", Symbol] default +"center"+
  # @param align_offset [Integer] default +0+
  # @param avoid_collisions [Boolean] default +true+
  # @param collision_padding [Integer] default +0+
  # @param collision_boundary [String, Array<String>, nil] default +nil+ (omitted from the options)
  # @param sticky ["partial", "always", Symbol] default +"partial"+
  # @param hide_when_detached [Boolean] default +false+
  # @param update_position_strategy ["optimized", "always", Symbol] default +"optimized"+
  # @param arrow_padding [Integer] default +0+
  # @param loop [Boolean] wrap keyboard navigation around the ends, default +false+
  # @param force_mount [Boolean] default +false+; serialized as +forceMount+ but without effect on this root Content (the
  #   controller only honors it on sub menus)
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that instead, receiving this part's attributes merged in (Radix Slot)
  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged; +style:+ is merged into the inline style that sets the popper CSS variables
  def initialize(side: "bottom", side_offset: 4, align: "center", align_offset: 0, avoid_collisions: true, collision_padding: 0,
                 collision_boundary: nil, sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized",
                 arrow_padding: 0, loop: false, force_mount: false, as_child: false, **attrs)
    @options = position_options(side_offset:, align:, align_offset:, avoid_collisions:, collision_padding:, collision_boundary:,
                                sticky:, hide_when_detached:, update_position_strategy:, arrow_padding:, loop:)
               .merge(side: side.to_s, forceMount: force_mount).compact
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the menu items
  # @raise [ArgumentError] when rendered outside a DropdownMenu
  # @return [void]
  def view_template
    root = root_context
    attrs = menu_content_attrs(classes: CLASSES, slot: "dropdown-menu-content", id: root[:content_id], labelledby: root[:trigger_id],
                               dir: root[:dir])
    template(data: { shadcn__dropdown_menu_template: root[:content_id], options: json(@options) }) do
      render_part(:div, @as_child, attrs) { yield if block_given? }
    end
  end
end
