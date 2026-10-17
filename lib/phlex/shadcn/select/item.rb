# frozen_string_literal: true

# Radix SelectItem + ItemIndicator + ItemText (as shadcn composes them). as_child is not offered: the React original
# renders two children, indicator and text. In the first pass of the root the item only registers itself.
#
# Renders a +div role="option"+ with a check indicator when its value is the selected one, and the block as its text.
# The hidden native +<option>+ text is also the block text, never +text_value:+ (which only feeds typeahead through
# +data-shadcn--select-text-value+).
#
# @example
#   select.item(value: "apple", text_value: "Apple") { "Apple" }
class Phlex::Shadcn::Select::Item < Phlex::Shadcn::Base
  include Phlex::Shadcn::Select::Support

  # @return [String] Tailwind classes of the option
  CLASSES = "relative flex w-full cursor-default items-center gap-2 rounded-sm py-1.5 pr-8 pl-2 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground *:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2"
  # @return [String] Tailwind classes of the indicator wrapper
  INDICATOR_CLASSES = "absolute right-2 flex size-3.5 items-center justify-center"

  # @param value [String, Symbol, Integer] value of the option (converted with +to_s+); required
  # @param disabled [Boolean] not selectable or focusable (+aria-disabled+, +data-disabled+, no +tabindex+)
  # @param text_value [String, nil] text used for typeahead (+data-shadcn--select-text-value+); defaults to the stripped text of the block
  # @param attrs [Hash] HTML attributes merged into the element (+class+ is merged with Tailwind conflict resolution, +data+/+aria+ deep-merged, caller wins)
  # @raise [ArgumentError] at construction when +value:+ is missing or +as_child:+ is passed (not supported, as in React)
  def initialize(value:, disabled: false, text_value: nil, **attrs)
    raise ArgumentError, "#{self.class.name} does not support as_child" if attrs.key?(:as_child)

    @value = value.to_s
    @disabled = disabled
    @text_value = text_value
    @attrs = attrs
    super()
  end

  # @yield the option's content (also shown in Value when selected)
  # @return [void]
  # @raise [ArgumentError] at render when used outside {Phlex::Shadcn::Select}
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
        shadcn__select_value: @value, shadcn__select_text_value: @text_value
      }
    }
  end

  def register(html)
    text = Nokogiri::HTML5.fragment(html).text
    select_state[:known] << { value: @value, disabled: @disabled, html:, text:, text_value: @text_value || text.strip }
  end
end
