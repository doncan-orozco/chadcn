# frozen_string_literal: true

# shadcn Bubble (new-york-v4). Spec: docs/shadcn-port/specs/bubble.md. Static: no controller.
class Phlex::Shadcn::Bubble < Phlex::Shadcn::Base
  BASE = "group/bubble relative flex w-fit max-w-[80%] min-w-0 flex-col gap-1 group-data-[align=end]/message:self-end data-[align=end]:self-end data-[variant=ghost]:max-w-full"

  VARIANTS = {
    "default" => "*:data-[slot=bubble-content]:bg-primary *:data-[slot=bubble-content]:text-primary-foreground [&>[data-slot=bubble-content]:is(button,a):hover]:bg-primary/80",
    "secondary" => "*:data-[slot=bubble-content]:bg-secondary *:data-[slot=bubble-content]:text-secondary-foreground [&>[data-slot=bubble-content]:is(button,a):hover]:bg-[color-mix(in_oklch,var(--secondary),var(--foreground)_5%)]",
    "muted" => "*:data-[slot=bubble-content]:bg-muted [&>[data-slot=bubble-content]:is(button,a):hover]:bg-[color-mix(in_oklch,var(--muted),var(--foreground)_5%)]",
    "tinted" => "*:data-[slot=bubble-content]:bg-[oklch(from_var(--primary)_0.93_calc(c*0.4)_h)] *:data-[slot=bubble-content]:text-foreground dark:*:data-[slot=bubble-content]:bg-[oklch(from_var(--primary)_0.3_calc(c*0.4)_h)] [&>[data-slot=bubble-content]:is(button,a):hover]:bg-[oklch(from_var(--primary)_0.88_calc(c*0.5)_h)] dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-[oklch(from_var(--primary)_0.35_calc(c*0.5)_h)]",
    "outline" => "*:data-[slot=bubble-content]:border-border *:data-[slot=bubble-content]:bg-background [&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted [&>[data-slot=bubble-content]:is(button,a):hover]:text-foreground dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-input/30",
    "ghost" => "border-none *:data-[slot=bubble-content]:rounded-none *:data-[slot=bubble-content]:bg-transparent *:data-[slot=bubble-content]:p-0 [&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted [&>[data-slot=bubble-content]:is(button,a):hover]:text-foreground dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted/50",
    "destructive" => "*:data-[slot=bubble-content]:bg-destructive/10 *:data-[slot=bubble-content]:text-destructive dark:*:data-[slot=bubble-content]:bg-destructive/20 [&>[data-slot=bubble-content]:is(button,a):hover]:bg-destructive/20 dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-destructive/30"
  }.freeze

  ALIGNS = %w[start end].freeze

  def self.fetch_option!(value, default, allowed, name)
    option = value&.to_s&.tr("_", "-") || default
    raise ArgumentError, "unknown #{name}: #{value.inspect} (expected one of #{allowed.join(', ')})" unless allowed.include?(option)

    option
  end

  def initialize(variant: "default", align: "start", **attrs)
    @variant = self.class.fetch_option!(variant, "default", VARIANTS.keys, "variant")
    @align = self.class.fetch_option!(align, "start", ALIGNS, "align")
    @attrs = attrs
    super()
  end

  def view_template(&block)
    defaults = { data: { slot: "bubble", variant: @variant, align: @align }, class: cn(BASE, VARIANTS[@variant]) }
    div(**merge_attrs(defaults, @attrs)) { yield self if block }
  end

  class Group < Phlex::Shadcn::Base
    CLASS_NAME = "flex min-w-0 flex-col gap-2"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "bubble-group" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Content < Phlex::Shadcn::Base
    CLASS_NAME = "w-fit max-w-full min-w-0 overflow-hidden rounded-xl border border-transparent px-3 py-2 text-sm leading-relaxed wrap-break-word group-data-[align=end]/bubble:self-end [button]:text-left [button,a]:transition-colors [button,a]:outline-none [button,a]:focus-visible:border-ring [button,a]:focus-visible:ring-3 [button,a]:focus-visible:ring-ring/50"

    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    def view_template(&)
      attrs = merge_attrs({ data: { slot: "bubble-content" }, class: CLASS_NAME }, @attrs.except(:class))
      attrs = attrs.merge(class: [ @slot_class, cn(CLASS_NAME, @attrs[:class]) ].compact_blank.join(" "))
      return render_as_child(@as_child, **attrs, &) if @as_child

      div(**attrs, &)
    end
  end

  class Reactions < Phlex::Shadcn::Base
    BASE = "absolute z-10 flex w-fit shrink-0 items-center justify-center gap-1 rounded-full bg-muted px-1.5 py-0.5 text-sm ring-3 ring-card has-[button]:p-0"
    SIDES = { "top" => "top-0 -translate-y-3/4", "bottom" => "bottom-0 translate-y-3/4" }.freeze
    ALIGNS = { "start" => "left-3", "end" => "right-3" }.freeze

    def initialize(side: "bottom", align: "end", **attrs)
      @side = Phlex::Shadcn::Bubble.fetch_option!(side, "bottom", SIDES.keys, "side")
      @align = Phlex::Shadcn::Bubble.fetch_option!(align, "end", ALIGNS.keys, "align")
      @attrs = attrs
      super()
    end

    def view_template(&)
      defaults = { data: { slot: "bubble-reactions", align: @align, side: @side }, class: cn(BASE, SIDES[@side], ALIGNS[@align]) }
      div(**merge_attrs(defaults, @attrs), &)
    end
  end
end
