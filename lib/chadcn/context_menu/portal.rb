# frozen_string_literal: true

# Radix MenuPortal: renders no element. Only meaningful around {SubContent} (+Content+ already portals itself): it tells the
# SubContent to mount in +container+ (a CSS selector, default +body+) instead of in place. It reaches every SubContent rendered directly
# inside it; sub menus nested inside one of those SubContents need a Portal of their own. It does not require a surrounding root.
#
# @example
#   menu.portal(container: "#overlays") { menu.sub_content { menu.item { "Save" } } }
class Chadcn::ContextMenu::Portal < Chadcn::Base
  # @param force_mount [Boolean] makes the wrapped SubContent force-mounted (default +false+)
  # @param container [String, nil] CSS selector of the element the SubContent mounts into; +nil+ (default) mounts it in +body+
  def initialize(force_mount: false, container: nil)
    @force_mount = force_mount
    @container = container
    super()
  end

  # @yield the parts rendered inside the portal (a SubContent)
  # @return [void]
  def view_template
    previous = context[Chadcn::ContextMenu::PORTAL_KEY]
    context[Chadcn::ContextMenu::PORTAL_KEY] = { force_mount: @force_mount, container: @container }
    yield if block_given?
  ensure
    context[Chadcn::ContextMenu::PORTAL_KEY] = previous
  end
end
