# frozen_string_literal: true

# shadcn Skeleton: a pulsing placeholder box; size it with +class+.
#
# @example
#   Phlex::Shadcn::Skeleton.new(class: "h-4 w-40")
class Phlex::Shadcn::Skeleton < Phlex::Shadcn::Base
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  BASE = "animate-pulse rounded-md bg-accent"

  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  def initialize(**attrs)
    @attrs = attrs
  end

  # Renders the element with the block as its content.
  #
  # @return [void]
  def view_template(&)
    attrs = merge_attrs({ data: { slot: "skeleton" } }, @attrs.except(:class))
    div(**attrs, class: cn(BASE, @attrs[:class]), &)
  end
end
