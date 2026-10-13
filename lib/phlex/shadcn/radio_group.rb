# frozen_string_literal: true

# shadcn RadioGroup over Radix RadioGroup. Spec: docs/shadcn-port/specs/radio-group.md.
# Behavior: controllers/v2/radio_group_controller.js (one controller per group, items are not controllers).
class Phlex::Shadcn::RadioGroup < Phlex::Shadcn::Base
  include Phlex::Shadcn::Direction::Consumer

  ROOT_KEY = :v2_radio_group_root
  CLASSES = "grid gap-3"
  ORIENTATIONS = %w[horizontal vertical].freeze
  DIRECTIONS = %w[ltr rtl].freeze

  # value: non-nil is controlled (user actions only dispatch value-change, the caller re-renders with the new value).
  def initialize(value: nil, default_value: nil, disabled: false, required: false, name: nil, form: nil,
                 orientation: nil, dir: nil, loop: true, as_child: false, **attrs)
    @controlled = !value.nil?
    @value = (@controlled ? value : default_value)&.to_s
    @disabled = disabled
    @required = required
    @name = name
    @form = form
    @orientation = choice(orientation, ORIENTATIONS, "orientation")
    @dir = choice(dir, DIRECTIONS, "dir")
    @loop = loop
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template
    previous = context[ROOT_KEY]
    @dir = use_direction(@dir)
    context[ROOT_KEY] = { value: @value, disabled: @disabled, required: @required, name: @name, form: @form, orientation: @orientation }
    attrs = merge_attrs(root_defaults, @attrs)
    attrs[:style] = merge_styles(root_defaults[:style], @attrs[:style]) if @attrs[:style]
    content = proc { yield self if block_given? }
    @as_child ? render_as_child(@as_child, **attrs, &content) : div(**attrs, &content)
  ensure
    context[ROOT_KEY] = previous
  end

  private

  def choice(value, allowed, name)
    return if value.nil?

    value = value.to_s
    return value if allowed.include?(value)

    raise ArgumentError, "#{name} must be one of #{allowed.join(', ')}, got #{value.inspect}"
  end

  def root_defaults
    {
      role: "radiogroup",
      aria: { required: @required.to_s, orientation: @orientation },
      dir: @dir,
      tabindex: @disabled ? -1 : 0,
      style: "outline: none;",
      class: CLASSES,
      data: {
        slot: "radio-group", orientation: @orientation, controller: "v2--radio-group",
        disabled: (@disabled ? "" : nil),
        v2__radio_group_controlled_value: @controlled.to_s,
        v2__radio_group_loop_value: @loop.to_s,
        v2__radio_group_orientation_value: @orientation,
        v2__radio_group_dir_value: @dir,
        v2__radio_group_indicator_html_value: indicator_html
      }
    }
  end

  # The controller mounts this markup when an item becomes checked (Radix Presence).
  def indicator_html
    capture { render Phlex::Shadcn::RadioGroup::Item::Indicator.new(state: "checked") }
  end
end
