# frozen_string_literal: true

# shadcn SidebarFooter.
#
# Rendered inside a {Chadcn::Sidebar}; also available as `sidebar.footer` on the yielded sidebar.
#
# @see Chadcn::Sidebar
class Chadcn::Sidebar::Footer < Chadcn::Base
  include Chadcn::Sidebar::Support

  # Tailwind classes of the `div` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = "flex flex-col gap-2 p-2"

  # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
  #   are deep-merged (caller wins).
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # Renders the `div` and yields the block as its content.
  #
  # @yield the content of the element
  # @return [void]
  def view_template(&)
    tag(:div, **part_attrs(CLASSES, data: { slot: "sidebar-footer", sidebar: "footer" }), &)
  end
end
