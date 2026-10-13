# frozen_string_literal: true

# shadcn `Skeleton` (new-york-v4). Spec: docs/shadcn-port/specs/skeleton.md. Static: no controller.
class Phlex::Shadcn::Skeleton < Phlex::Shadcn::Base
  BASE = "animate-pulse rounded-md bg-accent"

  def initialize(**attrs)
    @attrs = attrs
  end

  def view_template(&)
    attrs = merge_attrs({ data: { slot: "skeleton" } }, @attrs.except(:class))
    div(**attrs, class: cn(BASE, @attrs[:class]), &)
  end
end
