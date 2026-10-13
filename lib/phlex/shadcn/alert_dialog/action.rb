# frozen_string_literal: true

# shadcn AlertDialogAction: closes (Radix DialogClose, ad:85).
class Phlex::Shadcn::AlertDialog::Action < Phlex::Shadcn::Base
  include Phlex::Shadcn::AlertDialog::ActionButton

  private

  def default_variant = "default"

  def slot_data = { slot: "alert-dialog-action" }
end
