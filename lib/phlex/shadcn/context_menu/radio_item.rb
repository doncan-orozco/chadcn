# frozen_string_literal: true

class Phlex::Shadcn::ContextMenu::RadioItem < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  CLASSES = "relative flex cursor-default items-center gap-2 rounded-sm py-1.5 pr-2 pl-8 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
  INDICATOR_CLASSES = "pointer-events-none absolute left-2 flex size-3.5 items-center justify-center"

  def initialize(value:, disabled: false, text_value: nil, as_child: false, **attrs)
    @value = value.to_s
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    group = context[Phlex::Shadcn::ContextMenu::RADIO_GROUP_KEY]
    checked = !group.nil? && !group[:value].nil? && group[:value].to_s == @value
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).deep_merge(
      role: "menuitemradio", class: CLASSES,
      aria: { checked: checked.to_s },
      data: { slot: "context-menu-radio-item", state: checked ? "checked" : "unchecked", v2__dropdown_menu_value: @value }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs)) do
      span(class: INDICATOR_CLASSES) do
        span(data: { state: "checked" }) { render Phlex::Shadcn::Icon.new("circle", class: "size-2 fill-current") } if checked
      end
      yield if block_given?
    end
  end
end
