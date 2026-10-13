# frozen_string_literal: true

# shadcn SidebarTrigger: a ghost icon Button that toggles the sidebar. The children are fixed (icon + sr-only label).
class Phlex::Shadcn::Sidebar::Trigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  def initialize(variant: "ghost", size: "icon", **attrs)
    # The Button Slot would receive two children (icon + label) and throw (slot:38-47).
    raise ArgumentError, "Sidebar::Trigger cannot take as_child; it renders two children" if attrs.key?(:as_child)

    @variant = variant
    @size = size
    @attrs = attrs
    super()
  end

  def view_template
    Phlex::Shadcn::Sidebar.use_sidebar(self)
    attrs = with_toggle(canonical_attrs(@attrs).except(:class))
    attrs = attrs.merge(data: { sidebar: "trigger", slot: "sidebar-trigger" }.merge(attrs[:data]))
    render Phlex::Shadcn::Button.new(variant: @variant, size: @size, class: cn("size-7", @attrs[:class]), **attrs) do
      render Phlex::Shadcn::Icon.new("panel-left")
      span(class: "sr-only") { "Toggle Sidebar" }
    end
  end
end
