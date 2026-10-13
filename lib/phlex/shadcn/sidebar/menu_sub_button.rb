# frozen_string_literal: true

# shadcn SidebarMenuSubButton (an `a` without href unless given).
class Phlex::Shadcn::Sidebar::MenuSubButton < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  SIZES = %w[sm md].freeze
  CLASSES = [
    "flex h-7 min-w-0 -translate-x-px items-center gap-2 overflow-hidden rounded-md px-2 text-sidebar-foreground ring-sidebar-ring outline-hidden hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:ring-2 active:bg-sidebar-accent active:text-sidebar-accent-foreground disabled:pointer-events-none disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50 [&>span:last-child]:truncate [&>svg]:size-4 [&>svg]:shrink-0 [&>svg]:text-sidebar-accent-foreground",
    "data-[active=true]:bg-sidebar-accent data-[active=true]:text-sidebar-accent-foreground"
  ].freeze
  SIZE_CLASSES = { "sm" => "text-xs", "md" => "text-sm" }.freeze

  def initialize(as_child: false, size: "md", is_active: false, **attrs)
    @as_child = as_child
    @size = normalize_option(size) || "md"
    raise ArgumentError, "unknown size: #{size.inspect} (expected one of #{SIZES.join(', ')})" unless SIZES.include?(@size)

    @is_active = is_active
    @attrs = attrs
    super()
  end

  def view_template(&)
    classes = cn(CLASSES, SIZE_CLASSES.fetch(@size), "group-data-[collapsible=icon]:hidden")
    render_part(:a, @as_child,
                part_attrs(classes, data: { slot: "sidebar-menu-sub-button", sidebar: "menu-sub-button", size: @size, active: @is_active.to_s }), &)
  end
end
