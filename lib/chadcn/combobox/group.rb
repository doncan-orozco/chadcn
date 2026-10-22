# frozen_string_literal: true

# shadcn ComboboxGroup: a labelled set of items (`div`, `role="group"`). With `items:` (the group's items) a nested
# {Combobox::Collection} renders them.
#
# @example
#   render(Chadcn::Combobox::Group.new(items: group_items)) do
#     render(Chadcn::Combobox::Label.new { "Europe" })
#     render(Chadcn::Combobox::Collection.new) { |item| render(Chadcn::Combobox::Item.new(value: item) { item }) }
#   end
class Chadcn::Combobox::Group < Chadcn::Base
  include Chadcn::Combobox::Support

  # @api private
  CONTEXT_KEY = :shadcn_combobox_group

  # @param items [Array, nil] the items of the group, read by a nested {Combobox::Collection}
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(items: nil, **attrs)
    @items = items
    @attrs = attrs
    super()
  end

  # @yield the label, the items and separators of the group
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&)
    model = root_model
    previous = context[CONTEXT_KEY]
    group = context[CONTEXT_KEY] = { items: @items, label_id: "#{model.id}-group-label-#{model.next_counter}" }
    attrs = merge_attrs({ role: "group", aria: { labelledby: group[:label_id] },
                          data: { slot: "combobox-group", shadcn__combobox_part: "group" } }, @attrs)
    div(**attrs, &)
  ensure
    context[CONTEXT_KEY] = previous
  end
end
