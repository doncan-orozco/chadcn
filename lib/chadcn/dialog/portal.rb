# frozen_string_literal: true

# Radix DialogPortal: renders no element. Its children ship in an inert template that the controller mounts directly in
# the container (a CSS selector, default body) while the dialog is open, or always with force_mount.
class Chadcn::Dialog::Portal < Chadcn::Base
  include Chadcn::Dialog::Support

  # @param force_mount [Boolean] keep the content mounted while closed (forwarded to the controller as forceMount)
  # @param container [String, nil] CSS selector of the element the content is mounted in (default: body)
  def initialize(force_mount: false, container: nil)
    @options = { forceMount: force_mount, container: }.compact
    super()
  end

  # @yield the part's content
  # @return [void]
  # @raise [ArgumentError] when rendered outside Dialog
  def view_template
    root = root_context
    previous = context[Chadcn::Dialog::PORTAL_KEY]
    context[Chadcn::Dialog::PORTAL_KEY] = true
    template(data: { shadcn__dialog_template: root[:content_id], shadcn__dialog_options: json(@options) }) { yield if block_given? }
  ensure
    context[Chadcn::Dialog::PORTAL_KEY] = previous
  end
end
