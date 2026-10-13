# frozen_string_literal: true

# Controlled only, like Radix: value: decides which RadioItem is checked, value-change reports the user choice.
class Phlex::Shadcn::DropdownMenu::RadioGroup < Phlex::Shadcn::Base
  include Phlex::Shadcn::DropdownMenu::Support

  def initialize(value: nil, as_child: false, **attrs)
    @value = value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    previous = context[Phlex::Shadcn::DropdownMenu::RADIO_GROUP_KEY]
    context[Phlex::Shadcn::DropdownMenu::RADIO_GROUP_KEY] = { value: @value }
    render_part(:div, @as_child, merge_attrs({ role: "group", data: { slot: "dropdown-menu-radio-group" } }, @attrs), &)
  ensure
    context[Phlex::Shadcn::DropdownMenu::RADIO_GROUP_KEY] = previous
  end
end
