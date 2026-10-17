# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# shadcn Separator over Radix Separator: a thin horizontal or vertical rule.
#
# @example
#   Phlex::Shadcn::Separator.new(orientation: :vertical, decorative: false)
class Phlex::Shadcn::Separator < Phlex::Shadcn::Base
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  BASE = "shrink-0 bg-border data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px"
  # Accepted +orientation+ values.
  ORIENTATIONS = %w[horizontal vertical].freeze

  # @param orientation [String, Symbol] +horizontal+ or +vertical+; any other value falls back to +horizontal+
  # @param decorative [Boolean] +true+ renders +role="none"+; +false+ renders +role="separator"+ (plus +aria-orientation+ when vertical)
  # @param as_child [Boolean, Symbol, Phlex::Shadcn::Base] render this element (a tag name or component instance) instead of the default one (Radix +asChild+)
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  def initialize(orientation: "horizontal", decorative: true, as_child: false, **attrs)
    orientation = orientation.to_s
    @orientation = ORIENTATIONS.include?(orientation) ? orientation : "horizontal"
    @decorative = decorative
    @as_child = as_child
    @attrs = attrs
  end

  # Renders the element with the block as its content.
  #
  # @return [void]
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
