# frozen_string_literal: true

# shadcn ScrollArea over Radix ScrollArea (Root, Viewport, Scrollbar, Thumb, Corner). Spec: docs/shadcn-port/specs/scroll-area.md.
# Behavior: controllers/shadcn/scroll_area_controller.js (one controller on the root div; it mounts the scrollbars kept in templates).
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::ScrollArea < Phlex::Shadcn::Base
  include Phlex::Shadcn::Direction::Consumer

  KEY = :shadcn_scroll_area
  TYPES = %w[auto always scroll hover].freeze
  ROOT_CLASS = "relative"
  VIEWPORT_CLASS = "size-full rounded-[inherit] transition-[color,box-shadow] outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1"
  # Hides the native scrollbars (react-scroll-area ScrollAreaViewportStyle).
  VIEWPORT_CSS = "[data-radix-scroll-area-viewport]{scrollbar-width:none;-ms-overflow-style:none;-webkit-overflow-scrolling:touch;}[data-radix-scroll-area-viewport]::-webkit-scrollbar{display:none}"
  ROOT_STYLE = "position: relative; --radix-scroll-area-corner-width: 0px; --radix-scroll-area-corner-height: 0px;"

  def initialize(type: "hover", dir: nil, scroll_hide_delay: 600, **attrs)
    raise ArgumentError, "#{self.class.name} does not support as_child" if attrs.key?(:as_child) || attrs.key?(:asChild)

    @type = type.to_s
    raise ArgumentError, "type must be one of #{TYPES.join(', ')}, got #{type.inspect}" unless TYPES.include?(@type)

    @dir = dir
    @scroll_hide_delay = scroll_hide_delay
    @attrs = attrs
    super()
  end

  def view_template
    direction = use_direction(@dir)
    previous = context[KEY]
    # The built-in vertical ScrollBar always enables the Y axis; caller ScrollBars register while the block renders.
    state = context[KEY] = { orientations: Set["vertical"] }
    content = capture { yield self if block_given? }
    div(**merge_attrs(root_defaults(direction), @attrs.except(:style))) do
      style { raw(safe(VIEWPORT_CSS)) }
      div(data: { radix_scroll_area_viewport: "", slot: "scroll-area-viewport" }, class: VIEWPORT_CLASS,
          style: viewport_style(state[:orientations])) do
        div(style: "min-width: 100%; display: table;") { raw(safe(content)) }
      end
      render ScrollBar.new(orientation: "vertical")
    end
  ensure
    context[KEY] = previous
  end

  private

  def root_defaults(direction)
    {
      dir: direction,
      class: ROOT_CLASS,
      style: [ ROOT_STYLE, style_string(@attrs[:style]).unless_blank&.then { |css| "#{css};" } ].compact.join(" "),
      data: {
        slot: "scroll-area", controller: "shadcn--scroll-area",
        shadcn__scroll_area_type_value: @type, shadcn__scroll_area_scroll_hide_delay_value: @scroll_hide_delay
      }
    }
  end

  def viewport_style(orientations)
    overflow = ->(orientation) { orientations.include?(orientation) ? "scroll" : "hidden" }
    "overflow-x: #{overflow.call('horizontal')}; overflow-y: #{overflow.call('vertical')};"
  end

  # Radix ScrollAreaScrollbar + Thumb. Both stay in inert <template>s until the controller mounts them (spec: Deviations).
  class ScrollBar < Phlex::Shadcn::Base
    ORIENTATIONS = %w[vertical horizontal].freeze
    CLASS = "flex touch-none p-px transition-colors select-none"
    ORIENTATION_CLASS = {
      "vertical" => "h-full w-2.5 border-l border-l-transparent",
      "horizontal" => "h-2.5 flex-col border-t border-t-transparent"
    }.freeze
    THUMB_CLASS = "relative flex-1 rounded-full bg-border"

    def initialize(orientation: "vertical", force_mount: false, **attrs)
      raise ArgumentError, "#{self.class.name} does not support as_child" if attrs.key?(:as_child) || attrs.key?(:asChild)

      @orientation = orientation.to_s
      unless ORIENTATIONS.include?(@orientation)
        raise ArgumentError,
              "orientation must be one of #{ORIENTATIONS.join(', ')}, got #{orientation.inspect}"
      end

      @force_mount = force_mount
      @attrs = attrs
      super()
    end

    def view_template
      state = context[Phlex::Shadcn::ScrollArea::KEY]
      raise ArgumentError, "#{self.class.name} must be rendered inside a #{Phlex::Shadcn::ScrollArea.name}" unless state

      state[:orientations] << @orientation
      template(data: { shadcn__scroll_area_target: "scrollbar", shadcn__scroll_area_force_mount: (@force_mount ? "true" : nil) }) do
        div(**merge_attrs(defaults, @attrs)) do
          template do
            div(data: { state: "visible", slot: "scroll-area-thumb" }, class: THUMB_CLASS,
                style: "width: var(--radix-scroll-area-thumb-width); height: var(--radix-scroll-area-thumb-height);")
          end
        end
      end
    end

    private

    def defaults
      {
        data: { orientation: @orientation, slot: "scroll-area-scrollbar" },
        class: [ CLASS, ORIENTATION_CLASS[@orientation] ]
      }
    end
  end
end
