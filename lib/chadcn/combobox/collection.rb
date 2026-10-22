# frozen_string_literal: true

# shadcn ComboboxCollection: renders its block once per item of the enclosing {Combobox::Group} (its `items:`), or of the root. Renders
# no element (React passes `slot: "combobox-collection"`, Base UI drops it).
#
# @example
#   render(Chadcn::Combobox::Collection.new) { |item| render(Chadcn::Combobox::Item.new(value: item) { item }) }
class Chadcn::Combobox::Collection < Chadcn::Base
  include Chadcn::Combobox::Support

  # @yieldparam item [Object] each item
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&block)
    model = root_model
    group = context[Chadcn::Combobox::Group::CONTEXT_KEY]
    items = group ? group[:items] : model.items
    Array(items).each { |item| block&.call(item) }
  end
end
