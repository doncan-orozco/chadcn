# frozen_string_literal: true

# The scrollable region of the transcript (`MessageScrollerViewport`): a focusable `role="region"`.
class Chadcn::MessageScroller::Viewport < Chadcn::Base
  CLASSES = "size-full min-h-0 min-w-0 scroll-fade-b scrollbar-thin scrollbar-gutter-stable overflow-y-auto overscroll-contain contain-content data-autoscrolling:scrollbar-none data-pending-scroll:invisible"
  private_constant :CLASSES

  # The scroll events the controller follows. Wheel and touch are passive: they only note that the user took over.
  ACTIONS = "scroll->chadcn--message-scroller#syncAfterScroll wheel->chadcn--message-scroller#userScrollIntent:passive " \
            "touchmove->chadcn--message-scroller#userScrollIntent:passive keydown->chadcn--message-scroller#userScrollKey"
  private_constant :ACTIONS

  # @param preserve_scroll_on_prepend [Boolean] keep the visible message in place when rows are inserted above it
  # @param attrs [Hash] HTML attributes (`role`, `aria-label` and `tabindex` default to `region`, `Messages` and `0`)
  def initialize(preserve_scroll_on_prepend: true, **attrs)
    @preserve_scroll_on_prepend = preserve_scroll_on_prepend
    @attrs = attrs
    super()
  end

  # @yield the content
  # @return [void]
  def view_template(&)
    position = context.dig(Chadcn::MessageScroller::CONTEXT_KEY, :default_scroll_position)
    attrs = merge_attrs({
                          role: "region", aria: { label: "Messages" }, tabindex: 0, class: CLASSES,
                          data: { slot: "message-scroller-viewport", pending_scroll: (position == "start" || position.nil? ? nil : ""),
                                  chadcn__message_scroller_target: "viewport", action: ACTIONS,
                                  chadcn__message_scroller_preserve_scroll_on_prepend: (@preserve_scroll_on_prepend ? nil : "false") }
                        }, @attrs)
    div(**attrs, &)
  end
end
