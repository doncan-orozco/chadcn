# frozen_string_literal: true

# shadcn Alert (new-york-v4). Spec: docs/shadcn-port/specs/alert.md. Static: no controller.
class Phlex::Shadcn::Alert < Phlex::Shadcn::Base
  BASE = "relative grid w-full grid-cols-[0_1fr] items-start gap-y-0.5 rounded-lg border px-4 py-3 text-sm has-[>svg]:grid-cols-[calc(var(--spacing)*4)_1fr] has-[>svg]:gap-x-3 [&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current"

  VARIANTS = {
    "default" => "bg-card text-card-foreground",
    "destructive" => "bg-card text-destructive *:data-[slot=alert-description]:text-destructive/90 [&>svg]:text-current"
  }.freeze

  def initialize(variant: "default", **attrs)
    @variant = normalize_option(variant) || "default"
    raise ArgumentError, "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})" unless VARIANTS.key?(@variant)

    @attrs = attrs
    super()
  end

  def view_template(&block)
    attrs = merge_attrs({ data: { slot: "alert" }, role: "alert", class: cn(BASE, VARIANTS[@variant]) }, @attrs)
    div(**attrs) { yield self if block }
  end

  class Title < Phlex::Shadcn::Base
    CLASS_NAME = "col-start-2 line-clamp-1 min-h-4 font-medium tracking-tight"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "alert-title" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Description < Phlex::Shadcn::Base
    CLASS_NAME = "col-start-2 grid justify-items-start gap-1 text-sm text-muted-foreground [&_p]:leading-relaxed"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "alert-description" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
