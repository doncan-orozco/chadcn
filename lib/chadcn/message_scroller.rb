# frozen_string_literal: true

# shadcn MessageScroller over `@shadcn/react/message-scroller`. Spec: dev/port/specs/message-scroller.md.
# Behavior: controllers/chadcn/message_scroller_controller.js (on the Provider host).
#
# The styled frame of a chat transcript: a `div` that holds the viewport and the scroll buttons. Wrap it in a
# `MessageScroller::Provider`, which carries the behavior (sticky-to-bottom, turn anchoring, opening position) and may also
# wrap controls placed outside the frame. Yields itself, so `viewport` and `button` are yielded-root helpers equal to
# rendering `MessageScroller::Viewport` and `MessageScroller::Button`.
#
# @example
#   render Chadcn::MessageScroller::Provider.new(auto_scroll: true) do
#     render Chadcn::MessageScroller.new(class: "h-80") do |scroller|
#       scroller.viewport do
#         render Chadcn::MessageScroller::Content.new do
#           render(Chadcn::MessageScroller::Item.new(message_id: "m1", scroll_anchor: true)) { "Hello" }
#         end
#       end
#       scroller.button
#     end
#   end
class Chadcn::MessageScroller < Chadcn::Base
  # Where the Provider tells its parts the opening position (so the frame and the viewport start hidden until it is applied).
  #
  # @api private
  CONTEXT_KEY = :shadcn_message_scroller_provider

  # Opening positions accepted by `Provider#default_scroll_position:`.
  #
  # @api private
  SCROLL_POSITIONS = %w[start end last-anchor].freeze

  # @param attrs [Hash] HTML attributes merged onto the frame (`class:` wins Tailwind conflicts)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yieldparam message_scroller [Chadcn::MessageScroller] the root, exposing the part helpers
  # @return [void]
  def view_template
    position = context.dig(CONTEXT_KEY, :default_scroll_position)
    attrs = merge_attrs({
                          class: "group/message-scroller relative flex size-full min-h-0 flex-col overflow-hidden",
                          data: { slot: "message-scroller", pending_scroll: (position == "start" || position.nil? ? nil : ""),
                                  chadcn__message_scroller_target: "root" }
                        }, @attrs)
    div(**attrs) { yield self if block_given? }
  end
end
