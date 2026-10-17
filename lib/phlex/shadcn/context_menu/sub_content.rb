# frozen_string_literal: true

# Radix MenuSubContent (+role="menu"+, labelled by its SubTrigger). Mounted in place right after its SubTrigger, or in the Portal
# container when wrapped in {Portal}. Its side is not an option: it follows the root direction (right for ltr, left for rtl).
#
# @example
#   menu.sub_content(class: "w-44") { menu.item { "Save page as..." } }
class Phlex::Shadcn::ContextMenu::SubContent < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  # @return [String] the default Tailwind classes (shadcn new-york-v4)
  CLASSES = "z-50 min-w-[8rem] origin-(--radix-context-menu-content-transform-origin) overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-lg data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"

  # Positioning options are serialized to the template's +data-options+ and are not validated here.
  #
  # @param side_offset [Numeric] default +0+
  # @param align [String, Symbol] Radix +"start"+ (default), +"center"+ or +"end"+
  # @param align_offset [Numeric] default +0+
  # @param avoid_collisions [Boolean] default +true+
  # @param collision_padding [Numeric] default +0+
  # @param collision_boundary [String, Array<String>, nil] CSS selector(s) the controller resolves to the boundary elements
  #   (default +nil+: omitted)
  # @param sticky [String, Symbol] Radix +"partial"+ (default) or +"always"+
  # @param hide_when_detached [Boolean] default +false+
  # @param update_position_strategy [String, Symbol] Radix +"optimized"+ (default) or +"always"+
  # @param arrow_padding [Numeric] default +0+
  # @param loop [Boolean] keyboard focus wraps around the items (default +false+)
  # @param force_mount [Boolean] forwarded as +forceMount+ (default +false+); a surrounding {Portal} with +force_mount: true+
  #   has the same effect
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that element/component instead, with this part's attributes merged into it
  #   (Radix Slot)
  # @param attrs [Hash] HTML attributes for the menu element; +class+ is merged with the defaults, +data+ and +aria+ are
  #   deep-merged and a +style+ is inserted after the default outline and before the popper variables
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

  # @yield the items of the sub menu
  # @return [void]
  # @raise [ArgumentError] when not rendered within a {Phlex::Shadcn::ContextMenu} and a {Sub}
  def view_template
    root = root_context
    sub = context[Phlex::Shadcn::ContextMenu::SUB_KEY] or raise ArgumentError, "#{self.class.name} must be used within ContextMenu::Sub"
    portal = context[Phlex::Shadcn::ContextMenu::PORTAL_KEY]
    options = @options.merge(
      forceMount: @force_mount || portal&.dig(:force_mount) || false, portal: !portal.nil?, container: portal&.dig(:container)
    ).compact
    attrs = menu_content_attrs(classes: CLASSES, slot: "context-menu-sub-content", id: sub[:content_id], labelledby: sub[:trigger_id],
                               dir: root[:dir])
    # A Portal reaches only its own SubContent: sub menus nested inside need a Portal of their own.
    context[Phlex::Shadcn::ContextMenu::PORTAL_KEY] = nil
    template(data: { shadcn__dropdown_menu_template: sub[:content_id], options: json(options) }) do
      render_part(:div, @as_child, attrs) { yield if block_given? }
    end
  ensure
    context[Phlex::Shadcn::ContextMenu::PORTAL_KEY] = portal
  end
end
