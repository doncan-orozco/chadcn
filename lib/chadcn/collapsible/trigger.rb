# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn CollapsibleTrigger: a Radix button with no classes of its own.
#
# @example
#   c.trigger { "Toggle" }
class Chadcn::Collapsible::Trigger < Chadcn::Base
  include Chadcn::Collapsible::Support

  # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param attrs [Hash] HTML attributes merged onto the trigger (a `data-action` is kept ahead of the toggle action)
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the content of the element
  # @return [void]
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
