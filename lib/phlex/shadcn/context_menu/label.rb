# frozen_string_literal: true

# shadcn ContextMenuLabel: a +div+ that titles a group of items.
#
# @example
#   menu.label(inset: true) { "People" }
class Phlex::Shadcn::ContextMenu::Label < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  # @return [String] the default Tailwind classes (shadcn new-york-v4)
  CLASSES = "px-2 py-1.5 text-sm font-medium text-foreground data-[inset]:pl-8"

  # @param inset [Boolean, nil] rendered as +data-inset+ (+"true"+/+"false"+) when not +nil+; +true+ adds left padding
  #   (default +nil+: no attribute)
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that element/component instead, with this part's attributes merged into it
  #   (Radix Slot)
  # @param attrs [Hash] HTML attributes for the element; +class+ is merged with the defaults through tailwind-merge, +data+ and
  #   +aria+ are deep-merged (the caller wins)
  def initialize(inset: nil, as_child: false, **attrs)
    @inset = inset
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the text of the label
  # @return [void]
  def view_template(&)
    attrs = merge_attrs({ class: CLASSES, data: { slot: "context-menu-label", inset: inset_value(@inset) } }, @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end
