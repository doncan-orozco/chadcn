# frozen_string_literal: true

# shadcn `ButtonGroup` (new-york-v4). Spec: docs/shadcn-port/specs/button-group.md. Static: no controller.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::ButtonGroup < Phlex::Shadcn::Base
  BASE = "flex w-fit items-stretch has-[>[data-slot=button-group]]:gap-2 [&>*]:focus-visible:relative [&>*]:focus-visible:z-10 has-[select[aria-hidden=true]:last-child]:[&>[data-slot=select-trigger]:last-of-type]:rounded-r-md [&>[data-slot=select-trigger]:not([class*='w-'])]:w-fit [&>input]:flex-1"

  ORIENTATIONS = {
    "horizontal" => "[&>*:not(:first-child)]:rounded-l-none [&>*:not(:first-child)]:border-l-0 [&>*:not(:last-child)]:rounded-r-none",
    "vertical" => "flex-col [&>*:not(:first-child)]:rounded-t-none [&>*:not(:first-child)]:border-t-0 [&>*:not(:last-child)]:rounded-b-none"
  }.freeze

  # React `buttonGroupVariants`: nil uses the default, an unknown value yields no orientation classes (cva semantics).
  def self.variants(orientation: "horizontal", class: nil)
    new.send(:cn, BASE, ORIENTATIONS[(orientation || "horizontal").to_s], binding.local_variable_get(:class))
  end

  def initialize(orientation: nil, **attrs)
    @orientation = orientation
    @attrs = attrs
    super()
  end

  def view_template(&block)
    defaults = { role: "group", data: { slot: "button-group", orientation: @orientation&.to_s }.compact,
                 class: self.class.variants(orientation: @orientation) }
    div(**merge_attrs(defaults, @attrs)) { yield self if block }
  end

  class Separator < Phlex::Shadcn::Base
    CLASS_NAME = "relative m-0! self-stretch bg-input data-[orientation=vertical]:h-auto"

    def initialize(orientation: "vertical", **attrs)
      @orientation = orientation
      @attrs = attrs
      super()
    end

    def view_template(&)
      attrs = merge_attrs({ data: { slot: "button-group-separator" }, class: CLASS_NAME }, @attrs)
      render Phlex::Shadcn::Separator.new(orientation: @orientation, **attrs), &
    end
  end

  class Text < Phlex::Shadcn::Base
    CLASS_NAME = "flex items-center gap-2 rounded-md border bg-muted px-4 text-sm font-medium shadow-xs [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4"

    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    def view_template(&)
      attrs = merge_attrs({}, @attrs.except(:class))
      attrs = attrs.merge(class: [ @slot_class, cn(CLASS_NAME, @attrs[:class]) ].reject_blank.join(" "))
      return render_as_child(@as_child, **attrs, &) if @as_child

      div(**attrs, &)
    end
  end
end
