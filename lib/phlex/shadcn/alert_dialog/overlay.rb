# frozen_string_literal: true

# shadcn AlertDialogOverlay. Always rendered: the alert dialog is always modal (dialog:109).
class Phlex::Shadcn::AlertDialog::Overlay < Phlex::Shadcn::Base
  include Phlex::Shadcn::AlertDialog::Support

  CLASSES = "fixed inset-0 z-50 bg-black/50 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0"

  # force_mount has no effect: the surrounding Portal owns the Presence gate (spec, forceMount).
  def initialize(force_mount: false, as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    attrs = merge_attrs({
                          class: CLASSES, style: "pointer-events: auto",
                          data: { slot: "alert-dialog-overlay", state: state_of(root_context), shadcn__dialog_part: "overlay" }
                        }, @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end
