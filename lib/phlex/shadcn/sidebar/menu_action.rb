# frozen_string_literal: true

# shadcn SidebarMenuAction (no `type` attribute, like React).
#
# Rendered inside a {Phlex::Shadcn::Sidebar}; also available as `sidebar.menu_action` on the yielded sidebar.
#
# @see Phlex::Shadcn::Sidebar
class Phlex::Shadcn::Sidebar::MenuAction < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  # Tailwind classes of the `button` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = [
    "absolute top-1.5 right-1 flex aspect-square w-5 items-center justify-center rounded-md p-0 text-sidebar-foreground ring-sidebar-ring outline-hidden transition-transform peer-hover/menu-button:text-sidebar-accent-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:ring-2 [&>svg]:size-4 [&>svg]:shrink-0",
    "after:absolute after:-inset-2 md:after:hidden",
    "peer-data-[size=sm]/menu-button:top-1",
    "peer-data-[size=default]/menu-button:top-1.5",
    "peer-data-[size=lg]/menu-button:top-2.5",
    "group-data-[collapsible=icon]:hidden"
  ].freeze
  # Extra classes that reveal the action only while the menu item is hovered or focused (`show_on_hover: true`).
  #
  # @api private
  SHOW_ON_HOVER = "group-focus-within/menu-item:opacity-100 group-hover/menu-item:opacity-100 peer-data-[active=true]/menu-button:text-sidebar-accent-foreground data-[state=open]:opacity-100 md:opacity-0"

  # @param as_child [false, nil, Symbol, String, Phlex::Shadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param show_on_hover [Boolean] hide the action on desktop until the menu item is hovered or focused (default: false)
  # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
  #   are deep-merged (caller wins).
  def initialize(as_child: false, show_on_hover: false, **attrs)
    @as_child = as_child
    @show_on_hover = show_on_hover
    @attrs = attrs
    super()
  end

  # Renders the `button` (or the `as_child` child) and yields the block as its content.
  #
  # @yield the content of the element
  # @return [void]
  def view_template(&)
    render_part(:button, @as_child,
                part_attrs(cn(CLASSES, (SHOW_ON_HOVER if @show_on_hover)), data: { slot: "sidebar-menu-action", sidebar: "menu-action" }), &)
  end
end
