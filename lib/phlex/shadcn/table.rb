# frozen_string_literal: true

# shadcn Table. The container +div+ is fixed; attributes go to the inner +table+. Compose with {Table::Header}, {Table::Body}, {Table::Footer},
# {Table::Row}, {Table::Head}, {Table::Cell} and {Table::Caption}.
#
# @example
#   Phlex::Shadcn::Table.new { |t| t.header { t.row { t.head { "Name" } } }; t.body { t.row { t.cell { "Ada" } } } }
#
# @!method header(**attrs, &block)
#   Renders {Table::Header}; same as +render Table::Header.new(**attrs), &block+.
#   @return [void]
#
# @!method body(**attrs, &block)
#   Renders {Table::Body}; same as +render Table::Body.new(**attrs), &block+.
#   @return [void]
#
# @!method footer(**attrs, &block)
#   Renders {Table::Footer}; same as +render Table::Footer.new(**attrs), &block+.
#   @return [void]
#
# @!method row(**attrs, &block)
#   Renders {Table::Row}; same as +render Table::Row.new(**attrs), &block+.
#   @return [void]
#
# @!method head(**attrs, &block)
#   Renders {Table::Head}; same as +render Table::Head.new(**attrs), &block+.
#   @return [void]
#
# @!method cell(**attrs, &block)
#   Renders {Table::Cell}; same as +render Table::Cell.new(**attrs), &block+.
#   @return [void]
#
# @!method caption(**attrs, &block)
#   Renders {Table::Caption}; same as +render Table::Caption.new(**attrs), &block+.
#   @return [void]
class Phlex::Shadcn::Table < Phlex::Shadcn::Base
  # Tailwind classes of the wrapper +div+; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  CONTAINER_CLASS = "relative w-full overflow-x-auto"
  # Tailwind classes of the inner +table+; they are the DOM contract, not part of the Ruby API.
  #
  # @api private
  CLASS_NAME = "w-full caption-bottom text-sm"

  # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # Renders the element; yields +self+ so the parts can be composed with the generated helpers (+table.row { ... }+).
  # The block is skipped when none is given.
  #
  # @yieldparam table [Phlex::Shadcn::Table] the component itself
  # @return [void]
  def view_template(&block)
    div(data: { slot: "table-container" }, class: CONTAINER_CLASS) do
      table(**merge_attrs({ data: { slot: "table" }, class: CLASS_NAME }, @attrs)) { yield self if block }
    end
  end

  # +thead+.
  class Header < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "[&_tr]:border-b"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      thead(**merge_attrs({ data: { slot: "table-header" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # +tbody+.
  class Body < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "[&_tr:last-child]:border-0"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      tbody(**merge_attrs({ data: { slot: "table-body" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # +tfoot+.
  class Footer < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "border-t bg-muted/50 font-medium [&>tr]:last:border-b-0"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      tfoot(**merge_attrs({ data: { slot: "table-footer" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # +tr+; use +data-state="selected"+ to highlight it.
  class Row < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-[state=selected]:bg-muted"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      tr(**merge_attrs({ data: { slot: "table-row" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # +th+ (column heading).
  class Head < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "h-10 px-2 text-left align-middle font-medium whitespace-nowrap text-foreground [&:has([role=checkbox])]:pr-0 [&>[role=checkbox]]:translate-y-[2px]"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      th(**merge_attrs({ data: { slot: "table-head" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # +td+.
  class Cell < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "p-2 align-middle whitespace-nowrap [&:has([role=checkbox])]:pr-0 [&>[role=checkbox]]:translate-y-[2px]"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      td(**merge_attrs({ data: { slot: "table-cell" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # +caption+, shown below the table.
  class Caption < Phlex::Shadcn::Base
    # Tailwind classes of the element; they are the DOM contract, not part of the Ruby API.
    #
    # @api private
    CLASS_NAME = "mt-4 text-sm text-muted-foreground"

    # @param attrs [Hash] extra HTML attributes; +class+ is merged with the defaults (Tailwind conflicts resolved, yours win), +data+/+aria+ are deep-merged
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Renders the element with the block as its content.
    #
    # @return [void]
    def view_template(&)
      caption(**merge_attrs({ data: { slot: "table-caption" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
