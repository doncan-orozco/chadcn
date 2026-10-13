# frozen_string_literal: true

# checked: is controlled only, like Radix: the port never flips it, it dispatches checked-change.
class Phlex::Shadcn::ContextMenu::CheckboxItem < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  CLASSES = "relative flex cursor-default items-center gap-2 rounded-sm py-1.5 pr-2 pl-8 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
  INDICATOR_CLASSES = "pointer-events-none absolute left-2 flex size-3.5 items-center justify-center"

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

  def view_template(&)
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).deep_merge(
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
