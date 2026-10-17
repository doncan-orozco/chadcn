# frozen_string_literal: true

# Radix MenuRadioGroup: a +div role="group"+. Controlled only, like Radix: +value:+ decides which RadioItem is checked,
# +value-change+ (+detail.value+) reports the user choice and the caller re-renders.
#
# @example
#   menu.radio_group(value: @sort) do
#     menu.radio_item(value: "asc") { "Ascending" }
#     menu.radio_item(value: "desc") { "Descending" }
#   end
class Phlex::Shadcn::DropdownMenu::RadioGroup < Phlex::Shadcn::Base
  include Phlex::Shadcn::DropdownMenu::Support

  # @param value [String, Symbol, nil] value of the checked RadioItem (compared as strings); +nil+ (default) checks none
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that instead, receiving this part's attributes merged in (Radix Slot)
  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged
  def initialize(value: nil, as_child: false, **attrs)
    @value = value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the radio items
  # @return [void]
  def view_template(&)
    previous = context[Phlex::Shadcn::DropdownMenu::RADIO_GROUP_KEY]
    context[Phlex::Shadcn::DropdownMenu::RADIO_GROUP_KEY] = { value: @value }
    render_part(:div, @as_child, merge_attrs({ role: "group", data: { slot: "dropdown-menu-radio-group" } }, @attrs), &)
  ensure
    context[Phlex::Shadcn::DropdownMenu::RADIO_GROUP_KEY] = previous
  end
end
