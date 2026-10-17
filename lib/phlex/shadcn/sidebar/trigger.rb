# frozen_string_literal: true

# shadcn SidebarTrigger: a ghost icon Button that toggles the sidebar. The children are fixed (icon + sr-only label).
#
# Rendered inside a {Phlex::Shadcn::Sidebar::Provider}; also available as `sidebar.trigger` on the yielded sidebar.
#
# @see Phlex::Shadcn::Sidebar
# @see Phlex::Shadcn::Button
class Phlex::Shadcn::Sidebar::Trigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  # @param variant [String, Symbol] {Phlex::Shadcn::Button} variant (default: "ghost")
  # @param size [String, Symbol] {Phlex::Shadcn::Button} size (default: "icon")
  # @param attrs [Hash] attributes forwarded to the Button; `class:` is tailwind-merged over `size-7`, `data-action` runs before the toggle
  # @raise [ArgumentError] when `as_child:` is given, or on render without a {Phlex::Shadcn::Sidebar::Provider}
  def initialize(variant: "ghost", size: "icon", **attrs)
    # The Button Slot would receive two children (icon + label) and throw (slot:38-47).
    raise ArgumentError, "Sidebar::Trigger cannot take as_child; it renders two children" if attrs.key?(:as_child)

    @variant = variant
    @size = size
    @attrs = attrs
    super()
  end

  # Renders the toggle Button with the panel icon and the screen-reader label.
  #
  # @return [void]
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
