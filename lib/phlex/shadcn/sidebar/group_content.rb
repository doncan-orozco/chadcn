# frozen_string_literal: true

# shadcn SidebarGroupContent.
class Phlex::Shadcn::Sidebar::GroupContent < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  CLASSES = "w-full text-sm"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    tag(:div, **part_attrs(CLASSES, data: { slot: "sidebar-group-content", sidebar: "group-content" }), &)
  end
end
