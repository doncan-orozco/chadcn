# frozen_string_literal: true

# Radix MenuLabel: a non-interactive +div+ heading for a group of items.
#
# @example
#   menu.label(inset: true) { "My account" }
class Chadcn::DropdownMenu::Label < Chadcn::Base
  include Chadcn::DropdownMenu::Support

  # Default Tailwind classes of the label (merged with +class:+).
  #
  # @return [String]
  CLASSES = "px-2 py-1.5 text-sm font-medium data-[inset]:pl-8"

  # @param inset [Boolean, nil] +nil+ (default) omits +data-inset+; +true+/+false+ render +data-inset="true"+/+"false"+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that instead, receiving this part's attributes merged in (Radix Slot)
  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged
  def initialize(inset: nil, as_child: false, **attrs)
    @inset = inset
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the label content
  # @return [void]
  def view_template(&)
    attrs = merge_attrs({ class: CLASSES, data: { slot: "dropdown-menu-label", inset: inset_value(@inset) } }, @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end
