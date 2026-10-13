# frozen_string_literal: true

# shadcn SidebarMenuSubItem.
class Phlex::Shadcn::Sidebar::MenuSubItem < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  CLASSES = "group/menu-sub-item relative"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    tag(:li, **part_attrs(CLASSES, data: { slot: "sidebar-menu-sub-item", sidebar: "menu-sub-item" }), &)
  end
end
