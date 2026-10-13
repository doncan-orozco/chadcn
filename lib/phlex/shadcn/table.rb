# frozen_string_literal: true

# shadcn Table (new-york-v4). Spec: docs/shadcn-port/specs/table.md. Static: no controller.
# Attrs go to the inner table element; the container div takes none.
class Phlex::Shadcn::Table < Phlex::Shadcn::Base
  CONTAINER_CLASS = "relative w-full overflow-x-auto"
  CLASS_NAME = "w-full caption-bottom text-sm"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&block)
    div(data: { slot: "table-container" }, class: CONTAINER_CLASS) do
      table(**merge_attrs({ data: { slot: "table" }, class: CLASS_NAME }, @attrs)) { yield self if block }
    end
  end

  class Header < Phlex::Shadcn::Base
    CLASS_NAME = "[&_tr]:border-b"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      thead(**merge_attrs({ data: { slot: "table-header" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Body < Phlex::Shadcn::Base
    CLASS_NAME = "[&_tr:last-child]:border-0"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      tbody(**merge_attrs({ data: { slot: "table-body" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Footer < Phlex::Shadcn::Base
    CLASS_NAME = "border-t bg-muted/50 font-medium [&>tr]:last:border-b-0"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      tfoot(**merge_attrs({ data: { slot: "table-footer" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Row < Phlex::Shadcn::Base
    CLASS_NAME = "border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-[state=selected]:bg-muted"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      tr(**merge_attrs({ data: { slot: "table-row" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Head < Phlex::Shadcn::Base
    CLASS_NAME = "h-10 px-2 text-left align-middle font-medium whitespace-nowrap text-foreground [&:has([role=checkbox])]:pr-0 [&>[role=checkbox]]:translate-y-[2px]"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      th(**merge_attrs({ data: { slot: "table-head" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Cell < Phlex::Shadcn::Base
    CLASS_NAME = "p-2 align-middle whitespace-nowrap [&:has([role=checkbox])]:pr-0 [&>[role=checkbox]]:translate-y-[2px]"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      td(**merge_attrs({ data: { slot: "table-cell" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Caption < Phlex::Shadcn::Base
    CLASS_NAME = "mt-4 text-sm text-muted-foreground"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      caption(**merge_attrs({ data: { slot: "table-caption" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
