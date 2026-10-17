# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# Radix MenuRadioItem: a +div role="menuitemradio"+ with a circle indicator, checked when its +value+ equals the enclosing
# RadioGroup value (compared as strings; outside a RadioGroup it is never checked). Activating it dispatches +select+ and
# +value-change+ and closes the menu unless +select+ is prevented.
#
# @example
#   menu.radio_item(value: "asc") { "Ascending" }
class Phlex::Shadcn::DropdownMenu::RadioItem < Phlex::Shadcn::Base
  include Phlex::Shadcn::DropdownMenu::Support

  # Default Tailwind classes of the item (merged with +class:+).
  #
  # @return [String]
  CLASSES = "relative flex cursor-default items-center gap-2 rounded-sm py-1.5 pr-2 pl-8 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
  # Tailwind classes of the indicator wrapper span.
  #
  # @return [String]
  INDICATOR_CLASSES = "pointer-events-none absolute left-2 flex size-3.5 items-center justify-center"

  # @param value [String, Symbol] required (omitting it raises ArgumentError at construction); stored with +to_s+
  # @param disabled [Boolean] default +false+; renders +data-disabled+ and +aria-disabled+
  # @param text_value [String, nil] text used by typeahead, default +nil+
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that instead, receiving this part's attributes merged in (Radix Slot)
  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged
  def initialize(value:, disabled: false, text_value: nil, as_child: false, **attrs)
    @value = value.to_s
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the item content (rendered after the indicator)
  # @return [void]
  def view_template(&)
    group = context[Phlex::Shadcn::DropdownMenu::RADIO_GROUP_KEY]
    checked = !group.nil? && !group[:value].nil? && group[:value].to_s == @value
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitemradio", class: CLASSES,
      aria: { checked: checked.to_s },
      data: { slot: "dropdown-menu-radio-item", state: checked ? "checked" : "unchecked", shadcn__dropdown_menu_value: @value }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs)) do
      span(class: INDICATOR_CLASSES) do
        span(data: { state: "checked" }) { render Phlex::Shadcn::Icon.new("circle", class: "size-2 fill-current") } if checked
      end
      yield if block_given?
    end
  end
end
