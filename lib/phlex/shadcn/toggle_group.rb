# frozen_string_literal: true

# shadcn ToggleGroup over Radix ToggleGroup. Spec: docs/shadcn-port/specs/toggle-group.md.
# Behavior: controllers/shadcn/toggle_group_controller.js (one controller per group, items are not controllers).
class Phlex::Shadcn::ToggleGroup < Phlex::Shadcn::Base
  include Phlex::Shadcn::Direction::Consumer

  ROOT_KEY = :shadcn_toggle_group_root
  CLASSES = "group/toggle-group flex w-fit items-center gap-[--spacing(var(--gap))] rounded-md data-[spacing=default]:data-[variant=outline]:shadow-xs"
  TYPES = %w[single multiple].freeze
  ORIENTATIONS = %w[horizontal vertical].freeze
  DIRECTIONS = %w[ltr rtl].freeze

  # value: non-nil is controlled (user actions only dispatch value-change, the caller re-renders with the new value).
  def initialize(type:, value: nil, default_value: nil, variant: nil, size: nil, spacing: 0, disabled: false,
                 roving_focus: true, orientation: nil, dir: nil, loop: true, as_child: false, **attrs)
    @type = choice(type, TYPES, "type") or raise ArgumentError, "type is required, one of #{TYPES.join(', ')}"
    @controlled = !value.nil?
    @value = initial_value(@controlled ? value : default_value)
    @variant = normalize_option(variant)
    @size = normalize_option(size)
    raise ArgumentError, "spacing must be a Numeric, got #{spacing.inspect}" unless spacing.is_a?(Numeric)

    @spacing = format_number(spacing)
    @disabled = disabled
    @roving_focus = roving_focus
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
    context[ROOT_KEY] = { type: @type, value: @value, variant: @variant, size: @size, spacing: @spacing,
                          disabled: @disabled, roving: @roving_focus, orientation: @orientation }
    attrs = merge_attrs(root_defaults, @attrs.except(:style))
    attrs[:style] = style
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

  # single: String ("" = none); multiple: Array of Strings in activation order.
  def initial_value(value)
    if @type == "single"
      raise ArgumentError, "value must not be an Array for type #{@type}" if value.is_a?(Array)

      value.to_s
    else
      raise ArgumentError, "value must be an Array for type #{@type}" if !value.nil? && !value.is_a?(Array)

      Array(value).map(&:to_s)
    end
  end

  # JavaScript number formatting: 2.0 renders as "2".
  def format_number(number)
    (number.to_f % 1).zero? ? number.to_i.to_s : number.to_s
  end

  # Radix outline:none, then shadcn --gap; a caller style replaces the --gap declaration.
  def style
    custom = @attrs[:style]
    "#{[ (@roving_focus ? 'outline: none' : nil), (custom ? style_string(custom) : "--gap: #{@spacing}") ].compact.join('; ')};"
  end

  def root_defaults
    {
      role: (@type == "single" ? "radiogroup" : "toolbar"),
      dir: @dir,
      class: CLASSES,
      data: {
        slot: "toggle-group", variant: @variant, size: @size, spacing: @spacing, controller: "shadcn--toggle-group",
        orientation: (@roving_focus ? @orientation : nil),
        shadcn__toggle_group_type_value: @type,
        shadcn__toggle_group_controlled_value: @controlled.to_s,
        shadcn__toggle_group_initial_value: (@type == "multiple" ? json(@value) : nil),
        shadcn__toggle_group_loop_value: @loop.to_s,
        shadcn__toggle_group_roving_focus_value: @roving_focus.to_s,
        shadcn__toggle_group_orientation_value: @orientation,
        shadcn__toggle_group_dir_value: @dir
      }
    }.merge(if @roving_focus
              { tabindex: (@disabled ? -1 : 0) }
            else
              {}
            end)
  end
end
