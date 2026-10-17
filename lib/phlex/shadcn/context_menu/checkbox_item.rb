# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# shadcn ContextMenuCheckboxItem: a +div+ with +role="menuitemcheckbox"+ and a check indicator. +checked:+ is controlled only,
# like Radix: the port never flips it; selecting the item dispatches +shadcn--context-menu:checked-change+ on the item
# (with +detail.checked+, the requested value) and the server re-renders. Selecting also dispatches the cancelable
# +shadcn--context-menu:select+ and closes the menu unless that was prevented; +checked-change+ (not cancelable) fires even when
# +select+ was prevented.
#
# @example
#   menu.checkbox_item(checked: true) { "Show bookmarks" }
class Phlex::Shadcn::ContextMenu::CheckboxItem < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  # @return [String] the default Tailwind classes (shadcn new-york-v4)
  CLASSES = "relative flex cursor-default items-center gap-2 rounded-sm py-1.5 pr-2 pl-8 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
  # @return [String] the classes of the indicator span
  INDICATOR_CLASSES = "pointer-events-none absolute left-2 flex size-3.5 items-center justify-center"

  # @param checked [Boolean, String, Symbol] +"indeterminate"+ (or +:indeterminate+) renders the mixed state
  #   (+data-state="indeterminate"+, +aria-checked="mixed"+); any other truthy value is checked, falsy is unchecked (default +false+)
  # @param disabled [Boolean] +true+ renders +data-disabled+ and +aria-disabled="true"+ (default +false+)
  # @param text_value [String, nil] rendered as +data-text-value+ (typeahead text); omitted when +nil+
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that element/component instead, with this part's attributes merged into it
  #   (Radix Slot)
  # @param attrs [Hash] HTML attributes for the element; +class+ is merged with the defaults through tailwind-merge, +data+ and
  #   +aria+ are deep-merged (the caller wins)
  def initialize(checked: false, disabled: false, text_value: nil, as_child: false, **attrs)
    @state =
      if checked.to_s == "indeterminate"
        "indeterminate"
      else
        checked ? "checked" : "unchecked"
      end
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the label of the item
  # @return [void]
  def view_template(&)
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitemcheckbox", class: CLASSES,
      aria: { checked: { "checked" => "true", "unchecked" => "false", "indeterminate" => "mixed" }.fetch(@state) },
      data: { slot: "context-menu-checkbox-item", state: @state }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs)) do
      span(class: INDICATOR_CLASSES) do
        # Radix ItemIndicator (Presence): mounted for checked and indeterminate.
        span(data: { state: @state }) { render Phlex::Shadcn::Icon.new("check", class: "size-4") } unless @state == "unchecked"
      end
      yield if block_given?
    end
  end
end
