# frozen_string_literal: true

using Chadcn::Values::Refinements

# The "scroll to end/start" button (`MessageScrollerButton`): a `Chadcn::Button` that fades in while there is something to
# scroll to. Inactive it is `inert`, so it is skipped by the tab order and by clicks.
class Chadcn::MessageScroller::Button < Chadcn::Base
  CLASSES = "absolute inset-s-1/2 -translate-x-1/2 border-border bg-background text-foreground transition-[translate,scale,opacity] duration-200 hover:bg-muted hover:text-foreground data-[active=false]:pointer-events-none data-[active=false]:scale-95 data-[active=false]:opacity-0 data-[active=false]:duration-400 data-[active=false]:ease-[cubic-bezier(0.7,0,0.84,0)] data-[active=true]:translate-y-0 data-[active=true]:scale-100 data-[active=true]:opacity-100 data-[active=true]:ease-[cubic-bezier(0.23,1,0.32,1)] data-[direction=end]:bottom-4 data-[direction=end]:data-[active=false]:translate-y-full data-[direction=start]:top-4 data-[direction=start]:data-[active=false]:-translate-y-full rtl:translate-x-1/2 data-[direction=start]:[&_svg]:rotate-180"
  private_constant :CLASSES

  DIRECTIONS = %w[start end].freeze
  private_constant :DIRECTIONS

  # @param direction [String, Symbol] `start` or `end`
  # @param variant [String, Symbol] a `Chadcn::Button` variant
  # @param size [String, Symbol] a `Chadcn::Button` size (`:icon_sm` is `"icon-sm"`)
  # @param behavior [String, Symbol] `smooth`, `auto` or `instant`: how a click scrolls
  # @param render [nil, Symbol, Chadcn::Base] a tag name or component to render instead of `Chadcn::Button`
  # @param label [String, nil] the screen-reader text of the default content (default `Scroll to end` / `Scroll to start`)
  # @param attrs [Hash] HTML attributes (`type` defaults to `button`; a `tabindex` applies while the button is active)
  # @raise [ArgumentError] when the direction is neither start nor end
  def initialize(direction: "end", variant: "secondary", size: "icon-sm", behavior: "smooth", render: nil, label: nil, **attrs)
    @direction = normalize_option(direction)
    raise ArgumentError, "unknown direction: #{direction.inspect} (expected one of #{DIRECTIONS.join(', ')})" unless DIRECTIONS.include?(@direction)

    @variant = normalize_option(variant)
    @size = normalize_option(size)
    @behavior = normalize_option(behavior)
    @render = render
    @label = label || "Scroll to #{@direction}"
    @attrs = attrs
    super()
  end

  # @yield the button content (default: an arrow icon and a screen-reader label)
  # @return [void]
  def view_template(&block)
    content = block || proc { default_content }
    attrs = button_attrs
    return render_as_child(@render, **attrs, class: cn(CLASSES, @attrs[:class]), &content) if @render

    render Chadcn::Button.new(variant: @variant, size: @size, **attrs, class: cn(CLASSES, @attrs[:class])), &content
  end

  private

  def default_content
    render Chadcn::Icon.new("arrow-down")
    span(class: "sr-only") { @label }
  end

  # The server renders the inactive state; the controller flips active, inert and tabindex.
  def button_attrs
    caller_attrs = canonical_attrs(@attrs.except(:class))
    caller_tabindex = caller_attrs.delete(:tabindex)
    attrs = merge_attrs({
                          type: "button", inert: true, tabindex: -1,
                          data: { active: "false", direction: @direction, slot: "message-scroller-button", variant: @variant,
                                  size: @size, chadcn__message_scroller_target: "button",
                                  chadcn__message_scroller_behavior_param: @behavior,
                                  chadcn__message_scroller_active_tabindex: caller_tabindex }
                        }, caller_attrs)
    # The caller's click handlers run first, then ours.
    action = [ attrs.dig(:data, :action), "click->chadcn--message-scroller#press" ].reject_blank.join(" ")
    attrs.merge(data: attrs[:data].merge(action:))
  end
end
