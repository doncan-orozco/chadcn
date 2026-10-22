# frozen_string_literal: true

# shadcn SidebarMenuSub.
#
# Rendered inside a {Chadcn::Sidebar}; also available as `sidebar.menu_sub` on the yielded sidebar.
#
# @see Chadcn::Sidebar
class Chadcn::Sidebar::MenuSub < Chadcn::Base
  include Chadcn::Sidebar::Support

  # Tailwind classes of the `ul` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = [
    "mx-3.5 flex min-w-0 translate-x-px flex-col gap-1 border-l border-sidebar-border px-2.5 py-0.5",
    "group-data-[collapsible=icon]:hidden"
  ].freeze

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
    ul(**part_attrs(cn(CLASSES), data: { slot: "sidebar-menu-sub", sidebar: "menu-sub" }), &)
  end
end
