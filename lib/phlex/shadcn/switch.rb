# frozen_string_literal: true

# shadcn/ui Switch over Radix Switch. Spec: docs/shadcn-port/specs/switch.md
using Phlex::Shadcn::Values::Refinements

# A toggle button with `role=switch`, plus a hidden checkbox so it submits with a form.
#
# User input, or a form reset that changes the state, dispatches the `shadcn--switch:checked-change` event
# (`detail: { checked }`). The hidden checkbox is removed by the controller when the switch is not inside a `<form>`
# and has no `form:`.
#
# @example
#   render Phlex::Shadcn::Switch.new(name: "notifications", default_checked: true, id: "notifications")
class Phlex::Shadcn::Switch < Phlex::Shadcn::Base
  # Classes of the switch button.
  ROOT_CLASS = "peer group/switch inline-flex shrink-0 items-center rounded-full border border-transparent shadow-xs transition-all outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 data-[size=default]:h-[1.15rem] data-[size=default]:w-8 data-[size=sm]:h-3.5 data-[size=sm]:w-6 data-[state=checked]:bg-primary data-[state=unchecked]:bg-input dark:data-[state=unchecked]:bg-input/80"
  # Classes of the thumb span.
  THUMB_CLASS = "pointer-events-none block rounded-full bg-background ring-0 transition-transform group-data-[size=default]/switch:size-4 group-data-[size=sm]/switch:size-3 data-[state=checked]:translate-x-[calc(100%-2px)] data-[state=unchecked]:translate-x-0 dark:data-[state=checked]:bg-primary-foreground dark:data-[state=unchecked]:bg-foreground"
  # Inline style hiding the form bubble input.
  #
  # @api private
  BUBBLE_STYLE = "position: absolute; pointer-events: none; opacity: 0; margin: 0px; transform: translateX(-100%);"

  # @param size [String, Symbol] `"default"` or `"sm"`; other values are not supported: they are rendered as-is in
  #   `data-size` without sizing classes
  # @param checked [Boolean, nil] controlled state (non-nil: user input only dispatches an event, the caller re-renders)
  # @param default_checked [Boolean] initial state (uncontrolled)
  # @param disabled [Boolean] disables the button and the hidden checkbox, and adds `data-disabled`
  # @param required [Boolean, nil] sets `aria-required` and the bubble input's `required`
  # @param name [String, nil] form field name of the bubble input
  # @param value [String] value submitted when on
  # @param form [String, nil] id of the associated `<form>`
  # @param attrs [Hash] HTML attributes for the button (`id:`, `class:` merged last, `aria:`, `data:`)
  def initialize(size: "default", checked: nil, default_checked: false, disabled: false, required: nil,
                 name: nil, value: "on", form: nil, **attrs)
    @size = normalize_option(size) || "default"
    @controlled = !checked.nil?
    @checked = @controlled ? checked : default_checked
    @disabled = disabled
    @required = required
    @name = name
    @value = value
    @form = form
    @attrs = attrs
    super()
  end

  # @return [void]
  def view_template
    state = @checked ? "checked" : "unchecked"
    button(**root_with_action(merge_attrs(root_attrs(state), @attrs))) do
      span(data: { state:, slot: "switch-thumb", **(@disabled ? { disabled: "" } : {}) }, class: THUMB_CLASS)
    end
    bubble_input
  end

  private

  # Radix composes the consumer onClick first, then the toggle: our action goes last.
  def root_with_action(attrs)
    action = [ attrs.dig(:data, :action), "click->shadcn--switch#toggle" ].reject_blank.join(" ")
    attrs.merge(data: attrs[:data].merge(action:))
  end

  def root_attrs(state)
    {
      type: "button",
      role: "switch",
      aria: { checked: @checked, **(@required.nil? ? {} : { required: @required }) },
      data: { state:, slot: "switch", size: @size, controller: "shadcn--switch", shadcn__switch_controlled_value: @controlled,
              **(@disabled ? { disabled: "" } : {}) },
      disabled: @disabled,
      value: @value,
      class: ROOT_CLASS
    }
  end

  # Radix SSR renders the bubble input unconditionally; the controller drops it when outside a form.
  def bubble_input
    input(type: "checkbox", aria_hidden: "true", tabindex: -1, checked: @checked, required: @required == true,
          disabled: @disabled, name: @name, value: @value, form: @form, style: BUBBLE_STYLE)
  end
end
