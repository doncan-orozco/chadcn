# frozen_string_literal: true

# shadcn SidebarGroup.
#
# Rendered inside a {Phlex::Shadcn::Sidebar}; also available as `sidebar.group` on the yielded sidebar.
#
# @see Phlex::Shadcn::Sidebar
class Phlex::Shadcn::Sidebar::Group < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  # Tailwind classes of the `div` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = "relative flex w-full min-w-0 flex-col p-2"

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
    tag(:div, **part_attrs(CLASSES, data: { slot: "sidebar-group", sidebar: "group" }), &)
  end
end
