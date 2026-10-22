# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn Pagination (new-york-v4). Spec: docs/shadcn-port/specs/pagination.md. Static: no controller.
#
# Root `nav`. Yields itself, so the parts are yielded-root helpers (`content`, `item`, `link`, `previous`, `next`,
# `ellipsis`) equal to rendering `Pagination::Content`, `Pagination::Item`, etc.
#
# @example
#   render Chadcn::Pagination.new do |pg|
#     pg.content do
#       pg.item { pg.previous(href: "?page=1") }
#       pg.item { pg.link(href: "?page=2", is_active: true) { "2" } }
#       pg.item { pg.next(href: "?page=3") }
#     end
#   end
class Chadcn::Pagination < Chadcn::Base
  # @param attrs [Hash] HTML attributes merged onto the `nav`
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yieldparam pagination [Chadcn::Pagination] the root, exposing the part helpers
  # @return [void]
  def view_template(&block)
    defaults = { role: "navigation", aria: { label: "pagination" }, data: { slot: "pagination" },
                 class: "mx-auto flex w-full justify-center" }
    nav(**merge_attrs(defaults, @attrs)) { yield self if block }
  end

  # The `ul` that holds the items.
  class Content < Chadcn::Base
    # @param attrs [Hash] HTML attributes merged onto the element
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @yield the content of the element
    # @return [void]
    def view_template(&)
      ul(**merge_attrs({ data: { slot: "pagination-content" }, class: "flex flex-row items-center gap-1" }, @attrs), &)
    end
  end

  # An `li` wrapping a link, previous/next or an ellipsis.
  class Item < Chadcn::Base
    # @param attrs [Hash] HTML attributes merged onto the element
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # The React part does not destructure className: the caller class is emitted verbatim, not through cn.
    #
    # @yield the content of the element
    # @return [void]
    def view_template(&)
      li(**{ data: { slot: "pagination-item" } }.merge_deep(canonical_attrs(@attrs)), &)
    end
  end

  # A page link, styled as a ghost (or outline when active) button.
  #
  # @example
  #   pg.link(href: "?page=2", is_active: true) { "2" }
  class Link < Chadcn::Base
    # @param is_active [Boolean, nil] tri-state: true marks the current page, false emits `data-active="false"`, nil emits nothing
    # @param size [String, Symbol] Button size variant (`"icon"` by default)
    # @param attrs [Hash] HTML attributes for the `a` (`class:` is merged into the Button variant classes)
    def initialize(is_active: nil, size: "icon", **attrs)
      @is_active = is_active
      @size = size || "icon"
      @attrs = attrs
      super()
    end

    # @yield the content of the element
    # @return [void]
    def view_template(&)
      # Tri-state like React: nil emits no data-active, false emits "false".
      state = { aria: { current: ("page" if @is_active) }, data: { slot: "pagination-link", active: @is_active } }
      klass = Chadcn::Button.variants(variant: @is_active ? "outline" : "ghost", size: @size, class: @attrs[:class])
      attrs = canonical_attrs(state).merge_deep(canonical_attrs(@attrs.except(:class)))
      a(**attrs.merge(class: klass), &)
    end
  end

  # Link to the previous page (chevron plus "Previous" label).
  #
  # @example
  #   pg.item { pg.previous(href: "?page=1") }
  class Previous < Chadcn::Base
    # @param label [String] visible text (default: "Previous")
    # @param aria_label [String] accessible name of the link (default: "Go to previous page")
    # @param attrs [Hash] HTML attributes merged onto the element
    def initialize(label: "Previous", aria_label: "Go to previous page", **attrs)
      @label = label
      @aria_label = aria_label
      @attrs = attrs
      super()
    end

    # @return [void]
    def view_template
      attrs = merge_attrs({ aria: { label: @aria_label }, size: "default", class: "gap-1 px-2.5 sm:pl-2.5" }, @attrs)
      render Chadcn::Pagination::Link.new(**attrs) do
        render Chadcn::Icon.new("chevron-left")
        span(class: "hidden sm:block") { plain @label }
      end
    end
  end

  # Link to the next page ("Next" label plus chevron).
  #
  # @example
  #   pg.item { pg.next(href: "?page=3") }
  class Next < Chadcn::Base
    # @param label [String] visible text (default: "Next")
    # @param aria_label [String] accessible name of the link (default: "Go to next page")
    # @param attrs [Hash] HTML attributes merged onto the element
    def initialize(label: "Next", aria_label: "Go to next page", **attrs)
      @label = label
      @aria_label = aria_label
      @attrs = attrs
      super()
    end

    # @return [void]
    def view_template
      attrs = merge_attrs({ aria: { label: @aria_label }, size: "default", class: "gap-1 px-2.5 sm:pr-2.5" }, @attrs)
      render Chadcn::Pagination::Link.new(**attrs) do
        span(class: "hidden sm:block") { plain @label }
        render Chadcn::Icon.new("chevron-right")
      end
    end
  end

  # A collapsed-pages marker: ellipsis icon plus a screen-reader label.
  class Ellipsis < Chadcn::Base
    # @param label [String] screen-reader text (default: "More pages")
    # @param attrs [Hash] HTML attributes merged onto the element
    def initialize(label: "More pages", **attrs)
      @label = label
      @attrs = attrs
      super()
    end

    # @return [void]
    def view_template
      defaults = { aria: { hidden: "true" }, data: { slot: "pagination-ellipsis" }, class: "flex size-9 items-center justify-center" }
      span(**merge_attrs(defaults, @attrs)) do
        render Chadcn::Icon.new("ellipsis", class: "size-4")
        span(class: "sr-only") { plain @label }
      end
    end
  end
end
