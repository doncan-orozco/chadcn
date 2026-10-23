# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn Accordion over Radix Accordion. Spec: docs/shadcn-port/specs/accordion.md.
# Behavior: controllers/chadcn/accordion_controller.js.
#
# Root of the accordion. Yields itself, so the parts are available as yielded-root helpers
# (`item`, `trigger`, `content`) equal to rendering `Accordion::Item`, `Accordion::Trigger` and `Accordion::Content`.
#
# @example
#   render Chadcn::Accordion.new(type: "single", collapsible: true, default_value: "a") do |acc|
#     acc.item(value: "a") do
#       acc.trigger { "Is it accessible?" }
#       acc.content { "Yes." }
#     end
#   end
class Chadcn::Accordion < Chadcn::Base
  include Chadcn::Direction::Consumer

  # @api private
  ROOT_KEY = :shadcn_accordion_root
  # @api private
  ITEM_KEY = :shadcn_accordion_item
  # @api private
  SEQUENCE_KEY = :shadcn_accordion_sequence

  # value: non-nil is controlled (user actions only dispatch value-change, the caller re-renders with the new value).
  # single: String ("" = none open); multiple: Array of Strings.
  #
  # @param type [String, Symbol] `"single"` or `"multiple"` (anything else is `"single"`)
  # @param value [String, Array<String>, nil] open item value(s); non-nil makes the accordion controlled
  # @param default_value [String, Array<String>, nil] initially open item value(s) when uncontrolled
  # @param collapsible [Boolean] whether the open item of a `"single"` accordion can be closed (always true for `"multiple"`)
  # @param disabled [Boolean] disables every item
  # @param dir [String, Symbol, nil] reading direction (`"ltr"`/`"rtl"`); falls back to the Direction provider
  # @param orientation [String, Symbol] `"vertical"` or `"horizontal"`
  # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param id [String, nil] id of the root element, as in React, and the base of the generated ids (`"faq-item-1-trigger"`).
  #   Without it the element has no id and the base is `accordion-N`, numbered per request with the engine, per render without it
  # @param attrs [Hash] HTML attributes merged onto the root element
  def initialize(type: "single", value: nil, default_value: nil, collapsible: false, disabled: false, dir: nil,
                 orientation: "vertical", as_child: false, id: nil, **attrs)
    @type = type.to_s == "multiple" ? "multiple" : "single"
    @controlled = !value.nil?
    @open_values = Array(@controlled ? value : default_value).map(&:to_s).reject(&:empty?)
    @collapsible = @type == "multiple" || collapsible
    @disabled = disabled
    @dir = dir&.to_s
    @orientation = orientation.to_s
    @as_child = as_child
    @id = id
    @attrs = attrs
    super()
  end

  # @yieldparam acc [Chadcn::Accordion] the root, exposing the part helpers
  # @return [void]
  def view_template
    previous = context[ROOT_KEY]
    context[ROOT_KEY] = {
      open_values: @open_values, collapsible: @collapsible, disabled: @disabled, orientation: @orientation,
      base: @id || "accordion-#{next_sequence(SEQUENCE_KEY)}", items: 0
    }
    @dir = use_direction(@dir) if @dir.filled? || context[Chadcn::Direction::KEY]
    attrs = merge_attrs({ id: @id, data: root_data }, @attrs)
    content = proc { yield self if block_given? }
    @as_child ? render_as_child(@as_child, **attrs, &content) : div(**attrs, &content)
  ensure
    context[ROOT_KEY] = previous
  end

  private

  def root_data
    {
      slot: "accordion",
      orientation: @orientation,
      controller: "chadcn--accordion",
      chadcn__accordion_type_value: @type,
      chadcn__accordion_controlled_value: @controlled.to_s,
      chadcn__accordion_collapsible_value: @collapsible.to_s,
      chadcn__accordion_disabled_value: @disabled.to_s,
      chadcn__accordion_orientation_value: @orientation,
      chadcn__accordion_dir_value: @dir
    }
  end
end
