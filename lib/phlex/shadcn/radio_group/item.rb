# frozen_string_literal: true

# shadcn RadioGroupItem: Radix Item button (+ Indicator while checked) followed by the form bubble input.
class Phlex::Shadcn::RadioGroup::Item < Phlex::Shadcn::Base
  CLASSES = "aspect-square size-4 shrink-0 rounded-full border border-input text-primary shadow-xs transition-[color,box-shadow] outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:bg-input/30 dark:aria-invalid:ring-destructive/40"
  BUBBLE_STYLE = "position: absolute; pointer-events: none; opacity: 0; margin: 0px; transform: translateX(-100%);"
  ACTIONS = "click->v2--radio-group#select keydown->v2--radio-group#keydown focus->v2--radio-group#focus"

  # Radix Indicator: rendered only while checked.
  class Indicator < Phlex::Shadcn::Base
    CLASSES = "relative flex items-center justify-center"
    ICON_CLASSES = "absolute top-1/2 left-1/2 size-2 -translate-x-1/2 -translate-y-1/2 fill-primary"

    def initialize(state:, disabled: false)
      @state = state
      @disabled = disabled
      super()
    end

    def view_template
      span(data: { state: @state, disabled: (@disabled ? "" : nil), slot: "radio-group-indicator" }, class: CLASSES) do
        render Phlex::Shadcn::Icon.new("circle", class: ICON_CLASSES)
      end
    end
  end

  def initialize(value:, disabled: false, **attrs)
    @value = value.to_s
    @disabled = disabled
    @attrs = attrs
    super()
  end

  def view_template
    root = context[Phlex::Shadcn::RadioGroup::ROOT_KEY] or raise ArgumentError, "#{self.class.name} must be used within RadioGroup"
    checked = root[:value] == @value
    disabled = root[:disabled] || @disabled
    button(**with_action(merge_attrs(button_defaults(checked, disabled, root), @attrs))) do
      render Indicator.new(state: "checked", disabled:) if checked
    end
    bubble_input(checked, disabled, root)
  end

  private

  def button_defaults(checked, disabled, root)
    {
      type: "button",
      role: "radio",
      aria: { checked: checked.to_s },
      disabled:,
      value: @value,
      tabindex: -1,
      class: CLASSES,
      data: {
        state: (checked ? "checked" : "unchecked"), disabled: (disabled ? "" : nil), orientation: root[:orientation],
        radix_collection_item: "", slot: "radio-group-item"
      }
    }
  end

  # Radix composes the consumer handlers first, then its own: our actions go last.
  def with_action(attrs)
    action = [ attrs.dig(:data, :action), ACTIONS ].compact_blank.join(" ")
    attrs.merge(data: attrs[:data].merge(action:))
  end

  # Radix SSR renders the bubble input unconditionally; the controller drops it when outside a form.
  def bubble_input(checked, disabled, root)
    input(type: "radio", aria_hidden: "true", tabindex: -1, checked:, required: root[:required], disabled:,
          name: root[:name], value: @value, form: root[:form], style: BUBBLE_STYLE)
  end
end
