# frozen_string_literal: true

# Radix MenuPortal: renders no element. Only meaningful around SubContent (Content already portals itself); it tells
# SubContent to mount in container: (a CSS selector, default body) instead of in place. It reaches only its own SubContent:
# sub menus nested inside need a Portal of their own. It only sets render context, so it never raises outside a root.
#
# @example
#   menu.sub do
#     menu.sub_trigger { "More" }
#     menu.portal { menu.sub_content { menu.item { "Export" } } }
#   end
class Phlex::Shadcn::DropdownMenu::Portal < Phlex::Shadcn::Base
  # @param force_mount [Boolean] forwarded to the SubContent options as +forceMount+, default +false+
  # @param container [String, nil] CSS selector of the mount point, default +nil+ (the controller mounts in +body+)
  def initialize(force_mount: false, container: nil)
    @force_mount = force_mount
    @container = container
    super()
  end

  # @yield the SubContent to portal
  # @return [void]
  def view_template
    previous = context[Phlex::Shadcn::DropdownMenu::PORTAL_KEY]
    context[Phlex::Shadcn::DropdownMenu::PORTAL_KEY] = { force_mount: @force_mount, container: @container }
    yield if block_given?
  ensure
    context[Phlex::Shadcn::DropdownMenu::PORTAL_KEY] = previous
  end
end
