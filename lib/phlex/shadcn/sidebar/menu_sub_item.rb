# frozen_string_literal: true

# shadcn SidebarMenuSubItem.
#
# Rendered inside a {Phlex::Shadcn::Sidebar}; also available as `sidebar.menu_sub_item` on the yielded sidebar.
#
# @see Phlex::Shadcn::Sidebar
class Phlex::Shadcn::Sidebar::MenuSubItem < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  # Tailwind classes of the `li` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = "group/menu-sub-item relative"

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
    tag(:li, **part_attrs(CLASSES, data: { slot: "sidebar-menu-sub-item", sidebar: "menu-sub-item" }), &)
  end
end
