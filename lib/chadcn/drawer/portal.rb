# frozen_string_literal: true

# vaul Portal over Radix DialogPortal: renders no element. Its children ship in an inert template that the controller mounts
# directly in the container (a CSS selector, default the Root's `container:`, else body) while the drawer is open, or always with
# force_mount.
#
# @example Explicit form
#   render Chadcn::Drawer::Portal.new(container: "#slot") { render Chadcn::Drawer::Overlay.new }
# @example Yielded-root helper form
#   drawer.portal { drawer.overlay }
class Chadcn::Drawer::Portal < Chadcn::Base
  include Chadcn::Drawer::Support

  # @param force_mount [Boolean] keep the children mounted while closed (forwarded to the controller as forceMount)
  # @param container [String, nil] CSS selector of the element the children are mounted in
  def initialize(force_mount: false, container: nil)
    @force_mount = force_mount
    @container = container
    super()
  end

  # @yield the part's content
  # @return [void]
  # @raise [ArgumentError] when rendered outside Drawer
  def view_template
    root = root_context
    previous = context[Chadcn::Drawer::PORTAL_KEY]
    context[Chadcn::Drawer::PORTAL_KEY] = true
    options = { forceMount: @force_mount, container: @container || root[:container] }.compact
    template(data: { chadcn__dialog_template: root[:content_id], chadcn__dialog_options: json(options) }) { yield if block_given? }
  ensure
    context[Chadcn::Drawer::PORTAL_KEY] = previous
  end
end
