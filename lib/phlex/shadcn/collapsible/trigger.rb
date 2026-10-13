# frozen_string_literal: true

# shadcn CollapsibleTrigger: a Radix button with no classes of its own.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::Collapsible::Trigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::Collapsible::Support

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    root = root_context
    attrs = trigger_attrs(root)
    @as_child ? render_as_child(@as_child, **attrs, &) : button(**attrs, &)
  end

  private

  def trigger_attrs(root)
    attrs = merge_attrs({
                          type: "button",
                          disabled: root[:disabled],
                          aria: { controls: (root[:content_id] if root[:open]), expanded: root[:open] },
                          data: { state: state_of(root), disabled: disabled_data(root), slot: "collapsible-trigger",
                                  shadcn__collapsible_target: "trigger" }
                        }, @attrs)
    # Radix composes the consumer onClick first, then the toggle: our action goes last.
    action = [ attrs.dig(:data, :action), "click->shadcn--collapsible#toggle" ].reject_blank.join(" ")
    attrs.merge(data: attrs[:data].merge(action:))
  end
end
