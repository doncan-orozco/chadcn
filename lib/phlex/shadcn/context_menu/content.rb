# frozen_string_literal: true

# shadcn ContextMenuContent = Portal + Radix Content. +side+, +side_offset+ and +align+ are forced (+"right"+, +2+, +"start"+) and are not
# options: passing them raises. The markup ships in an inert +<template>+ that the controller clones into +<body>+ while the
# menu is open; the rendered element is +role="menu"+ with no id.
#
# @example
#   menu.content(class: "w-52") { menu.item { "Back" } }
class Phlex::Shadcn::ContextMenu::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  # @return [String] the default Tailwind classes (shadcn new-york-v4)
  CLASSES = "z-50 max-h-(--radix-context-menu-content-available-height) min-w-[8rem] origin-(--radix-context-menu-content-transform-origin) overflow-x-hidden overflow-y-auto rounded-md border bg-popover p-1 text-popover-foreground shadow-md data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"

  # Positioning options are serialized to the template's +data-options+ and are not validated here.
  #
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
  # @param force_mount [Boolean] forwarded as +forceMount+ (default +false+); the controller only honours it for sub menus, so
  #   it never keeps the root content mounted
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that element/component instead, with this part's attributes merged into it
  #   (Radix Slot)
  # @param attrs [Hash] HTML attributes for the menu element; +class+ is merged with the defaults, +data+ and +aria+ are
  #   deep-merged and a +style+ is inserted after the default outline and before the popper variables. +side+, +side_offset+ and +align+
  #   are rejected
  # @raise [ArgumentError] at construction when +attrs+ contains +side+, +side_offset+ or +align+ ("unknown keyword")
  def initialize(align_offset: 0, avoid_collisions: true, collision_padding: 0, collision_boundary: nil, sticky: "partial",
                 hide_when_detached: false, update_position_strategy: "optimized", arrow_padding: 0, loop: false,
                 force_mount: false, as_child: false, **attrs)
    forced = attrs.keys.map(&:to_sym) & %i[side side_offset align]
    raise ArgumentError, "unknown keyword#{'s' if forced.size > 1}: #{forced.map(&:inspect).join(', ')}" if forced.any?

    @options = position_options(side_offset: 2, align: "start", align_offset:, avoid_collisions:, collision_padding:, collision_boundary:,
                                sticky:, hide_when_detached:, update_position_strategy:, arrow_padding:, loop:)
               .merge(side: "right", forceMount: force_mount).compact
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the items of the menu
  # @return [void]
  # @raise [ArgumentError] when not rendered within a {Phlex::Shadcn::ContextMenu}
  def view_template
    root = root_context
    attrs = menu_content_attrs(classes: CLASSES, slot: "context-menu-content", id: nil, labelledby: nil, dir: root[:dir])
    template(data: { shadcn__dropdown_menu_template: root[:content_id], options: json(@options) }) do
      render_part(:div, @as_child, attrs) { yield if block_given? }
    end
  end
end
