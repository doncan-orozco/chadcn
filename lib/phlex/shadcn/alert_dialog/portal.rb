# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# Radix AlertDialogPortal: renders no element. Its children ship in an inert template that the controller mounts
# in the body, or in `container` (a CSS selector), while the alert dialog is open.
#
# @example
#   render Phlex::Shadcn::AlertDialog.new do |alert_dialog|
#     alert_dialog.portal(container: "#modals") do
#       alert_dialog.content { alert_dialog.title { "Delete?" } }
#     end
#   end
class Phlex::Shadcn::AlertDialog::Portal < Phlex::Shadcn::Base
  include Phlex::Shadcn::AlertDialog::Support

  # @param force_mount [Boolean] keep the content mounted while closed (forwarded to the controller as forceMount)
  # @param container [String, nil] CSS selector of the element the content is mounted in (default: body)
  def initialize(force_mount: false, container: nil)
    @options = { forceMount: force_mount.unless_blank, container: container }.compact
    super()
  end

  # @yield the part's content
  # @return [void]
  # @raise [ArgumentError] when rendered outside AlertDialog
  def view_template
    root = root_context
    previous = context[Phlex::Shadcn::AlertDialog::PORTAL_KEY]
    context[Phlex::Shadcn::AlertDialog::PORTAL_KEY] = true
    template(data: { shadcn__dialog_template: root[:content_id], shadcn__dialog_options: json(@options) }) { yield if block_given? }
  ensure
    context[Phlex::Shadcn::AlertDialog::PORTAL_KEY] = previous
  end
end
