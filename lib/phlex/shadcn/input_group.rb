# frozen_string_literal: true

# shadcn `InputGroup` (new-york-v4). Spec: docs/shadcn-port/specs/input-group.md
class Phlex::Shadcn::InputGroup < Phlex::Shadcn::Base
  CLASS_NAME = [
    "group/input-group relative flex w-full items-center rounded-md border border-input shadow-xs transition-[color,box-shadow] outline-none dark:bg-input/30",
    "h-9 min-w-0 has-[>textarea]:h-auto",
    "has-[>[data-align=inline-start]]:[&>input]:pl-2",
    "has-[>[data-align=inline-end]]:[&>input]:pr-2",
    "has-[>[data-align=block-start]]:h-auto has-[>[data-align=block-start]]:flex-col has-[>[data-align=block-start]]:[&>input]:pb-3",
    "has-[>[data-align=block-end]]:h-auto has-[>[data-align=block-end]]:flex-col has-[>[data-align=block-end]]:[&>input]:pt-3",
    "has-[[data-slot=input-group-control]:focus-visible]:border-ring has-[[data-slot=input-group-control]:focus-visible]:ring-[3px] has-[[data-slot=input-group-control]:focus-visible]:ring-ring/50",
    "has-[[data-slot][aria-invalid=true]]:border-destructive has-[[data-slot][aria-invalid=true]]:ring-destructive/20 dark:has-[[data-slot][aria-invalid=true]]:ring-destructive/40"
  ].freeze

  def initialize(**attrs)
    @attrs = attrs
  end

  def view_template(&block)
    div(**merge_attrs({ role: "group", data: { slot: "input-group" }, class: cn(*CLASS_NAME) }, @attrs)) { yield self if block }
  end

  class Addon < Phlex::Shadcn::Base
    BASE = "flex h-auto cursor-text items-center justify-center gap-2 py-1.5 text-sm font-medium text-muted-foreground select-none group-data-[disabled=true]/input-group:opacity-50 [&>kbd]:rounded-[calc(var(--radius)-5px)] [&>svg:not([class*='size-'])]:size-4"

    ALIGNS = {
      "inline-start" => "order-first pl-3 has-[>button]:ml-[-0.45rem] has-[>kbd]:ml-[-0.35rem]",
      "inline-end" => "order-last pr-3 has-[>button]:mr-[-0.45rem] has-[>kbd]:mr-[-0.35rem]",
      "block-start" => "order-first w-full justify-start px-3 pt-3 group-has-[>input]/input-group:pt-2.5 [.border-b]:pb-3",
      "block-end" => "order-last w-full justify-start px-3 pb-3 group-has-[>input]/input-group:pb-2.5 [.border-t]:pt-3"
    }.freeze

    CONTROLLER = "v2--input-group"
    ACTION = "click->v2--input-group#focusControl"

    def initialize(align: "inline-start", **attrs)
      @align = normalize_option(align) || "inline-start"
      raise ArgumentError, "unknown align: #{align.inspect} (expected one of #{ALIGNS.keys.join(', ')})" unless ALIGNS.key?(@align)

      @attrs = attrs
    end

    def view_template(&)
      caller_attrs = canonical_attrs(@attrs)
      defaults = { role: "group", data: { slot: "input-group-addon", align: @align }, class: cn(BASE, ALIGNS[@align]) }
      attrs = merge_attrs(defaults, caller_attrs.except(:class))
      attrs = attrs.merge(class: [ @slot_class, cn(BASE, ALIGNS[@align], caller_attrs[:class]) ].compact_blank.join(" "))
      attrs[:data] = wire_controller(attrs[:data] || {})
      div(**attrs, &)
    end

    private

    # A caller click action replaces the focus handler, like a React onClick spread after it (spec Behavior).
    def wire_controller(data)
      data = data.merge(controller: [ data[:controller], CONTROLLER ].compact_blank.flat_map(&:split).uniq.join(" "))
      return data if click_action?(data[:action])

      data.merge(action: [ data[:action], ACTION ].compact_blank.join(" "))
    end

    def click_action?(action)
      action.to_s.split.any? { |descriptor| descriptor.include?("->") ? descriptor.split("->").first.split(/[@.]/).first == "click" : true }
    end
  end

  class Button < Phlex::Shadcn::Base
    BASE = "flex items-center gap-2 text-sm shadow-none"

    SIZES = {
      "xs" => "h-6 gap-1 rounded-[calc(var(--radius)-5px)] px-2 has-[>svg]:px-2 [&>svg:not([class*='size-'])]:size-3.5",
      "sm" => "h-8 gap-1.5 rounded-md px-2.5 has-[>svg]:px-2.5",
      "icon-xs" => "size-6 rounded-[calc(var(--radius)-5px)] p-0 has-[>svg]:p-0",
      "icon-sm" => "size-8 p-0 has-[>svg]:p-0"
    }.freeze

    def initialize(type: "button", variant: "ghost", size: "xs", as_child: false, **attrs)
      @size = normalize_option(size) || "xs"
      raise ArgumentError, "unknown size: #{size.inspect} (expected one of #{SIZES.keys.join(', ')})" unless SIZES.key?(@size)

      @type = type
      @variant = variant
      @as_child = as_child
      @attrs = attrs
    end

    def view_template(&)
      attrs = { type: @type, variant: @variant, as_child: @as_child, "data-size": @size }.merge(@attrs)
      attrs[:class] = cn(BASE, SIZES[@size], @attrs[:class])
      render(Phlex::Shadcn::Button.new(**attrs), &)
    end
  end

  class Text < Phlex::Shadcn::Base
    CLASS_NAME = "flex items-center gap-2 text-sm text-muted-foreground [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4"

    def initialize(**attrs)
      @attrs = attrs
    end

    def view_template(&)
      span(**merge_attrs({ class: CLASS_NAME }, @attrs), &)
    end
  end

  class Input < Phlex::Shadcn::Base
    CLASS_NAME = "flex-1 rounded-none border-0 bg-transparent shadow-none focus-visible:ring-0 dark:bg-transparent"

    def initialize(**attrs)
      @attrs = attrs
    end

    def view_template
      render Phlex::Shadcn::Input.new("data-slot": "input-group-control", **@attrs, class: cn(CLASS_NAME, @attrs[:class]))
    end
  end

  class Textarea < Phlex::Shadcn::Base
    CLASS_NAME = "flex-1 resize-none rounded-none border-0 bg-transparent py-3 shadow-none focus-visible:ring-0 dark:bg-transparent"

    def initialize(**attrs)
      @attrs = attrs
    end

    def view_template(&)
      render Phlex::Shadcn::Textarea.new("data-slot": "input-group-control", **@attrs, class: cn(CLASS_NAME, @attrs[:class])), &
    end
  end
end
