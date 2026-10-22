# frozen_string_literal: true

# shadcn Kbd: a keyboard key cap (+kbd+), optionally grouped with {Kbd::Group}.
#
# @example
#   Chadcn::Kbd.new { "Esc" }
#
# @!method group(**attrs, &block)
#   Renders {Kbd::Group}; same as +render Kbd::Group.new(**attrs), &block+.
#   @return [void]
class Chadcn::Kbd < Chadcn::Base
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  CLASS_NAME = "pointer-events-none inline-flex h-5 w-fit min-w-5 items-center justify-center gap-1 rounded-sm bg-muted px-1 font-sans text-xs font-medium text-muted-foreground select-none [&_svg:not([class*='size-'])]:size-3 [[data-slot=tooltip-content]_&]:bg-background/20 [[data-slot=tooltip-content]_&]:text-background dark:[[data-slot=tooltip-content]_&]:bg-background/10"

  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # Renders the element; yields +self+ so the parts can be composed with the generated helpers (+kbd.group { ... }+).
  # The block is skipped when none is given.
  #
  # @yieldparam kbd [Chadcn::Kbd] the component itself
  # @return [void]
  def view_template(&block)
    kbd(**merge_attrs({ data: { slot: "kbd" }, class: CLASS_NAME }, @attrs)) { yield self if block }
  end

  # Lays several {Kbd} keys out in a row (a shortcut).
  class Group < Chadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "inline-flex items-center gap-1"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      kbd(**merge_attrs({ data: { slot: "kbd-group" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
