# frozen_string_literal: true

# shadcn Alert: a callout box with an optional leading +svg+ icon (a direct child, styled by the classes), {Alert::Title} and {Alert::Description}.
#
# @example
#   Phlex::Shadcn::Alert.new(variant: :destructive) { |alert| alert.title { "Heads up" }; alert.description { "Something broke." } }
#
# @!method title(**attrs, &block)
#   Renders {Alert::Title}; same as +render Alert::Title.new(**attrs), &block+.
#   @return [void]
#
# @!method description(**attrs, &block)
#   Renders {Alert::Description}; same as +render Alert::Description.new(**attrs), &block+.
#   @return [void]
class Phlex::Shadcn::Alert < Phlex::Shadcn::Base
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  BASE = "relative grid w-full grid-cols-[0_1fr] items-start gap-y-0.5 rounded-lg border px-4 py-3 text-sm has-[>svg]:grid-cols-[calc(var(--spacing)*4)_1fr] has-[>svg]:gap-x-3 [&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current"

  # Accepted +variant+ values and the Tailwind classes each one adds.
  VARIANTS = {
    "default" => "bg-card text-card-foreground",
    "destructive" => "bg-card text-destructive *:data-[slot=alert-description]:text-destructive/90 [&>svg]:text-current"
  }.freeze

  # @param variant [String, Symbol] one of the keys of {VARIANTS} (underscores read as dashes)
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  # @raise [ArgumentError] on an unknown variant
  def initialize(variant: "default", **attrs)
    @variant = normalize_option(variant) || "default"
    raise ArgumentError, "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})" unless VARIANTS.key?(@variant)

    @attrs = attrs
    super()
  end

  # Renders the element; yields +self+ so the parts can be composed with the generated helpers (+alert.title { ... }+).
  # The block is skipped when none is given.
  #
  # @yieldparam alert [Phlex::Shadcn::Alert] the component itself
  # @return [void]
  def view_template(&block)
    attrs = merge_attrs({ data: { slot: "alert" }, role: "alert", class: cn(BASE, VARIANTS[@variant]) }, @attrs)
    div(**attrs) { yield self if block }
  end

  # The alert heading (+div data-slot="alert-title"+).
  class Title < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "col-start-2 line-clamp-1 min-h-4 font-medium tracking-tight"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "alert-title" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # The alert body text (+div data-slot="alert-description"+).
  class Description < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "col-start-2 grid justify-items-start gap-1 text-sm text-muted-foreground [&_p]:leading-relaxed"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "alert-description" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
