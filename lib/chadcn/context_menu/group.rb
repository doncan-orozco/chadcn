# frozen_string_literal: true

# shadcn ContextMenuGroup: a +div+ with +role="group"+. Like Radix it has no default classes: a caller +class+ is emitted verbatim
# (no tailwind-merge).
#
# @example
#   menu.group { menu.item { "Copy" } }
class Chadcn::ContextMenu::Group < Chadcn::Base
  include Chadcn::ContextMenu::Support

  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that element/component instead, with this part's attributes merged into it
  #   (Radix Slot)
  # @param attrs [Hash] HTML attributes for the element; +data+ and +aria+ are deep-merged (the caller wins)
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the items of the group
  # @return [void]
  def view_template(&)
    attrs = verbatim_class(merge_attrs({ role: "group", data: { slot: "context-menu-group" } }, @attrs), @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end
