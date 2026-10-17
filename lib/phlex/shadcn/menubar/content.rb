# frozen_string_literal: true

# shadcn MenubarContent = Portal + Radix Content: the popup holding the items of one {Menu}. Radix mounts it only while
# open, so the markup ships in an inert +<template>+ (no data-slot, no box) that the controller clones into +<body>+
# while the menu is open. Must be rendered inside a {Menu} (raises +ArgumentError+ at render otherwise).
#
# Attributes you pass go on the content element inside the template, not on the template.
#
# @example
#   bar.content(side: "bottom", align: "start") { bar.item { "New" } }
class Phlex::Shadcn::Menubar::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  # @return [String] default Tailwind classes of the content element; the +class:+ you pass is merged on top
  CLASSES = "z-50 min-w-[12rem] origin-(--radix-menubar-content-transform-origin) overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-md data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"

  # Positioning options are serialised into the template's +data-options+ for the controller; values are not validated.
  #
  # @param side [String, Symbol] preferred side of the trigger (+top+, +right+, +bottom+, +left+). Default +"bottom"+
  # @param side_offset [Integer] distance in px from the trigger. Default +8+
  # @param align [String, Symbol] alignment against the trigger (+start+, +center+, +end+). Default +"start"+
  # @param align_offset [Integer] offset in px along the alignment axis. Default +-4+
  # @param avoid_collisions [Boolean] flip/shift to stay in the viewport. Default +true+
  # @param collision_padding [Integer, Hash] viewport padding for collision detection. Default +0+
  # @param collision_boundary [String, Array<String>, nil] CSS selector(s) of the collision boundary elements. Default +nil+
  # @param sticky [String, Symbol] +"partial"+ or +"always"+. Default +"partial"+
  # @param hide_when_detached [Boolean] hide when the trigger is fully hidden. Default +false+
  # @param update_position_strategy [String, Symbol] +"optimized"+ or +"always"+. Default +"optimized"+
  # @param arrow_padding [Integer] padding around the arrow. Default +0+
  # @param loop [Boolean] whether arrow-key navigation among the items wraps around. Default +false+
  # @param force_mount [Boolean] sent to the controller as +forceMount+. The controller ignores it for the root content (it is
  #   always unmounted when closed); it only applies to {SubContent}. Default +false+
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String or a component instance
  #   renders that element carrying this part's attributes instead
  # @param attrs [Hash] extra HTML attributes for the content element; +class+ is merged with {CLASSES}, +data+/+aria+ are deep merged, +style+ is
  #   placed before the Radix CSS variables (those win on a clash); a caller +id:+ replaces the generated id, so the {Trigger}'s
  #   +aria-controls+ (rendered while open) no longer points at the content
  # @raise [ArgumentError] at render, when not inside a {Phlex::Shadcn::Menubar} and a {Menu}
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

  # @yield the content's items
  # @return [void]
  def view_template
    root = root_context
    menu = menu_context
    attrs = menu_content_attrs(classes: CLASSES, slot: "menubar-content", id: menu[:content_id], labelledby: menu[:trigger_id],
                               dir: root[:dir])
    template(data: { shadcn__menubar_template: menu[:content_id], options: json(@options) }) do
      render_part(:div, @as_child, attrs) { yield if block_given? }
    end
  end
end
