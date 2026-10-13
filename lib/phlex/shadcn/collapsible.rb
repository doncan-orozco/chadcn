# frozen_string_literal: true

# shadcn Collapsible over Radix Collapsible. Spec: docs/shadcn-port/specs/collapsible.md.
# Behavior: controllers/shadcn/collapsible_controller.js.
class Phlex::Shadcn::Collapsible < Phlex::Shadcn::Base
  ROOT_KEY = :shadcn_collapsible_root
  SEQUENCE_KEY = :shadcn_collapsible_sequence

  # open: non-nil is controlled (user actions only dispatch open-change, the caller re-renders with the new value).
  def initialize(open: nil, default_open: false, disabled: false, as_child: false, **attrs)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template
    previous = context[ROOT_KEY]
    number = context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1
    content_id = "collapsible-#{number}-content"
    context[ROOT_KEY] = { open: @open, disabled: @disabled, content_id: }
    attrs = merge_attrs({ data: root_data(content_id) }, @attrs)
    content = proc { yield self if block_given? }
    @as_child ? render_as_child(@as_child, **attrs, &content) : div(**attrs, &content)
  ensure
    context[ROOT_KEY] = previous
  end

  private

  def root_data(content_id)
    {
      slot: "collapsible",
      state: @open ? "open" : "closed",
      disabled: (@disabled ? "" : nil),
      controller: "shadcn--collapsible",
      shadcn__collapsible_controlled_value: @controlled.to_s,
      shadcn__collapsible_disabled_value: @disabled.to_s,
      shadcn__collapsible_content_id_value: content_id
    }
  end
end
