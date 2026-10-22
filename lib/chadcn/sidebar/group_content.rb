# frozen_string_literal: true

# shadcn SidebarGroupContent.
#
# Rendered inside a {Chadcn::Sidebar}; also available as `sidebar.group_content` on the yielded sidebar.
#
# @see Chadcn::Sidebar
class Chadcn::Sidebar::GroupContent < Chadcn::Base
  include Chadcn::Sidebar::Support

  # Tailwind classes of the `div` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = "w-full text-sm"

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
    tag(:div, **part_attrs(CLASSES, data: { slot: "sidebar-group-content", sidebar: "group-content" }), &)
  end
end
