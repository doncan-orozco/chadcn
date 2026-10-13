# frozen_string_literal: true

# shadcn Pagination (new-york-v4). Spec: docs/shadcn-port/specs/pagination.md. Static: no controller.
class Phlex::Shadcn::Pagination < Phlex::Shadcn::Base
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&block)
    defaults = { role: "navigation", aria: { label: "pagination" }, data: { slot: "pagination" },
                 class: "mx-auto flex w-full justify-center" }
    nav(**merge_attrs(defaults, @attrs)) { yield self if block }
  end

  class Content < Phlex::Shadcn::Base
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      ul(**merge_attrs({ data: { slot: "pagination-content" }, class: "flex flex-row items-center gap-1" }, @attrs), &)
    end
  end

  class Item < Phlex::Shadcn::Base
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # The React part does not destructure className: the caller class is emitted verbatim, not through cn.
    def view_template(&)
      li(**{ data: { slot: "pagination-item" } }.deep_merge(canonical_attrs(@attrs)), &)
    end
  end

  class Link < Phlex::Shadcn::Base
    def initialize(is_active: nil, size: "icon", **attrs)
      @is_active = is_active
      @size = size || "icon"
      @attrs = attrs
      super()
    end

    def view_template(&)
      # Tri-state like React: nil emits no data-active, false emits "false".
      state = { aria: { current: ("page" if @is_active) }, data: { slot: "pagination-link", active: @is_active } }
      klass = Phlex::Shadcn::Button.variants(variant: @is_active ? "outline" : "ghost", size: @size, class: @attrs[:class])
      attrs = canonical_attrs(state).deep_merge(canonical_attrs(@attrs.except(:class)))
      a(**attrs.merge(class: klass), &)
    end
  end

  class Previous < Phlex::Shadcn::Base
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template
      attrs = merge_attrs({ aria: { label: "Go to previous page" }, size: "default", class: "gap-1 px-2.5 sm:pl-2.5" }, @attrs)
      render Phlex::Shadcn::Pagination::Link.new(**attrs) do
        render Phlex::Shadcn::Icon.new("chevron-left")
        span(class: "hidden sm:block") { plain "Previous" }
      end
    end
  end

  class Next < Phlex::Shadcn::Base
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template
      attrs = merge_attrs({ aria: { label: "Go to next page" }, size: "default", class: "gap-1 px-2.5 sm:pr-2.5" }, @attrs)
      render Phlex::Shadcn::Pagination::Link.new(**attrs) do
        span(class: "hidden sm:block") { plain "Next" }
        render Phlex::Shadcn::Icon.new("chevron-right")
      end
    end
  end

  class Ellipsis < Phlex::Shadcn::Base
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template
      defaults = { aria: { hidden: "true" }, data: { slot: "pagination-ellipsis" }, class: "flex size-9 items-center justify-center" }
      span(**merge_attrs(defaults, @attrs)) do
        render Phlex::Shadcn::Icon.new("ellipsis", class: "size-4")
        span(class: "sr-only") { plain "More pages" }
      end
    end
  end
end
