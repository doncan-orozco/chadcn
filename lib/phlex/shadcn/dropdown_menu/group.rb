# frozen_string_literal: true

# Radix MenuGroup: a +div role="group"+ that groups related items.
#
# @example
#   menu.group { menu.item { "Profile" } }
class Phlex::Shadcn::DropdownMenu::Group < Phlex::Shadcn::Base
  include Phlex::Shadcn::DropdownMenu::Support

  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that instead, receiving this part's attributes merged in (Radix Slot)
  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the grouped items
  # @return [void]
  def view_template(&)
    render_part(:div, @as_child, merge_attrs({ role: "group", data: { slot: "dropdown-menu-group" } }, @attrs), &)
  end
end
