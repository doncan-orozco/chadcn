# frozen_string_literal: true

# shadcn SidebarGroupAction (no `type` attribute, like React).
#
# Rendered inside a {Phlex::Shadcn::Sidebar}; also available as `sidebar.group_action` on the yielded sidebar.
#
# @see Phlex::Shadcn::Sidebar
class Phlex::Shadcn::Sidebar::GroupAction < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  # Tailwind classes of the `button` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = [
    "absolute top-3.5 right-3 flex aspect-square w-5 items-center justify-center rounded-md p-0 text-sidebar-foreground ring-sidebar-ring outline-hidden transition-transform hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:ring-2 [&>svg]:size-4 [&>svg]:shrink-0",
    "after:absolute after:-inset-2 md:after:hidden",
    "group-data-[collapsible=icon]:hidden"
  ].freeze

  # @param as_child [false, nil, Symbol, String, Phlex::Shadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
  #   are deep-merged (caller wins).
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # Renders the `button` (or the `as_child` child) and yields the block as its content.
  #
  # @yield the content of the element
  # @return [void]
  def view_template(&)
    render_part(:button, @as_child, part_attrs(cn(CLASSES), data: { slot: "sidebar-group-action", sidebar: "group-action" }), &)
  end
end
