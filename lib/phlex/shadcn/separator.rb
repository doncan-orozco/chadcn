# frozen_string_literal: true

# shadcn `Separator` over Radix Separator. Spec: docs/shadcn-port/specs/separator.md. Static: no controller.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::Separator < Phlex::Shadcn::Base
  BASE = "shrink-0 bg-border data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px"
  ORIENTATIONS = %w[horizontal vertical].freeze

  def initialize(orientation: "horizontal", decorative: true, as_child: false, **attrs)
    orientation = orientation.to_s
    @orientation = ORIENTATIONS.include?(orientation) ? orientation : "horizontal"
    @decorative = decorative
    @as_child = as_child
    @attrs = attrs
  end

  def view_template(&)
    attrs = merge_attrs(defaults, @attrs.except(:class))
    attrs = attrs.merge(class: [ @slot_class, cn(BASE, @attrs[:class]) ].reject_blank.join(" "))
    return render_as_child(@as_child, **attrs, &) if @as_child

    div(**attrs, &)
  end

  private

  def defaults
    semantics =
      if @decorative
        { role: "none" }
      else
        { role: "separator", aria: { orientation: (@orientation if @orientation == "vertical") }.compact }
      end
    { data: { slot: "separator", orientation: @orientation } }.merge(semantics)
  end
end
