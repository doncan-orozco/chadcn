# frozen_string_literal: true

# Radix MenuSubContent: the popup of a {Sub}. Mounted in place right after its own template, or in the {Portal} container when
# wrapped in a Portal. Like {Content} it ships in an inert +<template>+. Side is not an option: it follows the root direction
# (right for ltr, left for rtl). Must be rendered inside a {Sub} (raises +ArgumentError+ at render otherwise).
#
# @example
#   bar.sub_content { bar.item { "Email" } }
class Chadcn::Menubar::SubContent < Chadcn::Base
  include Chadcn::Menubar::Support

  # @return [String] default Tailwind classes of the content element; the +class:+ you pass is merged on top
  CLASSES = "z-50 min-w-[8rem] origin-(--radix-menubar-content-transform-origin) overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-lg data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"

  # Positioning options are serialised into the template's +data-options+ for the controller; values are not validated.
  #
  # @param side_offset [Integer] distance in px from the trigger. Default +0+
  # @param align [String, Symbol] alignment (+start+, +center+, +end+). Default +"start"+
  # @param align_offset [Integer] offset in px along the alignment axis. Default +0+
  # @param avoid_collisions [Boolean] flip/shift to stay in the viewport. Default +true+
  # @param collision_padding [Integer, Hash] viewport padding for collision detection. Default +0+
  # @param collision_boundary [String, Array<String>, nil] CSS selector(s) of the collision boundary elements. Default +nil+
  # @param sticky [String, Symbol] +"partial"+ or +"always"+. Default +"partial"+
  # @param hide_when_detached [Boolean] hide when the trigger is fully hidden. Default +false+
  # @param update_position_strategy [String, Symbol] +"optimized"+ or +"always"+. Default +"optimized"+
  # @param arrow_padding [Integer] padding around the arrow. Default +0+
  # @param loop [Boolean] whether arrow-key navigation among the items wraps around. Default +false+
  # @param force_mount [Boolean] keep the content mounted while closed (also enabled by a force-mounted {Portal}). Default +false+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String or a component instance
  #   renders that element carrying this part's attributes instead
  # @param attrs [Hash] extra HTML attributes for the content element; +class+ is merged with {CLASSES}, +data+/+aria+ are deep merged, +style+ is
  #   placed before the Radix CSS variables (those win on a clash); a caller +id:+ replaces the generated id, so the {SubTrigger}'s
  #   +aria-controls+ (rendered while open) no longer points at the content
  # @raise [ArgumentError] at render, when not inside a {Chadcn::Menubar} and a {Sub}
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

  # @yield the content's items
  # @return [void]
  def view_template
    root = root_context
    sub = context[Chadcn::Menubar::SUB_KEY] or raise ArgumentError, "#{self.class.name} must be used within Menubar::Sub"
    portal = context[Chadcn::Menubar::PORTAL_KEY]
    options = @options.merge(
      forceMount: @force_mount || portal&.dig(:force_mount) || false, portal: !portal.nil?, container: portal&.dig(:container)
    ).compact
    attrs = menu_content_attrs(classes: CLASSES, slot: "menubar-sub-content", id: sub[:content_id], labelledby: sub[:trigger_id],
                               dir: root[:dir])
    # A Portal reaches only its own SubContent: sub menus nested inside need a Portal of their own.
    context[Chadcn::Menubar::PORTAL_KEY] = nil
    template(data: { chadcn__menubar_template: sub[:content_id], options: json(options) }) do
      render_part(:div, @as_child, attrs) { yield if block_given? }
    end
  ensure
    context[Chadcn::Menubar::PORTAL_KEY] = portal
  end
end
