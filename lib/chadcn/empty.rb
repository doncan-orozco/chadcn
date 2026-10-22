# frozen_string_literal: true

# shadcn Empty: the empty-state block (no results, nothing here yet). Compose with {Empty::Header}, {Empty::Media}, {Empty::Title}, {Empty::Description} and {Empty::Content}.
#
# @example
#   Chadcn::Empty.new { |empty| empty.header { empty.media(variant: :icon) { "i" }; empty.title { "No projects" } } }
#
# @!method header(**attrs, &block)
#   Renders {Empty::Header}; same as +render Empty::Header.new(**attrs), &block+.
#   @return [void]
#
# @!method media(**attrs, &block)
#   Renders {Empty::Media}; same as +render Empty::Media.new(**attrs), &block+.
#   @return [void]
#
# @!method title(**attrs, &block)
#   Renders {Empty::Title}; same as +render Empty::Title.new(**attrs), &block+.
#   @return [void]
#
# @!method description(**attrs, &block)
#   Renders {Empty::Description}; same as +render Empty::Description.new(**attrs), &block+.
#   @return [void]
#
# @!method content(**attrs, &block)
#   Renders {Empty::Content}; same as +render Empty::Content.new(**attrs), &block+.
#   @return [void]
class Chadcn::Empty < Chadcn::Base
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  CLASS_NAME = "flex min-w-0 flex-1 flex-col items-center justify-center gap-6 rounded-lg border-dashed p-6 text-center text-balance md:p-12"

  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # Renders the element; yields +self+ so the parts can be composed with the generated helpers (+empty.title { ... }+).
  # The block is skipped when none is given.
  #
  # @yieldparam empty [Chadcn::Empty] the component itself
  # @return [void]
  def view_template(&block)
    div(**merge_attrs({ data: { slot: "empty" }, class: CLASS_NAME }, @attrs)) { yield self if block }
  end

  # Groups the media, title and description.
  class Header < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex max-w-sm flex-col items-center gap-2 text-center"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "empty-header" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # The illustration slot. The +icon+ variant draws a muted rounded square around an icon.
  class Media < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    BASE = "mb-2 flex shrink-0 items-center justify-center [&_svg]:pointer-events-none [&_svg]:shrink-0"

    # Accepted +variant+ values and the Tailwind classes each one adds.
    VARIANTS = {
      "default" => "bg-transparent",
      "icon" => "flex size-10 shrink-0 items-center justify-center rounded-lg bg-muted text-foreground [&_svg:not([class*='size-'])]:size-6"
    }.freeze

    # Class string of the component, for styling another element the same way (React +emptyMediaVariants+).
    #
    # @example
    #   Chadcn::Empty::Media.variants(variant: :icon)
    #
    # @param variant [String, Symbol] one of the keys of {VARIANTS}
    # @param class [String, nil] extra classes, merged last
    # @return [String]
    # @raise [ArgumentError] on an unknown variant
    def self.variants(variant: "default", class: nil)
      new(variant: variant).send(:classes, binding.local_variable_get(:class))
    end

    # @param variant [String, Symbol] one of the keys of {VARIANTS} (underscores read as dashes)
    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    # @raise [ArgumentError] on an unknown variant
    def initialize(variant: "default", **attrs)
      @variant = normalize_option(variant) || "default"
      unless VARIANTS.key?(@variant)
        raise ArgumentError,
              "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})"
      end

      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "empty-icon", variant: @variant }, class: classes }, @attrs), &)
    end

    private

    def classes(extra = nil) = cn(BASE, VARIANTS[@variant], extra)
  end

  # The empty-state heading.
  class Title < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "text-lg font-medium tracking-tight"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "empty-title" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Supporting text; links inside it are underlined.
  class Description < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "text-sm/relaxed text-muted-foreground [&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "empty-description" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Holds the call-to-action below the header.
  class Content < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex w-full max-w-sm min-w-0 flex-col items-center gap-4 text-sm text-balance"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "empty-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
