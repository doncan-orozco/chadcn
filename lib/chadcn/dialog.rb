# frozen_string_literal: true

# shadcn Dialog (Radix Dialog). Spec: docs/shadcn-port/specs/dialog.md. Behavior: controllers/chadcn/dialog_controller.js.
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
  # @param id [String, nil] id of the content (what the trigger controls); the other generated ids derive from it (`"x-title"`,
  #   `"x-description"`). Default `dialog-N`, numbered per request with the engine, per render without it
  # @param attrs [Hash] HTML attributes merged into the host element
  # @raise [ArgumentError] when id: is empty or contains whitespace, a double quote or a backslash
  def initialize(open: nil, default_open: false, modal: true, id: nil, **attrs)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    @modal = modal
    @id = validated_id(id)
    @attrs = attrs
    super()
  end

  # @yieldparam dialog [Dialog] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    previous = [ context[ROOT_KEY], context[PORTAL_KEY] ]
    base = @id || "dialog-#{next_sequence(SEQUENCE_KEY)}"
    root = { content_id: base, title_id: "#{base}-title", description_id: "#{base}-description",
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
      controller: "chadcn--dialog",
      chadcn__dialog_open_value: root[:open].to_s,
      chadcn__dialog_controlled_value: root[:controlled].to_s,
      chadcn__dialog_modal_value: root[:modal].to_s,
      chadcn__dialog_id_value: root[:content_id]
    }
  end
end
