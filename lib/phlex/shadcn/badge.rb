# frozen_string_literal: true

# shadcn `Badge` (new-york-v4). Spec: docs/shadcn-port/specs/badge.md. Static: no controller.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::Badge < Phlex::Shadcn::Base
  BASE = "inline-flex w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-full border border-transparent px-2 py-0.5 text-xs font-medium whitespace-nowrap transition-[color,box-shadow] focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&>svg]:pointer-events-none [&>svg]:size-3"

  VARIANTS = {
    "default" => "bg-primary text-primary-foreground [a&]:hover:bg-primary/90",
    "secondary" => "bg-secondary text-secondary-foreground [a&]:hover:bg-secondary/90",
    "destructive" => "bg-destructive text-white focus-visible:ring-destructive/20 dark:bg-destructive/60 dark:focus-visible:ring-destructive/40 [a&]:hover:bg-destructive/90",
    "outline" => "border-border text-foreground [a&]:hover:bg-accent [a&]:hover:text-accent-foreground",
    "ghost" => "[a&]:hover:bg-accent [a&]:hover:text-accent-foreground",
    "link" => "text-primary underline-offset-4 [a&]:hover:underline"
  }.freeze

  # React `badgeVariants`.
  def self.variants(variant: "default", class: nil)
    new(variant: variant).send(:classes, binding.local_variable_get(:class))
  end

  def initialize(variant: "default", as_child: false, **attrs)
    @variant = normalize_option(variant) || "default"
    raise ArgumentError, "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})" unless VARIANTS.key?(@variant)

    @as_child = as_child
    @attrs = attrs
  end

  def view_template(&)
    attrs = merge_attrs({ data: { slot: "badge", variant: @variant } }, @attrs.except(:class))
    attrs = attrs.merge(class: [ @slot_class, classes(@attrs[:class]) ].reject_blank.join(" "))
    return render_as_child(@as_child, **attrs, &) if @as_child

    span(**attrs, &)
  end

  private

  def classes(extra) = cn(BASE, VARIANTS[@variant], extra)
end
