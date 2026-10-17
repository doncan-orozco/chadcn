# frozen_string_literal: true

# Radix MenuPortal: renders no element. Only meaningful around {SubContent} (Content already portals itself): it tells
# the SubContent to mount in +container:+ (a CSS selector, default +body+) instead of in place. It reaches only its own
# SubContent; sub menus nested inside need a Portal of their own.
#
# @example
#   bar.portal(container: "#menus") { bar.sub_content { bar.item { "Email" } } }
class Phlex::Shadcn::Menubar::Portal < Phlex::Shadcn::Base
  # @param force_mount [Boolean] keep the SubContent mounted while closed. Default +false+
  # @param container [String, nil] CSS selector of the element to mount into; +body+ when nil or when nothing matches. Default +nil+
  def initialize(force_mount: false, container: nil)
    @force_mount = force_mount
    @container = container
    super()
  end

  # @yield the SubContent to portal
  # @return [void]
  def view_template
    previous = context[Phlex::Shadcn::Menubar::PORTAL_KEY]
    context[Phlex::Shadcn::Menubar::PORTAL_KEY] = { force_mount: @force_mount, container: @container }
    yield if block_given?
  ensure
    context[Phlex::Shadcn::Menubar::PORTAL_KEY] = previous
  end
end
