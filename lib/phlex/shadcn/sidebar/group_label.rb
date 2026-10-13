# frozen_string_literal: true

# shadcn SidebarGroupLabel.
class Phlex::Shadcn::Sidebar::GroupLabel < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  CLASSES = [
    "flex h-8 shrink-0 items-center rounded-md px-2 text-xs font-medium text-sidebar-foreground/70 ring-sidebar-ring outline-hidden transition-[margin,opacity] duration-200 ease-linear focus-visible:ring-2 [&>svg]:size-4 [&>svg]:shrink-0",
    "group-data-[collapsible=icon]:-mt-8 group-data-[collapsible=icon]:opacity-0"
  ].freeze

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    render_part(:div, @as_child, part_attrs(cn(CLASSES), data: { slot: "sidebar-group-label", sidebar: "group-label" }), &)
  end
end
