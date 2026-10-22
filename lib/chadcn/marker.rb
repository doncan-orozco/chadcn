# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn Marker: a timeline/chat divider line with an optional {Marker::Icon} and {Marker::Content}.
#
# @example
#   Chadcn::Marker.new(variant: :separator) { |marker| marker.content { "Today" } }
#
# @!method icon(**attrs, &block)
#   Renders {Marker::Icon}; same as +render Marker::Icon.new(**attrs), &block+.
#   @return [void]
#
# @!method content(**attrs, &block)
#   Renders {Marker::Content}; same as +render Marker::Content.new(**attrs), &block+.
#   @return [void]
class Chadcn::Marker < Chadcn::Base
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  BASE = "group/marker relative flex min-h-4 w-full items-center gap-2 text-left text-sm text-muted-foreground [&_svg:not([class*='size-'])]:size-4 [a]:underline [a]:underline-offset-3 [a]:hover:text-foreground"

  # Accepted +variant+ values and the Tailwind classes each one adds.
  VARIANTS = {
    "default" => "",
    "separator" => "before:mr-1 before:h-px before:min-w-0 before:flex-1 before:bg-border after:ml-1 after:h-px after:min-w-0 after:flex-1 after:bg-border",
    "border" => "border-b border-border pb-2"
  }.freeze

  # Class string of the component, for styling another element the same way (React +markerVariants+).
  #
  # @example
  #   Chadcn::Marker.variants(variant: :border)
  #
  # @param variant [String, Symbol] one of the keys of {VARIANTS}
  # @param class [String, nil] extra classes, merged last
  # @return [String]
  # @raise [ArgumentError] on an unknown variant
  def self.variants(variant: "default", class: nil)
    key = variant&.to_s&.tr("_", "-") || "default"
    raise ArgumentError, "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})" unless VARIANTS.key?(key)

    TailwindMerge::Merger.new.merge([ BASE, VARIANTS[key], binding.local_variable_get(:class) ].reject_blank.join(" "))
  end

  # @param variant [String, Symbol] one of the keys of {VARIANTS} (underscores read as dashes)
  # @param as_child [Boolean, Symbol, Chadcn::Base] render this element (a tag name or component instance) instead of the default one (Radix +asChild+)
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  # @raise [ArgumentError] on an unknown variant
  def initialize(variant: "default", as_child: false, **attrs)
    @variant = normalize_option(variant) || "default"
    raise ArgumentError, "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})" unless VARIANTS.key?(@variant)

    @as_child = as_child
    @attrs = attrs
    super()
  end

  # Renders the element; yields +self+ so the parts can be composed with the generated helpers (+marker.content { ... }+).
  # The block is skipped when none is given.
  #
  # @yieldparam marker [Chadcn::Marker] the component itself
  # @return [void]
  def view_template(&block)
    attrs = merge_attrs({ data: { slot: "marker", variant: @variant }, class: cn(BASE, VARIANTS[@variant]) }, @attrs)
    return render_as_child(@as_child, **attrs) { yield self if block } if @as_child

    div(**attrs) { yield self if block }
  end

  # Leading icon of the marker (+aria-hidden+).
  class Icon < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "size-4 shrink-0 [&_svg:not([class*='size-'])]:size-4"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      span(**merge_attrs({ data: { slot: "marker-icon" }, aria: { hidden: "true" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # The marker label.
  class Content < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "min-w-0 wrap-break-word group-data-[variant=separator]/marker:flex-none group-data-[variant=separator]/marker:text-center *:[a]:underline *:[a]:underline-offset-3 *:[a]:hover:text-foreground"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      span(**merge_attrs({ data: { slot: "marker-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
