# frozen_string_literal: true

# shadcn ComboboxList: the listbox. With `items:` on the root the block is called once per root item (a group when the items are
# groups) and the controller filters the rendered nodes; without them the block renders the items once.
#
# @example
#   render(Phlex::Shadcn::Combobox::List.new) { |item| render(Phlex::Shadcn::Combobox::Item.new(value: item) { item }) }
class Phlex::Shadcn::Combobox::List < Phlex::Shadcn::Base
  include Phlex::Shadcn::Combobox::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "max-h-[min(calc(--spacing(96)---spacing(9)),calc(var(--available-height)---spacing(9)))] scroll-py-1 overflow-y-auto p-1 data-empty:p-0"

  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yieldparam item [Object] each root item (String, Hash or group)
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&block)
    model = root_model
    model.item_index = 0
    div(**list_attrs(model)) do
      if model.items?
        model.items.each { |item| block&.call(item) }
      else
        block&.call
      end
      template(data: { shadcn__combobox_part: "indicator-template" }) { render_indicator }
    end
  end

  private

  def list_attrs(model)
    defaults = { role: "listbox", tabindex: "-1", id: model.list_id, class: CLASSES,
                 data: { slot: "combobox-list", shadcn__combobox_part: "list" },
                 aria: { multiselectable: (model.multiple? ? "true" : nil), readonly: (model.read_only? ? "true" : nil) } }
    defaults[:data] = defaults[:data].merge(empty: "") if list_empty?(model)
    merge_attrs(defaults, @attrs)
  end
end
