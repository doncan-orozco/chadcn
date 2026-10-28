# frozen_string_literal: true

# React's `MessageScrollerProvider` renders no element; the port renders one `display: contents` host that carries the
# `chadcn--message-scroller` controller, so controls outside the frame can call it (Deviations, spec).
#
# @example
#   render Chadcn::MessageScroller::Provider.new(auto_scroll: true, default_scroll_position: :last_anchor) { ... }
class Chadcn::MessageScroller::Provider < Chadcn::Base
  # @param auto_scroll [Boolean] keep the viewport pinned to the bottom while content streams in
  # @param default_scroll_position [String, Symbol] `start`, `end` or `last-anchor` (`:last_anchor`)
  # @param scroll_edge_threshold [Numeric] px from an edge under which the viewport counts as being at it
  # @param scroll_previous_item_peek [Numeric] px of the previous item kept visible above an anchored turn
  # @param scroll_margin [Numeric] px kept between the viewport edge and a scrolled-to message
  # @param track_visibility [Boolean] dispatch `chadcn--message-scroller:visibility-change` (replaces subscribing to
  #   `useMessageScrollerVisibility`)
  # @param attrs [Hash] HTML attributes merged onto the host
  # @raise [ArgumentError] when default_scroll_position is not one of the three positions
  def initialize(auto_scroll: false, default_scroll_position: "end", scroll_edge_threshold: 8, scroll_previous_item_peek: 64,
                 scroll_margin: 0, track_visibility: false, **attrs)
    @auto_scroll = auto_scroll
    @position = scroll_position(default_scroll_position)
    @scroll_edge_threshold = scroll_edge_threshold
    @scroll_previous_item_peek = scroll_previous_item_peek
    @scroll_margin = scroll_margin
    @track_visibility = track_visibility
    @attrs = attrs
    super()
  end

  # @yield the frame and any controls that use it
  # @return [void]
  def view_template(&)
    previous = context[Chadcn::MessageScroller::CONTEXT_KEY]
    context[Chadcn::MessageScroller::CONTEXT_KEY] = { default_scroll_position: @position }
    div(**merge_attrs({ style: "display: contents", data: host_data }, @attrs), &)
  ensure
    context[Chadcn::MessageScroller::CONTEXT_KEY] = previous
  end

  private

  def host_data
    {
      controller: "chadcn--message-scroller",
      chadcn__message_scroller_auto_scroll_value: @auto_scroll.to_s,
      chadcn__message_scroller_default_scroll_position_value: @position,
      chadcn__message_scroller_scroll_edge_threshold_value: @scroll_edge_threshold,
      chadcn__message_scroller_scroll_previous_item_peek_value: @scroll_previous_item_peek,
      chadcn__message_scroller_scroll_margin_value: @scroll_margin,
      chadcn__message_scroller_track_visibility_value: @track_visibility.to_s
    }
  end

  def scroll_position(value)
    position = normalize_option(value)
    return position if Chadcn::MessageScroller::SCROLL_POSITIONS.include?(position)

    raise ArgumentError, "unknown default_scroll_position: #{value.inspect} (expected one of #{Chadcn::MessageScroller::SCROLL_POSITIONS.join(', ')})"
  end
end
