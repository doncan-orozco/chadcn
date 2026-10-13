# frozen_string_literal: true

# Radix AccordionItem (a Collapsible root). Owns the trigger and content ids that relate its two children.
class Phlex::Shadcn::Accordion::Item < Phlex::Shadcn::Base
  include Phlex::Shadcn::Accordion::Support

  CLASSES = "border-b last:border-b-0"

  def initialize(value:, disabled: false, as_child: false, **attrs)
    @value = value.to_s
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

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
