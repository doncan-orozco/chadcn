# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# shadcn Item: a flexible list row (media, content, actions). Renders a +div+, or a link through +as_child:+.
#
# @example
#   Phlex::Shadcn::Item.new(variant: :outline) { |item| item.content { item.title { "Invoice" }; item.description { "Due Friday" } } }
#
# @!method media(**attrs, &block)
#   Renders {Item::Media}; same as +render Item::Media.new(**attrs), &block+.
#   @return [void]
#
# @!method content(**attrs, &block)
#   Renders {Item::Content}; same as +render Item::Content.new(**attrs), &block+.
#   @return [void]
#
# @!method actions(**attrs, &block)
#   Renders {Item::Actions}; same as +render Item::Actions.new(**attrs), &block+.
#   @return [void]
#
# @!method group(**attrs, &block)
#   Renders {Item::Group}; same as +render Item::Group.new(**attrs), &block+.
#   @return [void]
#
# @!method title(**attrs, &block)
#   Renders {Item::Title}; same as +render Item::Title.new(**attrs), &block+.
#   @return [void]
#
# @!method description(**attrs, &block)
#   Renders {Item::Description}; same as +render Item::Description.new(**attrs), &block+.
#   @return [void]
#
# @!method header(**attrs, &block)
#   Renders {Item::Header}; same as +render Item::Header.new(**attrs), &block+.
#   @return [void]
#
# @!method footer(**attrs, &block)
#   Renders {Item::Footer}; same as +render Item::Footer.new(**attrs), &block+.
#   @return [void]
#
# @!method separator(**attrs, &block)
#   Renders {Item::Separator}; same as +render Item::Separator.new(**attrs), &block+.
#   @return [void]
class Phlex::Shadcn::Item < Phlex::Shadcn::Base
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  BASE = "group/item flex flex-wrap items-center rounded-md border border-transparent text-sm transition-colors duration-100 outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 [a]:transition-colors [a]:hover:bg-accent/50"

  # Accepted +variant+ values and the Tailwind classes each one adds.
  VARIANTS = {
    "default" => "bg-transparent",
    "outline" => "border-border",
    "muted" => "bg-muted/50"
  }.freeze

  # Accepted +size+ values and the Tailwind classes each one adds.
  SIZES = {
    "default" => "gap-4 p-4",
    "sm" => "gap-2.5 px-4 py-3"
  }.freeze

  # Class string of the component, for styling another element the same way (React +itemVariants+).
  #
  # @example
  #   Phlex::Shadcn::Item.variants(variant: :outline, size: :sm)
  #
  # @param variant [String, Symbol] one of the keys of {VARIANTS}
  # @param size [String, Symbol] one of the keys of {SIZES}
  # @param class [String, nil] extra classes, merged last
  # @return [String]
  # @raise [ArgumentError] on an unknown variant/size
  def self.variants(variant: "default", size: "default", class: nil)
    new(variant: variant, size: size).send(:classes, binding.local_variable_get(:class))
  end

  # @param variant [String, Symbol] one of the keys of {VARIANTS} (underscores read as dashes)
  # @param size [String, Symbol] one of the keys of {SIZES}
  # @param as_child [Boolean, Symbol, Phlex::Shadcn::Base] render this element (a tag name or component instance) instead of the default one (Radix +asChild+)
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  # @raise [ArgumentError] on an unknown variant
  # @raise [ArgumentError] on an unknown size
  def initialize(variant: "default", size: "default", as_child: false, **attrs)
    @variant = normalize_option(variant) || "default"
    @size = normalize_option(size) || "default"
    raise ArgumentError, "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})" unless VARIANTS.key?(@variant)
    raise ArgumentError, "unknown size: #{size.inspect} (expected one of #{SIZES.keys.join(', ')})" unless SIZES.key?(@size)

    @as_child = as_child
    @attrs = attrs
  end

  # Renders the element; yields +self+ so the parts can be composed with the generated helpers (+item.content { ... }+).
  # The block is skipped when none is given.
  #
  # @yieldparam item [Phlex::Shadcn::Item] the component itself
  # @return [void]
  def view_template(&block)
    attrs = merge_attrs({ data: { slot: "item", variant: @variant, size: @size } }, @attrs.except(:class))
    attrs = attrs.merge(class: [ @slot_class, classes(@attrs[:class]) ].reject_blank.join(" "))
    return render_as_child(@as_child, **attrs) { yield self if block } if @as_child

    div(**attrs) { yield self if block }
  end

  private

  def classes(extra) = cn(BASE, VARIANTS[@variant], SIZES[@size], extra)

  # Leading icon or image of an {Item}.
  class Media < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    BASE = "flex shrink-0 items-center justify-center gap-2 group-has-[[data-slot=item-description]]/item:translate-y-0.5 group-has-[[data-slot=item-description]]/item:self-start [&_svg]:pointer-events-none"

    # Accepted +variant+ values and the Tailwind classes each one adds.
    VARIANTS = {
      "default" => "bg-transparent",
      "icon" => "size-8 rounded-sm border bg-muted [&_svg:not([class*='size-'])]:size-4",
      "image" => "size-10 overflow-hidden rounded-sm [&_img]:size-full [&_img]:object-cover"
    }.freeze

    # Class string of the media slot (React +itemMediaVariants+).
    #
    # @example
    #   Phlex::Shadcn::Item::Media.variants(variant: :icon)
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
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-media", variant: @variant }, class: classes(nil) }, @attrs), &)
    end

    private

    def classes(extra) = cn(BASE, VARIANTS[@variant], extra)
  end

  # Title and description column.
  class Content < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex flex-1 flex-col gap-1 [&+[data-slot=item-content]]:flex-none"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Trailing buttons.
  class Actions < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex items-center gap-2"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-actions" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # A +role="list"+ wrapper that stacks items.
  class Group < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "group/item-group flex flex-col"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ role: "list", data: { slot: "item-group" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # The item title.
  class Title < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex w-fit items-center gap-2 text-sm leading-snug font-medium"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-title" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # A +p+ with the item description (clamped to two lines).
  class Description < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "line-clamp-2 text-sm leading-normal font-normal text-balance text-muted-foreground [&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      p(**merge_attrs({ data: { slot: "item-description" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Full-width row above the content.
  class Header < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex basis-full items-center justify-between gap-2"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-header" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Full-width row below the content.
  class Footer < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex basis-full items-center justify-between gap-2"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-footer" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # A horizontal {Phlex::Shadcn::Separator} between items (+class: "my-0"+).
  class Separator < Phlex::Shadcn::Base
    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
    end

    # Renders a horizontal {Phlex::Shadcn::Separator} marked +data-slot="item-separator"+ (takes no block).
    #
    # @return [void]
    def view_template
      render Phlex::Shadcn::Separator.new(**merge_attrs({ data: { slot: "item-separator" }, orientation: "horizontal", class: "my-0" },
                                                        @attrs))
    end
  end
end
