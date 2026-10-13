# frozen_string_literal: true

# shadcn SidebarInput: the shared Input with the sidebar sizing.
class Phlex::Shadcn::Sidebar::Input < Phlex::Shadcn::Base
  CLASSES = "h-8 w-full bg-background shadow-none"

  def initialize(type: nil, **attrs)
    @type = type
    @attrs = attrs
    super()
  end

  def view_template
    attrs = canonical_attrs(@attrs).except(:class)
    data = { slot: "sidebar-input", sidebar: "input" }.merge(attrs[:data] || {})
    render Phlex::Shadcn::Input.new(type: @type, class: cn(CLASSES, @attrs[:class]), **attrs.merge(data:))
  end
end
