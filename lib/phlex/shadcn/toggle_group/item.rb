# frozen_string_literal: true

# shadcn ToggleGroupItem: Radix Toggle inside a RovingFocusGroup item.
class Phlex::Shadcn::ToggleGroup::Item < Phlex::Shadcn::Base
  EXTRA_CLASSES = "w-auto min-w-0 shrink-0 px-3 focus:z-10 focus-visible:z-10"
  SPACING_CLASSES = "data-[spacing=0]:rounded-none data-[spacing=0]:shadow-none data-[spacing=0]:first:rounded-l-md data-[spacing=0]:last:rounded-r-md data-[spacing=0]:data-[variant=outline]:border-l-0 data-[spacing=0]:data-[variant=outline]:first:border-l"
  ACTION = "click->v2--toggle-group#toggle"

  def initialize(value:, variant: nil, size: nil, disabled: false, as_child: false, **attrs)
    @value = value.to_s
    @variant = normalize_option(variant)
    @size = normalize_option(size)
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    root = context[Phlex::Shadcn::ToggleGroup::ROOT_KEY] or raise ArgumentError, "#{self.class.name} must be used within ToggleGroup"
    variant = root[:variant] || @variant
    size = root[:size] || @size
    disabled = root[:disabled] || @disabled
    attrs = merge_attrs(defaults(root, variant, size, disabled), @attrs.except(:class))
    attrs = with_action(attrs.merge(class: [ @slot_class, classes(variant, size) ].compact_blank.join(" ")))
    return render_as_child(@as_child, **attrs, &) if @as_child

    button(**attrs, &)
  end

  private

  def classes(variant, size)
    cn(Phlex::Shadcn::Toggle.variants(variant: variant || "default", size: size || "default"), EXTRA_CLASSES, SPACING_CLASSES,
       @attrs[:class])
  end

  def defaults(root, variant, size, disabled)
    pressed = pressed?(root)
    {
      type: "button",
      disabled:,
      data: {
        state: (pressed ? "on" : "off"), disabled: (disabled ? "" : nil), slot: "toggle-group-item",
        variant:, size:, spacing: root[:spacing], v2__toggle_group_item_value: @value
      }
    }.deep_merge(roving_attrs(root)).deep_merge(pressed_attrs(root, pressed))
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
    action = [ attrs.dig(:data, :action), ACTION ].compact_blank.join(" ")
    attrs.merge(data: attrs[:data].merge(action:))
  end
end
