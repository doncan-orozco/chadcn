# frozen_string_literal: true

# shadcn/ui Checkbox over Radix Checkbox. Spec: docs/shadcn-port/specs/checkbox.md
using Phlex::Shadcn::Values::Refinements

# A checkbox: a `<button role="checkbox">` plus the hidden form input Radix renders.
#
# Driven by the `shadcn--checkbox` Stimulus controller. Pass `checked:` for a controlled checkbox (the
# controller will not toggle the state itself) or `default_checked:` for an uncontrolled one. User input dispatches
# the `shadcn--checkbox:checked-change` event (`detail: { checked }`, where `checked` is true, false or "indeterminate");
# a form reset that changes the state dispatches it too. The hidden input is removed by the controller when the
# checkbox is not inside a `<form>` and has no `form:`.
#
# @example
#   render Phlex::Shadcn::Checkbox.new(name: "terms", id: "terms", default_checked: true)
# @example Indeterminate
#   render Phlex::Shadcn::Checkbox.new(checked: "indeterminate")
class Phlex::Shadcn::Checkbox < Phlex::Shadcn::Base
  # Classes of the checkbox button.
  #
  # @return [String]
  ROOT_CLASS = "peer size-4 shrink-0 rounded-[4px] border border-input shadow-xs transition-shadow outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 data-[state=checked]:border-primary data-[state=checked]:bg-primary data-[state=checked]:text-primary-foreground dark:bg-input/30 dark:aria-invalid:ring-destructive/40 dark:data-[state=checked]:bg-primary"
  # Classes of the check indicator.
  #
  # @return [String]
  INDICATOR_CLASS = "grid place-content-center text-current transition-none"
  # Inline style of the hidden form input.
  #
  # @api private
  BUBBLE_STYLE = "position: absolute; pointer-events: none; opacity: 0; margin: 0px; transform: translateX(-100%);"
  # Accepted values of `checked:` => `data-state`.
  #
  # @return [Hash{Boolean, String => String}]
  # @api private
  STATES = { true => "checked", false => "unchecked", "indeterminate" => "indeterminate" }.freeze
  # `data-state` => `aria-checked`.
  #
  # @return [Hash{String => String}]
  # @api private
  ARIA_CHECKED = { "checked" => "true", "unchecked" => "false", "indeterminate" => "mixed" }.freeze

  # @param checked [Boolean, String, Symbol, nil] controlled state: true, false or "indeterminate"; nil makes it uncontrolled
  # @param default_checked [Boolean, String, Symbol] initial state when uncontrolled (same values as `checked:`)
  # @param disabled [Boolean] disables the checkbox
  # @param required [Boolean, nil] sets `aria-required` and the hidden input `required`
  # @param name [String, nil] form field name, on the hidden input
  # @param value [String] form value submitted when checked
  # @param form [String, nil] id of the form the hidden input belongs to
  # @param attrs [Hash] HTML attributes merged onto the button (`id:`, `class:`, `data:`, `aria:`...)
  # @raise [ArgumentError] when the state is not true, false or "indeterminate"
  def initialize(checked: nil, default_checked: false, disabled: false, required: nil,
                 name: nil, value: "on", form: nil, **attrs)
    @controlled = !checked.nil?
    @checked = normalize_checked(@controlled ? checked : (default_checked || false))
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
    state = STATES.fetch(@checked)
    button(**root_with_action(merge_attrs(root_attrs(state), @attrs))) do
      indicator(state) unless state == "unchecked"
    end
    bubble_input
  end

  private

  def normalize_checked(value)
    value = "indeterminate" if value.to_s == "indeterminate"
    return value if STATES.key?(value)

    raise ArgumentError, "checked must be true, false or \"indeterminate\", got #{value.inspect}"
  end

  # Radix composes the consumer handlers first, then its own: our actions go last.
  def root_with_action(attrs)
    action = [ attrs.dig(:data, :action), "click->shadcn--checkbox#toggle keydown->shadcn--checkbox#keydown" ].reject_blank.join(" ")
    attrs.merge(data: attrs[:data].merge(action:))
  end

  def root_attrs(state)
    {
      type: "button",
      role: "checkbox",
      aria: { checked: ARIA_CHECKED.fetch(state), **(@required.nil? ? {} : { required: @required }) },
      data: { state:, slot: "checkbox", controller: "shadcn--checkbox", shadcn__checkbox_controlled_value: @controlled,
              shadcn__checkbox_indicator_html_value: indicator_html,
              **(@disabled ? { disabled: "" } : {}) },
      disabled: @disabled,
      value: @value,
      class: ROOT_CLASS
    }
  end

  # The controller mounts this markup on check (Radix Presence); it is never in the DOM while unchecked.
  def indicator_html
    capture { indicator("checked") }
  end

  def indicator(state)
    span(data: { state:, slot: "checkbox-indicator", **(@disabled ? { disabled: "" } : {}) }, class: INDICATOR_CLASS,
         style: "pointer-events: none;") do
      render Phlex::Shadcn::Icon.new("check", class: "size-3.5")
    end
  end

  # Radix SSR renders the bubble input unconditionally; the controller drops it when outside a form.
  def bubble_input
    input(type: "checkbox", aria_hidden: "true", tabindex: -1, checked: @checked == true, required: @required == true,
          disabled: @disabled, name: @name, value: @value, form: @form, style: BUBBLE_STYLE)
  end
end
