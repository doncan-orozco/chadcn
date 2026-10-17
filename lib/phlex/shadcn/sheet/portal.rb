# frozen_string_literal: true

# Radix DialogPortal: renders no element. Its children ship in an inert template that the controller mounts directly in
# the body while the sheet is open.
#
# Takes no arguments.
class Phlex::Shadcn::Sheet::Portal < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sheet::Support

  # @raise [ArgumentError] when rendered outside Sheet
  # @yield the content to mount
  # @return [void]
  def view_template
    root = root_context
    previous = context[Phlex::Shadcn::Sheet::PORTAL_KEY]
    context[Phlex::Shadcn::Sheet::PORTAL_KEY] = true
    template(data: { shadcn__dialog_template: root[:content_id], shadcn__dialog_options: "{}" }) { yield if block_given? }
  ensure
    context[Phlex::Shadcn::Sheet::PORTAL_KEY] = previous
  end
end
