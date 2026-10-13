# frozen_string_literal: true

# Radix SelectItem + ItemIndicator + ItemText (as shadcn composes them). as_child is not offered: the React original
# renders two children, indicator and text. In the first pass of the root the item only registers itself.
class Phlex::Shadcn::Select::Item < Phlex::Shadcn::Base
  include Phlex::Shadcn::Select::Support

  CLASSES = "relative flex w-full cursor-default items-center gap-2 rounded-sm py-1.5 pr-8 pl-2 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground *:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2"
  INDICATOR_CLASSES = "absolute right-2 flex size-3.5 items-center justify-center"

  def initialize(value:, disabled: false, text_value: nil, **attrs)
    raise ArgumentError, "#{self.class.name} does not support as_child" if attrs.key?(:as_child)

    @value = value.to_s
    @disabled = disabled
    @text_value = text_value
    @attrs = attrs
    super()
  end

  def view_template(&block)
    return register(block ? capture(&block) : "") if collecting?

    selected = select_state[:value] == @value
    text_id = next_id("text")
    div(**merge_attrs(attributes(text_id, selected), @attrs)) do
      span(data: { slot: "select-item-indicator" }, class: INDICATOR_CLASSES) do
        indicator if selected
      end
      span(id: text_id, &block)
    end
  end

  private

  def attributes(text_id, selected)
    {
      role: "option", class: CLASSES, tabindex: (-1 unless @disabled),
      aria: { labelledby: text_id, selected: "false", disabled: (true if @disabled) },
      data: {
        slot: "select-item", state: selected ? "checked" : "unchecked", disabled: (@disabled ? "" : nil), radix_collection_item: "",
        v2__select_value: @value, v2__select_text_value: @text_value
      }
    }
  end

  def register(html)
    text = Nokogiri::HTML5.fragment(html).text
    select_state[:known] << { value: @value, disabled: @disabled, html:, text:, text_value: @text_value || text.strip }
  end
end
