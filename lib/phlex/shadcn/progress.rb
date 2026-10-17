# frozen_string_literal: true

# shadcn Progress over Radix Progress.
# Like shadcn, the DOM is always +data-state="indeterminate"+: +value+ only moves the indicator.
#
# @example
#   Phlex::Shadcn::Progress.new(value: 40)
class Phlex::Shadcn::Progress < Phlex::Shadcn::Base
  # The +max+ used when none (or an invalid one) is given.
  DEFAULT_MAX = 100

  # @param value [Numeric, nil] a percentage (0-100) that positions the indicator; above 100 no style is rendered
  # @param max [Numeric, nil] only exposed as +data-max+ and +aria-valuemax+ (ignored unless a positive number, default 100)
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  def initialize(value: nil, max: nil, **attrs)
    @value = value || 0
    @max = valid_max?(max) ? js_number(max) : DEFAULT_MAX
    @attrs = attrs
  end

  # Renders the track and its indicator (takes no block; +aria-valuenow+ is never rendered, like shadcn).
  #
  # @return [void]
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
