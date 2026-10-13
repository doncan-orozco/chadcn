# frozen_string_literal: true

# shadcn SidebarSeparator: the shared Separator with the sidebar colors.
class Phlex::Shadcn::Sidebar::Separator < Phlex::Shadcn::Base
  CLASSES = "mx-2 w-auto bg-sidebar-border"

  def initialize(orientation: "horizontal", decorative: true, as_child: false, **attrs)
    @orientation = orientation
    @decorative = decorative
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    attrs = canonical_attrs(@attrs).except(:class)
    data = { slot: "sidebar-separator", sidebar: "separator" }.merge(attrs[:data] || {})
    render(Phlex::Shadcn::Separator.new(orientation: @orientation, decorative: @decorative, as_child: @as_child,
                                        class: cn(CLASSES, @attrs[:class]), **attrs.merge(data:)), &)
  end
end
