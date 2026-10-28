# frozen_string_literal: true

# The list of messages (`MessageScrollerContent`): a `role="log"` followed by the hidden spacer the controller sizes so an
# anchored turn can sit at the top of the viewport.
class Chadcn::MessageScroller::Content < Chadcn::Base
  # @param spacer_class_name [String, nil] class of the internal spacer (not merged)
  # @param attrs [Hash] HTML attributes (`role` and `aria-relevant` default to `log` and `additions`)
  def initialize(spacer_class_name: nil, **attrs)
    @spacer_class_name = spacer_class_name
    @attrs = attrs
    super()
  end

  # @yield the messages
  # @return [void]
  def view_template(&)
    attrs = merge_attrs({
                          role: "log", aria: { relevant: "additions" }, class: "flex h-max min-h-full flex-col gap-8",
                          data: { slot: "message-scroller-content", chadcn__message_scroller_target: "content" }
                        }, @attrs)
    div(**attrs) do
      yield if block_given?
      div(aria: { hidden: "true" }, hidden: true, class: @spacer_class_name,
          data: { message_scroller_spacer: "", chadcn__message_scroller_target: "spacer" })
    end
  end
end
