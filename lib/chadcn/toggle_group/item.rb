# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn ToggleGroupItem: Radix Toggle inside a RovingFocusGroup item.
#
# Must be rendered inside a {ToggleGroup} (raises ArgumentError otherwise). The group's `variant` and `size` win over
# the item's own; `disabled` applies when either the group or the item sets it.
#
# @example
#   group.item(value: "bold", aria: { label: "Bold" }) { "B" }
class Chadcn::ToggleGroup::Item < Chadcn::Base
  # Classes added on top of {Chadcn::Toggle} classes.
  #
  # @return [String]
  EXTRA_CLASSES = "w-auto min-w-0 shrink-0 px-3 focus:z-10 focus-visible:z-10"
  # Classes that join adjacent items when the group spacing is 0.
  #
  # @return [String]
  SPACING_CLASSES = "data-[spacing=0]:rounded-none data-[spacing=0]:shadow-none data-[spacing=0]:first:rounded-l-md data-[spacing=0]:last:rounded-r-md data-[spacing=0]:data-[variant=outline]:border-l-0 data-[spacing=0]:data-[variant=outline]:first:border-l"
  # Stimulus action wired on the item.
  #
  # @api private
  ACTION = "click->shadcn--toggle-group#toggle"

  # @param value [String] identifier of the item inside the group value (coerced with `to_s`)
  # @param variant [String, Symbol, nil] used when the group sets none
  # @param size [String, Symbol, nil] used when the group sets none
  # @param disabled [Boolean] disables this item (the group's `disabled:` also applies)
  # @param as_child [false, Symbol, String, Chadcn::Base]
  #   a tag or component instance to render instead of the `<button>`; false renders the default element
  # @param attrs [Hash] HTML attributes for the item (`class:` merged last, `aria:`, `data:`)
  def initialize(value:, variant: nil, size: nil, disabled: false, as_child: false, **attrs)
    @value = value.to_s
    @variant = normalize_option(variant)
    @size = normalize_option(size)
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the item content
  # @return [void]
  # @raise [ArgumentError] when rendered outside a {ToggleGroup}, or when the effective variant or size is unknown
  #   (raised by `Toggle.variants`)
  def view_template(&)
    root = context[Chadcn::ToggleGroup::ROOT_KEY] or raise ArgumentError, "#{self.class.name} must be used within ToggleGroup"
    variant = root[:variant] || @variant
    size = root[:size] || @size
    disabled = root[:disabled] || @disabled
    attrs = merge_attrs(defaults(root, variant, size, disabled), @attrs.except(:class))
    attrs = with_action(attrs.merge(class: [ @slot_class, classes(variant, size) ].reject_blank.join(" ")))
    return render_as_child(@as_child, **attrs, &) if @as_child

    button(**attrs, &)
  end

  private

  def classes(variant, size)
    cn(Chadcn::Toggle.variants(variant: variant || "default", size: size || "default"), EXTRA_CLASSES, SPACING_CLASSES,
       @attrs[:class])
  end

  def defaults(root, variant, size, disabled)
    pressed = pressed?(root)
    {
      type: "button",
      disabled:,
      data: {
        state: (pressed ? "on" : "off"), disabled: (disabled ? "" : nil), slot: "toggle-group-item",
        variant:, size:, spacing: root[:spacing], shadcn__toggle_group_item_value: @value
      }
    }.merge_deep(roving_attrs(root)).merge_deep(pressed_attrs(root, pressed))
  end

  def pressed?(root)
    root[:type] == "single" ? root[:value] == @value : root[:value].include?(@value)
  end

  def pressed_attrs(root, pressed)
    return { role: "radio", aria: { checked: pressed.to_s } } if root[:type] == "single"

    { aria: { pressed: pressed.to_s } }
  end

  def roving_attrs(root)
    return {} unless root[:roving]

    { tabindex: -1, data: { orientation: root[:orientation], radix_collection_item: "" } }
  end

  # Radix runs the consumer handlers first, then its own: our action goes last.
  def with_action(attrs)
    action = [ attrs.dig(:data, :action), ACTION ].reject_blank.join(" ")
    attrs.merge(data: attrs[:data].merge(action:))
  end
end
