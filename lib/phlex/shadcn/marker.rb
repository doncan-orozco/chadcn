# frozen_string_literal: true

# shadcn Marker (new-york-v4). Spec: docs/shadcn-port/specs/marker.md. Static: no controller.
class Phlex::Shadcn::Marker < Phlex::Shadcn::Base
  BASE = "group/marker relative flex min-h-4 w-full items-center gap-2 text-left text-sm text-muted-foreground [&_svg:not([class*='size-'])]:size-4 [a]:underline [a]:underline-offset-3 [a]:hover:text-foreground"

  VARIANTS = {
    "default" => "",
    "separator" => "before:mr-1 before:h-px before:min-w-0 before:flex-1 before:bg-border after:ml-1 after:h-px after:min-w-0 after:flex-1 after:bg-border",
    "border" => "border-b border-border pb-2"
  }.freeze

  # React `markerVariants`.
  def self.variants(variant: "default", class: nil)
    key = variant&.to_s&.tr("_", "-") || "default"
    raise ArgumentError, "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})" unless VARIANTS.key?(key)

    TailwindMerge::Merger.new.merge([ BASE, VARIANTS[key], binding.local_variable_get(:class) ].compact_blank.join(" "))
  end

  def initialize(variant: "default", as_child: false, **attrs)
    @variant = normalize_option(variant) || "default"
    raise ArgumentError, "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})" unless VARIANTS.key?(@variant)

    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&block)
    attrs = merge_attrs({ data: { slot: "marker", variant: @variant }, class: cn(BASE, VARIANTS[@variant]) }, @attrs)
    return render_as_child(@as_child, **attrs) { yield self if block } if @as_child

    div(**attrs) { yield self if block }
  end

  class Icon < Phlex::Shadcn::Base
    CLASS_NAME = "size-4 shrink-0 [&_svg:not([class*='size-'])]:size-4"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      span(**merge_attrs({ data: { slot: "marker-icon" }, aria: { hidden: "true" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Content < Phlex::Shadcn::Base
    CLASS_NAME = "min-w-0 wrap-break-word group-data-[variant=separator]/marker:flex-none group-data-[variant=separator]/marker:text-center *:[a]:underline *:[a]:underline-offset-3 *:[a]:hover:text-foreground"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      span(**merge_attrs({ data: { slot: "marker-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
