# frozen_string_literal: true

# shadcn Message: one chat message row. +align+ puts it on either side. Compose with {Message::Group}, {Message::Avatar}, {Message::Content},
# {Message::Header} and {Message::Footer} (the header and footer sit inside the content).
#
# @example
#   Phlex::Shadcn::Message.new(align: :end) { |message| message.content { message.header { "You" } } }
#
# @!method group(**attrs, &block)
#   Renders {Message::Group}; same as +render Message::Group.new(**attrs), &block+.
#   @return [void]
#
# @!method avatar(**attrs, &block)
#   Renders {Message::Avatar}; same as +render Message::Avatar.new(**attrs), &block+.
#   @return [void]
#
# @!method content(**attrs, &block)
#   Renders {Message::Content}; same as +render Message::Content.new(**attrs), &block+.
#   @return [void]
#
# @!method header(**attrs, &block)
#   Renders {Message::Header}; same as +render Message::Header.new(**attrs), &block+.
#   @return [void]
#
# @!method footer(**attrs, &block)
#   Renders {Message::Footer}; same as +render Message::Footer.new(**attrs), &block+.
#   @return [void]
class Phlex::Shadcn::Message < Phlex::Shadcn::Base
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  BASE = "group/message relative flex w-full min-w-0 gap-2 text-sm data-[align=end]:flex-row-reverse"
  # Accepted +align+ values.
  ALIGNS = %w[start end].freeze

  # @param align [String, Symbol] one of {ALIGNS}
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  # @raise [ArgumentError] on an unknown align
  def initialize(align: "start", **attrs)
    @align = align&.to_s || "start"
    raise ArgumentError, "unknown align: #{align.inspect} (expected one of #{ALIGNS.join(', ')})" unless ALIGNS.include?(@align)

    @attrs = attrs
    super()
  end

  # Renders the element; yields +self+ so the parts can be composed with the generated helpers (+message.content { ... }+).
  # The block is skipped when none is given.
  #
  # @yieldparam message [Phlex::Shadcn::Message] the component itself
  # @return [void]
  def view_template(&block)
    div(**merge_attrs({ data: { slot: "message", align: @align }, class: BASE }, @attrs)) { yield self if block }
  end

  # Stacks consecutive messages of the same sender.
  class Group < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex min-w-0 flex-col gap-2"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "message-group" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # The sender avatar slot.
  class Avatar < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex w-fit min-w-8 shrink-0 items-center justify-center self-end overflow-hidden rounded-full bg-muted group-has-data-[slot=message-footer]/message:-translate-y-8"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "message-avatar" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Column holding the header, bubble(s) and footer.
  class Content < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex w-full min-w-0 flex-col gap-2.5 wrap-break-word group-data-[align=end]/message:*:data-slot:self-end"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "message-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Small line above the bubble (sender name).
  class Header < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex max-w-full min-w-0 items-center px-3 text-xs font-medium text-muted-foreground group-has-data-[variant=ghost]/message:px-0"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "message-header" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Small line below the bubble (time, status).
  class Footer < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex max-w-full min-w-0 items-center px-3 text-xs font-medium text-muted-foreground group-has-data-[variant=ghost]/message:px-0 group-data-[align=end]/message:justify-end"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "message-footer" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
