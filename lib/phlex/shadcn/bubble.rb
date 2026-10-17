# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# shadcn Bubble: one chat bubble. Compose with {Bubble::Content}, {Bubble::Group} and {Bubble::Reactions}.
#
# @example
#   Phlex::Shadcn::Bubble.new(variant: :muted, align: :end) { |bubble| bubble.content { "Hello" } }
#
# @!method group(**attrs, &block)
#   Renders {Bubble::Group}; same as +render Bubble::Group.new(**attrs), &block+.
#   @return [void]
#
# @!method content(**attrs, &block)
#   Renders {Bubble::Content}; same as +render Bubble::Content.new(**attrs), &block+.
#   @return [void]
#
# @!method reactions(**attrs, &block)
#   Renders {Bubble::Reactions}; same as +render Bubble::Reactions.new(**attrs), &block+.
#   @return [void]
class Phlex::Shadcn::Bubble < Phlex::Shadcn::Base
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  BASE = "group/bubble relative flex w-fit max-w-[80%] min-w-0 flex-col gap-1 group-data-[align=end]/message:self-end data-[align=end]:self-end data-[variant=ghost]:max-w-full"

  # Accepted +variant+ values and the Tailwind classes each one adds.
  VARIANTS = {
    "default" => "*:data-[slot=bubble-content]:bg-primary *:data-[slot=bubble-content]:text-primary-foreground [&>[data-slot=bubble-content]:is(button,a):hover]:bg-primary/80",
    "secondary" => "*:data-[slot=bubble-content]:bg-secondary *:data-[slot=bubble-content]:text-secondary-foreground [&>[data-slot=bubble-content]:is(button,a):hover]:bg-[color-mix(in_oklch,var(--secondary),var(--foreground)_5%)]",
    "muted" => "*:data-[slot=bubble-content]:bg-muted [&>[data-slot=bubble-content]:is(button,a):hover]:bg-[color-mix(in_oklch,var(--muted),var(--foreground)_5%)]",
    "tinted" => "*:data-[slot=bubble-content]:bg-[oklch(from_var(--primary)_0.93_calc(c*0.4)_h)] *:data-[slot=bubble-content]:text-foreground dark:*:data-[slot=bubble-content]:bg-[oklch(from_var(--primary)_0.3_calc(c*0.4)_h)] [&>[data-slot=bubble-content]:is(button,a):hover]:bg-[oklch(from_var(--primary)_0.88_calc(c*0.5)_h)] dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-[oklch(from_var(--primary)_0.35_calc(c*0.5)_h)]",
    "outline" => "*:data-[slot=bubble-content]:border-border *:data-[slot=bubble-content]:bg-background [&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted [&>[data-slot=bubble-content]:is(button,a):hover]:text-foreground dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-input/30",
    "ghost" => "border-none *:data-[slot=bubble-content]:rounded-none *:data-[slot=bubble-content]:bg-transparent *:data-[slot=bubble-content]:p-0 [&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted [&>[data-slot=bubble-content]:is(button,a):hover]:text-foreground dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted/50",
    "destructive" => "*:data-[slot=bubble-content]:bg-destructive/10 *:data-[slot=bubble-content]:text-destructive dark:*:data-[slot=bubble-content]:bg-destructive/20 [&>[data-slot=bubble-content]:is(button,a):hover]:bg-destructive/20 dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-destructive/30"
  }.freeze

  # Accepted +align+ values.
  ALIGNS = %w[start end].freeze

  # Normalizes and validates a variant-like option; shared by the bubble parts.
  #
  # @api private
  def self.fetch_option!(value, default, allowed, name)
    option = value&.to_s&.tr("_", "-") || default
    raise ArgumentError, "unknown #{name}: #{value.inspect} (expected one of #{allowed.join(', ')})" unless allowed.include?(option)

    option
  end

  # @param variant [String, Symbol] one of the keys of {VARIANTS} (underscores read as dashes)
  # @param align [String, Symbol] one of {ALIGNS}
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  # @raise [ArgumentError] on an unknown variant
  # @raise [ArgumentError] on an unknown align
  def initialize(variant: "default", align: "start", **attrs)
    @variant = self.class.fetch_option!(variant, "default", VARIANTS.keys, "variant")
    @align = self.class.fetch_option!(align, "start", ALIGNS, "align")
    @attrs = attrs
    super()
  end

  # Renders the element; yields +self+ so the parts can be composed with the generated helpers (+bubble.content { ... }+).
  # The block is skipped when none is given.
  #
  # @yieldparam bubble [Phlex::Shadcn::Bubble] the component itself
  # @return [void]
  def view_template(&block)
    defaults = { data: { slot: "bubble", variant: @variant, align: @align }, class: cn(BASE, VARIANTS[@variant]) }
    div(**merge_attrs(defaults, @attrs)) { yield self if block }
  end

  # Stacks consecutive bubbles of the same sender.
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
      div(**merge_attrs({ data: { slot: "bubble-group" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # The bubble surface that holds the text. +as_child:+ renders it as a link or button.
  class Content < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "w-fit max-w-full min-w-0 overflow-hidden rounded-xl border border-transparent px-3 py-2 text-sm leading-relaxed wrap-break-word group-data-[align=end]/bubble:self-end [button]:text-left [button,a]:transition-colors [button,a]:outline-none [button,a]:focus-visible:border-ring [button,a]:focus-visible:ring-3 [button,a]:focus-visible:ring-ring/50"

    # @param as_child [Boolean, Symbol, Phlex::Shadcn::Base] render this element (a tag name or component instance) instead of the default one (Radix +asChild+)
    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      attrs = merge_attrs({ data: { slot: "bubble-content" }, class: CLASS_NAME }, @attrs.except(:class))
      attrs = attrs.merge(class: [ @slot_class, cn(CLASS_NAME, @attrs[:class]) ].reject_blank.join(" "))
      return render_as_child(@as_child, **attrs, &) if @as_child

      div(**attrs, &)
    end
  end

  # The reaction pill that overlaps the bubble edge.
  class Reactions < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    BASE = "absolute z-10 flex w-fit shrink-0 items-center justify-center gap-1 rounded-full bg-muted px-1.5 py-0.5 text-sm ring-3 ring-card has-[button]:p-0"
    # Accepted +side+ values and the Tailwind classes each one adds.
    SIDES = { "top" => "top-0 -translate-y-3/4", "bottom" => "bottom-0 translate-y-3/4" }.freeze
    # Accepted +align+ values.
    ALIGNS = { "start" => "left-3", "end" => "right-3" }.freeze

    # @param side [String, Symbol] +top+ or +bottom+
    # @param align [String, Symbol] one of the keys of {ALIGNS}
    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    # @raise [ArgumentError] on an unknown side
    # @raise [ArgumentError] on an unknown align
    def initialize(side: "bottom", align: "end", **attrs)
      @side = Phlex::Shadcn::Bubble.fetch_option!(side, "bottom", SIDES.keys, "side")
      @align = Phlex::Shadcn::Bubble.fetch_option!(align, "end", ALIGNS.keys, "align")
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      defaults = { data: { slot: "bubble-reactions", align: @align, side: @side }, class: cn(BASE, SIDES[@side], ALIGNS[@align]) }
      div(**merge_attrs(defaults, @attrs), &)
    end
  end
end
