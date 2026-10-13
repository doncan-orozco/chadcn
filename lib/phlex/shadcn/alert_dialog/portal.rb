# frozen_string_literal: true

# Radix AlertDialogPortal: renders no element. Its children ship in an inert template that the controller mounts
# directly in the body (or in `container`, a CSS selector) while the dialog is open.
class Phlex::Shadcn::AlertDialog::Portal < Phlex::Shadcn::Base
  include Phlex::Shadcn::AlertDialog::Support

  def initialize(force_mount: false, container: nil)
    @options = { forceMount: force_mount.presence, container: container }.compact
    super()
  end

  def view_template
    root = root_context
    previous = context[Phlex::Shadcn::AlertDialog::PORTAL_KEY]
    context[Phlex::Shadcn::AlertDialog::PORTAL_KEY] = true
    template(data: { v2__dialog_template: root[:content_id], v2__dialog_options: @options.to_json }) { yield if block_given? }
  ensure
    context[Phlex::Shadcn::AlertDialog::PORTAL_KEY] = previous
  end
end
