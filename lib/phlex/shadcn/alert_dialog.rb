# frozen_string_literal: true

# shadcn AlertDialog (Radix AlertDialog, always modal). Spec: docs/shadcn-port/specs/alert-dialog.md. Behavior:
# controllers/shadcn/alert_dialog_controller.js, which reuses the dialog controller.
#
# Radix Root renders no element; the port renders one display: contents host that carries the Stimulus controller (a
# trigger cannot host it: zero, one or several triggers, or a controlled open). Portal children are shipped in an inert
# template and mounted into the body by the controller, like Radix mounts them only while open.
class Phlex::Shadcn::AlertDialog < Phlex::Shadcn::Base
  ROOT_KEY = :shadcn_alert_dialog_root
  PORTAL_KEY = :shadcn_alert_dialog_portal
  SEQUENCE_KEY = :shadcn_alert_dialog_sequence

  # open: non-nil is controlled (user actions only dispatch open-change, the caller updates the open value).
  def initialize(open: nil, default_open: false, **attrs)
    raise ArgumentError, "unknown keyword: #{:modal.inspect} (always modal)" if attrs.key?(:modal)

    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    @attrs = attrs
    super()
  end

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
      controller: "shadcn--alert-dialog",
      shadcn__alert_dialog_open_value: root[:open].to_s,
      shadcn__alert_dialog_controlled_value: root[:controlled].to_s,
      shadcn__alert_dialog_id_value: root[:content_id]
    }
  end
end
