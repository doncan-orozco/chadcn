# frozen_string_literal: true

# shadcn Accordion over Radix Accordion. Spec: docs/shadcn-port/specs/accordion.md.
# Behavior: controllers/shadcn/accordion_controller.js.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::Accordion < Phlex::Shadcn::Base
  include Phlex::Shadcn::Direction::Consumer

  ROOT_KEY = :shadcn_accordion_root
  ITEM_KEY = :shadcn_accordion_item
  SEQUENCE_KEY = :shadcn_accordion_sequence

  # value: non-nil is controlled (user actions only dispatch value-change, the caller re-renders with the new value).
  # single: String ("" = none open); multiple: Array of Strings.
  def initialize(type: "single", value: nil, default_value: nil, collapsible: false, disabled: false, dir: nil,
                 orientation: "vertical", as_child: false, **attrs)
    @type = type.to_s == "multiple" ? "multiple" : "single"
    @controlled = !value.nil?
    @open_values = Array(@controlled ? value : default_value).map(&:to_s).reject(&:empty?)
    @collapsible = @type == "multiple" || collapsible
    @disabled = disabled
    @dir = dir&.to_s
    @orientation = orientation.to_s
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template
    previous = context[ROOT_KEY]
    context[ROOT_KEY] = { open_values: @open_values, collapsible: @collapsible, disabled: @disabled, orientation: @orientation }
    @dir = use_direction(@dir) if @dir.filled? || context[Phlex::Shadcn::Direction::KEY]
    attrs = merge_attrs({ data: root_data }, @attrs)
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
      controller: "shadcn--accordion",
      shadcn__accordion_type_value: @type,
      shadcn__accordion_controlled_value: @controlled.to_s,
      shadcn__accordion_collapsible_value: @collapsible.to_s,
      shadcn__accordion_disabled_value: @disabled.to_s,
      shadcn__accordion_orientation_value: @orientation,
      shadcn__accordion_dir_value: @dir
    }
  end
end
