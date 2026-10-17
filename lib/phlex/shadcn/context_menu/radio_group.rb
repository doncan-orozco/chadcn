# frozen_string_literal: true

# shadcn ContextMenuRadioGroup: a +div+ with +role="group"+ that holds {RadioItem}s. Controlled only, like Radix: +value:+ decides
# which RadioItem is checked and +shadcn--context-menu:value-change+ (+detail.value+) reports the user's choice. Like {Group},
# a caller +class+ is emitted verbatim.
#
# @example
#   menu.radio_group(value: "pedro") do
#     menu.radio_item(value: "pedro") { "Pedro Duarte" }
#     menu.radio_item(value: "colm") { "Colm Tuite" }
#   end
class Phlex::Shadcn::ContextMenu::RadioGroup < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  # @param value [String, Symbol, Integer, nil] the value of the checked item; compared with each item's value as strings.
  #   +nil+ (default) checks none
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that element/component instead, with this part's attributes merged into it
  #   (Radix Slot)
  # @param attrs [Hash] HTML attributes for the element; +data+ and +aria+ are deep-merged (the caller wins)
  def initialize(value: nil, as_child: false, **attrs)
    @value = value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the RadioItems
  # @return [void]
  def view_template(&)
    previous = context[Phlex::Shadcn::ContextMenu::RADIO_GROUP_KEY]
    context[Phlex::Shadcn::ContextMenu::RADIO_GROUP_KEY] = { value: @value }
    attrs = verbatim_class(merge_attrs({ role: "group", data: { slot: "context-menu-radio-group" } }, @attrs), @attrs)
    render_part(:div, @as_child, attrs, &)
  ensure
    context[Phlex::Shadcn::ContextMenu::RADIO_GROUP_KEY] = previous
  end
end
