# frozen_string_literal: true

# shadcn SidebarFooter.
class Phlex::Shadcn::Sidebar::Footer < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  CLASSES = "flex flex-col gap-2 p-2"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    tag(:div, **part_attrs(CLASSES, data: { slot: "sidebar-footer", sidebar: "footer" }), &)
  end
end
