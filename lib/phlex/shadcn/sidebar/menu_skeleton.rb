# frozen_string_literal: true

# shadcn SidebarMenuSkeleton. The text width is random per render like the oracle (50..89 percent, tsx:610-612).
# Parity pages only: with_pinned_width fixes the width so it can match the React harness, which stubs Math.random.
class Phlex::Shadcn::Sidebar::MenuSkeleton < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  CLASSES = "flex h-8 items-center gap-2 rounded-md px-2"

  PIN_KEY = :v2_sidebar_menu_skeleton_pinned_width

  def self.width_percent = ActiveSupport::IsolatedExecutionState[PIN_KEY] || rand(50..89)

  def self.with_pinned_width(percent)
    previous = ActiveSupport::IsolatedExecutionState[PIN_KEY]
    ActiveSupport::IsolatedExecutionState[PIN_KEY] = percent
    yield
  ensure
    ActiveSupport::IsolatedExecutionState[PIN_KEY] = previous
  end

  def initialize(show_icon: false, **attrs)
    @show_icon = show_icon
    @attrs = attrs
    super()
  end

  def view_template
    div(**part_attrs(CLASSES, data: { slot: "sidebar-menu-skeleton", sidebar: "menu-skeleton" })) do
      render Phlex::Shadcn::Skeleton.new(class: "size-4 rounded-md", data: { sidebar: "menu-skeleton-icon" }) if @show_icon
      render Phlex::Shadcn::Skeleton.new(class: "h-4 max-w-(--skeleton-width) flex-1", data: { sidebar: "menu-skeleton-text" },
                                         style: "--skeleton-width: #{self.class.width_percent}%;")
    end
  end
end
