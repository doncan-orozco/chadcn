# frozen_string_literal: true

# shadcn Message (new-york-v4). Spec: docs/shadcn-port/specs/message.md. Static: no controller.
class Phlex::Shadcn::Message < Phlex::Shadcn::Base
  BASE = "group/message relative flex w-full min-w-0 gap-2 text-sm data-[align=end]:flex-row-reverse"
  ALIGNS = %w[start end].freeze

  def initialize(align: "start", **attrs)
    @align = align&.to_s || "start"
    raise ArgumentError, "unknown align: #{align.inspect} (expected one of #{ALIGNS.join(', ')})" unless ALIGNS.include?(@align)

    @attrs = attrs
    super()
  end

  def view_template(&block)
    div(**merge_attrs({ data: { slot: "message", align: @align }, class: BASE }, @attrs)) { yield self if block }
  end

  class Group < Phlex::Shadcn::Base
    CLASS_NAME = "flex min-w-0 flex-col gap-2"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "message-group" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Avatar < Phlex::Shadcn::Base
    CLASS_NAME = "flex w-fit min-w-8 shrink-0 items-center justify-center self-end overflow-hidden rounded-full bg-muted group-has-data-[slot=message-footer]/message:-translate-y-8"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "message-avatar" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Content < Phlex::Shadcn::Base
    CLASS_NAME = "flex w-full min-w-0 flex-col gap-2.5 wrap-break-word group-data-[align=end]/message:*:data-slot:self-end"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "message-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Header < Phlex::Shadcn::Base
    CLASS_NAME = "flex max-w-full min-w-0 items-center px-3 text-xs font-medium text-muted-foreground group-has-data-[variant=ghost]/message:px-0"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "message-header" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Footer < Phlex::Shadcn::Base
    CLASS_NAME = "flex max-w-full min-w-0 items-center px-3 text-xs font-medium text-muted-foreground group-has-data-[variant=ghost]/message:px-0 group-data-[align=end]/message:justify-end"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "message-footer" }, class: CLASS_NAME }, @attrs), &)
    end
  end
end
