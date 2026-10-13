# frozen_string_literal: true

# shadcn Dialog (Radix Dialog). Spec: docs/shadcn-port/specs/dialog.md. Behavior: controllers/v2/dialog_controller.js.
#
# Radix Root renders no element; the port renders one display: contents host that carries the Stimulus controller (a
# trigger cannot host it: zero, one or several triggers, or a controlled open). Portal children are shipped in an inert
# template and mounted into the body by the controller, like Radix mounts them only while open.
class Phlex::Shadcn::Dialog < Phlex::Shadcn::Base
  ROOT_KEY = :v2_dialog_root
  PORTAL_KEY = :v2_dialog_portal
  SEQUENCE_KEY = :v2_dialog_sequence

  # open: non-nil is controlled (user actions only dispatch open-change, the caller updates the open value).
  def initialize(open: nil, default_open: false, modal: true, **attrs)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    @modal = modal
    @attrs = attrs
    super()
  end

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
      controller: "v2--dialog",
      v2__dialog_open_value: root[:open].to_s,
      v2__dialog_controlled_value: root[:controlled].to_s,
      v2__dialog_modal_value: root[:modal].to_s,
      v2__dialog_id_value: root[:content_id]
    }
  end
end
