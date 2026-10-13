# frozen_string_literal: true

# shadcn SidebarContent.
class Phlex::Shadcn::Sidebar::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  CLASSES = "flex min-h-0 flex-1 flex-col gap-2 overflow-auto group-data-[collapsible=icon]:overflow-hidden"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    tag(:div, **part_attrs(CLASSES, data: { slot: "sidebar-content", sidebar: "content" }), &)
  end
end
