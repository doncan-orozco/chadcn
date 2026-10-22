# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn ScrollArea over Radix ScrollArea (Root, Viewport, Scrollbar, Thumb, Corner). Spec: docs/shadcn-port/specs/scroll-area.md.
# Behavior: controllers/chadcn/scroll_area_controller.js (one controller on the root div; it mounts the scrollbars kept in templates).
#
# The block receives the scroll area, which has the `scroll_bar` helper (equal to `render ScrollArea::ScrollBar.new`).
# The vertical scrollbar is always rendered; render a horizontal one inside the block to enable that axis.
#
# @example
#   render Chadcn::ScrollArea.new(type: "always", class: "h-72 w-48") do |area|
#     %w[v1.2.0 v1.1.0 v1.0.0].each { |tag| div { plain tag } }
#     area.scroll_bar(orientation: "horizontal")
#   end
#
# @see Chadcn::ScrollArea::ScrollBar
# @see https://ui.shadcn.com/docs/components/scroll-area
class Chadcn::ScrollArea < Chadcn::Base
  include Chadcn::Direction::Consumer

  # Render-context key holding the orientations enabled by the scrollbars.
  #
  # @api private
  KEY = :shadcn_scroll_area
  # Accepted `type:` values.
  TYPES = %w[auto always scroll hover].freeze
  # Classes of the root `div`.
  #
  # @api private
  ROOT_CLASS = "relative"
  # Classes of the viewport `div`.
  #
  # @api private
  VIEWPORT_CLASS = "size-full rounded-[inherit] transition-[color,box-shadow] outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1"
  # CSS that hides the native scrollbars (react-scroll-area ScrollAreaViewportStyle).
  #
  # @api private
  VIEWPORT_CSS = "[data-radix-scroll-area-viewport]{scrollbar-width:none;-ms-overflow-style:none;-webkit-overflow-scrolling:touch;}[data-radix-scroll-area-viewport]::-webkit-scrollbar{display:none}"
  # Inline style of the root (Radix corner variables).
  #
  # @api private
  ROOT_STYLE = "position: relative; --radix-scroll-area-corner-width: 0px; --radix-scroll-area-corner-height: 0px;"

  # @param type [String, Symbol] when the scrollbars show: `auto`, `always`, `scroll` or `hover` (default: "hover")
  # @param dir [String, Symbol, nil] `ltr` or `rtl`; defaults to the nearest {Chadcn::Direction::Provider} (default: nil)
  # @param scroll_hide_delay [Integer] milliseconds before the scrollbars hide (default: 600)
  # @param attrs [Hash] HTML attributes for the root `div`; `class:` is tailwind-merged, `style:` is appended, `data:` and `aria:`
  #   are deep-merged
  # @raise [ArgumentError] when `type` is unknown or `as_child:` is given
  def initialize(type: "hover", dir: nil, scroll_hide_delay: 600, **attrs)
    raise ArgumentError, "#{self.class.name} does not support as_child" if attrs.key?(:as_child) || attrs.key?(:asChild)

    @type = type.to_s
    raise ArgumentError, "type must be one of #{TYPES.join(', ')}, got #{type.inspect}" unless TYPES.include?(@type)

    @dir = dir
    @scroll_hide_delay = scroll_hide_delay
    @attrs = attrs
    super()
  end

  # Renders the root, the viewport (with the block as content) and the vertical scrollbar.
  #
  # @yieldparam area [Chadcn::ScrollArea] the root, exposing the part helpers
  # @return [void]
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
        slot: "scroll-area", controller: "chadcn--scroll-area",
        chadcn__scroll_area_type_value: @type, chadcn__scroll_area_scroll_hide_delay_value: @scroll_hide_delay
      }
    }
  end

  def viewport_style(orientations)
    overflow = ->(orientation) { orientations.include?(orientation) ? "scroll" : "hidden" }
    "overflow-x: #{overflow.call('horizontal')}; overflow-y: #{overflow.call('vertical')};"
  end

  # Radix ScrollAreaScrollbar + Thumb. Both stay in inert <template>s until the controller mounts them (spec: Deviations).
  #
  # Must be rendered inside a {Chadcn::ScrollArea}; also available as `area.scroll_bar` on the yielded scroll area.
  class ScrollBar < Chadcn::Base
    # Accepted `orientation:` values.
    ORIENTATIONS = %w[vertical horizontal].freeze
    # Classes shared by both orientations.
    #
    # @api private
    CLASS = "flex touch-none p-px transition-colors select-none"
    # Classes per orientation.
    #
    # @api private
    ORIENTATION_CLASS = {
      "vertical" => "h-full w-2.5 border-l border-l-transparent",
      "horizontal" => "h-2.5 flex-col border-t border-t-transparent"
    }.freeze
    # Classes of the thumb.
    #
    # @api private
    THUMB_CLASS = "relative flex-1 rounded-full bg-border"

    # @param orientation [String, Symbol] `vertical` or `horizontal` (default: "vertical")
    # @param force_mount [Boolean] keep the scrollbar mounted even when there is nothing to scroll (default: false)
    # @param attrs [Hash] HTML attributes for the scrollbar `div`; `class:` is tailwind-merged, `data:` and `aria:` are deep-merged
    # @raise [ArgumentError] when `orientation` is unknown or `as_child:` is given
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

    # Registers the orientation with the scroll area and renders the scrollbar and its thumb inside inert templates.
    #
    # @return [void]
    # @raise [ArgumentError] when rendered outside a {Chadcn::ScrollArea}
    def view_template
      state = context[Chadcn::ScrollArea::KEY]
      raise ArgumentError, "#{self.class.name} must be rendered inside a #{Chadcn::ScrollArea.name}" unless state

      state[:orientations] << @orientation
      template(data: { chadcn__scroll_area_target: "scrollbar", chadcn__scroll_area_force_mount: (@force_mount ? "true" : nil) }) do
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
