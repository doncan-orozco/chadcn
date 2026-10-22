# frozen_string_literal: true

# shadcn AlertDialogCancel: closes and receives the open auto focus (ad:92-94).
#
# Cancels and closes the alert dialog (outline Button-styled `button`); receives the open auto focus.
#
# @example Explicit form
#   render Chadcn::AlertDialog::Cancel.new { "Cancel" }
# @example Yielded-root helper form
#   alert_dialog.cancel { "Cancel" }
#
# @!method initialize(variant: nil, size: "default", as_child: false, **attrs)
#   @param variant [String, Symbol, nil] Button variant (Action defaults to "default", Cancel to "outline")
#   @param size [String, Symbol] Button size (default "default")
#   @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
#   @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
#
# @!method view_template(&)
#   @yield the button content
#   @return [void]
#   @raise [ArgumentError] when rendered outside AlertDialog
class Chadcn::AlertDialog::Cancel < Chadcn::Base
  include Chadcn::AlertDialog::ActionButton

  private

  def default_variant = "outline"

  # Marker plus owner id: how the controller finds the element to focus on open (the content id can be overridden by the caller).
  def slot_data = { slot: "alert-dialog-cancel", shadcn__alert_dialog_part: "cancel", shadcn__alert_dialog_owner: root_context[:content_id] }
end
