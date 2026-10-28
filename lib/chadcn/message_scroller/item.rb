# frozen_string_literal: true

# One row of the transcript (`MessageScrollerItem`). `scroll_anchor: true` marks the start of a turn.
class Chadcn::MessageScroller::Item < Chadcn::Base
  # @param message_id [String, nil] id used to address, track and preserve the row
  # @param scroll_anchor [Boolean] anchors a new turn at the top of the viewport
  # @param attrs [Hash] HTML attributes merged onto the row
  def initialize(message_id: nil, scroll_anchor: false, **attrs)
    @message_id = message_id
    @scroll_anchor = scroll_anchor
    @attrs = attrs
    super()
  end

  # @yield the message
  # @return [void]
  def view_template(&)
    attrs = merge_attrs({
                          class: "min-w-0 shrink-0 [contain-intrinsic-size:auto_10rem] [content-visibility:auto]",
                          data: { message_id: @message_id&.to_s, scroll_anchor: @scroll_anchor ? "true" : "false",
                                  slot: "message-scroller-item" }
                        }, @attrs)
    div(**attrs, &)
  end
end
