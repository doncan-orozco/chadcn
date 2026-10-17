# frozen_string_literal: true

# shadcn Card: a bordered surface. Compose with {Card::Header}, {Card::Title}, {Card::Description}, {Card::Action}, {Card::Content} and {Card::Footer}.
#
# @example
#   Phlex::Shadcn::Card.new { |card| card.header { card.title { "Plan" } }; card.content { "Body" } }
#
# @!method header(**attrs, &block)
#   Renders {Card::Header}; same as +render Card::Header.new(**attrs), &block+.
#   @return [void]
#
# @!method title(**attrs, &block)
#   Renders {Card::Title}; same as +render Card::Title.new(**attrs), &block+.
#   @return [void]
#
# @!method description(**attrs, &block)
#   Renders {Card::Description}; same as +render Card::Description.new(**attrs), &block+.
#   @return [void]
#
# @!method action(**attrs, &block)
#   Renders {Card::Action}; same as +render Card::Action.new(**attrs), &block+.
#   @return [void]
#
# @!method content(**attrs, &block)
#   Renders {Card::Content}; same as +render Card::Content.new(**attrs), &block+.
#   @return [void]
#
# @!method footer(**attrs, &block)
#   Renders {Card::Footer}; same as +render Card::Footer.new(**attrs), &block+.
#   @return [void]
class Phlex::Shadcn::Card < Phlex::Shadcn::Base
  # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  CLASS_NAME = "flex flex-col gap-6 rounded-xl border bg-card py-6 text-card-foreground shadow-sm"

  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # Renders the element; yields +self+ so the parts can be composed with the generated helpers (+card.title { ... }+).
  # The block is skipped when none is given.
  #
  # @yieldparam card [Phlex::Shadcn::Card] the component itself
  # @return [void]
  def view_template(&block)
    div(**merge_attrs({ data: { slot: "card" }, class: CLASS_NAME }, @attrs)) { yield self if block }
  end

  # Top section: places the title, description and an optional {Card::Action} on a grid.
  class Header < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "@container/card-header grid auto-rows-min grid-rows-[auto_auto] items-start gap-2 px-6 has-data-[slot=card-action]:grid-cols-[1fr_auto] [.border-b]:pb-6"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-header" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # The card title.
  class Title < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "leading-none font-semibold"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-title" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Muted supporting text under the title.
  class Description < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "text-sm text-muted-foreground"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-description" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Top-right slot of the header (a button, a menu trigger).
  class Action < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "col-start-2 row-span-2 row-start-1 self-start justify-self-end"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-action" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # The card body.
  class Content < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "px-6"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # Bottom row, typically actions.
  class Footer < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "flex items-center px-6 [.border-t]:pt-6"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-footer" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
