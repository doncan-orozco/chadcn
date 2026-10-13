# frozen_string_literal: true

# shadcn Breadcrumb (new-york-v4). Spec: docs/shadcn-port/specs/breadcrumb.md. Static: no controller.
class Phlex::Shadcn::Breadcrumb < Phlex::Shadcn::Base
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # The React root does not destructure className: the caller class is emitted verbatim, not through cn.
  def view_template(&block)
    attrs = { aria: { label: "breadcrumb" }, data: { slot: "breadcrumb" } }.deep_merge(canonical_attrs(@attrs))
    nav(**attrs) { yield self if block }
  end

  class List < Phlex::Shadcn::Base
    CLASS_NAME = "flex flex-wrap items-center gap-1.5 text-sm break-words text-muted-foreground sm:gap-2.5"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      ol(**merge_attrs({ data: { slot: "breadcrumb-list" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Item < Phlex::Shadcn::Base
    CLASS_NAME = "inline-flex items-center gap-1.5"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      li(**merge_attrs({ data: { slot: "breadcrumb-item" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Link < Phlex::Shadcn::Base
    CLASS_NAME = "transition-colors hover:text-foreground"

    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    def view_template(&)
      attrs = merge_attrs({ data: { slot: "breadcrumb-link" }, class: CLASS_NAME }, @attrs)
      if @as_child
        render_as_child(@as_child, **attrs, &)
      else
        a(**attrs, &)
      end
    end
  end

  class Page < Phlex::Shadcn::Base
    CLASS_NAME = "font-normal text-foreground"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      defaults = { data: { slot: "breadcrumb-page" }, role: "link", aria: { disabled: "true", current: "page" }, class: CLASS_NAME }
      span(**merge_attrs(defaults, @attrs), &)
    end
  end

  class Separator < Phlex::Shadcn::Base
    CLASS_NAME = "[&>svg]:size-3.5"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&block)
      defaults = { data: { slot: "breadcrumb-separator" }, role: "presentation", aria: { hidden: "true" }, class: CLASS_NAME }
      # React renders the icon when children is nullish; a block that emits nothing counts as nullish here.
      content = block ? capture(&block) : ""
      li(**merge_attrs(defaults, @attrs)) do
        if content.blank?
          render Phlex::Shadcn::Icon.new("chevron-right")
        else
          raw(safe(content))
        end
      end
    end
  end

  class Ellipsis < Phlex::Shadcn::Base
    CLASS_NAME = "flex size-9 items-center justify-center"

    def initialize(label: "More", **attrs)
      @label = label
      @attrs = attrs
      super()
    end

    def view_template
      defaults = { data: { slot: "breadcrumb-ellipsis" }, role: "presentation", aria: { hidden: "true" }, class: CLASS_NAME }
      span(**merge_attrs(defaults, @attrs)) do
        render Phlex::Shadcn::Icon.new("ellipsis", class: "size-4")
        span(class: "sr-only") { plain @label }
      end
    end
  end
end
