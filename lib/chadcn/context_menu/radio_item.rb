# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn ContextMenuRadioItem: a +div+ with +role="menuitemradio"+ and a circle indicator. It is checked when the enclosing
# {RadioGroup}'s +value:+ equals its +value:+ (compared as strings); outside a RadioGroup it is never checked. Selecting it
# dispatches the cancelable +select+ and then +shadcn--context-menu:value-change+ (with +detail.value+, the item's +value:+ as a
# string), and closes the menu unless +select+ was prevented.
#
# @example
#   menu.radio_item(value: "pedro") { "Pedro Duarte" }
class Chadcn::ContextMenu::RadioItem < Chadcn::Base
  include Chadcn::ContextMenu::Support

  # @return [String] the default Tailwind classes (shadcn new-york-v4)
  CLASSES = "relative flex cursor-default items-center gap-2 rounded-sm py-1.5 pr-2 pl-8 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
  # @return [String] the classes of the indicator span
  INDICATOR_CLASSES = "pointer-events-none absolute left-2 flex size-3.5 items-center justify-center"

  # @param value [String, Symbol, Integer] the value reported on selection (required keyword; stored as a string in
  #   +data-shadcn--dropdown-menu-value+)
  # @param disabled [Boolean] +true+ renders +data-disabled+ and +aria-disabled="true"+ (default +false+)
  # @param text_value [String, nil] rendered as +data-text-value+ (typeahead text); omitted when +nil+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that element/component instead, with this part's attributes merged into it
  #   (Radix Slot)
  # @param attrs [Hash] HTML attributes for the element; +class+ is merged with the defaults through tailwind-merge, +data+ and
  #   +aria+ are deep-merged (the caller wins)
  # @raise [ArgumentError] at construction when +value:+ is missing ("missing keyword: :value")
  def initialize(value:, disabled: false, text_value: nil, as_child: false, **attrs)
    @value = value.to_s
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the label of the item
  # @return [void]
  def view_template(&)
    group = context[Chadcn::ContextMenu::RADIO_GROUP_KEY]
    checked = !group.nil? && !group[:value].nil? && group[:value].to_s == @value
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitemradio", class: CLASSES,
      aria: { checked: checked.to_s },
      data: { slot: "context-menu-radio-item", state: checked ? "checked" : "unchecked", shadcn__dropdown_menu_value: @value }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs)) do
      span(class: INDICATOR_CLASSES) do
        span(data: { state: "checked" }) { render Chadcn::Icon.new("circle", class: "size-2 fill-current") } if checked
      end
      yield if block_given?
    end
  end
end
