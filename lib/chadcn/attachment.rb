# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn Attachment: an uploaded-file chip with a +state+ (idle, uploading, processing, error, done). Compose with {Attachment::Media}, {Attachment::Content},
# {Attachment::Actions} and {Attachment::Trigger}.
#
# @example
#   Chadcn::Attachment.new(state: :uploading) { |a| a.media { "i" }; a.content { a.title { "report.pdf" } } }
#
# @!method group(**attrs, &block)
#   Renders {Attachment::Group}; same as +render Attachment::Group.new(**attrs), &block+.
#   @return [void]
#
# @!method media(**attrs, &block)
#   Renders {Attachment::Media}; same as +render Attachment::Media.new(**attrs), &block+.
#   @return [void]
#
# @!method content(**attrs, &block)
#   Renders {Attachment::Content}; same as +render Attachment::Content.new(**attrs), &block+.
#   @return [void]
#
# @!method title(**attrs, &block)
#   Renders {Attachment::Title}; same as +render Attachment::Title.new(**attrs), &block+.
#   @return [void]
#
# @!method description(**attrs, &block)
#   Renders {Attachment::Description}; same as +render Attachment::Description.new(**attrs), &block+.
#   @return [void]
#
# @!method actions(**attrs, &block)
#   Renders {Attachment::Actions}; same as +render Attachment::Actions.new(**attrs), &block+.
#   @return [void]
#
# @!method action(**attrs, &block)
#   Renders {Attachment::Action}; same as +render Attachment::Action.new(**attrs), &block+.
#   @return [void]
#
# @!method trigger(**attrs, &block)
#   Renders {Attachment::Trigger}; same as +render Attachment::Trigger.new(**attrs), &block+.
#   @return [void]
class Chadcn::Attachment < Chadcn::Base
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  BASE = "group/attachment relative flex w-fit max-w-full min-w-0 shrink-0 flex-wrap rounded-xl border bg-card text-card-foreground transition-colors focus-within:ring-1 focus-within:ring-ring/50 has-[>a,>button]:hover:bg-muted/50 data-[state=error]:border-destructive/30 data-[state=idle]:border-dashed"

  # Accepted +size+ values and the Tailwind classes each one adds.
  SIZES = {
    "default" => "gap-2 text-sm has-data-[slot=attachment-content]:px-2.5 has-data-[slot=attachment-content]:py-2 has-data-[slot=attachment-media]:p-2",
    "sm" => "gap-2.5 text-xs has-data-[slot=attachment-content]:px-2 has-data-[slot=attachment-content]:py-1.5 has-data-[slot=attachment-media]:p-1.5",
    "xs" => "gap-1.5 rounded-lg text-xs has-data-[slot=attachment-content]:px-1.5 has-data-[slot=attachment-content]:py-1 has-data-[slot=attachment-media]:p-1"
  }.freeze

  # Accepted +orientation+ values and the Tailwind classes each one adds.
  ORIENTATIONS = {
    "horizontal" => "min-w-40 items-center",
    "vertical" => "w-24 flex-col has-data-[slot=attachment-content]:w-30"
  }.freeze

  # Accepted +state+ values.
  STATES = %w[idle uploading processing error done].freeze

  # Normalizes and validates a variant-like option; shared by the attachment parts.
  #
  # @api private
  def self.fetch_option!(value, default, allowed, name)
    option = value&.to_s&.tr("_", "-") || default
    raise ArgumentError, "unknown #{name}: #{value.inspect} (expected one of #{allowed.join(', ')})" unless allowed.include?(option)

    option
  end

  # @param state [String, Symbol] one of +idle+, +uploading+, +processing+, +error+, +done+
  # @param size [String, Symbol] one of the keys of {SIZES}
  # @param orientation [String, Symbol] +horizontal+ or +vertical+
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  # @raise [ArgumentError] on an unknown state
  # @raise [ArgumentError] on an unknown size
  # @raise [ArgumentError] on an unknown orientation
  def initialize(state: "done", size: "default", orientation: "horizontal", **attrs)
    @state = self.class.fetch_option!(state, "done", STATES, "state")
    @size = self.class.fetch_option!(size, "default", SIZES.keys, "size")
    @orientation = self.class.fetch_option!(orientation, "horizontal", ORIENTATIONS.keys, "orientation")
    @attrs = attrs
    super()
  end

  # Renders the element; yields +self+ so the parts can be composed with the generated helpers (+attachment.content { ... }+).
  # The block is skipped when none is given.
  #
  # @yieldparam attachment [Chadcn::Attachment] the component itself
  # @return [void]
  def view_template(&block)
    defaults = {
      data: { slot: "attachment", state: @state, size: @size, orientation: @orientation },
      class: cn(BASE, SIZES[@size], ORIENTATIONS[@orientation])
    }
    div(**merge_attrs(defaults, @attrs)) { yield self if block }
  end

  # A horizontally scrolling row of attachments.
  class Group < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex min-w-0 scroll-fade-x snap-x snap-mandatory scroll-px-1 scrollbar-none gap-3 overflow-x-auto overscroll-x-contain py-1 *:data-[slot=attachment]:flex-none *:data-[slot=attachment]:snap-start"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "attachment-group" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Leading icon or image thumbnail.
  class Media < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    BASE = "relative flex aspect-square w-10 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-muted text-foreground group-data-[orientation=vertical]/attachment:w-full group-data-[size=sm]/attachment:w-8 group-data-[size=xs]/attachment:w-7 group-data-[size=xs]/attachment:rounded-md group-data-[state=error]/attachment:bg-destructive/10 group-data-[state=error]/attachment:text-destructive group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6! [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 group-data-[orientation=vertical]/attachment:[&_svg:not([class*='size-'])]:size-6 group-data-[size=xs]/attachment:[&_svg:not([class*='size-'])]:size-3.5"

    # Accepted +variant+ values and the Tailwind classes each one adds.
    VARIANTS = {
      "icon" => "",
      "image" => "opacity-60 group-data-[state=done]/attachment:opacity-100 group-data-[state=idle]/attachment:opacity-100 *:[img]:aspect-square *:[img]:w-full *:[img]:object-cover"
    }.freeze

    # @param variant [String, Symbol] one of the keys of {VARIANTS} (underscores read as dashes)
    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    # @raise [ArgumentError] on an unknown variant
    def initialize(variant: "icon", **attrs)
      @variant = Chadcn::Attachment.fetch_option!(variant, "icon", VARIANTS.keys, "variant")
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      defaults = { data: { slot: "attachment-media", variant: @variant }, class: cn(BASE, VARIANTS[@variant]) }
      div(**merge_attrs(defaults, @attrs), &)
    end
  end

  # Title and description column.
  class Content < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "max-w-full min-w-0 flex-1 leading-tight group-data-[orientation=vertical]/attachment:px-1"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "attachment-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # File name (+span+, shimmers while uploading or processing).
  class Title < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "block max-w-full min-w-0 truncate font-medium group-data-[state=processing]/attachment:shimmer group-data-[state=uploading]/attachment:shimmer"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      span(**merge_attrs({ data: { slot: "attachment-title" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Size or error text (+span+).
  class Description < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "mt-0.5 block min-w-0 truncate text-xs text-muted-foreground group-data-[state=error]/attachment:text-destructive/80"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      defaults = { data: { slot: "attachment-description" }, class: cn(CLASS_NAME, "max-w-full") }
      span(**merge_attrs(defaults, @attrs), &)
    end
  end

  # Container for {Attachment::Action} buttons.
  class Actions < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "relative z-20 flex shrink-0 items-center group-data-[orientation=vertical]/attachment:absolute group-data-[orientation=vertical]/attachment:top-3 group-data-[orientation=vertical]/attachment:right-3 group-data-[orientation=vertical]/attachment:gap-1"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "attachment-actions" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # An icon {Chadcn::Button} (+ghost+, +icon-xs+ by default) inside the actions area.
  class Action < Chadcn::Base
    # @param variant [String, Symbol, nil] any {Chadcn::Button} variant (default +ghost+)
    # @param size [String, Symbol] any {Chadcn::Button} size (default +icon-xs+)
    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    # @note Variant and size are validated by {Chadcn::Button} when the action renders, not here.
    def initialize(variant: nil, size: "icon-xs", **attrs)
      @variant = variant || "ghost"
      @size = size
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      attrs = merge_attrs({ data: { slot: "attachment-action" } }, @attrs)
      render(Chadcn::Button.new(variant: @variant, size: @size, **attrs), &)
    end
  end

  # Invisible full-area button that makes the whole attachment clickable. +as_child:+ renders it as a link.
  class Trigger < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "absolute inset-0 z-10 outline-none"

    # @param as_child [Symbol, Chadcn::Base, false] render this tag name or component instance instead of the +button+ (Radix +asChild+)
    # @param type [String, nil] button type (default +"button"+; not set with +as_child:+)
    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(as_child: false, type: nil, **attrs)
      @as_child = as_child
      @type = type
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      defaults = { data: { slot: "attachment-trigger" } }
      defaults[:type] = @type || "button" unless @as_child
      attrs = merge_attrs(defaults, @attrs.except(:class))
      attrs = attrs.merge(class: [ @slot_class, cn(CLASS_NAME, @attrs[:class]) ].reject_blank.join(" "))
      return render_as_child(@as_child, **attrs, &) if @as_child

      button(**attrs, &)
    end
  end
end
