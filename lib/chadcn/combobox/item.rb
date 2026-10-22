# frozen_string_literal: true

# shadcn ComboboxItem: one option (`div`, `role="option"`) with a check mark while selected. `value:` is the item (a String or Hash
# of the root's `items:`); the controller reads its identity from `data-shadcn--combobox-*` markers.
#
# @example
#   render(Chadcn::Combobox::Item.new(value: "Next.js") { "Next.js" })
class Chadcn::Combobox::Item < Chadcn::Base
  include Chadcn::Combobox::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "relative flex w-full cursor-default items-center gap-2 rounded-sm py-1.5 pr-8 pl-2 text-sm outline-hidden select-none data-highlighted:bg-accent data-highlighted:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"

  # @param value [Object] the item (String or Hash); nil is the "null" item
  # @param disabled [Boolean] highlightable but not selectable
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(value: nil, disabled: false, **attrs)
    @value = value
    @disabled = disabled
    @attrs = attrs
    super()
  end

  # @yield the item content, rendered before the check mark
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&block)
    model = root_model
    selected = model.selected?(@value)
    div(**item_attrs(model, selected)) do
      block&.call
      render_indicator if selected
    end
  end

  private

  def item_attrs(model, selected)
    index = model.item_index
    model.item_index += 1
    data = { slot: "combobox-item", shadcn__combobox_part: "item", shadcn__combobox_key: model.form_value(@value) }
    data[:selected] = "" if selected
    aria = { selected: selected.to_s }
    if @disabled
      data[:disabled] = ""
      aria[:disabled] = "true"
    end
    merge_attrs({ role: "option", id: "#{model.id}-#{index}", class: CLASSES, data: data, aria: aria }, @attrs)
  end
end
