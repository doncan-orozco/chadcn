# frozen_string_literal: true

# shadcn AlertDialogAction: closes (Radix DialogClose, ad:85).
#
# Confirms and closes the alert dialog (a Button-styled `button`).
#
# @example Explicit form
#   render Chadcn::AlertDialog::Action.new { "Action" }
# @example Yielded-root helper form
#   alert_dialog.action { "Action" }
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
class Chadcn::AlertDialog::Action < Chadcn::Base
  include Chadcn::AlertDialog::ActionButton

  private

  def default_variant = "default"

  def slot_data = { slot: "alert-dialog-action" }
end
