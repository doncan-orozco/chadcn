# frozen_string_literal: true

# shadcn AccordionTrigger: Radix Header (h3) > Trigger (button) + chevron.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::Accordion::Trigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::Accordion::Support

  CLASSES = "flex flex-1 items-start justify-between gap-4 rounded-md py-4 text-left text-sm font-medium transition-all outline-none hover:underline focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 [&[data-state=open]>svg]:rotate-180"
  ICON_CLASSES = "pointer-events-none size-4 shrink-0 translate-y-0.5 text-muted-foreground transition-transform duration-200"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template
    item = item_context
    root = item[:root]
    state = state_of(item)
    h3(class: "flex", data: { orientation: root[:orientation], state:, disabled: disabled_data(item) }) do
      button(**button_attrs(item, root, state)) do
        yield if block_given?
        render Phlex::Shadcn::Icon.new("chevron-down", class: ICON_CLASSES)
      end
    end
  end

  private

  def button_attrs(item, root, state)
    attrs = merge_attrs({
                          type: "button",
                          id: item[:trigger_id],
                          class: CLASSES,
                          disabled: item[:disabled],
                          aria: { controls: (item[:content_id] if item[:open]), expanded: item[:open],
                                  disabled: ("true" if item[:open] && !root[:collapsible]) },
                          data: { state:, disabled: disabled_data(item), orientation: root[:orientation], slot: "accordion-trigger",
                                  shadcn__accordion_target: "trigger" }
                        }, @attrs)
    # Radix composes the consumer onClick first, then the toggle: our action goes last.
    action = [ attrs.dig(:data, :action), "click->shadcn--accordion#toggle" ].reject_blank.join(" ")
    attrs.merge(data: attrs[:data].merge(action:))
  end
end
