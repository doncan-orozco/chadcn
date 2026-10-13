# frozen_string_literal: true

# shadcn SidebarMenu.
class Phlex::Shadcn::Sidebar::Menu < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  CLASSES = "flex w-full min-w-0 flex-col gap-1"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    tag(:ul, **part_attrs(CLASSES, data: { slot: "sidebar-menu", sidebar: "menu" }), &)
  end
end
