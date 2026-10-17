# frozen_string_literal: true

# Radix AccordionItem (a Collapsible root). Owns the trigger and content ids that relate its two children.
#
# @example
#   acc.item(value: "a", disabled: false) do
#     acc.trigger { "Title" }
#     acc.content { "Body" }
#   end
class Phlex::Shadcn::Accordion::Item < Phlex::Shadcn::Base
  include Phlex::Shadcn::Accordion::Support

  # Default Tailwind classes of the item element.
  #
  # @api private
  CLASSES = "border-b last:border-b-0"

  # @param value [String, Symbol] identifies the item; matched against the root `value`/`default_value`
  # @param disabled [Boolean] disables this item
  # @param as_child [false, nil, Symbol, String, Phlex::Shadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param attrs [Hash] HTML attributes merged onto the item element
  def initialize(value:, disabled: false, as_child: false, **attrs)
    @value = value.to_s
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the content of the element
  # @return [void]
  def view_template
    root = root_context
    previous = context[Phlex::Shadcn::Accordion::ITEM_KEY]
    item = build_item(root)
    context[Phlex::Shadcn::Accordion::ITEM_KEY] = item
    attrs = merge_attrs({
                          class: CLASSES,
                          data: { state: state_of(item), disabled: disabled_data(item), orientation: root[:orientation], slot: "accordion-item",
                                  shadcn__accordion_target: "item", shadcn__accordion_item_value: @value }
                        }, @attrs)
    content = proc { yield if block_given? }
    @as_child ? render_as_child(@as_child, **attrs, &content) : div(**attrs, &content)
  ensure
    context[Phlex::Shadcn::Accordion::ITEM_KEY] = previous
  end

  private

  def build_item(root)
    number = context[Phlex::Shadcn::Accordion::SEQUENCE_KEY] = context.fetch(Phlex::Shadcn::Accordion::SEQUENCE_KEY, 0) + 1
    {
      open: root[:open_values].include?(@value), disabled: root[:disabled] || @disabled, root:,
      trigger_id: "accordion-#{number}-trigger", content_id: "accordion-#{number}-content"
    }
  end
end
