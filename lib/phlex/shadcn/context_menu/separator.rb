# frozen_string_literal: true

# shadcn ContextMenuSeparator: a +div+ with +role="separator"+ and horizontal orientation.
#
# @example
#   menu.separator
class Phlex::Shadcn::ContextMenu::Separator < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  # @return [String] the default Tailwind classes (shadcn new-york-v4)
  CLASSES = "-mx-1 my-1 h-px bg-border"

  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that element/component instead, with this part's attributes merged into it
  #   (Radix Slot)
  # @param attrs [Hash] HTML attributes for the element; +class+ is merged with the defaults through tailwind-merge, +data+ and
  #   +aria+ are deep-merged (the caller wins)
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield optional content of the separator
  # @return [void]
  def view_template(&)
    attrs = merge_attrs(
      { role: "separator", class: CLASSES, aria: { orientation: "horizontal" }, data: { slot: "context-menu-separator" } }, @attrs
    )
    render_part(:div, @as_child, attrs, &)
  end
end
