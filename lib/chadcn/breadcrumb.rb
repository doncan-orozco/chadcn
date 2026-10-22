# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn Breadcrumb (new-york-v4). Spec: docs/shadcn-port/specs/breadcrumb.md. Static: no controller.
#
# Root `nav`. Yields itself, so the parts are yielded-root helpers (`list`, `item`, `link`, `page`, `separator`,
# `ellipsis`) equal to rendering `Breadcrumb::List`, `Breadcrumb::Item`, etc.
#
# @example
#   render Chadcn::Breadcrumb.new do |bc|
#     bc.list do
#       bc.item { bc.link(href: "/") { "Home" } }
#       bc.separator
#       bc.item { bc.page { "Current" } }
#     end
#   end
class Chadcn::Breadcrumb < Chadcn::Base
  # @param attrs [Hash] HTML attributes for the `nav` (the `class` is emitted verbatim)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # The React root does not destructure className: the caller class is emitted verbatim, not through cn.
  #
  # @yieldparam breadcrumb [Chadcn::Breadcrumb] the root, exposing the part helpers
  # @return [void]
  def view_template(&block)
    attrs = { aria: { label: "breadcrumb" }, data: { slot: "breadcrumb" } }.merge_deep(canonical_attrs(@attrs))
    nav(**attrs) { yield self if block }
  end

  # The `ol` that holds the items.
  class List < Chadcn::Base
    # Default Tailwind classes of the list.
    #
    # @api private
    CLASS_NAME = "flex flex-wrap items-center gap-1.5 text-sm break-words text-muted-foreground sm:gap-2.5"

    # @param attrs [Hash] HTML attributes merged onto the element
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @yield the content of the element
    # @return [void]
    def view_template(&)
      ol(**merge_attrs({ data: { slot: "breadcrumb-list" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # An `li` wrapping a link, the current page or an ellipsis.
  class Item < Chadcn::Base
    # Default Tailwind classes of the item.
    #
    # @api private
    CLASS_NAME = "inline-flex items-center gap-1.5"

    # @param attrs [Hash] HTML attributes merged onto the element
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @yield the content of the element
    # @return [void]
    def view_template(&)
      li(**merge_attrs({ data: { slot: "breadcrumb-item" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  # An `a` to an ancestor page.
  #
  # @example
  #   bc.link(href: "/docs") { "Docs" }
  class Link < Chadcn::Base
    # Default Tailwind classes of the link.
    #
    # @api private
    CLASS_NAME = "transition-colors hover:text-foreground"

    # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
    #   the part's attributes are merged onto it. `true` is not supported.
    # @param attrs [Hash] HTML attributes merged onto the element
    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # @yield the content of the element
    # @return [void]
    def view_template(&)
      attrs = merge_attrs({ data: { slot: "breadcrumb-link" }, class: CLASS_NAME }, @attrs)
      if @as_child
        render_as_child(@as_child, **attrs, &)
      else
        a(**attrs, &)
      end
    end
  end

  # The current page: a `span` with `aria-current="page"`.
  class Page < Chadcn::Base
    # Default Tailwind classes of the current page.
    #
    # @api private
    CLASS_NAME = "font-normal text-foreground"

    # @param attrs [Hash] HTML attributes merged onto the element
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @yield the content of the element
    # @return [void]
    def view_template(&)
      defaults = { data: { slot: "breadcrumb-page" }, role: "link", aria: { disabled: "true", current: "page" }, class: CLASS_NAME }
      span(**merge_attrs(defaults, @attrs), &)
    end
  end

  # An `li` separator; renders a chevron icon when the block is missing or emits nothing.
  class Separator < Chadcn::Base
    # Default Tailwind classes of the separator.
    #
    # @api private
    CLASS_NAME = "[&>svg]:size-3.5"

    # @param attrs [Hash] HTML attributes merged onto the element
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @yield the content of the element
    # @return [void]
    def view_template(&block)
      defaults = { data: { slot: "breadcrumb-separator" }, role: "presentation", aria: { hidden: "true" }, class: CLASS_NAME }
      # React renders the icon when children is nullish; a block that emits nothing counts as nullish here.
      content = block ? capture(&block) : ""
      li(**merge_attrs(defaults, @attrs)) do
        if content.blank_value?
          render Chadcn::Icon.new("chevron-right")
        else
          raw(safe(content))
        end
      end
    end
  end

  # A collapsed-items marker: ellipsis icon plus a screen-reader label.
  class Ellipsis < Chadcn::Base
    # Default Tailwind classes of the ellipsis.
    #
    # @api private
    CLASS_NAME = "flex size-9 items-center justify-center"

    # @param label [String] screen-reader text
    # @param attrs [Hash] HTML attributes merged onto the element
    def initialize(label: "More", **attrs)
      @label = label
      @attrs = attrs
      super()
    end

    # @return [void]
    def view_template
      defaults = { data: { slot: "breadcrumb-ellipsis" }, role: "presentation", aria: { hidden: "true" }, class: CLASS_NAME }
      span(**merge_attrs(defaults, @attrs)) do
        render Chadcn::Icon.new("ellipsis", class: "size-4")
        span(class: "sr-only") { plain @label }
      end
    end
  end
end
