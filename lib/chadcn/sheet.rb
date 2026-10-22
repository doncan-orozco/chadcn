# frozen_string_literal: true

# shadcn Sheet (Radix Dialog with side-aware styling). Spec: docs/shadcn-port/specs/sheet.md. Behavior:
# controllers/shadcn/sheet_controller.js, which reuses the dialog controller.
#
# Radix Root renders no element; the port renders one display: contents host that carries the Stimulus controller (a
# trigger cannot host it: zero, one or several triggers, or a controlled open). Portal children are shipped in an inert
# template and mounted into the body by the controller, like Radix mounts them only while open.
#
# Root of the Sheet family. Renders one `display: contents` host element that carries the Stimulus controller.
# Parts are rendered with the explicit classes or with the helpers generated on the yielded root (one per part).
#
# @example Explicit form
#   render Chadcn::Sheet.new do
#     render Chadcn::Sheet::Trigger.new { "Open" }
#     render Chadcn::Sheet::Content.new do
#       render(Chadcn::Sheet::Title.new { "Title" })
#     end
#   end
#
# @example Yielded-root helper form
#   render Chadcn::Sheet.new do |sheet|
#     sheet.trigger { "Open" }
#     sheet.content { sheet.title { "Title" } }
#   end
#
# Generated helpers (each forwards `**attrs` and the block to the part):
#
# @!method trigger(**attrs, &block)
#   Same as `render Sheet::Trigger.new(**attrs), &block`.
# @!method portal(&block)
#   Same as `render Sheet::Portal.new, &block`.
# @!method overlay(**attrs, &block)
#   Same as `render Sheet::Overlay.new(**attrs), &block`.
# @!method content(**attrs, &block)
#   Same as `render Sheet::Content.new(**attrs), &block`.
# @!method header(**attrs, &block)
#   Same as `render Sheet::Header.new(**attrs), &block`.
# @!method footer(**attrs, &block)
#   Same as `render Sheet::Footer.new(**attrs), &block`.
# @!method title(**attrs, &block)
#   Same as `render Sheet::Title.new(**attrs), &block`.
# @!method description(**attrs, &block)
#   Same as `render Sheet::Description.new(**attrs), &block`.
# @!method close(**attrs, &block)
#   Same as `render Sheet::Close.new(**attrs), &block`.
class Chadcn::Sheet < Chadcn::Base
  # @api private
  ROOT_KEY = :shadcn_sheet_root
  # @api private
  PORTAL_KEY = :shadcn_sheet_portal
  # @api private
  SEQUENCE_KEY = :shadcn_sheet_sequence

  # @param open [Boolean, nil] controlled open state when not nil (user actions only dispatch open-change; the caller updates it)
  # @param default_open [Boolean] initial open state when uncontrolled
  # @param modal [Boolean] modal (overlay and focus trap) or not; default true
  # @param attrs [Hash] HTML attributes merged into the host element
  def initialize(open: nil, default_open: false, modal: true, **attrs)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    @modal = modal
    @attrs = attrs
    super()
  end

  # @yieldparam sheet [Sheet] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    previous = [ context[ROOT_KEY], context[PORTAL_KEY] ]
    base = "sheet-#{context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1}"
    root = { content_id: "#{base}-content", title_id: "#{base}-title", description_id: "#{base}-description",
             open: @open, controlled: @controlled, modal: @modal }
    context[ROOT_KEY] = root
    context[PORTAL_KEY] = nil
    div(**merge_attrs({ style: "display: contents", data: host_data(root) }, @attrs)) { yield self if block_given? }
  ensure
    context[ROOT_KEY], context[PORTAL_KEY] = previous
  end

  private

  def host_data(root)
    {
      controller: "shadcn--sheet",
      shadcn__sheet_open_value: root[:open].to_s,
      shadcn__sheet_controlled_value: root[:controlled].to_s,
      shadcn__sheet_modal_value: root[:modal].to_s,
      shadcn__sheet_id_value: root[:content_id]
    }
  end
end
