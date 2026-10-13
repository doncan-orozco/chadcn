# frozen_string_literal: true

# shadcn Card (new-york-v4). Spec: docs/shadcn-port/specs/card.md. Static: no controller.
class Phlex::Shadcn::Card < Phlex::Shadcn::Base
  CLASS_NAME = "flex flex-col gap-6 rounded-xl border bg-card py-6 text-card-foreground shadow-sm"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&block)
    div(**merge_attrs({ data: { slot: "card" }, class: CLASS_NAME }, @attrs)) { yield self if block }
  end

  class Header < Phlex::Shadcn::Base
    CLASS_NAME = "@container/card-header grid auto-rows-min grid-rows-[auto_auto] items-start gap-2 px-6 has-data-[slot=card-action]:grid-cols-[1fr_auto] [.border-b]:pb-6"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-header" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Title < Phlex::Shadcn::Base
    CLASS_NAME = "leading-none font-semibold"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-title" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Description < Phlex::Shadcn::Base
    CLASS_NAME = "text-sm text-muted-foreground"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-description" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Action < Phlex::Shadcn::Base
    CLASS_NAME = "col-start-2 row-span-2 row-start-1 self-start justify-self-end"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-action" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Content < Phlex::Shadcn::Base
    CLASS_NAME = "px-6"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Footer < Phlex::Shadcn::Base
    CLASS_NAME = "flex items-center px-6 [.border-t]:pt-6"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "card-footer" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
