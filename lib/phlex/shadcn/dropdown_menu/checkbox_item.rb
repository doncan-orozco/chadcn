# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# Radix MenuCheckboxItem: a +div role="menuitemcheckbox"+ with a check indicator. +checked:+ is controlled only, like
# Radix: the port never flips it, it dispatches +checked-change+ (+detail.checked+ is the requested value) and the caller
# re-renders. Activating it also dispatches +select+ and closes the menu unless +select+ is prevented.
#
# @example
#   menu.checkbox_item(checked: @show_status) { "Status bar" }
#   menu.checkbox_item(checked: "indeterminate") { "Partial" }
class Phlex::Shadcn::DropdownMenu::CheckboxItem < Phlex::Shadcn::Base
  include Phlex::Shadcn::DropdownMenu::Support

  # Default Tailwind classes of the item (merged with +class:+).
  #
  # @return [String]
  CLASSES = "relative flex cursor-default items-center gap-2 rounded-sm py-1.5 pr-2 pl-8 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
  # Tailwind classes of the indicator wrapper span.
  #
  # @return [String]
  INDICATOR_CLASSES = "pointer-events-none absolute left-2 flex size-3.5 items-center justify-center"

  # @param checked [Boolean, "indeterminate", Symbol] +"indeterminate"+ (or +:indeterminate+) renders the mixed state;
  #   any other truthy value renders checked, falsy renders unchecked. Default +false+.
  # @param disabled [Boolean] default +false+; renders +data-disabled+ and +aria-disabled+
  # @param text_value [String, nil] text used by typeahead, default +nil+
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that instead, receiving this part's attributes merged in (Radix Slot)
  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged
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

  # @yield the item content (rendered after the indicator)
  # @return [void]
  def view_template(&)
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitemcheckbox", class: CLASSES,
      aria: { checked: { "checked" => "true", "unchecked" => "false", "indeterminate" => "mixed" }.fetch(@state) },
      data: { slot: "dropdown-menu-checkbox-item", state: @state }
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
