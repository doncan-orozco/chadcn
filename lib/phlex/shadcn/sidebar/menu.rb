# frozen_string_literal: true

# shadcn SidebarMenu.
#
# Rendered inside a {Phlex::Shadcn::Sidebar}; also available as `sidebar.menu` on the yielded sidebar.
#
# @see Phlex::Shadcn::Sidebar
class Phlex::Shadcn::Sidebar::Menu < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  # Tailwind classes of the `ul` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = "flex w-full min-w-0 flex-col gap-1"

  # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
  #   are deep-merged (caller wins).
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # Renders the `ul` and yields the block as its content.
  #
  # @yield the content of the element
  # @return [void]
  def view_template(&)
    tag(:ul, **part_attrs(CLASSES, data: { slot: "sidebar-menu", sidebar: "menu" }), &)
  end
end
