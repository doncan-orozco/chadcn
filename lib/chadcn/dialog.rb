# frozen_string_literal: true

# shadcn Dialog (Radix Dialog). Spec: docs/shadcn-port/specs/dialog.md. Behavior: controllers/shadcn/dialog_controller.js.
#
# Radix Root renders no element; the port renders one display: contents host that carries the Stimulus controller (a
# trigger cannot host it: zero, one or several triggers, or a controlled open). Portal children are shipped in an inert
# template and mounted into the body by the controller, like Radix mounts them only while open.
#
# Root of the Dialog family. Renders one `display: contents` host element that carries the Stimulus controller.
# Parts are rendered with the explicit classes or with the helpers generated on the yielded root (one per part).
#
# @example Explicit form
#   render Chadcn::Dialog.new do
#     render Chadcn::Dialog::Trigger.new { "Open" }
#     render Chadcn::Dialog::Content.new do
#       render(Chadcn::Dialog::Title.new { "Title" })
#     end
#   end
#
# @example Yielded-root helper form
#   render Chadcn::Dialog.new do |dialog|
#     dialog.trigger { "Open" }
#     dialog.content { dialog.title { "Title" } }
#   end
#
# Generated helpers (each forwards `**attrs` and the block to the part):
#
# @!method trigger(**attrs, &block)
#   Same as `render Dialog::Trigger.new(**attrs), &block`.
# @!method portal(force_mount: false, container: nil, &block)
#   Same as `render Dialog::Portal.new(force_mount:, container:), &block`.
# @!method overlay(**attrs, &block)
#   Same as `render Dialog::Overlay.new(**attrs), &block`.
# @!method content(**attrs, &block)
#   Same as `render Dialog::Content.new(**attrs), &block`.
# @!method header(**attrs, &block)
#   Same as `render Dialog::Header.new(**attrs), &block`.
# @!method footer(**attrs, &block)
#   Same as `render Dialog::Footer.new(**attrs), &block`.
# @!method title(**attrs, &block)
#   Same as `render Dialog::Title.new(**attrs), &block`.
# @!method description(**attrs, &block)
#   Same as `render Dialog::Description.new(**attrs), &block`.
# @!method close(**attrs, &block)
#   Same as `render Dialog::Close.new(**attrs), &block`.
class Chadcn::Dialog < Chadcn::Base
  # @api private
  ROOT_KEY = :shadcn_dialog_root
  # @api private
  PORTAL_KEY = :shadcn_dialog_portal
  # @api private
  SEQUENCE_KEY = :shadcn_dialog_sequence

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

  # @yieldparam dialog [Dialog] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    previous = [ context[ROOT_KEY], context[PORTAL_KEY] ]
    base = "dialog-#{context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1}"
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
      controller: "shadcn--dialog",
      shadcn__dialog_open_value: root[:open].to_s,
      shadcn__dialog_controlled_value: root[:controlled].to_s,
      shadcn__dialog_modal_value: root[:modal].to_s,
      shadcn__dialog_id_value: root[:content_id]
    }
  end
end
