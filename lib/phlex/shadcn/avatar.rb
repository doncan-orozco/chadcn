# frozen_string_literal: true

# shadcn Avatar over Radix Avatar. Spec: docs/shadcn-port/specs/avatar.md. Behavior in controllers/shadcn/avatar_controller.js.
class Phlex::Shadcn::Avatar < Phlex::Shadcn::Base
  SIZES = %w[default sm lg].freeze
  ROOT_CLASS = "group/avatar relative flex size-8 shrink-0 overflow-hidden rounded-full select-none data-[size=lg]:size-10 data-[size=sm]:size-6"

  def initialize(size: "default", as_child: false, **attrs)
    @size = normalize_option(size) || "default"
    raise ArgumentError, "unknown size #{size.inspect}, expected one of #{SIZES.join(', ')}" unless SIZES.include?(@size)

    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&block)
    attrs = merge_attrs({ data: { slot: "avatar", size: @size, controller: "shadcn--avatar" }, class: ROOT_CLASS }, @attrs)
    if @as_child
      render_as_child(@as_child, **attrs) { yield self if block }
    else
      span(**attrs) { yield self if block }
    end
  end

  # Mounted by the controller only once the image has loaded: kept in an inert template until then.
  # Deviation: docs/shadcn-port/deviations/avatar.json.
  class Image < Phlex::Shadcn::Base
    CLASSES = "aspect-square size-full"

    def initialize(src: nil, as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs.merge(src:).compact
      super()
    end

    def view_template(&)
      attrs = merge_attrs({ data: { slot: "avatar-image" }, class: CLASSES }, @attrs)
      template(data: { shadcn__avatar_target: "image" }) do
        @as_child ? render_as_child(@as_child, **attrs, &) : img(**attrs)
      end
    end
  end

  class Fallback < Phlex::Shadcn::Base
    CLASSES = "flex size-full items-center justify-center rounded-full bg-muted text-sm text-muted-foreground group-data-[size=sm]/avatar:text-xs"

    def initialize(delay_ms: nil, as_child: false, **attrs)
      @delay_ms = delay_ms
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # Without a delay the fallback is a live element (SSR and no-JS show it). With one, it waits in a template.
    def view_template(&)
      return element(&) unless @delay_ms

      template(data: { shadcn__avatar_target: "fallback", shadcn__avatar_delay_ms: @delay_ms }) { element(&) }
    end

    private

    def element(&)
      target = @delay_ms ? {} : { shadcn__avatar_target: "fallback" }
      attrs = merge_attrs({ data: { slot: "avatar-fallback", **target }, class: CLASSES }, @attrs)
      @as_child ? render_as_child(@as_child, **attrs, &) : span(**attrs, &)
    end
  end

  class Badge < Phlex::Shadcn::Base
    CLASSES = "absolute right-0 bottom-0 z-10 inline-flex items-center justify-center rounded-full bg-primary text-primary-foreground ring-2 ring-background select-none group-data-[size=sm]/avatar:size-2 group-data-[size=sm]/avatar:[&>svg]:hidden group-data-[size=default]/avatar:size-2.5 group-data-[size=default]/avatar:[&>svg]:size-2 group-data-[size=lg]/avatar:size-3 group-data-[size=lg]/avatar:[&>svg]:size-2"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      span(**merge_attrs({ data: { slot: "avatar-badge" }, class: CLASSES }, @attrs), &)
    end
  end

  class Group < Phlex::Shadcn::Base
    CLASSES = "group/avatar-group flex -space-x-2 *:data-[slot=avatar]:ring-2 *:data-[slot=avatar]:ring-background"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "avatar-group" }, class: CLASSES }, @attrs), &)
    end
  end

  class GroupCount < Phlex::Shadcn::Base
    CLASSES = "relative flex size-8 shrink-0 items-center justify-center rounded-full bg-muted text-sm text-muted-foreground ring-2 ring-background group-has-data-[size=lg]/avatar-group:size-10 group-has-data-[size=sm]/avatar-group:size-6 [&>svg]:size-4 group-has-data-[size=lg]/avatar-group:[&>svg]:size-5 group-has-data-[size=sm]/avatar-group:[&>svg]:size-3"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "avatar-group-count" }, class: CLASSES }, @attrs), &)
    end
  end
end
