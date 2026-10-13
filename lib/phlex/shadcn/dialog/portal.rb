# frozen_string_literal: true

# Radix DialogPortal: renders no element. Its children ship in an inert template that the controller mounts directly in
# the container (a CSS selector, default body) while the dialog is open, or always with force_mount.
class Phlex::Shadcn::Dialog::Portal < Phlex::Shadcn::Base
  include Phlex::Shadcn::Dialog::Support

  def initialize(force_mount: false, container: nil)
    @options = { forceMount: force_mount, container: }.compact
    super()
  end

  def view_template
    root = root_context
    previous = context[Phlex::Shadcn::Dialog::PORTAL_KEY]
    context[Phlex::Shadcn::Dialog::PORTAL_KEY] = true
    template(data: { shadcn__dialog_template: root[:content_id], shadcn__dialog_options: json(@options) }) { yield if block_given? }
  ensure
    context[Phlex::Shadcn::Dialog::PORTAL_KEY] = previous
  end
end
