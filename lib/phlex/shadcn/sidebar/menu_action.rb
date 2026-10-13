# frozen_string_literal: true

# shadcn SidebarMenuAction (no `type` attribute, like React).
class Phlex::Shadcn::Sidebar::MenuAction < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  CLASSES = [
    "absolute top-1.5 right-1 flex aspect-square w-5 items-center justify-center rounded-md p-0 text-sidebar-foreground ring-sidebar-ring outline-hidden transition-transform peer-hover/menu-button:text-sidebar-accent-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:ring-2 [&>svg]:size-4 [&>svg]:shrink-0",
    "after:absolute after:-inset-2 md:after:hidden",
    "peer-data-[size=sm]/menu-button:top-1",
    "peer-data-[size=default]/menu-button:top-1.5",
    "peer-data-[size=lg]/menu-button:top-2.5",
    "group-data-[collapsible=icon]:hidden"
  ].freeze
  SHOW_ON_HOVER = "group-focus-within/menu-item:opacity-100 group-hover/menu-item:opacity-100 peer-data-[active=true]/menu-button:text-sidebar-accent-foreground data-[state=open]:opacity-100 md:opacity-0"

  def initialize(as_child: false, show_on_hover: false, **attrs)
    @as_child = as_child
    @show_on_hover = show_on_hover
    @attrs = attrs
    super()
  end

  def view_template(&)
    render_part(:button, @as_child,
                part_attrs(cn(CLASSES, (SHOW_ON_HOVER if @show_on_hover)), data: { slot: "sidebar-menu-action", sidebar: "menu-action" }), &)
  end
end
