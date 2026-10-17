# frozen_string_literal: true

# shadcn SidebarRail: the thin toggle strip on the sidebar edge.
#
# Rendered inside a {Phlex::Shadcn::Sidebar::Provider}; also available as `sidebar.rail` on the yielded sidebar.
#
# @see Phlex::Shadcn::Sidebar
class Phlex::Shadcn::Sidebar::Rail < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  # Tailwind classes of the `button` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = [
    "absolute inset-y-0 z-20 hidden w-4 -translate-x-1/2 transition-all ease-linear group-data-[side=left]:-right-4 group-data-[side=right]:left-0 after:absolute after:inset-y-0 after:left-1/2 after:w-[2px] hover:after:bg-sidebar-border sm:flex",
    "in-data-[side=left]:cursor-w-resize in-data-[side=right]:cursor-e-resize",
    "[[data-side=left][data-state=collapsed]_&]:cursor-e-resize [[data-side=right][data-state=collapsed]_&]:cursor-w-resize",
    "group-data-[collapsible=offcanvas]:translate-x-0 group-data-[collapsible=offcanvas]:after:left-full hover:group-data-[collapsible=offcanvas]:bg-sidebar",
    "[[data-side=left][data-collapsible=offcanvas]_&]:-right-2",
    "[[data-side=right][data-collapsible=offcanvas]_&]:-left-2"
  ].freeze

  # @param attrs [Hash] HTML attributes for the `button`; the defaults (`aria-label`, `tabindex`, `title`) can be overridden,
  #   `class:` is tailwind-merged, `data:` and `aria:` are deep-merged (caller wins)
  # @raise [ArgumentError] on render, when there is no {Phlex::Shadcn::Sidebar::Provider} above
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # Renders the `button` that toggles the sidebar and yields the block as its content.
  #
  # @yield the content of the element
  # @return [void]
  def view_template(&)
    Phlex::Shadcn::Sidebar.use_sidebar(self)
    attrs = with_toggle(part_attrs(cn(CLASSES), data: { slot: "sidebar-rail", sidebar: "rail" }, aria: { label: "Toggle Sidebar" },
                                                tabindex: -1, title: "Toggle Sidebar"))
    button(**attrs, &)
  end
end
