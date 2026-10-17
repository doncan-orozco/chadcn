# frozen_string_literal: true

# shadcn `Input` (new-york-v4). Spec: docs/shadcn-port/specs/input.md
#
# A single-line text field, the shadcn `Input`; renders a void `<input data-slot="input">`.
#
# @example
#   render Phlex::Shadcn::Input.new(type: "email", name: "email", placeholder: "you@example.com")
class Phlex::Shadcn::Input < Phlex::Shadcn::Base
  # Layout, typography and disabled classes.
  BASE = "h-9 w-full min-w-0 rounded-md border border-input bg-transparent px-3 py-1 text-base shadow-xs transition-[color,box-shadow] outline-none selection:bg-primary selection:text-primary-foreground file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-muted-foreground disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm dark:bg-input/30"
  # Focus ring classes.
  FOCUS = "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
  # Classes applied when `aria-invalid` is set.
  INVALID = "aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40"

  # Builds the input; `default_value:` mirrors React `defaultValue`.
  #
  # @param type [String, Symbol, nil] the HTML input type; nil omits the attribute
  # @param default_value [String, nil] initial value, rendered as the `value` attribute (an explicit `value:` wins)
  # @param attrs [Hash] HTML attributes (`name:`, `placeholder:`, `disabled:`, `class:`, `data:`, `aria:`...)
  def initialize(type: nil, default_value: nil, **attrs)
    @type = type&.to_s
    @attrs = default_value.nil? ? attrs : { value: default_value }.merge(attrs)
  end

  # @return [void]
  def view_template
    attrs = merge_attrs({ data: { slot: "input" } }, @attrs.except(:class))
    input(type: @type, **attrs, class: cn(BASE, FOCUS, INVALID, @attrs[:class]))
  end
end
