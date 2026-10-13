# frozen_string_literal: true

# shadcn AlertDialogCancel: closes and receives the open auto focus (ad:92-94).
class Phlex::Shadcn::AlertDialog::Cancel < Phlex::Shadcn::Base
  include Phlex::Shadcn::AlertDialog::ActionButton

  private

  def default_variant = "outline"

  # Marker plus owner id: how the controller finds the element to focus on open (the content id can be overridden by the caller).
  def slot_data = { slot: "alert-dialog-cancel", v2__alert_dialog_part: "cancel", v2__alert_dialog_owner: root_context[:content_id] }
end
