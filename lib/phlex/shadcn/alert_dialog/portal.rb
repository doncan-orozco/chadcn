# frozen_string_literal: true

# Radix AlertDialogPortal: renders no element. Its children ship in an inert template that the controller mounts
# directly in the body (or in `container`, a CSS selector) while the dialog is open.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::AlertDialog::Portal < Phlex::Shadcn::Base
  include Phlex::Shadcn::AlertDialog::Support

  def initialize(force_mount: false, container: nil)
    @options = { forceMount: force_mount.unless_blank, container: container }.compact
    super()
  end

  def view_template
    root = root_context
    previous = context[Phlex::Shadcn::AlertDialog::PORTAL_KEY]
    context[Phlex::Shadcn::AlertDialog::PORTAL_KEY] = true
    template(data: { shadcn__dialog_template: root[:content_id], shadcn__dialog_options: json(@options) }) { yield if block_given? }
  ensure
    context[Phlex::Shadcn::AlertDialog::PORTAL_KEY] = previous
  end
end
