# frozen_string_literal: true

# Radix MenuPortal: renders no element. Only meaningful around SubContent (Content already portals itself); it tells
# SubContent to mount in container: (a CSS selector, default body) instead of in place.
class Phlex::Shadcn::Menubar::Portal < Phlex::Shadcn::Base
  def initialize(force_mount: false, container: nil)
    @force_mount = force_mount
    @container = container
    super()
  end

  def view_template
    previous = context[Phlex::Shadcn::Menubar::PORTAL_KEY]
    context[Phlex::Shadcn::Menubar::PORTAL_KEY] = { force_mount: @force_mount, container: @container }
    yield if block_given?
  ensure
    context[Phlex::Shadcn::Menubar::PORTAL_KEY] = previous
  end
end
