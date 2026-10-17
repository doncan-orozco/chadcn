# frozen_string_literal: true

# Radix MenuSubContent. Mounted in place right after its own template, or in the Portal container when wrapped in
# DropdownMenu::Portal. Side is not an option: it follows the root direction (right for ltr, left for rtl). Like Content,
# its markup ships in an inert <template> and the positioning keywords are serialized as-is, without validation.
#
# @example
#   menu.sub_content(side_offset: 2) { menu.item { "Export" } }
class Phlex::Shadcn::DropdownMenu::SubContent < Phlex::Shadcn::Base
  include Phlex::Shadcn::DropdownMenu::Support

  # Default Tailwind classes of the sub content element (merged with +class:+).
  #
  # @return [String]
  CLASSES = "z-50 min-w-[8rem] origin-(--radix-dropdown-menu-content-transform-origin) overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-lg data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"

  # @param side_offset [Integer] distance from the SubTrigger in px, default +0+
  # @param align ["start", "center", "end", Symbol] default +"start"+
  # @param align_offset [Integer] default +0+
  # @param avoid_collisions [Boolean] default +true+
  # @param collision_padding [Integer] default +0+
  # @param collision_boundary [String, Array<String>, nil] default +nil+ (omitted from the options)
  # @param sticky ["partial", "always", Symbol] default +"partial"+
  # @param hide_when_detached [Boolean] default +false+
  # @param update_position_strategy ["optimized", "always", Symbol] default +"optimized"+
  # @param arrow_padding [Integer] default +0+
  # @param loop [Boolean] wrap keyboard navigation around the ends, default +false+
  # @param force_mount [Boolean] default +false+; also forced by an enclosing Portal with +force_mount: true+
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that instead, receiving this part's attributes merged in (Radix Slot)
  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged; +style:+ is merged into the inline style that sets the popper CSS variables
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

  # @yield the sub menu items
  # @raise [ArgumentError] when rendered outside a DropdownMenu, or outside a DropdownMenu::Sub
  # @return [void]
  def view_template
    root = root_context
    sub = context[Phlex::Shadcn::DropdownMenu::SUB_KEY] or raise ArgumentError, "#{self.class.name} must be used within DropdownMenu::Sub"
    portal = context[Phlex::Shadcn::DropdownMenu::PORTAL_KEY]
    options = @options.merge(
      forceMount: @force_mount || portal&.dig(:force_mount) || false, portal: !portal.nil?, container: portal&.dig(:container)
    ).compact
    attrs = menu_content_attrs(classes: CLASSES, slot: "dropdown-menu-sub-content", id: sub[:content_id], labelledby: sub[:trigger_id],
                               dir: root[:dir])
    # A Portal reaches only its own SubContent: sub menus nested inside need a Portal of their own.
    context[Phlex::Shadcn::DropdownMenu::PORTAL_KEY] = nil
    template(data: { shadcn__dropdown_menu_template: sub[:content_id], options: json(options) }) do
      render_part(:div, @as_child, attrs) { yield if block_given? }
    end
  ensure
    context[Phlex::Shadcn::DropdownMenu::PORTAL_KEY] = portal
  end
end
