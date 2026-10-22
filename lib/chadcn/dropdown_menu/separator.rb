# frozen_string_literal: true

# Radix MenuSeparator: a +div role="separator"+ line between items.
#
# @example
#   menu.separator
class Chadcn::DropdownMenu::Separator < Chadcn::Base
  include Chadcn::DropdownMenu::Support

  # Default Tailwind classes of the separator (merged with +class:+).
  #
  # @return [String]
  CLASSES = "-mx-1 my-1 h-px bg-border"

  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that instead, receiving this part's attributes merged in (Radix Slot)
  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield optional content of the separator element
  # @return [void]
  def view_template(&)
    attrs = merge_attrs(
      { role: "separator", class: CLASSES, aria: { orientation: "horizontal" }, data: { slot: "dropdown-menu-separator" } }, @attrs
    )
    render_part(:div, @as_child, attrs, &)
  end
end
