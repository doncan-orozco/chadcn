# frozen_string_literal: true

# shadcn SidebarMenuSkeleton. The text width is random per render like the oracle (50..89 percent, tsx:610-612).
# Parity pages only: with_pinned_width fixes the width so it can match the React harness, which stubs Math.random.
class Phlex::Shadcn::Sidebar::MenuSkeleton < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  CLASSES = "flex h-8 items-center gap-2 rounded-md px-2"

  PIN_KEY = :shadcn_sidebar_menu_skeleton_pinned_width

  # The pinned width is fiber-local state (Thread.current[] is per fiber), so concurrent renders never see each other's pin.
  def self.width_percent = Thread.current[PIN_KEY] || rand(50..89)

  def self.with_pinned_width(percent)
    previous = Thread.current[PIN_KEY]
    Thread.current[PIN_KEY] = percent
    yield
  ensure
    Thread.current[PIN_KEY] = previous
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
