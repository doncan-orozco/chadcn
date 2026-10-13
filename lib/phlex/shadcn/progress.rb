# frozen_string_literal: true

# shadcn `Progress` (Radix Progress). Spec: docs/shadcn-port/specs/progress.md. Static: no controller.
# shadcn does not forward `value` to Radix, so the DOM is always indeterminate; `value` only drives the transform.
class Phlex::Shadcn::Progress < Phlex::Shadcn::Base
  DEFAULT_MAX = 100

  def initialize(value: nil, max: nil, **attrs)
    @value = value || 0
    @max = valid_max?(max) ? js_number(max) : DEFAULT_MAX
    @attrs = attrs
  end

  def view_template
    attrs = merge_attrs(
      {
        aria: { valuemax: @max, valuemin: 0 },
        role: "progressbar",
        data: { state: "indeterminate", max: @max, slot: "progress" },
        class: "relative h-2 w-full overflow-hidden rounded-full bg-primary/20"
      },
      @attrs
    )

    div(**attrs) do
      div(
        data: { state: "indeterminate", max: @max, slot: "progress-indicator" },
        class: "h-full w-full flex-1 bg-primary transition-all",
        style: indicator_style
      )
    end
  end

  private

  # Radix isNumber + max > 0 (progress.mjs:80-82).
  def valid_max?(max) = max.is_a?(Numeric) && max.to_f.finite? && max.positive?

  # Beyond 100 the JS string is translateX(--n%), an invalid transform the CSSOM drops: no style.
  def indicator_style
    remaining = 100 - @value
    return if remaining.negative?

    "transform: translateX(-#{js_number(remaining)}%);"
  end

  # JS String(number): integer-valued floats print without ".0".
  def js_number(number)
    number.is_a?(Float) && number == number.to_i ? number.to_i : number
  end
end
