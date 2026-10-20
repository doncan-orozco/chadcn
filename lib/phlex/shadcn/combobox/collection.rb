# frozen_string_literal: true

# shadcn ComboboxCollection: renders its block once per item of the enclosing {Combobox::Group} (its `items:`), or of the root. Renders
# no element (React passes `slot: "combobox-collection"`, Base UI drops it).
#
# @example
#   render(Phlex::Shadcn::Combobox::Collection.new) { |item| render(Phlex::Shadcn::Combobox::Item.new(value: item) { item }) }
class Phlex::Shadcn::Combobox::Collection < Phlex::Shadcn::Base
  include Phlex::Shadcn::Combobox::Support

  # @yieldparam item [Object] each item
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&block)
    model = root_model
    group = context[Phlex::Shadcn::Combobox::Group::CONTEXT_KEY]
    items = group ? group[:items] : model.items
    Array(items).each { |item| block&.call(item) }
  end
end
