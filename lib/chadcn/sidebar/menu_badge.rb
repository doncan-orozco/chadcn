# frozen_string_literal: true

# shadcn SidebarMenuBadge.
#
# Rendered inside a {Chadcn::Sidebar}; also available as `sidebar.menu_badge` on the yielded sidebar.
#
# @see Chadcn::Sidebar
class Chadcn::Sidebar::MenuBadge < Chadcn::Base
  include Chadcn::Sidebar::Support

  # Tailwind classes of the `div` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = [
    "pointer-events-none absolute right-1 flex h-5 min-w-5 items-center justify-center rounded-md px-1 text-xs font-medium text-sidebar-foreground tabular-nums select-none",
    "peer-hover/menu-button:text-sidebar-accent-foreground peer-data-[active=true]/menu-button:text-sidebar-accent-foreground",
    "peer-data-[size=sm]/menu-button:top-1",
    "peer-data-[size=default]/menu-button:top-1.5",
    "peer-data-[size=lg]/menu-button:top-2.5",
    "group-data-[collapsible=icon]:hidden"
  ].freeze

  # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
  #   are deep-merged (caller wins).
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # Renders the `div` and yields the block as its content.
  #
  # @yield the content of the element
  # @return [void]
  def view_template(&)
    div(**part_attrs(cn(CLASSES), data: { slot: "sidebar-menu-badge", sidebar: "menu-badge" }), &)
  end
end
