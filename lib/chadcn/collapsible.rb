# frozen_string_literal: true

# shadcn Collapsible over Radix Collapsible. Spec: docs/shadcn-port/specs/collapsible.md.
# Behavior: controllers/chadcn/collapsible_controller.js.
#
# Root of the collapsible. Yields itself, so `trigger` and `content` are yielded-root helpers equal to rendering
# `Collapsible::Trigger` and `Collapsible::Content`.
#
# @example
#   render Chadcn::Collapsible.new(default_open: false) do |c|
#     c.trigger { "Toggle" }
#     c.content { "Hidden body" }
#   end
class Chadcn::Collapsible < Chadcn::Base
  # @api private
  ROOT_KEY = :shadcn_collapsible_root
  # @api private
  SEQUENCE_KEY = :shadcn_collapsible_sequence

  # open: non-nil is controlled (user actions only dispatch open-change, the caller re-renders with the new value).
  #
  # @param open [Boolean, nil] non-nil makes the collapsible controlled
  # @param default_open [Boolean] initial state when uncontrolled
  # @param disabled [Boolean] disables the trigger
  # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param attrs [Hash] HTML attributes merged onto the root element
  def initialize(open: nil, default_open: false, disabled: false, as_child: false, **attrs)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yieldparam collapsible [Chadcn::Collapsible] the root, exposing the part helpers
  # @return [void]
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
      controller: "chadcn--collapsible",
      chadcn__collapsible_controlled_value: @controlled.to_s,
      chadcn__collapsible_disabled_value: @disabled.to_s,
      chadcn__collapsible_content_id_value: content_id
    }
  end
end
