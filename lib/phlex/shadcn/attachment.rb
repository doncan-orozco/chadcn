# frozen_string_literal: true

# shadcn Attachment (new-york-v4). Spec: docs/shadcn-port/specs/attachment.md. Static: no controller.
class Phlex::Shadcn::Attachment < Phlex::Shadcn::Base
  BASE = "group/attachment relative flex w-fit max-w-full min-w-0 shrink-0 flex-wrap rounded-xl border bg-card text-card-foreground transition-colors focus-within:ring-1 focus-within:ring-ring/50 has-[>a,>button]:hover:bg-muted/50 data-[state=error]:border-destructive/30 data-[state=idle]:border-dashed"

  SIZES = {
    "default" => "gap-2 text-sm has-data-[slot=attachment-content]:px-2.5 has-data-[slot=attachment-content]:py-2 has-data-[slot=attachment-media]:p-2",
    "sm" => "gap-2.5 text-xs has-data-[slot=attachment-content]:px-2 has-data-[slot=attachment-content]:py-1.5 has-data-[slot=attachment-media]:p-1.5",
    "xs" => "gap-1.5 rounded-lg text-xs has-data-[slot=attachment-content]:px-1.5 has-data-[slot=attachment-content]:py-1 has-data-[slot=attachment-media]:p-1"
  }.freeze

  ORIENTATIONS = {
    "horizontal" => "min-w-40 items-center",
    "vertical" => "w-24 flex-col has-data-[slot=attachment-content]:w-30"
  }.freeze

  STATES = %w[idle uploading processing error done].freeze

  def self.fetch_option!(value, default, allowed, name)
    option = value&.to_s&.tr("_", "-") || default
    raise ArgumentError, "unknown #{name}: #{value.inspect} (expected one of #{allowed.join(', ')})" unless allowed.include?(option)

    option
  end

  def initialize(state: "done", size: "default", orientation: "horizontal", **attrs)
    @state = self.class.fetch_option!(state, "done", STATES, "state")
    @size = self.class.fetch_option!(size, "default", SIZES.keys, "size")
    @orientation = self.class.fetch_option!(orientation, "horizontal", ORIENTATIONS.keys, "orientation")
    @attrs = attrs
    super()
  end

  def view_template(&block)
    defaults = {
      data: { slot: "attachment", state: @state, size: @size, orientation: @orientation },
      class: cn(BASE, SIZES[@size], ORIENTATIONS[@orientation])
    }
    div(**merge_attrs(defaults, @attrs)) { yield self if block }
  end

  class Group < Phlex::Shadcn::Base
    CLASS_NAME = "flex min-w-0 scroll-fade-x snap-x snap-mandatory scroll-px-1 scrollbar-none gap-3 overflow-x-auto overscroll-x-contain py-1 *:data-[slot=attachment]:flex-none *:data-[slot=attachment]:snap-start"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "attachment-group" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Media < Phlex::Shadcn::Base
    BASE = "relative flex aspect-square w-10 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-muted text-foreground group-data-[orientation=vertical]/attachment:w-full group-data-[size=sm]/attachment:w-8 group-data-[size=xs]/attachment:w-7 group-data-[size=xs]/attachment:rounded-md group-data-[state=error]/attachment:bg-destructive/10 group-data-[state=error]/attachment:text-destructive group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6! [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 group-data-[orientation=vertical]/attachment:[&_svg:not([class*='size-'])]:size-6 group-data-[size=xs]/attachment:[&_svg:not([class*='size-'])]:size-3.5"

    VARIANTS = {
      "icon" => "",
      "image" => "opacity-60 group-data-[state=done]/attachment:opacity-100 group-data-[state=idle]/attachment:opacity-100 *:[img]:aspect-square *:[img]:w-full *:[img]:object-cover"
    }.freeze

    def initialize(variant: "icon", **attrs)
      @variant = Phlex::Shadcn::Attachment.fetch_option!(variant, "icon", VARIANTS.keys, "variant")
      @attrs = attrs
      super()
    end

    def view_template(&)
      defaults = { data: { slot: "attachment-media", variant: @variant }, class: cn(BASE, VARIANTS[@variant]) }
      div(**merge_attrs(defaults, @attrs), &)
    end
  end

  class Content < Phlex::Shadcn::Base
    CLASS_NAME = "max-w-full min-w-0 flex-1 leading-tight group-data-[orientation=vertical]/attachment:px-1"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "attachment-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Title < Phlex::Shadcn::Base
    CLASS_NAME = "block max-w-full min-w-0 truncate font-medium group-data-[state=processing]/attachment:shimmer group-data-[state=uploading]/attachment:shimmer"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      span(**merge_attrs({ data: { slot: "attachment-title" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Description < Phlex::Shadcn::Base
    CLASS_NAME = "mt-0.5 block min-w-0 truncate text-xs text-muted-foreground group-data-[state=error]/attachment:text-destructive/80"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      defaults = { data: { slot: "attachment-description" }, class: cn(CLASS_NAME, "max-w-full") }
      span(**merge_attrs(defaults, @attrs), &)
    end
  end

  class Actions < Phlex::Shadcn::Base
    CLASS_NAME = "relative z-20 flex shrink-0 items-center group-data-[orientation=vertical]/attachment:absolute group-data-[orientation=vertical]/attachment:top-3 group-data-[orientation=vertical]/attachment:right-3 group-data-[orientation=vertical]/attachment:gap-1"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "attachment-actions" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Action < Phlex::Shadcn::Base
    def initialize(variant: nil, size: "icon-xs", **attrs)
      @variant = variant || "ghost"
      @size = size
      @attrs = attrs
      super()
    end

    def view_template(&)
      attrs = merge_attrs({ data: { slot: "attachment-action" } }, @attrs)
      render(Phlex::Shadcn::Button.new(variant: @variant, size: @size, **attrs), &)
    end
  end

  class Trigger < Phlex::Shadcn::Base
    CLASS_NAME = "absolute inset-0 z-10 outline-none"

    def initialize(as_child: false, type: nil, **attrs)
      @as_child = as_child
      @type = type
      @attrs = attrs
      super()
    end

    def view_template(&)
      defaults = { data: { slot: "attachment-trigger" } }
      defaults[:type] = @type || "button" unless @as_child
      attrs = merge_attrs(defaults, @attrs.except(:class))
      attrs = attrs.merge(class: [ @slot_class, cn(CLASS_NAME, @attrs[:class]) ].compact_blank.join(" "))
      return render_as_child(@as_child, **attrs, &) if @as_child

      button(**attrs, &)
    end
  end
end
