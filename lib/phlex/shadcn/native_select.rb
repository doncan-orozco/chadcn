# frozen_string_literal: true

# shadcn NativeSelect (new-york-v4). Spec: docs/shadcn-port/specs/native-select.md
class Phlex::Shadcn::NativeSelect < Phlex::Shadcn::Base
  CONTEXT_KEY = :v2_native_select_selected
  BASE = "h-9 w-full min-w-0 appearance-none rounded-md border border-input bg-transparent px-3 py-2 pr-9 text-sm shadow-xs transition-[color,box-shadow] outline-none selection:bg-primary selection:text-primary-foreground placeholder:text-muted-foreground disabled:pointer-events-none disabled:cursor-not-allowed data-[size=sm]:h-8 data-[size=sm]:py-1 dark:bg-input/30 dark:hover:bg-input/50"
  FOCUS = "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
  INVALID = "aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40"
  WRAPPER = "group/native-select relative w-fit has-[select:disabled]:opacity-50"
  ICON = "pointer-events-none absolute top-1/2 right-3.5 size-4 -translate-y-1/2 text-muted-foreground opacity-50 select-none"

  # value: wins over default_value:. Both render the selected attribute (spec Deviations).
  def initialize(size: "default", default_value: nil, value: nil, **attrs)
    @size = size.to_s
    @selected = Array(value.nil? ? default_value : value).map(&:to_s)
    @multiple = attrs[:multiple]
    @attrs = attrs
    super()
  end

  def view_template
    attrs = merge_attrs({ data: { slot: "native-select", size: @size } }, @attrs.except(:class))
    previous = context[CONTEXT_KEY]
    context[CONTEXT_KEY] = { values: @selected, multiple: @multiple, taken: false }
    div(class: WRAPPER, data: { slot: "native-select-wrapper" }) do
      select(**attrs, class: cn(BASE, FOCUS, INVALID, @attrs[:class])) { yield self }
      render Phlex::Shadcn::Icon.new("chevron-down", class: ICON, aria: { hidden: "true" }, data: { slot: "native-select-icon" })
    end
  ensure
    context[CONTEXT_KEY] = previous
  end
end
