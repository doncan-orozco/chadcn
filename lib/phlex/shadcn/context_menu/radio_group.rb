# frozen_string_literal: true

# Controlled only, like Radix: value: decides which RadioItem is checked, value-change reports the user choice.
class Phlex::Shadcn::ContextMenu::RadioGroup < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  def initialize(value: nil, as_child: false, **attrs)
    @value = value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    previous = context[Phlex::Shadcn::ContextMenu::RADIO_GROUP_KEY]
    context[Phlex::Shadcn::ContextMenu::RADIO_GROUP_KEY] = { value: @value }
    attrs = verbatim_class(merge_attrs({ role: "group", data: { slot: "context-menu-radio-group" } }, @attrs), @attrs)
    render_part(:div, @as_child, attrs, &)
  ensure
    context[Phlex::Shadcn::ContextMenu::RADIO_GROUP_KEY] = previous
  end
end
