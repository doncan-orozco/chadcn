# frozen_string_literal: true

using Chadcn::Values::Refinements

# A menu item that is one of a {RadioGroup} (+role="menuitemradio"+). It renders checked when its +value:+ equals the
# group's; outside a group it renders unchecked. Choosing it dispatches the cancelable +select+ event, then
# +value-change+ with its value (both on the item), and closes the menu unless +select+ was prevented.
#
# @example
#   bar.radio_item(value: "grid") { "Grid" }
class Chadcn::Menubar::RadioItem < Chadcn::Base
  include Chadcn::Menubar::Support

  # @return [String] default Tailwind classes; the +class:+ you pass is merged on top
  CLASSES = "relative flex cursor-default items-center gap-2 rounded-xs py-1.5 pr-2 pl-8 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
  # @return [String] Tailwind classes of the radio indicator wrapper span
  INDICATOR_CLASSES = "pointer-events-none absolute left-2 flex size-3.5 items-center justify-center"

  # @param value [String, Symbol] required; this item's value (stored as a String). Omitting it raises +ArgumentError+ at construction
  # @param disabled [Boolean] renders +aria-disabled+ and +data-disabled+ so the item cannot be chosen. Default +false+
  # @param text_value [String, nil] text the typeahead matches against (+data-text-value+); defaults to the item's text. Default +nil+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String or a component instance
  #   renders that element carrying this part's attributes instead
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with {CLASSES} (yours wins Tailwind conflicts), +data+/+aria+ are deep merged
  def initialize(value:, disabled: false, text_value: nil, as_child: false, **attrs)
    @value = value.to_s
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    group = context[Chadcn::Menubar::RADIO_GROUP_KEY]
    checked = !group.nil? && !group[:value].nil? && group[:value].to_s == @value
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitemradio", class: CLASSES,
      aria: { checked: checked.to_s },
      data: { slot: "menubar-radio-item", state: checked ? "checked" : "unchecked", chadcn__menubar_value: @value }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs)) do
      span(class: INDICATOR_CLASSES) do
        span(data: { state: "checked" }) { render Chadcn::Icon.new("circle", class: "size-2 fill-current") } if checked
      end
      yield if block_given?
    end
  end
end
