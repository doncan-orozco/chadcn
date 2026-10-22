# frozen_string_literal: true

# shadcn SidebarMenuItem.
#
# Rendered inside a {Chadcn::Sidebar}; also available as `sidebar.menu_item` on the yielded sidebar.
#
# @see Chadcn::Sidebar
class Chadcn::Sidebar::MenuItem < Chadcn::Base
  include Chadcn::Sidebar::Support

  # Tailwind classes of the `li` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = "group/menu-item relative"

  # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
  #   are deep-merged (caller wins).
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # Renders the `li` and yields the block as its content.
  #
  # @yield the content of the element
  # @return [void]
  def view_template(&)
    tag(:li, **part_attrs(CLASSES, data: { slot: "sidebar-menu-item", sidebar: "menu-item" }), &)
  end
end
