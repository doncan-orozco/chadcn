# frozen_string_literal: true

# shadcn `Item` (new-york-v4) and its parts. Spec: docs/shadcn-port/specs/item.md. Static: no controller.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::Item < Phlex::Shadcn::Base
  BASE = "group/item flex flex-wrap items-center rounded-md border border-transparent text-sm transition-colors duration-100 outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 [a]:transition-colors [a]:hover:bg-accent/50"

  VARIANTS = {
    "default" => "bg-transparent",
    "outline" => "border-border",
    "muted" => "bg-muted/50"
  }.freeze

  SIZES = {
    "default" => "gap-4 p-4",
    "sm" => "gap-2.5 px-4 py-3"
  }.freeze

  # React `itemVariants`.
  def self.variants(variant: "default", size: "default", class: nil)
    new(variant: variant, size: size).send(:classes, binding.local_variable_get(:class))
  end

  def initialize(variant: "default", size: "default", as_child: false, **attrs)
    @variant = normalize_option(variant) || "default"
    @size = normalize_option(size) || "default"
    raise ArgumentError, "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})" unless VARIANTS.key?(@variant)
    raise ArgumentError, "unknown size: #{size.inspect} (expected one of #{SIZES.keys.join(', ')})" unless SIZES.key?(@size)

    @as_child = as_child
    @attrs = attrs
  end

  def view_template(&block)
    attrs = merge_attrs({ data: { slot: "item", variant: @variant, size: @size } }, @attrs.except(:class))
    attrs = attrs.merge(class: [ @slot_class, classes(@attrs[:class]) ].reject_blank.join(" "))
    return render_as_child(@as_child, **attrs) { yield self if block } if @as_child

    div(**attrs) { yield self if block }
  end

  private

  def classes(extra) = cn(BASE, VARIANTS[@variant], SIZES[@size], extra)

  class Media < Phlex::Shadcn::Base
    BASE = "flex shrink-0 items-center justify-center gap-2 group-has-[[data-slot=item-description]]/item:translate-y-0.5 group-has-[[data-slot=item-description]]/item:self-start [&_svg]:pointer-events-none"

    VARIANTS = {
      "default" => "bg-transparent",
      "icon" => "size-8 rounded-sm border bg-muted [&_svg:not([class*='size-'])]:size-4",
      "image" => "size-10 overflow-hidden rounded-sm [&_img]:size-full [&_img]:object-cover"
    }.freeze

    # React `itemMediaVariants`.
    def self.variants(variant: "default", class: nil)
      new(variant: variant).send(:classes, binding.local_variable_get(:class))
    end

    def initialize(variant: "default", **attrs)
      @variant = normalize_option(variant) || "default"
      unless VARIANTS.key?(@variant)
        raise ArgumentError,
              "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})"
      end

      @attrs = attrs
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-media", variant: @variant }, class: classes(nil) }, @attrs), &)
    end

    private

    def classes(extra) = cn(BASE, VARIANTS[@variant], extra)
  end

  class Content < Phlex::Shadcn::Base
    CLASS_NAME = "flex flex-1 flex-col gap-1 [&+[data-slot=item-content]]:flex-none"

    def initialize(**attrs)
      @attrs = attrs
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Actions < Phlex::Shadcn::Base
    CLASS_NAME = "flex items-center gap-2"

    def initialize(**attrs)
      @attrs = attrs
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-actions" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Group < Phlex::Shadcn::Base
    CLASS_NAME = "group/item-group flex flex-col"

    def initialize(**attrs)
      @attrs = attrs
    end

    def view_template(&)
      div(**merge_attrs({ role: "list", data: { slot: "item-group" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Title < Phlex::Shadcn::Base
    CLASS_NAME = "flex w-fit items-center gap-2 text-sm leading-snug font-medium"

    def initialize(**attrs)
      @attrs = attrs
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-title" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Description < Phlex::Shadcn::Base
    CLASS_NAME = "line-clamp-2 text-sm leading-normal font-normal text-balance text-muted-foreground [&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary"

    def initialize(**attrs)
      @attrs = attrs
    end

    def view_template(&)
      p(**merge_attrs({ data: { slot: "item-description" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Header < Phlex::Shadcn::Base
    CLASS_NAME = "flex basis-full items-center justify-between gap-2"

    def initialize(**attrs)
      @attrs = attrs
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-header" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Footer < Phlex::Shadcn::Base
    CLASS_NAME = "flex basis-full items-center justify-between gap-2"

    def initialize(**attrs)
      @attrs = attrs
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "item-footer" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Separator < Phlex::Shadcn::Base
    def initialize(**attrs)
      @attrs = attrs
    end

    def view_template
      render Phlex::Shadcn::Separator.new(**merge_attrs({ data: { slot: "item-separator" }, orientation: "horizontal", class: "my-0" },
                                                        @attrs))
    end
  end
end
