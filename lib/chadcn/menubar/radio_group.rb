# frozen_string_literal: true

# A group of {RadioItem}s (+role="group"+). Controlled only, like Radix: +value:+ decides which RadioItem is checked,
# +value-change+ (+detail.value+) reports the user's choice and the server re-renders.
#
# @example
#   bar.radio_group(value: "list") { bar.radio_item(value: "list") { "List" }; bar.radio_item(value: "grid") { "Grid" } }
class Chadcn::Menubar::RadioGroup < Chadcn::Base
  include Chadcn::Menubar::Support

  # @param value [String, Symbol, nil] the checked item's value (compared as a String); +nil+ checks none. Default +nil+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String or a component instance
  #   renders that element carrying this part's attributes instead
  # @param attrs [Hash] extra HTML attributes; +class+, +data+ and +aria+ are merged with the defaults
  def initialize(value: nil, as_child: false, **attrs)
    @value = value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the group's {RadioItem}s
  # @return [void]
  def view_template(&)
    previous = context[Chadcn::Menubar::RADIO_GROUP_KEY]
    context[Chadcn::Menubar::RADIO_GROUP_KEY] = { value: @value }
    render_part(:div, @as_child, merge_attrs({ role: "group", data: { slot: "menubar-radio-group" } }, @attrs), &)
  ensure
    context[Chadcn::Menubar::RADIO_GROUP_KEY] = previous
  end
end
