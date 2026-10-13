# frozen_string_literal: true

# shadcn Kbd (new-york-v4). Spec: docs/shadcn-port/specs/kbd.md. Static: no controller.
class Phlex::Shadcn::Kbd < Phlex::Shadcn::Base
  CLASS_NAME = "pointer-events-none inline-flex h-5 w-fit min-w-5 items-center justify-center gap-1 rounded-sm bg-muted px-1 font-sans text-xs font-medium text-muted-foreground select-none [&_svg:not([class*='size-'])]:size-3 [[data-slot=tooltip-content]_&]:bg-background/20 [[data-slot=tooltip-content]_&]:text-background dark:[[data-slot=tooltip-content]_&]:bg-background/10"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&block)
    kbd(**merge_attrs({ data: { slot: "kbd" }, class: CLASS_NAME }, @attrs)) { yield self if block }
  end

  class Group < Phlex::Shadcn::Base
    CLASS_NAME = "inline-flex items-center gap-1"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      kbd(**merge_attrs({ data: { slot: "kbd-group" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
