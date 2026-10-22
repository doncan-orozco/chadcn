# frozen_string_literal: true

# shadcn Avatar over Radix Avatar: a round user picture that shows its {Avatar::Fallback} until the {Avatar::Image} has loaded.
# The loading logic lives in the +chadcn--avatar+ Stimulus controller.
#
# @example
#   Chadcn::Avatar.new(size: :lg) { |avatar| avatar.image(src: "/me.png", alt: "Me"); avatar.fallback { "ME" } }
#
# @!method image(**attrs, &block)
#   Renders {Avatar::Image}; same as +render Avatar::Image.new(**attrs), &block+.
#   @return [void]
#
# @!method fallback(**attrs, &block)
#   Renders {Avatar::Fallback}; same as +render Avatar::Fallback.new(**attrs), &block+.
#   @return [void]
#
# @!method badge(**attrs, &block)
#   Renders {Avatar::Badge}; same as +render Avatar::Badge.new(**attrs), &block+.
#   @return [void]
#
# @!method group(**attrs, &block)
#   Renders {Avatar::Group}; same as +render Avatar::Group.new(**attrs), &block+.
#   @return [void]
#
# @!method group_count(**attrs, &block)
#   Renders {Avatar::GroupCount}; same as +render Avatar::GroupCount.new(**attrs), &block+.
#   @return [void]
class Chadcn::Avatar < Chadcn::Base
  # Accepted +size+ values.
  SIZES = %w[default sm lg].freeze
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  ROOT_CLASS = "group/avatar relative flex size-8 shrink-0 overflow-hidden rounded-full select-none data-[size=lg]:size-10 data-[size=sm]:size-6"

  # @param size [String, Symbol, nil] one of {SIZES}; nil means +default+
  # @param as_child [Boolean, Symbol, Chadcn::Base] render this element (a tag name or component instance) instead of the default one (Radix +asChild+)
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  # @raise [ArgumentError] on an unknown size
  def initialize(size: "default", as_child: false, **attrs)
    @size = normalize_option(size) || "default"
    raise ArgumentError, "unknown size #{size.inspect}, expected one of #{SIZES.join(', ')}" unless SIZES.include?(@size)

    @as_child = as_child
    @attrs = attrs
    super()
  end

  # Renders the element; yields +self+ so the parts can be composed with the generated helpers (+avatar.fallback { ... }+).
  # The block is skipped when none is given.
  #
  # @yieldparam avatar [Chadcn::Avatar] the component itself
  # @return [void]
  def view_template(&block)
    attrs = merge_attrs({ data: { slot: "avatar", size: @size, controller: "chadcn--avatar" }, class: ROOT_CLASS }, @attrs)
    if @as_child
      render_as_child(@as_child, **attrs) { yield self if block }
    else
      span(**attrs) { yield self if block }
    end
  end

  # The avatar picture; mounted by the Stimulus controller once the image has loaded (kept in an inert +template+ until then).
  #
  # @note Deviation from Radix: the +img+ is not in the DOM before it has loaded.
  class Image < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASSES = "aspect-square size-full"

    # @param src [String, nil] image URL
    # @param as_child [Boolean, Symbol, Chadcn::Base] render this element (a tag name or component instance) instead of the default one (Radix +asChild+)
    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(src: nil, as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs.merge(src:).compact
      super()
    end

    # Renders the +template+ that holds the +img+. The block is only used with +as_child:+ (+img+ is a void element).
    #
    # @return [void]
    def view_template(&)
      attrs = merge_attrs({ data: { slot: "avatar-image" }, class: CLASSES }, @attrs)
      template(data: { chadcn__avatar_target: "image" }) do
        @as_child ? render_as_child(@as_child, **attrs, &) : img(**attrs)
      end
    end
  end

  # Shown while the image is missing or loading (initials, an icon). With +delay_ms:+ it waits in a +template+ and appears after the delay.
  class Fallback < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASSES = "flex size-full items-center justify-center rounded-full bg-muted text-sm text-muted-foreground group-data-[size=sm]/avatar:text-xs"

    # @param delay_ms [Integer, nil] wait this long before showing the fallback
    # @param as_child [Boolean, Symbol, Chadcn::Base] render this element (a tag name or component instance) instead of the default one (Radix +asChild+)
    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(delay_ms: nil, as_child: false, **attrs)
      @delay_ms = delay_ms
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # Renders the fallback content (the block). Without a delay it is a live element (SSR and no-JS show it); with one, it waits in a template.
    #
    # @return [void]
    def view_template(&)
      return element(&) unless @delay_ms

      template(data: { chadcn__avatar_target: "fallback", chadcn__avatar_delay_ms: @delay_ms }) { element(&) }
    end

    private

    def element(&)
      target = @delay_ms ? {} : { chadcn__avatar_target: "fallback" }
      attrs = merge_attrs({ data: { slot: "avatar-fallback", **target }, class: CLASSES }, @attrs)
      @as_child ? render_as_child(@as_child, **attrs, &) : span(**attrs, &)
    end
  end

  # A small status dot (or tiny icon) anchored to the bottom-right corner of the avatar.
  class Badge < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASSES = "absolute right-0 bottom-0 z-10 inline-flex items-center justify-center rounded-full bg-primary text-primary-foreground ring-2 ring-background select-none group-data-[size=sm]/avatar:size-2 group-data-[size=sm]/avatar:[&>svg]:hidden group-data-[size=default]/avatar:size-2.5 group-data-[size=default]/avatar:[&>svg]:size-2 group-data-[size=lg]/avatar:size-3 group-data-[size=lg]/avatar:[&>svg]:size-2"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      span(**merge_attrs({ data: { slot: "avatar-badge" }, class: CLASSES }, @attrs), &)
    end
  end

  # Overlaps several avatars in a row.
  class Group < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASSES = "group/avatar-group flex -space-x-2 *:data-[slot=avatar]:ring-2 *:data-[slot=avatar]:ring-background"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "avatar-group" }, class: CLASSES }, @attrs), &)
    end
  end

  # The "+3" bubble that closes an {Avatar::Group}.
  class GroupCount < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASSES = "relative flex size-8 shrink-0 items-center justify-center rounded-full bg-muted text-sm text-muted-foreground ring-2 ring-background group-has-data-[size=lg]/avatar-group:size-10 group-has-data-[size=sm]/avatar-group:size-6 [&>svg]:size-4 group-has-data-[size=lg]/avatar-group:[&>svg]:size-5 group-has-data-[size=sm]/avatar-group:[&>svg]:size-3"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "avatar-group-count" }, class: CLASSES }, @attrs), &)
    end
  end
end
