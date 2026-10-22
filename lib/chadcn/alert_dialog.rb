# frozen_string_literal: true

# shadcn AlertDialog (Radix AlertDialog, always modal). Spec: docs/shadcn-port/specs/alert-dialog.md. Behavior:
# controllers/chadcn/alert_dialog_controller.js, which reuses the dialog controller.
#
# Radix Root renders no element; the port renders one display: contents host that carries the Stimulus controller (a
# trigger cannot host it: zero, one or several triggers, or a controlled open). Portal children are shipped in an inert
# template and mounted into the body by the controller, like Radix mounts them only while open.
#
# Root of the AlertDialog family. Renders one `display: contents` host element that carries the Stimulus controller.
# The alert dialog is always modal: passing `modal:` raises ArgumentError.
# Parts are rendered with the explicit classes or with the helpers generated on the yielded root (one per part).
#
# @example Explicit form
#   render Chadcn::AlertDialog.new do
#     render Chadcn::AlertDialog::Trigger.new { "Open" }
#     render Chadcn::AlertDialog::Content.new do
#       render(Chadcn::AlertDialog::Title.new { "Title" })
#     end
#   end
#
# @example Yielded-root helper form
#   render Chadcn::AlertDialog.new do |alert_dialog|
#     alert_dialog.trigger { "Open" }
#     alert_dialog.content { alert_dialog.title { "Title" } }
#   end
#
# Generated helpers (each forwards `**attrs` and the block to the part):
#
# @!method trigger(**attrs, &block)
#   Same as `render AlertDialog::Trigger.new(**attrs), &block`.
# @!method portal(force_mount: false, container: nil, &block)
#   Same as `render AlertDialog::Portal.new(force_mount:, container:), &block`.
# @!method overlay(**attrs, &block)
#   Same as `render AlertDialog::Overlay.new(**attrs), &block`.
# @!method content(**attrs, &block)
#   Same as `render AlertDialog::Content.new(**attrs), &block`.
# @!method header(**attrs, &block)
#   Same as `render AlertDialog::Header.new(**attrs), &block`.
# @!method footer(**attrs, &block)
#   Same as `render AlertDialog::Footer.new(**attrs), &block`.
# @!method title(**attrs, &block)
#   Same as `render AlertDialog::Title.new(**attrs), &block`.
# @!method description(**attrs, &block)
#   Same as `render AlertDialog::Description.new(**attrs), &block`.
# @!method action(**attrs, &block)
#   Same as `render AlertDialog::Action.new(**attrs), &block`.
# @!method cancel(**attrs, &block)
#   Same as `render AlertDialog::Cancel.new(**attrs), &block`.
# @!method media(**attrs, &block)
#   Same as `render AlertDialog::Media.new(**attrs), &block`.
class Chadcn::AlertDialog < Chadcn::Base
  # @api private
  ROOT_KEY = :shadcn_alert_dialog_root
  # @api private
  PORTAL_KEY = :shadcn_alert_dialog_portal
  # @api private
  SEQUENCE_KEY = :shadcn_alert_dialog_sequence

  # @param open [Boolean, nil] controlled open state when not nil (user actions only dispatch open-change; the caller updates it)
  # @param default_open [Boolean] initial open state when uncontrolled
  # @param attrs [Hash] HTML attributes merged into the host element
  # @raise [ArgumentError] when `modal:` is given
  def initialize(open: nil, default_open: false, **attrs)
    raise ArgumentError, "unknown keyword: #{:modal.inspect} (always modal)" if attrs.key?(:modal)

    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    @attrs = attrs
    super()
  end

  # @yieldparam alert_dialog [AlertDialog] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    previous = [ context[ROOT_KEY], context[PORTAL_KEY] ]
    base = "alert-dialog-#{context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1}"
    root = { content_id: "#{base}-content", title_id: "#{base}-title", description_id: "#{base}-description",
             open: @open, controlled: @controlled }
    context[ROOT_KEY] = root
    context[PORTAL_KEY] = nil
    div(**merge_attrs({ style: "display: contents", data: host_data(root) }, @attrs)) { yield self if block_given? }
  ensure
    context[ROOT_KEY], context[PORTAL_KEY] = previous
  end

  private

  def host_data(root)
    {
      controller: "chadcn--alert-dialog",
      chadcn__alert_dialog_open_value: root[:open].to_s,
      chadcn__alert_dialog_controlled_value: root[:controlled].to_s,
      chadcn__alert_dialog_id_value: root[:content_id]
    }
  end
end
