# frozen_string_literal: true

using Chadcn::Values::Refinements

# A menu item with a checked state (+role="menuitemcheckbox"+). +checked:+ is controlled only, like Radix: the port never
# flips it, the controller dispatches +checked-change+ (+detail.checked+) and the server re-renders.
# Choosing it also dispatches the cancelable +select+ event and closes the menu unless that event is prevented.
#
# @example
#   bar.checkbox_item(checked: true) { "Show toolbar" }
class Chadcn::Menubar::CheckboxItem < Chadcn::Base
  include Chadcn::Menubar::Support

  # @return [String] default Tailwind classes; the +class:+ you pass is merged on top
  CLASSES = "relative flex cursor-default items-center gap-2 rounded-xs py-1.5 pr-2 pl-8 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
  # @return [String] Tailwind classes of the check indicator wrapper span
  INDICATOR_CLASSES = "pointer-events-none absolute left-2 flex size-3.5 items-center justify-center"

  # @param checked [Boolean, String, Symbol] +true+/truthy renders checked, +"indeterminate"+ (or the Symbol) renders
  #   indeterminate (+aria-checked="mixed"+), falsy renders unchecked. Default +false+
  # @param disabled [Boolean] renders +aria-disabled+ and +data-disabled+ so the item cannot be chosen. Default +false+
  # @param text_value [String, nil] text the typeahead matches against (+data-text-value+); defaults to the item's text. Default +nil+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String or a component instance
  #   renders that element carrying this part's attributes instead
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with {CLASSES} (yours wins Tailwind conflicts), +data+/+aria+ are deep merged
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

  # @yield the part's content
  # @return [void]
  def view_template(&)
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitemcheckbox", class: CLASSES,
      aria: { checked: { "checked" => "true", "unchecked" => "false", "indeterminate" => "mixed" }.fetch(@state) },
      data: { slot: "menubar-checkbox-item", state: @state }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs)) do
      span(class: INDICATOR_CLASSES) do
        # Radix ItemIndicator (Presence): mounted for checked and indeterminate.
        span(data: { state: @state }) { render Chadcn::Icon.new("check", class: "size-4") } unless @state == "unchecked"
      end
      yield if block_given?
    end
  end
end
